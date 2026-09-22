import SwiftUI

// MARK: - Taika scroll policy
//
// **TaikaRootVerticalScroll** — primary vertical screen scroll (one per route when possible).
// Avoid nesting a second vertical `ScrollView` unless you use `Lazy*` stacks and have a clear reason.
//
// **TaikaCarouselScroll** — horizontal carousels inside a vertical screen; keep horizontal scrolling on this helper.
//
// **Indicators** — hidden by default for product polish; use `showsScrollIndicators: true` only for DEBUG previews
// where Xcode needs visible scroll chrome.
//
// **QA / Instruments** — after shell/tab changes: Time Profiler + SwiftUI; scenarios noted in `AppShell.swift` header.

// MARK: - Root chrome (floating header clearance)

private struct TaikaRootHeaderClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Top gutter so scroll content clears the floating glass header; content still scrolls underneath it.
    var taikaRootHeaderClearance: CGFloat {
        get { self[TaikaRootHeaderClearanceKey.self] }
        set { self[TaikaRootHeaderClearanceKey.self] = newValue }
    }
}

/// Standard vertical “screen” scroll: unified indicators, bounce, keyboard dismiss.
struct TaikaRootVerticalScroll<Content: View>: View {
    var showsScrollIndicators: Bool = false
    @ViewBuilder var content: () -> Content
    @Environment(\.taikaRootHeaderClearance) private var headerClearance

    init(showsScrollIndicators: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.showsScrollIndicators = showsScrollIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: showsScrollIndicators) {
            VStack(spacing: 0) {
                if headerClearance > 0 {
                    Color.clear
                        .frame(height: headerClearance)
                        .accessibilityHidden(true)
                }
                content()
            }
        }
        .scrollIndicators(showsScrollIndicators ? .automatic : .hidden)
    }
}

/// Horizontal carousel inside a vertical screen (phrase rows, chips, course rails).
struct TaikaCarouselScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content()
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Liquid glass chrome

private enum TaikaGlassTokens {
    /// Denser veil — hides material grain over busy dark canvases.
    static let headerTint: Double = 0.28
    static let toolbarTint: Double = 0.32
    static let buttonTint: Double = 0.30
    static let edgeStroke: Double = 0.12
}

/// Neutral frosted glass for header / toolbar / icon orbs.
/// Chrome material (not ultraThin) — ultraThin looks sandy over particles/waves.
private struct TaikaNeutralGlassFill: View {
    var tint: Double = TaikaGlassTokens.headerTint

    var body: some View {
        ZStack {
            // UIKit chrome blur is denser/smoother than SwiftUI ultraThin over busy dark UIs.
            SystemBlur(style: .systemChromeMaterialDark)
            Color.black.opacity(tint)
        }
    }
}

/// Instagram-style circular header control — visibly tappable glass button.
struct TaikaHeaderGlassButton<Content: View>: View {
    var size: CGFloat = 38
    /// Idle: colored ring so the control reads as a button. Active: solid fill.
    var stroke: AnyShapeStyle = AnyShapeStyle(Color.white.opacity(TaikaGlassTokens.edgeStroke))
    var showsRing: Bool = true
    var filled: Bool = false
    var fill: AnyShapeStyle = AnyShapeStyle(Color.clear)
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: size, height: size)
            .background {
                if filled {
                    Circle().fill(fill)
                } else {
                    TaikaNeutralGlassFill(tint: TaikaGlassTokens.buttonTint)
                        .clipShape(Circle())
                }
            }
            .overlay {
                if showsRing {
                    Circle()
                        .stroke(filled ? AnyShapeStyle(Color.white.opacity(0.28)) : stroke, lineWidth: filled ? 0.6 : 1.25)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
    }
}

/// Pill glass for mic/heart counters in the root header.
struct TaikaHeaderGlassPill<Content: View>: View {
    var height: CGFloat = 38
    var horizontalPadding: CGFloat = 11
    var stroke: AnyShapeStyle = AnyShapeStyle(Color.white.opacity(TaikaGlassTokens.edgeStroke))
    var showsRing: Bool = true
    var filled: Bool = false
    var fill: AnyShapeStyle = AnyShapeStyle(Color.clear)
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background {
                if filled {
                    Capsule(style: .continuous).fill(fill)
                } else {
                    TaikaNeutralGlassFill(tint: TaikaGlassTokens.buttonTint)
                        .clipShape(Capsule(style: .continuous))
                }
            }
            .overlay {
                if showsRing {
                    Capsule(style: .continuous)
                        .stroke(filled ? AnyShapeStyle(Color.white.opacity(0.28)) : stroke, lineWidth: filled ? 0.6 : 1.25)
                }
            }
            .contentShape(Capsule(style: .continuous))
    }
}

struct TaikaHeaderButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(enabled && configuration.isPressed ? 0.90 : 1)
            .opacity(enabled && configuration.isPressed ? 0.82 : 1)
            .animation(enabled ? .spring(response: 0.28, dampingFraction: 0.78) : nil, value: configuration.isPressed)
    }
}

