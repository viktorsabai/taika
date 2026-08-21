import SwiftUI
import UIKit

// MARK: - Namespace
public enum LS {
    public struct Item: Identifiable, Hashable {
        public let id: String
        public let index: Int
        public let title: String
        public let subtitle: String?
        public let durationMinutes: Int
        public let isPro: Bool
        public let status: Status
        public let tags: [String]
        public let progress: Double?
        public let cardCount: Int?
        public let favoriteCount: Int
        public let learnedCardCount: Int
        public let errorCardCount: Int
        public let reinforcementScore: Int?
        public init(id: String = UUID().uuidString,
                    index: Int,
                    title: String,
                    subtitle: String? = nil,
                    durationMinutes: Int,
                    isPro: Bool,
                    status: Status,
                    tags: [String] = [],
                    progress: Double? = nil,
                    cardCount: Int? = nil,
                    favoriteCount: Int = 0,
                    learnedCardCount: Int = 0,
                    errorCardCount: Int = 0,
                    reinforcementScore: Int? = nil) {
            self.id = id
            self.index = index
            self.title = title
            self.subtitle = subtitle
            self.durationMinutes = durationMinutes
            self.isPro = isPro
            self.status = status
            self.tags = tags
            self.progress = progress
            self.cardCount = cardCount
            self.favoriteCount = favoriteCount
            self.learnedCardCount = max(0, learnedCardCount)
            self.errorCardCount = max(0, errorCardCount)
            self.reinforcementScore = reinforcementScore
        }
    }

    public enum Status: String, Hashable {
        case locked, inProgress, completed
    }
}

// MARK: - Header Section (no title; isolates the header as a DS section)
public struct LSHeaderSection: View {
    private let title: String
    private let subtitle: String
    private let ctaText: String?
    private let onCTA: (() -> Void)?
    private let progressCompleted: Int?
    private let progressTotal: Int?
    private let lessonsCount: Int?
    private let chipText: String?
    private let progressSlots: [Double]?
    private let bottomReserve: CGFloat?
    private let selectedIndex: Int?
    private let onTapSlot: ((Int) -> Void)?

    /// Optional bottom gap override. If nil, uses Theme.Layout.sectionGap.
    private let bottomGap: CGFloat?

    public init(
        title: String,
        subtitle: String,
        ctaText: String? = nil,
        onCTA: (() -> Void)? = nil,
        progressCompleted: Int? = nil,
        progressTotal: Int? = nil,
        lessonsCount: Int? = nil,
        chipText: String? = nil,
        progressSlots: [Double]? = nil,
        bottomReserve: CGFloat? = nil,
        selectedIndex: Int? = nil,
        onTapSlot: ((Int) -> Void)? = nil,
        bottomGap: CGFloat? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.ctaText = ctaText
        self.onCTA = onCTA
        self.progressCompleted = progressCompleted
        self.progressTotal = progressTotal
        self.lessonsCount = lessonsCount
        self.chipText = chipText
        self.progressSlots = progressSlots
        self.bottomReserve = bottomReserve
        self.selectedIndex = selectedIndex
        self.onTapSlot = onTapSlot
        self.bottomGap = bottomGap
    }

    public var body: some View {
        let gap = bottomGap ?? Theme.Layout.sectionGap
        return LSLessonHeader(
            title: title,
            subtitle: subtitle,
            ctaText: ctaText,
            onCTA: onCTA,
            progressCompleted: progressCompleted,
            progressTotal: progressTotal,
            lessonsCount: lessonsCount,
            chipText: chipText,
            progressSlots: progressSlots,
            bottomReserve: bottomReserve,
            selectedIndex: selectedIndex,
            onTapSlot: onTapSlot
        )
        .lsSectionPadding(bottom: gap)
    }
}

// MARK: - Hometask namespace (mock)
public enum HT {
    public struct Item: Identifiable, Hashable {
        public let id: String
        public let index: Int
        public let title: String
        public let subtitle: String?
        public let durationMinutes: Int?
        public let isLocked: Bool
        public init(id: String = UUID().uuidString,
                    index: Int,
                    title: String,
                    subtitle: String? = nil,
                    durationMinutes: Int? = nil,
                    isLocked: Bool = false) {
            self.id = id
            self.index = index
            self.title = title
            self.subtitle = subtitle
            self.durationMinutes = durationMinutes
            self.isLocked = isLocked
        }
    }
}

// MARK: - Header (unified with app header)
public struct LSLessonHeader: View {
    let title: String
    let subtitle: String
    let ctaText: String?
    let onCTA: (() -> Void)?
    let progressCompleted: Int?
    let progressTotal: Int?
    let lessonsCount: Int?
    let chipText: String?
    let progressSlots: [Double]?
    let bottomReserve: CGFloat?
    public var selectedIndex: Int? = nil
    public var onTapSlot: ((Int) -> Void)? = nil
    /// Optional content rendered inside the existing course hero card below progress.
    /// Used for contextual controls such as the Lessons/Lifehacks picker.
    public var bottomAccessory: AnyView? = nil
    /// Кнопка «назад в курсы» на карточке (вместо дырки в углу).
    public var onBack: (() -> Void)? = nil
    /// Optional educational summary rendered inside the same course hero card.
    public var completionSummary: AnyView? = nil
    /// Completed courses use jungle-green progress slots.
    public var isCompletedCourse: Bool = false

    public init(
        title: String,
        subtitle: String,
        ctaText: String? = nil,
        onCTA: (() -> Void)? = nil,
        progressCompleted: Int? = nil,
        progressTotal: Int? = nil,
        lessonsCount: Int? = nil,
        chipText: String? = nil,
        progressSlots: [Double]? = nil,
        bottomReserve: CGFloat? = nil,
        selectedIndex: Int? = nil,
        onTapSlot: ((Int) -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        completionSummary: AnyView? = nil,
        isCompletedCourse: Bool = false,
        bottomAccessory: AnyView? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.ctaText = ctaText
        self.onCTA = onCTA
        self.progressCompleted = progressCompleted
        self.progressTotal = progressTotal
        self.lessonsCount = lessonsCount
        self.chipText = chipText
        self.progressSlots = progressSlots
        self.bottomReserve = bottomReserve
        self.selectedIndex = selectedIndex
        self.onTapSlot = onTapSlot
        self.onBack = onBack
        self.completionSummary = completionSummary
        self.isCompletedCourse = isCompletedCourse
        self.bottomAccessory = bottomAccessory
    }

    // Use lessonsCount if provided, else fallback to progressTotal for compatibility
    private var totalLessons: Int? { lessonsCount ?? progressTotal }

    // [[...]] segments are tinted with accent color
    private func accentText(_ raw: String) -> Text {
        var result = Text("")
        var buffer = ""
        var isAccent = false
        for ch in raw {
            if ch == "[" {
                if buffer.hasSuffix("[") {
                    // start accent
                    buffer.removeLast()
                    if !buffer.isEmpty { result = result + Text(buffer) }
                    buffer = ""
                    isAccent = true
                } else {
                    buffer.append(ch)
                }
            } else if ch == "]" {
                if buffer.hasSuffix("]") {
                    // end accent
                    buffer.removeLast()
                    if !buffer.isEmpty {
                        result = result + Text(buffer).foregroundStyle(ThemeManager.shared.currentAccentFill)
                    }
                    buffer = ""
                    isAccent = false
                } else {
                    buffer.append(ch)
                }
            } else {
                buffer.append(ch)
            }
        }
        if !buffer.isEmpty {
            if isAccent {
                result = result + Text(buffer).foregroundStyle(ThemeManager.shared.currentAccentFill)
            } else {
                result = result + Text(buffer)
            }
        }
        return result
    }



    // Progress strip for lessons: completed, active, upcoming
    private struct LSProgressStrip: View {
        let done: Int
        let total: Int
        /// Fractional progress **inside текущего урока** (0...1).
        /// По умолчанию 0, чтобы старые вызовы не ломались.
        let currentFraction: Double
        let progressSlots: [Double]?

        init(done: Int, total: Int, currentFraction: Double = 0, progressSlots: [Double]? = nil) {
            self.done = done
            self.total = total
            self.currentFraction = currentFraction
            self.progressSlots = progressSlots
        }

        var body: some View {
            // The strip is driven by explicit per-slot fractions when available.

            // How many whole slots are filled

            GeometryReader { geo in
                let blockW = geo.size.width
                let blockH = geo.size.height
                let outerH: CGFloat = 6
                let outerW: CGFloat = 10
                let innerW = max(0, blockW - outerW * 2)
                let innerH = max(0, blockH - outerH * 2)
                let spacing: CGFloat = 10
                let targetHFactor: CGFloat = 0.90
                let minSide: CGFloat = 32
                let maxSide: CGFloat = 44
                let baseSide = max(minSide, min(maxSide, floor(innerH * targetHFactor)))
                // Per-slot fractions provided from manager (0...1 per slot)
                let fractions: [Double] = self.progressSlots ?? []
                let visibleSlots = fractions.isEmpty ? self.total : fractions.count
                // Active index is a purely visual highlight, not tied to fill
                let activeIndex = -1 // no highlight in fallback strip
                let sideByWidth = visibleSlots > 0 ? (innerW - spacing * CGFloat(visibleSlots - 1)) / CGFloat(visibleSlots) : 0
                let side = floor(min(baseSide, sideByWidth))
                let contentWidth = side * CGFloat(visibleSlots) + spacing * CGFloat(visibleSlots - 1)
                let sideInset = max(0, floor((innerW - contentWidth) / 2))

                HStack {
                    Spacer(minLength: 0)
                    HStack(spacing: spacing) {
                        ForEach(0..<visibleSlots, id: \.self) { i in
                            let fillAmount = fractions.indices.contains(i) ? min(1, max(0, fractions[i])) : 0
                            let isCompleted = fillAmount >= 0.999
                            let isActive = (i == activeIndex)
                            let base = RoundedRectangle(cornerRadius: 12, style: .continuous)

                            ZStack(alignment: .bottom) {
                                base.fill(Color.white.opacity(0.10))
                                if isCompleted {
                                    base.fill(ThemeManager.shared.currentAccentFill)
                                } else if fillAmount > 0 {
                                    GeometryReader { g in
                                        base
                                            .fill(ThemeManager.shared.currentAccentFill)
                                            .frame(height: max(1, g.size.height * CGFloat(fillAmount)))
                                            .frame(maxWidth: .infinity, alignment: .bottom)
                                    }
                                    .clipShape(base)
                                }
                            }
                            .shadow(color: isActive ? Color.black.opacity(0.20) : .clear, radius: isActive ? 3 : 0, x: 0, y: isActive ? 1 : 0)
                            .overlay(
                                Group {
                                    if isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.weight(.black))
                                            .foregroundStyle(Color.black.opacity(0.9))
                                            .shadow(color: Color.white.opacity(0.25), radius: 1, x: 0, y: 0)
                                    } else {
                                        Text("\(i + 1)")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(
                                                isActive ? Color.white.opacity(0.98) :
                                                Color.white.opacity(0.45)
                                            )
                                            .minimumScaleFactor(0.8)
                                    }
                                }
                            )
                            .frame(width: side, height: max(44, side * 1.28))
                        }
                    }
                    .padding(.horizontal, outerW + sideInset)
                    .padding(.vertical, outerH)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 56)
        }
    }

