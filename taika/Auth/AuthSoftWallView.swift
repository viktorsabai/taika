//
//  AuthSoftWallView.swift
//  taika
//
//  Мягкое окно «войти» — тот же нижний лист, что в профиле.
//  Когда показывать: AuthSoftWallState (не залогинен, есть прогресс, раз в 7 дней).
//

import SwiftUI
import UIKit

struct AuthSoftWallView: View {
    let masteryPercent: Int
    let streakDays: Int
    let onDismiss: () -> Void

    @ObservedObject private var auth = AuthService.shared
    @State private var authInProgress = false
    @State private var authErrorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ProfileGlassBackdrop {
                VStack(alignment: .leading, spacing: 14) {
                    ProfileDestinationIntro(
                        eyebrow: "АККАУНТ",
                        title: showSuccess ? "Прогресс сохранён" : "Сохрани результат",
                        subtitle: showSuccess
                            ? "Аккаунт привязан. Результат не пропадёт при смене телефона."
                            : progressLine
                    )
                    if !showSuccess {
                        ProfileGlassRow(
                            title: authInProgress ? "Входим…" : "Войти с Apple",
                            subtitle: authErrorMessage ?? "Прогресс перенесётся на это устройство",
                            systemImage: "apple.logo",
                            trailing: authInProgress ? "hourglass" : "chevron.right"
                        ) {
                            guard !authInProgress else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            startSignInWithApple()
                        }
                        .environmentObject(ThemeManager.shared)
                        .opacity(authInProgress ? 0.72 : 1)
                        Text("Нажимая, ты соглашаешься с условиями использования и политикой конфиденциальности.")
                            .font(PD.FontToken.caption(12))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, PD.Spacing.screen)
                .padding(.top, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Аккаунт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { onDismiss() }
                        .disabled(authInProgress)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var progressLine: String {
        if masteryPercent <= 0, streakDays <= 0 {
            return "Пока он только на этом телефоне. Войди — и он останется с тобой."
        }
        return "Пока он только на этом телефоне. Войди — и \(masteryPercent)% не пропадут."
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
                try? await Task.sleep(nanoseconds: 700_000_000)
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
