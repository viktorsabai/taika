import SwiftUI

/// Кнопки итогов закрепления.
/// - Курс (зачётка): очередь ошибок → 2a/2b/2c, без «следующий урок».
/// - Из урока/степа: повторить → произношение → следующий урок/курс → закрыть.
/// - Из игрового парка: повторить → следующая игра (или замок Taika+) → закрыть.
struct GameCompletionActions: View {
    var isFromLessonStep: Bool
    var isCourseReinforcement: Bool = false
    var isProUser: Bool
    /// «Следующий урок» / «Следующий курс» — только из степа.
    var continueLearningTitle: String? = nil
    var nextGameTitle: String? = nil
    var onRepeat: () -> Void
    /// Ошибки только этой сессии (ветка степа / парка).
    var errorCount: Int = 0
    /// Размер очереди курса после записи сессии (ветка зачётки, вариант A).
    var queueErrorCount: Int = 0
    var onRepeatErrors: (() -> Void)? = nil
    var onNextGame: (() -> Void)? = nil
    var onSpeakerPractice: (() -> Void)? = nil
    var onContinueLearning: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 12) {
            if isCourseReinforcement {
                courseReinforcementFollowUp
            } else if errorCount > 0 {
                errorFollowUpButtons
            } else {
                primaryButton(title: "Повторить", action: onRepeat)
                if isFromLessonStep {
                    stepFollowUpButtons
                } else {
                    parkFollowUpButtons
                }
            }

            if let onClose {
                // 2c already uses primary «К зачётке» — не дублируем.
                if !(isCourseReinforcement && queueErrorCount == 0) {
                    Button(action: onClose) {
                        Text(isCourseReinforcement ? "К зачётке" : "Закрыть")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 2a/2b: очередь > 0 · 2c: очередь пуста.
    @ViewBuilder
    private var courseReinforcementFollowUp: some View {
        if queueErrorCount > 0 {
            primaryButton(
                title: "Повторить ошибки · \(queueErrorCount)",
                action: onRepeatErrors ?? onRepeat
            )
            if let onNextGame {
                outlineButton(title: "Следующая игра", systemImage: "arrow.right", action: onNextGame)
            }
            outlineButton(title: "Повторить эту игру", systemImage: "arrow.counterclockwise", action: onRepeat)
        } else {
            if let onClose {
                primaryButton(title: "К зачётке", action: onClose)
            }
            if let onNextGame {
                outlineButton(title: "Следующая игра", systemImage: "arrow.right", action: onNextGame)
            } else if let onSpeakerPractice {
                outlineButton(
                    title: "Тренировать произношение",
                    systemImage: "mic.fill",
                    action: onSpeakerPractice
                )
            }
            outlineButton(title: "Повторить эту игру", systemImage: "arrow.counterclockwise", action: onRepeat)
        }
    }

    @ViewBuilder
    private var errorFollowUpButtons: some View {
        primaryButton(
            title: "Повторить ошибки · \(errorCount)",
            action: onRepeatErrors ?? onRepeat
        )
        if let onSpeakerPractice {
            outlineButton(
                title: "Продолжить в Спикере",
                systemImage: "mic.fill",
                action: onSpeakerPractice
            )
        }
    }

    @ViewBuilder
    private var stepFollowUpButtons: some View {
        if let onSpeakerPractice {
            outlineButton(
                title: "Тренировать произношение",
                systemImage: "mic.fill",
                action: onSpeakerPractice
            )
        }
        if let onContinueLearning, let continueLearningTitle, !continueLearningTitle.isEmpty {
            outlineButton(
                title: continueLearningTitle,
                systemImage: "arrow.right",
                action: onContinueLearning
            )
        }
    }

    @ViewBuilder
    private var parkFollowUpButtons: some View {
        if isProUser, let onNextGame {
            outlineButton(
                title: "Следующая игра",
                systemImage: "arrow.right",
                action: onNextGame
            )
        } else if !isProUser {
            lockedNextGameRow
        }
    }

    private var lockedNextGameRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(nextGameTitle ?? "Следующая игра")
                .font(CD.FontToken.body(15, weight: .medium))
            Text("· Taika+")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
        }
        .foregroundStyle(PD.ColorToken.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PD.ColorToken.card.opacity(0.55))
        )
        .accessibilityLabel("Следующая игра недоступна, нужен Taika+")
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PD.ColorToken.card.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.currentAccentFill.opacity(0.84), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func outlineButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(CD.FontToken.body(15, weight: .semibold))
            }
            .foregroundStyle(theme.currentAccentFill)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.currentAccentFill, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

extension HomeTaskView {
    /// Игра запущена из урока/степа (не из игрового парка / избранного).
    static func isLessonStepOrigin(courseId: String, lessonId: String) -> Bool {
        let lid = lessonId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cid = courseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lid.isEmpty else { return false }
        if cid == "__favorites__" || cid == "--favorites--" { return false }
        if DictionaryGameSource.isDictionaryCourseId(cid) { return false }
        if LearnedGameSource.isPseudoCourseId(cid) { return false }
        return true
    }

    static func continueLearningTitle(courseId: String, lessonId: String) -> String? {
        guard isLessonStepOrigin(courseId: courseId, lessonId: lessonId) else { return nil }
        switch CourseNavigator.shared.advance(from: courseId, lessonId: lessonId) {
        case .nextLesson: return "Следующий урок"
        case .nextCourse: return "К следующему курсу"
        case .end: return nil
        }
    }
}