    // Fixed card min height for consistent layout (balanced paddings/air)
    private let minHeight: CGFloat = 156

    // Background: карточка; при onBack != nil — в углу кнопка «назад», иначе — вырез как раньше.
    @ViewBuilder
    private func cardBackgroundWithNotch() -> some View {
        ZStack(alignment: .topLeading) {
            let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
            if isCompletedCourse {
                round
                    .fill(AnyShapeStyle(TaikaMasteryTokens.greenGradient.opacity(0.24)))
                    .overlay(round.stroke(TaikaMasteryTokens.greenGlow.opacity(0.42), lineWidth: 1))
            } else {
                Theme.Surfaces.card(round)
            }

            if onBack != nil {
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onBack?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("в курсы")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .frame(minWidth: 112, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .padding(.top, 8)
            } else {
                Circle()
                    .frame(width: 18, height: 18)
                    .offset(x: 12, y: 12)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    private var progressRow: some View {
        if let slots = progressSlots, !slots.isEmpty {
            LSProgressSlotsStrip(
                slots: slots,
                selectedIndex: selectedIndex,
                onTapSlot: onTapSlot,
                isCompletedCourse: isCompletedCourse
            )
            .frame(maxWidth: .infinity, alignment: .center)
        } else if let done = progressCompleted, let ttl = totalLessons, ttl > 0 {
            LSProgressStrip(
                done: done,
                total: ttl,
                progressSlots: progressSlots
            )
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            EmptyView()
        }
    }

    public var body: some View {
        // unified vertical metrics
        let sideInsetH: CGFloat = Theme.Layout.sectionInner
        let edgeInsetTop: CGFloat = Theme.Layout.pageTopAfterHeader
        // allow caller to reserve extra bottom space when needed
        let edgeInsetBottom: CGFloat = (bottomReserve ?? 18)
        let titleSubtitleSpacing: CGFloat = 10
        let subtitleProgressSpacing: CGFloat = 14

        // Inner content (title + subtitle + progress)
        let content = VStack(alignment: .center, spacing: 0) {
            // Title & subtitle
            VStack(alignment: .center, spacing: titleSubtitleSpacing) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)

                accentText(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineSpacing(2)
                    .shadow(color: Color.black.opacity(0.6), radius: 1, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // space between subtitle and progress row
            Spacer(minLength: subtitleProgressSpacing).frame(height: subtitleProgressSpacing)

            // Progress row
            progressRow
                .padding(.top, 8)

            if let completionSummary {
                completionSummary
                    .padding(.top, 12)
            }

            if let bottomAccessory {
                bottomAccessory
                    .padding(.top, 14)
            }
        }

        // Card with perfectly balanced vertical padding (same top & bottom)
        return ZStack {
            cardBackgroundWithNotch()
            VStack(spacing: 0) {
                Spacer(minLength: edgeInsetTop)
                content
                    .padding(.horizontal, CGFloat(sideInsetH))
                Spacer(minLength: edgeInsetBottom)
            }
        }
        .frame(minHeight: minHeight, alignment: .center)
        .contentShape(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Progress strip adapter (done/total -> slot fractions)
public struct LSProgressStrip: View {
    let done: Int
    let total: Int
    // if caller already has detailed slot fractions – forward them; otherwise we compute from done/total
    var progressSlots: [Double]?
    var isCompletedCourse: Bool = false

    public init(done: Int, total: Int, progressSlots: [Double]? = nil, isCompletedCourse: Bool = false) {
        self.done = max(0, done)
        self.total = max(1, total)
        self.progressSlots = progressSlots
        self.isCompletedCourse = isCompletedCourse
    }

    private func makeSlots() -> [Double] {
        // If explicit slots are provided (e.g., from ProgressManager) – use them as-is
        if let slots = progressSlots, !slots.isEmpty { return slots.map { min(1.0, max(0.0, $0)) } }

        // Otherwise convert done/total into N slot fractions, where N = total (clamped 1...20)
        let n = max(1, min(20, total))
        let progress = min(1.0, max(0.0, Double(done) / Double(total)))
        let exact = progress * Double(n)
        let full = Int(floor(exact))
        let partial = max(0.0, min(1.0, exact - Double(full)))

        var result = Array(repeating: 0.0, count: n)
        for i in 0..<min(full, n) { result[i] = 1.0 }
        if full < n { result[full] = partial }
        return result
    }

    public var body: some View {
        LSProgressSlotsStrip(
            slots: makeSlots(),
            selectedIndex: nil,
            onTapSlot: nil,
            isCompletedCourse: isCompletedCourse
        )
    }
}

// MARK: - Progress strip (per-slot fractions, 0…1 with partial fill)
public struct LSProgressSlotsStrip: View {
    let slots: [Double]
    let selectedIndex: Int?
    let onTapSlot: ((Int) -> Void)?
    let isCompletedCourse: Bool

    public init(slots: [Double], selectedIndex: Int? = nil, onTapSlot: ((Int) -> Void)? = nil, isCompletedCourse: Bool = false) {
        self.slots = slots
        self.selectedIndex = selectedIndex
        self.onTapSlot = onTapSlot
        self.isCompletedCourse = isCompletedCourse
    }

    private var accentFill: AnyShapeStyle {
        if isCompletedCourse {
            return AnyShapeStyle(TaikaMasteryTokens.greenGradient)
        }
        return AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

// New MiniSlot implementation for per-slot rendering
    private struct MiniSlot: View {
        let fill: Double
        let index: Int
        let isActive: Bool
        let accentFill: AnyShapeStyle
        let onTap: (() -> Void)?

        var body: some View {
            let base = RoundedRectangle(cornerRadius: 12, style: .continuous)
            GeometryReader { geo in
                ZStack {
                    // Unified, lighter card background layer
                    base
                        .fill(Color.black.opacity(0.15))
                    // Apply glass tint only when the slot is fully completed
                    if fill >= 0.999 {
                        CD.GradientToken.pro
                            .blur(radius: 2.5)
                            .opacity(0.55)
                            .mask(base)
                    }
                    // Subtle white highlight stroke for shimmer
                    base
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    // Subtle white gradient overlay for gentle light
                    base
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    // Bottom-up fill rectangle clipped to the same rounded shape
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(accentFill)
                            .frame(height: geo.size.height * CGFloat(max(0.0, min(1.0, fill))))
                            .clipped()
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .mask(base)

                    // Centered label (always perfectly centered inside the slot)
                    ZStack {
                        // When the slot is fully filled, show a dark checkmark
                        if fill >= 0.999 {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.black.opacity(0.9))
                        } else {
                            // If the bottom-up fill covers the vertical center of the slot,
                            // use dark text for contrast; otherwise keep light text.
                            let centerCovered = fill >= 0.55
                            Text("\(index + 1)")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(
                                    centerCovered
                                    ? Color.black.opacity(0.9)
                                    : (isActive ? Color.white : Color.white.opacity(0.45))
                                )
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: fill)
            .contentShape(base)
            .onTapGesture { onTap?() }
            .allowsHitTesting(true)
        }
    }

    public var body: some View {
        GeometryReader { geo in
            let total = max(1, slots.count)
            let spacing: CGFloat = 10
            let outerH: CGFloat = 6
            let outerW: CGFloat = 10
            let innerW = max(0, geo.size.width - outerW * 2)
            let innerH = max(0, geo.size.height - outerH * 2)
            let targetHFactor: CGFloat = 0.90
            let minSide: CGFloat = 32
            let maxSide: CGFloat = 44
            let baseSide = max(minSide, min(maxSide, floor(innerH * targetHFactor)))
            let sideByWidth = (innerW - spacing * CGFloat(total - 1)) / CGFloat(total)
            let rawSide = floor(min(baseSide, sideByWidth))
            let side = (rawSide.isFinite && rawSide > 0) ? min(maxSide, max(minSide, rawSide)) : minSide
            let contentWidth = side * CGFloat(total) + spacing * CGFloat(total - 1)
            let sideInset = max(0, floor((innerW - contentWidth) / 2))

            HStack { Spacer(minLength: 0)
                HStack(spacing: spacing) {
                    ForEach(Array(slots.enumerated()), id: \.offset) { idx, raw in
                        MiniSlot(
                            fill: min(1.0, max(0.0, raw)),
                            index: idx,
                            isActive: (selectedIndex == idx),
                            accentFill: accentFill,
                            onTap: { onTapSlot?(idx) }
                        )
                        .frame(width: side, height: 44)
                    }
                }
                .padding(.horizontal, outerW + sideInset)
                .padding(.vertical, outerH)
                Spacer(minLength: 0)
            }
        }
        .frame(height: 56)
    }
}

// MARK: - Unified external spacing for DS sections
public extension View {
    /// Standard container spacing for DS sections: horizontal screen inset + bottom rhythm.
    /// Use this in View-level integration so every section is isolated and doesn't overlap neighbors.
    func lsSectionPadding() -> some View {
        self.lsSectionPadding(bottom: Theme.Layout.sectionGap)
    }

    /// Same as `lsSectionPadding()`, but allows overriding the bottom gap.
    func lsSectionPadding(bottom: CGFloat) -> some View {
        self
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.bottom, bottom)
    }
}

// MARK: - Lessons Count Mono Chip (top-right tag)
public struct LSLessonsMonoChip: View {
    let count: Int
    public init(_ count: Int) { self.count = count }
    public var body: some View {
        return Text("\(count) карточек")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(ThemeManager.shared.currentAccentFill)
            )
            .overlay(
                Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .foregroundStyle(Color.black.opacity(0.85))
    }
}

public struct LSMonoChip: View {
    let text: String
    public init(text: String) { self.text = text }
    public var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(PD.ColorToken.accent.opacity(0.16))
        )
        .overlay(
            Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
        // Remove .foregroundStyle(accent) here so gradient applies to text only
    }
}

// MARK: - Marquee Section (header + mascot outside + fixed-height typing bubble)
public struct LSMarqueeSection: View {
    let title: String
    let messages: [String]
    let typingSpeed: Double
    let maxLines: Int
    let bubbleHeight: CGFloat

    @State private var currentIndex: Int = 0
    @State private var shownText: String = ""
    @State private var dotsPhase: Int = 0
    private enum Mode { case typing, thinking }
    @State private var mode: Mode = .typing

    private var longestMessage: String { messages.max(by: { $0.count < $1.count }) ?? "" }
    private var textHeight: CGFloat {
        // match .subheadline line height (~20pt) to align with card subtitles
        return CGFloat(max(1, maxLines)) * 20.0
    }

    public init(title: String = "taika fm",
                messages: [String],
                typingSpeed: Double = 0.045,
                maxLines: Int = 2,
                bubbleHeight: CGFloat = 64) {
        self.title = title
        self.messages = messages
        self.typingSpeed = typingSpeed
        self.maxLines = maxLines
        self.bubbleHeight = bubbleHeight
    }

    public var body: some View {
        let configMessages = TaikaFMData.shared.messages(for: .lessons)
        let configReactions = TaikaFMData.shared.reactionGroups(for: .lessons)

        let effectiveMessages = messages.isEmpty ? configMessages : messages
        let effectiveReactions = configReactions

        return VStack(alignment: .leading, spacing: 8) {
            LSSectionTitle(title)

            TaikaFMBubbleTyping(
                messages: effectiveMessages,
                reactions: effectiveReactions,
                repeats: false
            )
        }
    }
}

// MARK: - Toolbar Back Button
public struct LSBackToCoursesButton: View {
    public var title: String
    public var onTap: () -> Void

    public init(title: String = "Назад к курсам", onTap: @escaping () -> Void) {
        self.title = title
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(PD.FontToken.body(16, weight: .semibold))
            }
            .foregroundStyle(ThemeManager.shared.currentAccentFill)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 148, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityIdentifier("backToCoursesButton")
    }
}
// MARK: - Toolbar helper (reuse the same back button in toolbars)
public struct LSBackToolbarModifier: ViewModifier {
    public let title: String
    public let onTap: () -> Void

    public func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(false)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { // iOS 17+
                    LSBackToCoursesButton(title: title, onTap: onTap)
                }
            }
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

public extension View {
    /// Attach a standard "Назад к курсам" button in the leading toolbar, same look as in Step.
    func lsBackToCoursesToolbar(title: String = "Назад к курсам", onTap: @escaping () -> Void) -> some View {
        self.modifier(LSBackToolbarModifier(title: title, onTap: onTap))
    }
}
// MARK: - CTA Badge (icon-only circular CTA, gradient, dark icon, accessible)
public struct LSLessonCTABadge: View {
    let status: LS.Status
    public init(status: LS.Status) { self.status = status }
    private var titleIcon: (String, String) {
        switch status {
        case .locked: return ("начать", "play.fill")
        case .inProgress: return ("сбросить", "backward.end.fill")
        case .completed: return ("повторить", "arrow.clockwise")
        }
    }
    public var body: some View {
        let (title, icon) = titleIcon
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.9))
            .accessibilityLabel(Text(title.capitalized))
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - PRO Badge (mono, compact)
public struct LSLessonProBadge: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
            Text("PRO")
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(
                ThemeManager.shared.currentAccentFill
            ).opacity(0.85)
        )
        .overlay(Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
        .foregroundColor(Color.black.opacity(0.85))
    }
}

// MARK: - Start Badge (CTA for free)
public struct LSLessonStartBadge: View {
    let title: String
    public init(_ title: String) { self.title = title }
    public var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .kerning(0.3)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.16)))
            .overlay(Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
            .foregroundStyle(Color.white.opacity(0.95))
    }
}

// MARK: - Cards Count Chip (bottom-right accent)
public struct LSLessonCountChip: View {
    let count: Int
    public init(_ count: Int) { self.count = count }
    private var title: String { "\(count) карточек" }
    public var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .kerning(0.3)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(ThemeManager.shared.currentAccentFill).opacity(0.65)
            )
            .overlay(
                Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .foregroundStyle(Color.white)
    }
}

// MARK: - Skill Tag (bottom-right)
public struct LSLessonSkillTag: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .overlay(Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
            .foregroundStyle(Color.white.opacity(0.95))
    }
}

// Simple Russian pluralization for lessons
fileprivate func lsRuPlural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
    let n10 = n % 10
    let n100 = n % 100
    if n10 == 1 && n100 != 11 { return one }
    if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
    return many
}

