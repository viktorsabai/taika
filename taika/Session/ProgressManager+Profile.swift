//
//  ProgressManager+Profile.swift
//  taika
//
//  Profile dashboard state: все расчёты «готовности», мастерства и радара — здесь.
//  ProfileView подписывается на ProgressManager.publishedState и не считает данные сам.
//

import Foundation
import SwiftUI

// MARK: - Profile Dashboard State (single struct for Profile UI)

public struct ProfileDashboardState: Equatable {
    /// Всего выученных шагов (stable steps) по всем курсам
    public var totalStableSteps: Int
    /// Текущий стрик (дней подряд с активностью)
    public var currentStreak: Int
    /// Общий Mastery % (0...100), на базе MASTERY_MODEL / взвешенный прогресс курсов
    public var totalMasteryPercent: Int
    /// Средний балл произношения (0...100) по всем попыткам из SpeakerAttemptsStore
    public var averagePronunciationScore: Int?
    /// Количество завершённых Recall Builder игр (proxy: completed lessons count)
    public var completedRecallGamesCount: Int
    /// Радар: 5 осей 0...1 — Market, Taxi, Immigration, Cafe, General
    public var radarValues: [Double]

    /// Шагов в спикере, для которых есть сохранённая оценка (уникальные ключи)
    public var speakerTrackedStepsCount: Int
    /// Сумма `attemptCount` по всем шагам спикера
    public var speakerTotalMicAttempts: Int
    /// Максимальный `heardConfidence` среди сохранённых попыток
    public var speakerBestConfidence: Int?
    /// Все сессии игр закрепления (ReinforcementStore), по всем курсам и режимам
    public var reinforcementSessionsTotal: Int
    /// Взвешенное среднее точности по режимам, где считали score (0...100)
    public var reinforcementAvgAccuracy: Int?
    /// Карточек в избранном
    public var favoritesTotalCount: Int

    public static var empty: ProfileDashboardState {
        ProfileDashboardState(
            totalStableSteps: 0,
            currentStreak: 0,
            totalMasteryPercent: 0,
            averagePronunciationScore: nil,
            completedRecallGamesCount: 0,
            radarValues: [0, 0, 0, 0, 0],
            speakerTrackedStepsCount: 0,
            speakerTotalMicAttempts: 0,
            speakerBestConfidence: nil,
            reinforcementSessionsTotal: 0,
            reinforcementAvgAccuracy: nil,
            favoritesTotalCount: 0
        )
    }
}

// MARK: - ProgressManager extension: расчёт профиля

extension ProgressManager {

    /// Пересобрать publishedState из learnedSteps, UserSession, SpeakerAttemptsStore.
    /// Вызывается из emitChange() и refreshProfileState(). Не вызывать из init/load (риск цикла с UserSession.shared).
    public func rebuildProfileDashboardState() -> ProfileDashboardState {
        let totalStableSteps = learnedSteps.values.reduce(0) { $0 + $1.count }
        let currentStreak = Self.computeCurrentStreak()
        let courseIds = UserSession.shared.profileAllKnownCourseIds()
        var totalMasteryPercent = 0
        if !courseIds.isEmpty {
            var sum: Double = 0
            for cid in courseIds {
                sum += progress(for: cid)
            }
            totalMasteryPercent = Int(round(min(100, max(0, sum / Double(courseIds.count) * 100))))
        }
        let averagePronunciationScore: Int? = {
            let attempts = SpeakerAttemptsStore.loadAll()
            guard !attempts.isEmpty else { return nil }
            let scores = attempts.values.map { $0.advancedScore ?? $0.heardConfidence }
            let sum = scores.reduce(0, +)
            let avg = sum / scores.count
            return max(0, min(100, avg))
        }()
        let completedRecallGamesCount = completedLessons.count
        let radarValues = Self.computeRadarValues(
            courseIds: courseIds,
            totalStableSteps: totalStableSteps,
            totalMasteryPercent: totalMasteryPercent
        )
        let attemptValues = Array(SpeakerAttemptsStore.loadAll().values)
        let speakerTrackedStepsCount = attemptValues.count
        let speakerTotalMicAttempts = attemptValues.reduce(0) { $0 + $1.attemptCount }
        let speakerBestConfidence = attemptValues.map { $0.advancedScore ?? $0.heardConfidence }.max()
        let (reinforcementSessionsTotal, reinforcementAvgAccuracy) = Self.aggregateReinforcementTotals()
        let favoritesTotalCount = FavoriteManager.shared.items.count
        return ProfileDashboardState(
            totalStableSteps: totalStableSteps,
            currentStreak: currentStreak,
            totalMasteryPercent: totalMasteryPercent,
            averagePronunciationScore: averagePronunciationScore,
            completedRecallGamesCount: completedRecallGamesCount,
            radarValues: radarValues,
            speakerTrackedStepsCount: speakerTrackedStepsCount,
            speakerTotalMicAttempts: speakerTotalMicAttempts,
            speakerBestConfidence: speakerBestConfidence,
            reinforcementSessionsTotal: reinforcementSessionsTotal,
            reinforcementAvgAccuracy: reinforcementAvgAccuracy,
            favoritesTotalCount: favoritesTotalCount
        )
    }

