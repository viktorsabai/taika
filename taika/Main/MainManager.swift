//
//  MainManager.swift
//  taika
//
//  Created by product on 22.10.2025.
//

import Foundation
import SwiftUI

final class MainManager: ObservableObject {
    // Daily Picks payload for MainView → MainDS (pure data; DS draws visuals)
    struct DailyPicksPayload: Equatable {
        struct Ref: Equatable {
            let courseId: String
            let lessonId: String
            let index: Int

            static let proPlaceholder = Ref(courseId: "__pro__", lessonId: "__pro__", index: -1)
        }
        let refs: [Ref]
        let items: [SDStepItem]              // visual items for SDStepCarousel
        let courseShort: [String]            // parallel to items
        let lessonShort: [String]            // parallel to items
        let metaTitles: [String]             // e.g. "Разговорный старт • Урок 4"
        let favorites: [Bool]            // mask per item
        static let empty = DailyPicksPayload(refs: [], items: [], courseShort: [], lessonShort: [], metaTitles: [], favorites: [])
    }

// MARK: - AddCourseToDayRequested observer

    struct DailyCoursePicksPayload {
        let courses: [Course]
        static let empty = DailyCoursePicksPayload(courses: [])
    }

    enum CourseCardDisplayStyle: Equatable {
        /// Подборка дня — free discovery, organic lines.
        case discovery
        /// Подборка дня — PRO-витрина (розовый wash).
        case proShowcase
        /// Пройденный курс — закрепление, без PRO-sell chrome.
        case reinforcement
    }

    // Calendar overlay models (MainView uses these for .add(date) and .activity(date) modes)
    struct CourseCardModel: Identifiable, Equatable {
        enum CTA: Equatable {
            case add
            case `continue`
            case reinforce

            var title: String {
                switch self {
                case .add: return "добавить"
                case .continue: return "продолжить"
                case .reinforce: return "закрепить"
                }
            }

            var hint: String {
                switch self {
                case .add: return "тап → добавить в план"
                case .continue: return "тап → открыть курс"
                case .reinforce: return "тап → закрепить курс"
                }
            }

            var idKey: String {
                switch self {
                case .add: return "add"
                case .continue: return "continue"
                case .reinforce: return "reinforce"
                }
            }
        }

        private static func makeId(courseId: String, cta: CTA, displayStyle: CourseCardDisplayStyle) -> String {
            "\(courseId)|\(cta.idKey)|\(displayStyle)"
        }

        let id: String
        let courseId: String
        let title: String
        let subtitle: String
        let categoryChip: String?
        let lessonCount: Int?
        let durationMinutes: Int?
        let learningOutcomes: [String]
        let isPro: Bool
        let displayStyle: CourseCardDisplayStyle
        let reinforcementScore: Int?
        let reinforcementErrorCount: Int

        // Optional progress (0…1). `nil` means we intentionally don't show progress for this scenario.
        let progress: Double?

        // Scenario-specific CTA.
        let cta: CTA

        init(
            courseId: String,
            title: String,
            subtitle: String,
            categoryChip: String? = nil,
            lessonCount: Int? = nil,
            durationMinutes: Int? = nil,
            learningOutcomes: [String] = [],
            isPro: Bool,
            displayStyle: CourseCardDisplayStyle = .discovery,
            reinforcementScore: Int? = nil,
            reinforcementErrorCount: Int = 0,
            progress: Double? = nil,
            cta: CTA
        ) {
            self.id = Self.makeId(courseId: courseId, cta: cta, displayStyle: displayStyle)
            self.courseId = courseId
            self.title = title
            self.subtitle = subtitle
            self.categoryChip = categoryChip
            self.lessonCount = lessonCount
            self.durationMinutes = durationMinutes
            self.learningOutcomes = learningOutcomes
            self.isPro = isPro
            self.displayStyle = displayStyle
            self.reinforcementScore = reinforcementScore
            self.reinforcementErrorCount = reinforcementErrorCount
            self.progress = progress
            self.cta = cta
        }
    }

    @Published var dailyPicks: DailyPicksPayload = .empty
    @Published var dailyCoursePicks: DailyCoursePicksPayload = .empty
    /// Prepared UI models for "ПОДБОРКА ДНЯ" course reel (stable per day).
    @Published var dailyCourseCards: [CourseCardModel] = []
    /// Пройденные курсы для ряда «Закрепление» на Main (без дневного кэша).
    @Published var reinforcementCourseCards: [CourseCardModel] = []
    @Published var dailyFavMask: [Bool] = []
    @Published var resumeItems: [MainBannerItem] = []
    @Published var weekSummary: [DaySummary] = []   // 7 items, Sun..Sat (or locale order)

    // Cache daily picks list for the current day — keeps learned cards in today's rotation
    private var dailyKeysCache: [(ref: DailyPicksPayload.Ref, item: StepItem)] = []
    private var dailyKeysCacheCount: Int = 0
    private var dailyCourseCache: [Course] = []
    private var dailyCourseCacheCount: Int = 0
    /// Snapshot of completed ids when daily cache was built — invalidate when it changes.
    private var dailyCourseCompletedSnapshot: Set<String> = []
    private var dailyCacheDay: Date = MainManager.bangkokCal.startOfDay(for: Date())

    private func invalidateDailyCacheIfDayChanged() {
        let today = Self.bangkokCal.startOfDay(for: Date())
        if today > dailyCacheDay { // new day → drop cache
            dailyKeysCache.removeAll()
            dailyKeysCacheCount = 0
            invalidateDailyCourseCache()
            dailyCacheDay = today
        }
    }

    private func invalidateDailyCourseCache() {
        dailyCourseCache.removeAll()
        dailyCourseCacheCount = 0
        dailyCourseCompletedSnapshot.removeAll()
    }
    private let freeDailyPicksLimit: Int = 5
    private let proDailyPicksLimit: Int = 10

    private let freeDailyCoursePicksLimit: Int = 5
    private let proDailyCoursePicksLimit: Int = 10

    @MainActor
    private func hasExtraDailyPicks() -> Bool {
        // Feature-gating (more flexible than raw isPro).
        ProManager.shared.can(.dailyPicksExtra)
    }

    @MainActor
    private func effectiveDailyPicksLimit() -> Int {
        hasExtraDailyPicks() ? proDailyPicksLimit : freeDailyPicksLimit
    }

    @MainActor
    private func effectiveDailyCoursePicksLimit() -> Int {
        hasExtraDailyPicks() ? proDailyCoursePicksLimit : freeDailyCoursePicksLimit
    }
    
    static let shared = MainManager()
    
    private var resetObserver: NSObjectProtocol?
    private var favObserver: NSObjectProtocol?
    private var progObserver: NSObjectProtocol?
    private var lessonsObserver: NSObjectProtocol?
    private var coursePlanObserver: NSObjectProtocol?
    private var removeCourseObserver: NSObjectProtocol?
    private var addCourseObserver: NSObjectProtocol?
    private var activityObserver: NSObjectProtocol?

