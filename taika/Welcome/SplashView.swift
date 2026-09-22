//
//  SplashView.swift
//  taika
//
//  Returning cold start is a still frame + spinner. First-entry brand
//  assemble stays in TaikaBootAssembleView.
//

import SwiftUI
import UIKit

/// First-entry brand frame — atoms lock into the Speaker sphere, then the wordmark.
struct TaikaBootAssembleView: View {
    var captionLines: [String]
    var finishesAutomatically: Bool
    var onWordmarkAppeared: (() -> Void)? = nil
    var onFinished: (() -> Void)? = nil

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var planetMode: TaikaVoicePlanetMode = .assemble
    @State private var wordmarkVisible = false
    @State private var captionsVisible = false
    @State private var didFinish = false
    @State private var bootTask: Task<Void, Never>?

    private var caption: String {
        captionLines.first ?? ""
    }

    init(
        caption: String,
        finishesAutomatically: Bool,
        onWordmarkAppeared: (() -> Void)? = nil,
        onFinished: (() -> Void)? = nil
    ) {
        self.captionLines = [caption]
        self.finishesAutomatically = finishesAutomatically
        self.onWordmarkAppeared = onWordmarkAppeared
        self.onFinished = onFinished
    }

    init(
        captionLines: [String],
        finishesAutomatically: Bool,
        onWordmarkAppeared: (() -> Void)? = nil,
        onFinished: (() -> Void)? = nil
    ) {
        self.captionLines = captionLines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.finishesAutomatically = finishesAutomatically
        self.onWordmarkAppeared = onWordmarkAppeared
        self.onFinished = onFinished
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            TaikaVoicePlanet(
                mode: planetMode,
                scale: 0.82,
                centerSymbol: "mic.fill",
                palette: .theme,
                idleAccent: 0.72
            )
            .frame(width: 220, height: 220)

            Spacer().frame(height: 40)

            HStack(spacing: 6) {
                Text("tai")
                    .font(.custom("Onmark Trial", size: 42))
                    .foregroundStyle(PD.ColorToken.text)
                Text("kAAA")
                    .font(.custom("Onmark Trial", size: 42))
                    .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
            }
            .opacity(wordmarkVisible ? 1 : 0)
            .offset(y: wordmarkVisible ? 0 : 8)
            .blur(radius: wordmarkVisible ? 0 : 5)

            Spacer().frame(height: 28)

            Group {
                if captionsVisible, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .padding(.horizontal, 36)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Color.clear.frame(height: 20)
                }
            }
            .frame(minHeight: 28)
            .opacity(wordmarkVisible ? 1 : 0)

            Spacer(minLength: 72)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { runBoot() }
        .onDisappear { bootTask?.cancel() }
    }

    private func runBoot() {
        bootTask?.cancel()
        didFinish = false
        captionsVisible = false

        if reduceMotion {
            planetMode = .idle
            wordmarkVisible = true
            captionsVisible = true
            onWordmarkAppeared?()
            return
        }

        planetMode = .assemble
        wordmarkVisible = false
        bootTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 720_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.42)) {
                wordmarkVisible = true
            }
            onWordmarkAppeared?()

            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            planetMode = .idle
            withAnimation(.easeOut(duration: 0.35)) {
                captionsVisible = true
            }
        }
    }
}

/// Returning cold start: still frame, one line, spinner. Cover window holds it.
struct SplashTaikaView: View {
    let onFinished: (() -> Void)?

    @ObservedObject private var theme = ThemeManager.shared

    init(onFinished: (() -> Void)? = nil) {
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                TaikaSplashCAPlanet()
                    .frame(width: 220, height: 220)

                Spacer().frame(height: 40)

                HStack(spacing: 6) {
                    Text("tai")
                        .font(.custom("Onmark Trial", size: 42))
                        .foregroundStyle(PD.ColorToken.text)
                    Text("kAAA")
                        .font(.custom("Onmark Trial", size: 42))
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                }

                Spacer().frame(height: 28)

                Text("твоя персональная кун кру")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer().frame(height: 36)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.white.opacity(0.42))
                    .scaleEffect(0.85)
                    .accessibilityLabel("Загрузка")

                Spacer(minLength: 72)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Taika")
        .onAppear { TaikaCatalogBoot.start() }
    }
}

/// Same hollow planet, Core Animation. Keeps turning while SwiftUI is blocked — like the spinner.
private struct TaikaSplashCAPlanet: UIViewRepresentable {
    func makeUIView(context: Context) -> TaikaSplashCAPlanetView {
        TaikaSplashCAPlanetView()
    }

    func updateUIView(_ uiView: TaikaSplashCAPlanetView, context: Context) {}
}

final class TaikaSplashCAPlanetView: UIView {
    private let shell = UIView()
    private let mic = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false

        shell.backgroundColor = .clear
        addSubview(shell)

        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .semibold)
        let pink = UIColor(red: 1.0, green: 0.52, blue: 0.85, alpha: 1)
        let lilac = UIColor(red: 0.90, green: 0.78, blue: 1.0, alpha: 1)
        mic.image = UIImage(systemName: "mic.fill", withConfiguration: config)?
            .withTintColor(pink, renderingMode: .alwaysOriginal)
        mic.contentMode = .scaleAspectFit
        addSubview(mic)

        buildDots(pink: pink, lilac: lilac)
        startMotion()
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        shell.frame = bounds
        let micSide = min(bounds.width, bounds.height) * 0.16
        mic.frame = CGRect(
            x: bounds.midX - micSide / 2,
            y: bounds.midY - micSide / 2,
            width: micSide,
            height: micSide
        )
    }

    private func buildDots(pink: UIColor, lilac: UIColor) {
        let count = 110
        let golden = Double.pi * (3 - sqrt(5))
        let radius: CGFloat = 78
        for i in 0..<count {
            let y = 1 - (Double(i) / Double(count - 1)) * 2
            let ring = sqrt(max(0, 1 - y * y))
            let theta = golden * Double(i)
            let x = cos(theta) * ring
            let z = sin(theta) * ring
            let depth = CGFloat((z + 1) / 2)
            let size: CGFloat = 1.8 + depth * 1.8
            let dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            dot.cornerRadius = size / 2
            let tint: UIColor = {
                switch i % 5 {
                case 0, 1: return pink
                case 2: return lilac
                default: return .white
                }
            }()
            dot.backgroundColor = tint.withAlphaComponent(0.22 + 0.62 * depth).cgColor
            dot.position = CGPoint(x: 110 + CGFloat(x) * radius, y: 110 + CGFloat(y) * radius)
            shell.layer.addSublayer(dot)
        }
    }

    private func startMotion() {
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = CGFloat.pi * 2
        spin.duration = 16
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        shell.layer.add(spin, forKey: "spin")

        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.985
        pulse.toValue = 1.03
        pulse.duration = 1.7
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.isRemovedOnCompletion = false
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(pulse, forKey: "pulse")
    }
}

#Preview { SplashTaikaView(onFinished: nil) }
