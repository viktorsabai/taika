
import SwiftUI
import UIKit

// Temporary Theme shim for preview (maps to app tokens later)
public enum Theme {
    public enum Colors {
        public static var backgroundPrimary: Color { TaikaDynamicColors.background }
        public static var backgroundSecondary: Color { TaikaDynamicColors.backgroundSecondary }
        public static var card: Color { TaikaDynamicColors.card }
        public static var accent: Color { TaikaDynamicColors.accent }
        public static var textPrimary: Color { TaikaDynamicColors.text }
    }
    // unified layout rhythm for screens (root views) — use instead of magic numbers
    public enum Layout {
        /// horizontal page padding for root screens
        public static let pageHorizontal: CGFloat = 16
        /// vertical gap between global header and the first section on root screens
        public static let pageTopAfterHeader: CGFloat = rootHeaderClearance
        public static let pageTopAfterBackHeader: CGFloat = 55
        /// default vertical gap between major sections
        public static let sectionGap: CGFloat = 16
        /// vertical gap between a big header-card (e.g. lesson/course header) and the next section
        /// (needs to be larger than sectionGap to avoid card shadow/chrome overlap)
        public static let headerToSection: CGFloat = 24
        /// inner padding for section containers (cards/panels)
        public static let sectionInner: CGFloat = 16
        /// bottom safe gap (keeps content above floating bottom toolbar)
        public static let pageBottomSafeGap: CGFloat = bottomToolbarHeight
        /// legacy alias used by some screens
        public static let pageBottom: CGFloat = pageBottomSafeGap

        // MARK: - global bottom insets (avoid magic numbers in views)
        /// minimum bottom padding for scroll content
        public static let bottomInsetMin: CGFloat = 16
        /// Reserved space below the floating glass header. The header contains the wordmark,
        /// controls and page-title row; root content must begin below the full visual chrome.
        public static let rootHeaderClearance: CGFloat = 88
        /// Two-row game header with timer/progress controls.
        public static let rootHeaderClearanceGame: CGFloat = 104
        /// reserved height for the floating tab bar (capsule + bottom float)
        public static let bottomToolbarHeight: CGFloat = 68

        // MARK: - paywall layout (glass)
        public static let paywallHPad: CGFloat = 16
        /// reserved space for pro chip + close in the chrome
        public static let paywallChromeReserve: CGFloat = 58
        /// minimum gap between header / carousel / cta
        public static let paywallMinSectionGap: CGFloat = 18
        public static let paywallBottomInset: CGFloat = 16
        public static let paywallCarouselHeight: CGFloat = 232
        /// fixed height for paywall card (empty vs content)
        public static let paywallCardHeightEmpty: CGFloat = 520
        public static let paywallCardHeightFull: CGFloat = 680
        /// internal padding for glass content
        public static let paywallInnerVPad: CGFloat = 18
        public static let paywallInnerHPad: CGFloat = 20

        // MARK: - course ds bridging tokens (keep values stable)
        /// vertical spacing between stacked cards/rows inside a section (course ds)
        public static let sectionContentV: CGFloat = 12
        /// spacing from section title row to section content (course ds)
        public static let sectionTitleToContent: CGFloat = 14
        /// spacing between sections (top padding applied by course ds sections)
        public static let sectionTop: CGFloat = 20
        /// vertical padding for carousels inside sections (top+bottom)
        public static let carouselVPad: CGFloat = 4

        // MARK: - horizontal carousel depth (Course / Lesson / Main / Step — единая айдентика)
        /// visible peek per side (pt) so neighbors are visible
        public static let carouselDepthPeekMin: CGFloat = 24
        /// influence width factor for norm (0.6 = wider zone → stronger effect)
        public static let carouselDepthNormWidthFactor: CGFloat = 0.60
        public static let carouselDepthScaleSide: CGFloat = 0.85
        /// Согласовано с `CDLessonCarousel`: центр не > 1.0, иначе карта вылезает из фиксированного слота.
        public static let carouselDepthScaleCenter: CGFloat = 1.0
        public static let carouselDepthOpacitySide: CGFloat = 0.45
        public static let carouselDepthOpacityCenter: CGFloat = 1.00
        public static let carouselDepthYOffsetMax: CGFloat = 0

        // MARK: - intra-section (course ds)
        public static let rowV: CGFloat = 10
        public static let rowH: CGFloat = 10
        public static let chipGap: CGFloat = 10
        public static let metaGap: CGFloat = 6
        public static let iconGap: CGFloat = 8
        public static let inlineDividerGap: CGFloat = 6
        
