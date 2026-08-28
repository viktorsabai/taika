//
//  SpeakerCarouselEffect.swift
//  taika
//
//  Siri-inspired techno sphere: readable ribs + distinct idle / listen / cook motion.
//  Perf: TimelineView 12–24fps, few blur layers, stroke ribs (cheap).
//

import SwiftUI

// MARK: - Shared crayon palette (course cards — not the voice orb)

public enum TaikaCrayonCarouselPalette {
    public static func colors(accent: Color) -> [Color] {
        [
            accent,
            Color(red: 0.98, green: 0.78, blue: 0.34),
            Color(red: 0.58, green: 0.86, blue: 0.62),
            Color(red: 0.62, green: 0.48, blue: 0.92),
            Color(red: 0.52, green: 0.78, blue: 0.98)
        ]
    }
}

// MARK: - Motion mode (listening ≠ cooking — life signal)

public enum SpeakerSphereMotion: Equatable {
    case idle
    case listening
    case cooking
    case result
}

// MARK: - Techno sphere

public struct SpeakerCarouselEffect: View {
    public var motion: SpeakerSphereMotion
    /// 0…1 — listening only (voice amplitude → deformation).
    public var audioLevel: CGFloat
    public var intensity: CGFloat

    /// Backward-compatible init used by older call sites.
    public var isListening: Bool {
        motion == .listening || motion == .cooking
    }

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var smoothedLevel: CGFloat = 0

    public init(
        motion: SpeakerSphereMotion,
        audioLevel: CGFloat = 0,
        intensity: CGFloat = 1
    ) {
        self.motion = motion
        self.audioLevel = min(max(audioLevel, 0), 1)
        self.intensity = min(max(intensity, 0.35), 1)
    }

    public init(isListening: Bool, audioLevel: CGFloat = 0, intensity: CGFloat = 1) {
        self.motion = isListening ? .listening : .idle
        self.audioLevel = min(max(audioLevel, 0), 1)
        self.intensity = min(max(intensity, 0.35), 1)
    }

    private var frameInterval: Double {
        if reduceMotion { return 1.0 / 10.0 }
        switch motion {
        case .idle, .result: return 1.0 / 16.0
        case .listening, .cooking: return 1.0 / 24.0
        }
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: frameInterval)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let level = motion == .listening ? smoothedLevel : 0
            let accent = theme.currentAccentTintColor
            let live = liveBoost(level: level, time: time)
            let breath = reduceMotion
                ? 1.0
                : CGFloat(1 + breathAmp * sin(time * breathFreq))
            let sizeScale = (0.93 + live * 0.07 + level * 0.05) * breath * intensity

