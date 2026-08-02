// MARK: - Step Progress Segment (single capsule)
public struct SDStepProgressSegment: View {
    public var width: CGFloat
    public var isActive: Bool
    public var isLearned: Bool
    public var isFavorite: Bool
    public var isPro: Bool
    public var index: Int?
    public var onTap: ((Int) -> Void)?

    public init(width: CGFloat,
                isActive: Bool,
                isLearned: Bool,
                isFavorite: Bool,
                isPro: Bool = false,
                index: Int? = nil,
                onTap: ((Int) -> Void)? = nil) {
        self.width = width
        self.isActive = isActive
        self.isLearned = isLearned
        self.isFavorite = isFavorite
        self.isPro = isPro
        self.index = index
        self.onTap = onTap
    }

    public var body: some View {
        let base = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return ZStack {
            base
                .fill(AnyShapeStyle(.ultraThinMaterial.opacity(0.10)))
                .frame(width: width, height: 36)
                .overlay(
                    base.stroke(
                        isActive
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.85))
                        : AnyShapeStyle(PD.ColorToken.stroke.opacity(0.7)),
                        lineWidth: isActive ? 1.5 : 1
                    )
                )

            base
                .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .frame(width: width, height: 36)
                .mask(
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .frame(height: isLearned ? geo.size.height : 0)
                        }
                    }
                )
                .opacity(isLearned ? 1 : 0)

            if isFavorite {
                Group {
                    if isLearned {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(PD.ColorToken.card)
                    } else {
                        GradientIcon(systemName: "heart.fill", size: 12)
                    }
                }
                .opacity(0.95)
                .allowsHitTesting(false)
            }
            if isPro {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.background)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: 36)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: isLearned)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isActive)
        .animation(.easeOut(duration: 0.18), value: isFavorite)
        .onTapGesture {
            if let idx = index {
                onTap?(idx)
            }
        }
    }
}
//
//  StepDS.swift
//  taika
//
//  Design System for STEP (lesson content) cards & carousels
//  Visual-only layer: no networking/state here – just views & light models.

import SwiftUI
import UIKit

// MARK: - Model
public struct SDStepItem: Identifiable, Hashable {
    public enum Kind: String, CaseIterable, Hashable {
        case intro, word, phrase, tip, casual, summary
    }
    public let id: UUID
    public var kind: Kind
    public var titleRU: String            // «слово / фраза» на русском
    public var subtitleTH: String         // тайский / латиницей
    public var phonetic: String           // руссифицированная транскрипция по слогам
    /// Канонический `order` из steps.json (для Progress/Speaker). -1 если неизвестен.
    public var canonicalOrder: Int
    public var metaLearned: Int?
    public var metaFavorites: Int?
    public var isFavorite: Bool
    public var isLearned: Bool
    public var isPro: Bool

    public init(
        id: UUID = .init(),
        kind: Kind,
        titleRU: String,
        subtitleTH: String,
        phonetic: String,
        canonicalOrder: Int = -1,
        metaLearned: Int? = nil,
        metaFavorites: Int? = nil,
        isFavorite: Bool = false,
        isLearned: Bool = false,
        isPro: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.titleRU = titleRU
        self.subtitleTH = subtitleTH
        self.phonetic = phonetic
        self.canonicalOrder = canonicalOrder
        self.metaLearned = metaLearned
        self.metaFavorites = metaFavorites
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.isPro = isPro
    }
}

extension SDStepItem {
    var visualKind: Kind {
        // визуальный тип теперь напрямую следует за kind из json:
        // word / phrase / casual / tip / intro / summary
        // без эвристик по количеству слов в titleRU
        return kind
    }
}


// MARK: - Tag chip (тип карточки)

// Shared accent gradient (matches Lessons / Favorites)
fileprivate var AccentGradient: LinearGradient {
    LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.52, blue: 0.80),
            Color(red: 0.91, green: 0.62, blue: 0.98)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// Gradient helpers for icons/text

/// Фразы — квадрат; лайфхаки — вертикальный портрет.
fileprivate func stepCardSize(for kind: SDStepItem.Kind) -> CGSize {
    switch kind {
    case .tip:
        return CGSize(
            width: CardDS.Metrics.stepLifehackWidth,
            height: CardDS.Metrics.stepLifehackHeight
        )
    case .word, .phrase, .casual, .intro, .summary:
        let s = CardDS.Metrics.stepCarouselSquareSide
        return CGSize(width: s, height: s)
    }
}

fileprivate struct GradientIcon: View {
    var systemName: String
    var size: CGFloat = 18
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(ThemeManager.shared.currentAccentFill)
    }
}
fileprivate struct GradientStrokeCapsule: View {
    var body: some View {
        Capsule(style: .continuous)
            .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1)
    }
}

// MARK: - like micro-animations
// gradient sweep that fills heart from left → right (brief)
fileprivate struct SDFavSweepFill: View {
    var trigger: Bool
    @State private var progress: CGFloat = 0
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: 34 * max(progress, 0.001), height: 32)
            .clipped()
            .mask(Image(systemName: "heart.fill").font(.system(size: 18, weight: .semibold)))
            .opacity(progress > 0 ? 1 : 0)
        }
        .frame(width: 34, height: 32)
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, on in
            guard on else { return }
            progress = 0
            withAnimation(.easeOut(duration: 0.18)) { progress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { progress = 0 }
        }
    }
}

