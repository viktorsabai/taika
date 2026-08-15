//
//  SplashView.swift
//  taika
//
//  Тихий brand beat для returning users: лого + кун кру, без typewriter-статусов.
//

import SwiftUI

struct SplashTaikaView: View {
    let onFinished: (() -> Void)?

    @ObservedObject private var theme = ThemeManager.shared
    @State private var contentVisible = true
    @State private var logoPulse: CGFloat = 1.0
    @State private var orbPulse: CGFloat = 0.94
    @State private var fadeOut = false
    @State private var didFinish = false
    @State private var cursorOn = true

    init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            Circle()
                .fill(theme.currentAccentFill.opacity(0.14))
                .frame(width: 200, height: 200)
                .blur(radius: 52)
                .scaleEffect(orbPulse)
                .offset(y: -36)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 160)

                HStack(spacing: 6) {
                    Text("tai")
                        .font(.custom("Onmark Trial", size: 52))
                        .foregroundStyle(PD.ColorToken.text)
                    Text("kAAA")
                        .font(.custom("Onmark Trial", size: 52))
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                }
                .scaleEffect(logoPulse)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("твоя персональная кун кру")
                    Text("_")
                        .foregroundStyle(theme.currentAccentTintColor)
                        .opacity(cursorOn ? 1 : 0.18)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .padding(.top, 16)

                Spacer(minLength: 160)
            }
            .opacity(contentVisible && !fadeOut ? 1 : 0)
            .animation(.easeOut(duration: 0.28), value: fadeOut)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                logoPulse = 1.025
                orbPulse = 1.06
            }
        }
        .onReceive(Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()) { _ in
            cursorOn.toggle()
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
