//
//  VisualEffectsDS.swift
//  taika
//
//  Created by product on 31.10.2025.
//
import SwiftUI

// MARK: - единые метрики карточек (как в CourseDS)
public enum DSMetrics {
    public static let cardWidth:  CGFloat = CardDS.Metrics.courseCardWidth
    public static let cardHeight: CGFloat = CardDS.Metrics.courseCardHeight
    public static let reelSpacing: CGFloat = 18
}

// MARK: - общий градиент/цвета токены (оборачиваем ThemeManager)
public enum DSFill {
    public static var accent: AnyShapeStyle { AnyShapeStyle(ThemeManager.shared.currentAccentFill) }
    public static var card: Color { PD.ColorToken.card }
}

// MARK: - единый 3D-эффект глубины (как в CourseDS)
public struct DSDepth3D: ViewModifier {
    let tilt: Double
    let scale: CGFloat
    let opacity: CGFloat
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    public func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.78)
            .scaleEffect(scale)
            .opacity(opacity)
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowY)
            .compositingGroup()
    }
}

public enum DSDepth {
    @inline(__always)
    public static func params(dx: CGFloat, outerWidth: CGFloat)
    -> (tilt: Double, scale: CGFloat, opacity: CGFloat, shadowOpacity: Double, shadowRadius: CGFloat, shadowY: CGFloat) {

        let dx0: CGFloat = (abs(dx) < 0.75) ? 0 : dx
        let denom = max(1, outerWidth * 0.72)
        let norm  = min(1.0, abs(dx0) / denom)
        let t     = 1.0 - norm

        let tilt  = Double(-dx0 / 14.0)
        let scale = 0.88 + 0.22 * CGFloat(t * t)
        let opacity       = 0.55 + 0.45 * CGFloat(t)
        let isCenter      = scale >= 1.095
        let shadowOpacity = isCenter ? 0.30 : 0.10
        let shadowRadius: CGFloat = isCenter ? 9.0 : 2.0
        let shadowY: CGFloat = isCenter ? 3.0 : 1.0

        return (tilt, scale, opacity, shadowOpacity, shadowRadius, shadowY)
    }
}

public extension View {
    /// быстрый сахар: применить DS-глубину по dx
    func dsDepth3D(dx: CGFloat, outerWidth: CGFloat) -> some View {
        let p = DSDepth.params(dx: dx, outerWidth: outerWidth)
        return self.modifier(DSDepth3D(tilt: p.tilt, scale: p.scale,
                                       opacity: p.opacity,
                                       shadowOpacity: p.shadowOpacity,
                                       shadowRadius: p.shadowRadius,
                                       shadowY: p.shadowY))
    }

    /// единый внешний паддинг секций
    func dsSectionPadding(bottom: CGFloat = 24) -> some View {
        self.padding(.horizontal, PD.Spacing.screen).padding(.bottom, bottom)
    }
}


#if DEBUG
private struct _VE_PreviewHost<Content: View>: View {
    @StateObject private var theme = ThemeManager.shared
    let content: () -> Content
    var body: some View {
        content().environmentObject(theme)
    }
}
#Preview("DSDepth3D Demo") {
    _VE_PreviewHost {
        GeometryReader { outer in
            HStack(spacing: DSMetrics.reelSpacing) {
                ForEach(-2..<3, id: \.self) { offset in
                    let dx = CGFloat(offset) * 120
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DSFill.card)
                        .frame(width: DSMetrics.cardWidth, height: DSMetrics.cardHeight)
                        .overlay(
                            Text("card \(offset)")
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                        .dsDepth3D(dx: dx, outerWidth: outer.size.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.8))
        }
    }
}
#endif

// MARK: - Tech signal wave (onboarding orb DNA, reusable without the sphere)

/// Continuous brand wave used for live listening / recording / analyzing feedback.
/// Slow-mo AI-agent feel + accent gradient (not solid tint).
public struct TaikaTechWaveform: View {
    public enum Pace: Equatable {
        case recording
        case analyzing
        case idle
    }

    public var meter: Double
    public var pace: Pace
    public var lineCount: Int

    public init(
        meter: Double = 0.55,
        pace: Pace = .recording,
        lineCount: Int = 3
    ) {
        self.meter = meter
        self.pace = pace
        self.lineCount = max(1, lineCount)
    }

