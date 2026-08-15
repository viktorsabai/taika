//  ProgressManager.swift
//  taika
//
//  Created by product on 14.09.2025.
//

import Foundation
import Combine

// MARK: - Key
public struct LessonKey: Hashable, Codable {
    public let courseId: String
    public let lessonId: String
    public init(courseId: String, lessonId: String) {
        self.courseId = courseId
        self.lessonId = lessonId
    }
}


// MARK: - Aggregated Helpers

// MARK: - Notifications
public extension Notification.Name {
    static let progressDidChange = Notification.Name("progressDidChange")
    static let ProgressDidChange = Notification.Name("ProgressDidChange")
    static let progressLessonDidReset = Notification.Name("progressLessonDidReset")
    static let progressCourseDidReset = Notification.Name("progressCourseDidReset")
    static let stepLocalStateShouldReset = Notification.Name("stepLocalStateShouldReset")

    /// Fired when a step is marked learned (e.g. after Recall/Match or from Step view). userInfo: courseId, lessonId, index, gameType ("step" | "recall" | "match"). For Smart Discovery / analytics.
    static let masteryUpdate = Notification.Name("MasteryUpdate")

    // legacy aliases for backward compatibility with existing listeners
    static let lessonProgressDidReset = Notification.Name("lessonProgressDidReset")
    static let courseProgressDidReset = Notification.Name("courseProgressDidReset")

    /// Unified progress signal for LessonsManager, StepView, ProfileManager (historical raw name: `"Step.progressDidChange"`).
    static let stepProgressDidChange = Notification.Name("Step.progressDidChange")
}
// MARK: - Persistence DTO

// MARK: - Persistence DTO
private struct PMStore: Codable {
    var learned: [LessonKey: Set<Int>] = [:]
    var started: Set<LessonKey> = []
    var completed: Set<LessonKey> = []

    // yyyy-mm-dd -> set(courseId)
    var dayCourses: [String: Set<String>] = [:]
}

// MARK: - ProgressManager (single source of truth for "learned")
@MainActor
public final class ProgressManager: ObservableObject {
    public static let shared = ProgressManager()

    // Memoization to avoid repeated canonicalization and noisy logs
    private var canonCache: [String: String] = [:]            // raw -> canon
    private var keyCache: [String: LessonKey] = [:]           // "rawCourse|rawLesson" -> LessonKey

    // Per-lesson learned step indexes (excludes tips/hacks by контракт в вызывающей стороне)
    @Published private(set) var learnedSteps: [LessonKey: Set<Int>] = [:]
    @Published private(set) var startedLessons: Set<LessonKey> = []
    @Published private(set) var completedLessons: Set<LessonKey> = []
    // yyyy-mm-dd -> set(courseId)
    @Published private(set) var dayCourses: [String: Set<String>] = [:]
    @Published public private(set) var revision: Int = 0
    /// Profile dashboard: Total Stable Steps, Streak, Mastery %, Speaking, Radar. Пересобирается в emitChange() и load().
    @Published public private(set) var publishedState: ProfileDashboardState = .empty

    public var snapshot: (learned: [LessonKey: Set<Int>], started: Set<LessonKey>, completed: Set<LessonKey>) {
        (learnedSteps, startedLessons, completedLessons)
    }

    // MARK: Key canonicalization (internal for ProgressManager+Profile)
    func canonicalize(_ raw: String) -> String {
        if let cached = canonCache[raw] { return cached }
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { canonCache[raw] = s; return s }
        s = s.lowercased()
        s = s.replacingOccurrences(of: " ", with: "-")
        s = s.replacingOccurrences(of: "_", with: "-")
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        canonCache[raw] = s
        return s
    }

    private func makeKey(courseId: String, lessonId: String) -> LessonKey {
        let cacheKey = "\(courseId)|\(lessonId)"
        if let cached = keyCache[cacheKey] { return cached }
        let c = canonicalize(courseId)
        let l = canonicalize(lessonId)
        let key = LessonKey(courseId: c, lessonId: l)
        keyCache[cacheKey] = key
        return key
    }

