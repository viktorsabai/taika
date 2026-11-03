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
        ZStack {
            OverlayEtalonBackground(onDismiss: close)

            GlassSurface(cornerRadius: TaikaOverlayTokens.Layout.cardRadius) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Spacer(minLength: 0)
                        Button(action: close) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(CD.ColorToken.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(CD.ColorToken.chip.opacity(0.9)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(success ? "Готово" : "Закрыть")
                    }

                    Text(success ? "Taika Pro с тобой" : "У меня есть код")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(CD.ColorToken.text)

                    Text(success
                         ? "Доступ открыт. Можно сразу к урокам."
                         : "Вставь код от друга. Почта не нужна.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if success {
                        Image(systemName: "gift.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(theme.currentAccentFill)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
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
                                .font(.system(size: 13, weight: .medium))
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
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 420)
            .overlay {
                RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.cardRadius, style: .continuous)
                    .strokeBorder(theme.currentAccentFill.opacity(0.28), lineWidth: Theme.Strokes.strokeCardLineWidth)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func close() {
        if success { onActivated?() }
        onDismiss()
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
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)

            GlassSurface(cornerRadius: TaikaOverlayTokens.Layout.cardRadius) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Spacer(minLength: 0)
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(CD.ColorToken.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(CD.ColorToken.chip.opacity(0.9)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Готово")
                    }

                    Text("Подарок готов")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(CD.ColorToken.text)

                    Text("Отправь код другу. В приложении: У меня есть код.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

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
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 420)
            .overlay {
                RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.cardRadius, style: .continuous)
                    .strokeBorder(theme.currentAccentFill.opacity(0.28), lineWidth: Theme.Strokes.strokeCardLineWidth)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var shareText: String {
        "Тебе подарили Taika Pro.\nКод: \(code)\nОткрой приложение → У меня есть подарок → вставь код."
    }
}
