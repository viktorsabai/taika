import SwiftUI

/// Тот же паттерн, что у `PROView`: затемнение + стеклянная карточка 28pt.
struct CourseResetConfirmOverlayView: View {
    let courseId: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                HStack {
                    Text("taikA")
                        .font(.taikaLogo(16))
                        .foregroundStyle(CD.ColorToken.text)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    Text("Сбросить прогресс курса?")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Весь прогресс по этому курсу будет удалён. Вернуть данные будет нельзя.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 4)

                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        LessonsManager.shared.resetCourseProgress(courseId: courseId)
                        onDismiss()
                    } label: {
                        Text("сбросить")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(ThemeManager.shared.currentAccentFill)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(courseId.isEmpty)

                    Button(action: onDismiss) {
                        Text("отмена")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .taikaBlackGlassBackground(cornerRadius: 28)
            .frame(maxWidth: 420)
            .padding(.horizontal, 20)
            .transition(.scale(scale: 0.98).combined(with: .opacity))
        }
    }
}