    // MARK: - Day activity log (courses)
    private func dayKey(for date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func recordCourseActivity(courseId: String, on date: Date) {
        // deprecated: calendar history is tracked in UserSession
    }

    /// Обновить publishedState после готовности синглтонов (напр. из ProfileView.task). Присвоение только здесь — setter private(set).
    public func refreshProfileState() {
        publishedState = rebuildProfileDashboardState()
    }

    private var emitWorkItem: DispatchWorkItem?
    /// Guards against recursive resetLesson from notification handlers.
    private var isResettingLesson = false
    private var isResettingCourse = false
    private func emitChange() {
        emitWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.revision &+= 1
            self.publishedState = self.rebuildProfileDashboardState()
            NotificationCenter.default.post(name: .progressDidChange, object: self)
            NotificationCenter.default.post(name: .ProgressDidChange, object: self)
        }
        emitWorkItem = work
        // Debounce a little to avoid UI thrash when multiple mutations happen in a burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func purgeLesson(courseId rawCourse: String, lessonId rawLesson: String) {
        let canonCourse = canonicalize(rawCourse)
        let canonLesson = canonicalize(rawLesson)

        // Rebuild learnedSteps without the target lesson (match by canonical OR raw to be safe)
        var newLearned: [LessonKey: Set<Int>] = [:]
        for (k, v) in learnedSteps {
            let isSameCourse = (k.courseId == canonCourse) || (k.courseId == rawCourse)
            let isSameLesson = (k.lessonId == canonLesson) || (k.lessonId == rawLesson)
            if !(isSameCourse && isSameLesson) {
                newLearned[k] = v
            }
        }
        learnedSteps = newLearned

        // Rebuild started/completed without the target lesson
        startedLessons = Set(startedLessons.filter { key in
            let isSameCourse = (key.courseId == canonCourse) || (key.courseId == rawCourse)
            let isSameLesson = (key.lessonId == canonLesson) || (key.lessonId == rawLesson)
            return !(isSameCourse && isSameLesson)
        })
        completedLessons = Set(completedLessons.filter { key in
            let isSameCourse = (key.courseId == canonCourse) || (key.courseId == rawCourse)
            let isSameLesson = (key.lessonId == canonLesson) || (key.lessonId == rawLesson)
            return !(isSameCourse && isSameLesson)
        })
    }

    private let defaults = UserDefaults.standard
    private let storeKey = "ProgressManager.store.v1"
    private var saveWorkItem: DispatchWorkItem?

