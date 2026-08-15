//
//  ProfileView.swift
//  taika
//
//  Компактный корень: аккаунт · Taika+ · ценность · Ещё.
//  Детали Pro / legal / beta — в sheet’ах.
//

import SwiftUI
import UIKit

// MARK: - Build channel (TestFlight / Debug)

enum TaikaBuildChannel {
    /// TestFlight: receipt file is `sandboxReceipt` in non-Debug builds.
    static var isTestFlight: Bool {
        #if DEBUG
        return false
        #else
        guard let url = Bundle.main.appStoreReceiptURL else { return false }
        return url.lastPathComponent == "sandboxReceipt"
        #endif
    }

    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Плашка для профиля; `nil` на App Store релизе.
    static var badgeTitle: String? {
        if isDebug { return "Debug" }
        if isTestFlight { return "Beta · TestFlight" }
        return nil
    }

    static var badgeSubtitle: String? {
        if isDebug { return "Локальная сборка для разработки" }
        if isTestFlight {
            return "Тестовая сборка с taikaa.online · \(TaikaProConfig.introTrialDaysPhrase) Taika+"
        }
        return nil
    }
}

struct ProfileView: View {
    @ObservedObject private var pro = ProManager.shared
    @ObservedObject private var auth = AuthService.shared
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var overlay: OverlayPresenter

    @State private var showResetAllConfirm = false
    @State private var viewReloadToken = UUID()
    @State private var showDebugSheet = false
    @State private var showOnboarding = false
    @State private var showMoreSheet = false
    @State private var showProSheet = false
    @State private var authInProgress = false
    @State private var authErrorMessage: String?
    @State private var storeRestoreMessage: String?
    @State private var restoreInFlight = false

    private var listRowInsets: EdgeInsets {
        EdgeInsets(top: 10, leading: PD.Spacing.screen, bottom: 10, trailing: PD.Spacing.screen)
    }

