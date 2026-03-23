//
//  OnboardingCarouselView.swift
//  taika
//
//  Карусель карточек после сплэша. На последней карточке: «Начать» + кнопки входа как в «Закрепи результат» (Apple, Telegram).
//

import SwiftUI
import AuthenticationServices

private struct OnboardingCard {
    let title: String
    let subtitle: String
    let icon: String
}

private let supportURL = "https://t.me/taika_support"

struct OnboardingCarouselView: View {
    let onFinish: () -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var auth = AuthService.shared
    @State private var page: Int = 0
    @State private var authInProgress = false

    private static let cards: [OnboardingCard] = [
        OnboardingCard(
            title: "Учи тайский по шагам",
            subtitle: "Слова и фразы с произношением — от простого к сложному.",
            icon: "book.fill"
        ),
        OnboardingCard(
            title: "Тренируй произношение",
            subtitle: "Голосовые карточки и разбор — как ты звучишь.",
            icon: "waveform.circle.fill"
        ),
        OnboardingCard(
            title: "Сохраняй прогресс",
            subtitle: "Привяжи аккаунт в профиле, чтобы не потерять достижения.",
            icon: "icloud.fill"
        )
    ]

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Пропустить") {
                        onFinish()
                    }
                    .font(PD.FontToken.body(16, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                TabView(selection: $page) {
                    ForEach(Array(Self.cards.enumerated()), id: \.offset) { idx, card in
                        cardView(card)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator

                Spacer(minLength: 24)

                if page < Self.cards.count - 1 {
                    primaryButton(title: "Далее") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { page += 1 }
                    }
                    .frame(height: 220)
                } else {
                    lastCardActions
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                AuthService.presentationWindow = window
            }
        }
    }

    /// Тёмный цвет текста на акцентных кнопках (читаемо на розовом фоне в любой теме).
    private static let buttonTextOnAccent = Color(white: 0.14)

    /// Кнопка с акцентным фоном: тёмный текст для читаемости.
    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Self.buttonTextOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(theme.currentAccentFill))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
    }

    /// Последняя карточка: «Начать» + Sign in with Apple / Telegram в стиле «Закрепи результат»; фиксированная высота — карусель не прыгает.
    private var lastCardActions: some View {
        VStack(spacing: 12) {
            Button(action: { onFinish() }) {
                Text("Начать")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Self.buttonTextOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(theme.currentAccentFill))
            }
            .buttonStyle(.plain)

            Button(action: signInWithApple) {
                OnboardingAppleSignInButtonRepresentable()
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
            }
            .buttonStyle(.plain)
            .disabled(authInProgress)

            Button(action: openTelegram) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Sign in with Telegram")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.22, green: 0.51, blue: 0.92))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }

    private func signInWithApple() {
        authInProgress = true
        Task {
            do {
                _ = try await auth.signInWithApple()
                if let uid = auth.currentUserID {
                    SyncManager.shared.onUserDidLogin(userId: uid)
                }
                authInProgress = false
                onFinish()
            } catch AuthService.AuthError.cancelled {
                authInProgress = false
            } catch {
                authInProgress = false
            }
        }
    }

    private func openTelegram() {
        if let url = URL(string: supportURL) {
            UIApplication.shared.open(url)
        }
    }

    private func cardView(_ card: OnboardingCard) -> some View {
        VStack(spacing: 24) {
            Image(systemName: card.icon)
                .font(.system(size: 56))
                .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
            Text(card.title)
                .font(PD.FontToken.body(22, weight: .bold))
                .foregroundStyle(PD.ColorToken.text)
                .multilineTextAlignment(.center)
            Text(card.subtitle)
                .font(PD.FontToken.caption(16, weight: .regular))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<Self.cards.count, id: \.self) { idx in
                Circle()
                    .fill(idx == page ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.4)))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Системная кнопка Sign in with Apple (как в AuthSoftWallView)
private struct OnboardingAppleSignInButtonRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: .black
        )
    }
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}
