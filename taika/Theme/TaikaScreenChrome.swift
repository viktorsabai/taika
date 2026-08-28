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
    static let headerTint: Double = 0.36
    /// Toolbar stays neutral chrome — no accent wash.
    static let toolbarTint: Double = 0.42
    static let buttonTint: Double = 0.44
    static let edgeStroke: Double = 0.15
    static let innerSheenTop: Double = 0.08
}

/// Neutral frosted glass (toolbar + header strip + icon orbs). No theme recolor.
private struct TaikaNeutralGlassFill: View {
    var tint: Double = TaikaGlassTokens.headerTint

    var body: some View {
        ZStack {
            SystemBlur(style: .systemChromeMaterial)
            Color.black.opacity(tint)
            LinearGradient(
                colors: [
                    Color.white.opacity(TaikaGlassTokens.innerSheenTop),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Instagram-style circular header control — visibly tappable glass button.
struct TaikaHeaderGlassButton<Content: View>: View {
    var size: CGFloat = 38
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: size, height: size)
            .background {
                TaikaNeutralGlassFill(tint: TaikaGlassTokens.buttonTint)
                    .clipShape(Circle())
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(TaikaGlassTokens.edgeStroke), lineWidth: 0.5)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
    }
}

/// Pill glass for mic/heart counters in the root header.
struct TaikaHeaderGlassPill<Content: View>: View {
    var height: CGFloat = 38
    var horizontalPadding: CGFloat = 11
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .background {
                TaikaNeutralGlassFill(tint: TaikaGlassTokens.buttonTint)
                    .clipShape(Capsule(style: .continuous))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(TaikaGlassTokens.edgeStroke), lineWidth: 0.5)
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
            Color.black.opacity(0.985)
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
            Color.black
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

/// Спокойный techno-фон для фокус-сцен Спикера.
/// Графит + мягкие радиальные wash + размытые волновые линии (как на карточках курсов, но шире и тише).
struct TaikaTechnoSpaceBackdrop: View {
    var intensity: CGFloat = 1
    /// Practice / recording — subtle live pulse (kept cheap).
    var isLive: Bool = false
    var audioLevel: CGFloat = 0

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        let accent = theme.currentAccentTintColor
        let liveBoost = isLive ? (0.55 + min(max(audioLevel, 0), 1) * 0.35) : 0.35
        let pulse = isLive ? (0.9 + liveBoost * 0.15) : 1.0

        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.06)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.03 * intensity),
                    Color.clear,
                    Color.black.opacity(0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Radial washes, not solid ellipses — soft edges without blur cost.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.13 * intensity * pulse),
                            accent.opacity(0.05 * intensity * pulse),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 190
                    )
                )
                .frame(width: 380, height: 300)
                .offset(x: 28, y: -180)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.035 * intensity),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 240)
                .offset(x: -60, y: 200)

            // Ribbons live below the hero sphere — they must never cut across it.
            ForEach(Array(Self.waveSeeds.prefix(2).enumerated()), id: \.offset) { index, seed in
                TaikaSoftTechnoWaveShape(
                    phase: reduceMotion ? 0 : phase,
                    seed: seed
                )
                .stroke(
                    accent.opacity((index == 1 ? 0.20 : 0.11) * intensity * Double(pulse)),
                    style: StrokeStyle(lineWidth: index == 1 ? 1.4 : 0.9, lineCap: .round)
                )
                .offset(y: CGFloat(index) * 30)
            }

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.48)],
                center: .center,
                startRadius: 140,
                endRadius: 560
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            // One slow implicit animation — not a per-frame TimelineView
            withAnimation(.linear(duration: isLive ? 10 : 18).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private static let waveSeeds: [CGFloat] = [0.15, 1.1, 2.2, 3.35, 4.4]
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

/// Full-width header blur — even frosted strip, no accent blobs.
struct TaikaLiquidGlassHeaderBackdrop: View {
    var body: some View {
            TaikaNeutralGlassFill(tint: TaikaGlassTokens.headerTint * 0.24)
                .mask {
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black)
                    LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.35), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 72)
                }
            }
            .compositingGroup()
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

// Legacy aliases (if referenced elsewhere)
typealias TaikaGlassIconOrb = TaikaHeaderGlassButton
typealias TaikaGlassPill = TaikaHeaderGlassPill
