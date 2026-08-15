//
//  TaikaProSuccessView.swift
//  taika
//
//  Явный момент после активации триала / подписки.
//

import SwiftUI

struct TaikaProSuccessView: View {
    let onContinue: () -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var pro = ProManager.shared
    @State private var appeared = false
    @State private var crownBounce: CGFloat = 0.78

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onContinue() }

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(theme.currentAccentFill.opacity(0.2))
                            .frame(width: 96, height: 96)
                            .blur(radius: 2)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                            .scaleEffect(crownBounce)
                    }
                    .padding(.top, 8)

                    Text(pro.isInIntroTrial ? "Пробный период открыт" : "Taika+ с тобой")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(CD.ColorToken.text)
                        .multilineTextAlignment(.center)

                    Text(pro.subscriptionStatusSubtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    if pro.isInIntroTrial {
                        Text("Закрепляй голосом и играми — \(TaikaProConfig.introTrialDaysPhrase), отмена в любой момент.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    } label: {
                        Text("К урокам")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(white: 0.1))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(theme.currentAccentFill))
                    }
                    .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
                    .padding(.top, 8)
                }
                .padding(24)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(CD.ColorToken.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: 1)
                )
                .padding(.horizontal, 28)
                .scaleEffect(appeared ? 1 : 0.94)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                appeared = true
                crownBounce = 1.0
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TaikaProSuccessView(onContinue: {})
    }
    .environmentObject(ThemeManager.shared)
}
