//
//  ProfileView.swift
//  taika
//
//  Created by product on 23.08.2025.
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @ObservedObject private var progress = ProgressManager.shared
    @ObservedObject private var pro = ProManager.shared
    @ObservedObject private var auth = AuthService.shared
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var nav: NavigationIntent

    @State private var showResetAllConfirm = false
    @State private var viewReloadToken = UUID()
    @State private var showPROView = false
    @State private var showSettingsSheet = false
    @State private var authInProgress = false
    @State private var authErrorMessage: String?

    private var state: ProfileDashboardState { progress.publishedState }
    private var pronunciationScore: Int? { state.averagePronunciationScore }

    private func performFullReset() {
        // 1) All progress stores in sync (single source of truth chain)
        ProgressManager.shared.resetAll()
        UserSession.shared.resetAllProgress()  // LessonsManager + UserSession snapshot + FavoriteManager.clearAll()
        StepManager.shared.resetAll()         // in-memory learned so CourseView/Lesson cards show 0
        FavoriteManager.shared.resetAll()
        StepData.shared.resetDailyPicksCache()
        SpeakerAttemptsStore.clearAll()      // pronunciation scores so Speaker starts clean

        // 2) broadcast changes so views/managers refresh
        NotificationCenter.default.post(name: .init("ProgressDidChange"), object: nil)
        NotificationCenter.default.post(name: .init("FavoritesDidChange"), object: nil)
        NotificationCenter.default.post(name: .init("DailyPicksDidReset"), object: nil)
        NotificationCenter.default.post(name: .init("AppResetAll"), object: nil)

        // 3) light UI reload
        viewReloadToken = UUID()

        // 4) success haptic
        let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        let accent = AnyShapeStyle(theme.currentAccentFill)

                        // 1. Аккаунт — вверху
                        PDSection("Аккаунт") {
                            accountBlock(accent: accent)
                        }

                        // 2. Один якорный блок: как ты звучишь
                        VStack(alignment: .leading, spacing: Theme.Layout.sectionTitleToContent) {
                            pronunciationCard(accent: accent)
                        }
                        .padding(.top, Theme.Layout.sectionTop)

                        // 3. Кнопка: улучшить произношение → Speaker
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            nav.requestTab(2)
                        }) {
                            HStack(spacing: PD.Spacing.inner) {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.system(size: 20))
                                Text("Улучшить произношение")
                                    .font(PD.FontToken.body(17, weight: .medium))
                            }
                            .foregroundStyle(PD.ColorToken.text)
                            .frame(maxWidth: .infinity)
                            .padding(PD.Spacing.inner)
                            .background(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).fill(PD.ColorToken.card))
                            .overlay(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).stroke(PD.ColorToken.stroke, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, PD.Spacing.screen)
                        .padding(.top, 8)

                        // 4. Настройки — в конец, минимально
                        PDSection("Настройки") {
                            VStack(spacing: Theme.Layout.Section.itemGap) {
                                settingsRow(icon: "globe", title: "Язык интерфейса", showChevron: true) { showSettingsSheet = true }
                                settingsRowTheme()
                                settingsRow(icon: "questionmark.circle", title: "Поддержка", showChevron: true, action: openSupportURL)
                            }
                            .padding(.horizontal, PD.Spacing.screen)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Theme.Layout.sectionGap)
                    .safeAreaPadding(.bottom, Theme.Layout.pageBottomSafeGap)
                }
                .scrollIndicators(.hidden)
            }
            .id(viewReloadToken)
            .sheet(isPresented: $showSettingsSheet) {
                ProfileSettingsSheet(
                    showResetAllConfirm: $showResetAllConfirm,
                    performFullReset: performFullReset
                )
            }
        }
        .task {
            progress.refreshProfileState()
        }
        .onAppear {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                AuthService.presentationWindow = window
            }
            progress.refreshProfileState()
            Task { @MainActor in AuthSoftWallState.tryPresentSoftWall(calledFromProfile: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .progressDidChange)) { _ in
            progress.refreshProfileState()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProgressDidChange"))) { _ in
            progress.refreshProfileState()
        }
        .fullScreenCover(isPresented: $showPROView) {
            PROView(courseId: nil, initialPage: 0) {
                showPROView = false
            }
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

    // MARK: - MVP blocks

    @ViewBuilder
    private func accountBlock(accent: AnyShapeStyle) -> some View {
        Group {
            if auth.isLoggedIn {
                VStack(alignment: .leading, spacing: 8) {
                    if let name = auth.displayName, !name.isEmpty {
                        Text(name)
                            .font(PD.FontToken.body(18, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.text)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PD.ColorToken.accent)
                        Text("Аккаунт привязан")
                            .font(PD.FontToken.body(17, weight: .medium))
                            .foregroundStyle(PD.ColorToken.text)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                        Text("В облаке")
                            .font(PD.FontToken.caption(15, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    HStack {
                        Spacer()
                        Button("Выйти") {
                            try? auth.signOut()
                            ProManager.shared.reset()
                        }
                        .font(PD.FontToken.caption(13, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                }
                .padding(PD.Spacing.inner)
                .background(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).fill(PD.ColorToken.card))
                .overlay(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).stroke(PD.ColorToken.stroke, lineWidth: 1))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: signInWithAppleTapped) {
                        HStack(spacing: PD.Spacing.inner) {
                            if authInProgress {
                                TaikaLoadingView(label: "", compact: true)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Привязать Apple ID")
                                    .font(PD.FontToken.body(17, weight: .medium))
                            }
                        }
                        .foregroundStyle(PD.ColorToken.text)
                        .frame(maxWidth: .infinity)
                        .padding(PD.Spacing.inner)
                        .background(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).fill(PD.ColorToken.card))
                        .overlay(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).stroke(PD.ColorToken.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(authInProgress)
                    if let msg = authErrorMessage {
                        Text(msg)
                            .font(PD.FontToken.caption(13, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, PD.Spacing.screen)
    }

    private func pronunciationCard(accent: AnyShapeStyle) -> some View {
        let shape = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        let scoreText: String = pronunciationScore.map { "\($0)%" } ?? "—"
        return ZStack {
            Theme.Surfaces.card(shape)
            VStack(spacing: 12) {
                Text(scoreText)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .monospacedDigit()
                Text("средний балл произношения")
                    .font(PD.FontToken.caption(13, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                if !pro.isPro {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                        Text("разбор произношения в PRO")
                            .font(PD.FontToken.caption(12, weight: .medium))
                    }
                    .foregroundStyle(PD.ColorToken.textSecondary)
                }
            }
            .padding(24)
        }
        .overlay(shape.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
        .clipShape(shape)
        .padding(.horizontal, PD.Spacing.screen)
    }

    private func settingsRow(icon: String, title: String, showChevron: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: PD.Spacing.inner) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(PD.ColorToken.text)
                Text(title)
                    .font(PD.FontToken.body(17, weight: .medium))
                    .foregroundStyle(PD.ColorToken.text)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, PD.Spacing.inner)
            .background(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).fill(PD.ColorToken.card))
            .overlay(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).stroke(PD.ColorToken.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func settingsRowTheme() -> some View {
        let isDark = theme.preferredScheme == .dark
        return Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            theme.toggleTheme()
        }) {
            HStack(spacing: PD.Spacing.inner) {
                Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(PD.ColorToken.text)
                Text("Тема")
                    .font(PD.FontToken.body(17, weight: .medium))
                    .foregroundStyle(PD.ColorToken.text)
                Spacer()
                Text(isDark ? "Тёмная" : "Светлая")
                    .font(PD.FontToken.caption(15, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, PD.Spacing.inner)
            .background(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).fill(PD.ColorToken.card))
            .overlay(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).stroke(PD.ColorToken.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Поддержка: Telegram (фидбек-канал для фаундера)
    private func openSupportURL() {
        if let url = URL(string: "https://t.me/taika_support") {
            UIApplication.shared.open(url)
        } else if let fallback = URL(string: "https://taika.app") {
            UIApplication.shared.open(fallback)
        }
    }
}


// MARK: - Settings sheet (шестерёнка: настройки + админ в DEBUG)
private struct ProfileSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pro = ProManager.shared
    @Binding var showResetAllConfirm: Bool
    let performFullReset: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    openSupportURL()
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("Поддержка")
                            .font(PD.FontToken.body(17, weight: .medium))
                    }
                    .foregroundStyle(PD.ColorToken.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)

                #if DEBUG
                VStack(spacing: 0) {
                    AdminToggleRow(
                        icon: "crown.fill",
                        title: "pro режим",
                        subtitle: "тест: free ↔ pro",
                        isOn: Binding(
                            get: { pro.isPro },
                            set: { newValue in
                                pro.setDebugPro(newValue)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        )
                    )
                    AdminDivider()
                    AdminActionRow(icon: "trash", title: "сбросить всё", subtitle: "прогресс, лайки, daily picks", onTap: { showResetAllConfirm = true })
                    AdminDivider()
                    AdminActionRow(icon: "clock.arrow.circlepath", title: "сбросить подборку дня", subtitle: "очистить кэш daily picks", onTap: {
                        StepData.shared.resetDailyPicksCache()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    })
                }
                .background(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).fill(PD.ColorToken.card))
                .overlay(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).stroke(PD.ColorToken.stroke, lineWidth: 1))
                .padding(.horizontal)
                #endif
            }
            .padding(.vertical)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                    .foregroundStyle(PD.ColorToken.text)
                }
            }
        }
        .alert("сбросить всё?", isPresented: $showResetAllConfirm) {
            Button("отмена", role: .cancel) {}
            Button("сбросить", role: .destructive) {
                performFullReset()
                showResetAllConfirm = false
                dismiss()
            }
        } message: {
            Text("удалим прогресс, лайки, кэш подборки дня и перезапустим ui")
        }
    }

    private func openSupportURL() {
        if let url = URL(string: "https://t.me/taika_support") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Admin rows (ProfileView local)
private struct AdminToggleRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: PD.Spacing.inner) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PD.ColorToken.chip)
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(PD.ColorToken.stroke, lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(PD.ColorToken.text)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PD.FontToken.body(17, weight: .regular))
                    .foregroundColor(PD.ColorToken.text)
                Text(subtitle)
                    .font(PD.FontToken.caption(13, weight: .medium))
                    .foregroundColor(PD.ColorToken.textSecondary)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, PD.Spacing.inner)
        .padding(.vertical, 14)
    }
}

private struct AdminActionRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: PD.Spacing.inner) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PD.ColorToken.chip)
                        .frame(width: 42, height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(PD.ColorToken.stroke, lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(PD.ColorToken.text)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PD.FontToken.body(17, weight: .regular))
                        .foregroundColor(PD.ColorToken.text)
                    Text(subtitle)
                        .font(PD.FontToken.caption(13, weight: .medium))
                        .foregroundColor(PD.ColorToken.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PD.ColorToken.textSecondary)
            }
            .padding(.horizontal, PD.Spacing.inner)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

private struct AdminDivider: View {
    var body: some View {
        Rectangle()
            .fill(PD.ColorToken.stroke)
            .frame(height: 1)
            .padding(.leading, 68)
    }
}


// MARK: - Preview
#Preview("Profile View") {
    NavigationStack {
        ProfileView()
            .environmentObject(ThemeManager.shared)
            .environmentObject(NavigationIntent())
    }
    .preferredColorScheme(.dark)
}
