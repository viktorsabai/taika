//
//  HomeTaskDS.swift
//  taika
//
//  DS for a single game: "Подобрать пару" (phonetic ↔ ru)
//  Identity: dark, glassy cards, accentPink (from CD tokens), lowercase labels.
//  No business logic here — only reusable UI building blocks for the game screen.
//

import SwiftUI

// MARK: - Model used by DS (visual only)
public enum MPItemState { case idle, selected, matched, wrong }

public struct MPItem: Identifiable, Hashable {
    public let id: UUID = .init()
    public let pairId: String      // stable id to compare pairs
    public let text: String        // visible text (ph or ru)
    public let side: Side          // left: phonetic, right: ru
    public var state: MPItemState  // visual state
    public var hasAudio: Bool = false   // show speaker button when revealed
    public enum Side { case left, right }
    public init(pairId: String, text: String, side: Side, state: MPItemState = .idle, hasAudio: Bool = false) {
        self.pairId = pairId; self.text = text; self.side = side; self.state = state; self.hasAudio = hasAudio
    }
}

// MARK: - Card Back style
public enum MPBackStyle { case light, accent }

// MARK: - Card (mini) — brand identity
public struct MPCardMini: View {
    let text: String
    let isActive: Bool
    let isMatched: Bool
    let isWrong: Bool
    @EnvironmentObject private var theme: ThemeManager

    public init(text: String, isActive: Bool, isMatched: Bool, isWrong: Bool) {
        self.text = text
        self.isActive = isActive
        self.isMatched = isMatched
        self.isWrong = isWrong
    }

    public var body: some View {
        Text(text)
            .textCase(.lowercase)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .font(CD.FontToken.body(17, weight: .regular))
            .foregroundStyle(CD.ColorToken.text)
            .padding(.horizontal, 14).padding(.vertical, 14)
            .frame(minWidth: 120)
            .background(CD.ColorToken.card)
            .overlay(
                RoundedRectangle(cornerRadius: CD.Radius.card, style: .continuous)
                    .foregroundStyle(theme.currentAccentFill)
                    .opacity(isMatched ? 0.10 : (isActive ? 0.06 : 0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: CD.Radius.card, style: .continuous)
                    .stroke(
                        isMatched || isActive
                        ? AnyShapeStyle(theme.currentAccentFill)
                        : AnyShapeStyle(CD.ColorToken.stroke),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: CD.Radius.card, style: .continuous))
            .shadow(color: (isMatched || isActive) ? CD.ColorToken.accent.opacity(0.16) : .clear, radius: 10, x: 0, y: 6)
            .scaleEffect(isWrong ? 0.98 : (isActive ? 1.02 : 1.0))
            .animation(TaikaGameFeedbackMotion.pairSelectSpring, value: isActive)
            .animation(TaikaGameFeedbackMotion.cardWrongSpring, value: isWrong)
    }
}

// MARK: - Flip Card (memory-style)
public struct MPFlipCard: View {
    let text: String
    let isRevealed: Bool
    let state: MPItemState
    let side: MPItem.Side
    let backTitle: String
    let hasAudio: Bool
    let onPlay: (() -> Void)?
    @State private var matchedFlash: Bool = false
    @State private var selectedPulse: Bool = false
    @EnvironmentObject private var theme: ThemeManager

    public init(text: String, isRevealed: Bool, state: MPItemState, side: MPItem.Side, backTitle: String = "taika", hasAudio: Bool = false, onPlay: (() -> Void)? = nil) {
        self.text = text
        self.isRevealed = isRevealed
        self.state = state
        self.side = side
        self.backTitle = backTitle
        self.hasAudio = hasAudio
        self.onPlay = onPlay
    }

