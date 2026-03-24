//
//  AuthSoftWallView.swift
//  taika
//
//  Мягкое окно «Закрепи результат» — bottom sheet с копи, статистикой и кнопками входа.
//
//  Логика показа (AuthSoftWallState.tryPresentSoftWall):
//  - Только если пользователь НЕ залогинен и есть прогресс (хотя бы один выученный шаг или урок).
//  - Триггер 1: закрытие экрана успеха урока (X или тап по фону) в StepView.
//  - Триггер 2: открытие вкладки Профиль (onAppear в ProfileView).
//  - Не чаще одного раза в 7 дней (cooldown в UserDefaults).
//

import SwiftUI
import UIKit
import AuthenticationServices

// MARK: - Системная кнопка Sign in with Apple (UIViewRepresentable)

private struct AppleSignInButtonRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: .black
        )
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}

// MARK: - Контент шторки

struct AuthSoftWallView: View {
    let masteryPercent: Int
    let streakDays: Int
    let onDismiss: () -> Void

    @ObservedObject private var auth = AuthService.shared
    @State private var authInProgress = false
    @State private var authErrorMessage: String?
    @State private var showSuccess = false
    @EnvironmentObject private var theme: ThemeManager

    private let legalText = "Нажимая, ты соглашаешься с условиями использования и политикой конфиденциальности."

    var body: some View {
        Group {
            if showSuccess {
                successView
            } else {
                mainContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PD.ColorToken.background)
        .padding(.horizontal, PD.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
            Text("Данные синхронизированы")
                .font(PD.FontToken.body(18, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Закрепи свой результат")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PD.ColorToken.text)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Твой прогресс пока хранится только на этом телефоне. Привяжи аккаунт, чтобы не потерять достигнутые \(masteryPercent)% Mastery и Streak.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 24) {
                    statPill(label: "Мастерство", value: "\(masteryPercent)%")
                    statPill(label: "Стрик", value: "\(streakDays) дн.")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(PD.ColorToken.card))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PD.ColorToken.stroke, lineWidth: 1))

                VStack(spacing: 12) {
                    Button {
                        startSignInWithApple()
                    } label: {
                        AppleSignInButtonRepresentable()
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .allowsHitTesting(false)
                    }
                    .buttonStyle(.plain)
                    .disabled(authInProgress)

                    Button {
                        // Telegram — скоро
                    } label: {
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

                if authInProgress {
                    TaikaLoadingView(label: "Вход…", compact: true)
                        .frame(maxWidth: .infinity)
                }

                if let msg = authErrorMessage {
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }

                Text(legalText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PD.FontToken.caption(12, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(PD.Radius.card)
                .presentationBackground(.ultraThinMaterial)
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