    /// Back-compat for older call sites.
    public init(
        meter: Double,
        active: Bool,
        intense: Bool,
        lineCount: Int = 4
    ) {
        self.meter = meter
        self.pace = intense ? .recording : (active ? .analyzing : .idle)
        self.lineCount = max(1, lineCount)
    }

    public var body: some View {
        let colors = Self.brandColors()
        // Soften mic spikes so the ribbon doesn't jump frame-to-frame.
        let ampBoost = CGFloat(0.22 + 0.55 * max(0, min(1, meter)))
        let layers = lineCount
        let wavePace = pace

        // ~20 fps is enough for slow-mo and avoids micro-jitter.
        return TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let time = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
            Canvas { context, size in
                Self.drawWave(
                    context: &context,
                    size: size,
                    time: time,
                    colors: colors,
                    ampBoost: ampBoost,
                    lineCount: layers,
                    pace: wavePace
                )
            }
        }
        .accessibilityHidden(true)
    }

    private static func brandColors() -> [Color] {
        switch ThemeManager.shared.accent {
        case .pink:
            return [
                Color(red: 1.00, green: 0.52, blue: 0.85),
                Color(red: 0.98, green: 0.65, blue: 0.92),
                Color(red: 0.90, green: 0.78, blue: 1.00)
            ]
        case .azure:
            return [
                Color(red: 0.05, green: 0.40, blue: 0.24),
                Color(red: 0.20, green: 0.62, blue: 0.58),
                Color(red: 0.78, green: 0.90, blue: 1.00)
            ]
        case .sun:
            return [
                Color(red: 1.00, green: 0.97, blue: 0.70),
                Color(red: 1.00, green: 0.88, blue: 0.36),
                Color(red: 0.93, green: 0.34, blue: 0.08)
            ]
        case .thai:
            return [
                Color(red: 1.00, green: 0.52, blue: 0.85),
                Color(red: 0.95, green: 0.36, blue: 0.65),
                Color(red: 0.90, green: 0.78, blue: 1.00)
            ]
        }
    }

    private static func drawWave(
        context: inout GraphicsContext,
        size: CGSize,
        time: CGFloat,
        colors: [Color],
        ampBoost: CGFloat,
        lineCount: Int,
        pace: Pace
    ) {
        let mid = size.height * 0.5
        let heightFactor: CGFloat
        let speed: CGFloat
        switch pace {
        case .recording:
            // Voice-agent slow-mo: drift, don't thrash.
            heightFactor = 0.20
            speed = 0.16 + ampBoost * 0.06
        case .analyzing:
            heightFactor = 0.14
            speed = 0.11 + ampBoost * 0.04
        case .idle:
            heightFactor = 0.10
            speed = 0.08
        }
        let baseAmp = size.height * heightFactor * (pace == .idle ? 0.85 : ampBoost)
        let width = max(size.width, 1)

        for index in 0..<lineCount {
            var path = Path()
            let idx = CGFloat(index)
            let layerAmp = baseAmp * (0.70 + 0.08 * idx)
            let layerSpeed = speed * (1.0 + 0.03 * idx)
            let phase = idx * 0.55
            let strokeWidth: CGFloat = (index == lineCount - 1) ? 2.4 : 1.35
            let layerOpacity = 0.34 + 0.18 * Double(index)

            path.move(to: CGPoint(x: 0, y: mid))
            var x: CGFloat = 0
            while x <= width {
                let t = x / width
                // One soft carrier + tiny slow shimmer (no high-frequency jitter).
                let carrier = sin(t * .pi * 1.55 + time * layerSpeed + phase)
                let shimmer = sin(t * .pi * 2.4 - time * layerSpeed * 0.55 + phase) * 0.05
                let envelope = 0.55 + 0.45 * sin(t * .pi)
                let y = mid + (carrier + shimmer) * layerAmp * envelope
                path.addLine(to: CGPoint(x: x, y: y))
                x += 1.5
            }

            let faded = Gradient(colors: colors.map { $0.opacity(layerOpacity) })
            context.stroke(
                path,
                with: .linearGradient(
                    faded,
                    startPoint: CGPoint(x: 0, y: mid),
                    endPoint: CGPoint(x: width, y: mid)
                ),
                lineWidth: strokeWidth
            )
        }
    }
}
