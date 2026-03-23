//
//  SplashView.swift
//  taika
//
//  Загрузочный экран: название приложения как в хедере + анимация появления.
//

import SwiftUI

// MARK: - Split‑Flap Letter (masked split, readable + divider)
private struct SplitFlapLetter: View {
    let target: String
    let accent: Bool
    var onSettle: (() -> Void)? = nil

    // readable charset: A–Z + a–z
    private let charset: [String] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz").map { String($0) }

    // state
    @State private var current: String = ""
    @State private var running = true
    @State private var angleTop: CGFloat = 0
    @State private var angleBottom: CGFloat = 0
    @State private var interimAlpha: Double = 0.92
    @State private var interimAccent: Bool = false

    // tuning
    var startDelay: TimeInterval = 0.0
    var tick: TimeInterval = 0.075
    var cycles: Int = 12
    var tileSize: CGSize = CGSize(width: 60, height: 90)
    var fontSize: CGFloat = 68

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.98, green: 0.52, blue: 0.80),
                     Color(red: 0.91, green: 0.62, blue: 0.98)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        let glyph = current.isEmpty ? target : current
        let runningStyle: AnyShapeStyle = interimAccent
            ? AnyShapeStyle(accentGradient)
            : AnyShapeStyle(Color.white.opacity(interimAlpha))
        let finalStyle: AnyShapeStyle = accent ? AnyShapeStyle(accentGradient) : AnyShapeStyle(Color.white)

        return ZStack {
            // Tile background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))

            // Divider line
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)

            // TOP half (masked)
            ZStack {
                Text(glyph)
                    .font(.custom("ONMARK Trial", size: fontSize))
                    .kerning(0.8)
                    .foregroundStyle(running ? runningStyle : finalStyle)
                    .minimumScaleFactor(0.85)
                    .frame(width: tileSize.width, height:
                            tileSize.height, alignment: .center)
            }
            .mask(
                VStack(spacing: 0) {
                    Color.white.frame(height: tileSize.height/2)
                    Color.clear
                }
            )
            .rotation3DEffect(.degrees(angleTop), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.7)

            // BOTTOM half (masked)
            ZStack {
                Text(glyph)
                    .font(.custom("ONMARK Trial", size: fontSize))
                    .kerning(0.8)
                    .foregroundStyle(running ? runningStyle : finalStyle)
                    .minimumScaleFactor(0.85)
                    .frame(width: tileSize.width, height: tileSize.height, alignment: .center)
            }
            .mask(
                VStack(spacing: 0) {
                    Color.clear
                    Color.white.frame(height: tileSize.height/2)
                }
            )
            .rotation3DEffect(.degrees(angleBottom), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.7)
        }
        .frame(width: tileSize.width, height: tileSize.height)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) { start() }
        }
    }

    private func start() {
        current = charset.randomElement() ?? target
        var remaining = cycles
        running = true

        func flipOnce(to char: String, localTick: TimeInterval, settle: Bool) {
            // top flips down
            withAnimation(.easeIn(duration: localTick/2)) { angleTop = -90 }
            DispatchQueue.main.asyncAfter(deadline: .now() + localTick/2) {
                current = char
                withAnimation(.easeOut(duration: localTick/2)) { angleTop = 0 }
                // bottom flips up
                withAnimation(.easeIn(duration: localTick/2)) { angleBottom = 90 }
                DispatchQueue.main.asyncAfter(deadline: .now() + localTick/2) {
                    withAnimation(.easeOut(duration: localTick/2)) { angleBottom = 0 }
                    if settle {
                        running = false
                        DispatchQueue.main.async { onSettle?() }
                    }
                }
            }
        }

        func loop() {
            guard running else { return }
            let progress = 1.0 - Double(remaining) / Double(max(1, cycles))
            // decelerate towards the end
            let localTick = tick * (0.75 + 1.8 * pow(progress, 1.25))

            if remaining > 0 {
                remaining -= 1
                var next = charset.randomElement() ?? target
                // слегка мешаем регистр (невысокая доля для читабельности)
                if Double.random(in: 0...1) < 0.18 { next = next.lowercased() }
                interimAlpha = Double.random(in: 0.7...0.96)
                interimAccent = Double.random(in: 0...1) < 0.10
                flipOnce(to: next, localTick: localTick, settle: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + localTick) { loop() }
            } else {
                interimAlpha = 1.0
                interimAccent = false
                flipOnce(to: target, localTick: tick * 1.9, settle: true)
            }
        }
        loop()
    }
}

// MARK: - Gradient Spinner
private struct GradientSpinner: View {
    let size: CGFloat
    @State private var rotate = false
    private var gradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98),
                Color(red: 0.98, green: 0.52, blue: 0.80)
            ]),
            center: .center
        )
    }
    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.92)
            .stroke(gradient, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: rotate)
            .onAppear { rotate = true }
    }
}

struct SplashTaikaView: View {
    let onFinished: (() -> Void)?

    @ObservedObject private var theme = ThemeManager.shared
    @State private var logoVisible = false
    @State private var taglineVisible = false
    @State private var spinnerVisible = false
    @State private var fadeOut = false
    @State private var logoPulse: CGFloat = 1.0

    init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 140)

                // Название как в хедере: tai + kAAA с лёгкой пульсацией
                HStack(spacing: 6) {
                    Text("tai")
                        .font(.custom("Onmark Trial", size: 52))
                        .foregroundStyle(PD.ColorToken.text)
                    Text("kAAA")
                        .font(.custom("Onmark Trial", size: 52))
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                }
                .opacity(logoVisible ? 1 : 0)
                .scaleEffect((logoVisible ? logoPulse : 0.92))
                .animation(.spring(response: 0.6, dampingFraction: 0.82), value: logoVisible)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: logoPulse)

                Text("твоя персональная кун кру")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .padding(.top, 14)
                    .opacity(taglineVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: taglineVisible)

                Spacer(minLength: 60)

                GradientSpinner(size: 44)
                    .opacity(spinnerVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.4), value: spinnerVisible)

                Spacer(minLength: 80)
            }
            .opacity(fadeOut ? 0 : 1)
            .animation(.easeOut(duration: 0.35), value: fadeOut)
        }
        .onAppear {
            logoVisible = true
            logoPulse = 1.03
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { taglineVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { spinnerVisible = true }
            // Загрузочный экран без кнопки: авто-закрытие через 2.5 с
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                guard !fadeOut else { return }
                withAnimation(.easeOut(duration: 0.35)) { fadeOut = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onFinished?() }
            }
        }
    }
}

#Preview { SplashTaikaView(onFinished: nil) }
