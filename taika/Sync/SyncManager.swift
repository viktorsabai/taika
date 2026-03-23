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

@MainActor
public final class SyncManager: ObservableObject {

    public static let shared = SyncManager()

    @Published public private(set) var lastPushAt: Date?
    @Published public private(set) var lastPullAt: Date?
    @Published public private(set) var syncError: String?

    private var pushWorkItem: DispatchWorkItem?
    private var timer: Timer?

    private init() {
        if FirebaseApp.app() != nil {
            startPeriodicPushIfNeeded()
        }
    }

    /// Call after Auth state changes (login) to pull once and then start push.
    public func onUserDidLogin(userId: String) {
        syncError = nil
        startPeriodicPushIfNeeded()
        Task {
            await pullAndApply(userId: userId)
        }
    }

    /// Call on app launch when user is already logged in (pull latest from cloud once).
    public func restoreIfNeeded(userId: String) {
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
                await MainActor.run { lastPullAt = Date() }
                return
            }
            let snap = try JSONDecoder().decode(USSnapshot.self, from: data)
            await MainActor.run {
                UserSession.shared.applySnapshotFromSync(snap)
                ProgressManager.shared.applyFromUSSnapshot(snap)
                lastPullAt = Date()
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
}
