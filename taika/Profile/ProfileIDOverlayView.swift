import SwiftUI
import UIKit

/// Compact account ID from the header crown — not a tab, not the paywall.
struct ProfileIDOverlayView: View {
    var onDismiss: () -> Void

    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var theme: ThemeManager
    @ObservedObject private var pro = ProManager.shared
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var profile = ProfileManager.shared
    @State private var showSupport = false
    @State private var showLegal = false
    @State private var showDebugSheet = false
    @State private var showResetAllConfirm = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var deleteAccountInProgress = false
    @State private var authInProgress = false
    @State private var authErrorMessage: String?
    @State private var storeRestoreMessage: String?
    @State private var restoreInFlight = false

    private var appVersionLabel: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            OverlayEtalonCard(title: "Профиль", onDismiss: onDismiss, role: .message, usesContextPlacement: true) {
                VStack(alignment: .leading, spacing: 0) {
                    accountBlock

                    Divider()
                        .overlay(PD.ColorToken.stroke.opacity(0.40))
                        .padding(.horizontal, CD.Spacing.screen)
                        .padding(.vertical, 6)

                    idRow(
                        title: "Taika Pro",
                        subtitle: pro.isPro ? "Подписка открыта" : "Курсы, Speaker и игры",
                        systemImage: "crown"
                    ) {
                        onDismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            overlay.presentProDirect(reason: .general)
                        }
                    }

                    Divider()
                        .overlay(PD.ColorToken.stroke.opacity(0.40))
                        .padding(.horizontal, CD.Spacing.screen)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                    quietLinks

                    Text("версия \(appVersionLabel)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                        .padding(.bottom, 4)

                    #if DEBUG
                    HStack(spacing: 16) {
                        Button("Сбросить") { showResetAllConfirm = true }
                        Button("Отладка") { showDebugSheet = true }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                    #endif
                }
                .padding(.bottom, 18)
            }
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                AuthService.presentationWindow = window
            }
            profile.refresh()
        }
        .sheet(isPresented: $showSupport) {
            ProfileSupportView()
                .environmentObject(theme)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLegal) {
            ProfileLegalView()
                .environmentObject(theme)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDebugSheet) {
            ProfileDebugSheet()
                .environmentObject(theme)
                .presentationDetents([.fraction(0.42)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .alert("Покупки", isPresented: Binding(
            get: { storeRestoreMessage != nil },
            set: { if !$0 { storeRestoreMessage = nil } }
        )) {
            Button("OK", role: .cancel) { storeRestoreMessage = nil }
        } message: {
            Text(storeRestoreMessage ?? "")
        }
        .alert("Сбросить прогресс?", isPresented: $showResetAllConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) { performFullReset() }
        } message: {
            Text("Удалим прогресс уроков, избранное и кэш разминки. Подписка не сбросится.")
        }
        .alert("Выйти из аккаунта?", isPresented: $showSignOutConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Выйти", role: .destructive) {
                try? auth.signOut()
                ProManager.shared.reset()
            }
        } message: {
            Text("Прогресс останется на этом телефоне. На другом без входа его не будет.")
        }
        .alert("Удалить аккаунт?", isPresented: $showDeleteAccountConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Удалим вход через Apple на этом телефоне. Прогресс уроков останется. Подписку отмени в настройках Apple ID, если она ещё активна.")
        }
    }

    @ViewBuilder
    private var accountBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            if auth.isLoggedIn {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(auth.displayName ?? "Apple ID")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.text)
                        Text("Прогресс сохранён")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Gradients.accentText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 10) {
                    Button("Выйти") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showSignOutConfirm = true
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)

                    Button(deleteAccountInProgress ? "Удаляем…" : "Удалить аккаунт") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showDeleteAccountConfirm = true
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PD.ColorToken.toneWrong.opacity(0.92))
                    .disabled(deleteAccountInProgress)
                }
                .padding(.horizontal, CD.Spacing.screen)
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    signInWithApple()
                } label: {
                    HStack(spacing: 10) {
                        if authInProgress {
                            ProgressView()
                                .tint(PD.ColorToken.text)
                        } else {
                            Image(systemName: "apple.logo")
                                .font(.body.weight(.semibold))
                        }
                        Text(authInProgress ? "Входим…" : "Войти с Apple")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(PD.ColorToken.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PD.ColorToken.text.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .disabled(authInProgress)
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.top, 4)

                Text("Чтобы прогресс не пропал при смене телефона.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Gradients.accentText)
                    .padding(.horizontal, CD.Spacing.screen)
            }

            if let authErrorMessage, !authErrorMessage.isEmpty {
                Text(authErrorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .padding(.horizontal, CD.Spacing.screen)
            }
        }
        .padding(.bottom, 8)
    }

    private func idRow(title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.55))
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var quietLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            quietLink(restoreInFlight ? "Проверяю…" : "Покупки") {
                Task { await restorePurchases() }
            }
            quietLink("Поддержка") { showSupport = true }
            quietLink("Документы") { showLegal = true }
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 4)
    }

    private func quietLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func signInWithApple() {
        authInProgress = true
        authErrorMessage = nil
        Task {
            do {
                _ = try await auth.signInWithApple()
                if let uid = auth.currentUserID {
                    SyncManager.shared.onUserDidLogin(userId: uid)
                    await ProManager.shared.syncRevenueCatIdentity(userId: uid)
                }
                authInProgress = false
            } catch AuthService.AuthError.cancelled {
                authInProgress = false
            } catch {
                authInProgress = false
                authErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func restorePurchases() async {
        storeRestoreMessage = nil
        guard !restoreInFlight else { return }
        if !auth.isLoggedIn {
            storeRestoreMessage = "Войди в аккаунт, чтобы восстановить подписку."
            return
        }
        restoreInFlight = true
        defer { restoreInFlight = false }
        do {
            await ProManager.shared.syncRevenueCatIdentity(userId: auth.currentUserID)
            try await ProManager.shared.restorePurchases()
            if pro.isPro {
                storeRestoreMessage = pro.isInIntroTrial
                    ? "Пробный период восстановлен."
                    : "Taika Pro восстановлен."
            } else {
                storeRestoreMessage = "Активных покупок не найдено."
            }
        } catch {
            storeRestoreMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteAccount() async {
        guard !deleteAccountInProgress else { return }
        deleteAccountInProgress = true
        authErrorMessage = nil
        do {
            try await auth.deleteAccount()
            ProManager.shared.reset()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch AuthService.AuthError.cancelled {
            // Пользователь закрыл окно Apple — аккаунт на месте.
        } catch {
            authErrorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        deleteAccountInProgress = false
    }

    private func performFullReset() {
        ProgressManager.shared.resetAll()
        UserSession.shared.resetAllProgress()
        StepManager.shared.resetAll()
        FavoriteManager.shared.resetAll()
        StepData.shared.resetDailyPicksCache()
        SpeakerAttemptsStore.clearAll()
        HomeTaskDoneStore.clearAll()
        ReinforcementScopeStore.clearAll()
        TaikaStarsStore.shared.clearAll()
        NotificationCenter.default.post(name: .init("ProgressDidChange"), object: nil)
        NotificationCenter.default.post(name: .init("FavoritesDidChange"), object: nil)
        NotificationCenter.default.post(name: .init("DailyPicksDidReset"), object: nil)
        NotificationCenter.default.post(name: .init("AppResetAll"), object: nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
