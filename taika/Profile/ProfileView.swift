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
    @ObservedObject private var profile = ProfileManager.shared
    @ObservedObject private var auth = AuthService.shared
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent

    @State private var showResetAllConfirm = false
    @State private var viewReloadToken = UUID()
    @State private var showDebugSheet = false
    @State private var showValues = false
    @State private var showProSheet = false
    @State private var showStatistics = false
    @State private var showSupport = false
    @State private var showLegal = false
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
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(PD.ColorToken.card.opacity(0.38), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.58), lineWidth: 1))
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
            ZStack {
                PD.ColorToken.background
                    .ignoresSafeArea()
                Circle()
                    .fill(theme.currentAccentFill)
                    .frame(width: 280, height: 280)
                    .blur(radius: 110)
                    .opacity(0.10)
                    .offset(x: 130, y: -300)
                Circle()
                    .fill(Color.purple.opacity(0.22))
                    .frame(width: 220, height: 220)
                    .blur(radius: 100)
                    .opacity(0.10)
                    .offset(x: -150, y: 260)
            }

            VStack(spacing: 0) {
                TaikaScreenPageTitle(title: "Профиль")
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                ScrollView(showsIndicators: false) {
                    ProfileRootContent(
                        appVersionLabel: appVersionLabel,
                        authInProgress: authInProgress,
                        authErrorMessage: authErrorMessage,
                        restoreInFlight: restoreInFlight,
                        onAppleID: { signInWithAppleTapped() },
                        onRestore: { Task { await restorePurchasesTapped() } },
                        onTaikaPlus: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showProSheet = true
                        },
                        onRhythm: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showStatistics = true
                        },
                        onValues: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showValues = true
                        },
                        onSupport: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showSupport = true
                        },
                        onLegal: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showLegal = true
                        },
                        onReset: { showResetAllConfirm = true },
                        onDebug: { showDebugSheet = true }
                    )
                    .id(viewReloadToken)
                    .padding(.horizontal, PD.Spacing.screen)
                    .padding(.top, 12)
                    // Keep the last Profile rows above the persistent bottom tab bar.
                    .padding(.bottom, 140)
                }
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
        .sheet(isPresented: $showStatistics) {
            ProfileStatisticsView()
                .environmentObject(theme)
                .environmentObject(nav)
        }
        .sheet(isPresented: $showSupport) {
            ProfileSupportView()
                .environmentObject(theme)
        }
        .sheet(isPresented: $showLegal) {
            ProfileLegalView()
                .environmentObject(theme)
        }
        .sheet(isPresented: $showDebugSheet) {
            ProfileDebugSheet()
                .environmentObject(theme)
        }
        .fullScreenCover(isPresented: $showValues) {
            ProfileValuesView()
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

    var body: some View {
        NavigationStack {
            ProfileGlassBackdrop {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ProfileDestinationIntro(
                            eyebrow: "TAIKA+ ACCESS",
                            title: pro.subscriptionStatusTitle,
                            subtitle: pro.subscriptionStatusSubtitle
                        )
                        ProfileGlassRow(
                            title: pro.isPro ? "Taika+ открыт" : "Открыть Taika+",
                            subtitle: pro.isPro ? "Курсы, Speaker и игры доступны" : "7 дней бесплатно — разминка, курсы и Speaker",
                            systemImage: "crown.fill",
                            trailing: pro.isPro ? "checkmark" : "chevron.right"
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if pro.isPro {
                                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            } else {
                                onOpenPaywall()
                            }
                        }
                        .environmentObject(theme)
                        ProfileGlassRow(
                            title: restoreInFlight ? "Восстановление…" : "Восстановить покупки",
                            subtitle: pro.isPro ? "Проверить доступ на этом Apple ID" : "Если ты уже покупал Taika+",
                            systemImage: "arrow.triangle.2.circlepath",
                            trailing: restoreInFlight ? "hourglass" : "chevron.right"
                        ) {
                            guard !restoreInFlight else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onRestore()
                        }
                        .environmentObject(theme)
                        .opacity(restoreInFlight ? 0.72 : 1)
                        Text("Доступ и покупки синхронизируются через Apple ID. Если что-то не совпало, открой поддержку из профиля.")
                            .font(PD.FontToken.caption(12))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, PD.Spacing.screen)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
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
    @Binding var showLegal: Bool

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
                    moreLink("Сайт taikaa.online", systemImage: "globe") {
                        openURL("https://taikaa.online")
                    }
                    moreLink("Instagram", systemImage: "camera") {
                        openURL("https://www.instagram.com/taika.app")
                    }
                } header: {
                    Text("Ссылки")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .textCase(.uppercase)
                }

                Section {
                    moreLink("Правовые документы", systemImage: "doc.on.doc") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showLegal = true
                        }
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
