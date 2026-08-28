//  LessonsManager.swift
//  taika
//
//  Created by product on 13.09.2025.
//

import Foundation
import UIKit

/// Статус урока в рамках курса
public enum LessonStatus: String, Codable, Equatable {
    case locked
    case inProgress
    case completed
}

/// Прогресс по одному уроку
public struct LessonProgress: Codable, Equatable, Hashable {
    public var learned: Int
    public var total: Int
    public var status: LessonStatus

    /// Fractional percent progress [0.0 ... 1.0]
    public var percent: Double {
        guard total > 0 else { return 0.0 }
        let clamped = min(max(0, learned), total)
        return Double(clamped) / Double(total)
    }
}

extension LessonProgress {
    static var zero: LessonProgress { .init(learned: 0, total: 0, status: .locked) }
}

/// Агрегатор прогресса уроков по курсам — источник правды для хэдера Lessons/Course
@MainActor public final class LessonsManager: ObservableObject {
    public static let shared = LessonsManager()

    /// courseId -> (lessonId -> progress)
    @Published public private(set) var progress: [String: [String: LessonProgress]] = [:]
    @Published public private(set) var progressVersion: Int = 0

    // Tracks lessons that were explicitly started (entered) even with 0 learned
    @Published public private(set) var started: [String: Set<String>] = [:]

    private let storeKey = "LessonsManager.progress.v1"
    private let storeKeyStarted = "LessonsManager.started.v1"
    private var saveWorkItem: DispatchWorkItem?