        // MARK: - lessons ds: lesson header internal layout
        /// horizontal padding inside lesson header container
        public static let lessonHeaderHPad: CGFloat = PD.Spacing.screen
        /// top inset inside lesson header container
        public static let lessonHeaderTopInset: CGFloat = 28
        /// bottom inset inside lesson header container
        public static let lessonHeaderBottomInset: CGFloat = 20
        /// spacing between title and subtitle
        public static let lessonHeaderTitleToSubtitle: CGFloat = 12
        /// spacing between subtitle and progress row
        public static let lessonHeaderSubtitleToProgress: CGFloat = 18
        /// extra top padding applied to subtitle block (keeps air)
        public static let lessonHeaderSubtitleExtraTop: CGFloat = 8
        /// top padding applied to progress group
        public static let lessonHeaderProgressTop: CGFloat = 8

        // intra-section rhythm (padding and spacing INSIDE a section)
        public enum Section {
            /// horizontal inset for section content blocks
            public static let contentHorizontal: CGFloat = 16
            /// top inset for section content (under the section title/header row)
            public static let contentTop: CGFloat = 12
            /// bottom inset for section content
            public static let contentBottom: CGFloat = 16
            /// vertical gap between a section title row and its content
            public static let titleToContentGap: CGFloat = 12
            /// vertical gap between items inside a section content stack
            public static let itemGap: CGFloat = 12
        }
    }
    
    public enum Fonts {
        public static func appTitle(_ size: CGFloat) -> Font { .custom("ONMARK Trial", size: size) }
        /// Legacy score/statistics font kept for compatibility outside course metrics.
        public static func stat(_ size: CGFloat) -> Font { .custom("MVSKIFERRegular", size: size) }
        /// Strict numeric face for product metrics: technical, tabular and non-decorative.
        public static func metric(_ size: CGFloat) -> Font {
            .system(size: size, weight: .medium, design: .monospaced)
        }
        public static let heading: Font = .system(size: 22, weight: .semibold, design: .rounded)
        public static let body: Font    = .system(size: 16, weight: .regular, design: .rounded)
        public static let caption: Font = .system(size: 12, weight: .regular, design: .rounded)
    }
    public enum Radii {
        public static let card: CGFloat = 16
        public static let chip: CGFloat = 12
    }

    /// EPIC 5 identity: icon-only buttons; sizes for tap targets and visual weight.
    public enum IconButton {
        public static let cornerRadius: CGFloat = 10
        public static let sizeHeader: CGFloat = 36
        public static let sizeCard: CGFloat = 34
        /// Иконки на карточках крупнее — лучше видно и легче попасть (Ed Tech).
        public static let iconSizeCard: CGFloat = 18
        /// Минимальная зона нажатия для карточных иконок (доступность + «присутствие»).
        public static let tapMinCard: CGFloat = 48
    }

    /// EPIC 5: unified stroke tokens — readable outlines for blank-brain affordance.
    public enum Strokes {
        /// Outline for chips / icon buttons — adapts to light/dark.
        public static var strokeSubtle: Color {
            Color(uiColor: UIColor { tc in
                switch tc.userInterfaceStyle {
                case .dark: return UIColor(white: 1, alpha: 0.18)
                default: return UIColor(white: 0, alpha: 0.22)
                }
            })
        }
        /// Stronger outline for primary interactive cards / CTA frames.
        public static var strokeStrong: Color {
            Color(uiColor: UIColor { tc in
                switch tc.userInterfaceStyle {
                case .dark: return UIColor(white: 1, alpha: 0.26)
                default: return UIColor(white: 0, alpha: 0.28)
                }
            })
        }
        public static let strokeLineWidth: CGFloat = 1
        public static let strokeCardLineWidth: CGFloat = 1.25
    }

    /// EPIC 5: text block rules — avoid single-line ellipsis for user content; allow wrap + scale.
    public enum TextBlock {
        /// Max lines for card/lesson titles (user-facing content).
        public static let cardTitleLines: Int = 2
        /// Max lines for body/description text.
        public static let cardBodyLines: Int = 3
        /// Minimum scale factor for title text (readability).
        public static let titleMinimumScale: CGFloat = 0.72
        /// Minimum scale factor for body text.
        public static let bodyMinimumScale: CGFloat = 0.80
    }