// thin halo ring (no glow) expands and fades
fileprivate struct SDFavHaloRing: View {
    var trigger: Bool
    @State private var scale: CGFloat = 0.3
    @State private var alpha: CGFloat = 0.0
    var body: some View {
        Circle()
            .stroke(LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .leading, endPoint: .trailing), lineWidth: 1)
            .frame(width: 36, height: 36)
            .scaleEffect(scale)
            .opacity(alpha)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, on in
                guard on else { return }
                scale = 0.3; alpha = 0.35
                withAnimation(.easeOut(duration: 0.20)) { scale = 1.30; alpha = 0.0 }
            }
    }
}

// slow minimal pulse wave (single ring)
fileprivate struct SDFavPulseWave: View {
    var trigger: Bool
    @State private var scale: CGFloat = 0.9
    @State private var alpha: CGFloat = 0.0
    var body: some View {
        Circle()
            .stroke(LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .leading, endPoint: .trailing), lineWidth: 1)
            .frame(width: 42, height: 42)
            .scaleEffect(scale)
            .opacity(alpha)
            .blur(radius: 0.5)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, on in
                guard on else { return }
                scale = 0.92; alpha = 0.20
                withAnimation(.easeOut(duration: 0.50)) {
                    scale = 1.50; alpha = 0.0
                }
            }
    }
}

// tiny check flash — appears briefly when item is liked (yandex‑style feedback)
fileprivate struct SDTickFlash: View {
    var trigger: Bool
    @State private var show: Bool = false
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .leading, endPoint: .trailing))
            .scaleEffect(show ? 1.0 : 0.86)
            .opacity(show ? 0.95 : 0.0)
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, on in
                guard on else { return }
                show = false
                withAnimation(.easeOut(duration: 0.10)) { show = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeOut(duration: 0.10)) { show = false }
                }
            }
    }
}

// big like flash — moderate, calm Yandex‑style heart (centered, subtle)
fileprivate struct SDBigLikeFlash: View {
    var trigger: Bool
    @State private var scale: CGFloat = 0.92
    @State private var alpha: CGFloat = 0.0
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.98, green: 0.52, blue: 0.80),
                Color(red: 0.91, green: 0.62, blue: 0.98)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .mask(
                Image(systemName: "heart.fill")
                    .font(.system(size: 180, weight: .semibold))
            )
            .opacity(alpha)
            .scaleEffect(scale)
            .blur(radius: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, on in
            guard on else { return }
            // gentle breathe: 0.92 → 1.08 → 1.00 and fade
            scale = 0.92; alpha = 0.0
            withAnimation(.easeOut(duration: 0.22)) { scale = 1.08; alpha = 0.22 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeOut(duration: 0.18)) { scale = 1.00; alpha = 0.18 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                withAnimation(.easeOut(duration: 0.16)) { alpha = 0.0 }
            }
        }
    }
}

// Helper: build styled Text with stressed syllable (accent) highlighted
// Helper: build styled Text with stressed syllable (accent) highlighted
fileprivate func phoneticStyledText(_ s: String) -> Text {
    // всё, что без ударения — базовый светлый текст;
    // слог (кусок между пробелами/дефисами), внутри которого есть диакритика,
    // подсвечиваем целиком акцентным градиентом.
    let accentScalars: Set<UnicodeScalar> = [
        // acute
        UnicodeScalar(0x0301)!, // COMBINING ACUTE ACCENT
        UnicodeScalar(0x00B4)!, // ACUTE ACCENT (spacing)
        UnicodeScalar(0x02CA)!, // MODIFIER LETTER ACUTE ACCENT
        // grave
        UnicodeScalar(0x0300)!, // COMBINING GRAVE ACCENT
        UnicodeScalar(0x02CB)!, // MODIFIER LETTER GRAVE ACCENT
        // circumflex
        UnicodeScalar(0x0302)!, // COMBINING CIRCUMFLEX ACCENT
        UnicodeScalar(0x02C6)!, // MODIFIER LETTER CIRCUMFLEX ACCENT
        // breve
        UnicodeScalar(0x0306)!, // COMBINING BREVE
        UnicodeScalar(0x02D8)!, // BREVE (spacing)
        // caron
        UnicodeScalar(0x030C)!, // COMBINING CARON
        UnicodeScalar(0x02C7)!  // CARON (modifier)
    ]

    func chunkHasAccent(_ chunk: String) -> Bool {
        chunk.unicodeScalars.contains { accentScalars.contains($0) }
    }

    // быстрый путь: если нет ни одного ударения — просто базовый светлый текст
    guard s.unicodeScalars.contains(where: { accentScalars.contains($0) }) else {
        return Text(s).foregroundStyle(PD.ColorToken.text)
    }

    // слогами считаем куски между пробелами и дефисами
    let separators: Set<Character> = [" ", "-", "·"]

    var result = Text("")
    var currentChunk = ""
    var currentSeparator: Character? = nil

    func flushChunk() {
        guard !currentChunk.isEmpty else { return }
        let isAccentChunk = chunkHasAccent(currentChunk)
        let base = Text(currentChunk)
        if isAccentChunk {
            result = result + base.foregroundStyle(ThemeManager.shared.currentAccentFill)
        } else {
            result = result + base.foregroundStyle(PD.ColorToken.text)
        }
        currentChunk = ""
    }

    for ch in s {
        if separators.contains(ch) {
            // сначала выкидываем накопленный слог
            flushChunk()
            // сам разделитель добавляем базовым светлым цветом
            let sepText = Text(String(ch))
                .foregroundStyle(PD.ColorToken.text)
            result = result + sepText
            currentSeparator = ch
        } else {
            currentSeparator = nil
            currentChunk.append(ch)
        }
    }
    // последний слог
    flushChunk()

    return result
}


