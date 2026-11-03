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

    private var isOpen: Bool { pro.isPro }

    private var title: String {
        if !isOpen { return "Подписка ещё не открылась" }
        if pro.isInIntroTrial { return "Пробный период открыт" }
        return "Taika Pro с тобой"
    }

    private var subtitle: String {
        if !isOpen {
            return "Оплата прошла. Открой профиль → Покупки, если доступ не появится сам."
        }
        if pro.isInIntroTrial {
            return "\(TaikaProConfig.introTrialDaysPhrase) бесплатно. Отмена в любой момент в Apple ID."
        }
        return pro.subscriptionStatusSubtitle
    }

    var body: some View {
        ZStack {
            Color(red: 13 / 255, green: 13 / 255, blue: 15 / 255)
                .opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture { onContinue() }

            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Gradients.accentText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onContinue()
                } label: {
                    Text(isOpen ? "К урокам" : "Понятно")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(white: 0.1))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule().fill(theme.currentAccentFill))
                }
                .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
                .padding(.top, 4)
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
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                appeared = true
            }
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