    /// EPIC 5: step cards — квадрат ~268pt; типографика и лимиты строк под узкий контент + нижний action bar.
    public enum StepCardText {
        public static let titleLines: Int = 3
        public static let phoneticLines: Int = 3
        public static let thaiLines: Int = 3
        public static let lifehackLines: Int = 16
        public static let titleScale: CGFloat = 0.70
        public static let phoneticScale: CGFloat = 0.70
        public static let thaiScale: CGFloat = 0.76
        public static let lifehackScale: CGFloat = 0.88
        public static let blockSpacing: CGFloat = 10
        public static let titleFontSize: CGFloat = 19
        public static let lifehackTitleFontSize: CGFloat = 24
        public static let phoneticFontSize: CGFloat = 14
        public static let thaiFontSize: CGFloat = 13
        /// Тело лайфхака — крупно, как презентация, не как footnote.
        public static let lifehackBodyFontSize: CGFloat = 18
        public static let lifehackTipFontSize: CGFloat = 16
        public static let lifehackLineSpacing: CGFloat = 7
    }

    public enum Spacing {
        public static let outer: CGFloat = 16
    }
    public enum Gradients {
        /// Subtle glossy overlay used for panels/cards
        public static let panelGloss = LinearGradient(
            colors: [
                Color.white.opacity(0.08),   // очень мягкий верхний хайлайт
                Color.white.opacity(0.0)     // плавный уход в ноль
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        /// Neutral, low-contrast overlay for secondary chips/filters
        public static let chipNeutral = LinearGradient(
            colors: [Color.white.opacity(0.04), .white.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        /// Accent gradient for highlighted inline text (brighter pink → gentle lilac)
        public static let accentText = LinearGradient(
            colors: [
                // vivid pink start
                Color(red: 1.00, green: 0.52, blue: 0.85).opacity(1.0),
                // rosy mid (keeps warmth without washing out)
                Color(red: 0.98, green: 0.65, blue: 0.92).opacity(0.98),
                // soft lilac end (not white)
                Color(red: 0.90, green: 0.78, blue: 1.00).opacity(0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        /// compatibility alias (older DS code)
        public static let accentPink = accentText
        /// Ultra‑subtle ink sheen for primary text (opt‑in)
        public static let textPrimarySheen = LinearGradient(
            colors: [Color.white.opacity(0.06), .clear],
            startPoint: .top,
            endPoint: .bottom
        )

        /// Accent variant — Azure (softer jungle → sky)
        public static let accentAzure = LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.40, blue: 0.24), // wild jungle green
                Color(red: 0.20, green: 0.62, blue: 0.58), // soft lagoon teal (softer mid)
                Color(red: 0.78, green: 0.90, blue: 1.00)  // pale clear-sky blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Accent variant — Sun (yolk yellow → ember)
        public static let accentSun = LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.97, blue: 0.70), // clear sunny yellow (lighter start)
                Color(red: 1.00, green: 0.88, blue: 0.36), // warm midday yellow
                Color(red: 0.93, green: 0.34, blue: 0.08)  // ember orange (deeper, like coals)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Accent variant — Thai Tricolor (red‑currant → deep ocean blue)
        public static let accentThaiTricolor = LinearGradient(
            colors: [
                Color(red: 0.88, green: 0.15, blue: 0.28), // red‑currant
                Color(red: 0.10, green: 0.24, blue: 0.58)  // deep ocean blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public enum Surfaces {
        /// Unified card surface: заливка + читаемый контур + лёгкая тень.
        public static func card<S: Shape>(_ shape: S) -> some View {
            shape
                .fill(TaikaDynamicColors.card)
                .overlay(shape.stroke(TaikaDynamicColors.cardBorder, lineWidth: Theme.Strokes.strokeCardLineWidth))
                .shadow(color: TaikaDynamicColors.cardShadowAmbient.opacity(0.78), radius: 8, x: 0, y: 3)
                .shadow(color: TaikaDynamicColors.cardShadowTight.opacity(0.85), radius: 1.4, x: 0, y: 1)
        }

        /// Панель-секция (статы / ритм): мягкая тень без обводки — чище для blank-brain.
        public static func panel<S: Shape>(_ shape: S) -> some View {
            shape
                .fill(TaikaDynamicColors.card.opacity(0.96))
                .shadow(color: TaikaDynamicColors.cardShadowAmbient.opacity(0.45), radius: 5, x: 0, y: 2)
        }

        /// Жидкое глянцевое чёрное стекло: blur есть, серой «плёнки» нет.
        /// Полупрозрачный чёрный глянец — фон мутно читается сквозь карточку.
        /// Канон оверлеев / умного спикера / разбора / soft-wall / инфо-модалок.
        public static func blackGlass<S: Shape>(_ shape: S) -> some View {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(Color.black.opacity(0.52))
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.55)
                    )
                )
                .blendMode(.plusLighter)
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: Theme.Strokes.strokeLineWidth
                )
            }
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.38), radius: 28, y: 16)
        }

