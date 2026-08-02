import SwiftUI
import UIKit


// MARK: - Profile Design System (PD)
// Lightweight UI kit used by Profile screens. 100% SwiftUI.
// All tokens have sensible defaults and can later be mapped to ThemeDesign.

public enum PD {
    // MARK: Tokens
    public enum ColorToken {
        public static var background: SwiftUI.Color { TaikaDynamicColors.background }
        public static var card: SwiftUI.Color { TaikaDynamicColors.card }
        public static var stroke: SwiftUI.Color { TaikaDynamicColors.stroke }
        public static var text: SwiftUI.Color { TaikaDynamicColors.text }
        public static var textSecondary: SwiftUI.Color { TaikaDynamicColors.textSecondary }
        public static var accent: SwiftUI.Color { TaikaDynamicColors.accent }
        public static var chip: SwiftUI.Color { TaikaDynamicColors.chip }
        /// Разбор по тонам: цвет стрелки «нужно было» (нейтральный).
        public static var toneExpected: SwiftUI.Color {
            Color(uiColor: UIColor { tc in
                switch tc.userInterfaceStyle {
                case .dark: return UIColor(white: 1, alpha: 0.55)
                default: return UIColor(white: 0, alpha: 0.45)
                }
            })
        }
        /// Разбор: цвет стрелки «ты сказал», когда тон верный.
        public static var toneCorrect: SwiftUI.Color { Color(red: 0.30, green: 0.85, blue: 0.45) }
        /// Разбор: цвет стрелки «ты сказал», когда тон неверный.
        public static var toneWrong: SwiftUI.Color { Color(red: 0.98, green: 0.35, blue: 0.38) }
    }

    public enum Radius {
        public static var card: CGFloat { 20 }
        public static var chip: CGFloat { 12 }
    }

    public enum Spacing {
        public static var screen: CGFloat { 20 }
        public static var inner: CGFloat { 12 }
        public static var tiny: CGFloat { 6 }

        // Aliases for cross-DS compatibility
        public static var small: CGFloat { tiny }
        public static var medium: CGFloat { inner }   // use inner as medium spacing
        public static var block: CGFloat { screen }   // use screen as outer block spacing
    }

    public enum FontToken {
        public static func title(_ size: CGFloat = 32, weight: Font.Weight = .bold) -> Font { .system(size: size, weight: weight, design: .rounded) }
        public static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight, design: .rounded) }
        public static func caption(_ size: CGFloat = 13, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .rounded) }
    }

    public enum BrandFont {
        public static func appTitle(_ size: CGFloat) -> Font {
            // Use brand font if available; fallback to rounded system
            if UIFont(name: "OnmarkTRIAL", size: size) != nil { return .custom("OnmarkTRIAL", size: size) }
            return .system(size: size, weight: .bold, design: .rounded)
        }
    }

    public enum GradientToken {
        public static var pro: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.36, blue: 0.65),
                    Color(red: 0.98, green: 0.48, blue: 0.72)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - pdstyle (inject appds tokens here)
public struct PDStyle: Sendable {
    public var background: Color
    public var card: Color
    public var stroke: Color
    public var text: Color
    public var textSecondary: Color
    public var accent: Color
    public var accentFill: AnyShapeStyle
    public var chip: Color

    public init(
        background: Color,
        card: Color,
        stroke: Color,
        text: Color,
        textSecondary: Color,
        accent: Color,
        accentFill: AnyShapeStyle,
        chip: Color
    ) {
        self.background = background
        self.card = card
        self.stroke = stroke
        self.text = text
        self.textSecondary = textSecondary
        self.accent = accent
        self.accentFill = accentFill
        self.chip = chip
    }

    public static var legacy: PDStyle {
        .init(
            background: PD.ColorToken.background,
            card: PD.ColorToken.card,
            stroke: PD.ColorToken.stroke,
            text: PD.ColorToken.text,
            textSecondary: PD.ColorToken.textSecondary,
            accent: PD.ColorToken.accent,
            accentFill: AnyShapeStyle(PD.ColorToken.accent),
            chip: PD.ColorToken.chip
        )
    }

    public static var appDS: PDStyle {
        var s = legacy
        // take canonical accent from app theme (so profile graphs + chips match the rest of the app)
        s.accentFill = AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        return s
    }
}

// MARK: - Typing dots (inline, subtle)
struct PDTypingDots: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack(spacing: 4) {
            Circle().frame(width: 6, height: 6)
                .opacity(Double((phase.truncatingRemainder(dividingBy: 3) >= 0) ? 1 : 0.35))
            Circle().frame(width: 6, height: 6)
                .opacity(Double((phase.truncatingRemainder(dividingBy: 3) >= 1) ? 1 : 0.35))
            Circle().frame(width: 6, height: 6)
                .opacity(Double((phase.truncatingRemainder(dividingBy: 3) >= 2) ? 1 : 0.35))
        }
        .foregroundColor(PD.ColorToken.textSecondary)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
    }
}

// MARK: - Marquee / assistant stripe (fixed height, no layout jump)
public struct PDProfileMarquee: View {
    public var messages: [String]
    public var mascot: Image?
    public var typingDuration: TimeInterval = 2.2
    public var showDuration: TimeInterval = 3.2
    public var typingCharInterval: TimeInterval = 0.045
    public var style: PDStyle = .appDS

    @State private var idx: Int = 0
    @State private var isTyping: Bool = true
    @State private var shown: String = ""
    @State private var charIndex: Int = 0
    @State private var hasStarted: Bool = false

    public init(messages: [String], mascot: Image? = Image("mascot.profile"), style: PDStyle = .appDS) {
        self.messages = messages
        self.mascot = mascot
        self.style = style
    }

    public var body: some View {
        HStack(alignment: .center, spacing: PD.Spacing.inner) {
            mascot?
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .taikaMascotChrome()

            ZStack(alignment: .leading) {
                // Fixed bubble to avoid height jumps
                RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                    .fill(style.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                            .stroke(style.stroke, lineWidth: 1)
                    )

                // Content
                HStack(alignment: .center, spacing: 8) {
                    if isTyping {
                        PDTypingDots()
                    } else {
                        Text(shown)
                            .font(PD.FontToken.body(14, weight: .regular))
                            .foregroundColor(style.text)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, PD.Spacing.inner)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            startCycle()
        }
        .onDisappear {
            // stop further cycles when view leaves screen (previews/navigation)
            hasStarted = false
        }
    }

    private func startCycle() {
        guard hasStarted, !messages.isEmpty else { return }
        // Phase 1: thinking dots
        shown = ""
        charIndex = 0
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDuration) {
            // Phase 2: typewriter reveal
            withAnimation(.easeInOut(duration: 0.2)) { isTyping = false }
            beginTyping(message: messages[safe: idx] ?? "")
        }
    }

    private func beginTyping(message: String) {
        shown = ""
        charIndex = 0
        typeNextChar(message: message)
    }

    private func typeNextChar(message: String) {
        guard charIndex < message.count else {
            // Phase 3: linger full text
            DispatchQueue.main.asyncAfter(deadline: .now() + showDuration) {
                guard hasStarted else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    idx = (idx + 1) % max(messages.count, 1)
                    isTyping = true
                }
                startCycle()
            }
            return
        }
        let i = message.index(message.startIndex, offsetBy: charIndex)
        shown.append(message[i])
        charIndex += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + typingCharInterval) {
            guard hasStarted else { return }
            typeNextChar(message: message)
        }
    }
}

