//
//  SyncManager.swift
//  taika
//
//  Push/pull UserSession snapshot to Firestore. No-op when Firebase is not configured or user not logged in.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

private let progressKey = "progress"
private let updatedAtKey = "updatedAt"
private let usersCollection = "users"
private let syncInterval: TimeInterval = 300 // 5 min
private let pullCooldownInterval: TimeInterval = 90

@MainActor
public final class SyncManager: ObservableObject {

    public static let shared = SyncManager()

    @Published public private(set) var lastPushAt: Date?
    @Published public private(set) var lastPullAt: Date?
    @Published public private(set) var syncError: String?
    @Published public private(set) var lastCloudUpdatedAt: Date?

    public var diagnosticsSummary: String {
        let push = lastPushAt?.formatted(date: .omitted, time: .standard) ?? "—"
        let pull = lastPullAt?.formatted(date: .omitted, time: .standard) ?? "—"
        let cloud = lastCloudUpdatedAt?.formatted(date: .abbreviated, time: .standard) ?? "—"
        let err = syncError?.isEmpty == false ? syncError! : "ok"
        return "push: \(push) | pull: \(pull) | cloud: \(cloud) | status: \(err)"
    }

    private var pushWorkItem: DispatchWorkItem?
    private var timer: Timer?
    private var notificationTokens: [NSObjectProtocol] = []
    private var hasRestoredForCurrentSession: Bool = false
    private var restoredUserId: String?

    private init() {
        if FirebaseApp.app() != nil {
            startPeriodicPushIfNeeded()
            bindProgressChangeTriggers()
        }
    }

    /// Call after Auth state changes (login) to pull once and then start push.
    public func onUserDidLogin(userId: String) {
        syncError = nil
        hasRestoredForCurrentSession = false
        restoredUserId = nil
        startPeriodicPushIfNeeded()
        restoreIfNeeded(userId: userId, force: true)
    }

    /// Call on app launch when user is already logged in (pull latest from cloud once).
    public func restoreIfNeeded(userId: String, force: Bool = false) {
        if !force {
            if hasRestoredForCurrentSession, restoredUserId == userId { return }
            if let lastPullAt, Date().timeIntervalSince(lastPullAt) < pullCooldownInterval { return }
        }
        startPeriodicPushIfNeeded()
        Task {
            await pullAndApply(userId: userId)
        }
    }

