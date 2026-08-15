//
//  TaikaQuickStartView.swift
//  taika
//
//  После ценности — один выбор: База / голос / каталог.
//

import SwiftUI

enum TaikaQuickStartAction: Equatable {
    case baseCourse
    case speakerVoice
    case catalog
}

struct TaikaQuickStartView: View {
    let onPick: (TaikaQuickStartAction) -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @State private var appeared = false
    @State private var cardsVisible = false
    @State private var cursorOn = true

    var body: some View {
        ZStack {
            WelcomeSpaceBackdropView()

            Circle()
                .fill(theme.currentAccentFill.opacity(0.2))
                .frame(width: 260, height: 260)
                .blur(radius: 64)
                .offset(y: -160)
                .scaleEffect(appeared ? 1 : 0.8)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("tai")
                        .font(.custom("Onmark Trial", size: 26))
                        .foregroundStyle(.white.opacity(0.92))
                    Text("kAAA")
                        .font(.custom("Onmark Trial", size: 26))
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                }
                .padding(.top, 28)
                .opacity(appeared ? 1 : 0)

                VStack(spacing: 10) {
                    Text("С чего начнём?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("один шаг — и ты уже внутри")
                        Text("_")
                            .foregroundStyle(theme.currentAccentTintColor)
                            .opacity(cursorOn ? 1 : 0.12)
                    }
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
                }
                .padding(.top, 28)
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    startCard(
                        title: "Начать Базу",
                        subtitle: "Разговорный старт — первые фразы и тон",
                        systemImage: "graduationcap.fill",
                        prominent: true,
                        delayIndex: 0
                    ) {
                        onPick(.baseCourse)
                    }

                    startCard(
                        title: "Сначала голос",
                        subtitle: "Скажи сам — почувствуй Спикер",
                        systemImage: "mic.fill",
                        prominent: false,
                        delayIndex: 1
                    ) {
                        onPick(.speakerVoice)
                    }

                    startCard(
                        title: "Смотреть курсы",
                        subtitle: "Каталог сценариев целиком",
                        systemImage: "square.grid.2x2.fill",
                        prominent: false,
                        delayIndex: 2
                    ) {
                        onPick(.catalog)
                    }
                }
                .padding(.horizontal, 22)
                .opacity(cardsVisible ? 1 : 0)

                Spacer(minLength: 36)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                    cardsVisible = true
                }
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            cursorOn.toggle()
        }
    }

    private func startCard(
        title: String,
        subtitle: String,
        systemImage: String,
        prominent: Bool,
        delayIndex: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(prominent ? Color.black.opacity(0.12) : Color.white.opacity(0.08))
                        .frame(width: 46, height: 46)
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            prominent
                            ? AnyShapeStyle(Color(white: 0.12))
                            : AnyShapeStyle(theme.currentAccentFill)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(prominent ? Color(white: 0.1) : .white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(prominent ? Color(white: 0.1).opacity(0.7) : .white.opacity(0.55))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(prominent ? Color(white: 0.1).opacity(0.45) : .white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                Group {
                    if prominent {
                        Capsule(style: .continuous).fill(theme.currentAccentFill)
                    } else {
                        Capsule(style: .continuous).fill(Color.white.opacity(0.07))
                    }
                }
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        prominent
                        ? Color.clear
                        : Color.white.opacity(0.18),
                        lineWidth: 1
                    )
            )
            .overlay {
                if prominent {
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.16), .clear], startPoint: .top, endPoint: .center))
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
        .offset(y: cardsVisible ? 0 : 24 + CGFloat(delayIndex) * 10)
        .opacity(cardsVisible ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.84).delay(Double(delayIndex) * 0.07),
            value: cardsVisible
        )
    }
}

#Preview {
    TaikaQuickStartView(onPick: { _ in })
        .environmentObject(ThemeManager.shared)
}