// Safe index helper
private extension Collection {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - Ready-to-use section: "ТАЙКА FM"
public struct PDFMSection: View {
    public var title: String = "ТАЙКА FM"
    public var messages: [String]
    public var mascot: Image?
    public var style: PDStyle = .appDS
    
    public init(
        messages: [String] = [
            "Проверь бейджи за сегодня",
            "Напомнить о целях на неделю?",
            "Нужна помощь с подпиской или оплатой?"
        ],
        mascot: Image? = Image("mascot.profile"),
        style: PDStyle = .appDS
    ) {
        self.messages = messages
        self.mascot = mascot
        self.style = style
    }
    
    public var body: some View {
        PDSection(title, style: style) {
            TaikaFMRow(
                scope: .profile,
                mode: .typing,
                showBubble: true,
                repeats: true
            )
        }
    }
}
// MARK: - Section container (title + content) — ритмика как в CDSection / Theme.Layout
public struct PDSection<Content: View>: View {
    public var title: String
    public var style: PDStyle = .appDS
    public let content: Content

    public init(_ title: String, style: PDStyle = .appDS, @ViewBuilder content: () -> Content) {
        self.title = title
        self.style = style
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.sectionTitleToContent) {
            Text(title.uppercased())
                .taikaSectionTitleStyle()
                .padding(.horizontal, PD.Spacing.screen)

            content
        }
        .padding(.top, Theme.Layout.sectionTop)
    }
}

// MARK: - Dashboard: сводка в айдентике приложения (Surfaces.card, метрики-чипы, заголовок)
public struct PDSummaryCard: View {
    public var totalStableSteps: Int
    public var currentStreak: Int
    public var totalMasteryPercent: Int
    public var accentFill: AnyShapeStyle

    public init(totalStableSteps: Int, currentStreak: Int, totalMasteryPercent: Int, accentFill: AnyShapeStyle) {
        self.totalStableSteps = totalStableSteps
        self.currentStreak = currentStreak
        self.totalMasteryPercent = totalMasteryPercent
        self.accentFill = accentFill
    }

    private let shape = RoundedRectangle(cornerRadius: Theme.Radii.card, style: .continuous)

    public var body: some View {
        ZStack {
            Theme.Surfaces.card(shape)

            VStack(alignment: .leading, spacing: 18) {
                Text("Твой прогресс")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(PD.ColorToken.textSecondary)

                HStack(spacing: 0) {
                    metricBlock(label: "шагов", value: "\(totalStableSteps)", accent: false)
                    divider
                    metricBlock(label: "дней", value: "\(currentStreak)", accent: false)
                    divider
                    metricBlock(label: "мастерство", value: "\(totalMasteryPercent)%", accent: true)
                }
                .frame(maxWidth: .infinity)

                Text("слова по курсам • стрик • мастерство")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.82))
            }
            .padding(20)
        }
        .overlay(shape.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
        .clipShape(shape)
        .padding(.horizontal, PD.Spacing.screen)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Strokes.strokeSubtle)
            .frame(width: 1, height: 42)
            .padding(.horizontal, 14)
    }

    private func metricBlock(label: String, value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? accentFill : AnyShapeStyle(PD.ColorToken.text))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Dashboard: карусель «твои цифры»
public enum PDMasteryKind {
    case totalMastery
    case speakingPower
    case memory
}

public struct PDMasteryCarouselItem: Identifiable {
    public let id: String
    public let kind: PDMasteryKind
    public init(id: String, kind: PDMasteryKind) { self.id = id; self.kind = kind }
}

public struct PDMasteryCarousel: View {
    public var totalMasteryPercent: Int
    public var averagePronunciationScore: Int?
    public var completedRecallGamesCount: Int
    public var accentFill: AnyShapeStyle

    private static let cardWidth: CGFloat = 200
    private static let cardHeight: CGFloat = 140
    private static let spacing: CGFloat = CardDS.Metrics.carouselSpacing

    private var items: [PDMasteryCarouselItem] {
        [
            PDMasteryCarouselItem(id: "mastery", kind: .totalMastery),
            PDMasteryCarouselItem(id: "speaking", kind: .speakingPower),
            PDMasteryCarouselItem(id: "memory", kind: .memory),
        ]
    }

    public init(totalMasteryPercent: Int, averagePronunciationScore: Int?, completedRecallGamesCount: Int, accentFill: AnyShapeStyle) {
        self.totalMasteryPercent = totalMasteryPercent
        self.averagePronunciationScore = averagePronunciationScore
        self.completedRecallGamesCount = completedRecallGamesCount
        self.accentFill = accentFill
    }

    /// Карусель в стиле календарных карточек в Main: sideInset чтобы ничего не обрезалось, scale/opacity/rotation3D по расстоянию от центра.
    public var body: some View {
        GeometryReader { outer in
            let sideInset = max(0, (outer.size.width - Self.cardWidth) / 2)
            TaikaCarouselScroll {
                LazyHStack(spacing: Self.spacing) {
                    ForEach(items) { item in
                        GeometryReader { cellGeo in
                            let viewportCenterX = outer.size.width / 2
                            let cellCenterX = cellGeo.frame(in: .named("profileMasteryCarousel")).midX
                            let dist = abs(cellCenterX - viewportCenterX)
                            let norm = min(1.0, dist / max(1.0, outer.size.width * 0.65))
                            let scale = 0.94 + 0.06 * (1.0 - norm)
                            let opacity = 0.72 + 0.28 * (1.0 - norm)

                            PDMasteryCardView(
                                item: item,
                                totalMasteryPercent: totalMasteryPercent,
                                averagePronunciationScore: averagePronunciationScore ?? 0,
                                completedRecallGamesCount: completedRecallGamesCount,
                                accentFill: accentFill
                            )
                            .frame(width: Self.cardWidth, height: Self.cardHeight)
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .shadow(
                                color: Color.black.opacity(0.12),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                            .zIndex(Double(1.0 - norm))
                        }
                        .frame(width: Self.cardWidth, height: Self.cardHeight)
                        .id(item.id)
                    }
                }
                .padding(.horizontal, sideInset)
            }
            .coordinateSpace(name: "profileMasteryCarousel")
        }
        .frame(height: Self.cardHeight + 32)
        .padding(.horizontal, PD.Spacing.screen)
    }
}


public struct PDMasteryCardView: View {
    public let item: PDMasteryCarouselItem
    public var totalMasteryPercent: Int
    public var averagePronunciationScore: Int
    public var completedRecallGamesCount: Int
    public var accentFill: AnyShapeStyle

    private let shape = RoundedRectangle(cornerRadius: Theme.Radii.card, style: .continuous)

