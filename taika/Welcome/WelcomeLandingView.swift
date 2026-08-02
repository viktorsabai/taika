//
//  WelcomeLandingView.swift
//  taika
//
//  Первый экран: бренд Taika, капсулы «Начать» / вход, лист «Другие опции».
//

import SwiftUI

private let supportURL = "https://t.me/taika_support"

struct WelcomeLandingView: View {
    let onComplete: () -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var auth = AuthService.shared
    @State private var authInProgress = false
    @State private var authErrorMessage: String?
    @State private var showOtherOptions = false
    @State private var showOnboarding = false
    // Mini-splash phase inside the same entry screen.
    @State private var showBranding = false
    @State private var showSkip = false
    @State private var showButtons = false
    @State private var cursorVisible = true

    private let legalText = "Продолжая, ты соглашаешься с условиями использования и политикой конфиденциальности."

    @State private var aboutPage: Int = 0

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    onboardingChip
                    Spacer()
                    skipChip
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer(minLength: 24)

                brandingBlock
                    .opacity(showBranding ? 1 : 0)
                    .scaleEffect(showBranding ? 1 : 0.985)
                    .blur(radius: showBranding ? 0 : 6)
                    .offset(y: showBranding ? 0 : 12)
                    .animation(.spring(response: 0.55, dampingFraction: 0.86), value: showBranding)

                Spacer(minLength: 32)

                bottomBlock
                    .opacity(showButtons ? 1 : 0)
                    .scaleEffect(showButtons ? 1 : 0.99)
                    .blur(radius: showButtons ? 0 : 8)
                    .offset(y: showButtons ? 0 : 20)
                    .animation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.08), value: showButtons)
            }
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                AuthService.presentationWindow = window
            }

            // Timing similar to SplashTaikaView, but kept inside one entry page.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { showSkip = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { showBranding = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) { showButtons = true }
            }
        }
        .onReceive(Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()) { _ in
            cursorVisible.toggle()
        }
        .sheet(isPresented: $showOtherOptions) {
            otherOptionsSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(22)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            WelcomeOnboardingView(onClose: { showOnboarding = false })
                .environmentObject(theme)
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            WelcomeSpaceBackdropView()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    /// Главный CTA использует текущий акцент темы (синхронно со всем приложением).
    private var primaryCTAGradient: LinearGradient { theme.currentAccentFill }

    // MARK: - Top

    private var onboardingChip: some View {
        Button {
            showOnboarding = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 14, weight: .semibold))
                Text("О Taika")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.42))
                    .background(.ultraThinMaterial, in: Capsule())
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(showSkip ? 1 : 0)
        .scaleEffect(showSkip ? 1 : 0.98)
        .blur(radius: showSkip ? 0 : 6)
        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: showSkip)
    }

    private var skipChip: some View {
        Button(action: { onComplete() }) {
            Text("Пропустить")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.42))
                        .background(.ultraThinMaterial, in: Capsule())
                )
                .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .opacity(showSkip ? 1 : 0)
        .scaleEffect(showSkip ? 1 : 0.98)
        .blur(radius: showSkip ? 0 : 6)
        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: showSkip)
    }

    // MARK: - Branding

    private var brandingBlock: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Text("tai")
                    .font(.custom("Onmark Trial", size: 52))
                    .foregroundStyle(Color.white)
                Text("kAAA")
                    .font(.custom("Onmark Trial", size: 52))
                    .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
            }

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("твоя персональная кун кру")
                Text("_")
                    .opacity(cursorVisible ? 1 : 0.15)
            }
            .font(.system(size: 15, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.88))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }

    // MARK: - Bottom

    private var bottomBlock: some View {
        VStack(spacing: 14) {
            frostedPillButton(title: "Начать", systemImage: nil, prominent: true, action: { onComplete() })
                .disabled(authInProgress)

            frostedPillButton(title: "Войти через Apple", systemImage: "apple.logo", prominent: false, action: signInWithApple)
                .disabled(authInProgress)

            frostedPillButton(title: "Telegram", systemImage: "paperplane.fill", prominent: false, action: openTelegram)
                .disabled(authInProgress)

            if authInProgress {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 4)
            }

            if let msg = authErrorMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Text(legalText)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
    }

    private func frostedPillButton(title: String, systemImage: String?, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: prominent ? .semibold : .medium))
            }
            .foregroundStyle(prominent ? Color(white: 0.12) : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if prominent {
                        Capsule().fill(primaryCTAGradient)
                    } else {
                        ZStack {
                            Capsule().fill(.ultraThinMaterial)
                            Capsule().fill(Color.black.opacity(0.48))
                        }
                    }
                }
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(prominent ? 0 : 0.5), lineWidth: prominent ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sheet

    private var otherOptionsSheet: some View {
        return NavigationStack {
            TaikaRootVerticalScroll {
                VStack(alignment: .leading, spacing: 18) {
                    Text("О Taika")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(PD.ColorToken.text)

                    Text("Мы учим тайскому через короткие шаги, произношение и прогресс — без хаоса и «простыней» теории.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary)

                    TaikaValueCarouselView(
                        slides: TaikaValueDeck.about,
                        page: $aboutPage,
                        compact: true
                    )
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 14) {
                        sheetRow(
                            icon: "checkmark.seal.fill",
                            title: "Как начать",
                            subtitle: "Нажми «Начать», выбери курс и двигайся по урокам. Произношение — в карточках и в Спикере."
                        )
                        sheetRow(
                            icon: "person.crop.circle.fill",
                            title: "Аккаунт и синхронизация",
                            subtitle: "Вход нужен, чтобы сохранять прогресс между устройствами."
                        )
                    }
                    .padding(.top, 10)
                }
                .padding(24)
            }
            .background(PD.ColorToken.background)
            .navigationTitle("О Taika")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { showOtherOptions = false }
                }
            }
        }
        .environmentObject(theme)
    }

    private func sheetRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(PD.FontToken.body(17, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Text(subtitle)
                    .font(PD.FontToken.caption(15, weight: .regular))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actions

    private func signInWithApple() {
        authInProgress = true
        authErrorMessage = nil
        Task {
            do {
                _ = try await auth.signInWithApple()
                if let uid = auth.currentUserID {
                    SyncManager.shared.onUserDidLogin(userId: uid)
                }
                authInProgress = false
                onComplete()
            } catch AuthService.AuthError.cancelled {
                authInProgress = false
            } catch {
                authInProgress = false
                authErrorMessage = error.localizedDescription
            }
        }
    }

    private func openTelegram() {
        if let url = URL(string: supportURL) {
            UIApplication.shared.open(url)
        }
    }
}


#Preview {
    WelcomeLandingView(onComplete: {})
        .environmentObject(ThemeManager.shared)
}
