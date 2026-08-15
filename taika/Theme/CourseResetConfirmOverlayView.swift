import SwiftUI

/// Тот же паттерн, что у эталонных оверлеев: blur-scrim + стеклянная карточка с хедером.
struct CourseResetConfirmOverlayView: View {
    let courseId: String
    /// Если задан — сброс только этого урока; иначе всего курса.
    var lessonId: String? = nil
    let onDismiss: () -> Void

    private var isLessonScope: Bool {
        !(lessonId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)

            OverlayEtalonCard(
                title: isLessonScope ? "Сбросить урок?" : "Сбросить прогресс?",
                onDismiss: onDismiss
            ) {
                VStack(spacing: 16) {
                    Text(
                        isLessonScope
                        ? "Прогресс по этому уроку будет обнулён. Карточки снова станут невыученными."
                        : "Весь прогресс по этому курсу будет удалён. Вернуть данные будет нельзя."
                    )
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, CD.Spacing.screen)

                    VStack(spacing: 12) {
                        OverlayEtalonPrimaryButton(title: "сбросить") {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            performReset()
                            onDismiss()
                        }
                        .disabled(courseId.isEmpty || (isLessonScope && (lessonId ?? "").isEmpty))

                        OverlayEtalonSecondaryButton(title: "отмена", action: onDismiss)
                    }
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.bottom, 20)
                }
            }
            .transition(.scale(scale: 0.98).combined(with: .opacity))
        }
    }

    private func performReset() {
        if let lid = lessonId?.trimmingCharacters(in: .whitespacesAndNewlines), !lid.isEmpty {
            LessonsManager.shared.resetLessonProgress(courseId: courseId, lessonId: lid)
        } else {
            LessonsManager.shared.resetCourseProgress(courseId: courseId)
        }
    }
}