    public var body: some View {
        let radius: CGFloat = 16
        let len = text.count
        let fontSize: CGFloat = len > 28 ? 15 : (len > 20 ? 17 : 19)

        let front = ZStack {
            // base fill
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.96))
            // subtle top highlight
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom))
                .blendMode(.plusLighter)
            // state-specific backgrounds
            switch state {
            case .selected:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            case .matched:
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .foregroundStyle(theme.currentAccentFill)
                        .opacity(0.08)
                    // subtle brand gloss
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .blendMode(.plusLighter)
                }
            case .wrong:
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.red.opacity(0.06))
            case .idle:
                EmptyView()
            }
            // subtle lift for selected left cards (helps contrast)
            if side == .left && state == .selected {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(0.02))
            }
            // content
            Text(text)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .font(CD.FontToken.body(fontSize, weight: (side == .right ? .semibold : .medium)))
                .foregroundStyle(
                    side == .right
                    ? AnyShapeStyle(CD.ColorToken.text)
                    : AnyShapeStyle(theme.currentAccentFill)
                )
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .padding(.horizontal, 14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .overlay {
            if state == .selected {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        // (brand watermark overlay removed)

        ZStack {
            // BACK (shows when not revealed)
            MPCardBack(style: side == .left ? .light : .accent)
                .rotation3DEffect(.degrees(isRevealed ? -180 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                .opacity(isRevealed ? 0 : 1)

            // FRONT (content)
            front
                .rotation3DEffect(.degrees(isRevealed ? 0 : 180), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
                .opacity(isRevealed ? 1 : 0)
        }
        .frame(width: 172, height: 84)
        .overlay {
            if matchedFlash {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
                    .opacity(0.85)
                    .shadow(color: CD.ColorToken.accent.opacity(0.25), radius: 8, x: 0, y: 5)
                    .scaleEffect(matchedFlash ? 1.06 : 0.7)
                    .opacity(matchedFlash ? 0.0 : 0.75)
                    .animation(.easeOut(duration: 0.48), value: matchedFlash)
            }
        }
        .shadow(color: (state == .matched ? CD.ColorToken.accent.opacity(0.18) : (state == .selected ? Color.white.opacity(0.18) : .clear)),
                radius: state == .matched ? 12 : (state == .selected ? 12 : 0), x: 0, y: 8)
        .scaleEffect(state == .wrong ? 0.96 : (state == .selected ? 1.04 : (state == .matched ? 1.02 : 1.0)))
        .scaleEffect(matchedFlash ? 1.04 : 1.0)
        .modifier(TaikaGameShakeGeometryEffect(pct: state == .wrong ? 1 : 0))
        .animation(.easeInOut(duration: 0.34), value: isRevealed)
        .animation(.linear(duration: TaikaGameFeedbackMotion.mismatchShakeDuration), value: state == .wrong)
        .animation(TaikaGameFeedbackMotion.cardSelectSpring, value: state == .selected)
        .opacity(matchedFlash ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.6), value: matchedFlash)
        .onChange(of: state) { _, newValue in
            if newValue == .matched {
                matchedFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    matchedFlash = false
                }
            }
            if newValue == .selected {
                selectedPulse = true
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    selectedPulse.toggle()
                }
            } else {
                selectedPulse = false
            }
        }
    }

    private var isGlowing: Bool { state == .selected || state == .matched }
    private var glowColor: Color {
        switch state {
        case .matched: return CD.ColorToken.accent
        case .wrong:   return CD.ColorToken.accent.opacity(0.4)
        default:       return CD.ColorToken.accent
        }
    }
    private var borderColor: Color {
        switch state {
        case .matched:
            return CD.ColorToken.accent.opacity(0.65)
        case .selected:
            return CD.ColorToken.accent.opacity(0.9)
        case .wrong:
            return Color.red.opacity(0.5)
        default:
            return CD.ColorToken.stroke.opacity(0.7)
        }
    }
}

// MARK: - Card Back (brand templates)
public struct MPCardBack: View {
    public let style: MPBackStyle
    public var width: CGFloat
    public var height: CGFloat
    @EnvironmentObject private var theme: ThemeManager

    public init(style: MPBackStyle, width: CGFloat = 172, height: CGFloat = 84) {
        self.style = style
        self.width = width
        self.height = height
    }

    public var body: some View {
        let radius: CGFloat = 16
        ZStack {
            // base plate
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.96))
            // soft top highlight
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom))
                .blendMode(.plusLighter)
            // (brand title removed)
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    style == .accent
                    ? AnyShapeStyle(theme.currentAccentFill)
                    : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                    lineWidth: Theme.Strokes.strokeLineWidth
                )
                .opacity(style == .accent ? 0.55 : 1.0)
        )
    }
}

public struct MPCardBackLight: View { public var body: some View { MPCardBack(style: .light) } }
public struct MPCardBackAccent: View { public var body: some View { MPCardBack(style: .accent) } }