    public var body: some View {
        ZStack {
            Color.clear
            VStack(alignment: .leading, spacing: 10) {
                iconView

                Text(cardTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))

                valueView

                Text(cardSubtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private var cardTitle: String {
        switch item.kind {
        case .totalMastery: return "прогресс курса"
        case .speakingPower: return "произношение"
        case .memory: return "игры на память"
        }
    }

    private var cardSubtitle: String {
        switch item.kind {
        case .totalMastery: return "твой прогресс"
        case .speakingPower: return "как ты звучишь"
        case .memory: return "игр пройдено"
        }
    }

    private var iconView: some View {
        Group {
            switch item.kind {
            case .totalMastery: Image(systemName: "chart.line.uptrend.xyaxis")
            case .speakingPower: Image(systemName: "waveform")
            case .memory: Image(systemName: "brain.head.profile")
            }
        }
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(accentFill)
    }

    private var valueView: some View {
        Group {
            switch item.kind {
            case .totalMastery: Text("\(totalMasteryPercent)%")
            case .speakingPower: Text("\(averagePronunciationScore)%")
            case .memory: Text("\(completedRecallGamesCount)")
            }
        }
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(accentFill)
    }
}

// MARK: - Dashboard: радар готовности к ситуациям
public struct PDRadarBlock: View {
    public var values: [Double]
    public var accentFill: AnyShapeStyle

    public init(values: [Double], accentFill: AnyShapeStyle) {
        self.values = values
        self.accentFill = accentFill
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.Section.titleToContentGap) {
            Text("Рынок, такси, иммиграция, кафе — по твоему прогрессу.")
                .font(PD.FontToken.caption(13, weight: .regular))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
            ThaiSurvivalRadarView(values: values, accentFill: accentFill, linesOnly: true)
        }
        .padding(.horizontal, PD.Spacing.screen)
    }
}

// MARK: - Dashboard: PRO и настройки (ряды кнопок)
public struct PDUtilityBlock: View {
    public var isPro: Bool
    public var onPRO: () -> Void
    public var onSettings: () -> Void
    public var onLanguage: () -> Void
    public var onSupport: () -> Void

    public init(isPro: Bool, onPRO: @escaping () -> Void, onSettings: @escaping () -> Void, onLanguage: @escaping () -> Void, onSupport: @escaping () -> Void) {
        self.isPro = isPro
        self.onPRO = onPRO
        self.onSettings = onSettings
        self.onLanguage = onLanguage
        self.onSupport = onSupport
    }

    public var body: some View {
        VStack(spacing: Theme.Layout.Section.itemGap) {
            if !isPro {
                Button(action: onPRO) {
                    HStack(spacing: PD.Spacing.inner) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                        Text("Upgrade to PRO")
                            .font(PD.FontToken.body(17, weight: .medium))
                    }
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            Button(action: onSettings) {
                HStack(spacing: PD.Spacing.inner) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                    Text("Настройки")
                        .font(PD.FontToken.body(17, weight: .medium))
                }
                .foregroundStyle(PD.ColorToken.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button(action: onLanguage) {
                HStack(spacing: PD.Spacing.inner) {
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                    Text("Language Settings")
                        .font(PD.FontToken.body(17, weight: .medium))
                }
                .foregroundStyle(PD.ColorToken.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button(action: onSupport) {
                HStack(spacing: PD.Spacing.inner) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16))
                    Text("Support")
                        .font(PD.FontToken.body(17, weight: .medium))
                }
                .foregroundStyle(PD.ColorToken.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PD.Spacing.screen)
    }
}

// MARK: - Row cell with chevron (supports expand)
public struct PDRow: View {
    public var systemIcon: String
    public var title: String
    public var showsChevron: Bool
    public var isExpanded: Bool
    public var style: PDStyle = .appDS
    public var action: () -> Void

    public var expandedContent: AnyView?


    public init(
        icon: String,
        title: String,
        showsChevron: Bool = true,
        isExpanded: Bool = false,
        style: PDStyle = .appDS,
        action: @escaping () -> Void,
        expandedContent: AnyView? = nil
    ) {
        self.systemIcon = icon
        self.title = title
        self.showsChevron = showsChevron
        self.isExpanded = isExpanded
        self.style = style
        self.action = action
        self.expandedContent = expandedContent
    }

    public var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: PD.Spacing.inner) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(style.chip)
                            .frame(width: 42, height: 42)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(style.stroke, lineWidth: 1)
                            )
                        Image(systemName: systemIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(style.text)
                    }
                    Text(title)
                        .font(PD.FontToken.body(17, weight: .regular))
                        .foregroundColor(style.text)
                    Spacer()

                    if showsChevron {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(style.accent)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isExpanded)
                    }
                }
                .padding(.horizontal, PD.Spacing.inner)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded, let expandedContent {
                expandedContent
                    .padding(.horizontal, PD.Spacing.inner)
                    .padding(.bottom, PD.Spacing.inner)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Grouped list helper (supports expandable rows)
public struct PDListGroup: View {
    public var rows: [Row]
    public var style: PDStyle = .appDS

    public struct Row {
        public var icon: String
        public var title: String
        public var isExpanded: Bool
        public var action: () -> Void
        public var expandedContent: AnyView?

        public init(
            icon: String,
            title: String,
            isExpanded: Bool = false,
            action: @escaping () -> Void,
            expandedContent: AnyView? = nil
        ) {
            self.icon = icon
            self.title = title
            self.isExpanded = isExpanded
            self.action = action
            self.expandedContent = expandedContent
        }
    }

    public init(_ rows: [Row], style: PDStyle = .appDS) {
        self.rows = rows
        self.style = style
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, r in
                PDRow(
                    icon: r.icon,
                    title: r.title,
                    showsChevron: true,
                    isExpanded: r.isExpanded,
                    style: style,
                    action: r.action,
                    expandedContent: r.expandedContent
                )

                if idx != rows.count - 1 {
                    Rectangle()
                        .fill(style.stroke)
                        .frame(height: 1)
                        .padding(.leading, 68)
                }
            }
        }
    }
}

// MARK: - Progress scope (courses vs lessons)
public enum PDProgressScope: String, CaseIterable {
    case courses = "курсы"
    case lessons = "уроки"
}

// MARK: - Segmented tabs (2 items)
public struct PDTabbedSwitch: View {
    public var items: [PDProgressScope] = PDProgressScope.allCases
    public var selected: PDProgressScope
    public var onSelect: (PDProgressScope) -> Void