        /// Лёгкая context surface для overlay sheets: исходный экран остаётся виден сквозь material.
        public static func contextGlass<S: Shape>(_ shape: S) -> some View {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(Color.black.opacity(0.28))
                shape.stroke(Color.white.opacity(0.18), lineWidth: Theme.Strokes.strokeLineWidth)
            }
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.28), radius: 24, y: 12)
        }

        /// Backdrop модалок: translucent blur, сохраняющий читаемый исходный context.
        public static var blackGlassScrim: some View {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.34)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear,
                        Color.black.opacity(0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.plusLighter)
            }
        }
    }

    public struct AccentInlineText: ViewModifier {
        public func body(content: Content) -> some View {
            content
                .compositingGroup() // isolate from parent foreground/overlays
                .foregroundStyle(Theme.Gradients.accentText)
                // inner vertical gloss (as in LessonsDS)
                .overlay(
                    LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .blendMode(.screen)
                        .mask(content)
                )
                // shadows tuned to LessonsDS
                .shadow(color: Color.black.opacity(0.40), radius: 1.0, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.28), radius: 5, x: 0, y: 7)
                // keep crispness
                .saturation(1.08)
                .contrast(1.04)
        }
    }

    /// Белый маскот на «молочном» фоне: лёгкая глубина без перекраски ассета.
    public struct TaikaMascotChromeModifier: ViewModifier {
        @Environment(\.colorScheme) private var colorScheme
        public init() {}
        public func body(content: Content) -> some View {
            let light = colorScheme == .light
            content
                .compositingGroup()
                .shadow(color: Color.black.opacity(light ? 0.13 : 0.42), radius: light ? 11 : 8, x: 0, y: light ? 5 : 4)
                .shadow(color: Color.black.opacity(light ? 0.05 : 0.22), radius: 2, x: 0, y: 1)
        }
    }
}

extension View {
    public func taikaMascotChrome() -> some View {
        modifier(Theme.TaikaMascotChromeModifier())
    }