// MARK: - Inline Meta (icon + text, no pill)
public struct LSInlineMeta: View {
    let icon: String
    let text: String
    public init(icon: String, text: String) { self.icon = icon; self.text = text }
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(Color.white.opacity(0.90))
    }
}

// MARK: - Info Pills (duration / pro)
public struct LSLessonInfoPills: View {
    let minutes: Int
    let cardCount: Int?
    let compact: Bool
    public init(minutes: Int, cardCount: Int?, compact: Bool = false) {
        self.minutes = minutes
        self.cardCount = cardCount
        self.compact = compact
    }
    public var body: some View {
        HStack(spacing: 10) {
            LSInlineMeta(icon: "clock", text: "≈ \(minutes) мин")
            Text("•").foregroundStyle(Color.white.opacity(0.6))
            if let c = cardCount, c > 0 {
                LSInlineMeta(icon: "book.closed", text: "\(c) \(lsRuPlural(c, "карточка", "карточки", "карточек"))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Info Pills (vertical, for right rail)
public struct LSLessonInfoPillsVertical: View {
    let minutes: Int
    let cardCount: Int?
    public init(minutes: Int, cardCount: Int?) {
        self.minutes = minutes
        self.cardCount = cardCount
    }
    public var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            LSInlineMeta(icon: "clock", text: "≈ \(minutes) мин")
            if let c = cardCount, c > 0 {
                LSInlineMeta(icon: "book.closed", text: "\(c) \(lsRuPlural(c, "урок", "урока", "уроков"))")
            }
        }
    }
}

// MARK: - Assistant Card (Taika chat teaser)
public struct LSLessonAssistantCard: View {
    let avatar: Image
    let messages: [String]
    let typingSpeed: Double
    let maxLines: Int
    let textHeight: CGFloat
    let onTap: () -> Void

    @State private var currentIndex: Int = 0
    @State private var shownText: String = ""
    @State private var isTyping: Bool = true
    @State private var dotsPhase: Int = 0
    private enum Mode { case typing, thinking }
    @State private var mode: Mode = .typing
    private var longestMessage: String { messages.max(by: { $0.count < $1.count }) ?? "" }

    public init(avatar: Image = Image("mascot.profile"),
                messages: [String],
                typingSpeed: Double = 0.045,
                maxLines: Int = 2,
                onTap: @escaping () -> Void) {
        self.avatar = avatar
        self.messages = messages
        self.typingSpeed = typingSpeed
        self.maxLines = maxLines
        // Approximate fixed height for body text lines (iOS body ≈ 17pt line-height). Add headroom.
        self.textHeight = CGFloat(max(1, maxLines)) * 20.0
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // avatar
                avatar
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
                    .taikaMascotChrome()

                VStack(alignment: .leading, spacing: 6) {
                    // reserve height by laying out the longest message invisibly
                    ZStack(alignment: .topLeading) {
                        Text(longestMessage)
                            .font(.subheadline)
                            .lineLimit(maxLines)
                            .foregroundStyle(.clear)
                            .frame(height: textHeight, alignment: .topLeading)

                        // message or thinking dots (messenger-style)
                        Group {
                            if mode == .typing {
                                Text(shownText)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(maxLines)
                                    .animation(.none, value: shownText)
                                    .frame(height: textHeight, alignment: .topLeading)
                            } else {
                                // thinking between messages — align to avatar center line
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack(spacing: 4) {
                                        ForEach(0..<3, id: \.self) { i in
                                            Circle()
                                                .fill(CD.ColorToken.textSecondary.opacity(dotsPhase == i ? 0.9 : 0.35))
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                    .frame(height: 12)
                                    .padding(.top, 12) // 36pt avatar center minus 12pt dots height ≈ 12pt
                                    Spacer(minLength: 0)
                                }
                                .frame(height: textHeight, alignment: .topLeading)
                                .accessibilityLabel("taika печатает")
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                    .fill(PD.ColorToken.card)
            )
            // No border – matches unified APP DS visuals
        }
        .buttonStyle(.plain)
        .onAppear {
            startDotsTimer()
            startTyping()
        }
    }

    private func startDotsTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            dotsPhase = (dotsPhase + 1) % 3
        }
    }

    private func startTyping() {
        guard messages.indices.contains(currentIndex) else { return }
        shownText = ""
        isTyping = true
        mode = .typing
        let text = messages[currentIndex]
        var i = 0
        let timer = Timer.scheduledTimer(withTimeInterval: typingSpeed, repeats: true) { t in
            if i < text.count {
                let idx = text.index(text.startIndex, offsetBy: i)
                shownText.append(text[idx])
                i += 1
            } else {
                t.invalidate()
                // reading pause based on length (clamped)
                let pause = min(3.0, max(1.2, 0.03 * Double(text.count)))
                DispatchQueue.main.asyncAfter(deadline: .now() + pause) {
                    // show thinking dots between messages
                    isTyping = false
                    mode = .thinking
                    dotsPhase = 0
                    let thinking = 1.1
                    DispatchQueue.main.asyncAfter(deadline: .now() + thinking) {
                        currentIndex = (currentIndex + 1) % max(1, messages.count)
                        startTyping()
                    }
                }
            }
        }
        RunLoop.current.add(timer, forMode: .common)
    }
}

// MARK: - Primary CTA Pill (text + icon)
public struct LSLessonCTAPill: View {
    let status: LS.Status
    let fullWidth: Bool
    public init(status: LS.Status, fullWidth: Bool = false) { self.status = status; self.fullWidth = fullWidth }
    private var config: (title: String, icon: String) {
        switch status {
        case .locked:    return ("начать", "play.fill")
        case .inProgress:return ("продолжить", "pause.fill")
        case .completed: return ("повторить", "arrow.clockwise")
        }
    }
    public var body: some View {
        let c = config
        HStack(spacing: 6) {
            Image(systemName: c.icon)
                .font(.caption2.weight(.semibold))
            Text(c.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.14))
        )
        // No chip stroke – matches unified APP DS visuals
        .foregroundStyle(Color.white.opacity(0.95))
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 36)
        .contentShape(Rectangle())
    }
}

// MARK: - Lesson Row
public struct LSLessonRow: View {
    let item: LS.Item
    let onTap: (LS.Item) -> Void

    public init(item: LS.Item, onTap: @escaping (LS.Item) -> Void) {
        self.item = item
        self.onTap = onTap
    }

    public var body: some View {
        // Map to CardDS props
        let statusKind: AppStatusKind = {
            switch item.status {
            case .locked:      return .new
            case .inProgress:  return .inProgress
            case .completed:   return .completed
            }
        }()
        let primaryCTA: AppCTAType = {
            switch item.status {
            case .locked:      return .start
            case .inProgress:  return .resume
            case .completed:   return .reinforce
            }
        }()
        let durationText = "≈ \(item.durationMinutes) мин"
        let starsFraction: Double? = {
            switch item.status {
            case .completed:
                return 1.0
            case .inProgress:
                return item.progress ?? 0.0
            case .locked:
                return 0.0
            }
        }()

        return CourseLessonCard(
            title: item.title,
            subtitle: item.subtitle,
            lessonsCount: item.cardCount,
            durationText: durationText,
            statusKind: statusKind,
            isPro: item.isPro,
            tags: [],
            sectionChrome: .seps,
            primaryCTA: primaryCTA,
            scale: .s,
            showFavorite: true,
            showConsole: true,
            onPrimaryTap: {
                LSLessonActivity.mark(item.id)
                onTap(item)
            },
            completionFraction: (item.status == .completed ? 1.0 : nil),
            statusStarsFraction: starsFraction,
            backFaceKind: item.status == .completed ? .lessonCompletion : .lessonReminders(lines: []),
            favoriteCount: item.favoriteCount
        )
    }
}

// MARK: - Lesson List (Section)
public struct LSLessonList: View {
    let title: String
    let items: [LS.Item]
    let onTap: (LS.Item) -> Void

    public init(_ title: String, items: [LS.Item], onTap: @escaping (LS.Item) -> Void) {
        self.title = title
        self.items = items
        self.onTap = onTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .taikaSectionTitleStyle()

            VStack(spacing: 14) {
                ForEach(items) { it in
                    LSLessonRow(item: it, onTap: onTap)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Card Role (learnable vs supporting)

public enum LSLessonActivity {
    private static let key = "LSLessonActivity.lastActiveLessonId"
    public static func mark(_ id: String) { UserDefaults.standard.set(id, forKey: key) }
    public static func last() -> String? { UserDefaults.standard.string(forKey: key) }
}
public enum LSCardRole {
    case learnable
    case support // e.g., лайфхаки/сцены — не влияют на прогресс, только избранное
}

// MARK: - Lesson Card (vertical for carousel)
public struct LSLessonCardV: View {
    let item: LS.Item
    let role: LSCardRole
    let onTap: (LS.Item) -> Void
    let onFavorite: (() -> Void)?
    let favoriteCount: Int
    let onConsole: (() -> Void)?
    let onSpeaker: (() -> Void)?
    let onNext: (() -> Void)?
    let isTrainingSelected: Bool
    let onTrainingToggle: (() -> Void)?
    @AppStorage("LSLessonActivity.lastActiveLessonId") private var lastActiveLessonId: String = ""

    public init(item: LS.Item,
                role: LSCardRole = .learnable,
                onTap: @escaping (LS.Item) -> Void,
                onFavorite: (() -> Void)? = nil,
                favoriteCount: Int = 0,
                onConsole: (() -> Void)? = nil,
                onSpeaker: (() -> Void)? = nil,
                onNext: (() -> Void)? = nil,
                isTrainingSelected: Bool = false,
                onTrainingToggle: (() -> Void)? = nil) {
        self.item = item
        self.role = role
        self.onTap = onTap
        self.onFavorite = onFavorite
        self.favoriteCount = favoriteCount
        self.onConsole = onConsole
        self.onSpeaker = onSpeaker
        self.onNext = onNext
        self.isTrainingSelected = isTrainingSelected
        self.onTrainingToggle = onTrainingToggle
    }

    // MARK: - Extracted subviews to help the type-checker
    // Precomputed gradient for heart/badge
    private var heartGrad: LinearGradient {
        LinearGradient(colors: [
            Color(red:0.98, green:0.52, blue:0.80),
            Color(red:0.91, green:0.62, blue:0.98)
        ], startPoint: .leading, endPoint: .trailing)
    }

    /// Real average of stored speaker confidence for this lesson. Nil means no assessment yet.
    private var lessonPronunciationPercent: Int? {
        let scores = SpeakerAttemptsStore.loadAll().values
            .filter { $0.lessonId == item.id && $0.heardConfidence > 0 }
            .map(\.heardConfidence)
        guard !scores.isEmpty else { return nil }
        let average = Double(scores.reduce(0, +)) / Double(scores.count)
        return max(0, min(100, Int(average.rounded())))
    }


    @ViewBuilder
    private var heartBadge: some View {
        if favoriteCount > 0 {
            Text("\(favoriteCount)")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.black.opacity(0.9))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(heartGrad.opacity(0.95))
                )
                .overlay(
                    Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
                .offset(x: 4, y: -4) // keep badge inside the button bounds
                .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                .transition(.scale.combined(with: .opacity))
        }
    }


    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            AppStatusChip(kind: {
                switch item.status {
                case .locked:      return .new
                case .inProgress:  return .inProgress
                case .completed:   return .completed
                }
            }())
            Spacer(minLength: 8)
            if item.isPro { LSLessonProBadge() }
        }
        .padding(.top, 6)
    }

    private var centerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.system(size: 19, weight: .semibold))
                .kerning(0.15)
                .foregroundStyle(Color.white.opacity(0.90))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let subtitle = item.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1.2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            LSLessonInfoPills(minutes: item.durationMinutes, cardCount: item.cardCount, compact: false)
                .padding(.top, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bottomRail: some View {
        HStack(spacing: 12) {
            if role == .learnable {
                let primaryKind: AppCTAType = {
                    switch item.status {
                    case .locked:      return .start
                    case .inProgress:  return .resume
                    case .completed:   return .resume
                    }
                }()
                AppCTAButtons(
                    primary: primaryKind,
                    onPrimary: {
                        LSLessonActivity.mark(item.id)
                        onTap(item)
                    },
                    scale: .xs,
                    unifiedWidth: true
                )
            }

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                // unified like button from AppDS
                Button(action: { onFavorite?() }) {
                    ZStack(alignment: .topTrailing) {
                        AppCardIconButton(kind: .favorite)
                        heartBadge
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Добавить в избранное")
                .accessibilityValue("избранное: \(favoriteCount)")
                .animation(.spring(response: 0.28, dampingFraction: 0.8), value: favoriteCount)

                if role == .learnable {
                    Button(action: { onConsole?() }) {
                        AppCardIconButton(kind: .console)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 36, alignment: .center)
            .contentShape(Rectangle())
            .padding(.trailing, 2)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 10)
    }

    public var body: some View {
        // Map LS.Status → AppStatusKind used by CardDS
        let statusKind: AppStatusKind = {
            switch item.status {
            case .locked:      return .new
            case .inProgress:  return .inProgress
            case .completed:   return .completed
            }
        }()

        // Map LS.Status → primary CTA
        let primaryCTA: AppCTAType = {
            switch item.status {
            case .locked:      return .start
            case .inProgress:  return .resume
            case .completed:   return .reinforce
            }
        }()

        // Build duration text (same format, reused by CardDS)
        let durationText = "≈ \(item.durationMinutes) мин"

        return CourseLessonCard(
            title: item.title,
            subtitle: item.subtitle,
            lessonsCount: item.cardCount,
            durationText: durationText,
            statusKind: statusKind,
            isPro: item.isPro,
            tags: [],
            sectionChrome: .none,
            accentTreatment: item.status == .completed
                ? .taikaValues(
                    fill: AnyShapeStyle(TaikaMasteryTokens.greenGradient.opacity(0.34)),
                    glow: TaikaMasteryTokens.greenGlow.opacity(0.72)
                )
                : .none,
            primaryCTA: primaryCTA,
            scale: .s,
            showFavorite: true,
            showConsole: onConsole != nil,
            onPrimaryTap: {
                LSLessonActivity.mark(item.id)
                onTap(item)
            },
            isFavoriteActive: favoriteCount > 0,
            isConsoleEnabled: item.status == .completed,
            completionFraction: item.status == .completed ? 1.0 : item.progress,
            pronunciationPercent: lessonPronunciationPercent,
            flipEnabled: item.status == .completed,
            backFaceKind: item.status == .completed ? .lessonCompletion : .courseGradeSheet,
            backPrimaryActionTitle: nil,
            onBackPrimaryAction: nil,
            backSecondaryActionTitle: nil,
            onBackSecondaryAction: nil,
            favoriteCount: favoriteCount,
            onFavoriteTap: onFavorite,
            onConsoleTap: { onConsole?() },
            onSpeakerTap: onSpeaker,
            showsInlineProgress: true
        )
        .overlay(alignment: .topTrailing) {
            if isTrainingSelected {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("ВЫБРАН")
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AnyShapeStyle(TaikaMasteryTokens.greenGradient))
                .padding(.top, 14)
                .padding(.trailing, 16)
                .allowsHitTesting(false)
            }
        }
    }
}

// Reusable Console embed (from CardDS) to drop into any section

public struct LSLessonReels: View {
    let title: String
    let items: [LS.Item]
    let collapsible: Bool
    let startExpanded: Bool
    let autoplay: Bool
    let interval: Double
    public let selectedIndex: Int?
    let onTap: (LS.Item) -> Void
    let onTapAccessory: ((LS.Item) -> Void)?
    let onFavorite: ((LS.Item) -> Void)?
    let onSpeaker: ((LS.Item) -> Void)?
    let onNext: ((LS.Item) -> Void)?
    let selectedLessonIds: Set<String>

    @State private var currentIndex: Int = 0
    @State private var isCollapsed: Bool

    public init(_ title: String,
                items: [LS.Item],
                collapsible: Bool = true,
                startExpanded: Bool = true,
                autoplay: Bool = false,
                interval: Double = 4.0,
                onTap: @escaping (LS.Item) -> Void,
                onTapAccessory: ((LS.Item) -> Void)? = nil,
                onFavorite: ((LS.Item) -> Void)? = nil,
                onSpeaker: ((LS.Item) -> Void)? = nil,
                onNext: ((LS.Item) -> Void)? = nil,
                selectedIndex: Int? = nil,
                selectedLessonIds: Set<String> = []) {
        self.title = title
        self.items = items
        self.collapsible = collapsible
        self.startExpanded = startExpanded
        self._isCollapsed = State(initialValue: !startExpanded)
        self.autoplay = autoplay
        self.interval = interval
        self.onTap = onTap
        self.onTapAccessory = onTapAccessory
        self.onFavorite = onFavorite
        self.onSpeaker = onSpeaker
        self.onNext = onNext
        self.selectedIndex = selectedIndex
        self.selectedLessonIds = selectedLessonIds
    }

    public var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        LSSectionTitle(title)
                        Spacer(minLength: 0)
                        if collapsible {
                            Button(action: { withAnimation(.easeInOut(duration: 0.22)) { isCollapsed.toggle() } }) {
                                HStack(spacing: 6) {
                                    Text("").textCase(.lowercase)
                                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                }
                                .font(.caption.weight(.semibold))
                                .kerning(0.4)
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Group {
                        if isCollapsed {
                            EmptyView().frame(height: 0)
                        } else {
                            CDLessonCarousel(
                                data: items,
                                cardWidth: CDLessonCarouselCanonical.cardWidth,
                                cardHeight: CDLessonCarouselCanonical.courseLessonCardHeight,
                                spacing: CDLessonCarouselCanonical.spacing,
                                initialIndex: min(max(0, selectedIndex ?? currentIndex), max(0, items.count - 1)),
                                onTapScrollToCenter: true,
                                loop: false,
                                onCenterIndexChange: { idx in
                                    guard idx >= 0, idx < items.count else { return }
                                    if idx != currentIndex {
                                        currentIndex = idx
                                    }
                                }
                            ) { item in
                                LSLessonCardV(
                                    item: item,
                                    onTap: onTap,
                                    onFavorite: onFavorite.map { cb in { cb(item) } },
                                    favoriteCount: item.favoriteCount,
                                    onConsole: onTapAccessory.map { tap in { tap(item) } },
                                    onSpeaker: onSpeaker.map { cb in { cb(item) } },
                                    onNext: onNext.map { cb in { cb(item) } },
                                    isTrainingSelected: selectedLessonIds.contains(item.id),
                                    onTrainingToggle: nil
                                )
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: isCollapsed)
            }
        }
    }
}

// MARK: - Course Stats (model)
public struct LSReinforcementSkill: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: String
    public let score: Int?
    public let sessions: Int
    public let isSpeaker: Bool
    /// Raw GameModeType value for a classified game row; nil for Speaker.
    public let modeRawValue: String?
    /// True when the row is a paid game and the current user is not PRO.
    public let isProLocked: Bool

    public init(id: String, title: String, subtitle: String, icon: String, score: Int? = nil, sessions: Int = 0, isSpeaker: Bool = false, modeRawValue: String? = nil, isProLocked: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.score = score
        self.sessions = max(0, sessions)
        self.isSpeaker = isSpeaker
        self.modeRawValue = modeRawValue
        self.isProLocked = isProLocked
    }
}

public struct LSCourseStats: Hashable {
    public let completedLessons: Int
    public let totalLessons: Int
    public let learnedWords: Int
    public let favorites: Int
    public let streakDays: Int
    public let timeMinutes: Int
    public let gameCoveredCards: Int
    public let gameSessions: Int
    public let reinforcementScore: Int?
    public let reinforcementSkills: [LSReinforcementSkill]

    public init(
        completedLessons: Int,
        totalLessons: Int,
        learnedWords: Int,
        favorites: Int,
        streakDays: Int,
        timeMinutes: Int,
        gameCoveredCards: Int = 0,
        gameSessions: Int = 0,
        reinforcementScore: Int? = nil,
        reinforcementSkills: [LSReinforcementSkill] = []
    ) {
        self.completedLessons = max(0, completedLessons)
        self.totalLessons = max(1, totalLessons)
        self.learnedWords = max(0, learnedWords)
        self.favorites = max(0, favorites)
        self.streakDays = max(0, streakDays)
        self.timeMinutes = max(0, timeMinutes)
        self.gameCoveredCards = max(0, gameCoveredCards)
        self.gameSessions = max(0, gameSessions)
        self.reinforcementScore = reinforcementScore.map { max(0, min(100, $0)) }
        self.reinforcementSkills = reinforcementSkills
    }
}

// MARK: - Course overview (minimal: no outer card; progress block + stats strip)

/// Оставшееся время курса: заметная «пилюля» в акценте (читается как таймер).
private struct LSCourseETATimer: View {
    let minutes: Int

    private var mmss: String {
        let m = max(0, minutes)
        return String(format: "%d:%02d", m, 0)
    }

    private var accent: AnyShapeStyle {
        AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))
            Text(mmss)
                .font(Theme.Fonts.metric(13))
                .monospacedDigit()
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(ThemeManager.shared.currentAccentFill.opacity(0.2))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(ThemeManager.shared.currentAccentFill.opacity(0.45), lineWidth: 1)
        )
        .accessibilityLabel("Осталось примерно \(minutes) минут")
    }
}

// MARK: - Course Practice Dock
public struct LSCompletedLessonOption: Identifiable, Hashable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

private enum LSGradeSheetTokens {
    static let error = Color(red: 0.92, green: 0.28, blue: 0.32)
}

private struct LSCompletedJungleWaves: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Color(red: 0.055, green: 0.062, blue: 0.066)
                RadialGradient(
                    colors: [Color(red: 0.78, green: 0.90, blue: 0.88).opacity(0.055), .clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: max(w, h) * 0.82
                )
                Path { path in
                    path.move(to: CGPoint(x: -12, y: h * 0.76))
                    path.addCurve(to: CGPoint(x: w * 0.46, y: h * 0.57), control1: CGPoint(x: w * 0.14, y: h * 0.52), control2: CGPoint(x: w * 0.28, y: h * 0.84))
                    path.addCurve(to: CGPoint(x: w + 12, y: h * 0.42), control1: CGPoint(x: w * 0.67, y: h * 0.33), control2: CGPoint(x: w * 0.82, y: h * 0.54))
                }
                .stroke(Color(red: 0x36 / 255.0, green: 0xF5 / 255.0, blue: 0xB0 / 255.0).opacity(0.19), lineWidth: 1.0)
                Path { path in
                    path.move(to: CGPoint(x: -12, y: h * 0.87))
                    path.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.68), control1: CGPoint(x: w * 0.10, y: h * 0.74), control2: CGPoint(x: w * 0.28, y: h * 0.94))
                    path.addCurve(to: CGPoint(x: w + 12, y: h * 0.52), control1: CGPoint(x: w * 0.62, y: h * 0.40), control2: CGPoint(x: w * 0.82, y: h * 0.66))
                }
                .stroke(Color(red: 0x19 / 255.0, green: 0xCF / 255.0, blue: 0xA0 / 255.0).opacity(0.12), lineWidth: 0.8)
                Path { path in
                    path.move(to: CGPoint(x: -12, y: h * 0.62))
                    path.addCurve(to: CGPoint(x: w * 0.55, y: h * 0.46), control1: CGPoint(x: w * 0.18, y: h * 0.38), control2: CGPoint(x: w * 0.31, y: h * 0.72))
                    path.addCurve(to: CGPoint(x: w + 12, y: h * 0.30), control1: CGPoint(x: w * 0.72, y: h * 0.23), control2: CGPoint(x: w * 0.86, y: h * 0.39))
                }
                .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The completed-course hero: reinforcement is the primary task, not the lesson catalog.
public struct LSCompletedTrainingHero: View {
    public let stats: LSCourseStats
    public let selectedCount: Int
    public let totalLessons: Int
    public let weakCount: Int
    public let onSpeaker: (() -> Void)?
    public let onGamePark: (() -> Void)?
    public let onGameMode: ((String) -> Void)?
    public let onProLocked: (() -> Void)?
    public let selectedWeakCount: Int
    public let onFocus: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didReveal = false
    @State private var displayedScore = 0