    public init(
        items: [PDProgressScope] = PDProgressScope.allCases,
        selected: PDProgressScope,
        onSelect: @escaping (PDProgressScope) -> Void
    ) {
        self.items = items
        self.selected = selected
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.self) { it in
                let isSelected = (it == selected)
                Button {
                    onSelect(it)
                } label: {
                    Text(it.rawValue)
                        .font(PD.FontToken.caption(13, weight: .semibold))
                        .foregroundColor(isSelected ? PD.ColorToken.text : PD.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? PD.ColorToken.chip.opacity(1.0) : PD.ColorToken.chip)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? PD.ColorToken.accent.opacity(0.55) : PD.ColorToken.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}


// MARK: - PDMetric (data-only type for metrics)
public struct PDMetric: Hashable {
    public var key: String
    public var title: String
    public var value7d: String
    public var delta7d: String?

    public init(key: String, title: String, value7d: String, delta7d: String? = nil) {
        self.key = key
        self.title = title
        self.value7d = value7d
        self.delta7d = delta7d
    }
}

// MARK: - Stat graphs (mock-friendly, DS-only)
public struct PDStatSparkline: View {
    public var values: [Double]
    public var style: PDStyle = .appDS

    public init(values: [Double], style: PDStyle = .appDS) {
        self.values = values
        self.style = style
    }

    public var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 1
            let span = max(maxV - minV, 0.0001)

            ZStack {
                // area fill
                Path { p in
                    guard values.count >= 2 else { return }
                    for i in values.indices {
                        let x = w * (Double(i) / Double(max(values.count - 1, 1)))
                        let yN = (values[i] - minV) / span
                        let y = h - (h * yN)
                        if i == values.startIndex {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(style.accentFill)
                .opacity(0.14)

                // line
                Path { p in
                    guard values.count >= 2 else { return }
                    for i in values.indices {
                        let x = w * (Double(i) / Double(max(values.count - 1, 1)))
                        let yN = (values[i] - minV) / span
                        let y = h - (h * yN)
                        if i == values.startIndex {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(style.accentFill, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
    }
}

public struct PDStatBars7d: View {
    public var values: [Double]
    public var style: PDStyle = .appDS

    public init(values: [Double], style: PDStyle = .appDS) {
        self.values = values
        self.style = style
    }

    public var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 0.0001)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(style.accentFill)
                        .frame(height: max(8, geo.size.height * (v / maxV)))
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 6)
        }
    }
}

public struct PDTwoGraphBlock: View {
    public var weekly: [Double]
    public var last7: [Double]
    public var style: PDStyle = .appDS

    @State private var showWeeklyInfo: Bool = false
    @State private var showLast7Info: Bool = false

    public init(weekly: [Double], last7: [Double], style: PDStyle = .appDS) {
        self.weekly = weekly
        self.last7 = last7
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // weekly
            HStack(spacing: 8) {
                Text("по неделям")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundColor(style.textSecondary)
                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showWeeklyInfo.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(style.textSecondary)
                        .opacity(0.85)
                }
                .buttonStyle(.plain)
            }

            if showWeeklyInfo {
                Text("общий тренд по выбранной метрике, агрегировано по неделям")
                    .font(PD.FontToken.caption(13, weight: .regular))
                    .foregroundColor(style.textSecondary)
                    .transition(.opacity)
            }

            PDStatSparkline(values: weekly, style: style)
                .frame(height: 128)

            // last 7 days
            HStack(spacing: 8) {
                Text("последние 7 дней")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundColor(style.textSecondary)
                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showLast7Info.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(style.textSecondary)
                        .opacity(0.85)
                }
                .buttonStyle(.plain)
            }

            if showLast7Info {
                Text("распределение по дням за последнюю неделю")
                    .font(PD.FontToken.caption(13, weight: .regular))
                    .foregroundColor(style.textSecondary)
                    .transition(.opacity)
            }

            PDStatBars7d(values: last7, style: style)
                .frame(height: 128)
        }
    }
}


// MARK: - progress panel (ds owns visuals; view will own data later)
public struct PDProgressPanel: View {
    public var scope: PDProgressScope
    public var onScopeChange: (PDProgressScope) -> Void

    public var coursesMetrics: [PDMetric]
    public var lessonsMetrics: [PDMetric]

    public var selectedCourseMetricKey: Binding<String>
    public var selectedLessonMetricKey: Binding<String>

    public var onSelectCourseMetric: (String) -> Void
    public var onSelectLessonMetric: (String) -> Void

    public var weeklyByCourseMetric: [String: [Double]]
    public var last7ByCourseMetric: [String: [Double]]
    public var weeklyByLessonMetric: [String: [Double]]
    public var last7ByLessonMetric: [String: [Double]]

    public var style: PDStyle = .appDS

    public init(
        scope: PDProgressScope,
        onScopeChange: @escaping (PDProgressScope) -> Void,
        coursesMetrics: [PDMetric],
        lessonsMetrics: [PDMetric],
        selectedCourseMetricKey: Binding<String>,
        selectedLessonMetricKey: Binding<String>,
        onSelectCourseMetric: @escaping (String) -> Void,
        onSelectLessonMetric: @escaping (String) -> Void,
        weeklyByCourseMetric: [String: [Double]],
        last7ByCourseMetric: [String: [Double]],
        weeklyByLessonMetric: [String: [Double]],
        last7ByLessonMetric: [String: [Double]],
        style: PDStyle = .appDS
    ) {
        self.scope = scope
        self.onScopeChange = onScopeChange
        self.coursesMetrics = coursesMetrics
        self.lessonsMetrics = lessonsMetrics
        self.selectedCourseMetricKey = selectedCourseMetricKey
        self.selectedLessonMetricKey = selectedLessonMetricKey
        self.onSelectCourseMetric = onSelectCourseMetric
        self.onSelectLessonMetric = onSelectLessonMetric
        self.weeklyByCourseMetric = weeklyByCourseMetric
        self.last7ByCourseMetric = last7ByCourseMetric
        self.weeklyByLessonMetric = weeklyByLessonMetric
        self.last7ByLessonMetric = last7ByLessonMetric
        self.style = style
    }

    public init(
        scope: PDProgressScope,
        onScopeChange: @escaping (PDProgressScope) -> Void,
        coursesMetrics: [PDMetric],
        lessonsMetrics: [PDMetric],
        selectedCourseMetricKey: String,
        selectedLessonMetricKey: String,
        onSelectCourseMetric: @escaping (String) -> Void,
        onSelectLessonMetric: @escaping (String) -> Void,
        weeklyByCourseMetric: [String: [Double]],
        last7ByCourseMetric: [String: [Double]],
        weeklyByLessonMetric: [String: [Double]],
        last7ByLessonMetric: [String: [Double]],
        style: PDStyle = .appDS
    ) {
        self.init(
            scope: scope,
            onScopeChange: onScopeChange,
            coursesMetrics: coursesMetrics,
            lessonsMetrics: lessonsMetrics,
            selectedCourseMetricKey: .constant(selectedCourseMetricKey),
            selectedLessonMetricKey: .constant(selectedLessonMetricKey),
            onSelectCourseMetric: onSelectCourseMetric,
            onSelectLessonMetric: onSelectLessonMetric,
            weeklyByCourseMetric: weeklyByCourseMetric,
            last7ByCourseMetric: last7ByCourseMetric,
            weeklyByLessonMetric: weeklyByLessonMetric,
            last7ByLessonMetric: last7ByLessonMetric,
            style: style
        )
    }

    // Convenience: DS-only mock panel (lets ProfileView compile while data wiring is pending)
    public init() {
        self.scope = .courses
        self.onScopeChange = { _ in }

        self.coursesMetrics = [
            .init(key: "courses_completed", title: "пройдено", value7d: "1", delta7d: "+1"),
            .init(key: "courses_started", title: "начато", value7d: "2", delta7d: "+0"),
            .init(key: "courses_active", title: "активно", value7d: "3", delta7d: "+1"),
        ]
        self.lessonsMetrics = [
            .init(key: "lessons_completed", title: "уроки", value7d: "3", delta7d: "+1"),
            .init(key: "words_learned", title: "слова", value7d: "42", delta7d: "+8"),
            .init(key: "phrases_learned", title: "фразы", value7d: "9", delta7d: "+2"),
        ]

        self.selectedCourseMetricKey = .constant("courses_completed")
        self.selectedLessonMetricKey = .constant("lessons_completed")

        self.onSelectCourseMetric = { _ in }
        self.onSelectLessonMetric = { _ in }

        self.weeklyByCourseMetric = [
            "courses_completed": [0, 0, 1, 1, 1, 2, 2, 3],
            "courses_started": [1, 1, 1, 2, 2, 2, 3, 3],
            "courses_active": [2, 2, 3, 3, 4, 4, 4, 5],
        ]
        self.last7ByCourseMetric = [
            "courses_completed": [0, 0, 0, 1, 0, 0, 0],
            "courses_started": [0, 1, 0, 0, 0, 1, 0],
            "courses_active": [1, 1, 1, 1, 1, 1, 1],
        ]
        self.weeklyByLessonMetric = [
            "lessons_completed": [1, 2, 2, 3, 3, 4, 4, 5],
            "words_learned": [10, 14, 16, 18, 24, 30, 36, 42],
            "phrases_learned": [2, 3, 3, 4, 5, 6, 8, 9],
        ]
        self.last7ByLessonMetric = [
            "lessons_completed": [0, 1, 0, 1, 0, 1, 0],
            "words_learned": [4, 6, 3, 7, 5, 9, 8],
            "phrases_learned": [1, 1, 0, 2, 1, 2, 2],
        ]
        self.style = .appDS
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                AppMiniChip(
                    title: PDProgressScope.courses.rawValue,
                    style: (scope == .courses) ? .accent : .neutral
                ) {
                    onScopeChange(.courses)
                }

                AppMiniChip(
                    title: PDProgressScope.lessons.rawValue,
                    style: (scope == .lessons) ? .accent : .neutral
                ) {
                    onScopeChange(.lessons)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 2)

            if scope == .courses {
                TaikaCarouselScroll {
                    HStack(spacing: 10) {
                        ForEach(coursesMetrics, id: \.key) { m in
                            AppMetricDeltaChip(
                                item: AppMetricDeltaItem(
                                    title: m.title,
                                    value: m.value7d,
                                    delta: (m.delta7d ?? "")
                                ),
                                onTap: {
                                    onSelectCourseMetric(m.key)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                let w = weeklyByCourseMetric[selectedCourseMetricKey.wrappedValue] ?? [2, 3, 4, 3, 5, 6, 6, 7]
                let d = last7ByCourseMetric[selectedCourseMetricKey.wrappedValue] ?? [0, 1, 1, 2, 1, 3, 2]

                PDTwoGraphBlock(
                    weekly: w,
                    last7: d,
                    style: style
                )
            } else {
                TaikaCarouselScroll {
                    HStack(spacing: 10) {
                        ForEach(lessonsMetrics, id: \.key) { m in
                            AppMetricDeltaChip(
                                item: AppMetricDeltaItem(
                                    title: m.title,
                                    value: m.value7d,
                                    delta: (m.delta7d ?? "")
                                ),
                                onTap: {
                                    onSelectLessonMetric(m.key)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                let w = weeklyByLessonMetric[selectedLessonMetricKey.wrappedValue] ?? [6, 7, 8, 7, 9, 10, 11, 12]
                let d = last7ByLessonMetric[selectedLessonMetricKey.wrappedValue] ?? [2, 3, 1, 4, 2, 5, 3]

                PDTwoGraphBlock(
                    weekly: w,
                    last7: d,
                    style: style
                )
            }
        }
        .padding(.bottom, 2)
        .padding(.top, 2)
    }
}

// MARK: - preview/demo wrapper (state only for previews)
private struct PDProgressPanelDemo: View {
    @State private var scope: PDProgressScope = .courses
    @State private var selectedCourseMetric: String = "courses_completed"
    @State private var selectedLessonMetric: String = "lessons_completed"

    private let coursesMetrics: [PDMetric] = [
        .init(key: "courses_completed", title: "пройдено", value7d: "1", delta7d: "+1"),
        .init(key: "courses_started", title: "начато", value7d: "2", delta7d: "+0"),
        .init(key: "courses_active", title: "активно", value7d: "3", delta7d: "+1")
    ]

    private let lessonsMetrics: [PDMetric] = [
        .init(key: "lessons_completed", title: "уроки", value7d: "3", delta7d: "+1"),
        .init(key: "words_learned", title: "слова", value7d: "42", delta7d: "+8"),
        .init(key: "phrases_learned", title: "фразы", value7d: "9", delta7d: "+2")
    ]

    private let weeklyByCourse: [String: [Double]] = [
        "courses_completed": [0, 0, 1, 1, 1, 2, 2, 3],
        "courses_started": [1, 1, 1, 2, 2, 2, 3, 3],
        "courses_active": [2, 2, 3, 3, 4, 4, 4, 5]
    ]

    private let last7ByCourse: [String: [Double]] = [
        "courses_completed": [0, 0, 0, 1, 0, 0, 0],
        "courses_started": [0, 1, 0, 0, 0, 1, 0],
        "courses_active": [1, 1, 1, 1, 1, 1, 1]
    ]

    private let weeklyByLesson: [String: [Double]] = [
        "lessons_completed": [1, 2, 2, 3, 3, 4, 4, 5],
        "words_learned": [10, 14, 16, 18, 24, 30, 36, 42],
        "phrases_learned": [2, 3, 3, 4, 5, 6, 8, 9]
    ]

    private let last7ByLesson: [String: [Double]] = [
        "lessons_completed": [0, 1, 0, 1, 0, 1, 0],
        "words_learned": [4, 6, 3, 7, 5, 9, 8],
        "phrases_learned": [1, 1, 0, 2, 1, 2, 2]
    ]

    var body: some View {
        PDProgressPanel(
            scope: scope,
            onScopeChange: { scope = $0 },
            coursesMetrics: coursesMetrics,
            lessonsMetrics: lessonsMetrics,
            selectedCourseMetricKey: $selectedCourseMetric,
            selectedLessonMetricKey: $selectedLessonMetric,
            onSelectCourseMetric: { selectedCourseMetric = $0 },
            onSelectLessonMetric: { selectedLessonMetric = $0 },
            weeklyByCourseMetric: weeklyByCourse,
            last7ByCourseMetric: last7ByCourse,
            weeklyByLessonMetric: weeklyByLesson,
            last7ByLessonMetric: last7ByLesson,
            style: .appDS
        )
    }
}


// MARK: - Activity (last 7 days heat + day note)
public struct PDActivityDay: Hashable {
    public var key: String            // stable id (e.g. yyyy-mm-dd)
    public var title: String          // e.g. "вчера", "сегодня", "пн"
    public var intensity01: Double    // 0...1 (storage stays simple; mapping to AppDS is inside the panel)

    // legacy/fallback (kept for now)
    public var lines: [String]        // short summary lines

    // AppDS lego payload (preferred)
    public var events: [PDActivityEvent]

    public init(key: String, title: String, intensity: Double, lines: [String] = [], events: [PDActivityEvent] = []) {
        self.key = key
        self.title = title
        self.intensity01 = max(0, min(1, intensity))
        self.lines = lines
        self.events = events
    }

    public var summary: String {
        if !lines.isEmpty { return lines.joined(separator: " • ") }
        if events.isEmpty { return "нет активности" }

        // compact summary from events (title/value)
        let parts: [String] = events.compactMap {
            if let v = $0.value, !v.isEmpty { return "\($0.title): \(v)" }
            return $0.title
        }
        return parts.isEmpty ? "нет активности" : parts.joined(separator: " • ")
    }
}

public struct PDActivityEvent: Hashable {
    public var kind: AppActivityEventKind
    public var title: String
    public var subtitle: String?
    public var value: String?

    public init(kind: AppActivityEventKind, title: String, subtitle: String? = nil, value: String? = nil) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.value = value
    }
}

public struct PDActivityPanel: View {
    public var days: [PDActivityDay]
    public var selectedIndex: Binding<Int?>
    public var onSelect: (Int?) -> Void
    public var style: PDStyle = .appDS

    @State private var showInfo: Bool = false

    public init(
        days: [PDActivityDay],
        selectedIndex: Binding<Int?>,
        onSelect: @escaping (Int?) -> Void,
        style: PDStyle = .appDS
    ) {
        self.days = days
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
        self.style = style
    }

    // DS-only mock: do NOT reference concrete AppActivityEventKind cases here.
    // AppDS owns the enum cases; ProfileDS should compile even if AppDS changes them.
    public init(style: PDStyle = .appDS) {
        self.days = [
            .init(key: "d-6", title: "", intensity: 0.05, events: []),
            .init(key: "d-5", title: "", intensity: 0.20, events: []),
            .init(key: "d-4", title: "", intensity: 0.35, events: []),
            .init(key: "d-3", title: "", intensity: 0.55, events: []),
            .init(key: "d-2", title: "", intensity: 0.15, events: []),
            .init(key: "d-1", title: "", intensity: 0.75, events: []),
            .init(key: "d0", title: "", intensity: 0.00, events: [])
        ]
        self.selectedIndex = .constant(nil)
        self.onSelect = { _ in }
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("последние 7 дней")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundColor(style.textSecondary)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showInfo.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(style.textSecondary)
                        .opacity(0.85)
                }
                .buttonStyle(.plain)
            }

            if showInfo {
                Text("яркость квадрата = интенсивность дня. тап — показать, что происходило")
                    .font(PD.FontToken.caption(13, weight: .regular))
                    .foregroundColor(style.textSecondary)
                    .transition(.opacity)
            }

            // AppDS lego: week heat row
            AppActivityWeekRow(
                intensities: days.map { AppActivityIntensity.from01($0.intensity01) },
                selectedIndex: selectedIndex.wrappedValue ?? -1,
                onSelect: { idx in
                    if idx < 0 || idx >= days.count {
                        selectedIndex.wrappedValue = nil
                        onSelect(nil)
                    } else {
                        selectedIndex.wrappedValue = idx
                        onSelect(idx)
                    }
                }
            )
            .frame(height: 32)

            // (weekday label row removed)

            if let i = selectedIndex.wrappedValue, days.indices.contains(i) {
                let d = days[i]
                AppActivityDayNoteCard(
                    dayTitle: "",
                    summary: d.summary,
                    intensity: AppActivityIntensity.from01(d.intensity01),
                    events: d.events.map {
                        AppActivityEvent(
                            kind: $0.kind,
                            title: $0.title,
                            subtitle: $0.subtitle
                        )
                    },
                    onDetails: {}
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: selectedIndex.wrappedValue)
        .padding(.top, 2)
    }
}

// MARK: - Compatibility aliases (for existing ProfileView references)
// Do NOT use these in new code. Kept only to avoid breaking old call sites.

public typealias PDMyProgressPanel = PDProgressPanel
public typealias PDMyActivityPanel = PDActivityPanel


// MARK: - Study accordion (list + one detail panel)
public enum PDStudyPanel: Hashable {
    case progress
    case activity
}

public struct PDStudyAccordion: View {
    // compatibility shim: older call sites reference PDStudyAccordion.Selection
    public typealias Selection = PDStudyPanel
    public var selected: PDStudyPanel?
    public var onSelect: (PDStudyPanel?) -> Void
    public var progressContent: AnyView
    public var activityContent: AnyView
    public var style: PDStyle = .appDS

    public init(
        selected: PDStudyPanel?,
        onSelect: @escaping (PDStudyPanel?) -> Void,
        progressContent: AnyView,
        activityContent: AnyView,
        style: PDStyle = .appDS
    ) {
        self.selected = selected
        self.onSelect = onSelect
        self.progressContent = progressContent
        self.activityContent = activityContent
        self.style = style
    }

    public init(
        selected: PDStudyPanel?,
        onSelect: @escaping (PDStudyPanel?) -> Void,
        @ViewBuilder progressContent: () -> some View,
        @ViewBuilder activityContent: () -> some View,
        style: PDStyle = .appDS
    ) {
        self.selected = selected
        self.onSelect = onSelect
        self.progressContent = AnyView(progressContent())
        self.activityContent = AnyView(activityContent())
        self.style = style
    }

    public var body: some View {
        PDListGroup([
            .init(
                icon: "graduationcap",
                title: "мой прогресс",
                isExpanded: selected == .progress,
                action: {
                    onSelect(selected == .progress ? nil : .progress)
                },
                expandedContent: (selected == .progress)
                    ? AnyView(
                        progressContent
                            .padding(.top, PD.Spacing.tiny)
                            .transition(.opacity)
                    )
                    : nil
            ),
            .init(
                icon: "chart.bar",
                title: "моя активность",
                isExpanded: selected == .activity,
                action: {
                    onSelect(selected == .activity ? nil : .activity)
                },
                expandedContent: (selected == .activity)
                    ? AnyView(
                        activityContent
                            .padding(.top, PD.Spacing.tiny)
                            .transition(.opacity)
                    )
                    : nil
            )
        ], style: style)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: selected)
    }
}

// MARK: - Preview
#Preview("Profile DS") {
    ZStack {
        PDStyle.appDS.background.ignoresSafeArea()
        TaikaRootVerticalScroll {
            VStack(spacing: 0) {
                PDFMSection()

                PDSection("Учёба") {
                    _PDStudyAccordionDemo()
                }

                PDSection("Аккаунт") {
                    PDListGroup([
                        .init(icon: "creditcard", title: "Оплата и подписка", action: {}),
                        .init(icon: "rectangle.and.pencil.and.ellipsis", title: "Личная информация", action: {}),
                    ])
                }

                PDSection("Служба") {
                    PDListGroup([
                        .init(icon: "questionmark.circle", title: "Помощь и поддержка", action: {}),
                    ])
                }
            }
            .padding(.vertical, 20)
        }
    }
}

private struct _PDStudyAccordionDemo: View {
    @State private var selected: PDStudyPanel? = .progress

    var body: some View {
        PDStudyAccordion(
            selected: selected,
            onSelect: { selected = $0 },
            progressContent: AnyView(PDProgressPanelDemo()),
            activityContent: AnyView(_PDActivityPanelDemo())
        )
    }
}

private struct _PDActivityPanelDemo: View {
    @State private var selected: Int? = nil

    var body: some View {
        let mock = PDActivityPanel(style: .appDS)
        PDActivityPanel(
            days: mock.days,
            selectedIndex: $selected,
            onSelect: { selected = $0 },
            style: .appDS
        )
    }
}

// MARK: - Dashboard MVP (Minimalist Analytics)

/// Универсальный контейнер для виджетов прогресса на профиле
public struct ProfileCardDS<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(PD.Spacing.inner)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
    }
}

// MARK: - Cyber-Nomad: Glass card (Blur 20px, border 0.5 white 10%)

public struct GlassCardDS<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = PD.Radius.card

    public init(cornerRadius: CGFloat = PD.Radius.card, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(PD.Spacing.inner)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.72))
                    )
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .blendMode(.plusLighter)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
    }
}

// MARK: - Mastery Card (Glass + living progress bar: Watch-style rings in one row, neon blur)
/// Data: Mastery % and "Stable" words count. Visual: glass tile, horizontal segments with glow.
public struct MasteryCardView: View {
    let masteryPercent: Double
    let stableWordsCount: Int
    let recognitionPercent: Int
    let recallPercent: Int
    let speakingPercent: Int
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)
    @State private var phase: CGFloat = 0