    /// Канон всплытий: жидкое чёрное стекло вместо серого material.
    public func taikaBlackGlassBackground(cornerRadius: CGFloat = 28) -> some View {
        background {
            Theme.Surfaces.blackGlass(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}

/// Brand phonetic: accent only on stress / tone arrows (не вся строка).
enum TaikaPhoneticText {
    private static let toneArrows: Set<Character> = ["→", "↓", "↘", "↑", "↗"]
    private static let accentScalars: Set<UnicodeScalar> = [
        UnicodeScalar(0x0301)!, UnicodeScalar(0x00B4)!, UnicodeScalar(0x02CA)!,
        UnicodeScalar(0x0300)!, UnicodeScalar(0x02CB)!, UnicodeScalar(0x0302)!,
        UnicodeScalar(0x02C6)!, UnicodeScalar(0x0306)!, UnicodeScalar(0x02D8)!,
        UnicodeScalar(0x030C)!, UnicodeScalar(0x02C7)!
    ]

    static func styled(
        _ raw: String,
        font: Font = .system(size: 15, weight: .semibold),
        baseColor: Color = PD.ColorToken.text
    ) -> Text {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for arrow in toneArrows {
            t = t.replacingOccurrences(of: String(arrow) + "-", with: String(arrow) + " ")
        }
        guard !t.isEmpty else { return Text("").font(font) }

        let separators: Set<Character> = [" ", "-", "·"]
        var result = Text("")
        var chunk = ""

        func flush() {
            guard !chunk.isEmpty else { return }
            let hasAccent = chunk.unicodeScalars.contains { accentScalars.contains($0) }
            let piece = Text(chunk).font(font)
            if hasAccent {
                result = result + piece.foregroundStyle(ThemeManager.shared.currentAccentFill)
            } else {
                result = result + piece.foregroundStyle(baseColor)
            }
            chunk = ""
        }

        for ch in t {
            if toneArrows.contains(ch) {
                flush()
                result = result + Text(String(ch)).font(font).foregroundStyle(ThemeManager.shared.currentAccentFill)
            } else if separators.contains(ch) {
                flush()
                result = result + Text(String(ch)).font(font).foregroundStyle(baseColor)
            } else {
                chunk.append(ch)
            }
        }
        flush()
        return result
    }
}

struct ThemePreview: View {
    var body: some View {
        TaikaRootVerticalScroll {
            VStack(spacing: 24) {
                // MARK: — Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("taikA — Design Moodboard")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text("Quick glance at colors, type, and components")
                        .font(.caption)
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

// MARK: — Colors Grid
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(text: "Colors")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        Swatch(name: "backgroundPrimary", desc: "Main background", color: Theme.Colors.backgroundPrimary)
                        Swatch(name: "backgroundSecondary", desc: "Secondary surface", color: Theme.Colors.backgroundSecondary)
                        Swatch(name: "card", desc: "Card surface", color: Theme.Colors.card)
                        Swatch(name: "accent", desc: "Accent / action", color: Theme.Colors.accent)
                    }
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Accent Variants (Gradients)
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(text: "Accent Variants")
                    VStack(spacing: 12) {
                        GradientSwatch(name: "accentAzure", desc: "лазурно‑голубой → зелёный", gradient: Theme.Gradients.accentAzure)
                        GradientSwatch(name: "accentSun", desc: "светло‑жёлтый (желток) → костёр", gradient: Theme.Gradients.accentSun)
                        GradientSwatch(name: "accentThaiTricolor", desc: "триколор Таиланда", gradient: Theme.Gradients.accentThaiTricolor)
                    }
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Typography (removed legacy panel; see FontShowcaseView below)

                // MARK: — Typography • Brand Set (showcase)
                FontShowcaseView()
                    .padding(20)
                    .background(panel)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Components snapshot
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(text: "Components")
                    VStack(spacing: 12) {
                        SpecCard(title: "Привет", subtitle: "са-ват-ди", tag: "Приветствие")
                        HStack(spacing: 12) {
                            PrimaryButtonPreview(title: "добавить в избранное")
                            OutlineButtonPreview(title: "играть ещё")
                        }
                    }
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Chips & Filters
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(text: "Chips & Filters")
                    HStack(spacing: 10) {
                        ChipPreview(title: "все", style: .neutral)
                        ChipPreview(title: "любимые", style: .active)
                        ChipPreview(title: "скрытые", style: .disabled)
                    }
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // MARK: — Tokens quicklook
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(text: "Tokens")
                    LabeledValue(label: "Card radius", value: "\(Int(Theme.Radii.card))")
                    LabeledValue(label: "Chip radius", value: "\(Int(Theme.Radii.chip))")
                    LabeledValue(label: "Outer spacing", value: "\(Int(Theme.Spacing.outer))")
                }
                .padding(20)
                .background(panel)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Spacer(minLength: 8)
            }
            .padding(16)
            .background(Theme.Colors.backgroundPrimary)
            .foregroundColor(Theme.Colors.textPrimary)
        }
    }

    // Subviews & helpers
    private var panel: some View {
        Theme.Colors.backgroundSecondary
            .overlay(Theme.Gradients.panelGloss)
    }
}

private struct SectionHeader: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.Colors.accent.opacity(0.6)).frame(width: 6, height: 6)
            Text(text).font(.system(size: 14, weight: .semibold, design: .rounded)).opacity(0.9)
        }
    }
}

private struct Swatch: View {
    let name: String
    let desc: String
    let color: Color
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color)
                .frame(width: 56, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.caption.bold())
                Text(desc).font(.caption).opacity(0.65)
            }
            Spacer()
        }
    }
}

private struct SpecCard: View {
    let title: String
    let subtitle: String
    let tag: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .taikaAccentText()
            HStack {
                Image(systemName: "heart.fill").font(.footnote)
                Text(tag).font(.footnote)
                Spacer()
                Image(systemName: "speaker.wave.2.fill")
            }
            .opacity(0.8)
        }
        .padding(16)
        .background(
            ZStack {
                Theme.Colors.card
                Theme.Gradients.panelGloss
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radii.card).stroke(Color.white.opacity(0.06)))
    }
}

