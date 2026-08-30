//
//  TaikaVoicePlanet.swift
//  taika
//
//  Voice CTA: brand accent core + soft star glow.
//  Cheap motion — no TimelineView / no blur storms.
//

import SwiftUI

public enum TaikaVoicePlanetMode: Equatable {
    case idle
    case cooking
    case speaking
    case listening
    case result
}

public enum TaikaVoicePlanetKind: Equatable {
    case voice
    case text
}

/// Shared voice control — Main, Speaker, onboarding.
public struct TaikaVoicePlanet: View {
    public let mode: TaikaVoicePlanetMode
    public var kind: TaikaVoicePlanetKind = .voice
    public var scale: CGFloat = 1
    public var centerSymbol: String? = nil
    public var lite: Bool = false
    public var inviteTap: Bool = false
    /// Live voice level 0…1 — used in `.listening` / `.speaking`.
    public var audioLevel: CGFloat = 0
    public var showsCarousel: Bool = true

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cookSpin = false
    @State private var idlePulse = false
    @State private var sonarPhase = false

    public init(
        mode: TaikaVoicePlanetMode,
        kind: TaikaVoicePlanetKind = .voice,
        scale: CGFloat = 1,
        centerSymbol: String? = nil,
        lite: Bool = false,
        inviteTap: Bool = false,
        audioLevel: CGFloat = 0,
        showsCarousel: Bool = true
    ) {
        self.mode = mode
        self.kind = kind
        self.scale = scale
        self.centerSymbol = centerSymbol
        self.lite = lite
        self.inviteTap = inviteTap
        self.audioLevel = min(max(audioLevel, 0), 1)
        self.showsCarousel = showsCarousel
    }

    private var accentTint: Color {
        switch kind {
        case .voice: return theme.currentAccentTintColor
        case .text: return Color(red: 0.42, green: 0.78, blue: 1.0)
        }
    }

    private var accentFill: LinearGradient {
        switch kind {
        case .voice: return theme.currentAccentFill
        case .text:
            return LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.78, blue: 1.0),
                    Color(red: 0.72, green: 0.90, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var level: CGFloat {
        switch mode {
        case .listening, .speaking: return audioLevel
        default: return 0
        }
    }

    private var micSymbol: String {
        if let centerSymbol, !centerSymbol.isEmpty { return centerSymbol }
        switch kind {
        case .text: return "keyboard"
        case .voice:
            switch mode {
            case .listening: return "ear.fill"
            case .cooking: return "magnifyingglass"
            case .result: return "checkmark"
            case .speaking: return "speaker.wave.2.fill"
            case .idle: return "mic.fill"
            }
        }
    }

    public var body: some View {
        ZStack {
            if kind == .text {
                textKindPlaceholder
            } else if showsCarousel {
                micWithGlow
            } else {
                micCore(size: 88)
            }
        }
        .frame(width: 300, height: 300)
        .scaleEffect(scale)
        .animation(.easeInOut(duration: 0.3), value: mode)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .onAppear { syncMotion() }
        .onChange(of: mode) { _, _ in syncMotion() }
        .onChange(of: inviteTap) { _, _ in syncMotion() }
    }

    private var accessibilityLabel: String {
        switch mode {
        case .idle: return "Микрофон"
        case .listening: return "Слушаю"
        case .cooking: return "Распознаю"
        case .speaking: return "Говорю"
        case .result: return "Готово"
        }
    }

    private func syncMotion() {
        guard !reduceMotion else {
            cookSpin = false
            idlePulse = false
            sonarPhase = false
            return
        }
        switch mode {
        case .cooking:
            cookSpin = false
            idlePulse = false
            sonarPhase = false
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                cookSpin = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                idlePulse = true
            }
        case .idle:
            cookSpin = false
            idlePulse = false
            sonarPhase = false
            withAnimation(.easeInOut(duration: inviteTap ? 1.5 : 2.2).repeatForever(autoreverses: true)) {
                idlePulse = true
            }
        case .listening, .speaking:
            cookSpin = false
            idlePulse = false
            sonarPhase = true
        case .result:
            cookSpin = false
            idlePulse = false
            sonarPhase = false
        }
    }

    // MARK: - Brand core + soft glow (no plastic body)

    private var micWithGlow: some View {
        let core: CGFloat = lite ? 76 : 90
        let listenBoost = 0.55 + Double(level) * 0.45

        return ZStack {
            starGlow(listenBoost: listenBoost)

            if mode == .cooking {
                cookRings
            } else if mode == .listening || mode == .speaking {
                sonarRipples(base: lite ? 118 : 128)
            }

            micCore(size: core)
                .scaleEffect(listeningCoreScale)
        }
    }

    /// Soft brand bloom — identity tint only, no cloudy overlays.
    private func starGlow(listenBoost: Double) -> some View {
        let size: CGFloat = lite ? 200 : 228
        let peak: Double = {
            switch mode {
            case .idle: return inviteTap ? 0.50 : 0.38
            case .listening, .speaking: return 0.42 * listenBoost
            case .cooking: return 0.44
            case .result: return 0.20
            }
        }()
        let live = idlePulse ? peak * 1.2 : peak

        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        accentTint.opacity(live),
                        accentTint.opacity(live * 0.35),
                        .clear
                    ],
                    center: .center,
                    startRadius: size * 0.06,
                    endRadius: size * 0.50
                )
            )
            .frame(width: size, height: size)
            .scaleEffect(idlePulse ? 1.06 : 1.0)
            .allowsHitTesting(false)
    }

    private var listeningCoreScale: CGFloat {
        guard mode == .listening || mode == .speaking else {
            return idlePulse ? 1.03 : 1
        }
        return 0.97 + level * 0.08
    }

    private func sonarRipples(base: CGFloat) -> some View {
        let strength = 0.28 + Double(level) * 0.40
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        accentTint.opacity(sonarPhase ? 0 : strength),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                    )
                    .frame(width: base, height: base)
                    .scaleEffect(sonarPhase ? 1.55 : 0.94)
                    .animation(
                        .easeOut(duration: 2.1)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.7),
                        value: sonarPhase
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private var cookRings: some View {
        let inner: CGFloat = lite ? 122 : 134
        let outer: CGFloat = lite ? 158 : 172
        return ZStack {
            Circle()
                .stroke(accentFill.opacity(0.18), lineWidth: 2)
                .frame(width: inner, height: inner)

            Circle()
                .trim(from: 0.02, to: 0.34)
                .stroke(
                    accentFill,
                    style: StrokeStyle(lineWidth: 3.4, lineCap: .round)
                )
                .frame(width: inner, height: inner)
                .rotationEffect(.degrees(cookSpin ? 360 : 0))

            Circle()
                .trim(from: 0.55, to: 0.78)
                .stroke(
                    accentFill.opacity(0.45),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
                .frame(width: outer, height: outer)
                .rotationEffect(.degrees(cookSpin ? -360 : 0))
        }
        .allowsHitTesting(false)
    }

    /// Brand gradient pill — same language as buttons / chips.
    private func micCore(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(accentFill)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.04),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(mode == .listening ? 0.35 : 0.18), lineWidth: 1)
                )
                .shadow(color: accentTint.opacity(0.40), radius: 14, y: 4)

            Image(systemName: micSymbol)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(Theme.Colors.backgroundPrimary)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var textKindPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(accentFill.opacity(0.7), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
            .frame(width: 72, height: 46)
            .overlay(
                Image(systemName: "keyboard")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentFill)
            )
    }
}