    public init(
        masteryPercent: Double,
        stableWordsCount: Int,
        recognitionPercent: Int = 0,
        recallPercent: Int = 0,
        speakingPercent: Int = 0,
        accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)
    ) {
        self.masteryPercent = masteryPercent
        self.stableWordsCount = stableWordsCount
        self.recognitionPercent = recognitionPercent
        self.recallPercent = recallPercent
        self.speakingPercent = speakingPercent
        self.accentFill = accentFill
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Living progress: 3 segments in one row (Watch-style, neon)
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    let p = segmentValue(i)
                    LivingSegmentBar(value: p, phase: phase, accentFill: accentFill)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 28)

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(masteryPercentText)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(PD.ColorToken.text)
                Text("Mastery")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Spacer(minLength: 0)
                Text("\(stableWordsCount)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(PD.ColorToken.text)
                Text("Stable")
                    .font(PD.FontToken.caption(11, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }

    private func segmentValue(_ i: Int) -> CGFloat {
        switch i {
        case 0: return CGFloat(recognitionPercent) / 100
        case 1: return CGFloat(recallPercent) / 100
        case 2: return CGFloat(speakingPercent) / 100
        default: return 0
        }
    }

    private var masteryPercentText: String {
        let v = Int(round(min(100, max(0, masteryPercent))))
        return "\(v)%"
    }
}

private struct LivingSegmentBar: View {
    let value: CGFloat
    let phase: CGFloat
    var accentFill: AnyShapeStyle

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let v = min(1, max(0, value))
            let glow = 0.5 + 0.5 * sin(phase * .pi * 2)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: h / 2, style: .continuous)
                    .fill(PD.ColorToken.chip.opacity(0.8))
                    .frame(height: h)
                RoundedRectangle(cornerRadius: h / 2, style: .continuous)
                    .fill(accentFill)
                    .frame(width: max(4, w * v), height: h)
                    .shadow(color: PD.ColorToken.accent.opacity(0.6), radius: 4, x: 0, y: 0)
                    .opacity(0.85 + 0.15 * glow)
            }
        }
        .frame(height: 28)
    }
}

