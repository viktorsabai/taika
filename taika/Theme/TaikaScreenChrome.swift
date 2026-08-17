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
            Color.black
            LinearGradient(
                colors: [
                    Color.white.opacity(0.035),
                    Color.clear,
                    Color.black.opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    Color(red: 0.56, green: 0.16, blue: 0.42).opacity(0.12),
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

/// Full-width header blur — even frosted strip, no accent blobs.
struct TaikaLiquidGlassHeaderBackdrop: View {
    var body: some View {
            TaikaNeutralGlassFill(tint: TaikaGlassTokens.headerTint * 0.72)
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