// MARK: - Step card
// (StepWordCardVisual removed)

/// Step Card for displaying a learning item. Supports active glow state.
public struct SDStepCard: View {
    /// Whether this card is currently active/selected (shows glow, no white stroke)
    public var isActive: Bool = false
    public var isReadOnly: Bool = false
    public var isOverlay: Bool = false
    // Unified typography for learning cards (word/phrase/casual)
    private let TITLE_FONT: Font      = .taikaTitle(28)                      // main RU word/phrase
    private let PHON_FONT: Font       = .system(size: 18, weight: .semibold) // phonetic line (accented)
    private let THAI_FONT: Font       = .system(size: 20, weight: .regular)  // thai line
    // Typography for tips (лайфхаки)
    private let TIP_TITLE_FONT  = PD.FontToken.body(18, weight: .semibold)
    private let TIP_BODY_FONT   = PD.FontToken.body(15, weight: .regular)
    private let LINES_SPACING: CGFloat = 3
    public var item: SDStepItem
    public var onTap: ()->Void
    public var onPlay: ()->Void
    public var onToggleFavorite: ()->Void
    public var onMarkLearned: ()->Void
    public var onNext: ()->Void

    // Injectables to allow custom visuals from StepIntroSum
    private var introContentBuilder: () -> AnyView
    private var summaryContentBuilder: () -> AnyView
    private var introBarBuilder: () -> AnyView
    private var summaryBarBuilder: () -> AnyView

    @State private var favPulse: Bool = false
    @State private var playPulse: Bool = false
    @State private var nextPulse: Bool = false
    @State private var donePulse: Bool = false
    @State private var isFav: Bool = false
    @State private var denyPulse: Bool = false
    @State private var likeAnim: Bool = false
    @State private var unlikeAnim: Bool = false
    @State private var bigLike: Bool = false
    private var isLearned: Bool

    /// Лайфхак: `tip` → заголовок (`titleRU`); `text` → тело (`subtitleTH`).
    /// Тело может начинаться с заголовка через `\n\n` (legacy) — тогда берём его из текста.
    private static func lifehackHeadlineAndBody(from item: SDStepItem) -> (headline: String?, body: String) {
        let tipTitle = item.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
        let genericTitles: Set<String> = ["лайфхак", "лайфхаки", "сцена"]
        let hasRealTitle = !tipTitle.isEmpty && !genericTitles.contains(tipTitle.lowercased())

        let raw = (item.subtitleTH.isEmpty ? item.titleRU : item.subtitleTH)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return (nil, " ") }

        let paragraphs = raw.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if paragraphs.count >= 2 {
            return (paragraphs[0], paragraphs.dropFirst().joined(separator: "\n\n"))
        }