// MARK: - Two Columns Grid (left: phonetic, right: ru)
public struct MPMatchPairsGrid: View {
    public let left: [MPItem]      // side == .left, phonetic
    public let right: [MPItem]     // side == .right, ru
    public let selectedLeft: Int?  // index in left
    public let selectedRight: Int? // index in right
    public let leftTitle: String?
    public let rightTitle: String?
    public let onTapLeft: (Int) -> Void
    public let onTapRight: (Int) -> Void
    public let revealedIds: Set<String>?

    public init(left: [MPItem], right: [MPItem], selectedLeft: Int?, selectedRight: Int?, leftTitle: String? = nil, rightTitle: String? = nil, onTapLeft: @escaping (Int) -> Void, onTapRight: @escaping (Int) -> Void, revealedIds: Set<String>? = nil) {
        self.left = left; self.right = right
        self.selectedLeft = selectedLeft; self.selectedRight = selectedRight
        self.leftTitle = leftTitle; self.rightTitle = rightTitle
        self.onTapLeft = onTapLeft; self.onTapRight = onTapRight
        self.revealedIds = revealedIds
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                if let t = leftTitle, !t.isEmpty { header(t) }
                column(left, isLeft: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 6) {
                if let t = rightTitle, !t.isEmpty { header(t) }
                column(right, isLeft: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(CD.FontToken.caption())
            .tracking(0.5)
            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func column(_ items: [MPItem], isLeft: Bool) -> some View {
        // Few cards (error replay): keep a centered cluster.
        // Many cards: distribute evenly across height.
        let compact = items.count <= 3
        VStack(alignment: .center, spacing: compact ? 12 : 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, it in
                let isActive = (isLeft ? selectedLeft == idx : selectedRight == idx)
                MPFlipCard(
                    text: it.text,
                    isRevealed: (revealedIds?.contains(it.pairId) ?? (isActive || it.state == .matched || it.state == .wrong)),
                    state: it.state,
                    side: it.side,
                    backTitle: "taika",
                    hasAudio: it.hasAudio,
                    onPlay: nil
                )
                .contentShape(Rectangle())
                .onTapGesture { (isLeft ? onTapLeft(idx) : onTapRight(idx)) }

                if !compact, idx < items.count - 1 {
                    Spacer(minLength: 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: compact ? .center : .top)
    }
}

// MARK: - Compact progress bar (brand style)
fileprivate struct MPProgressBar: View {
    let value: Double   // 0...1
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(CD.ColorToken.card.opacity(0.9))
            GeometryReader { geo in
                let w = max(4, geo.size.width * value)
                Capsule()
                    .fill(LinearGradient(colors: [CD.ColorToken.accent, CD.ColorToken.accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w)
            }
        }
        .frame(height: 6)
        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Lightweight HUD used in DS previews / optional in host
fileprivate struct MPMatchHUD: View {
    let title: String
    let pairsDone: Int
    let total: Int
    let tries: Int
    @EnvironmentObject private var theme: ThemeManager
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            // centered title
            Text(title)
                .textCase(.lowercase)
                .font(CD.FontToken.title(24, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            // subtle inline hint (no capsule)
            HStack(spacing: 8) {
                Circle()
                    .foregroundStyle(theme.currentAccentFill)
                    .frame(width: 6, height: 6)
                Text("найди совпадения слева и справа")
                    .font(CD.FontToken.body(13, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.horizontal, 4)
        .padding(.bottom, 12)
    }
}

// MARK: - Game status strip (все игры: ход / таймер / очки)

/// Fixed 2-row status chrome — layout never jumps when score/mistakes change.
/// Colors: gold stars · gucci green correct · crimson mistakes.
public struct TaikaGameStatusStrip: View {
    public var timeText: String
    public var progressText: String?
    public var mistakes: Int
    /// Correct answers in the current session (not the global star wallet).
    public var score: Int
    /// When false, session score chip stays at 0 visually (still reserved).
    public var showsSessionScore: Bool
    /// When true, shows persistent star balance from `TaikaStarsStore`.
    public var showsStarWallet: Bool
    /// Hints opened by tapping the star chip (no separate hint chips).
    public var hints: [TaikaGameHintAction]

    @ObservedObject private var stars = TaikaStarsStore.shared

    public init(
        timeText: String,
        progressText: String? = nil,
        mistakes: Int = 0,
        score: Int = 0,
        showsSessionScore: Bool = true,
        showsStarWallet: Bool = true,
        hints: [TaikaGameHintAction] = []
    ) {
        self.timeText = timeText
        self.progressText = progressText
        self.mistakes = mistakes
        self.score = score
        self.showsSessionScore = showsSessionScore
        self.showsStarWallet = showsStarWallet
        self.hints = hints
    }

    private var trimmedProgress: String {
        guard let progress = progressText?.trimmingCharacters(in: .whitespacesAndNewlines), !progress.isEmpty else {
            return "—"
        }
        return progress
    }

    private var sessionScoreValue: Int {
        showsSessionScore ? max(0, score) : 0
    }

    private var availableHints: [TaikaGameHintAction] {
        hints.filter(\.isEnabled)
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                statusChip(icon: "timer", text: timeText, style: .neutral)

                statusChip(
                    icon: "list.number",
                    text: trimmedProgress,
                    style: .neutral
                )
                .opacity(progressText == nil ? 0.45 : 1)

                if showsStarWallet {
                    starWalletChip
                }
            }

            // Always reserved — prevents layout jump when first mistake / score appears.
            HStack(spacing: 8) {
                statusChip(
                    icon: "checkmark.circle.fill",
                    text: "\(sessionScoreValue)",
                    style: .correct,
                    dimmed: sessionScoreValue == 0
                )
                statusChip(
                    icon: "xmark.circle.fill",
                    text: "\(max(0, mistakes))",
                    style: .wrong,
                    dimmed: mistakes == 0
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var starWalletChip: some View {
        let chip = statusChip(
            icon: "star.fill",
            text: "\(stars.balance)",
            style: .gold,
            accessibilityLabel: availableHints.isEmpty
                ? "Звёзды: \(stars.balance)"
                : "Звёзды: \(stars.balance). Тап — подсказка"
        )

        if availableHints.isEmpty {
            chip
        } else if availableHints.count == 1, let only = availableHints.first {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                only.action()
            } label: {
                chip
            }
            .buttonStyle(.plain)
            .accessibilityHint("Активировать подсказку: \(only.title)")
        } else {
            Menu {
                ForEach(availableHints) { hint in
                    Button {
                        hint.action()
                    } label: {
                        Label("\(hint.title) · \(hint.cost)★", systemImage: "star.fill")
                    }
                }
            } label: {
                chip
            }
            .accessibilityHint("Открыть подсказки за звёзды")
        }
    }

    private enum ChipStyle {
        case neutral
        case gold
        case correct
        case wrong
    }

    private func statusChip(
        icon: String,
        text: String,
        style: ChipStyle,
        dimmed: Bool = false,
        accessibilityLabel: String? = nil
    ) -> some View {
        let palette = Self.palette(for: style)
        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.icon)
            Text(text)
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(palette.text)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.stroke, lineWidth: 1)
        )
        .opacity(dimmed ? 0.42 : 1)
        .accessibilityLabel(accessibilityLabel ?? text)
    }

    private struct ChipPalette {
        let icon: AnyShapeStyle
        let text: Color
        let fill: Color
        let stroke: Color
    }

    private static func palette(for style: ChipStyle) -> ChipPalette {
        switch style {
        case .neutral:
            return ChipPalette(
                icon: AnyShapeStyle(CD.ColorToken.text),
                text: CD.ColorToken.text,
                fill: CD.ColorToken.card.opacity(0.92),
                stroke: CD.ColorToken.stroke.opacity(0.4)
            )
        case .gold:
            return ChipPalette(
                icon: AnyShapeStyle(TaikaGoldStarGradient.fill),
                text: Color(red: 1.0, green: 0.86, blue: 0.42),
                fill: Color(red: 1.0, green: 0.78, blue: 0.22).opacity(0.16),
                stroke: Color(red: 0.98, green: 0.72, blue: 0.18).opacity(0.48)
            )
        case .correct:
            let green = TaikaMasteryTokens.green
            return ChipPalette(
                icon: AnyShapeStyle(green),
                text: green,
                fill: green.opacity(0.16),
                stroke: green.opacity(0.42)
            )
        case .wrong:
            let crimson = Color(red: 0.92, green: 0.22, blue: 0.38)
            return ChipPalette(
                icon: AnyShapeStyle(crimson),
                text: crimson,
                fill: crimson.opacity(0.16),
                stroke: crimson.opacity(0.42)
            )
        }
    }
}

/// Status strip — единый верхний chrome для всех игр (подсказки через тап по ★).
public struct TaikaGameTopChrome: View {
    public var timeText: String
    public var progressText: String?
    public var mistakes: Int
    public var score: Int
    public var showsSessionScore: Bool
    public var showsStarWallet: Bool
    public var hints: [TaikaGameHintAction]

    public init(
        timeText: String,
        progressText: String? = nil,
        mistakes: Int = 0,
        score: Int = 0,
        showsSessionScore: Bool = true,
        showsStarWallet: Bool = true,
        hints: [TaikaGameHintAction] = []
    ) {
        self.timeText = timeText
        self.progressText = progressText
        self.mistakes = mistakes
        self.score = score
        self.showsSessionScore = showsSessionScore
        self.showsStarWallet = showsStarWallet
        self.hints = hints
    }

    public var body: some View {
        TaikaGameStatusStrip(
            timeText: timeText,
            progressText: progressText,
            mistakes: mistakes,
            score: score,
            showsSessionScore: showsSessionScore,
            showsStarWallet: showsStarWallet,
            hints: hints
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Taika Stars UI (gold wallet + hint actions via ★)

public enum TaikaGoldStarGradient {
    public static var fill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.88, blue: 0.38),
                Color(red: 0.98, green: 0.72, blue: 0.18),
                Color(red: 0.92, green: 0.58, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var stroke: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                Color(red: 1.0, green: 0.82, blue: 0.35).opacity(0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

public struct TaikaGameHintAction: Identifiable {
    public let id: String
    public let title: String
    public let cost: Int
    public let isEnabled: Bool
    public let action: () -> Void

    public init(id: String, title: String, cost: Int, isEnabled: Bool, action: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.cost = cost
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// Legacy hint bar — kept for source compatibility; unused by top chrome.
public struct TaikaGameHintBar: View {
    public let hints: [TaikaGameHintAction]

    public init(hints: [TaikaGameHintAction]) {
        self.hints = hints
    }

    public var body: some View {
        EmptyView()
    }
}

public struct TaikaGameHintButton: View {
    public let title: String
    public let cost: Int
    public let isEnabled: Bool
    public let action: () -> Void

    public init(title: String, cost: Int, isEnabled: Bool, action: @escaping () -> Void) {
        self.title = title
        self.cost = cost
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        EmptyView()
    }
}

// MARK: - Canonical game chrome (как Speaker training)

enum TaikaGameCoverflowMetrics {
    /// 1:1 с `SpeakerTopCard` (268×196).
    static let cardW: CGFloat = 268
    static let cardH: CGFloat = 196
    static let peekStepFactor: CGFloat = 0.92
}

/// Карточка раунда в играх — тот же chrome/ритм, что у Speaker training.
struct TaikaGameSpeakerStyleCard: View {
    var lessonTitle: String?
    /// Главная строка (в спикере — транслит; в сборке — RU; в аудио — транслит).
    var hero: String
    /// Рендер hero через phonetic chrome (стрелки/тоны accent), как в спикере.
    var heroIsPhonetic: Bool = false
    /// Вторая строка (в спикере — RU).
    var secondary: String?
    /// Третья строка (в спикере — тайский footnote).
    var tertiary: String?
    var secondaryIsAccent: Bool = false
    var succeeded: Bool = false
    var successGlow: CGFloat = 0
    var showsPlayControl: Bool = false
    var playDisabled: Bool = true
    var onPlay: (() -> Void)? = nil

    private var brandAccent: AnyShapeStyle {
        AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CD.Radius.card, style: .continuous)
        let heroText = hero.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLong = heroText.count > 22
        let heroFont: Font = isLong
            ? .system(size: 17, weight: .semibold)
            : .system(size: 20, weight: .semibold)
        let secondaryText = (secondary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let tertiaryText = (tertiary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("taikA")
                    .font(.custom("ONMARK Trial", size: 14))
                    .tracking(0.6)
                    .foregroundStyle(CD.ColorToken.text)
                Spacer(minLength: 0)
                if let lessonTitle, !lessonTitle.isEmpty {
                    TaikaGameLessonPill(title: lessonTitle)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if heroText.isEmpty {
                        Text("—")
                            .font(heroFont)
                            .foregroundStyle(CD.ColorToken.textSecondary)
                    } else if heroIsPhonetic {
                        TaikaPhoneticText.styled(heroText, font: heroFont)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(heroText)
                            .font(heroFont)
                            .foregroundStyle(CD.ColorToken.text)
                    }
                }
                .lineLimit(2)
                .allowsTightening(true)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(heroText.isEmpty ? 0.45 : 1)
                .padding(.bottom, 2)

                if !secondaryText.isEmpty {
                    Text(secondaryText)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(
                            secondaryIsAccent
                            ? brandAccent
                            : AnyShapeStyle(Theme.Colors.textPrimary)
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.80)
                        .padding(.top, 4)
                }

                if !tertiaryText.isEmpty {
                    Text(tertiaryText)
                        .font(.footnote)
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .opacity(0.86)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            if showsPlayControl {
                HStack {
                    TaikaGameBareSpeakerButton(
                        disabled: playDisabled,
                        action: { onPlay?() }
                    )
                    Spacer(minLength: 0)
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(
            width: TaikaGameCoverflowMetrics.cardW,
            height: TaikaGameCoverflowMetrics.cardH,
            alignment: .topLeading
        )
        .background(Theme.Surfaces.card(shape))
        .overlay {
            if succeeded {
                shape.stroke(brandAccent, lineWidth: 2)
            }
        }
        .shadow(
            color: succeeded
            ? ThemeManager.shared.currentAccentTintColor.opacity(0.28 * successGlow)
            : .clear,
            radius: succeeded ? 14 : 0,
            y: succeeded ? 4 : 0
        )
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroText.isEmpty ? "Карточка" : heroText)
    }
}

/// Outline-капсула урока — как на карточке Спикера.
struct TaikaGameLessonPill: View {
    let title: String

    var body: some View {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(t)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(ThemeManager.shared.currentAccentFill)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule(style: .continuous).fill(Color.clear))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(ThemeManager.shared.currentAccentFill, lineWidth: 1.2)
            )
        }
    }
}

/// Динамик без кружка — меньше визуального шума.
struct TaikaGameBareSpeakerButton: View {
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel("Прослушать")
    }
}

// MARK: - Memory game prompt (игры 2–3: без StepWordCard, фокус на задании)

public enum TaikaGameMemoryPromptMode {
    /// Сборка: крупно RU, тайский приглушённо, транскрипция после успеха.
    case buildFromMeaning
    /// Аудио-квиз: крупно тайский + кнопка прослушивания.
    case listenAndPick
}

public struct TaikaGameMemoryPrompt: View {
    public var mode: TaikaGameMemoryPromptMode
    public var title: String
    public var subtitle: String?
    public var phonetic: String?
    public var playLabel: String?
    public var isListening: Bool
    public var compact: Bool
    /// Показывать мелкий meta-лейбл («ПЕРЕВОД» / «СЛУШАЙ»). В играх обычно выключаем — меньше слов.
    public var showsMetaLabel: Bool
    public var onPlay: (() -> Void)?

    public init(
        mode: TaikaGameMemoryPromptMode,
        title: String,
        subtitle: String? = nil,
        phonetic: String? = nil,
        playLabel: String? = nil,
        isListening: Bool = false,
        compact: Bool = false,
        showsMetaLabel: Bool = false,
        onPlay: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.title = title
        self.subtitle = subtitle
        self.phonetic = phonetic
        self.playLabel = playLabel
        self.isListening = isListening
        self.compact = compact
        self.showsMetaLabel = showsMetaLabel
        self.onPlay = onPlay
    }

    public var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            if mode == .listenAndPick {
                listenBody
            } else {
                buildBody
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var buildBody: some View {
        let thai = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let ru = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if showsMetaLabel {
            promptMetaLabel("ПЕРЕВОД")
        }

        Text(ru.isEmpty ? "—" : ru)
            .font(.system(size: compact ? 22 : 28, weight: .semibold))
            .foregroundStyle(CD.ColorToken.text)
            .multilineTextAlignment(.center)
            .lineLimit(compact ? 2 : 2)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)

        if !thai.isEmpty {
            Text(thai)
                .font(.system(size: compact ? 14 : 16, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineLimit(compact ? 1 : 2)
                .minimumScaleFactor(0.85)
        }

        if let line = phonetic?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
            Text(line)
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill.opacity(0.92))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }

        if onPlay != nil {
            playControl
                .scaleEffect(compact ? 0.92 : 1, anchor: .center)
        }
    }

    @ViewBuilder
    private var listenBody: some View {
        let thai = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if showsMetaLabel {
            promptMetaLabel("СЛУШАЙ")
        }

        if !thai.isEmpty {
            Text(thai)
                .font(.system(size: compact ? 32 : 38, weight: .semibold))
                .foregroundStyle(CD.ColorToken.text)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 8)
        }

        if onPlay != nil {
            playControl
        }
    }

    @ViewBuilder
    private var playControl: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onPlay?()
        } label: {
            TaikaHeaderGlassPill(height: 42, horizontalPadding: playLabel == nil ? 0 : 14) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                    if let playLabel, !playLabel.isEmpty {
                        Text(playLabel)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(CD.ColorToken.text)
                .frame(width: playLabel == nil ? 40 : nil)
            }
            .overlay {
                if isListening {
                    Capsule(style: .continuous)
                        .stroke(ThemeManager.shared.currentAccentTintColor.opacity(0.55), lineWidth: 1.2)
                }
            }
        }
        .buttonStyle(TaikaHeaderButtonStyle())
        .disabled(onPlay == nil)
        .padding(.top, 2)
    }

    private func promptMetaLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: compact ? 11 : 12, weight: .semibold))
            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.74))
            .textCase(.uppercase)
            .tracking(0.4)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

#if DEBUG

/// Interactive DS playground (no business logic) — tap to preview visual states
struct MPMatchPairs_Playground: View {
    @State private var leftItems: [MPItem]
    @State private var rightItems: [MPItem]
    @State private var selL: Int? = nil
    @State private var selR: Int? = nil

    init() {
        let sample: [(String,String,String)] = [
            ("pŏm", "Я", "pair1"),
            ("kun", "ты", "pair2"),
            ("káo", "он", "pair3"),
            ("chán", "я (жен.)", "pair4"),
            ("rao", "мы", "pair5"),
            ("kun-táo", "вы", "pair6")
        ]
        let left = sample.map { MPItem(pairId: $0.2, text: $0.0, side: .left, hasAudio: true) }
        let right = sample.map { MPItem(pairId: $0.2, text: $0.1, side: .right) }
        _leftItems = State(initialValue: Array(left.prefix(5)))
        _rightItems = State(initialValue: Array(right.prefix(5)))
    }

    var body: some View {
        TaikaRootVerticalScroll {
            VStack(spacing: 16) {
                MPMatchHUD(title: "подобрать пару", pairsDone: 0, total: 0, tries: 0)
                HStack(spacing: 20) {
                    MPCardBack(style: .light)
                    MPCardBack(style: .accent)
                }
                .padding(.bottom, 8)
                MPMatchPairsGrid(
                    left: leftItems,
                    right: rightItems,
                    selectedLeft: selL,
                    selectedRight: selR,
                    leftTitle: "транслит",
                    rightTitle: "перевод",
                    onTapLeft: { onTapLeft($0) },
                    onTapRight: { onTapRight($0) }
                )
                .frame(maxHeight: 560)
                .padding(.top, 24)
            }
            .padding(20)
        }
        .background(CD.ColorToken.background)
    }

    private func onTapLeft(_ i: Int) {
        if let p = selL { leftItems[p].state = .idle }
        selL = i
        leftItems[i].state = .selected
        resolve()
    }

    private func onTapRight(_ j: Int) {
        if let p = selR { rightItems[p].state = .idle }
        selR = j
        rightItems[j].state = .selected
        resolve()
    }

    private func resolve() {
        guard let li = selL, let rj = selR else { return }
        if leftItems[li].pairId == rightItems[rj].pairId {
            leftItems[li].state = .matched
            rightItems[rj].state = .matched
            selL = nil; selR = nil
        } else {
            leftItems[li].state = .wrong
            rightItems[rj].state = .wrong
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                leftItems[li].state = .idle
                rightItems[rj].state = .idle
                selL = nil; selR = nil
            }
        }
    }
}

struct MPMatchPairs_Previews: PreviewProvider {
    static var previews: some View {
        MPMatchPairs_Playground().environmentObject(ThemeManager.shared)
    }
}
#endif