/// Bottom tab capsule — neutral glass only (do not tint with accent).
struct TaikaLiquidGlassCapsule: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.clear)
            .background {
                TaikaNeutralGlassFill(tint: TaikaGlassTokens.toolbarTint)
                    .clipShape(Capsule(style: .continuous))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(TaikaGlassTokens.edgeStroke), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
    }
}

/// Continuous canvas background shared by root screens under the floating header.
/// Keeps the header and body on one visual plane while preserving the existing chrome API.
struct TaikaContinuousCanvasBackground: View {
    var body: some View {
        ZStack {
            PD.ColorToken.background
            LinearGradient(
                colors: [
                    Color.white.opacity(0.010),
                    Color.clear,
                    Color.black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    Color(red: 0.56, green: 0.16, blue: 0.42).opacity(0.035),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

/// Brand wash for result / analyze — identity pink (or current accent), no techno waves.
struct TaikaBrandWashBackdrop: View {
    var intensity: CGFloat = 1

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let tint = theme.currentAccentTintColor
        let hot = theme.accent == .pink
            ? Color(red: 1.00, green: 0.52, blue: 0.85)
            : tint
        let cool = theme.accent == .pink
            ? Color(red: 0.90, green: 0.78, blue: 1.00)
            : tint.opacity(0.55)
        ZStack {
            PD.ColorToken.background
            RadialGradient(
                colors: [
                    hot.opacity(0.26 * intensity),
                    tint.opacity(0.12 * intensity),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 24,
                endRadius: 340
            )
            RadialGradient(
                colors: [
                    cool.opacity(0.14 * intensity),
                    Color.clear
                ],
                center: UnitPoint(x: 0.62, y: 0.58),
                startRadius: 10,
                endRadius: 260
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Спокойный techno-фон: лёгкая волна, без цветного «сияния» поверх бренда.
struct TaikaTechnoSpaceBackdrop: View {
    var intensity: CGFloat = 1
    /// Practice / recording — subtle live pulse (kept cheap).
    var isLive: Bool = false
    var audioLevel: CGFloat = 0
    /// Where the voice planet sits — orbits lock to this, not screen-bottom.
    var heroAnchor: UnitPoint = UnitPoint(x: 0.5, y: 0.40)

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        let fill = theme.currentAccentFill
        let liveBoost = isLive ? (0.55 + min(max(audioLevel, 0), 1) * 0.35) : 0.35
        let pulse = isLive ? (0.9 + liveBoost * 0.15) : 1.0
        let orbitPhase = reduceMotion ? CGFloat(0) : phase

        ZStack {
            PD.ColorToken.background

            LinearGradient(
                colors: [
                    Color.white.opacity(0.028 * intensity),
                    Color.clear,
                    Color.black.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            TaikaSoftTechnoWaveShape(
                phase: orbitPhase,
                seed: 1.1
            )
            .stroke(
                fill.opacity(Double(0.08 * intensity * pulse)),
                style: StrokeStyle(lineWidth: 1.0, lineCap: .round)
            )

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.50)],
                center: heroAnchor,
                startRadius: 120,
                endRadius: 540
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: isLive ? 14 : 28).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

/// Wide soft ribbon — cousin of course-card organic waves, stretched for full-screen atmosphere.
private struct TaikaSoftTechnoWaveShape: Shape {
    var phase: CGFloat
    var seed: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let shift = sin(phase * .pi * 2 + seed) * 22
        let yBase = rect.height * (0.74 + 0.05 * sin(seed * 1.3))
        var path = Path()
        path.move(to: CGPoint(x: -40, y: yBase + shift * 0.55))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.36, y: yBase - 28 + shift * 0.2),
            control1: CGPoint(x: rect.width * 0.12, y: yBase - 56 - shift),
            control2: CGPoint(x: rect.width * 0.22, y: yBase + 48 + shift * 0.4)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.68, y: yBase + 18 - shift * 0.25),
            control1: CGPoint(x: rect.width * 0.48, y: yBase - 62 + shift),
            control2: CGPoint(x: rect.width * 0.56, y: yBase + 54 - shift)
        )
        path.addCurve(
            to: CGPoint(x: rect.width + 40, y: yBase - 12 - shift * 0.15),
            control1: CGPoint(x: rect.width * 0.82, y: yBase - 36 + shift * 0.3),
            control2: CGPoint(x: rect.width * 0.92, y: yBase + 28 - shift)
        )
        return path
    }
}

/// Full-width header blur — frosted strip that fades into the canvas (Mail-style).
struct TaikaLiquidGlassHeaderBackdrop: View {
    /// Total painted height including the soft fade below the controls row.
    var height: CGFloat = 128

    var body: some View {
        TaikaNeutralGlassFill(tint: TaikaGlassTokens.headerTint)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .top)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.48),
                        .init(color: .black.opacity(0.45), location: 0.72),
                        .init(color: .black.opacity(0.12), location: 0.90),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .compositingGroup()
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

// Legacy aliases (if referenced elsewhere)
typealias TaikaGlassIconOrb = TaikaHeaderGlassButton
typealias TaikaGlassPill = TaikaHeaderGlassPill