        if let nl = raw.firstIndex(of: "\n") {
            let h = String(raw[..<nl]).trimmingCharacters(in: .whitespacesAndNewlines)
            let b = String(raw[raw.index(after: nl)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if h.count <= 88, !b.isEmpty { return (h, b) }
        }

        if hasRealTitle {
            return (tipTitle, raw)
        }

        return (nil, raw)
    }

    private func splitSubtitle(_ raw: String) -> (thai: String, latin: String) {
        // Expected formats: "ขอบคุณ (kh̄xbkhuṇ)" or just "ขอบคุณ"
        if let open = raw.firstIndex(of: "("), let close = raw.lastIndex(of: ")"), open < close {
            let thai = raw[..<open].trimmingCharacters(in: .whitespaces)
            let latin = raw[raw.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
            return (String(thai), String(latin))
        } else {
            return (raw, raw)
        }
    }

    public init(
        item: SDStepItem,
        onTap: @escaping ()->Void = {},
        onPlay: @escaping ()->Void = {},
        onToggleFavorite: @escaping ()->Void = {},
        onMarkLearned: @escaping ()->Void = {},
        onNext: @escaping ()->Void = {},
        initialLearned: Bool = false,
        introContent: (() -> AnyView)? = nil,
        summaryContent: (() -> AnyView)? = nil,
        introCTA:   (() -> AnyView)? = nil,
        summaryCTA: (() -> AnyView)? = nil,
        isReadOnly: Bool = false,
        isOverlay: Bool = false,
        isActive: Bool = false
    ) {
        self.item = item
        self.onTap = onTap
        self.onPlay = onPlay
        self.onToggleFavorite = onToggleFavorite
        self.onMarkLearned = onMarkLearned
        self.onNext = onNext
        // Fallbacks are defined here, so we can safely use private/internal helpers
        self.introContentBuilder   = introContent   ?? { AnyView(_IntroPlaceholder()) }
        self.summaryContentBuilder = summaryContent ?? { AnyView(_SummaryPlaceholder()) }
        self.introBarBuilder       = introCTA       ?? { AnyView(SDStepCard.defaultIntroActionBar()) }
        self.summaryBarBuilder     = summaryCTA     ?? { AnyView(SDStepCard.defaultSummaryActionBar()) }
        self._isFav = State(initialValue: item.isFavorite)
        self.isLearned = initialLearned
        self.isActive = isActive
        self.isOverlay = isOverlay
        self.isReadOnly = isReadOnly
    }

    public var body: some View {
        let vkOuter = item.visualKind
        let cardSize = stepCardSize(for: vkOuter)

        // строим готовую карточку из CardDS и сразу прокидываем всю логику CTA внутрь
        let cardView: AnyView = {
            switch vkOuter {
            case .tip:
                let hb = Self.lifehackHeadlineAndBody(from: item)
                return AnyView(
                    StepLifehackCardLegacy(
                        headline: hb.headline,
                        body: hb.body,
                        label: labelFor(item: item),
                        size: cardSize,
                        sectionChrome: .seps,
                        chromeStyle: .cards,
                        isFavorite: isFav,
                        onFavorite: {
                            onToggleFavorite()
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            favPulse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { favPulse = false }
                        },
                        onNext: {
                            onNext()
                            nextPulse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { nextPulse = false }
                        }
                    )
                )

            default:
                if item.isPro {
                    return AnyView(
                        StepProTeaserCard(
                            title: item.titleRU.isEmpty ? "ещё 5 карточек" : item.titleRU,
                            subtitle: {
                                let th = item.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !th.isEmpty { return th }
                                let ph = item.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
                                return ph.isEmpty ? "расширь разминку с Taika+" : ph
                            }(),
                            ctaTitle: "открыть Taika+",
                            size: cardSize,
                            onOpen: onTap
                        )
                    )
                }

                return AnyView(
                    StepWordCard(
                        title: item.titleRU,
                        translit: item.phonetic,
                        thai: splitSubtitle(item.subtitleTH).thai,
                        label: labelFor(item: item),
                        size: cardSize,
                        sectionChrome: .seps,
                        chromeStyle: .cards,
                        isFavorite: isFav,
                        isLearned: isLearned,
                        allowLearn: !isReadOnly,
                        onPlay: {
                            playPulse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { playPulse = false }
                            onPlay()
                        },
                        onFavorite: {
                            onToggleFavorite()
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            favPulse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { favPulse = false }
                        },
                        onLearn: {
                            if isReadOnly {
                                denyFeedback()
                            } else {
                                onMarkLearned()
                                donePulse = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { donePulse = false }
                            }
                        }
                    )
                )
            }
        }()

        return cardView
            .frame(width: cardSize.width, height: cardSize.height)
            .contentShape(RoundedRectangle(cornerRadius: CardDS.Metrics.stepCardContentRadius, style: .continuous))
            .onTapGesture {
                onTap()
            }
            .animation(.none, value: isLearned)
            .animation(.none, value: isFav)
            .transaction { $0.animation = nil }
            .onAppear { isFav = item.isFavorite }
            .onChange(of: item.id) { _, _ in isFav = item.isFavorite }
            .onChange(of: item.isFavorite) { _, newValue in isFav = newValue }
    }



    private func labelFor(item: SDStepItem) -> String {
        if item.isPro { return "pro" }
        switch item.visualKind {
        case .intro: return "Старт"
        case .word: return "Слово"
        case .phrase: return "Фраза"
        case .tip: return "Лайфхак"
        case .casual: return "Сленг"
        case .summary: return "Итоги"
        }
    }


    private func styledPhonetic(_ s: String) -> some View {
        phoneticStyledText(s)
            .font(PHON_FONT)
            .multilineTextAlignment(.center)
    }


    private func denyFeedback() {
        // Rigid haptic + tiny bounce to indicate non-interactive in overlay
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            denyPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                denyPulse = false
            }
        }
    }

    // MARK: - New Action Bars for Intro and Summary
    static func defaultIntroActionBar() -> some View {
        ZStack(alignment: .trailing) {
            Capsule(style: .continuous)
                .fill(Color.clear)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1)
                )

            Button(action: { }) {
                GradientIcon(systemName: "chevron.right", size: 18)
                    .frame(width: 34, height: 32)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .contentShape(Rectangle())
    }

