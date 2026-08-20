//
//  SplashView.swift
//  taika
//
//  Adult branded ritual for returning users: a quiet voice-wave signal,
//  the Taika wordmark, and a secondary Kun Kru cue. No decorative blob.
//

import SwiftUI

private struct SplashVoiceWave: Shape {
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let width = rect.width
        let steps = 48

        for index in 0...steps {
            let progress = CGFloat(index) / CGFloat(steps)
            let x = rect.minX + progress * width
            let envelope = sin(progress * .pi)
            let wave = sin(progress * .pi * 2.15 + phase) * amplitude * envelope
            let y = midY + wave
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

struct SplashTaikaView: View {
    let onFinished: (() -> Void)?

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentVisible = true
    @State private var logoPulse: CGFloat = 1.0
    @State private var wavePhase: CGFloat = 0
    @State private var waveAmplitude: CGFloat = 7
    @State private var fadeOut = false
    @State private var didFinish = false

    init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    theme.currentAccentTintColor.opacity(0.035),
                    Color.clear,
                    theme.currentAccentTintColor.opacity(0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 88)

                HStack(spacing: 6) {
                    Text("tai")
                        .font(.custom("Onmark Trial", size: 52))
                        .foregroundStyle(PD.ColorToken.text)
                    Text("kAAA")
                        .font(.custom("Onmark Trial", size: 52))
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                }
                .scaleEffect(logoPulse)

                ZStack {
                    SplashVoiceWave(phase: wavePhase, amplitude: waveAmplitude)
                        .stroke(PD.ColorToken.text.opacity(0.92), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .frame(width: 230, height: 44)

                    SplashVoiceWave(phase: wavePhase + 1.1, amplitude: waveAmplitude * 0.58)
                        .stroke(theme.currentAccentTintColor.opacity(0.56), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
                        .frame(width: 230, height: 44)
                        .offset(y: 9)
                }
                .padding(.top, 28)
                .accessibilityLabel("Живая линия голоса Taika")

                Text("Кун Кру готовит практику")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .padding(.top, 20)

                Spacer(minLength: 88)
            }
            .opacity(contentVisible && !fadeOut ? 1 : 0)
            .offset(y: -28)
            .animation(.easeOut(duration: 0.28), value: fadeOut)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                logoPulse = 1.018
                waveAmplitude = 12
            }
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_050_000_000)
            await MainActor.run { finishIfNeeded() }
        }
    }

    @MainActor
    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true
        withAnimation(.easeOut(duration: 0.28)) { fadeOut = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            onFinished?()
        }
    }
}

#Preview { SplashTaikaView(onFinished: nil) }