// MARK: - Skill Stats: two square tiles (Speaker + Games), hairline borders
public struct ProfileSkillStatsTwoTilesView: View {
    let pronunciationScore: Int
    let recallGamesCount: Int
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)

    public init(pronunciationScore: Int, recallGamesCount: Int, accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)) {
        self.pronunciationScore = pronunciationScore
        self.recallGamesCount = recallGamesCount
        self.accentFill = accentFill
    }

    public var body: some View {
        HStack(spacing: 0.5) {
            // Speaker tile
            ProfileSkillTileView(
                icon: "mic.fill",
                value: "\(min(100, max(0, pronunciationScore)))%",
                label: "Speaker",
                accentFill: accentFill,
                animated: true
            )
            .frame(maxWidth: .infinity)

            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.5)

            // Games tile
            ProfileSkillTileView(
                icon: "gamecontroller.fill",
                value: "\(recallGamesCount)",
                label: "Recall",
                accentFill: accentFill,
                animated: false
            )
            .frame(maxWidth: .infinity)
        }
        .background(PD.ColorToken.card.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProfileSkillTileView: View {
    let icon: String
    let value: String
    let label: String
    var accentFill: AnyShapeStyle
    var animated: Bool
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(accentFill)
                .scaleEffect(animated && pulse ? 1.08 : 1.0)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(PD.ColorToken.text)
            Text(label)
                .font(PD.FontToken.caption(11, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
        }
        .padding(.vertical, 16)
        .onAppear { if animated { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true } } }
    }
}