    public init(
        stats: LSCourseStats,
        selectedCount: Int,
        totalLessons: Int,
        weakCount: Int,
        onSpeaker: (() -> Void)? = nil,
        onGamePark: (() -> Void)? = nil,
        onGameMode: ((String) -> Void)? = nil,
        onProLocked: (() -> Void)? = nil,
        selectedWeakCount: Int = 0,
        onFocus: (() -> Void)? = nil
    ) {
        self.stats = stats
        self.selectedCount = selectedCount
        self.totalLessons = totalLessons
        self.weakCount = weakCount
        self.onSpeaker = onSpeaker
        self.onGamePark = onGamePark
        self.onGameMode = onGameMode
        self.onProLocked = onProLocked
        self.selectedWeakCount = max(0, selectedWeakCount)
        self.onFocus = onFocus
    }

    private var scoreValue: Int { stats.reinforcementScore ?? 0 }
    private var skillRows: [LSReinforcementSkill] {
        if !stats.reinforcementSkills.isEmpty { return stats.reinforcementSkills }
        return [
            LSReinforcementSkill(id: "speaker", title: "Спикер", subtitle: "Произношение и тоны", icon: "mic.fill", isSpeaker: true),
            LSReinforcementSkill(id: "game", title: "Игра", subtitle: "Закрепление карточек", icon: "gamecontroller.fill")
        ]
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("ЗАЧЁТКА КУРСА")
                    .font(.system(size: 12, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(AnyShapeStyle(TaikaMasteryTokens.greenBadgeGradient))
                Spacer(minLength: 0)
                Text(selectedCount == 0 ? "выбери уроки ниже" : "\(selectedCount) уроков в фокусе")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }

            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(PD.ColorToken.stroke.opacity(0.78), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: max(0.02, CGFloat(scoreValue) / 100))
                        .stroke(
                            TaikaMasteryTokens.greenGradient,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.55), value: displayedScore)
                    VStack(spacing: 0) {
                        Text(stats.reinforcementScore == nil ? "—" : "\(displayedScore)%")
                            .font(Theme.Fonts.metric(32))
                            .foregroundStyle(AnyShapeStyle(TaikaMasteryTokens.greenBadgeGradient))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .frame(width: 116, height: 116)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(stats.reinforcementScore == nil ? "Результат пока не рассчитан" : "\(displayedScore) процентов закрепления")
                .opacity(didReveal ? 1 : 0)
                .scaleEffect(didReveal || reduceMotion ? 1 : 0.94)

                VStack(alignment: .leading, spacing: 6) {
                    Text(statusTitle)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .lineLimit(2)
                    Text(statusSubtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(didReveal ? 1 : 0)
                .offset(y: didReveal ? 0 : 5)
            }

            HStack(alignment: .top, spacing: 0) {
                metric(value: "\(stats.gameCoveredCards)", label: "карточки в игре")
                metric(value: "\(stats.gameSessions)", label: "игровые сессии")
                metric(value: "\(weakCount)", label: "в фокусе")
            }
            .padding(.top, 2)
            .opacity(didReveal ? 1 : 0)

            HStack(spacing: 8) {
                conclusionTag(title: "Сильные стороны", value: strengthTag)
                conclusionTag(title: "Зона роста", value: growthTag)
            }
            .opacity(didReveal ? 1 : 0)

            Rectangle()
                .fill(PD.ColorToken.stroke.opacity(0.55))
                .frame(height: 1)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 0) {
                Text("ПРЕДМЕТЫ ЗАЧЁТКИ")
                    .font(.system(size: 12, weight: .bold))
                    .kerning(0.4)
                    .foregroundStyle(AnyShapeStyle(TaikaMasteryTokens.greenBadgeGradient))
                    .padding(.bottom, 2)
                ForEach(skillRows) { skill in
                    skillRow(skill)
                }

                // Reinforcement is surfaced once as a contextual floating action at screen level.
                // Keeping the grade sheet focused on the result and the lesson scope avoids a second CTA stack here.
            }
        }
        .padding(14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.035))
                LSCompletedJungleWaves()
                    .opacity(0.16)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .onAppear {
            guard !didReveal else { return }
            if reduceMotion {
                didReveal = true
                displayedScore = scoreValue
            } else {
                withAnimation(.easeOut(duration: 0.32)) {
                    didReveal = true
                    displayedScore = scoreValue
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Главный блок тренировки курса")
    }

    private var statusTitle: String {
        guard let score = stats.reinforcementScore else { return "Закрепление начинается" }
        if score >= 85 { return "Отличный результат!" }
        if score >= 65 { return "Хорошая база для речи" }
        return "Есть что усилить"
    }

    private var statusSubtitle: String {
        if stats.reinforcementScore == nil { return "Пройди первую тренировку, чтобы увидеть эффективность курса." }
        if weakCount > 0 { return "Продолжай закреплять — сначала то, что ещё просит внимания." }
        return "Продолжай закреплять — ты почти всё запомнил(а)."
    }

    private var strengthTag: String {
        let scored = skillRows.compactMap { skill -> (String, Int)? in
            guard let score = skill.score else { return nil }
            return (skill.title, score)
        }
        return scored.max(by: { $0.1 < $1.1 })?.0 ?? "память"
    }

    private var growthTag: String {
        if weakCount > 0 {
            let scored = skillRows.compactMap { skill -> (String, Int)? in
                guard let score = skill.score else { return nil }
                return (skill.title, score)
            }
            return scored.min(by: { $0.1 < $1.1 })?.0 ?? "на слух"
        }
        return "поддержать"
    }

    private func conclusionTag(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .kerning(0.25)
                .foregroundStyle(PD.ColorToken.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AnyShapeStyle(TaikaMasteryTokens.greenBadgeGradient))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
    }

    @ViewBuilder
    private func skillRow(_ skill: LSReinforcementSkill) -> some View {
        let action: (() -> Void)? = {
            if skill.isSpeaker { return onSpeaker }
            if skill.isProLocked { return onProLocked }
            if let mode = skill.modeRawValue { return { onGameMode?(mode) } }
            return onGamePark
        }()
        let enabled = action != nil && selectedCount > 0
        let content = HStack(alignment: .center, spacing: 12) {
            Image(systemName: skill.icon)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(PD.ColorToken.text)
                .frame(width: 28, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Text(skill.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .center, spacing: 8) {
                if skill.isProLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
                        .accessibilityLabel("Недоступно")
                    Text("Taika+")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                } else {
                    Text(skill.score.map { "\($0)%" } ?? "—")
                        .font(Theme.Fonts.metric(21))
                        .foregroundStyle(skill.score == nil ? AnyShapeStyle(PD.ColorToken.textSecondary) : AnyShapeStyle(TaikaMasteryTokens.greenBadgeGradient))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.28), value: skill.score)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(PD.ColorToken.textSecondary.opacity(skill.isProLocked ? 0.56 : 0.82)))
            }
            .frame(minWidth: 88, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(PD.ColorToken.stroke.opacity(0.42)).frame(height: 1) }
        if enabled, let action { Button(action: action) { content }.buttonStyle(.plain) } else { content }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Theme.Fonts.metric(27))
                .monospacedDigit()
                .foregroundStyle(PD.ColorToken.text)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.28), value: value)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 4)
    }

}