    static func defaultSummaryActionBar() -> some View {
        HStack(spacing: 0) {
            Button(action: { }) {
                GradientIcon(systemName: "doc.text", size: 18)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: { }) {
                GradientIcon(systemName: "chevron.right", size: 18)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.clear)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .contentShape(Rectangle())
    }

    private func builtIntroActionBar() -> AnyView { introBarBuilder() }
    private func builtSummaryActionBar() -> AnyView { summaryBarBuilder() }
}

// Local placeholders to keep DS self-contained when StepIntroSum is not linked.
private struct _IntroPlaceholder: View {
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Image("mascot.step")
                .resizable()
                .scaledToFit()
                .frame(height: 88)
                .opacity(0.75)
                .taikaMascotChrome()
            Text("Вступление")
                .font(PD.FontToken.body(18, weight: .semibold))
                .foregroundColor(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct _SummaryPlaceholder: View {
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Image("mascot.step")
                .resizable()
                .scaledToFit()
                .frame(height: 88)
                .opacity(0.75)
            Text("Итоги урока")
                .font(PD.FontToken.body(18, weight: .semibold))
                .foregroundColor(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// Helper for detecting which step card is closest to center in the carousel
// MARK: - Carousel (горизонтальная) — coverflow как Спикер (без ScrollView)
public struct SDStepCarousel: View {
    public var title: String
    public var items: [SDStepItem]
    @Binding public var activeIndex: Int
    public var subtitle: String?
    public var learned: Set<Int>
    public var favorites: Set<Int>
    public var onTap: (SDStepItem)->Void
    public var onPlay: (SDStepItem)->Void
    public var onFav: (SDStepItem)->Void
    public var onDone: (SDStepItem)->Void
    public var onActiveIndexChange: ((Int) -> Void)?
    public var onNext: (SDStepItem) -> Void
    public var onFavAt: ((Int, SDStepItem) -> Void)?
    public var onDoneAt: ((Int, SDStepItem) -> Void)?
    // Optional builders injected from StepIntroSum to avoid DS hard dependency
    public var introContentView: (() -> AnyView)?
    public var summaryContentView: (() -> AnyView)?
    public var introCTAView: (() -> AnyView)?
    public var summaryCTAView: (() -> AnyView)?
    public var isOverlay: Bool
    public var allowLearning: Bool
    /// When true, carousel scrolls cyclically (triple indices, start in middle block) like CDLessonCarousel — for разминка.
    public var loop: Bool
    /// Когда true — без вертикального паддинга секции (как Продолжить/Подборка дня на Main).
    public var compactSection: Bool

    public init(
        title: String,
        items: [SDStepItem],
        activeIndex: Binding<Int>,
        subtitle: String? = nil,
        learned: Set<Int> = [],
        favorites: Set<Int> = [],
        onTap: @escaping (SDStepItem)->Void = {_ in},
        onPlay: @escaping (SDStepItem)->Void = {_ in},
        onFav: @escaping (SDStepItem)->Void = {_ in},
        onDone: @escaping (SDStepItem)->Void = {_ in},
        onActiveIndexChange: ((Int) -> Void)? = nil,
        onNext: @escaping (SDStepItem) -> Void = { _ in },
        onFavAt: ((Int, SDStepItem) -> Void)? = nil,
        onDoneAt: ((Int, SDStepItem) -> Void)? = nil,
        introContentView: (() -> AnyView)? = nil,
        summaryContentView: (() -> AnyView)? = nil,
        introCTAView: (() -> AnyView)? = nil,
        summaryCTAView: (() -> AnyView)? = nil,
        isOverlay: Bool = false,
        allowLearning: Bool = true,
        loop: Bool = false,
        compactSection: Bool = false
    ) {
        self.title = title
        self.items = items
        self._activeIndex = activeIndex
        self.subtitle = subtitle
        self.learned = learned
        self.favorites = favorites
        self.onTap = onTap
        self.onPlay = onPlay
        self.onFav = onFav
        self.onDone = onDone
        self.onActiveIndexChange = onActiveIndexChange
        self.onNext = onNext
        self.onFavAt = onFavAt
        self.onDoneAt = onDoneAt
        self.introContentView = introContentView
        self.summaryContentView = summaryContentView
        self.introCTAView = introCTAView
        self.summaryCTAView = summaryCTAView
        self.isOverlay = isOverlay
        self.allowLearning = allowLearning
        self.loop = loop
        self.compactSection = compactSection
    }

    public var body: some View {
        let tipsOnly = !items.isEmpty && items.allSatisfy { $0.kind == .tip }
        let itemW = tipsOnly ? CardDS.Metrics.stepLifehackWidth : CardDS.Metrics.stepCarouselSquareSide
        let itemH = tipsOnly ? CardDS.Metrics.stepLifehackHeight : CardDS.Metrics.stepCarouselSquareSide
        let slotHeight = itemH + (compactSection ? 28 : 36)
        return VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                header
            }
            coverflowCarousel(itemW: itemW, itemH: itemH)
                .frame(height: slotHeight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compactSection ? 0 : Theme.Layout.carouselVPad)
        }
    }

    /// Coverflow: фразы — привычный 3D; лайфхаки — спокойнее и центрированнее (презентационный фокус).
    @ViewBuilder
    private func coverflowCarousel(itemW: CGFloat, itemH: CGFloat) -> some View {
        let currentIndex = min(max(0, activeIndex), max(0, items.count - 1))
        let tipsOnly = !items.isEmpty && items.allSatisfy { $0.kind == .tip }
        let sideScale: CGFloat = tipsOnly ? 0.90 : 0.82
        let yaw: Double = tipsOnly ? -8 : -14
        let stepX = itemW * (tipsOnly ? 0.78 : 0.88)
        let sideOpacity: Double = tipsOnly ? 0.38 : 0.45

        ZStack {
            ForEach(Array(items.indices), id: \.self) { index in
                let rel = index - currentIndex
                let item = items[index]
                let isFav = favorites.contains(index)
                let effective = withFavorite(item, fav: isFav)

                stepCardBody(for: effective, idx: index)
                    .frame(width: itemW, height: itemH)
                    .scaleEffect(rel == 0 ? 1.0 : sideScale)
                    .rotation3DEffect(
                        .degrees(Double(rel) * yaw),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: tipsOnly ? 0.55 : 0.7
                    )
                    .opacity(abs(rel) > 2 ? 0 : (rel == 0 ? 1.0 : sideOpacity))
                    .offset(x: CGFloat(rel) * stepX)
                    .zIndex(rel == 0 ? 10 : Double(10 - abs(rel)))
                    .allowsHitTesting(abs(rel) <= 1)
                    .onTapGesture {
                        guard index != currentIndex else { return }
                        selectIndex(index)
                    }
            }
        }
        .frame(height: itemH + (tipsOnly ? 20 : 12))
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 48, abs(dx) > abs(dy) * 1.15 else { return }
                    if dx < 0 {
                        goNext()
                    } else {
                        goPrev()
                    }
                }
        )
        .animation(.easeInOut(duration: 0.35), value: currentIndex)
        .id(isOverlay ? "overlayCarousel" : "stepsCarousel")
    }

