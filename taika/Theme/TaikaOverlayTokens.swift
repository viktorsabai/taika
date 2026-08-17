import SwiftUI

// MARK: - Sprint 0: shared Liquid Glass foundation
// This file intentionally stays inside the existing Theme layer. It owns only
// visual tokens and reusable overlay surfaces; product flows, routing, state,
// persistence, recognition and RevenueCat remain unchanged.

enum TaikaOverlayTokens {
    enum Material {
        static let cardOpacity: Double = 0.52
        static let backdropOpacity: Double = 0.68
        static let innerHighlightOpacity: Double = 0.18
        static let strokeOpacity: Double = 0.24
        static let secondaryStrokeOpacity: Double = 0.12
        static let shadowOpacity: Double = 0.38
    }

    enum Layout {
        static let cardRadius: CGFloat = 28
        static let controlRadius: CGFloat = 18
        static let compactRadius: CGFloat = 14
        static let cardHorizontalInset: CGFloat = 20
        static let cardTopInset: CGFloat = Theme.Layout.rootHeaderClearance
        static let contentHorizontalInset: CGFloat = 16
        static let compactControlHeight: CGFloat = 44
        static let primaryButtonHeight: CGFloat = 48
    }

    enum Motion {
        static let interaction = Animation.easeOut(duration: 0.18)
        static let presentation = Animation.easeOut(duration: 0.24)
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.52, blue: 0.85),
                Color(red: 0.85, green: 0.55, blue: 1.00)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// Shared continuous-canvas surface. Keep content and navigation outside it.
struct GlassSurface<Content: View>: View {
    let cornerRadius: CGFloat
    let content: () -> Content

    init(
        cornerRadius: CGFloat = TaikaOverlayTokens.Layout.cardRadius,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background {
                Theme.Surfaces.blackGlass(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Shared modal backdrop: preserve the screen context instead of replacing it
/// with an opaque gray slab.
struct GlassBackdrop: View {
    let onDismiss: () -> Void

    var body: some View {
        Theme.Surfaces.blackGlassScrim
            .opacity(TaikaOverlayTokens.Material.backdropOpacity)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .accessibilityHidden(true)
    }
}

/// Informational message primitive used by Game Park, Speaker and empty states.
struct GlassMessage<Content: View>: View {
    let title: String
    let symbol: String?
    let content: () -> Content

    init(
        title: String,
        symbol: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.content = content
    }

    var body: some View {
        GlassSurface {
            VStack(spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.center)
                content()
            }
            .padding(.horizontal, TaikaOverlayTokens.Layout.contentHorizontalInset)
            .padding(.vertical, 18)
        }
    }
}

/// Choice primitive for a short list of contextual modes or recovery paths.
struct GlassChoice<Content: View>: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
        self.content = content
    }

    private var indicatorSystemName: String {
        isSelected ? "checkmark.circle.fill" : "chevron.right"
    }

    private var indicatorForeground: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        }
        return AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.7))
    }

    @ViewBuilder
    private var titleContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(CD.ColorToken.text)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.75))
                    .lineLimit(2)
            }
        }
    }

    private var cardBackground: some View {
        let fillOpacity = isSelected ? 0.10 : 0.045
        let strokeOpacity = isSelected ? 0.22 : 0.10
        return RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.compactRadius, style: .continuous)
            .fill(Color.white.opacity(fillOpacity))
            .overlay {
                RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.compactRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: 1)
            }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                titleContent
                Spacer(minLength: 0)
                content()
                Image(systemName: indicatorSystemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(indicatorForeground)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: TaikaOverlayTokens.Layout.compactControlHeight)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

/// Compact entitlement/usage primitive. The caller owns the real quota value.
struct GlassQuota: View {
    let title: String
    let detail: String
    let progress: Double

    var body: some View {
        GlassSurface(cornerRadius: TaikaOverlayTokens.Layout.controlRadius) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(CD.ColorToken.text)
                    Spacer()
                    Text(detail)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.82))
                }
                ProgressView(value: min(max(progress, 0), 1))
                    .tint(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                Text("Обновится завтра")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.68))
            }
            .padding(14)
        }
    }
}

/// Paywall primitive keeps the existing paywall flow and only standardises its
/// material, hierarchy and CTA treatment.
struct GlassPaywall<Content: View>: View {
    let title: String
    let subtitle: String?
    let actionTitle: String
    let action: () -> Void
    let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
        self.content = content
    }

    var body: some View {
        GlassSurface {
            VStack(spacing: 14) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.center)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.78))
                        .multilineTextAlignment(.center)
                }
                content()
                OverlayGlassPrimaryButton(title: actionTitle, action: action)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
    }
}

/// Search/workbench primitive: input-like shell only; actual search state stays
/// in the existing feature view.
struct GlassWorkbench<Content: View>: View {
    let placeholder: String
    let symbol: String
    let content: () -> Content

    init(
        placeholder: String,
        symbol: String = "magnifyingglass",
        @ViewBuilder content: @escaping () -> Content = { EmptyView() }
    ) {
        self.placeholder = placeholder
        self.symbol = symbol
        self.content = content
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.78))
            Text(placeholder)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.72))
            Spacer(minLength: 0)
            content()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: TaikaOverlayTokens.Layout.compactControlHeight)
        .background {
            RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.compactRadius, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.compactRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

/// Shared CTA styling for all Sprint 0 glass primitives.
struct OverlayGlassPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(minHeight: TaikaOverlayTokens.Layout.primaryButtonHeight)
                .background(TaikaOverlayTokens.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.controlRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.26), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}