public struct LSCompletedLessonList: View {
    public let items: [LS.Item]
    public let selectedIds: Set<String>
    public let weakIds: Set<String>
    public let scores: [String: Int]
    public let courseSessionCount: Int
    public let onToggle: (String) -> Void
    public let onOpen: ((String) -> Void)?
    public let onSelectAll: (() -> Void)?
    public let onClearAll: (() -> Void)?
    public let onSelectWeak: (() -> Void)?
    public let onTrainWeak: ((Set<String>) -> Void)?
    public let accentFill: AnyShapeStyle
    public let accentColor: Color
    public let isCompletedPresentation: Bool
    public let showFocusAction: Bool
    public let sectionTitle: String
    @State private var showingErrorsOnly: Bool = false

    public init(items: [LS.Item], selectedIds: Set<String>, weakIds: Set<String>, scores: [String: Int] = [:], courseSessionCount: Int = 0, onToggle: @escaping (String) -> Void, onOpen: ((String) -> Void)? = nil, onSelectAll: (() -> Void)? = nil, onClearAll: (() -> Void)? = nil, onSelectWeak: (() -> Void)? = nil, onTrainWeak: ((Set<String>) -> Void)? = nil, accentFill: AnyShapeStyle = AnyShapeStyle(TaikaMasteryTokens.greenGradient), accentColor: Color = TaikaMasteryTokens.greenGlow, isCompletedPresentation: Bool = true, showFocusAction: Bool = true, sectionTitle: String = "ФОКУС НА СЕГОДНЯ") {
        self.items = items
        self.selectedIds = selectedIds
        self.weakIds = weakIds
        self.scores = scores
        self.courseSessionCount = max(0, courseSessionCount)
        self.onToggle = onToggle
        self.onOpen = onOpen
        self.onSelectAll = onSelectAll
        self.onClearAll = onClearAll
        self.onSelectWeak = onSelectWeak
        self.onTrainWeak = onTrainWeak
                self.accentFill = accentFill
        self.accentColor = accentColor
        self.isCompletedPresentation = isCompletedPresentation
        self.showFocusAction = showFocusAction
        self.sectionTitle = sectionTitle
    }
    @ViewBuilder
    public var body: some View {
        if isCompletedPresentation {
            completedBody
        } else {
            legacyBody
        }
    }

