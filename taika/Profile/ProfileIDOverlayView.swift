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
            OverlayEtalonCard(title: "Профиль", onDismiss: onDismiss, role: .message) {
                VStack(alignment: .leading, spacing: 0) {
                    idRow(
                        title: auth.isLoggedIn ? (auth.displayName ?? "Apple ID") : "Аккаунт",
                        subtitle: auth.isLoggedIn ? "Нажми, чтобы выйти" : "Войти с Apple ID",
                        systemImage: "apple.logo"
                    ) {
                        if auth.isLoggedIn {
                            try? auth.signOut()
                            ProManager.shared.reset()
                        } else {
                            signInWithApple()
                        }
                    }
                    if authInProgress {
                        ProgressView()
                            .padding(.leading, 42)
                            .padding(.bottom, 8)
                    }
                    if let authErrorMessage, !authErrorMessage.isEmpty {
                        Text(authErrorMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 8)
                    }

                    Divider().overlay(PD.ColorToken.stroke.opacity(0.40))

                    idRow(
                        title: "Восстановить покупки",
                        subtitle: restoreInFlight ? "Проверяю…" : "Подписка с этого Apple ID",
                        systemImage: "arrow.clockwise"
                    ) {
                        Task { await restorePurchases() }
                    }

                    Divider().overlay(PD.ColorToken.stroke.opacity(0.40))

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

                    Divider().overlay(PD.ColorToken.stroke.opacity(0.40))

                    idRow(
                        title: "Поддержка",
                        subtitle: "Помощь и обратная связь",
                        systemImage: "questionmark.bubble"
                    ) {
                        showSupport = true
                    }

                    Divider().overlay(PD.ColorToken.stroke.opacity(0.40))

                    idRow(
                        title: "Правовые документы",
                        subtitle: "Версия \(appVersionLabel)",
                        systemImage: "doc.on.doc"
                    ) {
                        showLegal = true
                    }

                    #if DEBUG
                    Divider().overlay(PD.ColorToken.stroke.opacity(0.40))
                    idRow(
                        title: "Сбросить прогресс",
                        subtitle: "Только локальные данные",
                        systemImage: "trash"
                    ) {
                        showResetAllConfirm = true
                    }

                    Divider().overlay(PD.ColorToken.stroke.opacity(0.40))
                    idRow(
                        title: "Отладка",
                        subtitle: "Taika Pro, онбординг, демо",
                        systemImage: "wrench.and.screwdriver"
                    ) {
                        showDebugSheet = true
                    }
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