    private var appVersionLabel: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PD.ColorToken.textSecondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    @ViewBuilder
    private func profileLinkRow(title: String, subtitle: String? = nil, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: subtitle == nil ? .center : .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .frame(width: 24, alignment: .center)
                    .padding(.top, subtitle == nil ? 0 : 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(PD.ColorToken.text)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.55))
                    .padding(.top, subtitle == nil ? 0 : 2)
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(listRowInsets)
        .listRowBackground(PD.ColorToken.card.opacity(0.35))
    }

    private func performFullReset() {
        ProgressManager.shared.resetAll()
        UserSession.shared.resetAllProgress()
        StepManager.shared.resetAll()
        FavoriteManager.shared.resetAll()
        StepData.shared.resetDailyPicksCache()
        SpeakerAttemptsStore.clearAll()

        NotificationCenter.default.post(name: .init("ProgressDidChange"), object: nil)
        NotificationCenter.default.post(name: .init("FavoritesDidChange"), object: nil)
        NotificationCenter.default.post(name: .init("DailyPicksDidReset"), object: nil)
        NotificationCenter.default.post(name: .init("AppResetAll"), object: nil)

        viewReloadToken = UUID()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TaikaScreenPageTitle(title: "Профиль")
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                List {
                    if let badge = TaikaBuildChannel.badgeTitle {
                        Section {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "hammer.fill")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(theme.currentAccentFill)
                                    .frame(width: 24, alignment: .center)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(badge)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(PD.ColorToken.text)
                                    if let sub = TaikaBuildChannel.badgeSubtitle {
                                        Text(sub)
                                            .font(.caption)
                                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.92))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Text(appVersionLabel)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                                }
                                Spacer(minLength: 0)
                            }
                            .listRowInsets(listRowInsets)
                            .listRowBackground(PD.ColorToken.card.opacity(0.35))
                        }
                    }

                    Section {
                        if auth.isLoggedIn {
                            if let name = auth.displayName, !name.isEmpty {
                                Text(name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                    .listRowInsets(listRowInsets)
                                    .listRowBackground(PD.ColorToken.card.opacity(0.35))
                            }
                            Button("Выйти", role: .destructive) {
                                try? auth.signOut()
                                ProManager.shared.reset()
                            }
                            .listRowInsets(listRowInsets)
                            .listRowBackground(PD.ColorToken.card.opacity(0.35))
                        } else {
                            Button {
                                signInWithAppleTapped()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "apple.logo")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                    Text("Привязать Apple ID")
                                        .font(.body)
                                        .foregroundStyle(PD.ColorToken.text)
                                    if authInProgress {
                                        Spacer(minLength: 8)
                                        ProgressView()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(authInProgress)
                            .listRowInsets(listRowInsets)
                            .listRowBackground(PD.ColorToken.card.opacity(0.35))
                        }
                    } header: {
                        sectionHeader("Аккаунт")
                    }

                    if let msg = authErrorMessage, !auth.isLoggedIn {
                        Section {
                            Text(msg)
                                .font(.footnote)
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .listRowInsets(listRowInsets)
                                .listRowBackground(PD.ColorToken.card.opacity(0.35))
                        }
                    }

                    Section {
                        profileLinkRow(
                            title: pro.isPro ? pro.subscriptionStatusTitle : "Открыть Taika+",
                            subtitle: pro.subscriptionStatusSubtitle,
                            systemImage: "crown.fill"
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showProSheet = true
                        }
                    } header: {
                        sectionHeader("Taika+")
                    }

                    Section {
                        profileLinkRow(
                            title: "Как устроена Taika",
                            subtitle: "Не переводчик · уроки · игры · Спикер",
                            systemImage: "sparkles"
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showOnboarding = true
                        }
                        profileLinkRow(
                            title: "Ещё",
                            subtitle: "Поддержка, сайт, сброс, версия",
                            systemImage: "ellipsis.circle"
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showMoreSheet = true
                        }
                    }
                }
                .id(viewReloadToken)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listSectionSpacing(14)
                .listRowSeparatorTint(PD.ColorToken.stroke.opacity(0.45))
            }
            .padding(.top, Theme.Layout.rootHeaderClearance)
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
            Button("Сбросить", role: .destructive) {
                performFullReset()
            }
        } message: {
            Text("Удалим прогресс уроков, избранное и кэш разминки. Подписка не сбросится.")
        }
        .sheet(isPresented: $showProSheet) {
            ProfileProSheet(
                restoreInFlight: $restoreInFlight,
                onOpenPaywall: {
                    showProSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        overlay.presentPro(reason: .general)
                    }
                },
                onRestore: {
                    Task { await restorePurchasesTapped() }
                }
            )
            .environmentObject(theme)
        }
        .sheet(isPresented: $showMoreSheet) {
            ProfileMoreSheet(
                appVersionLabel: appVersionLabel,
                showResetAllConfirm: $showResetAllConfirm,
                showDebugSheet: $showDebugSheet
            )
            .environmentObject(theme)
        }
        .sheet(isPresented: $showDebugSheet) {
            ProfileDebugSheet()
                .environmentObject(theme)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            TaikaEntryOnboardingView(
                onFinished: { showOnboarding = false },
                onSkipToStart: { showOnboarding = false }
            )
            .environmentObject(theme)
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                AuthService.presentationWindow = window
            }
            Task { @MainActor in
                await ProManager.shared.syncCustomerInfoFromRevenueCat()
                AuthSoftWallState.tryPresentSoftWall(calledFromProfile: true)
            }
        }
    }

    @MainActor
    private func restorePurchasesTapped() async {
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
                    : "Taika+ восстановлен."
            } else {
                storeRestoreMessage = "Активных покупок не найдено."
            }
        } catch {
            storeRestoreMessage = error.localizedDescription
        }
    }

    private func signInWithAppleTapped() {
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
}

// MARK: - Taika+ details