    private var completedBody: some View {
        let visibleItems = showingErrorsOnly ? items.filter { weakIds.contains($0.id) } : items
        let selectedFill = AnyShapeStyle(PD.ColorToken.text.opacity(0.92))
        let errorFill = AnyShapeStyle(LSGradeSheetTokens.error)
        let hasErrors = !weakIds.isEmpty
        let selectedCount = selectedIds.intersection(Set(visibleItems.map(\.id))).count
        let selectedFocusIds = selectedIds.intersection(weakIds)
        let canStartFocus = !selectedFocusIds.isEmpty && onTrainWeak != nil

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(sectionTitle)
                    .taikaSectionTitleStyle()
                Spacer(minLength: 0)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showingErrorsOnly = false }
                } label: {
                    Text("УРОКИ")
                        .font(.system(size: 12, weight: showingErrorsOnly ? .medium : .semibold))
                        .foregroundStyle(showingErrorsOnly ? PD.ColorToken.textSecondary : PD.ColorToken.text)
                        .padding(.bottom, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(showingErrorsOnly ? AnyShapeStyle(Color.clear) : selectedFill)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showingErrorsOnly = true }
                } label: {
                    Text("ОШИБКИ \(weakCardCount)")
                        .font(.system(size: 12, weight: showingErrorsOnly ? .semibold : .medium))
                        .foregroundStyle(showingErrorsOnly ? PD.ColorToken.text : (hasErrors ? PD.ColorToken.textSecondary : PD.ColorToken.textSecondary.opacity(0.45)))
                        .padding(.bottom, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(showingErrorsOnly ? selectedFill : AnyShapeStyle(Color.clear))
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!hasErrors)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(PD.ColorToken.stroke.opacity(0.55)).frame(height: 1)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(showingErrorsOnly ? "Ошибки в курсе" : "Выбрано \(selectedCount) из \(items.count)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Spacer(minLength: 8)
                if let onClearAll, !selectedIds.isEmpty {
                    Button("Сбросить", action: onClearAll)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .buttonStyle(.plain)
                } else if !showingErrorsOnly, let onSelectAll, selectedIds.count < items.count {
                    Button("Выбрать все", action: onSelectAll)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)

            if visibleItems.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ошибок пока нет")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                    Text("После игры здесь появятся уроки, которым нужна короткая практика.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(visibleItems) { item in
                        let selected = selectedIds.contains(item.id)
                        HStack(spacing: 12) {
                            Button { onToggle(item.id) } label: {
                                HStack(spacing: 12) {
                                    Rectangle()
                                        .fill(selected ? selectedFill : AnyShapeStyle(Color.clear))
                                        .frame(width: 2)
                                    Text(String(format: "%02d", item.index + 1))
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                        .frame(width: 26, alignment: .leading)
                                    HStack(spacing: 8) {
                                        Text(item.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(PD.ColorToken.text)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.82)
                                        if item.errorCardCount > 0 {
                                            HStack(spacing: 4) {
                                                Image(systemName: "exclamationmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                Text("ошибки \(item.errorCardCount)")
                                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            }
                                            .foregroundStyle(errorFill)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(LSGradeSheetTokens.error.opacity(0.12))
                                                    .overlay(
                                                        Capsule(style: .continuous)
                                                            .stroke(LSGradeSheetTokens.error.opacity(0.38), lineWidth: 1)
                                                    )
                                            )
                                        } else {
                                            Text("без ошибок")
                                                .font(.system(size: 11, weight: .regular))
                                                .foregroundStyle(PD.ColorToken.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if let onOpen {
                                Button { onOpen(item.id) } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.82))
                                        .frame(width: 28, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Открыть урок")
                            }
                        }
                        .frame(minHeight: 66)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(PD.ColorToken.stroke.opacity(0.32)).frame(height: 1)
                        }
                    }
                }
            }

            if showFocusAction {
                let focusTitle = canStartFocus ? "Начать с фокуса" : "Фокус пока недоступен"
                let focusDetail: String = {
                    if !hasErrors { return "После игры здесь появятся карточки для повторения" }
                    if selectedFocusIds.isEmpty { return "Выбери урок с ошибками выше" }
                    return "\(selectedFocusIds.count) уроков · \(weakCardCount) карточки требуют внимания"
                }()
                Button {
                    onTrainWeak?(selectedFocusIds)
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: "scope")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(canStartFocus ? 0.9 : 0.42))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(focusTitle)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(canStartFocus ? PD.ColorToken.text : PD.ColorToken.textSecondary.opacity(0.55))
                            Text(focusDetail)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(canStartFocus ? 0.86 : 0.48))
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(canStartFocus ? 0.9 : 0.38))
                    }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(PD.ColorToken.card.opacity(canStartFocus ? 0.82 : 0.42))
                            )
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(
                                        canStartFocus
                                            ? AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [ThemeManager.shared.currentAccentTintColor, ThemeManager.shared.currentAccentFill],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            : AnyShapeStyle(PD.ColorToken.stroke.opacity(0.34))
                                    )
                                    .frame(width: 3)
                                    .padding(.vertical, 10)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(PD.ColorToken.stroke.opacity(canStartFocus ? 0.72 : 0.34), lineWidth: 1)
                            )
                }
                .buttonStyle(PressDownStyle(scale: 0.985, fade: 0.98, useBouncySpring: false))
                .disabled(!canStartFocus)
                .padding(.top, 12)
                .accessibilityLabel(canStartFocus ? "Начать закрепление с выбранных ошибок" : focusDetail)
            }
        }
        .padding(.top, 4)
    }

    private var legacyBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("ФОКУС НА СЕГОДНЯ")
                    .taikaSectionTitleStyle()
                Spacer(minLength: 8)
                Text(legacySelectionLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            Text("Выбери пройденные уроки для следующего подхода")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(2)
            HStack(spacing: 18) {
                if let onSelectAll {
                    Button("Выбрать все", action: onSelectAll)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selectedIds.count < items.count ? AnyShapeStyle(accentColor) : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.5)))
                        .buttonStyle(.plain)
                }
                if let onClearAll {
                    Button("Снять выбор", action: onClearAll)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(!selectedIds.isEmpty ? AnyShapeStyle(accentColor) : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.5)))
                        .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: 11) {
                        Button { onToggle(item.id) } label: {
                            HStack(spacing: 11) {
                                Image(systemName: selectedIds.contains(item.id) ? "checkmark" : "circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(selectedIds.contains(item.id) ? AnyShapeStyle(accentColor) : AnyShapeStyle(PD.ColorToken.textSecondary))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(PD.ColorToken.text)
                                    Text(item.errorCardCount > 0 ? "ошибки \(item.errorCardCount)" : "без ошибок")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(item.errorCardCount > 0 ? AnyShapeStyle(accentColor) : AnyShapeStyle(PD.ColorToken.textSecondary))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if let onOpen {
                            Button { onOpen(item.id) } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.78))
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Открыть урок")
                        }
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Rectangle().fill(PD.ColorToken.stroke.opacity(0.32)).frame(height: 1) }
                }
            }
        }
        .padding(.top, 4)
    }

    private var legacySelectionLabel: String {
        if selectedIds.isEmpty { return "ничего не выбрано" }
        if selectedIds.count == items.count { return "все уроки" }
        return "\(selectedIds.count) выбрано"
    }

    private var weakCardCount: Int {
        let count = items
            .filter { weakIds.contains($0.id) }
            .reduce(0) { $0 + max(0, $1.errorCardCount) }
        return max(0, count)
    }
}