    // Cached formatters and calendar helpers
    // MARK: - Thailand canonical calendar (Asia/Bangkok)
    private static let bangkokTZ: TimeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current

    private static var bangkokCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = bangkokTZ
        return cal
    }()
    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.timeZone = bangkokTZ
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let uiDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.timeZone = bangkokTZ
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private var weekSummaryReloadWork: DispatchWorkItem?
    private var resumeReloadWork: DispatchWorkItem?

    private func scheduleWeekSummaryReload() {
        weekSummaryReloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.rebuildWeekSummary()
            }
        }
        weekSummaryReloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    private func scheduleResumeReload() {
        resumeReloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.refresh()
            }
        }
        resumeReloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private init() {
        resetObserver = NotificationCenter.default.addObserver(
            forName: .init("AppResetAll"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh() }
            self.scheduleWeekSummaryReload()
        }
        favObserver = NotificationCenter.default.addObserver(
            forName: .init("FavoritesDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.reloadDailyPicks() }
            self.scheduleWeekSummaryReload()
        }
        progObserver = NotificationCenter.default.addObserver(
            forName: .init("ProgressDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.invalidateDailyCacheIfDayChanged()
            self.scheduleDailyPicksReload()
            self.scheduleWeekSummaryReload()
            self.scheduleResumeReload()
        }
        lessonsObserver = NotificationCenter.default.addObserver(
            forName: .init("LessonsDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.scheduleWeekSummaryReload()
            self.scheduleResumeReload()
        }
        coursePlanObserver = NotificationCenter.default.addObserver(
            forName: .init("CoursePlanDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if let day = note.userInfo?["day"] as? Date {
                Task { @MainActor in
                    await self.applyPlannedQuickUpdate(for: day)
                }
            }
            Task { @MainActor in
                await self.refresh()
            }
            self.scheduleWeekSummaryReload()
        }
        addCourseObserver = NotificationCenter.default.addObserver(
            forName: .init("AddCourseToDayRequested"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard self != nil else { return }
            guard let courseId = note.userInfo?["courseId"] as? String else { return }
            let day = (note.userInfo?["day"] as? Date) ?? Self.bangkokCal.startOfDay(for: Date())
            let dayStart = Self.bangkokCal.startOfDay(for: day)

            Task { @MainActor in
                let isProUser = ProManager.shared.isPro
                if isProUser {
                    UserSession.shared.togglePlannedCourse(courseId: courseId, on: dayStart)
                } else {
                    // free-tier: do not overwrite an existing planned course; keep the first one.
                    let existing = UserSession.shared.plannedCourseIds(on: dayStart)
                    if existing.isEmpty {
                        UserSession.shared.setPlannedCourses(on: dayStart, courseIds: Set([courseId]))
                    } else {
                        // if the user taps the same course again, treat it as no-op (UI toggling is handled elsewhere)
                        if existing.contains(courseId) {
                            // no-op
                        } else {
                            // keep existing selection (prevents "rewrite" effect)
                            // optional upsell can be added later without changing storage semantics
                        }
                    }
                }

                NotificationCenter.default.post(
                    name: .init("CoursePlanDidChange"),
                    object: nil,
                    userInfo: ["day": dayStart]
                )
                UserSession.shared.logActivity(.coursePlannedAdded, courseId: courseId, ts: dayStart)
            }
        }
        removeCourseObserver = NotificationCenter.default.addObserver(
            forName: .init("RemoveCourseFromDayRequested"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard self != nil else { return }
            guard let courseId = note.userInfo?["courseId"] as? String else { return }
            let day = (note.userInfo?["day"] as? Date) ?? Self.bangkokCal.startOfDay(for: Date())
            let dayStart = Self.bangkokCal.startOfDay(for: day)
            Task { @MainActor in
                UserSession.shared.removePlannedCourse(courseId: courseId, on: dayStart)
                NotificationCenter.default.post(
                    name: .init("CoursePlanDidChange"),
                    object: nil,
                    userInfo: ["day": dayStart]
                )
                UserSession.shared.logActivity(.coursePlannedRemoved, courseId: courseId, ts: dayStart)
            }
        }
        activityObserver = NotificationCenter.default.addObserver(
            forName: .usActivityLogDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleResumeReload()
        }
    }

    deinit {
        if let token = resetObserver { NotificationCenter.default.removeObserver(token) }
        if let token = favObserver { NotificationCenter.default.removeObserver(token) }
        if let token = progObserver { NotificationCenter.default.removeObserver(token) }
        if let token = lessonsObserver { NotificationCenter.default.removeObserver(token) }
        if let token = coursePlanObserver { NotificationCenter.default.removeObserver(token) }
        if let token = removeCourseObserver { NotificationCenter.default.removeObserver(token) }
        if let token = addCourseObserver { NotificationCenter.default.removeObserver(token) }
        if let token = activityObserver { NotificationCenter.default.removeObserver(token) }
        dailyReloadWork?.cancel()
        weekSummaryReloadWork?.cancel()
        resumeReloadWork?.cancel()
    }
    
    private var cacheInvalidated = false

    private var dailyReloadWork: DispatchWorkItem?

    private func scheduleDailyPicksReload() {
        dailyReloadWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.reloadDailyPicks()
                await self.reloadDailyCoursePicks()
                await self.reloadReinforcementCourseCards()
            }
        }
        dailyReloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30, execute: work)
    }

    @MainActor
    private func resolvedResumeLessonId(courseId: String, preferredLessonId: String?) -> String? {
        let lessons = LessonsData.shared.lessons(for: courseId)
        guard !lessons.isEmpty else { return nil }

        struct LessonProgress {
            let lessonId: String
            let progress: Double
            let order: Int
        }

        let progressByLesson: [LessonProgress] = lessons.map { lesson in
            LessonProgress(
                lessonId: lesson.lessonID,
                progress: LessonsManager.shared.lessonPercent(courseId: courseId, lessonId: lesson.lessonID),
                order: lesson.order
            )
        }

        let inProgress = progressByLesson
            .filter { $0.progress > 0.0001 && $0.progress < 0.9999 }
            .sorted {
                if abs($0.progress - $1.progress) > 0.0001 { return $0.progress > $1.progress }
                return $0.order < $1.order
            }
        if let preferredLessonId,
           inProgress.contains(where: { $0.lessonId == preferredLessonId }) {
            return preferredLessonId
        }
        if let firstInProgress = inProgress.first {
            return firstInProgress.lessonId
        }

        let completed = progressByLesson
            .filter { $0.progress >= 0.9999 }
            .sorted { $0.order < $1.order }
        if let lastCompleted = completed.last {
            if let next = progressByLesson.first(where: { $0.order == lastCompleted.order + 1 }) {
                return next.lessonId
            }
            // Course is fully completed — don't keep it in "Continue".
            return nil
        }

        if let preferredLessonId,
           progressByLesson.contains(where: { $0.lessonId == preferredLessonId }) {
            return preferredLessonId
        }
        return progressByLesson.sorted { $0.order < $1.order }.first?.lessonId
    }
    
    @MainActor
    func refresh() async {
        // Derive recent pairs from UserSession snapshot (no recentActivity API)
        let snap = UserSession.shared.snapshot
        let nav = CourseNavigator.shared
        let todayStart = Self.bangkokCal.startOfDay(for: Date())
        var recent: [(courseId: String, lessonId: String?)] = []

        // 1) derive a real lesson target per course (in-progress first; if completed, next lesson)
        for (cid, lid) in snap.lastLessonByCourse {
            recent.append((courseId: cid, lessonId: resolvedResumeLessonId(courseId: cid, preferredLessonId: lid)))
        }
        // 2) fallback: started courses if nothing else
        if recent.isEmpty {
            for cid in snap.startedCourses {
                recent.append((courseId: cid, lessonId: resolvedResumeLessonId(courseId: cid, preferredLessonId: nil)))
            }
        }

        // Stable priority: entries with lessonId first, then by courseId
        recent.sort { lhs, rhs in
            if (lhs.lessonId != nil) != (rhs.lessonId != nil) { return lhs.lessonId != nil }
            return lhs.courseId < rhs.courseId
        }

        let plannedIds = UserSession.shared.plannedCourseIds(on: todayStart)
        var ordered: [(courseId: String, lessonId: String?)] = []
        var usedCourseIds = Set<String>()

        func appendResume(courseId cid: String, preferredLessonId: String?) {
            guard !cid.isEmpty, !usedCourseIds.contains(cid) else { return }
            let lid = resolvedResumeLessonId(courseId: cid, preferredLessonId: preferredLessonId)
            ordered.append((courseId: cid, lessonId: lid))
            usedCourseIds.insert(cid)
        }

        // Последний открытый курс — всегда первый в «Продолжить».
        if let lastCid = snap.lastCourseId?.trimmingCharacters(in: .whitespacesAndNewlines), !lastCid.isEmpty {
            appendResume(courseId: lastCid, preferredLessonId: snap.lastLessonByCourse[lastCid])
        }

        // План на сегодня (без дублей).
        for cid in plannedIds {
            appendResume(courseId: cid, preferredLessonId: snap.lastLessonByCourse[cid])
        }

        // Недавние курсы (до 4 слотов).
        let pickLessons = Array(recent.filter { $0.lessonId != nil && !usedCourseIds.contains($0.courseId) }.prefix(2))
        let pickCourses = Array(recent.filter { $0.lessonId == nil && !usedCourseIds.contains($0.courseId) }.prefix(2))
        func appendIfAny(_ item: (courseId: String, lessonId: String?)?) {
            guard let it = item else { return }
            appendResume(courseId: it.courseId, preferredLessonId: it.lessonId)
        }
        appendIfAny(pickCourses.indices.contains(0) ? pickCourses[0] : nil)
        appendIfAny(pickLessons.indices.contains(0) ? pickLessons[0] : nil)
        appendIfAny(pickCourses.indices.contains(1) ? pickCourses[1] : nil)
        appendIfAny(pickLessons.indices.contains(1) ? pickLessons[1] : nil)

        if ordered.count < 4 {
            for pair in recent where !usedCourseIds.contains(pair.courseId) {
                appendResume(courseId: pair.courseId, preferredLessonId: pair.lessonId)
                if ordered.count == 4 { break }
            }
        }

        // Legacy block removed — ordered built above.
        let plannedSet = Set(plannedIds)
        _ = plannedSet

        // Map to banner items — titles via CourseNavigator; real progress from ProgressManager/LessonsManager
        let now = Date()
        var mapped: [(id: String, date: Date, title: String, kind: MainBannerItem.Kind, progress: Double, lessonMinutes: Int?)] = []
        for pair in ordered {
            let id = pair.lessonId != nil ? "\(pair.courseId):\(pair.lessonId!)" : pair.courseId
            let title: String = {
                if let lid = pair.lessonId {
                    return nav.lessonTitle(for: lid)
                } else {
                    return nav.courseTitle(for: pair.courseId)
                }
            }()
            let kind: MainBannerItem.Kind = (pair.lessonId != nil) ? .lesson : .course
            let progress: Double
            let lessonMinutes: Int?
            if pair.lessonId == nil {
                // average course progress from ProgressManager
                progress = ProgressManager.shared.progress(for: pair.courseId, lessonId: nil)
                lessonMinutes = nil
            } else if let lid = pair.lessonId {
                // use LessonsManager helper (0…1)
                progress = LessonsManager.shared.lessonPercent(courseId: pair.courseId, lessonId: lid)
                lessonMinutes = LessonsData.shared.lesson(courseID: pair.courseId, lessonID: lid)?.durationMinutes
            } else {
                progress = 0.0
                lessonMinutes = nil
            }
            let cleanedTitle: String = {
                let raw = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else { return kind == .lesson ? "урок" : "курс" }
                let lowered = raw.lowercased()
                let looksIdentifier = raw == pair.courseId
                    || lowered == "user dict"
                    || lowered.contains("user_dict")
                    || lowered.contains("user-dict")
                if looksIdentifier {
                    return kind == .lesson ? "урок" : "курс"
                }
                return raw
            }()
            mapped.append((id: id, date: now, title: cleanedTitle, kind: kind, progress: progress, lessonMinutes: lessonMinutes))
        }

        // Deduplicate by id (just in case) and keep order
        var seen = Set<String>()
        let unique = mapped.filter { item in
            if seen.contains(item.id) { return false }
            seen.insert(item.id)
            return true
        }

        let bannerItems = unique.map {
            MainBannerItem(
                id: $0.id,
                title: $0.title,
                kind: $0.kind,
                progress: $0.progress,
                lessonMinutes: $0.lessonMinutes
            )
        }

        // Skip publishing if nothing changed to avoid notification loops
        if bannerItems == self.resumeItems {
            return
        }

        self.resumeItems = bannerItems
        await rebuildWeekSummary()
    }
    
}

struct MainBannerItem: Identifiable, Equatable {
    let id: String
    let title: String
    let kind: Kind
    let progress: Double
    let lessonMinutes: Int?

    init(id: String, title: String, kind: Kind, progress: Double, lessonMinutes: Int? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.progress = progress
        self.lessonMinutes = lessonMinutes
    }
    
    enum Kind: Equatable {
        case course
        case lesson
    }
}

// MARK: - Weekly day summaries (calendar mini-cards)
struct DaySummary: Identifiable, Equatable {
    let id: String            // "YYYY-MM-DD"
    let date: Date
    let courses: [String]     // up to 2 last active courses
    let totalCourses: Int     // total courses interacted with that day (or planned count for planned-only)
    let progress: Double      // aggregated progress for that day

    // explicit scenario flag for CardDS (planned-only day, including missed plan in the past)
    let isPlanned: Bool
}


// MARK: - Daily Picks reload
extension MainManager {
    @MainActor
    func reloadDailyPicks() async {
        let limit = effectiveDailyPicksLimit()
        await reloadDailyPicks(count: limit)
    }

    @MainActor
    private func courseProgressFraction(courseId: String) async -> Double {
        // single source of truth: ProgressManager
        let raw = ProgressManager.shared.progress(for: courseId, lessonId: nil)
        let clamped = min(max(raw, 0.0), 1.0)

        // if course was started but progress is still ~0, show minimal visible progress
        let snap = UserSession.shared.snapshot
        let isStarted =
            snap.startedCourses.contains(courseId) ||
            snap.lastLessonByCourse[courseId] != nil

        if isStarted && clamped <= 0.0001 {
            return 0.02
        }

        return clamped
    }
    @MainActor
    private func shortCourseName(_ courseId: String) async -> String {
        let title = LessonsManager.shared.courseTitle(for: courseId)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return title.isEmpty ? courseId : title
    }

    @MainActor
    private func shortCourseSubtitle(_ courseId: String, course: Course) -> String {
        // Prefer a real subtitle from the Course model if present; otherwise fall back to an empty string.
        let m = Mirror(reflecting: course)
        for c in m.children {
            guard let label = c.label?.lowercased() else { continue }
            if label == "subtitle" || label.contains("subtitle") {
                if let s = c.value as? String {
                    return s.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            // sometimes stored as description/summary
            if label == "summary" || label.contains("summary") || label == "desc" || label.contains("description") {
                if let s = c.value as? String {
                    return s.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return ""
    }

    @MainActor
    private func courseOutcomePreview(_ courseId: String) -> String? {
        // Prefer outcomes from lessons.json (LessonsData) for course previews.
        // Rule: take the first non-empty outcome from the first lesson that has outcomes.
        let m = LessonsData.shared
        // Try to access lessons for course (expected API in LessonsData).
        let lessons = m.lessons(for: courseId)
        for lesson in lessons {
            let outcomes = lesson.outcomes
            if let first = outcomes.first {
                let s = first.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { return s }
            }
        }
        return nil
    }

    // Best-effort PRO flag resolver without hard dependencies on Course model fields.
    private func resolveIsProCourse(_ course: Course) -> Bool {
        let m = Mirror(reflecting: course)
        for c in m.children {
            guard let label = c.label?.lowercased() else { continue }
            if label == "ispro" || label == "pro" || label.contains("is_pro") || label.contains("isprocourse") {
                if let b = c.value as? Bool { return b }
                if let s = c.value as? String { return s.lowercased().contains("pro") }
                if let i = c.value as? Int { return i != 0 }
            }
            if label == "tier" || label.contains("tier") {
                if let s = c.value as? String { return s.lowercased().contains("pro") }
                if let i = c.value as? Int { return i > 0 }
            }
        }
        return false
    }

    /// Course meta resolver from typed `Course` fields.
    private func resolveCourseMeta(_ course: Course) -> (lessonCount: Int?, durationMinutes: Int?, outcomes: [String]) {
        let lessonCount = course.lessonCount > 0 ? course.lessonCount : nil
        let durationMinutes = course.durationMinutes > 0 ? course.durationMinutes : nil
        let outcomes = course.learningOutcomes
            .map { item -> String in
                let t = item.type.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return "" }
                return t
            }
            .filter { !$0.isEmpty }
        return (lessonCount, durationMinutes, outcomes)
    }

    // Best-effort category resolver (chip text) without hard dependencies on Course model fields.
    private func resolveCourseCategoryChip(_ course: Course) -> String? {
        let m = Mirror(reflecting: course)
        for c in m.children {
            guard let label = c.label?.lowercased() else { continue }

            // common variants: category, level, kind, section
            if label == "category" || label.contains("category") || label == "level" || label.contains("level") || label == "kind" || label.contains("kind") || label == "section" || label.contains("section") {
                if let s = c.value as? String {
                    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }
            }

            // sometimes category comes as tags: [String]
            if label == "tags" || label.contains("tags") {
                if let arr = c.value as? [String], let first = arr.first {
                    let t = first.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }
            }
        }
        return nil
    }

    /// Source for `.add(date)` overlay: free courses first, then a randomized PRO showcase (disabled for non-PRO users).
    @MainActor
    func availableCoursesForAdd(isProUser: Bool, proShowcaseLimit: Int = 8) async -> [CourseCardModel] {
        let all = CourseData.shared.featuredCourses
        guard !all.isEmpty else { return [] }

        // Map → models (title falls back to id)
        let snap = UserSession.shared.snapshot
        let startedIds = snap.startedCourses

        var mapped: [CourseCardModel] = []
        mapped.reserveCapacity(all.count)
        for c in all {
            let cid = c.id
            let title = await shortCourseName(cid)
            let subtitle = courseOutcomePreview(cid) ?? shortCourseSubtitle(cid, course: c)
            let isProCourse = resolveIsProCourse(c)
            let meta = resolveCourseMeta(c)
            let cta: CourseCardModel.CTA = startedIds.contains(cid) ? .continue : .add
            mapped.append(CourseCardModel(
                courseId: cid,
                title: title,
                subtitle: subtitle,
                categoryChip: resolveCourseCategoryChip(c),
                lessonCount: meta.lessonCount,
                durationMinutes: meta.durationMinutes,
                learningOutcomes: meta.outcomes,
                isPro: isProCourse,
                progress: nil,
                cta: cta
            ))
        }

        let free = mapped.filter { !$0.isPro }
        let pro  = mapped.filter { $0.isPro }

        // For non-PRO users: show only a subset of PRO courses as a showcase (disabled in UI).
        // For PRO users: show all PRO courses.
        let proPart: [CourseCardModel]
        if isProUser {
            proPart = pro
        } else {
            proPart = Array(pro.shuffled().prefix(max(0, proShowcaseLimit)))
        }

        // final order: free first, then PRO
        return free + proPart
    }

    /// Source for `.activity(date)` overlay: courses active on that day, prepared for CardDS.
    /// View must not filter/compute; it only renders the returned models.
    @MainActor
    func activeCoursesForDay(_ date: Date, limit: Int = 8) async -> [CourseCardModel] {
        let resolved = await dayState(for: date)

        var ids: [String] = []
        switch resolved.state {
        case .active:
            ids = resolved.activeIds
        case .plannedOnly:
            ids = resolved.plannedIds
        case .empty:
            ids = []
        }

        if ids.count > limit { ids = Array(ids.prefix(limit)) }
        guard !ids.isEmpty else { return [] }

        // Best-effort lookup for subtitles / PRO flags from featured courses.
        let featured = CourseData.shared.featuredCourses
        func featuredCourse(by id: String) -> Course? {
            featured.first(where: { $0.id == id })
        }

        var out: [CourseCardModel] = []
        out.reserveCapacity(ids.count)

        for cid in ids {
            let title = await shortCourseName(cid)
            let subtitle: String = {
                if let outcome = courseOutcomePreview(cid) {
                    return outcome
                }
                if let c = featuredCourse(by: cid) {
                    let s = shortCourseSubtitle(cid, course: c)
                    return s.isEmpty ? CourseCardModel.CTA.continue.hint : s
                }
                return CourseCardModel.CTA.continue.hint
            }()

            let isProCourse: Bool = {
                if let c = featuredCourse(by: cid) { return resolveIsProCourse(c) }
                return false
            }()

            let categoryChip: String? = {
                if let c = featuredCourse(by: cid) { return resolveCourseCategoryChip(c) }
                return nil
            }()
            let meta: (Int?, Int?, [String]) = {
                if let c = featuredCourse(by: cid) {
                    let m = resolveCourseMeta(c)
                    return (m.lessonCount, m.durationMinutes, m.outcomes)
                }
                return (nil, nil, [])
            }()

            let p = await courseProgressFraction(courseId: cid)

            out.append(
                CourseCardModel(
                    courseId: cid,
                    title: title,
                    subtitle: subtitle,
                    categoryChip: categoryChip,
                    lessonCount: meta.0,
                    durationMinutes: meta.1,
                    learningOutcomes: meta.2,
                    isPro: isProCourse,
                    progress: p,
                    cta: .continue
                )
            )
        }

        return out
    }

    /// public resolver for UI: returns course title (fallbacks to id)
    @MainActor
    func courseTitle(for courseId: String) async -> String {
        await shortCourseName(courseId)
    }

    @MainActor
    private func shortLessonName(_ lessonId: String) -> String {
        let title = LessonsManager.shared.lessonTitle(for: lessonId)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !title.isEmpty { return title }
        // fallback: parse "course_b_1_l4" → "урок 4"
        if let r = lessonId.split(separator: "_").last, r.first == "l", let n = Int(r.dropFirst()) {
            return "урок \(n)"
        }
        return lessonId
    }
    /// Priority step refs for Smart Discovery (empty = current behavior). Reserved for future use.
    @MainActor
    func reloadDailyPicks(count: Int = 5, priorityStepRefs: [StepData.StepRef] = []) async {
        // Free всегда ≤5 реальных карточек + PRO-заглушки; PRO — до proDailyPicksLimit.
        // Игнорируем «раздутый» count от UI/кэша после смены entitlement.
        let cappedCount = hasExtraDailyPicks()
            ? min(max(1, count), proDailyPicksLimit)
            : freeDailyPicksLimit

        // keep today's picks stable: rebuild only when cache is empty or day changed or count changes
        invalidateDailyCacheIfDayChanged()
        if dailyKeysCache.isEmpty || dailyKeysCacheCount != cappedCount {
            let keys = StepData.shared.dailyPicksKeys(count: cappedCount, priorityStepRefs: priorityStepRefs)
            dailyKeysCache = keys.map { k in
                let r = DailyPicksPayload.Ref(courseId: k.courseId, lessonId: k.lessonId, index: k.index)
                return (ref: r, item: k.item)
            }
            dailyKeysCacheCount = cappedCount
        }

        var refs: [DailyPicksPayload.Ref] = []
        var visuals: [SDStepItem] = []
        var courseShort: [String] = []
        var lessonShort: [String] = []
        var metaTitles: [String] = []

        for pair in dailyKeysCache {
            let r = pair.ref
            refs.append(r)
            visuals.append(sd(from: pair.item))

            let finalCourse = await shortCourseName(r.courseId)
            let finalLesson = shortLessonName(r.lessonId)
            courseShort.append(finalCourse)
            lessonShort.append(finalLesson)
            metaTitles.append("\(finalCourse) • \(finalLesson)")
        }

        // --- PRO gates (visual-only): add before first and after last for Daily Picks.
        // These are not real learning items and must not affect favorites/progress ids.
        let hasExtra = hasExtraDailyPicks()
        if !visuals.isEmpty && !hasExtra {
            let before = SDStepItem(
                kind: .word,
                titleRU: "ещё 5 карточек",
                subtitleTH: "расширь разминку с Taika+",
                phonetic: "",
                isPro: true
            )
            let after = SDStepItem(
                kind: .word,
                titleRU: "полная подборка",
                subtitleTH: "до 10 карточек каждый день",
                phonetic: "",
                isPro: true
            )

            refs.insert(.proPlaceholder, at: 0)
            visuals.insert(before, at: 0)
            courseShort.insert("", at: 0)
            lessonShort.insert("", at: 0)
            metaTitles.insert("", at: 0)

            refs.append(.proPlaceholder)
            visuals.append(after)
            courseShort.append("")
            lessonShort.append("")
            metaTitles.append("")
        }

        // sync favorite mask with current daily items order (real FavoriteManager state)
        let fm = FavoriteManager.shared
        var favMask: [Bool] = []
        favMask.reserveCapacity(refs.count)
        for (i, r) in refs.enumerated() {
            if i < visuals.count, visuals[i].isPro {
                favMask.append(false)
                continue
            }
            let isTip = i < visuals.count && visuals[i].kind == .tip
            let id = isTip
                ? fm.idForHack(courseId: r.courseId, lessonId: r.lessonId, index: r.index)
                : fm.idForStep(courseId: r.courseId, lessonId: r.lessonId, index: r.index)
            favMask.append(fm.contains(stepId: id))
        }
        let newPayload = DailyPicksPayload(refs: refs, items: visuals, courseShort: courseShort, lessonShort: lessonShort, metaTitles: metaTitles, favorites: favMask)
        if newPayload == self.dailyPicks { return }
        self.dailyPicks = newPayload
        self.dailyFavMask = favMask

        self.cacheInvalidated = false

        // No per-refresh console log here: daily picks can refresh frequently in normal app flow.
    }

    private func sd(from item: StepItem) -> SDStepItem {
        let f = StepData.shared.face(for: item)
        let kind: SDStepItem.Kind = {
            switch f.kind {
            case .word:   return .word
            case .phrase: return .phrase
            case .casual: return .casual
            case .tip:    return .tip
            case .dialog: return .phrase // dialogs не идут в daily, но визуально безопасный фолбэк
            }
        }()
        return SDStepItem(
            kind: kind,
            titleRU: f.titleRU,
            subtitleTH: f.subtitleTH,
            phonetic: f.phonetic
        )
    }
}

// MARK: - Week Summary (last 7 days)
extension MainManager {
    enum DayState: Equatable {
        case empty
        case plannedOnly
        case active
    }

    /// single source of truth for calendar day scenario (active/planned/empty)
    @MainActor
    func dayState(for date: Date) async -> (state: DayState, dayStart: Date, activeIds: [String], plannedIds: [String]) {
        let cal = Self.bangkokCal
        let dayStart = cal.startOfDay(for: date)

        // activity ids (recorded learning for the day)
        let activeIds = await courseIds(for: dayStart, limit: Int.max)

        // planned ids (explicit planning)
        let plannedIds = UserSession.shared.plannedCourseIds(on: dayStart)


        if !activeIds.isEmpty { return (.active, dayStart, activeIds, plannedIds) }
        if !plannedIds.isEmpty { return (.plannedOnly, dayStart, [], plannedIds) }
        return (.empty, dayStart, [], [])
    }
    /// Public entry to rebuild summaries for the last 7 days.
    @MainActor
    func rebuildWeekSummary(reference: Date = Date()) async {
        let days = last7Days(endingAt: reference)
        var out: [DaySummary] = []
        out.reserveCapacity(days.count)

        for day in days {
            let resolved = await dayState(for: day)
            let id = isoDayId(resolved.dayStart)

            switch resolved.state {
            case .active:
                let courses = await courseTitlesFromIds(resolved.activeIds, limit: 2)
                let progress = await dailyProgressFromActiveIds(resolved.activeIds)
                out.append(DaySummary(
                    id: id,
                    date: resolved.dayStart,
                    courses: courses,
                    totalCourses: resolved.activeIds.count,
                    progress: progress,
                    isPlanned: false
                ))

            case .plannedOnly:
                let titles = await courseTitlesFromIds(resolved.plannedIds, limit: 2)
                out.append(DaySummary(
                    id: id,
                    date: resolved.dayStart,
                    courses: titles,
                    totalCourses: resolved.plannedIds.count,
                    progress: 0.0,
                    isPlanned: true
                ))

            case .empty:
                out.append(DaySummary(
                    id: id,
                    date: resolved.dayStart,
                    courses: [],
                    totalCourses: 0,
                    progress: 0.0,
                    isPlanned: false
                ))
            }
        }

        // Keep order as returned by last7Days (oldest...newest) — UI may center today's card.
        if out != self.weekSummary {
            self.weekSummary = out
        }
    }
    @MainActor
    private func courseTitlesFromIds(_ ids: [String], limit: Int) async -> [String] {
        guard limit > 0 else { return [] }
        guard !ids.isEmpty else { return [] }
        var out: [String] = []
        out.reserveCapacity(min(ids.count, limit))
        for cid in ids {
            out.append(await shortCourseName(cid))
            if out.count == limit { break }
        }
        return out
    }

    @MainActor
    private func applyPlannedQuickUpdate(for dayStart: Date) async {
        let d = Self.bangkokCal.startOfDay(for: dayStart)
        let id = isoDayId(d)
        // If weekSummary hasn't been built yet (e.g. first entry without refresh),
        // build an empty 7-day scaffold so the quick update can apply immediately.
        if weekSummary.isEmpty {
            let days = last7Days(endingAt: Date())
            var scaffold: [DaySummary] = []
            scaffold.reserveCapacity(days.count)
            for day in days {
                let dayStart = Self.bangkokCal.startOfDay(for: day)
                scaffold.append(DaySummary(
                    id: isoDayId(dayStart),
                    date: dayStart,
                    courses: [],
                    totalCourses: 0,
                    progress: 0.0,
                    isPlanned: false
                ))
            }
            weekSummary = scaffold
        }
        guard let idx = weekSummary.firstIndex(where: { isSameCalendarDay($0.date, d) }) else { return }

        // If there is real activity already (progress > tiny), keep it (full rebuild will refresh later).
        if weekSummary[idx].progress > 0.0001 { return }

        let plannedIds = UserSession.shared.plannedCourseIds(on: d)

        var copy = weekSummary
        if plannedIds.isEmpty {
            copy[idx] = DaySummary(id: id, date: d, courses: [], totalCourses: 0, progress: 0.0, isPlanned: false)
            if copy != weekSummary { weekSummary = copy }
            return
        }

        let titles = Task { await courseTitlesFromIds(plannedIds, limit: 2) }
        let resolvedTitles = await titles.value
        copy[idx] = DaySummary(
            id: id,
            date: d,
            courses: resolvedTitles,
            totalCourses: plannedIds.count,
            progress: 0.0,
            isPlanned: true
        )
        if copy != weekSummary { weekSummary = copy }
    }

    @MainActor
    private func dailyProgressFromActiveIds(_ ids: [String]) async -> Double {
        guard !ids.isEmpty else { return 0.0 }
        var sum: Double = 0
        var count: Int = 0
        for cid in ids {
            let p = await courseProgressFraction(courseId: cid)
            sum += p
            count += 1
        }
        guard count > 0 else { return 0.0 }
        let avg = sum / Double(count)
        let clamped = min(max(avg, 0.0), 1.0)
        // If there is explicit activity ids for the day but progress is ~0, keep a tiny visible signal.
        if clamped <= 0.0001 { return 0.02 }
        return clamped
    }

    /// adapter for CardDS: provide compact counters for a given date
    @MainActor
    func daySummary(for date: Date) -> CardDS_DaySummary? {
        // prefer the already-built weekSummary (cheap lookup by day)
        if let s = weekSummary.first(where: { isSameCalendarDay($0.date, date) }) {
            let id = UserSession.shared.dayKey(for: s.date)
            let events = UserSession.shared.snapshot.activityLog[id] ?? []
            let learned = events.filter { $0.kind == USActivityEventKind.stepLearned }.count
            let favs = events.filter { $0.kind == USActivityEventKind.favoriteAdded }.count
            let audio = 0

            // Decide overlay mode by calendar content:
            // - active day: there are active courses (weekSummary.progress has a tiny visible minimum) → return non-nil
            // - planned-only day: courses planned but no learning progress (progress ~0) → return nil to open add overlay
            // - empty day: no courses at all → nil
            if s.totalCourses == 0 { return nil }

            let isPlannedOnly = (s.progress <= 0.0001)
            if isPlannedOnly {
                // planned-only days:
                // - today/future: treat as "add" overlay (nil)
                // - past: treat as "missed" (non-nil) so UI opens activity overlay / renders scenario
                let todayStart = Self.bangkokCal.startOfDay(for: Date())
                let isPast = s.date < todayStart
                if s.isPlanned && isPast {
                    return CardDS_DaySummary(learned: learned, favs: favs, audioMinutes: audio)
                }
                return nil
            }

            return CardDS_DaySummary(learned: learned, favs: favs, audioMinutes: audio)
        }

        // fallback: build from UserSession activity log
        let id = UserSession.shared.dayKey(for: date)
        let events = UserSession.shared.snapshot.activityLog[id] ?? []
        let learned = events.filter { $0.kind == USActivityEventKind.stepLearned }.count
        let favs = events.filter { $0.kind == USActivityEventKind.favoriteAdded }.count
        let audio = 0 // no audio aggregation yet

        // If we have no counters at all, treat the day as empty.
        if learned == 0 && favs == 0 && audio == 0 {
            return nil
        }

        // Counters-only fallback is always "activity" (planned-only must be decided via weekSummary above).
        return CardDS_DaySummary(learned: learned, favs: favs, audioMinutes: audio)
    }

    // MARK: helpers (scaffolding)
    private func last7Days(endingAt ref: Date) -> [Date] {
        // canonical UI range: today -3 ... today +3 (Bangkok day)
        let cal = Self.bangkokCal
        let center = cal.startOfDay(for: ref)
        return (-3...3).compactMap { delta in
            cal.date(byAdding: .day, value: delta, to: center)
        }
    }

    private func isoDayId(_ date: Date) -> String {
        Self.isoDayFormatter.string(from: date)
    }

    // Helper to compare if two dates are the same calendar day.
    private func isSameCalendarDay(_ a: Date, _ b: Date) -> Bool {
        let cal = Self.bangkokCal
        return cal.isDate(cal.startOfDay(for: a), inSameDayAs: cal.startOfDay(for: b))
    }

    // The following providers intentionally return zeros/empty data.
    // They will be wired to real sources in subsequent micro-steps (M2+).
    private func dailyLearnedCount(on date: Date) async -> Int {
        0
    }
    private func dailyFavoritesCount(on date: Date) async -> Int {
        0
    }
    private func dailyAudioMinutes(on _: Date) async -> Int { 0 }
    @MainActor
    private func dailyProgress(on date: Date) async -> Double {
        let day = Self.bangkokCal.startOfDay(for: date)
        let ids = await courseIds(for: day, limit: Int.max)
        return await dailyProgressFromActiveIds(ids)
    }

    @MainActor
    private func dailyUniqueItemsCount(on date: Date) async -> Int {
        // Use today's cached daily picks; historical aggregation will be added in later steps.
        if isSameCalendarDay(date, Date()) {
            invalidateDailyCacheIfDayChanged()
            // ensure cache is populated at least once
            if dailyKeysCache.isEmpty {
                let keys = StepData.shared.dailyPicksKeys(count: 5)
                dailyKeysCache = keys.map { k in
                    let r = DailyPicksPayload.Ref(courseId: k.courseId, lessonId: k.lessonId, index: k.index)
                    return (ref: r, item: k.item)
                }
            }
            return dailyKeysCache.count
        }
        return 0
    }

    @MainActor
    private func dailyTopCoursesTitles(on date: Date, limit: Int) async -> [String] {
        guard limit > 0 else { return [] }
        let day = Self.bangkokCal.startOfDay(for: date)
        let ids = UserSession.shared.courseIds(on: day)
        guard !ids.isEmpty else { return [] }

        var out: [String] = []
        out.reserveCapacity(min(ids.count, limit))
        for cid in ids {
            out.append(await shortCourseName(cid))
            if out.count == limit { break }
        }
        return out
    }


    /// ids of courses that were active on a given day.
    /// mvp: returns real data only for today (derived from stable daily cache).
    @MainActor
    func courseIds(for date: Date, limit: Int = 10) async -> [String] {
        guard limit > 0 else { return [] }
        let day = Self.bangkokCal.startOfDay(for: date)
        let all = UserSession.shared.courseIds(on: day)
        guard !all.isEmpty else { return [] }

        // DO NOT drop zero-progress courses. If the course is recorded in dayCourses, it counts as activity for that day.
        // We only sort by progress to keep "most relevant" first.
        var scored: [(String, Double)] = []
        scored.reserveCapacity(all.count)
        for cid in all {
            let p = await courseProgressFraction(courseId: cid)
            scored.append((cid, p))
        }
        scored.sort { $0.1 > $1.1 }

        let ids = scored.map { $0.0 }
        if ids.count <= limit { return ids }
        return Array(ids.prefix(limit))
    }

    /// display titles for courses that were active on a given day.
    /// uses LessonsManager titles; falls back to raw id if title is missing.
    @MainActor
    func courseTitles(for date: Date, limit: Int = 10) async -> [String] {
        let ids = await courseIds(for: date, limit: limit)
        guard !ids.isEmpty else { return [] }
        return await withTaskGroup(of: String.self) { group in
            for cid in ids {
                group.addTask { [cid] in
                    await self.shortCourseName(cid)
                }
            }
            var out: [String] = []
            out.reserveCapacity(ids.count)
            for await t in group { out.append(t) }
            return out
        }
    }

    /// first course title for a day (handy for calendar mini-cards).
    @MainActor
    func firstCourseTitle(for date: Date) async -> String? {
        (await courseTitles(for: date, limit: 1)).first
    }

    /// helper: whether there is any activity for a given day.
    @MainActor
    func hasCourses(on date: Date) async -> Bool {
        !UserSession.shared.courseIds(on: date).isEmpty
    }
}



extension MainManager {
    @MainActor
    func reloadDailyCoursePicks() async {
        let limit = effectiveDailyCoursePicksLimit()
        await reloadDailyCoursePicks(count: limit)
    }

    @MainActor
    func reloadDailyCoursePicks(count: Int = 5) async {
        // Free: смесь free+PRO (не «все платные»). PRO: больше слотов, любой микс.
        let cappedCount = hasExtraDailyPicks()
            ? min(max(1, count), proDailyCoursePicksLimit)
            : freeDailyCoursePicksLimit

        invalidateDailyCacheIfDayChanged()

        let all = CourseData.shared.featuredCourses
        if all.isEmpty {
            dailyCoursePicks = .empty
            dailyCourseCards = []
            return
        }

        let completedNow = Set(all.filter { isCourseCompleted($0) }.map(\.id))
        if !dailyCourseCache.isEmpty,
           (dailyCourseCacheCount != cappedCount || completedNow != dailyCourseCompletedSnapshot) {
            invalidateDailyCourseCache()
        }

        if dailyCourseCache.isEmpty || dailyCourseCacheCount != cappedCount {
            let limited = Self.pickDailyCourses(
                from: all,
                count: cappedCount,
                isProUser: hasExtraDailyPicks(),
                isCompleted: { [weak self] c in
                    self?.isCourseCompleted(c) ?? false
                },
                isProCourse: { [weak self] c in
                    self?.resolveIsProCourse(c) ?? c.isPro
                }
            )
            dailyCourseCache = limited
            dailyCourseCacheCount = cappedCount
            dailyCourseCompletedSnapshot = completedNow
        }

        let payload = DailyCoursePicksPayload(courses: dailyCourseCache)
        dailyCoursePicks = payload

        let snap = UserSession.shared.snapshot
        let started = snap.startedCourses
        var out: [CourseCardModel] = []
        out.reserveCapacity(dailyCourseCache.count)
        for c in dailyCourseCache {
            let isProCourse = resolveIsProCourse(c)
            out.append(
                await makeDiscoveryCourseCard(
                    from: c,
                    displayStyle: isProCourse ? .proShowcase : .discovery,
                    cta: started.contains(c.id) ? .continue : .add
                )
            )
        }
        dailyCourseCards = out
    }

    @MainActor
    func reloadReinforcementCourseCards(limit: Int = 8) async {
        let all = CourseData.shared.featuredCourses
        guard !all.isEmpty else {
            reinforcementCourseCards = []
            return
        }

        let completed = all.filter { isCourseCompleted($0) }
        guard !completed.isEmpty else {
            reinforcementCourseCards = []
            return
        }

        let sorted = sortedReinforcementCourses(completed)
        let capped = Array(sorted.prefix(max(1, limit)))
        var out: [CourseCardModel] = []
        out.reserveCapacity(capped.count)
        for c in capped {
            out.append(await makeReinforcementCourseCard(from: c))
        }
        reinforcementCourseCards = out
    }

    /// Единая проверка завершения курса (как в CourseView).
    @MainActor
    func isCourseCompleted(_ course: Course) -> Bool {
        let ids = [
            course.id,
            course.id.replacingOccurrences(of: "_", with: "-"),
            course.id.replacingOccurrences(of: "-", with: "_")
        ]
        for cid in ids {
            let lessonsTotal = max(course.lessonCount, LessonsData.shared.lessons(for: cid).count)
            let (done, total) = LessonsManager.shared.headerCounts(for: cid, lessonsTotal: lessonsTotal)
            if total > 0, done >= total { return true }
            if LessonsManager.shared.courseStatus(for: cid) == .completed { return true }
        }
        return false
    }

    @MainActor
    private func sortedReinforcementCourses(_ courses: [Course]) -> [Course] {
        courses.sorted { lhs, rhs in
            let failedA = ReinforcementStore.shared.failedCardKeys(courseId: lhs.id).count
            let failedB = ReinforcementStore.shared.failedCardKeys(courseId: rhs.id).count
            if failedA != failedB { return failedA > failedB }

            let scoreA = ReinforcementStore.shared.overallScore(courseId: lhs.id) ?? 100
            let scoreB = ReinforcementStore.shared.overallScore(courseId: rhs.id) ?? 100
            if scoreA != scoreB { return scoreA < scoreB }

            let sessionsA = ReinforcementStore.shared.gameSessions(courseId: lhs.id)
            let sessionsB = ReinforcementStore.shared.gameSessions(courseId: rhs.id)
            if sessionsA != sessionsB { return sessionsA < sessionsB }

            return lhs.id < rhs.id
        }
    }

    @MainActor
    private func makeDiscoveryCourseCard(
        from course: Course,
        displayStyle: CourseCardDisplayStyle,
        cta: CourseCardModel.CTA
    ) async -> CourseCardModel {
        let cid = course.id
        let title = await shortCourseName(cid)
        let subtitle: String = {
            if let outcome = courseOutcomePreview(cid) { return outcome }
            let s = shortCourseSubtitle(cid, course: course)
            return s.isEmpty ? CourseCardModel.CTA.continue.hint : s
        }()
        let meta = resolveCourseMeta(course)
        let p = await courseProgressFraction(courseId: cid)
        return CourseCardModel(
            courseId: cid,
            title: title,
            subtitle: subtitle,
            categoryChip: resolveCourseCategoryChip(course),
            lessonCount: meta.lessonCount,
            durationMinutes: meta.durationMinutes,
            learningOutcomes: meta.outcomes,
            isPro: resolveIsProCourse(course),
            displayStyle: displayStyle,
            progress: p,
            cta: cta
        )
    }

    @MainActor
    private func makeReinforcementCourseCard(from course: Course) async -> CourseCardModel {
        let cid = course.id
        let title = await shortCourseName(cid)
        let score = ReinforcementStore.shared.overallScore(courseId: cid)
        let errors = ReinforcementStore.shared.failedCardKeys(courseId: cid).count
        let sessions = ReinforcementStore.shared.gameSessions(courseId: cid)
        let subtitle: String = {
            if errors > 0 {
                return "\(errors) \(ruCardWord(errors, one: "ошибка", few: "ошибки", many: "ошибок")) · повторить"
            }
            if let score {
                return "закрепление \(score)% · \(sessions) \(ruCardWord(sessions, one: "игра", few: "игры", many: "игр"))"
            }
            return "курс пройден · закрепить в играх"
        }()
        let meta = resolveCourseMeta(course)
        return CourseCardModel(
            courseId: cid,
            title: title,
            subtitle: subtitle,
            categoryChip: resolveCourseCategoryChip(course),
            lessonCount: meta.lessonCount,
            durationMinutes: meta.durationMinutes,
            learningOutcomes: meta.outcomes,
            isPro: resolveIsProCourse(course),
            displayStyle: .reinforcement,
            reinforcementScore: score,
            reinforcementErrorCount: errors,
            progress: 1.0,
            cta: .reinforce
        )
    }

    private func ruCardWord(_ count: Int, one: String, few: String, many: String) -> String {
        let n = abs(count)
        let m10 = n % 10
        let m100 = n % 100
        if m10 == 1, m100 != 11 { return one }
        if (2...4).contains(m10), !(12...14).contains(m100) { return few }
        return many
    }


    /// Free: сначала бесплатные (шанс начать), затем PRO-витрина.
    /// PRO: случайная выборка из всего каталога.
    /// Пройденные курсы не попадают в подборку дня.
    private static func pickDailyCourses(
        from all: [Course],
        count: Int,
        isProUser: Bool,
        isCompleted: (Course) -> Bool,
        isProCourse: (Course) -> Bool
    ) -> [Course] {
        let pool = all.filter { !isCompleted($0) }
        guard count > 0, !pool.isEmpty else { return [] }
        if isProUser {
            return Array(pool.shuffled().prefix(count))
        }

        let free = pool.filter { !isProCourse($0) }.shuffled()
        let pro = pool.filter { isProCourse($0) }.shuffled()

        // Цель: минимум 2 free (если есть), остальное — PRO-витрина; иначе добиваем free.
        let freeTarget: Int = {
            if free.isEmpty { return 0 }
            if pro.isEmpty { return min(free.count, count) }
            return min(free.count, max(2, count - min(2, pro.count)))
        }()
        var picked = Array(free.prefix(freeTarget))
        let remaining = count - picked.count
        if remaining > 0 {
            picked.append(contentsOf: pro.prefix(remaining))
        }
        if picked.count < count {
            picked.append(contentsOf: free.dropFirst(freeTarget).prefix(count - picked.count))
        }
        return Array(picked.prefix(count))
    }

    @MainActor
    func randomCourseForToday(isProUser: Bool) async -> Course? {
        let all = CourseData.shared.featuredCourses
        guard !all.isEmpty else { return nil }

        let snap = UserSession.shared.snapshot
        let startedIds = snap.startedCourses

        let filtered = all.filter { course in
            let isProCourse = resolveIsProCourse(course)
            return isProUser || !isProCourse
        }

        guard !filtered.isEmpty else { return nil }

        let notStarted = filtered.filter { !startedIds.contains($0.id) }
        if let pick = notStarted.randomElement() {
            return pick
        }

        return filtered.randomElement()
    }
}