// MARK: - Achievement Deck (carousel, calendar-card style, parallax)
public struct PDAchievementItem: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let iconSF: String
    public let unlocked: Bool

    public init(id: String, title: String, subtitle: String? = nil, iconSF: String, unlocked: Bool) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconSF = iconSF
        self.unlocked = unlocked
    }
}

public struct AchievementDeckCarousel: View {
    let items: [PDAchievementItem]
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)
    let cardWidth: CGFloat = 100
    let cardHeight: CGFloat = 120

    public init(items: [PDAchievementItem], accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)) {
        self.items = items
        self.accentFill = accentFill
    }

    public var body: some View {
        TaikaCarouselScroll {
            HStack(spacing: -16) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    AchievementDeckCardView(item: item, accentFill: accentFill)
                        .frame(width: cardWidth, height: cardHeight)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: cardHeight + 8)
    }
}

/// Single achievement card — glass tile, calendar-cell style (like Main), icon + title
public struct AchievementDeckCardView: View {
    let item: PDAchievementItem
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)

    public init(item: PDAchievementItem, accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)) {
        self.item = item
        self.accentFill = accentFill
    }

    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 10) {
                Image(systemName: item.iconSF)
                    .font(.system(size: 28))
                    .foregroundStyle(item.unlocked ? accentFill : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.5)))
                Text(item.title)
                    .font(PD.FontToken.caption(11, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(item.unlocked ? PD.ColorToken.text : PD.ColorToken.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Identity Halo: Mastery Ring (дышит, цвет новичок→мастер, моноширин, статус)

public struct MasteryRingHaloView: View {
    let streakDays: Int
    let masteryFraction: Double
    let learnedCount: Int
    var ringColor: Color { masteryRingColor(masteryFraction) }
    @State private var breathe: Bool = false

    public init(streakDays: Int, masteryFraction: Double, learnedCount: Int) {
        self.streakDays = streakDays
        self.masteryFraction = masteryFraction
        self.learnedCount = learnedCount
    }

    private func masteryRingColor(_ f: Double) -> Color {
        let t = min(1, max(0, f))
        if t < 0.25 { return Color(red: 0.2, green: 0.5, blue: 0.95) }
        if t < 0.5 { return Color(red: 0.4, green: 0.75, blue: 0.95) }
        if t < 0.75 { return Color(red: 0.95, green: 0.65, blue: 0.3) }
        return Color(red: 0.95, green: 0.75, blue: 0.2)
    }

    private var statusLabel: String {
        let p = masteryFraction
        if p >= 0.7 { return "Speaking Machine" }
        if p >= 0.4 { return "Stable Learner" }
        if p >= 0.15 { return "On the way" }
        return "Starter"
    }

    public var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(PD.ColorToken.chip.opacity(0.8), lineWidth: 10)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, max(0, masteryFraction))))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(breathe ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathe)

                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(ringColor)
                    Text("\(streakDays)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(PD.ColorToken.text)
                }
            }
            .onAppear { breathe = true }

            Text(statusLabel)
                .font(PD.FontToken.caption(12, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)

            Text("\(learnedCount)")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(PD.ColorToken.text)
            Text("фраз")
                .font(PD.FontToken.caption(11, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
        }
        .padding(.vertical, 16)
    }
}

/// Bento: Speaking card with waveform placeholder
public struct BentoSpeakingCard: View {
    let score: Int
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)

    public init(score: Int, accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)) {
        self.score = score
        self.accentFill = accentFill
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundStyle(accentFill)
                Text("Speaking")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            WaveformBarsView(percent: score, accentFill: accentFill)
            Text("\(min(100, max(0, score)))%")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(PD.ColorToken.text)
        }
    }
}

private struct WaveformBarsView: View {
    let percent: Int
    var accentFill: AnyShapeStyle
    private let barCount = 12
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                let h = barHeight(index: i)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accentFill)
                    .frame(width: 4, height: max(4, h))
                    .opacity(0.5 + 0.5 * Double(percent) / 100.0)
            }
        }
        .frame(height: 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }

    private func barHeight(index: Int) -> CGFloat {
        let p = CGFloat(min(100, max(0, percent))) / 100.0
        let wave = 0.4 + 0.6 * sin(CGFloat(index) * 0.7 + phase * .pi * 2)
        return 6 + 18 * p * wave
    }
}