    /// Сводка по `ReinforcementStore`: сколько раз играли и средняя точность там, где она считалась.
    private static func aggregateReinforcementTotals() -> (sessions: Int, avg: Int?) {
        let all = ReinforcementStore.shared.courses
        var sessions = 0
        var sumWeighted = 0
        var weight = 0
        for cm in all.values {
            for mm in cm.byMode.values {
                sessions += mm.sessions
                if let a = mm.averageScore, mm.sessions > 0 {
                    sumWeighted += a * mm.sessions
                    weight += mm.sessions
                }
            }
        }
        let avg = weight > 0 ? sumWeighted / weight : nil
        return (sessions, avg)
    }

    private static func computeCurrentStreak() -> Int {
        let cal = UserSession.bangkokCal
        var today = cal.startOfDay(for: Date())
        var streak = 0
        for _ in 0..<365 {
            let key = UserSession.shared.bangkokDayKey(for: today)
            let hasActivity = !(UserSession.shared.snapshot.activityLog[key]?.isEmpty ?? true)
                || !(UserSession.shared.snapshot.dayCourses[key]?.isEmpty ?? true)
            if hasActivity {
                streak += 1
            } else {
                break
            }
            today = cal.date(byAdding: .day, value: -1, to: today) ?? today
        }
        return streak
    }

    private static func computeRadarValues(
        courseIds: [String],
        totalStableSteps: Int,
        totalMasteryPercent: Int
    ) -> [Double] {
        guard !courseIds.isEmpty else { return [0, 0, 0, 0, 0] }
        var lessonsDone = 0
        var lessonsTotal = 0
        for cid in courseIds {
            guard let meta = ProgressManager.shared.lessonMetaProvider?(cid) else { continue }
            for l in meta {
                lessonsTotal += 1
                let key = LessonKey(courseId: ProgressManager.shared.canonicalize(cid), lessonId: ProgressManager.shared.canonicalize(l.id))
                let learned = ProgressManager.shared.learnedSteps[key] ?? []
                let effective = learned.subtracting(l.tipIndexes).subtracting(l.excludedIndexes)
                let total = max(0, l.totalSteps - l.tipIndexes.count - l.excludedIndexes.count)
                if total > 0, effective.count >= total { lessonsDone += 1 }
            }
        }
        let lessonBase = lessonsTotal > 0 ? Double(lessonsDone) / Double(lessonsTotal) : 0
        let masterFraction = Double(totalMasteryPercent) / 100.0
        let market = min(1, max(0, Double(totalStableSteps) * 0.012 + lessonBase * 0.25))
        let taxi = market * 0.85
        let immigration = min(1, lessonBase * 0.80)
        let cafe = market * 0.7
        let general = masterFraction
        return [market, taxi, immigration, cafe, general]
    }
}
