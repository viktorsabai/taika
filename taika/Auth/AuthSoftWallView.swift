//
//  AuthSoftWallView.swift
//  taika
//
//  Soft wall «Закрепи результат» — sheet в текущей айдентике (как paywall auth).
//
//  Логика показа (AuthSoftWallState.tryPresentSoftWall):
//  - Только если пользователь НЕ залогинен и есть прогресс.
//  - Триггер 1: закрытие экрана успеха урока в StepView.
//  - Триггер 2: открытие вкладки Профиль (onAppear в ProfileView).
//  - Не чаще одного раза в 7 дней (cooldown в UserDefaults).
//

import SwiftUI
import UIKit
import AuthenticationServices

// MARK: - Контент шторки

struct AuthSoftWallView: View {
    let masteryPercent: Int
    let streakDays: Int
    let onDismiss: () -> Void

    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var authInProgress = false
    @State private var authErrorMessage: String?
    @State private var showSuccess = false

    private let legalText = "Нажимая, ты соглашаешься с условиями использования и политикой конфиденциальности."

    var body: some View {
        Group {
            if showSuccess {
                successView
            } else {
                mainContent
            }
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.backgroundPrimary.ignoresSafeArea())
    }

    private var successView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
            Text("Прогресс сохранён")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PD.ColorToken.text)
            Text("Аккаунт привязан — результат не пропадёт при смене телефона.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 48)
    }

    private var mainContent: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(PD.ColorToken.textSecondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .accessibilityHidden(true)

            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
                .padding(.top, 4)

            Text("Закрепи свой результат")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PD.ColorToken.text)
                .multilineTextAlignment(.center)

            Text("Прогресс пока только на этом телефоне. Привяжи аккаунт — \(masteryPercent)% мастерства и стрик не потеряются.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)

            HStack(spacing: 12) {
                softStat(label: "Мастерство", value: "\(masteryPercent)%")
                softStat(label: "Стрик", value: "\(max(streakDays, 0)) дн.")
            }

            if let msg = authErrorMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.currentAccentFill)
                    .multilineTextAlignment(.center)
            }

            Button {
                startSignInWithApple()
            } label: {
                HStack(spacing: 8) {
                    if authInProgress {
                        ProgressView().tint(.white)
                    }
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16, weight: .semibold))
                    Text(authInProgress ? "Входим…" : "Sign in with Apple")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule(style: .continuous).fill(Color.black))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
            .disabled(authInProgress)
            .accessibilityLabel("Войти с Apple")

            Button("Позже") {
                onDismiss()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(PD.ColorToken.textSecondary)
            .disabled(authInProgress)
            .buttonStyle(.plain)

            Text(legalText)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }

    private func softStat(label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(theme.currentAccentFill)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.currentAccentFill.opacity(0.22), lineWidth: 1)
        )
    }

    private func startSignInWithApple() {
        authInProgress = true
        authErrorMessage = nil
        Task {
            do {
                try await auth.signInWithApple()
                if let uid = auth.currentUserID {
                    SyncManager.shared.onUserDidLogin(userId: uid)
                }
                showSuccess = true
                authInProgress = false
                try? await Task.sleep(nanoseconds: 500_000_000)
                onDismiss()
            } catch AuthService.AuthError.cancelled {
                authInProgress = false
            } catch {
                authErrorMessage = error.localizedDescription
                authInProgress = false
            }
        }
    }
}

// MARK: - Хост для показа в виде sheet (вызывается из AppShell)

struct AuthSoftWallSheetHost: View {
    let masteryPercent: Int
    let streakDays: Int
    let onDismiss: () -> Void

    @State private var showSheet = true

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showSheet) {
                AuthSoftWallView(
                    masteryPercent: masteryPercent,
                    streakDays: streakDays,
                    onDismiss: {
                        showSheet = false
                        onDismiss()
                    }
                )
                .environmentObject(ThemeManager.shared)
                .presentationDetents([.fraction(0.58), .medium])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
                .presentationBackground(Theme.Colors.backgroundPrimary)
            }
            .onChange(of: showSheet) { _, new in
                if !new { onDismiss() }
            }
            .onAppear {
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                   let window = scene.windows.first(where: { $0.isKeyWindow }) {
                    AuthService.presentationWindow = window
                }
            }
    }
}