    // Coalesced UI notifier to prevent excessive objectWillChange/tick spam
    private var pendingEmit = false
    private func scheduleEmit() {
        guard !pendingEmit else { return }
        pendingEmit = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingEmit = false
            self.objectWillChange.send()
            self.tick()
        }
    }

    // Navigation helper (single source of truth for course/lesson order)
    public let navigator = CourseNavigator.shared

    // single source of truth for lesson content (parsed from lessons.json)
    private let lessonsData = LessonsData.shared

    // MARK: - Course id canonicalization (same course, duplicate UserDefaults keys: `a_b` vs `a-b`)

    private static func normalizeCourseIdKey(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
    }

    /// Всегда используем `courseID` из `lessons.json`, чтобы `LessonsManager.progress` совпадал с `rebuildAggregatesFromProgressManager` и с `ProgressManager`.
    private func catalogCourseId(for raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return t }
        if let c = lessonsData.courseBundle(matchingAnyId: t) {
            return c.courseID
        }
        return t
    }

    /// Сопоставить `lessonId` с id из каталога (разный регистр / `_` vs `-`).
    private func catalogLessonId(courseId cid: String, lessonId raw: String) -> String {
        if let l = lessonsData.lesson(courseID: cid, lessonID: raw) {
            return l.lessonID
        }
        let target = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for l in lessonsData.lessons(for: cid) {
            if l.lessonID.caseInsensitiveCompare(target) == .orderedSame { return l.lessonID }
            let a = l.lessonID.replacingOccurrences(of: "_", with: "-").lowercased()
            let b = target.replacingOccurrences(of: "_", with: "-").lowercased()
            if a == b { return l.lessonID }
        }
        return raw
    }

    private func mergeLessonProgress(_ a: LessonProgress, _ b: LessonProgress) -> LessonProgress {
        if a.status == .completed { return a }
        if b.status == .completed { return b }
        if a.percent != b.percent {
            return a.percent >= b.percent ? a : b
        }
        return a.learned >= b.learned ? a : b
    }

    private func mergeProgressDictionary(_ input: [String: [String: LessonProgress]]) -> [String: [String: LessonProgress]] {
        var out: [String: [String: LessonProgress]] = [:]
        for (rawKey, lessons) in input {
            let canon = catalogCourseId(for: rawKey)
            var bucket = out[canon] ?? [:]
            for (lid, lp) in lessons {
                if let existing = bucket[lid] {
                    bucket[lid] = mergeLessonProgress(existing, lp)
                } else {
                    bucket[lid] = lp
                }
            }
            out[canon] = bucket
        }
        return out
    }

    private func mergeStartedDictionary(_ decoded: [String: [String]]) -> [String: Set<String>] {
        var out: [String: Set<String>] = [:]
        for (rawKey, arr) in decoded {
            let canon = catalogCourseId(for: rawKey)
            var s = out[canon] ?? []
            s.formUnion(arr)
            out[canon] = s
        }
        return out
    }

    private init() {
        load()
        NotificationCenter.default.addObserver(forName: .stepProgressDidChange, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                guard let u = note.userInfo as? [String: Any],
                      let courseId = u["courseId"] as? String,
                      let lessonId = u["lessonId"] as? String else {
                    // Нет контекста урока — полный ребилд из ProgressManager (синк, игры, облако).
                    self.refreshFromProgressManager()
                    return
                }
                // Единый источник счётчиков: ProgressManager (снапшоты StepView могли давать рассинхрон по индексам полоски).
                self.syncLessonFromProgressManager(courseId: courseId, lessonId: lessonId)
            }
        }
        NotificationCenter.default.addObserver(forName: .stepProgressDidReset, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.forceRefresh()
            }
        }
        // Mark a lesson as started (user entered the lesson) even if learned == 0
        NotificationCenter.default.addObserver(forName: .lessonDidStart, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                guard let u = note.userInfo as? [String: Any],
                      let courseId = u["courseId"] as? String,
                      let lessonId = u["lessonId"] as? String else {
                    return
                }
                let providedTotal = (u["totalCount"] as? Int) ?? 0
                self.markLessonStarted(courseId: courseId, lessonId: lessonId, hintTotal: providedTotal)
            }
        }
        // Favorites: LessonsView/CourseView refresh via FavoriteManager / NotificationCenter;
        // avoid invalidating all LessonsManager subscribers on every $items emission (global jank).
        // Save on app background so progress never lost (safety net; we also save immediately on change)
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.save()
            }
        }
        // При возврате в приложение — пересобрать агрегаты из ProgressManager, чтобы выученные уроки не «пропадали»
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFromProgressManager()
            }
        }
    }

    private func tick() {
        // Wrap to avoid overflow in extreme cases
        if progressVersion == Int.max { progressVersion = 0 }
        progressVersion += 1
    }

    /// Явно опубликовать текущее состояние (на случай, когда данные логически поменялись,
    /// но словарь `progress` остался прежним и SwiftUI не триггернул перерисовку)
    public func publishProgress() {
        scheduleEmit()
    }

    /// Силовой рефреш подписчиков (дергает objectWillChange и версию)
    public func forceRefresh() {
        scheduleEmit()
    }

    /// Синхронизировать progress с ProgressManager (источник истины для выученных шагов). Вызывается при возврате в приложение.
    public func refreshFromProgressManager() {
        rebuildAggregatesFromProgressManager()
    }

    /// Одна строка урока в `progress` из `ProgressManager.learnedEffectiveCount` / `totalEffectiveCount`.
    public func syncLessonFromProgressManager(courseId rawCourseId: String, lessonId rawLessonId: String) {
        let cid = catalogCourseId(for: rawCourseId)
        let lid = catalogLessonId(courseId: cid, lessonId: rawLessonId)
        let learned = ProgressManager.shared.learnedEffectiveCount(courseId: cid, lessonId: lid)
        let totalEffective = ProgressManager.shared.totalEffectiveCount(courseId: cid, lessonId: lid)
        if applyLessonProgressInMemory(courseId: cid, lessonId: lid, learnedCount: learned, total: totalEffective, lifehackCount: 0) {
            // ProgressManager already persists learned state; coalesce LessonsManager JSON writes.
            saveDebounced()
            scheduleEmit()
        }
    }

    /// Применить снапшот прогресса по конкретному уроку (используется из Step/ProgressManager)
    public func applySnapshot(courseId: String,
                              lessonId: String,
                              learnedContent: Set<Int>,
                              allCards: Set<Int>,
                              lifehacks: Set<Int> = []) {
        updateLessonProgress(courseId: courseId,
                             lessonId: lessonId,
                             learnedContent: learnedContent,
                             allCards: allCards,
                             lifehacks: lifehacks)
        // Print percent for debug
        if let prog = lessonProgress(courseId: courseId, lessonId: lessonId) {
            #if DEBUG
            print("[LessonsManager] applySnapshot course=\(courseId) lesson=\(lessonId) percent=\(prog.percent)")
            #endif
        }
        // UI обновится через собственный эмит в updateLessonProgress либо через внешние нотификации
    }

    /// Обновить агрегат прогресса по уроку (вызов из StepManager)
    /// - Parameters:
    ///   - learnedCount: количество выученных "контентных" карточек (без лайфхаков)
    ///   - total: общее количество карточек урока (с лайфхаками)
    ///   - lifehackCount: сколько из total являются лайфхаками (НЕ участвуют в прогрессе урока)
    public func updateLessonProgress(courseId: String,
                                     lessonId: String,
                                     learnedCount: Int,
                                     total: Int,
                                     lifehackCount: Int = 0) {
        let cid = catalogCourseId(for: courseId)
        let lid = catalogLessonId(courseId: cid, lessonId: lessonId)
        // LessonsManager stores progress denominators as *effective totals*
        // (consistent with ProgressManager learnedEffectiveCount/totalEffectiveCount).
        // `lifehackCount` is ignored for consistency; older call sites may pass it.
        let effectiveTotal = max(0, total)
        let learned = max(0, learnedCount)

        let status: LessonStatus
        if effectiveTotal == 0 {
            // Нет контентных карточек → урок нельзя завершить, остаётся locked, пока нет выученных
            status = learned > 0 ? .inProgress : .locked
        } else if learned >= effectiveTotal {
            status = .completed
        } else if learned > 0 {
            status = .inProgress
        } else {
            status = .locked
        }

        var byLesson = progress[cid] ?? [:]
        let next = LessonProgress(learned: learned, total: effectiveTotal, status: status)

        if byLesson[lid] != next {
            byLesson[lid] = next
            progress[cid] = byLesson
            save()  // immediate save so progress persists before app exit/background (same as ProgressManager)
            objectWillChange.send()
            tick()
        }

        // Hot-path debug log removed: this callback can fire very frequently.
    }

    /// Удобный апдейтер, если уже посчитаны наборы индексов
    /// - Parameters:
    ///   - learnedContent: множество индексов контентных карточек (без лайфхаков)
    ///   - allCards: общее множество всех карточек урока (включая лайфхаки)
    ///   - lifehacks: множество индексов лайфхаков (исключаются из прогресса)
    public func updateLessonProgress(
        courseId: String,
        lessonId: String,
        learnedContent: Set<Int>,
        allCards: Set<Int>,
        lifehacks: Set<Int> = []
    ) {
        let effectiveSet = allCards.subtracting(lifehacks)
        let learned = learnedContent.intersection(effectiveSet).count
        self.updateLessonProgress(courseId: courseId,
                                  lessonId: lessonId,
                                  learnedCount: learned,
                                  total: effectiveSet.count,
                                  lifehackCount: 0)
        // Hot-path debug log removed to keep console signal/noise healthy.
    }

    /// Помечает урок как «начатый» (вошли в lesson), даже если learned==0.
    /// Если передан hintTotal > 0 и у нас не было записи по уроку — создаём запись с total=hintTotal.
    public func markLessonStarted(courseId: String, lessonId: String, hintTotal: Int = 0) {
        let cid = catalogCourseId(for: courseId)
        let lid = catalogLessonId(courseId: cid, lessonId: lessonId)
        var s = started[cid] ?? []
        let inserted = s.insert(lid).inserted
        if inserted {
            started[cid] = s
            // Если нет прогресса по уроку — можем создать "нулевую" запись,
            // чтобы статус курса пересчитался в .inProgress сразу после входа.
            if progress[cid]?[lid] == nil {
                let total = max(0, hintTotal)
                let lp = LessonProgress(learned: 0, total: total, status: .inProgress)
                var byLesson = progress[cid] ?? [:]
                byLesson[lid] = lp
                progress[cid] = byLesson
            }
            save()
            saveStarted()
            objectWillChange.send()
            tick()
        }
    }

    /// Текущий прогресс по конкретному уроку
    public func lessonProgress(courseId: String, lessonId: String) -> LessonProgress? {
        let cid = catalogCourseId(for: courseId)
        let lid = catalogLessonId(courseId: cid, lessonId: lessonId)
        return progress[cid]?[lid]
    }

    // MARK: - Main integration helpers

    /// Удобный доступ к проценту прогресса по уроку (0.0 ... 1.0).
    /// Считаем из ProgressManager напрямую — не из потенциально устаревшего агрегата `progress`.
    public func lessonPercent(courseId: String, lessonId: String) -> Double {
        let cid = catalogCourseId(for: courseId)
        let lid = catalogLessonId(courseId: cid, lessonId: lessonId)
        let learned = ProgressManager.shared.learnedEffectiveCount(courseId: cid, lessonId: lid)
        let total = ProgressManager.shared.totalEffectiveCount(courseId: cid, lessonId: lid)
        guard total > 0 else {
            return lessonProgress(courseId: cid, lessonId: lid)?.percent ?? 0.0
        }
        return min(1.0, Double(min(learned, total)) / Double(total))
    }

    /// Возвращает статус и прогресс по уроку (0.0...1.0)
    public func lessonStatusWithProgress(courseId: String, lessonId: String) -> (LessonStatus, Double) {
        let cid = catalogCourseId(for: courseId)
        let lid = catalogLessonId(courseId: cid, lessonId: lessonId)
        guard let lp = progress[cid]?[lid], lp.total > 0 else {
            return (.locked, 0.0)
        }
        return (lp.status, lp.percent)
    }

    /// Returns all lessonIds currently tracked for a course, sorted for stability.
    public func lessonIds(for courseId: String) -> [String] {
        let cid = catalogCourseId(for: courseId)
        let byLesson = progress[cid] ?? [:]
        return byLesson.keys.sorted()
    }

    /// Returns the overall status for a course:
    /// - .completed if all catalog lessons are completed and at least one exists,
    /// - .inProgress if any lesson is in progress, completed (but not all), or started,
    /// - .locked otherwise (no progress).
    public func courseStatus(for courseId: String) -> LessonStatus {
        let cid = catalogCourseId(for: courseId)
        let catalogIds = lessonsData.lessons(for: cid).map(\.lessonID)
        let byLesson = progress[cid] ?? [:]
        let startedLessons = started[cid] ?? []

        let statuses: [LessonStatus]
        if !catalogIds.isEmpty {
            // Считаем по актуальному каталогу — иначе «все записи completed»
            // при частично начатом курсе даёт ложный .completed.
            statuses = catalogIds.map { byLesson[$0]?.status ?? .locked }
        } else {
            statuses = byLesson.values.map(\.status)
        }

        if statuses.isEmpty && startedLessons.isEmpty {
            return .locked
        }
        if !statuses.isEmpty, statuses.allSatisfy({ $0 == .completed }) {
            return .completed
        }
        if statuses.contains(.inProgress)
            || statuses.contains(.completed)
            || !startedLessons.isEmpty {
            return .inProgress
        }
        return .locked
    }

    /// Общий процент прогресса по курсу (0.0 ... 1.0): выученные карточки / все карточки всех уроков курса
    public func coursePercent(for courseId: String) -> Double {
        let cid = catalogCourseId(for: courseId)
        let lessons = lessonsData.lessons(for: cid)
        guard !lessons.isEmpty else { return 0.0 }

        // Important: course progress must be computed from ProgressManager
        // (same source as LessonsView "Итоги курса"), otherwise partial progress
        // can temporarily desync between different aggregators.
        let learnedTotal = lessons.reduce(0) { acc, lesson in
            acc + ProgressManager.shared.learnedEffectiveCount(courseId: cid, lessonId: lesson.lessonID)
        }

        let totalEffective = lessons.reduce(0) { acc, lesson in
            acc + ProgressManager.shared.totalEffectiveCount(courseId: cid, lessonId: lesson.lessonID)
        }

        guard totalEffective > 0 else { return 0.0 }
        let value = Double(min(max(learnedTotal, 0), totalEffective)) / Double(totalEffective)
        return min(max(value, 0.0), 1.0)
    }
    /// Кол-во завершённых уроков для хэдера курса и карточек CourseView.
    /// Учитываются только `lesson_id` из актуального `lessons.json`, иначе после удаления урока из каталога
    /// в персисте остаётся «призрак» (например `course_b_1_l8`) и получается логически 9/8 при total=8.
    public func headerCounts(for courseId: String, lessonsTotal: Int) -> (completed: Int, total: Int) {
        let cid = catalogCourseId(for: courseId)
        let catalogIds = lessonsData.lessons(for: cid).map(\.lessonID)
        let byLesson = progress[cid] ?? [:]
        if !catalogIds.isEmpty {
            let completed = catalogIds.filter { byLesson[$0]?.status == .completed }.count
            return (completed, catalogIds.count)
        }
        let completed = byLesson.values.filter { $0.status == .completed }.count
        return (completed, max(1, lessonsTotal))
    }

    /// Полный сброс прогресса по курсу
    public func resetCourseProgress(courseId: String) {
        let cid = catalogCourseId(for: courseId)
        // 1) Обнуляем агрегаты по урокам этого курса (включая старые дубли ключей)
        for key in progress.keys where Self.normalizeCourseIdKey(catalogCourseId(for: key)) == Self.normalizeCourseIdKey(cid) {
            progress.removeValue(forKey: key)
        }
        for key in started.keys where Self.normalizeCourseIdKey(catalogCourseId(for: key)) == Self.normalizeCourseIdKey(cid) {
            started.removeValue(forKey: key)
        }
        saveStarted()
        // также чистим персист в ProgressManager по всем урокам курса
        ProgressManager.shared.resetCourse(courseId: cid)

        NotificationCenter.default.post(
            name: .stepProgressDidReset,
            object: nil,
            userInfo: [
                "courseId": cid,
                "lessonId": "__all__"
            ]
        )

        // 2) Сбрасываем связанные состояния в соседних менеджерах (если реализованы)
        // NOTE: Реализуй методы в соответствующих менеджерах, если их ещё нет.
        #if canImport(Foundation)
        FavoriteManager.shared.clearForCourse(cid)
        #endif

        // 3) Сохранить и оповестить подписчиков
        save()
        scheduleEmit()

        // 4) Широкое оповещение через NotificationCenter (на него можно подписать StepView и др.)
        NotificationCenter.default.post(name: .lessonsCourseProgressDidReset, object: nil, userInfo: ["courseId": cid])
        NotificationCenter.default.post(name: .courseProgressDidReset, object: nil, userInfo: ["courseId": cid])
        NotificationCenter.default.post(name: .stepStateShouldReset, object: nil, userInfo: ["courseId": cid])

        #if DEBUG
        print("[LessonsManager] reset progress for course=\(cid)")
        #endif
    }

    /// Сброс прогресса по конкретному уроку
    public func resetLessonProgress(courseId: String, lessonId: String) {
        let cid = catalogCourseId(for: courseId)
        let lid = catalogLessonId(courseId: cid, lessonId: lessonId)
        // 1) Удалить агрегат по этому уроку в рамках курса
        var byLesson = progress[cid] ?? [:]
        let hadValue = byLesson.removeValue(forKey: lid) != nil
        progress[cid] = byLesson
        // чистим персист в ProgressManager для конкретного урока
        ProgressManager.shared.resetLesson(courseId: cid, lessonId: lid)

        NotificationCenter.default.post(
            name: .stepProgressDidReset,
            object: nil,
            userInfo: [
                "courseId": cid,
                "lessonId": lid
            ]
        )

        // 2) Сохранить и оповестить UI (даже если не было записи — важно дернуть перерисовку)
        save()
        scheduleEmit()

        // 3) Нотификации для подписчиков (StepView/StepManager и т.д.)
        NotificationCenter.default.post(
            name: .lessonsLessonProgressDidReset,
            object: nil,
            userInfo: [
                "courseId": cid,
                "lessonId": lid,
                "changed": hadValue
            ]
        )
        NotificationCenter.default.post(
            name: .lessonProgressDidReset,
            object: nil,
            userInfo: [
                "courseId": cid,
                "lessonId": lid,
                "changed": hadValue
            ]
        )
        NotificationCenter.default.post(
            name: .stepStateShouldReset,
            object: nil,
            userInfo: [
                "courseId": cid,
                "lessonId": lid
            ]
        )

        #if DEBUG
        print("[LessonsManager] reset progress course=\(cid) lesson=\(lid)")
        #endif
    }

    /// Полный сброс прогресса по всем курсам
    public func resetAllProgress() {
        // 1) Обнуляем весь агрегированный прогресс
        progress.removeAll()

        // 2) Сбрасываем связанные состояния в соседних менеджерах (если реализованы)
        #if canImport(Foundation)
        FavoriteManager.shared.clearAll()
        #endif

        // 3) Сохранить и оповестить UI
        save()
        scheduleEmit()

        // 4) Широкое оповещение
        NotificationCenter.default.post(name: .allProgressDidReset, object: nil)
        NotificationCenter.default.post(name: .stepStateShouldReset, object: nil, userInfo: ["courseId": "__all__"])

        #if DEBUG
        print("[LessonsManager] reset progress for ALL courses")
        #endif
    }


    /// Количество лайков (из FavoriteManager) по конкретному уроку
    public func lessonFavoriteCount(courseId: String, lessonId: String) -> Int {
        #if canImport(Foundation)
        let cid = catalogCourseId(for: courseId)
        let favs = FavoriteManager.shared.favoritesForLesson(courseId: cid, lessonId: lessonId)
        return favs.count
        #else
        return 0
        #endif
    }

    /// Удобный хелпер для Step/StepManager: агрегирует прогресс урока из наборов индексов
    public func aggregateFromStep(courseId: String,
                                  lessonId: String,
                                  learnedContent: Set<Int>,
                                  allCards: Set<Int>,
                                  lifehacks: Set<Int> = []) {
        applySnapshot(courseId: courseId,
                      lessonId: lessonId,
                      learnedContent: learnedContent,
                      allCards: allCards,
                      lifehacks: lifehacks)
    }

    /// Перценты прогресса по каждому уроку (для хэдера/слотов)
    /// - Parameters:
    ///   - courseId: идентификатор курса
    ///   - lessonIds: массив lessonId в нужном порядке (1:1 с отображением во View)
    /// - Returns: массив значений [0.0 ... 1.0], по одному на каждый lessonId
    public func percentsForLessons(courseId: String, lessonIds: [String]) -> [Double] {
        let cid = catalogCourseId(for: courseId)
        let byLesson = progress[cid] ?? [:]
        return lessonIds.map { lid in
            guard let lp = byLesson[lid], lp.total > 0 else { return 0.0 }
            let clamped = min(max(0, lp.learned), lp.total)
            return Double(clamped) / Double(lp.total)
        }
    }

    /// Точные доли прогресса по урокам для мини-слотов хэдера (0.0...1.0 в заданном порядке)
    public func progressSlots(courseId: String, lessonIds: [String]) -> [Double] {
        let cid = catalogCourseId(for: courseId)
        let byLesson = progress[cid] ?? [:]
        return lessonIds.map { lid in
            guard let lp = byLesson[lid] else { return 0.0 }
            let value = lp.percent
            return min(max(value, 0.0), 1.0)
        }
    }

    // MARK: - Persistence

    private func saveDebounced() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(progress)
            UserDefaults.standard.set(data, forKey: storeKey)
            UserDefaults.standard.set(progressVersion, forKey: storeKey+".version")
        } catch {
            print("[LessonsManager] save error: \(error)")
        }
        if let dataStarted = try? JSONEncoder().encode(started.mapValues { Array($0) }) {
            UserDefaults.standard.set(dataStarted, forKey: storeKeyStarted)
        }
    }

    private func saveStarted() {
        if let data = try? JSONEncoder().encode(started.mapValues { Array($0) }) {
            UserDefaults.standard.set(data, forKey: storeKeyStarted)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else {
            rebuildAggregatesFromProgressManager()
            return
        }
        do {
            let decoded = try JSONDecoder().decode([String: [String: LessonProgress]].self, from: data)
            progress = mergeProgressDictionary(decoded)
            let ver = UserDefaults.standard.integer(forKey: storeKey+".version")
            self.progressVersion = max(0, ver)
        } catch {
            print("[LessonsManager] load error: \(error)")
        }
        if let dataStarted = UserDefaults.standard.data(forKey: storeKeyStarted),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: dataStarted) {
            self.started = mergeStartedDictionary(decoded)
        }
        // EPIC 4: align aggregates with ProgressManager (single source of truth for learned)
        rebuildAggregatesFromProgressManager()
    }

    /// Пересобрать агрегаты из ProgressManager (при старте и при возврате в приложение). Публичный вызов — refreshFromProgressManager().
    private func rebuildAggregatesFromProgressManager() {
        var didChange = false
        for course in lessonsData.allCourses() {
            let courseId = course.courseID
            for lesson in course.lessons {
                let lessonId = lesson.lessonID
                let learned = ProgressManager.shared.learnedEffectiveCount(courseId: courseId, lessonId: lessonId)
                let totalEffective = ProgressManager.shared.totalEffectiveCount(courseId: courseId, lessonId: lessonId)
                if applyLessonProgressInMemory(courseId: courseId, lessonId: lessonId, learnedCount: learned, total: totalEffective, lifehackCount: 0) {
                    didChange = true
                }
            }
        }
        if didChange {
            save()
            objectWillChange.send()
            tick()
        }
    }

    /// Updates progress dictionary only (no save/emit). Returns true if value changed. Used by rebuildAggregatesFromProgressManager.
    private func applyLessonProgressInMemory(courseId: String, lessonId: String, learnedCount: Int, total: Int, lifehackCount: Int) -> Bool {
        // LessonsManager stores progress denominators as *effective totals*
        // (consistent with ProgressManager learnedEffectiveCount/totalEffectiveCount).
        // `lifehackCount` is kept only for backward signature compatibility.
        let effectiveTotal = max(0, total)
        let learned = max(0, learnedCount)
        let status: LessonStatus
        if effectiveTotal == 0 {
            status = learned > 0 ? .inProgress : .locked
        } else if learned >= effectiveTotal {
            status = .completed
        } else if learned > 0 {
            status = .inProgress
        } else {
            status = .locked
        }
        var byLesson = progress[courseId] ?? [:]
        let next = LessonProgress(learned: learned, total: effectiveTotal, status: status)
        guard byLesson[lessonId] != next else { return false }
        byLesson[lessonId] = next
        progress[courseId] = byLesson
        return true
    }
    // MARK: - Navigation (forwarded to CourseNavigator)
    /// Compute next destination from a given course/lesson.
    @inlinable
    public func advance(from courseId: String, lessonId: String) -> CourseNavigator.Advance {
        navigator.advance(from: courseId, lessonId: lessonId)
    }

    /// First lesson in a course (if any)
    @inlinable
    public func firstLesson(in courseId: String) -> String? {
        navigator.firstLesson(in: courseId)
    }

    /// Safe lesson title resolution
    @inlinable
    public func lessonTitle(for lessonId: String) -> String {
        navigator.lessonTitle(for: lessonId)
    }

    /// Canonical lesson title lookup used across the app (favorites, etc.)
    /// `courseId` kept for forward-compat (not used by current navigator)
    @inlinable
    public func titleForLesson(courseId: String, lessonId: String) -> String {
        let t = navigator.lessonTitle(for: lessonId)
        let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? lessonId.replacingOccurrences(of: "_", with: " ") : t
    }

    /// Safe course title resolution
    @inlinable
    public func courseTitle(for courseId: String) -> String {
        // delegate to single source of truth
        let resolved = navigator.courseTitle(for: courseId)
        let trimmed = resolved.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        // fallback: humanize id if navigator has no title yet
        return courseId
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

public extension Notification.Name {
    static let lessonsCourseProgressDidReset = Notification.Name("LessonsManager.courseProgressDidReset")
    static let lessonsLessonProgressDidReset = Notification.Name("LessonsManager.lessonProgressDidReset")
    static let allProgressDidReset = Notification.Name("LessonsManager.allProgressDidReset")
    static let stepStateShouldReset = Notification.Name("LessonsManager.stepStateShouldReset")

    static let stepProgressDidReset  = Notification.Name("Step.progressDidReset")
    static let lessonDidStart = Notification.Name("Lesson.sessionDidStart")
}




// MARK: - Paywall preview
extension LessonsManager {

    /// paywall preview lessons for a pro-course overlay (read-only)
    func paywallPreviewLessons(for courseId: String) -> [LessonBundle] {
        lessonsData.lessons(for: courseId)
    }
}
