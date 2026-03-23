import SwiftUI

struct PROView: View {
    let courseId: String?
    private let initialPage: Int
    let onClose: () -> Void

    init(courseId: String?, initialPage: Int = 0, onClose: @escaping () -> Void) {
        self.courseId = courseId
        self.initialPage = initialPage
        self._page = State(initialValue: initialPage)
        self.onClose = onClose
    }

    private struct Benefit: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let systemImage: String
    }

    private let benefits: [Benefit] = [
        .init(
            title: "быстрое повторение",
            subtitle: "активное вспоминание слов в формате sprint",
            systemImage: "bolt.fill"
        ),
        .init(
            title: "фразы в контексте",
            subtitle: "сборка предложений и живых диалогов",
            systemImage: "text.bubble.fill"
        ),
        .init(
            title: "спикер",
            subtitle: "практика произношения с анализом речи",
            systemImage: "mic.fill"
        )
    ]

    private var orderedBenefits: [Benefit] {
        guard benefits.indices.contains(initialPage) else { return benefits }
        var reordered = benefits
        let selected = reordered.remove(at: initialPage)
        reordered.insert(selected, at: 0)
        return reordered
    }

    @State private var page: Int

    private var modalHeight: CGFloat {
        UIScreen.main.bounds.height * 0.5
    }

    private var carouselSection: some View {
        TabView(selection: $page) {
            ForEach(Array(orderedBenefits.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(item.subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 160)
    }

    private var dotsSection: some View {
        HStack(spacing: 6) {
            ForEach(0..<orderedBenefits.count, id: \.self) { index in
                Circle()
                    .fill(
                        index == page
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        : AnyShapeStyle(Color.white.opacity(0.25))
                    )
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.top, 4)
    }

    private var modalCard: some View {
        VStack(spacing: 20) {
            header

            carouselSection

            dotsSection

            ctaSection
                .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, y: 14)
        .frame(maxWidth: 420)
        .frame(height: modalHeight)
        .padding(.horizontal, 20)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            modalCard
                .transition(.scale(scale: 0.98).combined(with: .opacity))
        }
    }

    private var header: some View {
        HStack {
            Text("taikA")
                .font(.taikaLogo(16))
                .foregroundStyle(CD.ColorToken.text)

            Spacer(minLength: 0)

            Image(systemName: "crown.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                .scaleEffect(page == 0 ? 1.0 : 1.08)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: page)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            if !AuthService.shared.isLoggedIn {
                Text("Чтобы прогресс не пропал на новом устройстве, привяжи аккаунт в Профиле.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            Button {
                NotificationCenter.default.post(
                    name: Notification.Name("OpenProPurchaseRequested"),
                    object: nil,
                    userInfo: ["courseId": courseId ?? ""]
                )
                onClose()
            } label: {
                Text("перейти на pro")
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

            Button(action: onClose) {
                Text("позже")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        PROView(courseId: "course_test", initialPage: 0) {}
    }
}