/// Compact practice surface: completed scope first, Dictionary-style actions second.
public struct LSCoursePracticeDock: View {
    public let stats: LSCourseStats
    public let currentLessonTitle: String?
    public let completedLessons: [LSCompletedLessonOption]
    public let weakLessonIds: Set<String>
    public let onSelectionChange: ((Set<String>?) -> Void)?
    public let onSpeaker: (() -> Void)?
    public let onGamePark: (() -> Void)?
    @State private var selectedLessonIds: Set<String>?

    public init(
        stats: LSCourseStats,
        currentLessonTitle: String? = nil,
        completedLessons: [LSCompletedLessonOption] = [],
        weakLessonIds: Set<String> = [],
        selectedLessonIds: Set<String>? = nil,
        onSelectionChange: ((Set<String>?) -> Void)? = nil,
        onSpeaker: (() -> Void)? = nil,
        onGamePark: (() -> Void)? = nil
    ) {
        self.stats = stats
        self.currentLessonTitle = currentLessonTitle
        self.completedLessons = completedLessons
        self.weakLessonIds = weakLessonIds
        self.onSelectionChange = onSelectionChange
        self.onSpeaker = onSpeaker
        self.onGamePark = onGamePark
        self._selectedLessonIds = State(initialValue: selectedLessonIds)
    }

    private var selectedScope: Set<String> {
        let all = Set(completedLessons.map(\.id))
        return selectedLessonIds ?? all
    }

    private var selectedTitle: String {
        let count = selectedScope.count
        if count == completedLessons.count {
            return "Все пройденные уроки · \(completedLessons.count)"
        }
        if count == 0 { return "Выберите уроки для закрепления" }
        return "Выбрано уроков · \(count)"
    }

    public var body: some View {
        let allSelected = !completedLessons.isEmpty && selectedScope.count == completedLessons.count
        let hasSelection = !selectedScope.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("ЗАКРЕПЛЕНИЕ")
                    .taikaSectionTitleStyle()
                Spacer(minLength: 8)
                Text(hasSelection ? "\(selectedScope.count) выбрано" : "выбери материалы")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(hasSelection ? AnyShapeStyle(TaikaMasteryTokens.green) : AnyShapeStyle(PD.ColorToken.textSecondary))
            }

            HStack(spacing: 8) {
                Button {
                    selectedLessonIds = nil
                    onSelectionChange?(nil)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                        Text("Все")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(allSelected ? AnyShapeStyle(Color.black) : AnyShapeStyle(PD.ColorToken.textSecondary))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(allSelected ? AnyShapeStyle(TaikaMasteryTokens.green) : AnyShapeStyle(PD.ColorToken.card.opacity(0.7))))
                }
                .buttonStyle(.plain)