    private func selectIndex(_ index: Int) {
        guard items.indices.contains(index) else { return }
        guard index != activeIndex else { return }
        activeIndex = index
        onActiveIndexChange?(index)
        onTap(items[index])
    }

    private func goNext() {
        guard !items.isEmpty else { return }
        if activeIndex + 1 < items.count {
            let next = activeIndex + 1
            activeIndex = next
            onActiveIndexChange?(next)
            // Не вызываем onNext: родительский handleNextItem тоже делает +1 → прыжок через карточку.
        } else if loop, items.count > 1 {
            activeIndex = 0
            onActiveIndexChange?(0)
        }
    }

    private func goPrev() {
        guard !items.isEmpty else { return }
        if activeIndex > 0 {
            let prev = activeIndex - 1
            activeIndex = prev
            onActiveIndexChange?(prev)
        } else if loop, items.count > 1 {
            let last = items.count - 1
            activeIndex = last
            onActiveIndexChange?(last)
        }
    }

    private func withFavorite(_ item: SDStepItem, fav: Bool) -> SDStepItem {
        var c = item
        c.isFavorite = fav || item.isFavorite
        return c
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("УРОК")
                .font(PD.FontToken.caption(12, weight: .medium))
                .foregroundColor(PD.ColorToken.textSecondary.opacity(0.9))

            Spacer(minLength: 8)

            Text(normalizeIntroTitle(title))
                .font(PD.FontToken.body(15, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                .lineLimit(1)
        }
        .padding(.horizontal, PD.Spacing.screen)
        .padding(.bottom, 2)
    }

    // Normalize header "УРОК: ПРИВЕТСТВИЯ" → "Приветствия"
    private func normalizeIntroTitle(_ header: String) -> String {
        let raw: String = {
            if let colon = header.firstIndex(of: ":") {
                return header[header.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            }
            let prefix = "УРОК"
            if header.uppercased().hasPrefix(prefix) {
                return header.dropFirst(prefix.count).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
            }
            return header
        }()
        return sentenceCase(raw)
    }

    // Lowercase the string and capitalize the first letter (sentence case).
    private func sentenceCase(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let lowered = trimmed.lowercased()
        let first = String(lowered.prefix(1)).uppercased()
        let rest = String(lowered.dropFirst())
        return first + rest
    }

    @ViewBuilder
    private func stepCardBody(for effective: SDStepItem, idx: Int) -> some View {
        SDStepCard(
            item: effective,
            onTap: {
                activeIndex = idx
                onActiveIndexChange?(idx)
                onTap(effective)
            },
            onPlay: { onPlay(effective) },
            onToggleFavorite: {
                onFav(effective)
                onFavAt?(idx, effective)
            },
            onMarkLearned: {
                onDone(effective)
                onDoneAt?(idx, effective)
            },
            onNext: {
                goNext()
            },
            initialLearned: learned.contains(idx),
            introContent: {
                if let v = introContentView { return v() }
                return AnyView(_IntroPlaceholder())
            },
            summaryContent: {
                if let v = summaryContentView { return v() }
                return AnyView(_SummaryPlaceholder())
            },
            introCTA: {
                if let v = introCTAView { return v() }
                return AnyView(SDStepCard.defaultIntroActionBar())
            },
            summaryCTA: {
                if let v = summaryCTAView { return v() }
                return AnyView(SDStepCard.defaultSummaryActionBar())
            },
            isReadOnly: !allowLearning,
            isOverlay: isOverlay,
            isActive: idx == activeIndex
        )
    }
}

// Typing dots helper
struct SDTypingDots: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        HStack(spacing: 4) {
            Circle().frame(width: 6, height: 6)
                .opacity(phase.truncatingRemainder(dividingBy: 3) >= 0 ? 1 : 0.35)
            Circle().frame(width: 6, height: 6)
                .opacity(phase.truncatingRemainder(dividingBy: 3) >= 1 ? 1 : 0.35)
            Circle().frame(width: 6, height: 6)
                .opacity(phase.truncatingRemainder(dividingBy: 3) >= 2 ? 1 : 0.35)
        }
        .foregroundColor(PD.ColorToken.textSecondary)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 3
            }
        }
    }
}