            ZStack {
                // Soft outer wash (one blur only)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.18 * Double(live)),
                                Color(red: 0.55, green: 0.40, blue: 0.88).opacity(0.10 * Double(live)),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 28,
                            endRadius: 148
                        )
                    )
                    .frame(width: 292, height: 292)
                    .blur(radius: 20)

                // Soft petals — fewer, quieter
                ForEach(Array(Self.blades.enumerated()), id: \.offset) { _, blade in
                    bladeLayer(blade: blade, time: time, live: live, accent: accent, level: level)
                }

                // Readable ribs / facets (Siri structure) — no blur
                ForEach(Array(Self.ribs.enumerated()), id: \.offset) { index, rib in
                    ribLayer(rib: rib, index: index, time: time, live: live, accent: accent, level: level)
                }

                // Cooking sweep — orbiting arc = “thinking”, not frozen
                if motion == .cooking, !reduceMotion {
                    cookingSweep(time: time, accent: accent, live: live)
                }

                // Glass body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.96, green: 0.88, blue: 0.98).opacity(0.26 * Double(live)),
                                accent.opacity(0.16 * Double(live)),
                                Color(red: 0.45, green: 0.72, blue: 0.95).opacity(0.10 * Double(live)),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.40, y: 0.34),
                            startRadius: 0,
                            endRadius: 92
                        )
                    )
                    .frame(width: 168, height: 168)
                    .blur(radius: 6)

                // Outer rim — clear edge
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32 * Double(live)),
                                accent.opacity(0.36 * Double(live)),
                                Color(red: 0.55, green: 0.80, blue: 0.98).opacity(0.20 * Double(live)),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: motion == .cooking ? 1.4 : 1.1
                    )
                    .frame(width: 148 + level * 10, height: 148 + level * 10)
                    .opacity(0.88)

                // Soft core
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.94, blue: 0.98).opacity(0.38 * Double(live)),
                                Color(red: 0.98, green: 0.78, blue: 0.90).opacity(0.18 * Double(live)),
                                accent.opacity(0.08 * Double(live)),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 32 + level * 10
                        )
                    )
                    .frame(width: 68 + level * 14, height: 68 + level * 14)
                    .blur(radius: reduceMotion ? 2 : 5)
                    .scaleEffect(coreScale(level: level))
            }
            .scaleEffect(sizeScale)
            .frame(width: 300, height: 300)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            smoothedLevel = motion == .listening ? min(max(audioLevel, 0), 1) : 0
        }
        .onChange(of: motion) { _, new in
            if new != .listening { smoothedLevel = 0 }
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            let target = motion == .listening ? min(max(audioLevel, 0), 1) : 0
            if abs(smoothedLevel - target) < 0.008 {
                smoothedLevel = target
                return
            }
            smoothedLevel += (target - smoothedLevel) * (motion == .listening ? 0.22 : 0.14)
        }
    }

    // MARK: - Mode curves

    private var breathAmp: Double {
        switch motion {
        case .idle: return 0.018
        case .listening: return 0.028
        case .cooking: return 0.022
        case .result: return 0.010
        }
    }

    private var breathFreq: Double {
        switch motion {
        case .idle: return 0.65
        case .listening: return 1.15
        case .cooking: return 1.55
        case .result: return 0.5
        }
    }

    private func liveBoost(level: CGFloat, time: Double) -> CGFloat {
        switch motion {
        case .idle:
            return 0.52 + CGFloat(0.04 * sin(time * 0.55))
        case .listening:
            return 0.68 + level * 0.28
        case .cooking:
            // Distinct pulse — not voice-reactive
            return reduceMotion
                ? 0.62
                : CGFloat(0.58 + 0.12 * (0.5 + 0.5 * sin(time * 2.4)))
        case .result:
            return 0.46
        }
    }

    private func coreScale(level: CGFloat) -> CGFloat {
        switch motion {
        case .listening: return 1.0 + level * 0.08
        case .cooking: return 0.96
        case .idle: return 0.94
        case .result: return 0.90
        }
    }

    // MARK: - Ribs (structure)

    private struct RibSpec {
        let radiusX: CGFloat
        let radiusY: CGFloat
        let tilt: Double
        let speed: Double
        let phase: Double
        let lineWidth: CGFloat
        let opacity: Double
        let colorIndex: Int
    }

    private static let ribs: [RibSpec] = [
        RibSpec(radiusX: 78, radiusY: 62, tilt: 18, speed: 0.09, phase: 0.0, lineWidth: 1.35, opacity: 0.55, colorIndex: 0),
        RibSpec(radiusX: 86, radiusY: 68, tilt: -28, speed: -0.07, phase: 1.1, lineWidth: 1.15, opacity: 0.42, colorIndex: 1),
        RibSpec(radiusX: 94, radiusY: 74, tilt: 42, speed: 0.06, phase: 2.2, lineWidth: 1.05, opacity: 0.36, colorIndex: 2),
        RibSpec(radiusX: 70, radiusY: 88, tilt: -12, speed: -0.08, phase: 0.6, lineWidth: 1.2, opacity: 0.40, colorIndex: 0),
        RibSpec(radiusX: 102, radiusY: 78, tilt: 55, speed: 0.05, phase: 3.0, lineWidth: 0.95, opacity: 0.28, colorIndex: 3)
    ]

    @ViewBuilder
    private func ribLayer(
        rib: RibSpec,
        index: Int,
        time: Double,
        live: CGFloat,
        accent: Color,
        level: CGFloat
    ) -> some View {
        let colors: [Color] = [
            accent,
            Color(red: 0.55, green: 0.82, blue: 0.98),
            Color(red: 0.72, green: 0.58, blue: 0.95),
            Color(red: 0.96, green: 0.55, blue: 0.78)
        ]
        let color = colors[rib.colorIndex % colors.count]
        let deform = motion == .listening ? (1.0 + level * 0.10) : 1.0
        let angle: Double = {
            if reduceMotion { return rib.tilt + rib.phase * 8 }
            switch motion {
            case .idle:
                return rib.tilt + time * rib.speed * 10 + rib.phase * 6
            case .listening:
                return rib.tilt + time * rib.speed * 14 + sin(time * 1.8 + rib.phase) * Double(level) * 6
            case .cooking:
                // Faster orbital drift — “working”
                return rib.tilt + time * rib.speed * 28 + rib.phase * 10
            case .result:
                return rib.tilt + rib.phase * 8
            }
        }()
        let trimStart: CGFloat = {
            if reduceMotion { return 0.02 }
            if motion == .cooking {
                let w = sin(time * 1.6 + Double(index) * 0.9) * 0.08
                return CGFloat(0.08 + w)
            }
            return 0.04
        }()
        let trimEnd: CGFloat = {
            if reduceMotion { return 0.92 }
            if motion == .cooking {
                return CGFloat(0.72 + 0.18 * sin(time * 1.3 + Double(index)))
            }
            if motion == .listening {
                return CGFloat(0.88 + 0.08 * Double(level))
            }
            return 0.90
        }()

        Ellipse()
            .trim(from: trimStart, to: min(0.98, max(trimStart + 0.2, trimEnd)))
            .stroke(
                color.opacity(rib.opacity * Double(live)),
                style: StrokeStyle(lineWidth: rib.lineWidth, lineCap: .round)
            )
            .frame(width: rib.radiusX * 2 * deform, height: rib.radiusY * 2 * deform)
            .rotationEffect(.degrees(angle))
    }

    @ViewBuilder
    private func cookingSweep(time: Double, accent: Color, live: CGFloat) -> some View {
        let angle = time * 72
        Circle()
            .trim(from: 0.0, to: 0.22)
            .stroke(
                AngularGradient(
                    colors: [
                        accent.opacity(0.0),
                        accent.opacity(0.55 * Double(live)),
                        Color.white.opacity(0.35 * Double(live)),
                        accent.opacity(0.0)
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )
            .frame(width: 156, height: 156)
            .rotationEffect(.degrees(angle))
            .opacity(0.9)
    }

    // MARK: - Soft petals

    private struct BladeSpec {
        let hue: BladeHue
        let size: CGFloat
        let blur: CGFloat
        let speed: Double
        let phase: Double
        let driftX: CGFloat
        let driftY: CGFloat
        let squash: CGFloat
        let baseOpacity: Double
    }

    private enum BladeHue {
        case sky, rose, lilac, accent
    }

    private static let blades: [BladeSpec] = [
        BladeSpec(hue: .sky, size: 158, blur: 18, speed: 0.08, phase: 0.0, driftX: -12, driftY: -16, squash: 0.80, baseOpacity: 0.26),
        BladeSpec(hue: .rose, size: 150, blur: 20, speed: -0.07, phase: 1.4, driftX: 16, driftY: 12, squash: 0.84, baseOpacity: 0.28),
        BladeSpec(hue: .lilac, size: 166, blur: 22, speed: 0.06, phase: 2.3, driftX: -8, driftY: 18, squash: 0.90, baseOpacity: 0.22),
        BladeSpec(hue: .accent, size: 140, blur: 16, speed: -0.09, phase: 0.7, driftX: 10, driftY: -10, squash: 0.76, baseOpacity: 0.30)
    ]

    @ViewBuilder
    private func bladeLayer(
        blade: BladeSpec,
        time: Double,
        live: CGFloat,
        accent: Color,
        level: CGFloat
    ) -> some View {
        let speedMul: Double = {
            switch motion {
            case .idle: return 0.7
            case .listening: return 1.0 + Double(level) * 0.35
            case .cooking: return 1.6
            case .result: return 0.4
            }
        }()
        let angle = reduceMotion
            ? blade.phase * 14
            : blade.phase * 14 + time * blade.speed * 12 * speedMul
        let pulse = reduceMotion
            ? 1.0
            : 1.0 + (motion == .listening ? 0.035 : 0.018) * sin(time * 0.9 + blade.phase)
                + (motion == .listening ? Double(level) * 0.04 : 0)
        let color = color(for: blade.hue, accent: accent)
        let opacity = blade.baseOpacity * Double(live)

        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(opacity),
                        color.opacity(opacity * 0.40),
                        color.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: blade.size * 0.50
                )
            )
            .frame(width: blade.size, height: blade.size * blade.squash)
            .blur(radius: blade.blur)
            .offset(x: blade.driftX * pulse, y: blade.driftY * pulse)
            .rotationEffect(.degrees(angle))
            .scaleEffect(pulse)
    }

    private func color(for hue: BladeHue, accent: Color) -> Color {
        switch hue {
        case .sky: return Color(red: 0.55, green: 0.82, blue: 0.98)
        case .rose: return Color(red: 0.96, green: 0.55, blue: 0.78)
        case .lilac: return Color(red: 0.72, green: 0.58, blue: 0.95)
        case .accent: return accent
        }
    }
}
