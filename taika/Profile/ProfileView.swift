//
//  ProfileView.swift
//  taika
//
//  Created by product on 23.08.2025.
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @ObservedObject private var pro = ProManager.shared
    @ObservedObject private var auth = AuthService.shared
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var overlay: OverlayPresenter

    @State private var showResetAllConfirm = false
    @State private var viewReloadToken = UUID()
    @State private var showSettingsSheet = false
    @State private var authInProgress = false
    @State private var authErrorMessage: String?
    @State private var storeRestoreMessage: String?
    @State private var restoreInFlight = false

    private var listRowInsets: EdgeInsets {
        EdgeInsets(top: 10, leading: PD.Spacing.screen, bottom: 10, trailing: PD.Spacing.screen)
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

    @ViewBuilder
    private func profileValueRow(title: String, systemImage: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .frame(width: 24, alignment: .center)
                Text(title)
                    .font(.body)
                    .foregroundStyle(PD.ColorToken.text)
                Spacer()
                Text(value)
                    .font(.body)
                    .foregroundStyle(PD.ColorToken.textSecondary)
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
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
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
                Section {
                    TaikaFMRow(scope: .profile, mode: .typing, showBubble: false, repeats: true)
                        .listRowInsets(EdgeInsets(top: 8, leading: PD.Spacing.screen, bottom: 8, trailing: PD.Spacing.screen))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    sectionHeader("ТАЙКА FM")
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
                    if pro.isPro {
                        HStack(spacing: 14) {
                            Image(systemName: "crown.fill")
                                .font(.body.weight(.medium))
                                .foregroundStyle(theme.currentAccentFill)
                                .frame(width: 24, alignment: .center)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Taika+ активен")
                                    .font(.body)
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("Расширенная разминка, курсы и Спикер")
                                    .font(.caption)
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.92))
                            }
                            Spacer(minLength: 0)
                        }
                        .listRowInsets(listRowInsets)
                        .listRowBackground(PD.ColorToken.card.opacity(0.35))
                    } else {
                        profileLinkRow(
                            title: "Открыть Taika+",
                            subtitle: "10 карточек в день, курсы и Спикер",
                            systemImage: "crown.fill"
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            overlay.presentPro(reason: .general)
                        }
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await restorePurchasesTapped() }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.body.weight(.medium))
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .frame(width: 24, alignment: .center)
                            Text(restoreInFlight ? "Восстановление…" : "Восстановить покупки")
                                .font(.body)
                                .foregroundStyle(PD.ColorToken.text)
                            Spacer()
                            if restoreInFlight {
                                ProgressView()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(restoreInFlight)
                    .listRowInsets(listRowInsets)
                    .listRowBackground(PD.ColorToken.card.opacity(0.35))
                } header: {
                    sectionHeader("Taika+")
                }

                Section {
                    profileLinkRow(title: "Поддержка", systemImage: "questionmark.circle") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        openSupportURL()
                    }
                    #if DEBUG
                    profileLinkRow(title: "Отладка", systemImage: "wrench.and.screwdriver") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showSettingsSheet = true
                    }
                    #endif
                } header: {
                    sectionHeader("Основное")
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
        .sheet(isPresented: $showSettingsSheet) {
            ProfileSettingsSheet(
                showResetAllConfirm: $showResetAllConfirm,
                performFullReset: performFullReset
            )
            .environmentObject(theme)
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                AuthService.presentationWindow = window
            }
            Task { @MainActor in
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
                storeRestoreMessage = "Подписка восстановлена — Taika+ снова активен."
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
                SyncManager.shared.onUserDidLogin(userId: AuthService.shared.currentUserID ?? "")
                authInProgress = false
            } catch AuthService.AuthError.cancelled {
                authInProgress = false
            } catch {
                authErrorMessage = error.localizedDescription
                authInProgress = false
            }
        }
    }

    private func openSupportURL() {
        if let url = URL(string: "https://t.me/taika_support") {
            UIApplication.shared.open(url)
        } else if let fallback = URL(string: "https://taika.app") {
            UIApplication.shared.open(fallback)
        }
    }
}

// MARK: - Sheet: отладка (DEBUG)
private struct ProfileSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @ObservedObject private var pro = ProManager.shared
    @Binding var showResetAllConfirm: Bool
    let performFullReset: () -> Void

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
                    Button("Сбросить всё", role: .destructive) {
                        showResetAllConfirm = true
                    }
                    .listRowBackground(PD.ColorToken.background)
                    Button("Сбросить подборку дня") {
                        StepData.shared.resetDailyPicksCache()
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
            .listRowSeparatorTint(PD.ColorToken.stroke.opacity(0.35))
            .background(PD.ColorToken.background)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .alert("Сбросить всё?", isPresented: $showResetAllConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) {
                performFullReset()
                showResetAllConfirm = false
                dismiss()
            }
        } message: {
            Text("Удалим прогресс, избранное и кэш подборки дня.")
        }
    }
}

// MARK: - Preview
#Preview("Profile View") {
    NavigationStack {
        ProfileView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(OverlayPresenter.shared)
    }
}