                Button {
                    let weak = weakLessonIds.intersection(Set(completedLessons.map(\.id)))
                    selectedLessonIds = weak.isEmpty ? nil : weak
                    onSelectionChange?(selectedLessonIds)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.path.ecg")
                        Text("Ошибки")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(weakLessonIds.isEmpty ? AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.45)) : AnyShapeStyle(TaikaMasteryTokens.green))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(PD.ColorToken.card.opacity(0.72)))
                }
                .buttonStyle(.plain)
                .disabled(weakLessonIds.isEmpty)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(completedLessons) { option in
                            let isSelected = selectedScope.contains(option.id)
                            Button {
                                var updated = selectedScope
                                if isSelected { updated.remove(option.id) } else { updated.insert(option.id) }
                                let all = Set(completedLessons.map(\.id))
                                selectedLessonIds = updated == all ? nil : updated
                                onSelectionChange?(selectedLessonIds)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: isSelected ? "checkmark" : "circle")
                                    Text(option.title)
                                        .lineLimit(1)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isSelected ? AnyShapeStyle(Color.black) : AnyShapeStyle(PD.ColorToken.text))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(isSelected ? AnyShapeStyle(TaikaMasteryTokens.green) : AnyShapeStyle(PD.ColorToken.card.opacity(0.72))))
                                .overlay(Capsule().stroke(isSelected ? AnyShapeStyle(TaikaMasteryTokens.green) : AnyShapeStyle(PD.ColorToken.stroke.opacity(0.5)), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .disabled(completedLessons.isEmpty)
            .accessibilityLabel("Выбор нескольких уроков для закрепления")

            HStack(spacing: 8) {
                Image(systemName: stats.gameSessions > 0 ? "checkmark.seal.fill" : "waveform.path.ecg")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(TaikaMasteryTokens.green))
                Text(stats.reinforcementScore.map { "В игре · \(stats.gameCoveredCards) карточек · \($0)%" } ?? "Выбери уроки, чтобы собрать тренировку")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                quickActionRow(
                    icon: "mic.fill",
                    title: "Закрепить в Спикере",
                    detail: hasSelection ? "Произношение выбранных уроков" : "Сначала выбери один или несколько уроков",
                    isEnabled: onSpeaker != nil && hasSelection,
                    action: onSpeaker
                )
                quickActionRow(
                    icon: "gamecontroller.fill",
                    title: "Повторить в игре",
                    detail: hasSelection ? "Проверка памяти по этому же набору" : "Сначала выбери один или несколько уроков",
                    isEnabled: onGamePark != nil && hasSelection,
                    action: onGamePark
                )
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Закрепление пройденных уроков")
    }

    @ViewBuilder
    private func quickActionRow(icon: String, title: String, detail: String, isEnabled: Bool, action: (() -> Void)?) -> some View {
        let content = HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isEnabled ? AnyShapeStyle(TaikaMasteryTokens.greenGradient) : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.55)))
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isEnabled ? PD.ColorToken.text : PD.ColorToken.textSecondary.opacity(0.55))
                Text(detail)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(isEnabled ? 0.82 : 0.45))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(isEnabled ? 0.85 : 0.42))
        }
        .padding(.vertical, 12)
        .padding(.leading, isEnabled ? 8 : 0)
        .background {
            if isEnabled {
                LinearGradient(
                    colors: [
                        TaikaMasteryTokens.green.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .overlay(alignment: .leading) {
            if isEnabled {
                Capsule()
                    .fill(TaikaMasteryTokens.greenGradient)
                    .frame(width: 3)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PD.ColorToken.stroke.opacity(0.42))
                .frame(height: 1)
        }
        .contentShape(Rectangle())

        if isEnabled, let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

public struct LSCourseOverview: View {
    public let stats: LSCourseStats
    /// Course title (displayed as main heading).
    public let category: String
    public var etaMinutes: Int?
    public let onCTA: () -> Void
    public let onReset: () -> Void
    public var onSpeaker: (() -> Void)?
    public var onReinforce: (() -> Void)?
    public let showInlineProgress: Bool

    @State private var displayLessonsDone: Int = 0
    @State private var displayWords: Int = 0
    @State private var displayFavorites: Int = 0
    @State private var displayMinutes: Int = 0
    @State private var appeared: Bool = false
    @State private var countTask: Task<Void, Never>?

    private var courseProgress: Double {
        guard stats.totalLessons > 0 else { return 0 }
        return min(1.0, max(0.0, Double(stats.completedLessons) / Double(stats.totalLessons)))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !category.isEmpty {
                Text(category)
                    .font(PD.FontToken.body(18, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .lineLimit(2)
                    .padding(.bottom, 14)
            }

            // Прогресс + сброс в одной панели
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Text("ПРОГРЕСС")
                        .taikaSectionTitleStyle()
                    Spacer(minLength: 8)
                    if let eta = etaMinutes, eta > 0 {
                        LSCourseETATimer(minutes: eta)
                    }
                    Button(action: onReset) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("сброс")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(
                            Capsule(style: .continuous)
                                .fill(PD.ColorToken.chip.opacity(0.9))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Сбросить прогресс курса")
                }

                AppProgressBar(value: CGFloat(courseProgress), height: 6)
                    .padding(.trailing, 1)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: courseProgress)
            }
            .padding(.bottom, 18)

            // Course metrics: technical numeric face, без рамок и hairline.
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                TaikaStatMetric(
                    valueText: "\(displayLessonsDone)/\(stats.totalLessons)",
                    label: "уроки",
                    valueSize: 44,
                    accent: false,
                    appeared: appeared,
                    delay: 0
                )
                TaikaStatMetric(
                    valueText: "\(displayWords)",
                    label: "слова",
                    valueSize: 44,
                    accent: false,
                    appeared: appeared,
                    delay: 0.06
                )
                TaikaStatMetric(
                    valueText: "\(displayFavorites)",
                    label: "избранное",
                    valueSize: 44,
                    accent: false,
                    appeared: appeared,
                    delay: 0.12
                )
                TaikaStatMetric(
                    valueText: "\(displayMinutes)",
                    label: "мин",
                    valueSize: 44,
                    accent: false,
                    appeared: appeared,
                    delay: 0.18
                )
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(stats.completedLessons) из \(stats.totalLessons) уроков, \(stats.learnedWords) слов, \(stats.favorites) в избранном, \(stats.timeMinutes) минут"
            )
        }
        .onAppear { animateStats() }
        .onChange(of: stats) { _, _ in animateStats(fromCurrent: true) }
        .onDisappear { countTask?.cancel() }
    }

    private func animateStats(fromCurrent: Bool = false) {
        countTask?.cancel()
        if !fromCurrent {
            displayLessonsDone = 0
            displayWords = 0
            displayFavorites = 0
            displayMinutes = 0
            appeared = false
        }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
            appeared = true
        }
        countTask = Task { @MainActor in
            async let a: Void = countUp(to: stats.completedLessons, assign: { displayLessonsDone = $0 }, stagger: 0)
            async let b: Void = countUp(to: stats.learnedWords, assign: { displayWords = $0 }, stagger: 0.06)
            async let c: Void = countUp(to: stats.favorites, assign: { displayFavorites = $0 }, stagger: 0.12)
            async let d: Void = countUp(to: stats.timeMinutes, assign: { displayMinutes = $0 }, stagger: 0.18)
            _ = await (a, b, c, d)
        }
    }

    private func countUp(to target: Int, assign: @escaping (Int) -> Void, stagger: TimeInterval) async {
        if stagger > 0 {
            try? await Task.sleep(nanoseconds: UInt64(stagger * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        let clamped = max(0, target)
        guard clamped > 0 else {
            assign(0)
            return
        }
        let steps = min(clamped, 22)
        let stepDuration = 0.72 / Double(steps)
        for i in 1...steps {
            if Task.isCancelled { return }
            let next = Int(round(Double(clamped) * Double(i) / Double(steps)))
            withAnimation(.easeOut(duration: 0.05)) {
                assign(next)
            }
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }
        assign(clamped)
    }

    public init(
        stats: LSCourseStats,
        category: String,
        etaMinutes: Int? = nil,
        onCTA: @escaping () -> Void,
        onReset: @escaping () -> Void = {},
        onSpeaker: (() -> Void)? = nil,
        onReinforce: (() -> Void)? = nil,
        showInlineProgress: Bool = false
    ) {
        self.stats = stats
        self.category = category
        self.etaMinutes = etaMinutes
        self.onCTA = onCTA
        self.onReset = onReset
        self.onSpeaker = onSpeaker
        self.onReinforce = onReinforce
        self.showInlineProgress = showInlineProgress
    }
}

// MARK: - Section Title (shared style)
public struct LSSectionTitle: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public init(title: String) { self.text = title }
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(text.uppercased())
                .taikaSectionTitleStyle()
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview helpers
struct LSSampleData {
    static let list: [LS.Item] = [
        .init(index: 1, title: "Приветствие и small talk", subtitle: "Первые фразы, ice‑breakers. Научимся начинать разговор уверенно.", durationMinutes: 6, isPro: false, status: .completed, tags: ["разговор"], cardCount: 12, favoriteCount: 3),
        .init(index: 2, title: "Заказать кофе", subtitle: "Как без стресса попросить и уточнить. Практикуем вежливые формулы.", durationMinutes: 8, isPro: false, status: .inProgress, tags: ["кофейня"], cardCount: 16, favoriteCount: 2),
        .init(index: 3, title: "Такси и адрес", subtitle: "Вежливо, но уверенно. Закрепим полезные фразы и короткие диалоги.", durationMinutes: 10, isPro: true, status: .locked, tags: ["такси"], cardCount: 9, favoriteCount: 1)
    ]
    static let content: [LS.ContentItem] = [
        .init(kind: .intro,
              text: "Немного разогреемся: что говорить при знакомстве и как уверенно начать разговор.",
              imageName: "mascot.profile"),
        .init(kind: .outline,
              text: "Из чего состоит урок: мини‑диалоги, полезные фразы и короткая практика.",
              imageName: "mascot.profile"),
        .init(kind: .outcome,
              text: "По итогам поймёшь базовые структуры, начнёшь говорить увереннее и быстрее подбирать фразы.",
              imageName: "mascot.profile"),
        .init(kind: .apply,
              text: "Где применять: кафе, такси, короткие small talk — сразу пробуешь в жизни.",
              imageName: "mascot.profile")
    ]
    static let hometasks: [HT.Item] = [
        .init(index: 1, title: "домашка: small talk", subtitle: "2 короткие диалога и 1 запись голоса", durationMinutes: 5),
        .init(index: 2, title: "домашка: кофе без стресса", subtitle: "потренируй форму вежливости", durationMinutes: 6),
        .init(index: 3, title: "домашка: адрес для такси", subtitle: "проговори адрес и уточнение 3 раза", durationMinutes: 7)
    ]
    static let stats = LSCourseStats(
        completedLessons: 5,
        totalLessons: 8,
        learnedWords: 207, // 145 words + 62 phrases
        favorites: 23,
        streakDays: 9,
        timeMinutes: 118
    )
}

// MARK: - Progress Section (modeled after CDProgressSection)
public struct LSProgressSection: View {
    public let lessonsDone: Int
    public let lessonsTotal: Int
    public let etaMinutes: Int?

    private var progress: Double {
        guard lessonsTotal > 0 else { return 0 }
        return min(1.0, max(0.0, Double(lessonsDone) / Double(lessonsTotal)))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header (LEFT: gray title, RIGHT: lessons label)
            HStack(alignment: .center) {
                Text("ПРОГРЕСС")
                    .taikaSectionTitleStyle()

                Spacer()

                Text("\(lessonsDone)/\(lessonsTotal)")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
            }

            if let etaMinutes, etaMinutes > 0 {
                Text("до завершения курса ≈ \(etaMinutes) мин")
                    .font(PD.FontToken.caption(12, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.92))
            }

            // Single thin progress bar – reuse unified App progress widget
            AppProgressBar(value: CGFloat(progress), height: 8)
                .padding(.trailing, 2)
        }
    }
}

// MARK: - Preview host to inject ThemeManager
private struct _ThemePreviewHost<Content: View>: View {
    @StateObject private var theme = ThemeManager.shared
    let content: () -> Content
    var body: some View { content().environmentObject(theme) }
}

#Preview("Lessons DS – List") {
    _ThemePreviewHost {
        NavigationStack {
            TaikaRootVerticalScroll {
                VStack(spacing: 12) {
                    LSLessonHeader(
                        title: "Разговорный минимум",
                        subtitle: "Учимся [[простому]] и [[полезному]] каждодневно",
                        progressCompleted: 3,
                        progressTotal: 8,
                        lessonsCount: 8,
                        progressSlots: [0.5, 0.4, 1.0, 0.0, 0.2, 0.85, 0.0, 0.0],
                        selectedIndex: 1
                    )
                    .lsSectionPadding()

                    LSMarqueeSection(
                        title: "taika fm",
                        messages: [
                            "давай закрепим тему: закажем кофе без стресса ☕️",
                            "повтори: ‘кафе йаак, капхе йаак’ — я подскажу произношение"
                        ]
                    )
                    .lsSectionPadding()

                    LSContentReels("содержание", items: LSSampleData.content)
                        .lsSectionPadding()

                    LSLessonReels("уроки", items: LSSampleData.list, collapsible: true, startExpanded: true, autoplay: false) { _ in }
                        .lsSectionPadding()

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("ИТОГИ")
                            .font(.caption.weight(.semibold))
                            .kerning(0.8)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text("Разговорный старт")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.text)
                            .lineLimit(1)
                    }
                    .lsSectionPadding(bottom: 0)
                    LSCourseOverview(
                        stats: LSCourseStats(
                            completedLessons: 3,
                            totalLessons: 10,
                            learnedWords: 25,
                            favorites: 5,
                            streakDays: 7,
                            timeMinutes: 120
                        ),
                        category: "",
                        etaMinutes: 22,
                        onCTA: {},
                        onReset: {},
                        showInlineProgress: false
                    )
                    .lsSectionPadding()
                }
                .padding(.top, Theme.Layout.pageTopAfterHeader)
            }
            .background(PD.ColorToken.background.ignoresSafeArea())
        }
        .lsBackToCoursesToolbar(title: "Назад к курсам") {
            print("backToCourses tapped in preview")
        }
    }
}
// MARK: - Content (section below assistant)

public extension LS {
    enum ContentKind: String, Hashable {
        case intro, outline, outcome, apply

        var chipTitle: String {
            switch self {
            case .intro:   return "Вводная"
            case .outline: return "Состав урока"
            case .outcome: return "Результат"
            case .apply:   return "Где применить"
            }
        }
    }

    struct ContentItem: Identifiable, Hashable {
        public let id: String
        public let kind: ContentKind
        public let text: String
        public let imageName: String?

        public init(id: String = UUID().uuidString,
                    kind: ContentKind,
                    text: String,
                    imageName: String? = nil) {
            self.id = id
            self.kind = kind
            self.text = text
            self.imageName = imageName
        }
    }
}

// Small reusable capsule chip
public struct LSChip: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.white.opacity(0.14))
            )
            .overlay(
                Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .foregroundStyle(Color.white.opacity(0.92))
            .frame(height: 26)
    }
}

// Adapter: LSContentCard now delegates to CardDS NoteCard
public struct LSContentCard: View {
    let item: LS.ContentItem
    public init(item: LS.ContentItem) { self.item = item }

    public var body: some View {
        NoteTextCard(
            label: item.kind.chipTitle.lowercased(),
            text: item.text,
            sectionChrome: .seps,
            chromeStyle: .cards
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// Horizontal reels of content cards with section title
public struct LSContentReels: View {
    let title: String
    let items: [LS.ContentItem]
    let collapsible: Bool

    @State private var currentIndex: Int = 0
    @State private var isCollapsed: Bool = true

    public init(_ title: String,
                items: [LS.ContentItem],
                autoplay: Bool = false,
                interval: Double = 4.0,
                collapsible: Bool = true) {
        self.title = title
        self.items = items
        self.collapsible = collapsible
    }

    public var body: some View {
        if items.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    LSSectionTitle(title)
                    Spacer(minLength: 0)
                    if collapsible {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                isCollapsed.toggle()
                            }
                        }) {
                            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                .font(.caption.weight(.semibold))
                                .kerning(0.4)
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isCollapsed ? "раскрыть содержание" : "скрыть содержание")
                    }
                }

                Group {
                    if isCollapsed {
                        EmptyView().frame(height: 0)
                    } else {
                        GeometryReader { geo in
                            let width = geo.size.width
                            // content cards should feel like a compact carousel, not full-width posters
                            let cardW = min(420, max(260, floor(width * 0.84)))
                            let spacing: CGFloat = 12
                            TaikaCarouselScroll {
                                HStack(spacing: spacing) {
                                    ForEach(items) { it in
                                        LSContentCard(item: it)
                                            .frame(width: cardW, height: CardDS.Metrics.noteCardHeight)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 2)
                            }
                        }
                        // note cards are tall; reserve full height so the next section doesn't get overlapped
                        .frame(height: CardDS.Metrics.noteCardHeight + 8)
                        .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isCollapsed)
        )
    }
}
// MARK: - Status Badge