    /// Push current progress to Firestore. Called periodically and on background.
    public func pushNow() async {
        guard let uid = AuthService.shared.currentUserID,
              FirebaseApp.app() != nil else { return }
        let snap = UserSession.shared.snapshot
        do {
            let data = try JSONEncoder().encode(snap)
            guard let json = String(data: data, encoding: .utf8) else { return }
            let doc: [String: Any] = [
                progressKey: json,
                updatedAtKey: FieldValue.serverTimestamp()
            ]
            try await Firestore.firestore().collection(usersCollection).document(uid).setData(doc, merge: true)
            await MainActor.run {
                lastPushAt = Date()
                syncError = nil
            }
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
            }
        }
    }

    /// Pull once and apply to UserSession + ProgressManager.
    public func pullAndApply(userId: String) async {
        guard FirebaseApp.app() != nil else { return }
        do {
            let doc = try await Firestore.firestore().collection(usersCollection).document(userId).getDocument()
            guard doc.exists,
                  let json = doc.data()?[progressKey] as? String,
                  let data = json.data(using: .utf8) else {
                await MainActor.run {
                    lastPullAt = Date()
                    hasRestoredForCurrentSession = true
                    restoredUserId = userId
                }
                return
            }
            let remoteSnapshot = try JSONDecoder().decode(USSnapshot.self, from: data)
            let localSnapshot = UserSession.shared.snapshot
            let merged = Self.mergeSnapshots(local: localSnapshot, remote: remoteSnapshot)
            let cloudUpdatedAt = (doc.data()?[updatedAtKey] as? Timestamp)?.dateValue()
            await MainActor.run {
                UserSession.shared.applySnapshotFromSync(merged)
                ProgressManager.shared.applyFromUSSnapshot(merged)
                lastPullAt = Date()
                lastCloudUpdatedAt = cloudUpdatedAt
                hasRestoredForCurrentSession = true
                restoredUserId = userId
                syncError = nil
            }
        } catch {
            await MainActor.run {
                syncError = error.localizedDescription
            }
        }
    }

    public func schedulePush() {
        guard AuthService.shared.currentUserID != nil, FirebaseApp.app() != nil else { return }
        pushWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.pushNow()
            }
        }
        pushWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func startPeriodicPushIfNeeded() {
        guard FirebaseApp.app() != nil else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pushNow()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func bindProgressChangeTriggers() {
        guard notificationTokens.isEmpty else { return }
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            .stepProgressDidChange,
            .ProgressDidChange,
            .usStepLearnedSetDidChange
        ]
        notificationTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.schedulePush()
                }
            }
        }
    }

    private static func mergeSnapshots(local: USSnapshot, remote: USSnapshot) -> USSnapshot {
        var out = local

        out.startedCourses.formUnion(remote.startedCourses)

        for (courseId, lessons) in remote.startedLessons {
            var existing = out.startedLessons[courseId] ?? []
            existing.formUnion(lessons)
            out.startedLessons[courseId] = existing
        }

        for (courseId, lessons) in remote.completedLessons {
            var existing = out.completedLessons[courseId] ?? []
            existing.formUnion(lessons)
            out.completedLessons[courseId] = existing
        }

        for (compound, indices) in remote.learnedSteps {
            var existing = out.learnedSteps[compound] ?? []
            existing.formUnion(indices)
            out.learnedSteps[compound] = existing
        }

        for (kind, refs) in remote.favorites {
            var existing = out.favorites[kind] ?? []
            existing.formUnion(refs)
            out.favorites[kind] = existing
        }

        for (courseId, byLesson) in remote.lessonProgress {
            var existingByLesson = out.lessonProgress[courseId] ?? [:]
            for (lessonId, remoteProgress) in byLesson {
                if let localProgress = existingByLesson[lessonId] {
                    let learned = max(localProgress.learned, remoteProgress.learned)
                    let total = max(localProgress.total, remoteProgress.total)
                    let status: LessonStatus = (localProgress.status == .completed || remoteProgress.status == .completed)
                        ? .completed
                        : (localProgress.status == .inProgress || remoteProgress.status == .inProgress ? .inProgress : .locked)
                    existingByLesson[lessonId] = LessonProgress(learned: learned, total: total, status: status)
                } else {
                    existingByLesson[lessonId] = remoteProgress
                }
            }
            out.lessonProgress[courseId] = existingByLesson
        }

        for (day, courses) in remote.dayCourses {
            var existing = out.dayCourses[day] ?? []
            existing.formUnion(courses)
            out.dayCourses[day] = existing
        }

        for (day, events) in remote.activityLog {
            let localEvents = out.activityLog[day] ?? []
            let merged = Dictionary(uniqueKeysWithValues: (localEvents + events).map { ($0.id, $0) })
            out.activityLog[day] = merged.values.sorted { $0.ts < $1.ts }
        }

        for (day, courses) in remote.plannedDayCourses {
            var existing = out.plannedDayCourses[day] ?? []
            existing.formUnion(courses)
            out.plannedDayCourses[day] = existing
        }

        for (day, courseId) in remote.plannedDayLastCourseId {
            if out.plannedDayLastCourseId[day] == nil {
                out.plannedDayLastCourseId[day] = courseId
            }
        }

        if out.lastCourseId == nil { out.lastCourseId = remote.lastCourseId }
        for (courseId, lessonId) in remote.lastLessonByCourse where out.lastLessonByCourse[courseId] == nil {
            out.lastLessonByCourse[courseId] = lessonId
        }
        for (compound, index) in remote.lastStepByLesson where out.lastStepByLesson[compound] == nil {
            out.lastStepByLesson[compound] = index
        }

        out.sessionStartedAt = min(local.sessionStartedAt, remote.sessionStartedAt)
        out.lastEventAt = max(local.lastEventAt, remote.lastEventAt)
        out.isProUser = local.isProUser || remote.isProUser

        return out
    }
}