// MARK: - Hints (TAIKA FM) section for steps
public struct SDHintBubble: View {
    public var mascot: Image?
    public var text: String
    public init(text: String, mascot: Image? = Image("mascot.step")) {
        self.text = text
        self.mascot = mascot
    }
    public var body: some View {
        HStack(alignment: .center, spacing: PD.Spacing.inner) {
            mascot?
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .taikaMascotChrome()
            Text(text)
                .font(PD.FontToken.body(16, weight: .regular))
                .foregroundColor(PD.ColorToken.text)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PD.Spacing.inner)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .fill(PD.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                        .stroke(PD.ColorToken.stroke, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
        .frame(minHeight: 72)
    }
}

public struct SDStepHintsSection: View {
    public var title: String
    public var subtitle: String?
    public var hints: [String]

    // Animation tuning (unused, but left for compatibility)
    public var typingDuration: TimeInterval = 2.0
    public var showDuration: TimeInterval = 3.2
    public var typingCharInterval: TimeInterval = 0.045

    @State private var idx: Int = 0
    @State private var isTyping: Bool = true
    @State private var shown: String = ""
    @State private var charIndex: Int = 0

    public init(title: String = "", subtitle: String? = nil, hints: [String]) {
        self.title = title
        self.subtitle = subtitle
        self.hints = hints
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 12) {
            heroHeader
            hintBubble
        }
        .padding(.horizontal, PD.Spacing.screen)
        .padding(.bottom, PD.Spacing.block * 2.5)
    }

    @ViewBuilder
    private var heroHeader: some View {
        VStack(spacing: 6) {
            // brand wordmark
            Text("taikA")
                .font(.custom("ONMARK Trial", size: 30))
                .foregroundColor(PD.ColorToken.textSecondary.opacity(0.92))
                .kerning(0.2)

            // lesson title (thin subtitle under brand)
            if !title.isEmpty {
                Text(title)
                    .font(PD.FontToken.body(16, weight: .medium))
                    .foregroundColor(PD.ColorToken.textSecondary.opacity(0.82))
                    .lineLimit(1)
            }

            // meta/description line (e.g., "вступление • 8 карт • итоги")
            if let sub = subtitle, !sub.isEmpty {
                Text(sub)
                    .font(PD.FontToken.caption(12, weight: .regular))
                    .foregroundColor(PD.ColorToken.textSecondary.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, PD.Spacing.block * 2)
    }

    @ViewBuilder
    private var hintBubble: some View {
        // Compact tools chip instead of typing bubble
        let msg = hints.first ?? ""
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(PD.ColorToken.textSecondary)
            Text(msg)
                .font(PD.FontToken.body(15, weight: .regular))
                .foregroundColor(PD.ColorToken.textSecondary)
                .lineLimit(Theme.TextBlock.cardBodyLines)
                .minimumScaleFactor(Theme.TextBlock.bodyMinimumScale)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(PD.ColorToken.card)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(PD.ColorToken.stroke, lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .frame(maxWidth: 420, alignment: .center)
    }
}
// MARK: - Hero mascot (standalone, above carousels)
public struct SDStepHeroMascot: View {
    private var image: Image
    public var maxHeight: CGFloat
    public init(imageName: String = "mascot.step.main2", maxHeight: CGFloat = 200) {
        self.image = Image(imageName)
        self.maxHeight = maxHeight
    }
    public var body: some View {
        image
            .resizable()
            .renderingMode(.template)
            .foregroundColor(PD.ColorToken.textSecondary.opacity(0.55))
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: maxHeight)
            .padding(.horizontal, PD.Spacing.screen)
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
    }
}


// MARK: - Step Progress Bar (DS)
public struct SDStepProgress: View {
    public var total: Int
    public var activeIndex: Int?
    public var learned: Set<Int>
    public var favorites: Set<Int>
    public var tipIndices: Set<Int>
    public var onTap: ((Int) -> Void)?
    public var onReset: (() -> Void)?

    public init(total: Int,
                activeIndex: Int? = nil,
                learned: Set<Int> = [],
                favorites: Set<Int> = [],
                tipIndices: Set<Int> = [],
                onTap: ((Int) -> Void)? = nil,
                onReset: (() -> Void)? = nil) {
        self.total = total
        self.learned = learned
        self.favorites = favorites
        self.tipIndices = tipIndices
        self.onTap = onTap
        self.onReset = onReset
        if let idx = activeIndex, total > 0 {
            self.activeIndex = min(max(0, idx), total - 1)
        } else {
            self.activeIndex = nil
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                TaikaSectionLabel(title: "Прогресс")
                Spacer(minLength: 8)
            }

            HStack(alignment: .center, spacing: 10) {
                GeometryReader { geo in
                    let segmentWidth: CGFloat = 22
                    let spacing: CGFloat = 6
                    let _ = geo.size.width
                    let needScroll = false

                    if needScroll {
                        scrollableBar(segmentWidth: segmentWidth, spacing: spacing)
                    } else {
                        centeredBar(segmentWidth: segmentWidth, spacing: spacing)
                    }
                }
                .frame(height: 36 + (total > 10 ? CGFloat((total - 1) / 10) * (36 + 6) : 0))

                if let onReset {
                    Button(action: onReset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Сбросить прогресс урока")
                }
            }
        }
        .padding(.horizontal, PD.Spacing.screen)
    }

    // Helper: renders a single segment capsule for the progress bar
    @ViewBuilder
    private func segmentCapsule(index i: Int, width: CGFloat) -> some View {
        let isActive = (activeIndex ?? -1) == i
        let isLearned = learned.contains(i)
        let isFav = favorites.contains(i)

        SDStepProgressSegment(
            width: width,
            isActive: isActive,
            isLearned: isLearned,
            isFavorite: isFav,
            index: i,
            onTap: onTap
        )
        .id(i)
    }

    @ViewBuilder
    private func centeredBar(segmentWidth: CGFloat, spacing: CGFloat) -> some View {
        let perRow = 10
        let rows: [Range<Int>] = stride(from: 0, to: total, by: perRow).map { start in
            let end = min(start + perRow, total)
            return start..<end
        }
        VStack(alignment: .center, spacing: spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, range in
                HStack(spacing: spacing) {
                    ForEach(range, id: \.self) { i in
                        segmentCapsule(index: i, width: segmentWidth)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, PD.Spacing.screen)
        .frame(height: 36 + (rows.count > 1 ? CGFloat(rows.count - 1) * (36 + spacing) : 0))
    }

    @ViewBuilder
    private func scrollableBar(segmentWidth: CGFloat, spacing: CGFloat) -> some View {
        // Always use centered multi-row layout, no horizontal scroll
        centeredBar(segmentWidth: segmentWidth, spacing: spacing)
    }
}


extension SDStepProgress {
    @ViewBuilder
    fileprivate func progressSegments(width: CGFloat) -> some View {
        Group {
            ForEach(0..<total, id: \.self) { i in
                segmentCapsule(index: i, width: width)
            }
        }
    }
}

#if DEBUG
struct SDStep_Previews: PreviewProvider {
    static let mockItems: [SDStepItem] = [
        .init(kind: .word, titleRU: "Кофе", subtitleTH: "กาแฟ (kaa-fae)", phonetic: "ка-фа́э"),
        .init(kind: .word, titleRU: "Вода", subtitleTH: "น้ำ (náam)", phonetic: "на́м"),
        .init(kind: .phrase, titleRU: "Большое спасибо", subtitleTH: "ขอบคุณมาก (kh̄xbkhuṇ mâak)", phonetic: "коп-ку́н ма́к"),
        .init(kind: .phrase, titleRU: "Доброе утро", subtitleTH: "สวัสดีตอนเช้า (s̄wạs̄dī txn chêa)", phonetic: "са-ва́т-ди тон ча́о"),
        .init(kind: .tip, titleRU: "Ассоциация", subtitleTH: "Свяжи \"коп-ку́н\" с благодарностью — говори после помощи.", phonetic: ""),
        .init(kind: .word, titleRU: "Счёт", subtitleTH: "บิล (bin)", phonetic: "бин"),
        .init(kind: .word, titleRU: "Чек", subtitleTH: "เช็ค (chék)", phonetic: "чек"),
        .init(kind: .phrase, titleRU: "Где туалет?", subtitleTH: "ห้องน้ำอยู่ไหน (h̄̂xngn̂ả yùu năi)", phonetic: "хонг-на́м ю́ най?"),
        .init(kind: .phrase, titleRU: "Можно меню?", subtitleTH: "ขอเมนูได้ไหม (kȟx menû dị̂ h̄ım)", phonetic: "хо́ ме-ну́ дай май?"),
        .init(kind: .tip, titleRU: "Повторение", subtitleTH: "Повтори вслух 3 раза утром и вечером — лучше закрепится.", phonetic: "")
    ]

    static var previews: some View {
        ZStack {
            PD.ColorToken.background.ignoresSafeArea()

            VStack(spacing: PD.Spacing.block * 2) {
                TaikaFMBubbleTyping(
                    messages: TaikaFMData.shared.messages(for: .step),
                    reactions: TaikaFMData.shared.reactionGroups(for: .step),
                    repeats: false,
                    showBubble: false
                )
                .padding(.horizontal, PD.Spacing.screen)

                SDStepCarousel(
                    title: "УРОК: ПРИВЕТСТВИЯ",
                    items: mockItems,
                    activeIndex: .constant(0),
                    subtitle: "вступление • 8 карт • итоги",
                    isOverlay: false
                )
                .padding(.top, PD.Spacing.block)

                SDStepProgress(
                    total: mockItems.count,
                    activeIndex: 0,
                    learned: Set([0, 1, 4]),
                    favorites: Set([2, 5])
                )
                .padding(.top, 4)

                Spacer(minLength: PD.Spacing.block * 2)
            }
        }
    }
}
#endif