private struct PrimaryButtonPreview: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(
                LinearGradient(colors: [Theme.Colors.accent.opacity(0.9), Theme.Colors.accent.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
    }
}

private struct OutlineButtonPreview: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.Colors.backgroundPrimary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.Colors.accent.opacity(0.6), lineWidth: 1))
    }
}

private struct ChipPreview: View {
    enum Style { case neutral, active, disabled }
    let title: String
    let style: Style
    var body: some View {
        let fg: Color = {
            switch style {
            case .active:   return Color.black.opacity(0.88)   // dark text on accent
            case .disabled: return Color.white.opacity(0.55)
            case .neutral:  return Theme.Colors.textPrimary
            }
        }()
        let stroke: Color = {
            switch style {
            case .active:   return Theme.Colors.accent.opacity(0.85)
            case .disabled: return Color.white.opacity(0.06)
            case .neutral:  return Color.white.opacity(0.12)
            }
        }()

        let base: some View = Group {
            switch style {
            case .neutral:
                ZStack {
                    Theme.Colors.backgroundSecondary
                    Theme.Gradients.chipNeutral
                    // soft top highlight for glassy feel
                    LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center)
                        .blendMode(.screen)
                }
            case .active:
                ZStack {
                    LinearGradient(colors: [Theme.Colors.accent.opacity(0.95), Theme.Colors.accent.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    // inner glossy highlight
                    LinearGradient(colors: [Color.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom)
                        .blendMode(.screen)
                }
            case .disabled:
                ZStack {
                    Theme.Colors.backgroundSecondary.opacity(0.7)
                    LinearGradient(colors: [Color.white.opacity(0.04), .clear], startPoint: .top, endPoint: .bottom)
                        .blendMode(.screen)
                }
            }
        }

        return Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(fg)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(
                Capsule().fill(.clear).overlay(base.clipShape(Capsule()))
            )
            .overlay(
                Capsule().stroke(stroke, lineWidth: 1)
                    .overlay(
                        // inner stroke for depth
                        Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5).blendMode(.overlay)
                    )
            )
            .shadow(color: Color.black.opacity(style == .active ? 0.18 : 0.10), radius: style == .active ? 10 : 6, x: 0, y: 4)
    }
}

private struct LabeledValue: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption)
            Spacer()
            Text(value).font(.caption.bold()).opacity(0.85)
        }
        .padding(.vertical, 2)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.06)), alignment: .bottom)
    }
}

// Brand font showcase helper view
private struct FontShowcaseView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(text: "Typography — Brand Set")

            // Название приложения (ONMARK Trial)
            VStack(alignment: .leading, spacing: 4) {
                Text("Название приложения")
                    .font(.caption)
                    .opacity(0.65)
                Text("taikA")
                    .font(Theme.Fonts.appTitle(36))
            }

            Divider().opacity(0.08)

            // Название курса (Heading)
            VStack(alignment: .leading, spacing: 4) {
                Text("Название курса (Heading)")
                    .font(.caption)
                    .opacity(0.65)
                Text("Основы тайского языка")
                    .font(Theme.Fonts.heading)
            }

            // Описание курса (Body)
            VStack(alignment: .leading, spacing: 4) {
                Text("Описание курса (Body)")
                    .font(.caption)
                    .opacity(0.65)
                Text("Короткое описание курса — русская транслитерация, тайские слова и примеры предложений.")
                    .font(Theme.Fonts.body)
                    .opacity(0.92)
            }

            // Заголовок секции (Semibold 22)
            VStack(alignment: .leading, spacing: 4) {
                Text("Заголовок секции (Semibold 22)")
                    .font(.caption)
                    .opacity(0.65)
                Text("Избранное • повторы • мини‑игры")
                    .font(Theme.Fonts.heading)
            }

            // Текст кнопки (Semibold 14)
            VStack(alignment: .leading, spacing: 4) {
                Text("Текст кнопки (Semibold 14)")
                    .font(.caption)
                    .opacity(0.65)
                Text("играть ещё")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }

            // Подпись / Caption (12)
            VStack(alignment: .leading, spacing: 4) {
                Text("Подпись / Caption (12)")
                    .font(.caption)
                    .opacity(0.65)
                Text("са‑ват‑ди • приветствие")
                    .font(Theme.Fonts.caption)
                    .opacity(0.9)
            }

            // Accent inline text (градиентный токен)
            VStack(alignment: .leading, spacing: 4) {
                Text("Accent inline (taikaAccentText)")
                    .font(.caption)
                    .opacity(0.65)
                Text("тайка — акцентный текст")
                    .font(Theme.Fonts.body)
                    .taikaAccentText()
            }
        }
    }
}