/// Bento: Memory card (flip → problem syllables)
public struct BentoMemoryCard: View {
    let learnedCount: Int
    let problemSyllables: [String]
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)
    @State private var isFlipped: Bool = false

    public init(learnedCount: Int, problemSyllables: [String], accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)) {
        self.learnedCount = learnedCount
        self.problemSyllables = problemSyllables
        self.accentFill = accentFill
    }

    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isFlipped.toggle() }
        }) {
            ZStack {
                frontFace
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0))
                backFace
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .buttonStyle(.plain)
    }

    private var frontFace: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 16))
                .foregroundStyle(accentFill)
            Text("Memory")
                .font(PD.FontToken.caption(12, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
            Text("\(learnedCount)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(PD.ColorToken.text)
            Text("слов")
                .font(PD.FontToken.caption(11, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backFace: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Топ путаницы")
                .font(PD.FontToken.caption(12, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
            if problemSyllables.isEmpty {
                Text("—")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            } else {
                ForEach(problemSyllables.prefix(3), id: \.self) { s in
                    Text(s)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(PD.ColorToken.text)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Bento: Consistency — 7-day heat (reuse AppHeatRow style)
public struct BentoConsistencyCard: View {
    let heatValues: [CGFloat]
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)

    public init(heatValues: [CGFloat], accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)) {
        self.heatValues = heatValues
        self.accentFill = accentFill
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 14))
                .foregroundStyle(accentFill)
            Text("Consistency")
                .font(PD.FontToken.caption(12, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
            HStack(spacing: 6) {
                ForEach(Array((heatValues.count >= 7 ? heatValues : (0..<7).map { _ in CGFloat(0) }).prefix(7).enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(v > 0.01 ? AnyShapeStyle(accentFill) : AnyShapeStyle(PD.ColorToken.chip))
                        .opacity(v > 0.01 ? (0.35 + 0.65 * Double(v)) : 1)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Thai Survival Radar — 5 axes (Market, Taxi, Immigration, Cafe, General). linesOnly: true = только линии, без заливки.
public struct ThaiSurvivalRadarView: View {
    let values: [Double]
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)
    var linesOnly: Bool = false
    private let labels = ["Рынок", "Такси", "Иммиграция", "Кафе", "Общее"]

    public init(values: [Double], accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent), linesOnly: Bool = false) {
        self.values = values
        self.accentFill = accentFill
        self.linesOnly = linesOnly
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = size / 2 * 0.72
            let labelRadius = r + 22
            let n = 5
            let vals = (values.count >= n ? values : (0..<n).map { _ in 0.0 }).prefix(n).map { min(1, max(0, $0)) }

            ZStack {
                ForEach(0..<n, id: \.self) { i in
                    let angle = angleFor(i, n: n)
                    let end = pointOnCircle(center: center, radius: r, angle: angle)
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: end)
                    }
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                if linesOnly {
                    PolygonShape(values: Array(vals), center: center, radius: r, count: n)
                        .stroke(accentFill, lineWidth: 1.5)
                } else {
                    PolygonShape(values: Array(vals), center: center, radius: r, count: n)
                        .fill(accentFill.opacity(0.25))
                        .overlay(
                            PolygonShape(values: Array(vals), center: center, radius: r, count: n)
                                .stroke(accentFill, lineWidth: 1.5)
                        )
                }
                ForEach(0..<n, id: \.self) { i in
                    let angle = angleFor(i, n: n)
                    let pt = pointOnCircle(center: center, radius: labelRadius, angle: angle)
                    Text(labels[i])
                        .font(PD.FontToken.caption(10, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .position(pt)
                }
            }
        }
        .frame(height: 200)
    }

    private func angleFor(_ i: Int, n: Int) -> Double {
        (.pi / 2) + (Double(i) * 2 * .pi / Double(n))
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y - radius * CGFloat(sin(angle)))
    }
}

private struct PolygonShape: Shape {
    let values: [Double]
    let center: CGPoint
    let radius: CGFloat
    let count: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard count > 0, values.count >= count else { return p }
        let n = count
        for i in 0..<n {
            let angle = (.pi / 2) + (Double(i) * 2 * .pi / Double(n))
            let v = min(1, max(0, values[i]))
            let r = radius * CGFloat(v)
            let pt = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y - r * CGFloat(sin(angle)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Блок A (legacy): Personal Stats — оставлен для совместимости; предпочтительно MasteryRingHaloView
public struct DashboardPersonalStatsView: View {
    let streakDays: Int
    let masteryFraction: Double
    let learnedCount: Int
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)

    public init(streakDays: Int, masteryFraction: Double, learnedCount: Int, accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)) {
        self.streakDays = streakDays
        self.masteryFraction = masteryFraction
        self.learnedCount = learnedCount
        self.accentFill = accentFill
    }

    public var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(accentFill)
                Text("\(streakDays)")
                    .font(PD.FontToken.body(20, weight: .bold))
                    .foregroundStyle(PD.ColorToken.text)
                Text("дней")
                    .font(PD.FontToken.caption(11, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            .frame(width: 64)

            ZStack {
                Circle()
                    .stroke(PD.ColorToken.chip, lineWidth: 8)
                    .frame(width: 88, height: 88)
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, max(0, masteryFraction))))
                    .stroke(accentFill, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(round(masteryFraction * 100)))%")
                    .font(PD.FontToken.caption(14, weight: .bold))
                    .foregroundStyle(PD.ColorToken.text)
            }

            VStack(spacing: 4) {
                Text("\(learnedCount)")
                    .font(PD.FontToken.body(20, weight: .bold))
                    .foregroundStyle(PD.ColorToken.text)
                Text("фраз")
                    .font(PD.FontToken.caption(11, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            .frame(width: 64)
        }
        .padding(.vertical, 8)
    }
}

/// Один скилл-бар (Recognition / Construction / Speaking)
public struct DashboardSkillBarView: View {
    let title: String
    let percent: Int
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)

    public init(title: String, percent: Int, accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)) {
        self.title = title
        self.percent = percent
        self.accentFill = accentFill
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(PD.FontToken.caption(13, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Spacer(minLength: 8)
                Text("\(min(100, max(0, percent)))%")
                    .font(PD.FontToken.caption(13, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(PD.ColorToken.chip)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(accentFill)
                        .frame(width: max(0, geo.size.width * CGFloat(min(100, max(0, percent)) / 100)))
                }
            }
            .frame(height: 8)
        }
    }
}

/// Блок C: Expat Health Check — готовность к рынку / иммиграции
public struct DashboardExpatWidgetView: View {
    let marketPercent: Int
    let immigrationPercent: Int
    var accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)

    public init(marketPercent: Int, immigrationPercent: Int, accentFill: AnyShapeStyle = AnyShapeStyle(PD.ColorToken.accent)) {
        self.marketPercent = marketPercent
        self.immigrationPercent = immigrationPercent
        self.accentFill = accentFill
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Твой уровень выживания в Таиланде")
                .font(PD.FontToken.caption(12, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
            HStack(spacing: 16) {
                labelCell(title: "поход на рынок", percent: marketPercent)
                labelCell(title: "иммиграция", percent: immigrationPercent)
            }
        }
        .padding(.vertical, 4)
    }

    private func labelCell(title: String, percent: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(PD.FontToken.caption(11, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
            Text("\(min(100, max(0, percent)))%")
                .font(PD.FontToken.body(18, weight: .bold))
                .foregroundStyle(accentFill)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - Helper: Map 0...1 to AppActivityIntensity
private extension AppActivityIntensity {
    static func from01(_ v: Double) -> AppActivityIntensity {
        let x = max(0, min(1, v))
        // keep ProfileDS strictly aligned with AppDS contract: only use cases that exist there.
        // AppDS currently exposes `.low` and `.high` (no `.none`, `.medium`, `.max`).
        if x < 0.45 { return .low }
        return .high
    }
}
