//
//  AuthSoftWallState.swift
//  taika
//
//  Флаги и логика показа мягкого окна «Закрепи результат» (привязка аккаунта).
//
//  Условия показа:
//  - Пользователь не залогинен (AuthService.shared.isLoggedIn == false).
//  - Есть прогресс: totalStableSteps > 0 или completedRecallGamesCount > 0 (хотя бы один выученный шаг или завершённый урок).
//  - Не показывали в последние 7 дней (cooldown в UserDefaults authSoftWall.lastShownDate).
//
//  Триггеры:
//  1. Закрытие экрана успеха урока в StepView (крестик, тап по фону, «Следующий урок», «Следующий курс», «К курсам»).
//  2. onAppear вкладки «Профиль» (ProfileView).
//
//  Отладка: в DEBUG в консоли печатаются [AuthSoftWall] shouldShow: ... и tryPresentSoftWall / presenting overlay.
//  Сброс cooldown для теста: UserDefaults.standard.removeObject(forKey: "authSoftWall.lastShownDate")
//

import Foundation

private let lastShownKey = "authSoftWall.lastShownDate"
private let cooldownDays: Int = 7

@MainActor
public enum AuthSoftWallState {

    /// Есть ли достаточный прогресс для показа soft wall (хотя бы один выученный шаг, завершённый урок или начатый урок).
    public static var hasProgress: Bool {
        let pm = ProgressManager.shared
        let state = pm.publishedState
        let hasStepsOrCompleted = state.totalStableSteps > 0 || state.completedRecallGamesCount > 0
        let hasStartedLesson = !pm.startedLessons.isEmpty
        return hasStepsOrCompleted || hasStartedLesson
    }

    /// Показывали ли уже в течение последних N дней.
    private static var lastShownDate: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: lastShownKey)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: lastShownKey)
        }
    }

    /// Нужно ли показать soft wall: не залогинен, есть прогресс, не показывали недавно.
    public static func shouldShowSoftWall() -> Bool {
        let isLoggedIn = AuthService.shared.isLoggedIn
        let prog = hasProgress
        let state = ProgressManager.shared.publishedState
        #if DEBUG
        let startedCount = ProgressManager.shared.startedLessons.count
        print("[AuthSoftWall] shouldShow: isLoggedIn=\(isLoggedIn) hasProgress=\(prog) totalStableSteps=\(state.totalStableSteps) completedRecall=\(state.completedRecallGamesCount) startedLessons=\(startedCount) lastShown=\(lastShownDate?.description ?? "nil")")
        #endif
        if isLoggedIn { return false }
        if !prog { return false }
        guard let last = lastShownDate else { return true }
        let calendar = Calendar.current
        guard let daysAgo = calendar.dateComponents([.day], from: last, to: Date()).day else { return true }
        return daysAgo >= cooldownDays
    }

    /// Отметить, что soft wall показан (сбрасывает таймер показа).
    public static func markSoftWallShown() {
        lastShownDate = Date()
    }

    /// Проверить условия и при выполнении показать overlay authSoftWall.
    /// - Parameter calledFromProfile: если true, не обновляем cooldown — сообщение можно показывать при каждом заходе в Профиль, пока пользователь не войдёт.
    public static func tryPresentSoftWall(calledFromProfile: Bool = false) {
        #if DEBUG
        print("[AuthSoftWall] tryPresentSoftWall called fromProfile=\(calledFromProfile)")
        #endif
        guard shouldShowSoftWall() else { return }
        let state = ProgressManager.shared.publishedState
        #if DEBUG
        print("[AuthSoftWall] presenting overlay mastery=\(state.totalMasteryPercent) streak=\(state.currentStreak)")
        #endif
        OverlayPresenter.shared.present(.authSoftWall(masteryPercent: state.totalMasteryPercent, streakDays: state.currentStreak))
        if !calledFromProfile {
            markSoftWallShown()
        }
    }
}