#Preview {
    ThemePreview()
}

// Convenience View extension for taika accent inline text
extension View {
    /// Apply taika inline accent text (1:1 with LessonsDS)
    func taikaAccentText() -> some View {
        modifier(Theme.AccentInlineText())
    }
}

// MARK: - Unified Section/Subsection text style
extension Text {
    /// Primary section label style (e.g. "ПОДБОРКА ДНЯ", "УРОКИ").
    func taikaSectionTitleStyle() -> some View {
        self
            .font(PD.FontToken.caption(12, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(PD.ColorToken.textSecondary)
            .textCase(.uppercase)
    }

    /// Secondary subsection label style (e.g. "ВСЕ КУРСЫ", lesson/course context).
    func taikaSubsectionStyle(accent: Bool = true) -> some View {
        self
            .font(PD.FontToken.caption(11, weight: .semibold))
            .kerning(0.5)
            .foregroundStyle(accent ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(PD.ColorToken.textSecondary))
            .textCase(.uppercase)
    }
}

/// Заголовок секции с accent-pip слева — «это секция», не просто серый caps в пустоте.
struct TaikaSectionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Capsule(style: .continuous)
                .fill(ThemeManager.shared.currentAccentFill)
                .frame(width: 3, height: 12)
            Text(title)
                .taikaSectionTitleStyle()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

/// Ряд секции: pip+title слева, trailing справа (как в бланковых приложениях).
struct TaikaSectionHeaderRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String) where Trailing == EmptyView {
        self.title = title
        self.trailing = { EmptyView() }
    }

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TaikaSectionLabel(title: title)
            Spacer(minLength: 8)
            trailing()
        }
    }
}

/// Крупный заголовок корневой вкладки; опционально — интерактивный фильтр справа (одна строка).
struct TaikaScreenPageTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(title: String) where Trailing == EmptyView {
        self.title = title
        self.trailing = { EmptyView() }
    }

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(CD.FontToken.title(28, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing()
        }
        .padding(.horizontal, CD.Spacing.screen)
    }
}

/// Иконка пустого экрана: контурный SF Symbol + акцент + мягкий pulse.
struct TaikaEmptyStateIcon: View {
    let systemName: String
    var size: CGFloat = 30

    @State private var pulse = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(ThemeManager.shared.currentAccentFill)
            .symbolRenderingMode(.hierarchical)
            .scaleEffect(pulse ? 1.08 : 1.0)
            .opacity(pulse ? 1.0 : 0.82)
            .symbolEffect(.pulse, options: .repeating.speed(0.55), isActive: true)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// Колонка статистики курса/урока: строгая технологичная цифра + подпись. Без рамок.
public struct TaikaStatMetric: View {
    public var valueText: String
    public var label: String
    public var valueSize: CGFloat
    public var accent: Bool
    public var appeared: Bool
    public var delay: TimeInterval