    private init() {
        load()
        // EPIC 4: single source for course progress — compute from learnedSteps + LessonsData/StepData meta
        lessonMetaProvider = { courseId in
            // Be defensive about courseId formatting (dash vs underscore).
            // Different entry points can pass either variant, while LessonsData/steps.json
            // typically use one canonical form.
            var lessons = LessonsData.shared.lessons(for: courseId)
            if lessons.isEmpty {
                lessons = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "_", with: "-"))
            }
            if lessons.isEmpty {
                lessons = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "-", with: "_"))
            }
            return lessons.map { lesson in
                let items = StepData.shared.items(for: lesson.lessonID)
                var tipIndexes = Set<Int>()
                var learnable = 0
                for item in items {
                    switch item.kind {
                    case .tip, .dialog:
                        tipIndexes.insert(item.order)
                    case .word, .phrase, .casual:
                        learnable += 1
                    }
                }
                let excludedIndexes = StepData.shared.invalidProgressIndices(for: lesson.lessonID)
                // totalSteps = только учебные карточки; tipIndexes оставляем, чтобы вычищать
                // случайно сохранённые ключи лайфхаков из learnedSteps.
                return (id: lesson.lessonID, totalSteps: learnable, tipIndexes: tipIndexes, excludedIndexes: excludedIndexes)
            }
        }
        // Не вызываем rebuildProfileDashboardState() здесь: UserSession.shared в цепочке → возможный цикл при старте.
        // Первый пересчёт — из ProfileView.task или при первом emitChange().
    }

    // MARK: - Debug: cross-cutting progress audit
    #if DEBUG
    private static var didRunDebugAudit: Bool = false

    /// One-shot integrity audit for learned/progress. Enabled by UserDefaults flag:
    /// `taika.debug.progressAudit = true`
    ///
    /// Prints only anomalies (invalid indices, learned includes tips/excluded, learned > effective total).
    public func debugAuditProgressIfEnabled() {
        guard !Self.didRunDebugAudit else { return }
        guard UserDefaults.standard.bool(forKey: "taika.debug.progressAudit") else { return }
        Self.didRunDebugAudit = true

        StepData.shared.preload()

        var issues: [String] = []
        issues.reserveCapacity(64)

        let snap = learnedSteps
        if snap.isEmpty {
            print("[ProgressAudit] learnedSteps is empty (no progress stored).")
            return
        }

        for (key, learned) in snap {
            let courseId = key.courseId
            let lessonId = key.lessonId

            let items = StepData.shared.items(for: lessonId)
            let totalSteps = items.count

            // Rebuild tip/excluded sets exactly like meta provider does
            var tipIndexes = Set<Int>()
            tipIndexes.reserveCapacity(8)
            for item in items {
                if item.kind == .tip || item.kind == .dialog { tipIndexes.insert(item.order) }
            }
            let excluded = StepData.shared.invalidProgressIndices(for: lessonId)

            let invalid = learned.filter { $0 < 0 || $0 >= totalSteps }
            if !invalid.isEmpty {
                issues.append("[ProgressAudit] invalid indices course=\(courseId) lesson=\(lessonId) total=\(totalSteps) invalid=\(Array(invalid).sorted()) learnedCount=\(learned.count)")
            }

            let learnedTips = learned.intersection(tipIndexes)
            if !learnedTips.isEmpty {
                issues.append("[ProgressAudit] learned contains tips/dialog course=\(courseId) lesson=\(lessonId) tips=\(Array(learnedTips).sorted())")
            }

            let learnedExcluded = learned.intersection(excluded)
            if !learnedExcluded.isEmpty {
                issues.append("[ProgressAudit] learned contains excluded indices course=\(courseId) lesson=\(lessonId) excluded=\(Array(learnedExcluded).sorted())")
            }

            let effectiveTotal = max(0, totalSteps - tipIndexes.count - excluded.count)
            let effectiveLearned = learned.subtracting(tipIndexes).subtracting(excluded).filter { $0 >= 0 && $0 < totalSteps }
            if effectiveLearned.count > effectiveTotal {
                issues.append("[ProgressAudit] learned > totalEff course=\(courseId) lesson=\(lessonId) learnedEff=\(effectiveLearned.count) totalEff=\(effectiveTotal) total=\(totalSteps) tips=\(tipIndexes.count) excluded=\(excluded.count)")
            }
        }

        if issues.isEmpty {
            print("[ProgressAudit] OK: no anomalies across \(snap.count) lessons.")
        } else {
            print("[ProgressAudit] FOUND \(issues.count) issue(s):")
            for line in issues.prefix(80) { print(line) }
            if issues.count > 80 { print("[ProgressAudit] (truncated; \(issues.count - 80) more)") }
        }
    }
    #endif

    // MARK: Read
    public func learnedSet(courseId: String, lessonId: String) -> Set<Int> {
        learnedSteps[makeKey(courseId: courseId, lessonId: lessonId)] ?? []
    }

    public func isStepLearned(courseId: String, lessonId: String, index: Int) -> Bool {
        learnedSet(courseId: courseId, lessonId: lessonId).contains(index)
    }

    // MARK: - Effective count helpers
    /// Считаем только word/phrase/casual. Ключи в `learnedSteps` могут быть `order`,
    /// enumerated index или compact-индекс среди learnable — матчим все три, лайфхаки не учитываем.
    public func learnedEffectiveCount(courseId: String, lessonId: String) -> Int {
        let learned = learnedSet(courseId: courseId, lessonId: lessonId)
        guard !learned.isEmpty else { return 0 }
        let items = StepData.shared.items(for: lessonId)
        let invalid = StepData.shared.invalidProgressIndices(for: lessonId)
        var count = 0
        var learnableOrdinal = 0
        for (i, item) in items.enumerated() {
            switch item.kind {
            case .word, .phrase, .casual:
                let orderKey = item.order >= 0 ? item.order : i
                defer { learnableOrdinal += 1 }
                if invalid.contains(orderKey) || invalid.contains(i) { continue }
                if Self.matchesLearnedIndex(learned, order: orderKey, enumerated: i, learnableOrdinal: learnableOrdinal) {
                    count += 1
                }
            default:
                continue
            }
        }
        return count
    }

    public func totalEffectiveCount(courseId: String, lessonId: String) -> Int {
        let items = StepData.shared.items(for: lessonId)
        let invalid = StepData.shared.invalidProgressIndices(for: lessonId)
        var total = 0
        for (i, item) in items.enumerated() {
            switch item.kind {
            case .word, .phrase, .casual:
                let orderKey = item.order >= 0 ? item.order : i
                if invalid.contains(orderKey) || invalid.contains(i) { continue }
                total += 1
            default:
                continue
            }
        }
        if total > 0 { return total }
        // Fallback if StepData ещё не прогрузил урок.
        let counts = StepData.shared.progressCounts(for: lessonId)
        if counts.learnable > 0 { return counts.learnable }
        if let meta = lessonMeta(courseId: courseId, lessonId: lessonId) {
            // meta.totalSteps уже learnable-only (без tipIndexes в знаменателе).
            return max(0, meta.totalSteps - meta.excludedIndexes.count)
        }
        return 0
    }

    /// Совпадение ключа прогресса с карточкой (order / index / compact learnable ordinal).
    public static func matchesLearnedIndex(
        _ learned: Set<Int>,
        order: Int,
        enumerated: Int,
        learnableOrdinal: Int
    ) -> Bool {
        learned.contains(order)
            || learned.contains(enumerated)
            || learned.contains(learnableOrdinal)
    }

    private func lessonMeta(
        courseId: String,
        lessonId: String
    ) -> (id: String, totalSteps: Int, tipIndexes: Set<Int>, excludedIndexes: Set<Int>)? {
        guard let meta = lessonMetaProvider?(courseId) else { return nil }
        let canonLesson = canonicalize(lessonId)
        // Match by canonical id (defensive vs raw ids)
        return meta.first(where: { canonicalize($0.id) == canonLesson })
    }

    // MARK: Write
    public func setStepLearned(courseId: String, lessonId: String, index: Int, isLearned: Bool, excludedIndexes: Set<Int> = []) {
        if excludedIndexes.contains(index) {
            // Ignore changes to excluded indexes
            return
        }
        let key = makeKey(courseId: courseId, lessonId: lessonId)
        var set = learnedSteps[key] ?? []
        let had = set.contains(index)
        if isLearned == had { return } // no change
        if isLearned {
            set.insert(index)
        } else {
            set.remove(index)
        }

        // calendar history is tracked in UserSession
        UserSession.shared.setStepLearned(
            courseId: courseId,
            lessonId: lessonId,
            index: index,
            isLearned: isLearned
        )
        learnedSteps[key] = set
        startedLessons.insert(key)
        scheduleSave(immediate: true)
        emitChange()
        NotificationCenter.default.post(
            name: .stepProgressDidChange,
            object: self,
            userInfo: [
                "courseId": courseId,
                "lessonId": lessonId,
                "index": index,
                "isLearned": isLearned
            ]
        )
    }

    /// Convenience async facade used by UI layers: marks a step as learned.
    /// Exists to keep older call sites (`await ProgressManager.shared.markLearned(...)`) compiling.
    public func markLearned(
        courseId: String,
        lessonId: String,
        index: Int,
        excludedIndexes: Set<Int> = []
    ) async {
        setStepLearned(courseId: courseId, lessonId: lessonId, index: index, isLearned: true, excludedIndexes: excludedIndexes)
    }

    /// Convenience async facade used by UI layers: marks a step as **not** learned.
    public func markUnlearned(
        courseId: String,
        lessonId: String,
        index: Int,
        excludedIndexes: Set<Int> = []
    ) async {
        setStepLearned(courseId: courseId, lessonId: lessonId, index: index, isLearned: false, excludedIndexes: excludedIndexes)
    }

    /// Call this after mutating learned to update completed state for the lesson.
    /// - Parameters:
    ///   - totalSteps: total count of steps in lesson **excluding** hacks/tips
    ///   - tipIndexes: indexes of hack/tip steps that should not count to completion
    ///   - excludedIndexes: indexes of intro/summary or other steps that should not count to completion
    /// - Returns: true if status became completed
    @discardableResult
    public func markCompletedIfNeeded(courseId: String, lessonId: String, totalSteps: Int, tipIndexes: Set<Int> = [], excludedIndexes: Set<Int> = []) -> Bool {
        let key = makeKey(courseId: courseId, lessonId: lessonId)
        let learned = learnedSteps[key] ?? []
        let effectiveLearned = learned.subtracting(tipIndexes).subtracting(excludedIndexes)
        let shouldBeCompleted = (totalSteps > 0 && effectiveLearned.count == totalSteps)
        let hadCompleted = completedLessons.contains(key)
        if shouldBeCompleted {
            if !hadCompleted {
                completedLessons.insert(key)
                scheduleSave()
                emitChange()
                NotificationCenter.default.post(
                    name: .stepProgressDidChange,
                    object: self,
                    userInfo: [
                        "courseId": courseId,
                        "lessonId": lessonId,
                        "completed": true
                    ]
                )
            }
            return true
        } else {
            if hadCompleted {
                completedLessons.remove(key)
                scheduleSave()
                emitChange()
                NotificationCenter.default.post(
                    name: .stepProgressDidChange,
                    object: self,
                    userInfo: [
                        "courseId": courseId,
                        "lessonId": lessonId,
                        "completed": false
                    ]
                )
            }
            return false
        }
    }

    /// Returns the progress fraction [0, 1] for a lesson, counting only learnable cards.
    public func lessonProgressFraction(
        courseId: String,
        lessonId: String,
        totalSteps: Int,
        tipIndexes: Set<Int> = [],
        excludedIndexes: Set<Int> = []
    ) -> Double {
        // Prefer kind-based counters (устойчивы к смеси order/enum/compact ключей).
        let learned = learnedEffectiveCount(courseId: courseId, lessonId: lessonId)
        let total = totalSteps > 0
            ? max(0, totalSteps - excludedIndexes.count)
            : totalEffectiveCount(courseId: courseId, lessonId: lessonId)
        guard total > 0 else { return 0 }
        _ = tipIndexes // tips never enter the denominator; learnedEffectiveCount already ignores them
        return min(1.0, Double(learned) / Double(total))
    }

    /// Backward-compatible overload that ignores tipIndexes.
    public func lessonProgressFraction(
        courseId: String,
        lessonId: String,
        totalSteps: Int,
        excludedIndexes: Set<Int>
    ) -> Double {
        lessonProgressFraction(
            courseId: courseId,
            lessonId: lessonId,
            totalSteps: totalSteps,
            tipIndexes: [],
            excludedIndexes: excludedIndexes
        )
    }

    public func markStarted(courseId: String, lessonId: String) {
        let key = makeKey(courseId: courseId, lessonId: lessonId)
        if startedLessons.contains(key) { return }
        startedLessons.insert(key)
        scheduleSave()
        emitChange()
    }

    /// Hard clear learned set for a particular lesson (no notifications, no started/completed touches).
    /// Useful to ensure UI hydrations don't pick stale data between reset and next render.
    public func clearLearnedOnly(courseId: String, lessonId: String) {
        let key = makeKey(courseId: courseId, lessonId: lessonId)
        learnedSteps.removeValue(forKey: key)
        scheduleSave(immediate: true)
    }

    // MARK: Reset
    public func resetLesson(courseId: String, lessonId: String) {
        // Re-entrancy guard: StepView used to call resetLesson again from .lessonProgressDidReset.
        if isResettingLesson { return }
        isResettingLesson = true
        defer { isResettingLesson = false }

        purgeLesson(courseId: courseId, lessonId: lessonId)
        scheduleSave(immediate: true)
        emitChange()
        NotificationCenter.default.post(name: .progressLessonDidReset, object: self, userInfo: ["courseId": courseId, "lessonId": lessonId])
        NotificationCenter.default.post(name: .lessonProgressDidReset, object: self, userInfo: ["courseId": courseId, "lessonId": lessonId])
        NotificationCenter.default.post(
            name: .stepLocalStateShouldReset,
            object: self,
            userInfo: [
                "scope": "lesson",
                "courseId": courseId,
                "lessonId": lessonId
            ]
        )
    }

    public func resetCourse(courseId: String) {
        if isResettingCourse { return }
        isResettingCourse = true
        defer { isResettingCourse = false }

        let norm = canonicalize(courseId)

        // learned
        var newLearned: [LessonKey: Set<Int>] = [:]
        for (k, v) in learnedSteps {
            if !(k.courseId == norm || k.courseId == courseId) {
                newLearned[k] = v
            }
        }
        learnedSteps = newLearned

        // started/completed
        startedLessons = Set(startedLessons.filter { !($0.courseId == norm || $0.courseId == courseId) })
        completedLessons = Set(completedLessons.filter { !($0.courseId == norm || $0.courseId == courseId) })

        // Persist & notify
        scheduleSave(immediate: true)
        emitChange()
        NotificationCenter.default.post(name: .progressCourseDidReset, object: self, userInfo: ["courseId": courseId])
        NotificationCenter.default.post(name: .courseProgressDidReset, object: self, userInfo: ["courseId": courseId])
        NotificationCenter.default.post(
            name: .stepLocalStateShouldReset,
            object: self,
            userInfo: [
                "scope": "course",
                "courseId": courseId
            ]
        )
    }

    public func resetAll() {
        learnedSteps.removeAll()
        startedLessons.removeAll()
        completedLessons.removeAll()
        dayCourses.removeAll()
        scheduleSave(immediate: true)
        emitChange()
        NotificationCenter.default.post(
            name: .stepLocalStateShouldReset,
            object: self,
            userInfo: [
                "scope": "all"
            ]
        )
    }

    /// Apply progress from cloud sync (USSnapshot). Call after UserSession.applySnapshotFromSync.
    public func applyFromUSSnapshot(_ snap: USSnapshot) {
        var learned: [LessonKey: Set<Int>] = [:]
        let sep = "|"
        for (compound, set) in snap.learnedSteps {
            guard let idx = compound.firstIndex(of: "|") else { continue }
            let courseId = String(compound[..<idx])
            let lessonId = String(compound[compound.index(after: idx)...])
            let key = makeKey(courseId: courseId, lessonId: lessonId)
            learned[key] = set
        }
        learnedSteps = learned
        startedLessons = Set(learned.keys)
        var completed: Set<LessonKey> = []
        for (courseId, lessonIds) in snap.completedLessons {
            for lessonId in lessonIds {
                completed.insert(makeKey(courseId: courseId, lessonId: lessonId))
            }
        }
        completedLessons = completed
        dayCourses = snap.dayCourses
        scheduleSave(immediate: true)
        emitChange()
        NotificationCenter.default.post(name: .progressDidChange, object: self)
        // Список уроков / профиль: полный ребилд агрегатов (userInfo без courseId → LessonsManager.refreshFromProgressManager).
        NotificationCenter.default.post(name: .stepProgressDidChange, object: self, userInfo: nil)
    }

    // MARK: Persistence
    /// When immediate: true, save synchronously so progress is persisted before app can background (same as FavoriteManager).
    private func scheduleSave(immediate: Bool = false) {
        saveWorkItem?.cancel()
        if immediate {
            save()
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func save() {
        let store = PMStore(learned: learnedSteps, started: startedLessons, completed: completedLessons, dayCourses: dayCourses)
        do {
            let data = try JSONEncoder().encode(store)
            if let existing = defaults.data(forKey: storeKey), existing == data {
                return // no-op
            }
            defaults.set(data, forKey: storeKey)
        } catch {
            // swallow in production; optionally log
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storeKey) else { return }
        do {
            let store = try JSONDecoder().decode(PMStore.self, from: data)
            var learned: [LessonKey: Set<Int>] = [:]
            store.learned.forEach { key, set in
                let canon = LessonKey(courseId: canonicalize(key.courseId), lessonId: canonicalize(key.lessonId))
                if var existing = learned[canon] {
                    existing.formUnion(set)
                    learned[canon] = existing
                } else {
                    learned[canon] = set
                }
            }
            self.learnedSteps = learned
            self.startedLessons = Set(store.started.map { LessonKey(courseId: canonicalize($0.courseId), lessonId: canonicalize($0.lessonId)) })
            self.completedLessons = Set(store.completed.map { LessonKey(courseId: canonicalize($0.courseId), lessonId: canonicalize($0.lessonId)) })
            self.dayCourses = store.dayCourses
            // publishedState не пересобираем в load() — избегаем обращения к UserSession.shared до конца инициализации синглтонов.
        } catch {
            // corrupted -> start clean
            self.learnedSteps = [:]
            self.startedLessons = []
            self.completedLessons = []
            self.dayCourses = [:]
        }
    }
    // MARK: - Aggregated Helpers
    public func lessonProgressSlots(courseId: String, lessons: [(id: String, totalSteps: Int)]) -> [Double] {
        return lessonProgressSlots(courseId: courseId, meta: lessons.map { (id: $0.id, totalSteps: $0.totalSteps, tipIndexes: [], excludedIndexes: []) })
    }

    public func lessonProgressSlots(
        courseId: String,
        meta: [(id: String, totalSteps: Int, tipIndexes: Set<Int>, excludedIndexes: Set<Int>)]
    ) -> [Double] {
        meta.map { l in
            lessonProgressFraction(
                courseId: courseId,
                lessonId: l.id,
                totalSteps: l.totalSteps,
                tipIndexes: l.tipIndexes,
                excludedIndexes: l.excludedIndexes
            )
        }
    }

    // External provider for lesson meta (id, totals, tips, excluded) to avoid hard-coupling
    public var lessonMetaProvider: ((String) -> [(id: String, totalSteps: Int, tipIndexes: Set<Int>, excludedIndexes: Set<Int>)])?

    /// Fractions for mini-progress header per lesson in a course (0…1 each).
    public func lessonFractions(for courseId: String) -> [Double] {
        if let meta = lessonMetaProvider?(courseId) {
            return lessonProgressSlots(courseId: courseId, meta: meta)
        }
        return []
    }
}

public extension ProgressManager {
    // MARK: - Public unified accessor
    /// Unified progress accessor.
    /// - Parameters:
    ///   - courseId: Course identifier (raw or canonical; will be normalized internally).
    ///   - lessonId: Optional lesson identifier. If nil, returns averaged course progress.
    ///   - totalSteps: Total steps for the lesson (excluding tips/excluded). If 0 and lessonId is provided, returns 0 until meta is supplied.
    /// - Returns: Fraction in [0, 1].
    /// Returns progress fraction in [0, 1]. EPIC 4: all callers can rely on this range.
    func progress(for courseId: String, lessonId: String? = nil, totalSteps: Int = 0) -> Double {
        if let lessonId = lessonId {
            let f = lessonProgressFraction(courseId: courseId, lessonId: lessonId, totalSteps: totalSteps)
            return min(1.0, max(0.0, f))
        } else {
            // Course progress must be consistent everywhere.
            // Use weighted progress by effective step counts (excluding tips/excluded), not a plain average by lessons.
            if let meta = lessonMetaProvider?(courseId), !meta.isEmpty {
                var learnedTotal = 0
                var effectiveTotal = 0
                for l in meta {
                    learnedTotal += learnedEffectiveCount(courseId: courseId, lessonId: l.id)
                    effectiveTotal += totalEffectiveCount(courseId: courseId, lessonId: l.id)
                }
                guard effectiveTotal > 0 else { return 0 }
                return min(1.0, max(0.0, Double(learnedTotal) / Double(effectiveTotal)))
            }

            // Fallback: if no meta is available, use LessonsManager's course percent (already weighted).
            let v = LessonsManager.shared.coursePercent(for: courseId)
            return min(1.0, max(0.0, v))
        }
    }

    /// course ids that had any learning activity on a given day.
    func courseIds(on date: Date, limit: Int = 10) -> [String] {
        guard limit > 0 else { return [] }
        return UserSession.shared.courseIds(on: date, limit: limit)
    }

    func hasCourses(on date: Date) -> Bool {
        !UserSession.shared.courseIds(on: date, limit: 1).isEmpty
    }
}