private struct ProfileProSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @ObservedObject private var pro = ProManager.shared
    @Binding var restoreInFlight: Bool
    let onOpenPaywall: () -> Void
    let onRestore: () -> Void

    private var listRowInsets: EdgeInsets {
        EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(theme.currentAccentFill)
                            Text(pro.subscriptionStatusTitle)
                                .font(.headline)
                                .foregroundStyle(PD.ColorToken.text)
                        }
                        Text(pro.subscriptionStatusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(listRowInsets)
                    .listRowBackground(PD.ColorToken.card.opacity(0.35))
                }

                Section {
                    if !pro.isPro {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onOpenPaywall()
                        } label: {
                            Label("Открыть Taika+", systemImage: "crown.fill")
                                .foregroundStyle(PD.ColorToken.text)
                        }
                        .listRowInsets(listRowInsets)
                        .listRowBackground(PD.ColorToken.card.opacity(0.35))
                    } else {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Управление подпиской", systemImage: "creditcard")
                                .foregroundStyle(PD.ColorToken.text)
                        }
                        .listRowInsets(listRowInsets)
                        .listRowBackground(PD.ColorToken.card.opacity(0.35))
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onRestore()
                    } label: {
                        HStack {
                            Label(
                                restoreInFlight ? "Восстановление…" : "Восстановить покупки",
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                            .foregroundStyle(PD.ColorToken.text)
                            Spacer()
                            if restoreInFlight { ProgressView() }
                        }
                    }
                    .disabled(restoreInFlight)
                    .listRowInsets(listRowInsets)
                    .listRowBackground(PD.ColorToken.card.opacity(0.35))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(PD.ColorToken.background)
            .navigationTitle("Taika+")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - More / About

private struct ProfileMoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    let appVersionLabel: String
    @Binding var showResetAllConfirm: Bool
    @Binding var showDebugSheet: Bool

    private var listRowInsets: EdgeInsets {
        EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
    }

    var body: some View {
        NavigationStack {
            List {
                if TaikaBuildChannel.badgeTitle != nil {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(TaikaBuildChannel.badgeTitle ?? "Beta")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PD.ColorToken.text)
                            Text(TaikaBuildChannel.badgeSubtitle ?? "")
                                .font(.caption)
                                .foregroundStyle(PD.ColorToken.textSecondary)
                            Text("Сайт → TestFlight → этот профиль. Пиши фидбек в поддержку.")
                                .font(.caption)
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .listRowInsets(listRowInsets)
                        .listRowBackground(PD.ColorToken.card.opacity(0.35))
                    } header: {
                        Text("Тестирование")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .textCase(.uppercase)
                    }
                }

                Section {
                    moreLink("Поддержка", systemImage: "questionmark.circle") {
                        openURL("https://t.me/taika_support")
                    }
                    moreLink("Сайт taikaa.online", systemImage: "globe") {
                        openURL("https://taikaa.online")
                    }
                    moreLink("Instagram", systemImage: "camera") {
                        openURL("https://www.instagram.com/taika.app")
                    }
                } header: {
                    Text("Связь")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .textCase(.uppercase)
                }

                Section {
                    moreLink("Политика конфиденциальности", systemImage: "hand.raised") {
                        UIApplication.shared.open(TaikaProConfig.Legal.privacyPolicy)
                    }
                    moreLink("Условия использования", systemImage: "doc.text") {
                        UIApplication.shared.open(TaikaProConfig.Legal.termsOfUse)
                    }
                    HStack {
                        Label("Версия", systemImage: "info.circle")
                            .foregroundStyle(PD.ColorToken.text)
                        Spacer()
                        Text(appVersionLabel)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    .listRowInsets(listRowInsets)
                    .listRowBackground(PD.ColorToken.card.opacity(0.35))
                } header: {
                    Text("О приложении")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .textCase(.uppercase)
                }

                Section {
                    Button(role: .destructive) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showResetAllConfirm = true
                        }
                    } label: {
                        Label("Сбросить прогресс", systemImage: "trash")
                    }
                    .listRowInsets(listRowInsets)
                    .listRowBackground(PD.ColorToken.card.opacity(0.35))

                    #if DEBUG
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showDebugSheet = true
                        }
                    } label: {
                        Label("Отладка", systemImage: "wrench.and.screwdriver")
                            .foregroundStyle(PD.ColorToken.text)
                    }
                    .listRowInsets(listRowInsets)
                    .listRowBackground(PD.ColorToken.card.opacity(0.35))
                    #endif
                } header: {
                    Text("Данные")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .textCase(.uppercase)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(PD.ColorToken.background)
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func moreLink(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(PD.ColorToken.text)
        }
        .listRowInsets(listRowInsets)
        .listRowBackground(PD.ColorToken.card.opacity(0.35))
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Debug

private struct ProfileDebugSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @ObservedObject private var pro = ProManager.shared

    var body: some View {
        NavigationStack {
            List {
                #if DEBUG
                Section {
                    Toggle(isOn: Binding(
                        get: { pro.isPro },
                        set: { newValue in
                            pro.setDebugPro(newValue)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    )) {
                        Text("Taika+ режим (тест)")
                            .foregroundStyle(PD.ColorToken.text)
                    }
                    .tint(theme.currentAccentFill)
                    .listRowBackground(PD.ColorToken.background)
                    Button("Сбросить подборку дня") {
                        StepData.shared.resetDailyPicksCache()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .foregroundStyle(PD.ColorToken.text)
                    .listRowBackground(PD.ColorToken.background)
                    Button("Сбросить онбординг v2") {
                        UserDefaults.standard.removeObject(forKey: "taika.onboarding.v2.done")
                        UserDefaults.standard.set(false, forKey: "taika.welcome.seen.v1")
                        TaikaProductDemoFlags.resetAllForDebug()
                        NotificationCenter.default.post(
                            name: TaikaProductDemoFlags.debugResetOnboardingNotification,
                            object: nil
                        )
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .foregroundStyle(PD.ColorToken.text)
                    .listRowBackground(PD.ColorToken.background)
                    Button("Сбросить product-demo (Спикер/Курсы)") {
                        TaikaProductDemoFlags.resetAllForDebug()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .foregroundStyle(PD.ColorToken.text)
                    .listRowBackground(PD.ColorToken.background)
                } header: {
                    Text("Отладка")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .textCase(.uppercase)
                }
                #endif
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(PD.ColorToken.background)
            .navigationTitle("Отладка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

#Preview("Profile View") {
    NavigationStack {
        ProfileView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(OverlayPresenter.shared)
    }
}