    public init(
        valueText: String,
        label: String,
        valueSize: CGFloat = 34,
        accent: Bool = true,
        appeared: Bool = true,
        delay: TimeInterval = 0
    ) {
        self.valueText = valueText
        self.label = label
        self.valueSize = valueSize
        self.accent = accent
        self.appeared = appeared
        self.delay = delay
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text(valueText)
                .font(Theme.Fonts.metric(valueSize))
                .foregroundStyle(
                    accent
                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                    : AnyShapeStyle(PD.ColorToken.text.opacity(0.92))
                )
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .scaleEffect(appeared ? 1 : 0.86)
                .animation(
                    .spring(response: 0.55, dampingFraction: 0.78).delay(delay),
                    value: appeared
                )
            Text(label)
                .font(.system(size: valueSize >= 48 ? 13 : 12, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Счётчик очков MV-SKIFER: плавно «набирает» значение (Speaker, онбординг, статистика).
public struct TaikaCountingScore<S: ShapeStyle>: View {
    public let value: Int
    public let font: Font
    public let color: S
    public var suffix: String = ""

    @State private var displayed: Int = 0

    public init(value: Int, font: Font, color: S, suffix: String = "") {
        self.value = value
        self.font = font
        self.color = color
        self.suffix = suffix
    }

    public var body: some View {
        Text("\(displayed)\(suffix)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear { runCount(to: value) }
            .onChange(of: value) { _, newValue in
                runCount(to: newValue)
            }
    }

    private func runCount(to target: Int) {
        displayed = 0
        let clamped = max(0, target)
        guard clamped > 0 else { return }
        let steps = min(clamped, 28)
        let stepDuration = 0.85 / Double(steps)
        for i in 1...steps {
            let next = Int(round(Double(clamped) * Double(i) / Double(steps)))
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeOut(duration: 0.06)) {
                    displayed = next
                }
            }
        }
    }
}

/// Кольцо + крупный скор + подпись — «вау»-момент после первой попытки (без полного PRO-разбора).
public struct TaikaScoreHero: View {
    public let score: Int
    public let caption: String
    public var ringSize: CGFloat = 118
    public var fontSize: CGFloat = 48
    public var lineWidth: CGFloat = 5

    @State private var ringProgress: CGFloat = 0
    @State private var appeared = false

    public init(
        score: Int,
        caption: String,
        ringSize: CGFloat = 118,
        fontSize: CGFloat = 48,
        lineWidth: CGFloat = 5
    ) {
        self.score = score
        self.caption = caption
        self.ringSize = ringSize
        self.fontSize = fontSize
        self.lineWidth = lineWidth
    }

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        let target = CGFloat(max(0, min(100, score))) / 100.0

        ZStack {
            Circle()
                .fill(ThemeManager.shared.currentAccentTintColor.opacity(appeared ? 0.22 : 0))
                .frame(width: ringSize * 1.35, height: ringSize * 1.35)
                .blur(radius: 18)
                .scaleEffect(appeared ? 1.05 : 0.7)

            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    AnyShapeStyle(accent),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                TaikaCountingScore(
                    value: score,
                    font: .taikaStat(fontSize),
                    color: AnyShapeStyle(accent),
                    suffix: "%"
                )
                Text(caption)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 6)
        }
        .frame(width: ringSize, height: ringSize)
        .scaleEffect(appeared ? 1 : 0.72)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            ringProgress = 0
            appeared = false
            withAnimation(.spring(response: 0.58, dampingFraction: 0.76)) {
                appeared = true
            }
            withAnimation(.easeOut(duration: 0.95).delay(0.12)) {
                ringProgress = target
            }
        }
        .onChange(of: score) { _, _ in
            ringProgress = 0
            appeared = false
            withAnimation(.spring(response: 0.58, dampingFraction: 0.76)) {
                appeared = true
            }
            withAnimation(.easeOut(duration: 0.95).delay(0.12)) {
                ringProgress = target
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(score) процентов, \(caption)")
    }
}

/// Мини-волны для «Послушай» и записи — лёгкий motion без тяжёлого Speaker UI.
public struct TaikaListenWaveBars: View {
    public var active: Bool
    public var meter: Double = 0.35
    public var barCount: Int = 5

    @State private var phase: CGFloat = 0

    public init(active: Bool, meter: Double = 0.35, barCount: Int = 5) {
        self.active = active
        self.meter = meter
        self.barCount = barCount
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .frame(width: 3, height: barHeight(i))
                    .opacity(active ? 0.92 : 0.35)
            }
        }
        .frame(height: 16)
        .onAppear { startPhaseIfNeeded() }
        .onChange(of: active) { _, isActive in
            if isActive { startPhaseIfNeeded() }
        }
        .accessibilityHidden(true)
    }

    private func barHeight(_ index: Int) -> CGFloat {
        let base: CGFloat = 4
        let amp = CGFloat(max(0.12, min(1.0, active ? meter : 0.22)))
        let wobble = active ? (0.35 + 0.65 * wave(index)) : 0.45
        return base + 11 * amp * wobble
    }

    private func wave(_ index: Int) -> CGFloat {
        let t = (Double(phase) + Double(index) * 0.14).truncatingRemainder(dividingBy: 1.0)
        let v = 1.0 - abs(t - 0.5) * 2.0
        return CGFloat(max(0.0, v))
    }

    private func startPhaseIfNeeded() {
        let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        phase = 0
        guard active, !isPreview else { return }
        withAnimation(.linear(duration: 0.95).repeatForever(autoreverses: false)) {
            phase = 1
        }
    }
}

private struct GradientSwatch: View {
    let name: String
    let desc: String
    let gradient: LinearGradient
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(gradient)
                .frame(width: 56, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.caption.bold())
                Text(desc).font(.caption).opacity(0.65)
            }
            Spacer()
        }
    }
}
