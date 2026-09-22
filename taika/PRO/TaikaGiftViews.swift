//
//  TaikaGiftViews.swift
//  taika
//
//  Сквозной gift UX: активация кода + экран выданного подарка (share).
//

import SwiftUI
import RevenueCat

/// Активация подарка — один sheet на онбординг / профиль / paywall.
struct TaikaGiftRedeemSheet: View {
    let onDismiss: () -> Void
    var onActivated: (() -> Void)? = nil

    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var pro = ProManager.shared

    @State private var code = ""
    @State private var inFlight = false
    @State private var errorMessage: String?
    @State private var success = false
    @State private var authInProgress = false

    var body: some View {
        NavigationStack {
            ProfileGlassBackdrop {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ProfileDestinationIntro(
                            eyebrow: "ПОДАРОК",
                            title: success ? "Taika Pro с тобой" : "У меня есть подарок",
                            subtitle: success
                                ? "Доступ открыт. Можно сразу на главную."
                                : "Вставь код от друга — без почты и без новой оплаты."
                        )

                        if success {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(theme.currentAccentFill)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        } else {
                            TextField("TAIKA-XXXX-XXXX-XXXX", text: $code)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(PD.FontToken.caption(13, weight: .medium))
                                    .foregroundStyle(theme.currentAccentTintColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Button {
                                Task { await activate() }
                            } label: {
                                HStack(spacing: 8) {
                                    if inFlight || authInProgress {
                                        ProgressView().tint(Color.black.opacity(0.75))
                                    }
                                    Image(systemName: "gift.fill")
                                    Text(auth.isLoggedIn ? "Активировать" : "Войти и активировать")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(Color.black.opacity(0.88))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(theme.currentAccentFill))
                            }
                            .buttonStyle(.plain)
                            .disabled(inFlight || authInProgress || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.horizontal, PD.Spacing.screen)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Подарок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(success ? "Готово" : "Закрыть") {
                        if success { onActivated?() }
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func activate() async {
        errorMessage = nil
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !auth.isLoggedIn {
            authInProgress = true
            defer { authInProgress = false }
            do {
                try await auth.signInWithApple()
                if let uid = auth.currentUserID {
                    SyncManager.shared.onUserDidLogin(userId: uid)
                    await ProManager.shared.syncRevenueCatIdentity(userId: uid)
                }
            } catch AuthService.AuthError.cancelled {
                return
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        guard let appUserId = await resolveAppUserId() else {
            errorMessage = "Не удалось определить аккаунт. Войди ещё раз."
            return
        }

        inFlight = true
        defer { inFlight = false }
        do {
            let result = try await TaikaGiftService.redeemCode(trimmed, appUserId: appUserId)
            if result.demoGrant {
                #if DEBUG
                ProManager.shared.setDebugOverride(true)
                #endif
            } else {
                await ProManager.shared.syncCustomerInfoFromRevenueCat()
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                success = true
            }
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func resolveAppUserId() async -> String? {
        await ProManager.shared.syncRevenueCatIdentity(userId: auth.currentUserID)
        if RevenueCatBootstrap.isConfigured {
            return Purchases.shared.appUserID
        }
        return auth.currentUserID
    }
}

/// После покупки подарка — код + share.
struct TaikaGiftIssuedSheet: View {
    let code: String
    let onDismiss: () -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        NavigationStack {
            ProfileGlassBackdrop {
                VStack(spacing: 18) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(theme.currentAccentFill)
                        .padding(.top, 12)

                    Text("Подарок готов")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(PD.ColorToken.text)

                    Text("Отправь код другу. В приложении: У меня есть подарок.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Text(code)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(PD.ColorToken.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = code
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label("Скопировать", systemImage: "doc.on.doc")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(PD.ColorToken.text)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)

                        ShareLink(item: shareText) {
                            Label("Поделиться", systemImage: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(Color.black.opacity(0.88))
                                .background(Capsule().fill(theme.currentAccentFill))
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, PD.Spacing.screen)
                .padding(.bottom, 28)
            }
            .navigationTitle("Подарок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var shareText: String {
        "Тебе подарили Taika Pro.\nКод: \(code)\nОткрой приложение → У меня есть подарок → вставь код."
    }
}
