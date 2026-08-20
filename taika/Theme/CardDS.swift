//  CardDS.swift
//  taika
//  Created by product on 30.09.2025.

import SwiftUI
import AVKit

// MARK: - Title font (system – Helvetica‑like)
private enum TaikaFontPS {
    static let title = "ONMARK Trial" // PostScript name
}

/// Canonical app wordmark: `tai` + accent `kAAA` (same lockup as `AppChromeHeader` / `AppBackHeader`, not legacy single-string `taikA`).
public struct TaikaWordmarkLockup: View {
    public var fontSize: CGFloat
    /// Opacity for the white `tai` half (accent half uses `accentOpacity`).
    public var taiOpacity: Double
    public var accentOpacity: Double
    /// Optional semantic tint for completed cards; nil preserves the global brand accent.
    public var accentColor: Color?

    public init(fontSize: CGFloat = 16, taiOpacity: Double = 1, accentOpacity: Double = 1, accentColor: Color? = nil) {
        self.fontSize = fontSize
        self.taiOpacity = taiOpacity
        self.accentOpacity = accentOpacity
        self.accentColor = accentColor
    }

    public var body: some View {
        let spacing = max(2, fontSize * 0.15)
        return HStack(spacing: spacing) {
            Text("tai")
                .font(.custom("Onmark Trial", size: fontSize))
                .foregroundColor(CD.ColorToken.text.opacity(taiOpacity))
                Text("kAAA")
                .font(.custom("Onmark Trial", size: fontSize))
                .foregroundStyle(accentColor.map { AnyShapeStyle($0.opacity(accentOpacity)) } ?? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(accentOpacity)))
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("taikAAA")
    }
}

/// Lockup в углу step-карточки; на экране урока отключается через `Environment.stepLessonSuppressCardWordmark`.
fileprivate struct StepCardInlineWordmarkSlot: View {
    @Environment(\.stepLessonSuppressCardWordmark) private var suppress
    var body: some View {
        if suppress {
            Color.clear.frame(width: 1, height: 1)
        } else {
            TaikaWordmarkLockup(fontSize: 16)
        }
    }
}

/// Шапка step: две **равные** по ширине колонки (leading / trailing), чтобы чип и lockup были симметричны относительно центра карты.
fileprivate struct StepCardBalancedTopChrome<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing
    let sideSlotWidth: CGFloat

    init(sideSlotWidth: CGFloat = 92, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.sideSlotWidth = sideSlotWidth
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: sideSlotWidth, alignment: .leading)
            Spacer(minLength: 0)
            trailing
                .frame(width: sideSlotWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

fileprivate func stepCardTypeChipStyle(forLabel label: String) -> AppMiniChipStyle {
    let c = label.lowercased()
    return (c == "лайфхак" || c == "запомнил") ? .accent : .neutral
}

// MARK: - StepProGateCard (DS atom: step-style PRO gate card; same shell as StepWordCard)
public struct StepProGateCard: View {
    public let title: String
    public let subtitle: String
    public let footnote: String?
    public let label: String

    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle

    public let primaryTitle: String
    public let onPrimaryTap: () -> Void

    public init(
        title: String,
        subtitle: String,
        footnote: String? = "нужно pro",
        label: String = "pro",
        primaryTitle: String = "открыть pro",
        size: CGSize = CGSize(width: CardDS.Metrics.stepWordWidth, height: CardDS.Metrics.stepWordHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        onPrimaryTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.footnote = footnote
        self.label = label
        self.primaryTitle = primaryTitle
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.onPrimaryTap = onPrimaryTap
    }

    public var body: some View {
        CardBase(
            title: title,
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            cornerRadius: CardDS.Metrics.stepCardContentRadius,
            contentLayout: .stepSymmetric,
            top: {
                StepCardBalancedTopChrome {
                    TaikaWordmarkLockup(fontSize: 16)
                } trailing: {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
                .padding(.top, 8)
            },
            bottom: {
                Button(action: onPrimaryTap) {
                    Text(primaryTitle.lowercased())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
            },
            meta: {
                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    VStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)

                        Text(title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)

                        Text(subtitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)

                        if let footnote, !footnote.isEmpty {
                            Text(footnote)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .allowsTightening(true)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 20)
                }
                .padding(.vertical, 18)
            },
            tags: { EmptyView() },
            belowTitle: { EmptyView() }
        )
    }
}
// MARK: - StepWordCardVisual (adapter from SDStepItem → StepWordCard visual)
public struct StepWordCardVisual: View {
    public let item: SDStepItem
    public let label: String
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let phoneticView: AnyView?
    public let isFavorite: Bool
    public let isLearned: Bool
    public let allowLearn: Bool
    public let isAudioPlaying: Bool
    public let showsTypeChip: Bool
    public let onPlay: (() -> Void)?
    public let onFavorite: () -> Void
    public let onLearn: () -> Void

    public init(
        item: SDStepItem,
        label: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.stepCardWidth,
                              height: CardDS.Metrics.stepWordCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        phoneticView: AnyView? = nil,
        isFavorite: Bool = false,
        isLearned: Bool = false,
        allowLearn: Bool = true,
        isAudioPlaying: Bool = false,
        showsTypeChip: Bool = true,
        onPlay: (() -> Void)? = nil,
        onFavorite: @escaping () -> Void = {},
        onLearn: @escaping () -> Void = {}
    ) {
        self.item = item
        // default label depends on kind, but falls back to "слово"
        if let label {
            self.label = label
        } else {
            switch item.visualKind {
            case .word, .phrase, .casual:
                self.label = "слово"
            default:
                self.label = "слово"
            }
        }
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.phoneticView = phoneticView
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.allowLearn = allowLearn
        self.isAudioPlaying = isAudioPlaying
        self.showsTypeChip = showsTypeChip
        self.onPlay = onPlay
        self.onFavorite = onFavorite
        self.onLearn = onLearn
    }

    public var body: some View {
        StepWordCard(
            title: item.titleRU,
            translit: item.phonetic,
            thai: item.subtitleTH,
            label: label,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            phoneticView: phoneticView,
            isFavorite: isFavorite,
            isLearned: isLearned,
            allowLearn: allowLearn,
            isAudioPlaying: isAudioPlaying,
            showsTypeChip: showsTypeChip,
            onPlay: onPlay,
            onFavorite: onFavorite,
            onLearn: onLearn
        )
    }
}

// MARK: - StepLifehackCardVisual (adapter from SDStepItem → StepLifehack visual)
public struct StepLifehackCardVisual: View {
    public let item: SDStepItem
    public let label: String
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let isFavorite: Bool
    public let onFavorite: () -> Void
    public let onNext: (() -> Void)?

    public init(
        item: SDStepItem,
        label: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.stepCardWidth,
                              height: CardDS.Metrics.stepLifehackCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        isFavorite: Bool = false,
        onFavorite: @escaping () -> Void = {},
        onNext: (() -> Void)? = nil
    ) {
        self.item = item
        if let label {
            self.label = label
        } else {
            switch item.visualKind {
            case .tip:
                self.label = "лайфхак"
            default:
                self.label = "заметка"
            }
        }
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.isFavorite = isFavorite
        self.onFavorite = onFavorite
        self.onNext = onNext
    }

    public var body: some View {
        let trimmedRU = item.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTH = item.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodyStr = trimmedTH.isEmpty ? trimmedRU : trimmedTH
        let headlineStr: String? = trimmedTH.isEmpty ? nil : (trimmedRU.isEmpty ? nil : trimmedRU)
        StepLifehackCardLegacy(
            headline: headlineStr,
            body: bodyStr.isEmpty ? "Лайфхак" : bodyStr,
            label: label,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            isFavorite: isFavorite,
            onFavorite: onFavorite,
            onNext: onNext
        )
    }
}

// MARK: - StepLifehackCard (DS atom: lifehack card)
public struct StepLifehackCardLegacy: View {
    /// Короткий заголовок (как RU-строка карточки слова) — опционально, под канон word/tip.
    public let headline: String?
    public let bodyText: String      // основной текст лайфхака
    public let label: String         // чип в правом верхнем углу, по умолчанию "лайфхак"
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let isFavorite: Bool
    public let isLearned: Bool
    public let allowLearn: Bool
    /// `true` в зачётке: показываем «запомнил» вместо шеврона «далее».
    public let tipShowsLearnSlot: Bool
    public let onFavorite: () -> Void
    public let onLearn: () -> Void
    public let onNext: (() -> Void)?

    public init(
        headline: String? = nil,
        body: String,
        label: String = "лайфхак",
        size: CGSize = CGSize(width: CardDS.Metrics.stepLifehackWidth,
                              height: CardDS.Metrics.stepLifehackHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        isFavorite: Bool = false,
        isLearned: Bool = false,
        allowLearn: Bool = true,
        tipShowsLearnSlot: Bool = false,
        onFavorite: @escaping () -> Void = {},
        onLearn: @escaping () -> Void = {},
        onNext: (() -> Void)? = nil
    ) {
        self.headline = headline
        self.bodyText = body
        self.label = label
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.allowLearn = allowLearn
        self.tipShowsLearnSlot = tipShowsLearnSlot
        self.onFavorite = onFavorite
        self.onLearn = onLearn
        self.onNext = onNext
    }

    private var parsedBody: (main: String, tip: String?) {
        let raw = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Режем по 💡 / «Лайфхак:» — эмодзи и рамку не показываем, только суть.
        let tipMarkers = ["💡", "Лайфхак:", "лайфхак:"]
        for marker in tipMarkers {
            guard let range = raw.range(of: marker) else { continue }
            let main = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            var tip = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Убрать ведущий «Лайфхак:» если резали только по эмодзи
            for prefix in ["Лайфхак:", "лайфхак:"] where tip.lowercased().hasPrefix(prefix.lowercased()) {
                tip = String(tip.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            tip = tip.replacingOccurrences(of: "💡", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return (main.isEmpty ? Self.stripEmojiNoise(raw) : Self.stripEmojiNoise(main),
                    tip.isEmpty ? nil : tip)
        }
        return (Self.stripEmojiNoise(raw), nil)
    }

    private static func stripEmojiNoise(_ s: String) -> String {
        s.replacingOccurrences(of: "💡", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        let tint = ThemeManager.shared.currentAccentTintColor
        let parts = parsedBody

        ZStack {
            shape.fill(CD.ColorToken.card)

            // Лёгкий brand wash — без тяжёлой обводки и «рамки в рамке».
            LinearGradient(
                colors: [
                    tint.opacity(0.14),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(shape)

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    StepCardInlineWordmarkSlot()
                    Spacer(minLength: 8)
                    AppMiniChip(
                        title: label.lowercased(),
                        style: stepCardTypeChipStyle(forLabel: label)
                    ) { }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Spacer(minLength: 12)

                VStack(spacing: 12) {
                    if let headline, !headline.isEmpty {
                        Text(Self.stripEmojiNoise(headline))
                            .font(.system(size: Theme.StepCardText.lifehackTitleFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(CD.ColorToken.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    taikaFMStyledText(parts.main, baseColor: CD.ColorToken.text.opacity(0.94))
                        .font(.system(size: Theme.StepCardText.lifehackBodyFontSize, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineSpacing(Theme.StepCardText.lifehackLineSpacing)
                        .lineLimit(Theme.StepCardText.lifehackLines)
                        .minimumScaleFactor(Theme.StepCardText.lifehackScale)
                        .fixedSize(horizontal: false, vertical: true)

                    if let tip = parts.tip {
                        taikaFMStyledText(tip, baseColor: tint)
                            .font(.system(size: Theme.StepCardText.lifehackTipFontSize, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .lineLimit(5)
                            .minimumScaleFactor(0.88)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 12)

                StepIconCircleButton(
                    systemName: isFavorite ? "heart.fill" : "heart",
                    isActive: isFavorite,
                    caption: "в избранное",
                    action: onFavorite
                )
                .padding(.bottom, 16)
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: Color.black.opacity(0.28), radius: 16, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([headline, parts.main, parts.tip].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". "))
    }
}

// EPIC 5: оверлей лайфхака — тот же фон, что у «Итоги урока» (dim 0.45 + ultraThinMaterial + black 0.35)
private struct StepLifehackExpandSheet: View {
    let bodyText: String
    let onDismiss: () -> Void

    private static let sheetCornerRadius: CGFloat = 28
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.sheetCornerRadius, style: .continuous)
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            HStack {
                TaikaWordmarkLockup(fontSize: 16)
                Spacer(minLength: 0)
                AppMiniChip(title: "лайфхак", style: .accent) { }
            }
            .padding(.horizontal, CardDS.Metrics.contentX)
            .padding(.top, 12)
            .padding(.bottom, 8)

            let scrollHeight: CGFloat = UIScreen.main.bounds.height * 0.45
            TaikaRootVerticalScroll {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    taikaFMStyledText(bodyText, baseColor: CD.ColorToken.textSecondary.opacity(0.92))
                        .font(.system(size: Theme.StepCardText.lifehackBodyFontSize, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, CardDS.Metrics.contentX)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer(minLength: 24)
                }
                .frame(minHeight: scrollHeight)
            }
            .frame(maxHeight: scrollHeight)

            Button {
                onDismiss()
            } label: {
                Text("закрыть")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .padding(.horizontal, CardDS.Metrics.contentX)
            .padding(.bottom, 20)
            .padding(.top, 8)
        }
        .taikaBlackGlassBackground(cornerRadius: Self.sheetCornerRadius)
        .clipShape(cardShape)
        .frame(maxWidth: 320)
    }

    var body: some View {
        ZStack {
            Theme.Surfaces.blackGlassScrim
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            cardContent
        }
        .presentationBackground(.clear)
    }
}

extension Font {
    /// UI titles: use system (Helvetica/SF-like), not the app logo font
    static func taikaTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// App logo only — ONMARK Trial
    static func taikaLogo(_ size: CGFloat) -> Font {
        .custom(TaikaFontPS.title, size: size, relativeTo: .title2)
    }

    /// Скор и статистика курса/урока — MV-SKIFER (`MVSKIFERRegular`).
    static func taikaStat(_ size: CGFloat) -> Font {
        Theme.Fonts.stat(size)
    }
}

extension UIFont {
    /// UI titles: system font
    static func taikaTitle(_ size: CGFloat) -> UIFont {
        .systemFont(ofSize: size, weight: .semibold)
    }
    /// App logo only — ONMARK Trial
    static func taikaLogo(_ size: CGFloat) -> UIFont {
        UIFont(name: TaikaFontPS.title, size: size) ?? .systemFont(ofSize: size, weight: .bold)
    }
}

// MARK: - Namespacing (size & spacing only)
public enum CardDS {
    public enum SectionChrome { case none, fold, lines, rail, zones, seps, sepsLR }
    public enum ChromeStyle { case brand, cards }

    /// Optional restrained brand treatment for read-only informational cards.
    /// Existing course cards remain unchanged with `.none`.
    public enum AccentTreatment {
        case none
        case taikaValues(fill: AnyShapeStyle, glow: Color)
    }

    public struct Metrics {
        public static let radius: CGFloat = 16
        /// Квадратные карточки шага: чуть крупнее радиус, чем у 280×360 — визуально ближе к «мягкой» карусели курса.
        public static let stepCardContentRadius: CGFloat = 20
        public static let contentX: CGFloat = 18
        public static let contentYTop: CGFloat = 24
        public static let contentYBottom: CGFloat = 32
        public static let vSpacing: CGFloat = 10
        public static let footerRailSpacing: CGFloat = 12
        public static let footerHeight: CGFloat = 38
        public static let titleTopGap: CGFloat = 4
        public static let titleBottomGap: CGFloat = 6
        // Unified card sizing for course and lesson cards (canonical dimensions)
        public static let courseWidth: CGFloat  = 300
        public static let courseHeight: CGFloat = 384
        public static let courseCardWidth: CGFloat  = courseWidth
        public static let courseCardHeight: CGFloat = courseHeight

        // lessons use same footprint as courses
        public static let lessonWidth: CGFloat  = courseWidth
        public static let lessonHeight: CGFloat = courseHeight
        public static let lessonCardWidth: CGFloat  = lessonWidth
        public static let lessonCardHeight: CGFloat = lessonHeight

        // step cards: крупнее в карусели, чтобы не «тонули» на экране.
        public static let stepCardWidth: CGFloat = 336
        public static let stepWordCardHeight: CGFloat = stepCardWidth
        /// EPIC 5: max height for step word card when using adaptive height so long text is not truncated.
        public static let stepCardMaxHeight: CGFloat = 420
        public static let stepLifehackCardHeight: CGFloat = 468
        /// Сторона квадрата в ленте шагов для фраз (`SDStepCarousel`).
        public static var stepCarouselSquareSide: CGFloat { stepCardWidth }

        // алиасы для старых имён, чтобы не ломать существующие вызовы
        public static let stepWordWidth: CGFloat = stepCardWidth
        public static let stepWordHeight: CGFloat = stepWordCardHeight
        /// Шире и выше: презентационный портрет, не «мини-стикер».
        public static let stepLifehackWidth: CGFloat = 318
        public static let stepLifehackHeight: CGFloat = stepLifehackCardHeight

        /// Компактная рабочая карточка «По фразам» в Спикере (фраза + разбор) — намеренно НЕ квадрат
        /// лайфхака/тизера: это плотная рабочая единица, а не промо-плашка.
        public static let speakerPhraseCardWidth: CGFloat = 268
        public static let speakerPhraseCardHeight: CGFloat = 196

        // note cards sizing (independent from step cards)
        // noteCourse/noteText are square; noteStep is a shorter rectangle.
        public static let noteCardWidth: CGFloat = 290
        public static let noteCardHeight: CGFloat = 290
        public static let noteStepHeight: CGFloat = 220
        // note card paddings (keep top/bottom symmetric)
        public static let noteTopPadding: CGFloat = 14
        public static let noteBottomPadding: CGFloat = 14

        public static let topBandHeight: CGFloat = 56
        public static let bottomBandHeight: CGFloat = 80
        /// Узкая шапка для квадратной step-карты — иначе meta + нижний ряд не помещаются в фиксированный квадрат и клипает `clipShape`.
        public static let stepCardTopBandHeight: CGFloat = 50
        /// Нижняя зона step-карты: ближе к верхней полосе, чтобы контентный центр был визуально симметричным.
        public static let stepCardBottomBandHeight: CGFloat = 62
        /// Main «Разминка»: подписи под иконками — чуть выше нижняя полоса.
        public static let stepCardBottomBandHeightCaptions: CGFloat = 78
        /// Добавляется к `contentX` для всей step-карты (`stepSymmetric`): шапка, meta и нижний ряд на одной сетке; чип не липнет к скруглению.
        public static let stepCardHeaderEdgeInset: CGFloat = 6
        public static let bannerHeight: CGFloat = 340
        public static let bannerHeightCompact: CGFloat = 170 // half-height banner for calendar detail
        public static let weeklyCellWidth: CGFloat = 120
        public static let weeklyCellHeight: CGFloat = 260
        /// Компактная полоска дней на Main (не board-карточки 260pt).
        public static let weeklyRowCompactWidth: CGFloat = 52
        public static let weeklyRowCompactHeight: CGFloat = 48

        // Global inter-card spacing token for carousels (used by CourseDS/LessonsDS)
        public static let carouselSpacing: CGFloat = 20
        /// `SDStepCarousel`: заметный gutter между ячейками — иначе центр с большим z-index «съедает» скругление соседей.
        public static let stepCarouselSpacing: CGFloat = 34

        // Isolated block metrics
        public static let blockSpacing: CGFloat = 12       // space between content blocks
        public static let titleMinHeight: CGFloat = 56     // reserve space for multi-line titles
        public static let descMinHeight: CGFloat = 18      // single-line description
        public static let metaRowMinHeight: CGFloat = 24   // chips (timer/cards)
        public static let tagsRowMinHeight: CGFloat = 24   // tags (optional)

        // ConsoleCard metrics
        public static let consoleWidth: CGFloat = 408
        public static let consoleHeight: CGFloat = 280
        public static let tearStripHeight: CGFloat = 26
        public static let tearTabWidth: CGFloat = 42
        public static let tearTabGap: CGFloat = 10
        public static let tearPerforationDash: [CGFloat] = [4, 4]
        public static let consoleContentX: CGFloat = 14
    }

    /// Только `CourseLessonCard` в `CDLessonCarousel` читает `stepCarouselCellSize` (ячейка карусели курса/урока). Шаговые карточки используют параметр `size` из `SDStepCard` — так не подтягиваются чужие 280×360.
    public enum StepCarousel {
        public struct CellSizeKey: EnvironmentKey {
            public static let defaultValue: CGSize? = nil
        }
        /// Экран урока (`StepView`): шапка уже даёт wordmark — не дублировать внутри `StepWordCard` / pro / лайфхак. Main «Разминка» не выставляет ключ → lockup остаётся как в референсе.
        public struct SuppressInlineWordmarkKey: EnvironmentKey {
            public static let defaultValue: Bool = false
        }
        /// Main «Разминка»: подписи под иконками (слушать / в избранное) — для «бланкового» мозга.
        public struct ActionCaptionsKey: EnvironmentKey {
            public static let defaultValue: Bool = false
        }
    }
}

extension EnvironmentValues {
    /// Ячейка `CDLessonCarousel` для `CourseLessonCard` (шаговые атомы этот ключ не используют).
    public var stepCarouselCellSize: CGSize? {
        get { self[CardDS.StepCarousel.CellSizeKey.self] }
        set { self[CardDS.StepCarousel.CellSizeKey.self] = newValue }
    }

    public var stepLessonSuppressCardWordmark: Bool {
        get { self[CardDS.StepCarousel.SuppressInlineWordmarkKey.self] }
        set { self[CardDS.StepCarousel.SuppressInlineWordmarkKey.self] = newValue }
    }

    public var taikaStepActionCaptions: Bool {
        get { self[CardDS.StepCarousel.ActionCaptionsKey.self] }
        set { self[CardDS.StepCarousel.ActionCaptionsKey.self] = newValue }
    }
}

// MARK: - Chrome (background only)
public struct CardChrome: View {
    let style: CardDS.ChromeStyle
    public init(style: CardDS.ChromeStyle = .brand) { self.style = style }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous)
        switch style {
        case .brand, .cards:
            return AnyView(
                Theme.Surfaces.card(shape)
            )
        }
    }
}



// MARK: - Footer rail (CTA left, actions right)
public struct CardFooterRail<Left: View, Right: View>: View {
    let left: Left
    let right: Right
    public init(@ViewBuilder left: () -> Left, @ViewBuilder right: () -> Right) {
        self.left = left(); self.right = right()
    }
    public var body: some View {
        HStack(spacing: CardDS.Metrics.footerRailSpacing) {
            left
            Spacer(minLength: 8)
            right
        }
        .frame(height: CardDS.Metrics.footerHeight)
    }
}

// MARK: - Single template: Course/Lesson card (layout only, atoms come from AppDS)

/// Раскладка контентной колонки: курс — слева; квадрат step — симметрично по центру (одинаковые боковые inset с шапкой и нижним рядом).
public enum CardBaseContentLayout: Equatable {
    case editorial
    case stepSymmetric
}

/// Usage (compose with AppDS atoms):
/// CardBase(title: ..., subtitle: ...) { // top, optional via trailing label
///   // top: e.g. AppStatusChip + AppProChip (from AppDS)
/// } bottom: {
///   // bottom: e.g. AppCTAButtons + AppCardIconButton (from AppDS)
/// } meta: {
///   // meta row: e.g. AppInlineMeta/AppTagChip from AppDS
/// }
public struct CardBase<Top: View, Meta: View, BelowTitle: View, Tags: View, Bottom: View>: View {
    // content
    let title: String
    let subtitle: String?
    let size: CGSize
    let sectionChrome: CardDS.SectionChrome
    let chromeStyle: CardDS.ChromeStyle
    let showTitle: Bool
    let isFluidWidth: Bool
    let brandText: String?
    let cornerRadius: CGFloat
    let contentLayout: CardBaseContentLayout
    @Environment(\.taikaStepActionCaptions) private var stepActionCaptions

    // provided slots
    let top: Top          // e.g. статус/PRO-ряд (из AppDS)
    let meta: Meta        // inline metrics only
    let belowTitle: BelowTitle        // inline content directly under the title
    let tags: Tags        // optional tags slot (bottom-right of CONTENT)
    let bottom: Bottom    // e.g. CTA/иконки (из AppDS)

    public init(
        title: String,
        subtitle: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.courseWidth, height: CardDS.Metrics.courseHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        showTitle: Bool = true,
        isFluidWidth: Bool = false,
        brandText: String? = nil,
        cornerRadius: CGFloat = CardDS.Metrics.radius,
        contentLayout: CardBaseContentLayout = .editorial,
        @ViewBuilder top: () -> Top = { EmptyView() as! Top },
        @ViewBuilder bottom: () -> Bottom = { EmptyView() as! Bottom },
        @ViewBuilder meta: () -> Meta,
        @ViewBuilder tags: () -> Tags = { EmptyView() as! Tags },
        @ViewBuilder belowTitle: () -> BelowTitle = { EmptyView() as! BelowTitle }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.showTitle = showTitle
        self.isFluidWidth = isFluidWidth
        self.brandText = brandText
        self.cornerRadius = cornerRadius
        self.contentLayout = contentLayout
        self.top = top()
        self.bottom = bottom()
        self.meta = meta()
        self.tags = tags()
        self.belowTitle = belowTitle()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isStepSymmetric = contentLayout == .stepSymmetric
        let contentHStackAlignment: HorizontalAlignment = isStepSymmetric ? .center : .leading
        let metaSlotAlignment: Alignment = isStepSymmetric ? .center : .topLeading
        let titleBlockAlignment: Alignment = isStepSymmetric ? .center : .leading
        let belowTitleAlignment: Alignment = isStepSymmetric ? .center : .leading
        let bottomSlotAlignment: Alignment = isStepSymmetric ? .center : .leading
        let horizontalPadding: CGFloat = isStepSymmetric
            ? CardDS.Metrics.contentX + CardDS.Metrics.stepCardHeaderEdgeInset
            : CardDS.Metrics.contentX
        // Core layout
        let base = ZStack {
            CardChrome(style: chromeStyle)
            VStack(spacing: 0) {
                // TOP zone (status/PRO area only — AppDS atoms), vertically centered
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        top
                    }
                    .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(height: isStepSymmetric ? CardDS.Metrics.stepCardTopBandHeight : CardDS.Metrics.topBandHeight)

                // CONTENT zone — editorial: leading; step: симметричная колонка по центру
                ZStack {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(alignment: contentHStackAlignment, spacing: CardDS.Metrics.blockSpacing) {
                            meta
                                .frame(maxWidth: .infinity,
                                       minHeight: CardDS.Metrics.metaRowMinHeight,
                                       alignment: metaSlotAlignment)

                            if showTitle {
                                Text(title)
                                    .font(.taikaTitle(24))
                                    .kerning(0.05)
                                    .foregroundStyle(CD.ColorToken.text)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.88)
                                    .multilineTextAlignment(isStepSymmetric ? .center : .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(minHeight: CardDS.Metrics.titleMinHeight, alignment: titleBlockAlignment)
                            }

                            belowTitle
                                .frame(maxWidth: .infinity, alignment: belowTitleAlignment)

                            if let subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.95))
                                    .lineLimit(2)
                                    .multilineTextAlignment(isStepSymmetric ? .center : .leading)
                                    .frame(minHeight: CardDS.Metrics.descMinHeight, alignment: titleBlockAlignment)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isStepSymmetric ? .center : .leading)
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) { tags }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.bottom, 4)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, isStepSymmetric ? 5 : 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    bottom
                        .frame(maxWidth: .infinity, alignment: bottomSlotAlignment)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(height: {
                    if !isStepSymmetric { return CardDS.Metrics.bottomBandHeight }
                    return stepActionCaptions
                        ? CardDS.Metrics.stepCardBottomBandHeightCaptions
                        : CardDS.Metrics.stepCardBottomBandHeight
                }())
            }
        }

        // Clean base chrome: no legacy overlays — all visual tokens come from Theme (CD.ColorToken.card, etc.)
        let clipped = base
            .clipShape(shape)
            .contentShape(shape)

        let optimized: AnyView = isStepSymmetric
            ? AnyView(clipped)
            : AnyView(clipped.compositingGroup())

        return optimized
            .frame(width: isFluidWidth ? nil : size.width, height: size.height, alignment: .topLeading)
            .frame(maxWidth: isFluidWidth ? .infinity : nil)
    }
}

extension CardBase where Top == EmptyView, BelowTitle == EmptyView, Tags == EmptyView, Bottom == EmptyView {
    public init(
        title: String,
        subtitle: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.courseWidth, height: CardDS.Metrics.courseHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        showTitle: Bool = true,
        isFluidWidth: Bool = false,
        brandText: String? = nil,
        @ViewBuilder meta: () -> Meta
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: showTitle,
            isFluidWidth: isFluidWidth,
            brandText: brandText,
            cornerRadius: CardDS.Metrics.radius,
            top: { EmptyView() },
            bottom: { EmptyView() },
            meta: meta,
            tags: { EmptyView() },
            belowTitle: { EmptyView() }
        )
    }
}

// MARK: - YouTube-like micro burst (лайк / выучил) — короткий разлёт частиц из центра кнопки
fileprivate struct TaikaStepTapBurst: View {
    let trigger: Int
    let systemName: String
    // `phase` управляет и позицией частиц, и их непрозрачностью.
    // Нужна начальная невидимость: иначе на старте (до первого тапа) видно “точки” в центре иконки.
    @State private var phase: CGFloat = 1

    var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        GeometryReader { g in
            let mid = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    let angle = Double(i) / 10.0 * 2 * Double.pi
                    Image(systemName: systemName)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(accent.opacity(0.92))
                        .position(
                            x: mid.x + CGFloat(cos(angle)) * 28 * phase,
                            y: mid.y + CGFloat(sin(angle)) * 28 * phase
                        )
                        .opacity(1.0 - Double(phase))
                        .scaleEffect(0.45 + 0.6 * phase)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            phase = 0
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.5)) {
                    phase = 1
                }
            }
        }
    }
}

// MARK: - Unified step card action bar (CTA for word/tip cards)
public struct StepCardActionBar: View {
    public let isFavorite: Bool
    public let isLearned: Bool
    public let allowLearn: Bool
    public let isTip: Bool
    /// В зачётке: у лайфхака те же действия, что у слова (без шеврона «далее») — раскрыть, сердце, запомнил.
    public let tipShowsLearnSlot: Bool
    public let showsPlayAndFavorite: Bool
    /// Highlights the speaker control while TTS for this card is playing.
    public let isAudioPlaying: Bool
    public let onPlay: (() -> Void)?
    public let onFavorite: () -> Void
    public let onLearn: () -> Void
    public let onNext: (() -> Void)?
    public let onExpand: (() -> Void)?
    /// Мини-карточки (избранное): выучено → только залитая галочка, без чипа «запомнил» (иначе ломается нижний ряд).
    public let miniLearnedCheckmarkOnly: Bool

    @State private var favBurstTrigger: Int = 0
    @State private var learnBurstTrigger: Int = 0
    @State private var playBurstTrigger: Int = 0
    @Environment(\.taikaStepActionCaptions) private var showCaptions

    public init(
        isFavorite: Bool,
        isLearned: Bool,
        allowLearn: Bool = true,
        isTip: Bool = false,
        tipShowsLearnSlot: Bool = false,
        showsPlayAndFavorite: Bool = true,
        isAudioPlaying: Bool = false,
        onPlay: (() -> Void)? = nil,
        onFavorite: @escaping () -> Void,
        onLearn: @escaping () -> Void,
        onNext: (() -> Void)? = nil,
        onExpand: (() -> Void)? = nil,
        miniLearnedCheckmarkOnly: Bool = false
    ) {
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.allowLearn = allowLearn
        self.isTip = isTip
        self.tipShowsLearnSlot = tipShowsLearnSlot
        self.showsPlayAndFavorite = showsPlayAndFavorite
        self.isAudioPlaying = isAudioPlaying
        self.onPlay = onPlay
        self.onFavorite = onFavorite
        self.onLearn = onLearn
        self.onNext = onNext
        self.onExpand = onExpand
        self.miniLearnedCheckmarkOnly = miniLearnedCheckmarkOnly
    }

    /// Горизонтальный зазор между иконками: на квадратной step-карте ~232pt контента 28pt разносил ряд за край.
    private static let stepActionHSpacing: CGFloat = 14
    /// Фиксированная ширина слота «выучил» / chip. Слегка увеличено для баланса с левой парой иконок.
    private static let stepLearnSlotWidth: CGFloat = 102
    /// Fixed width for every icon slot so speaker / heart / expand / check align on one grid.
    private static let stepIconSlotWidth: CGFloat = Theme.IconButton.tapMinCard
    /// Width of the left icon cluster (2 icon slots + spacing), matched against the learn chip slot.
    private static let stepLeftClusterWidth: CGFloat = (Theme.IconButton.tapMinCard * 2) + stepActionHSpacing

    public var body: some View {
        HStack(spacing: 0) {
            // left slot
            Group {
                if isTip {
                    StepIconCircleButton(
                        systemName: "rectangle.expand.vertical",
                        isActive: false,
                        caption: showCaptions ? "ещё" : nil,
                        action: { onExpand?() }
                    )
                } else if showsPlayAndFavorite {
                    ZStack {
                        StepIconCircleButton(
                            systemName: "speaker.wave.2.fill",
                            isActive: false,
                            playbackActive: isAudioPlaying,
                            caption: showCaptions ? "слушать" : nil,
                            action: {
                                playBurstTrigger &+= 1
                                onPlay?()
                            }
                        )
                        TaikaStepTapBurst(trigger: playBurstTrigger, systemName: "speaker.wave.2.fill")
                            .frame(width: 72, height: 56)
                    }
                } else {
                    Color.clear
                        .frame(width: Theme.IconButton.tapMinCard, height: Theme.IconButton.tapMinCard)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // center slot
            Group {
                if showsPlayAndFavorite {
                    ZStack {
                        StepIconCircleButton(
                            systemName: isFavorite ? "heart.fill" : "heart",
                            isActive: isFavorite,
                            caption: showCaptions ? (isFavorite ? "избранное" : "в избранное") : nil,
                            action: {
                                favBurstTrigger &+= 1
                                onFavorite()
                            }
                        )
                        TaikaStepTapBurst(trigger: favBurstTrigger, systemName: "heart.fill")
                            .frame(width: 72, height: 56)
                    }
                } else {
                    Color.clear
                        .frame(width: Theme.IconButton.tapMinCard, height: Theme.IconButton.tapMinCard)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // right slot
            Group {
                if isTip {
                    if tipShowsLearnSlot {
                        Group {
                            if isLearned {
                                ZStack {
                                    AppMiniChip(
                                        title: "запомнил",
                                        style: .accent
                                    ) {
                                        learnBurstTrigger &+= 1
                                        if allowLearn { onLearn() }
                                    }
                                    TaikaStepTapBurst(trigger: learnBurstTrigger, systemName: "checkmark")
                                        .frame(width: 100, height: 48)
                                }
                            } else {
                                ZStack {
                                    StepIconCircleButton(
                                        systemName: "checkmark",
                                        isActive: false,
                                        caption: showCaptions ? "запомнил" : nil,
                                        action: {
                                            learnBurstTrigger &+= 1
                                            if allowLearn { onLearn() }
                                        }
                                    )
                                    TaikaStepTapBurst(trigger: learnBurstTrigger, systemName: "checkmark")
                                        .frame(width: 72, height: 56)
                                }
                            }
                        }
                    } else {
                        StepIconCircleButton(
                            systemName: "chevron.right",
                            isActive: false,
                            caption: showCaptions ? "далее" : nil,
                            action: { onNext?() }
                        )
                    }
                } else {
                    Group {
                        if miniLearnedCheckmarkOnly {
                            if isLearned {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                    .frame(minWidth: Theme.IconButton.tapMinCard, minHeight: Theme.IconButton.tapMinCard)
                                    .accessibilityLabel("Выучено")
                            } else {
                                // Как на полноразмерной step-карточке: приглушённая круглая галочка (в мини-избранном allowLearn обычно false).
                                ZStack {
                                    StepIconCircleButton(
                                        systemName: "checkmark",
                                        isActive: false,
                                        caption: showCaptions ? "запомнил" : nil,
                                        action: {
                                            guard allowLearn else { return }
                                            learnBurstTrigger &+= 1
                                            onLearn()
                                        }
                                    )
                                    if allowLearn {
                                        TaikaStepTapBurst(trigger: learnBurstTrigger, systemName: "checkmark")
                                            .frame(width: 72, height: 56)
                                    }
                                }
                            }
                        } else if isLearned {
                            ZStack {
                                AppMiniChip(
                                    title: "запомнил",
                                    style: .accent
                                ) {
                                    learnBurstTrigger &+= 1
                                    if allowLearn { onLearn() }
                                }
                                TaikaStepTapBurst(trigger: learnBurstTrigger, systemName: "checkmark")
                                    .frame(width: 100, height: 48)
                            }
                        } else {
                            ZStack {
                                StepIconCircleButton(
                                    systemName: "checkmark",
                                    isActive: false,
                                    caption: showCaptions ? "запомнил" : nil,
                                    action: {
                                        learnBurstTrigger &+= 1
                                        if allowLearn { onLearn() }
                                    }
                                )
                                TaikaStepTapBurst(trigger: learnBurstTrigger, systemName: "checkmark")
                                    .frame(width: 72, height: 56)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(CD.ColorToken.textSecondary)
    }
}
// MARK: - StepCardBase (shared shell for step cards – layout only, no logic)

fileprivate struct StepIconCircleButton: View {
    let systemName: String
    let isActive: Bool
    var playbackActive: Bool = false
    var caption: String? = nil
    let action: () -> Void
    @State private var pulseScale: CGFloat = 1

    private var iconForeground: AnyShapeStyle {
        let accent = ThemeManager.shared.currentAccentFill
        let dim = CD.ColorToken.textSecondary.opacity(0.92)
        if systemName == "speaker.wave.2.fill", playbackActive {
            return AnyShapeStyle(accent)
        }
        if isActive {
            return AnyShapeStyle(accent)
        }
        return AnyShapeStyle(dim)
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.58)) {
                pulseScale = 1.12
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    pulseScale = 1.0
                }
            }
        }) {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: Theme.IconButton.iconSizeCard, weight: .semibold))
                    .foregroundStyle(iconForeground)
                    .modifier(StepSpeakerWaveSpeakingModifier(systemName: systemName, speaking: playbackActive))
                    .scaleEffect(pulseScale)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(PD.ColorToken.chip)
                    )
                    .overlay(
                        Circle()
                            .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                    )

                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(minWidth: Theme.IconButton.tapMinCard, minHeight: Theme.IconButton.tapMinCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle(scale: 0.88, fade: 0.92, useBouncySpring: true, flashOpacity: 0.16))
        .accessibilityLabel(caption ?? systemName)
    }
}

private struct StepSpeakerWaveSpeakingModifier: ViewModifier {
    let systemName: String
    let speaking: Bool

    func body(content: Content) -> some View {
        if systemName == "speaker.wave.2.fill", speaking {
            content.symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
        } else {
            content
        }
    }
}
public struct StepCardBase<Content: View, Bottom: View>: View {
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    private let content: Content
    private let bottom: Bottom

    public init(
        size: CGSize = CGSize(width: CardDS.Metrics.stepWordWidth, height: CardDS.Metrics.stepWordHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.content = content()
        self.bottom = bottom()
    }

    public var body: some View {
        CardBase(
            title: "",
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            isFluidWidth: false,
            brandText: nil,
            cornerRadius: CardDS.Metrics.stepCardContentRadius,
            contentLayout: .stepSymmetric,
            top: { EmptyView() },
            bottom: { bottom },
            meta: {
                content
            },
            tags: {
                EmptyView()
            },
            belowTitle: {
                EmptyView()
            }
        )
    }
}


public struct CardNoteBase<Content: View, Bottom: View>: View {
    public let label: String?
    public let topTrailing: AnyView?
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let contentTopSpacer: CGFloat
    public let contentBottomSpacer: CGFloat
    public let contentInsetsY: CGFloat

    private let content: Content
    private let bottom: Bottom

    public init(
        label: String? = nil,
        topTrailing: AnyView? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        contentTopSpacer: CGFloat = 16,
        contentBottomSpacer: CGFloat = 20,
        contentInsetsY: CGFloat = 18,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.label = label
        self.topTrailing = topTrailing
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.contentTopSpacer = contentTopSpacer
        self.contentBottomSpacer = contentBottomSpacer
        self.contentInsetsY = contentInsetsY
        self.content = content()
        self.bottom = bottom()
    }

    public var body: some View {
        // CardBase has fixed top/bottom bands (56/80) tuned for course/lesson cards.
        // For note cards we draw the header + CTA inside the CONTENT zone and compensate the band delta
        // so the note layout stays visually symmetric.
        let bandDelta = CardDS.Metrics.bottomBandHeight - CardDS.Metrics.topBandHeight
        let bandCompTop: CGFloat = max(0, bandDelta / 2)

        return CardBase(
            title: "",
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            isFluidWidth: false,
            brandText: nil,
            top: { EmptyView() },
            bottom: { EmptyView() },
            meta: {
                VStack(spacing: 0) {
                    // header (brand + top-right chips)
                    HStack(alignment: .top, spacing: 8) {
                        TaikaWordmarkLockup(fontSize: 16)

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 0) {
                            if let topTrailing {
                                topTrailing
                            } else if let label, !label.isEmpty {
                                AppMiniChip(
                                    title: label.lowercased(),
                                    style: .neutral
                                ) { }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .topTrailing)
                    }
                    .padding(.top, CardDS.Metrics.noteTopPadding + bandCompTop)
                    .padding(.horizontal, CardDS.Metrics.contentX)

                    // content area (centered)
                    VStack(spacing: 0) {
                        Spacer(minLength: contentTopSpacer)

                        content
                            .frame(maxWidth: .infinity)

                        Spacer(minLength: contentBottomSpacer)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, CardDS.Metrics.contentX)
                    .padding(.vertical, contentInsetsY)

                    // bottom area (CTA / actions)
                    bottom
                        .padding(.horizontal, CardDS.Metrics.contentX)
                        .padding(.bottom, CardDS.Metrics.noteBottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            },
            tags: {
                EmptyView()
            },
            belowTitle: {
                EmptyView()
            }
        )
    }
}

extension CardNoteBase where Bottom == EmptyView {
    public init(
        label: String? = nil,
        topTrailing: AnyView? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        contentTopSpacer: CGFloat = 16,
        contentBottomSpacer: CGFloat = 20,
        contentInsetsY: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            label: label,
            topTrailing: topTrailing,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            contentTopSpacer: contentTopSpacer,
            contentBottomSpacer: contentBottomSpacer,
            contentInsetsY: contentInsetsY,
            content: content,
            bottom: { EmptyView() }
        )
    }
}
// MARK: - Note cards (built on CardNoteBase)

public extension CardDS {
    /// note-course: big title + subtitle (closest to your screenshot)
    struct NoteCourseCardV: View {
        public let label: String
        public let categoryChip: String?
        public let title: String
        public let subtitle: String
        public let progress: Double?
        public let progressText: String?
        public let ctaTitle: String?
        public let onTap: (() -> Void)?
        public let showsProBadge: Bool

        public enum ActionKind: Equatable {
            case add        // not selected yet
            case added      // selected (toggle on)
            case continueCourse
        }

        public let actionKind: ActionKind?
        public let onActionTap: (() -> Void)?

        // legacy initializer (kept for back-compat)
        public init(
            label: String = "заметка",
            categoryChip: String? = nil,
            title: String,
            subtitle: String,
            progressFraction: Double? = nil,
            ctaTitle: String? = nil,
            onCTATap: (() -> Void)? = nil,
            topRightChip: String? = nil,
            showsProBadge: Bool = false,
            actionKind: ActionKind? = nil,
            onActionTap: (() -> Void)? = nil
        ) {
            self.label = label
            self.categoryChip = topRightChip ?? categoryChip
            self.title = title
            self.subtitle = subtitle
            self.progress = progressFraction
            self.progressText = nil
            self.ctaTitle = ctaTitle
            self.onTap = onCTATap
            self.actionKind = actionKind
            self.onActionTap = onActionTap
            self.showsProBadge = showsProBadge
        }

        // new initializer (MainView-friendly)
        public init(
            label: String = "заметка",
            categoryChip: String? = nil,
            title: String,
            subtitle: String,
            progress: Double = 0,
            progressText: String? = nil,
            ctaTitle: String? = nil,
            onTap: @escaping () -> Void,
            topRightChip: String? = nil,
            showsProBadge: Bool = false,
            actionKind: ActionKind? = nil,
            onActionTap: (() -> Void)? = nil
        ) {
            self.label = label
            self.categoryChip = topRightChip ?? categoryChip
            self.title = title
            self.subtitle = subtitle
            self.progress = progress
            self.progressText = progressText
            self.ctaTitle = ctaTitle
            self.onTap = onTap
            self.actionKind = actionKind
            self.onActionTap = onActionTap
            self.showsProBadge = showsProBadge
        }

        private func actionPill(kind: ActionKind, onTap: @escaping () -> Void) -> some View {
            let cfg: (title: String, icon: String, isFilled: Bool, strokeWidth: CGFloat) = {
                switch kind {
                case .add:
                    return ("добавить", "plus", false, 1.5)
                case .added:
                    return ("добавлено", "checkmark", true, 1.0)
                case .continueCourse:
                    return ("продолжить", "play.fill", true, 1.0)
                }
            }()

            return Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: cfg.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(cfg.title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(height: 24)
                .foregroundStyle(cfg.isFilled ? Color.black.opacity(0.85) : CD.ColorToken.text)
                .background(
                    Capsule(style: .continuous)
                        .fill(cfg.isFilled
                              ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                              : AnyShapeStyle(CD.ColorToken.card))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    cfg.isFilled
                                        ? AnyShapeStyle(CD.ColorToken.stroke.opacity(0.25))
                                        : AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.85)),
                                    lineWidth: cfg.strokeWidth
                                )
                        )
                )
            }
            .buttonStyle(.plain)
        }

        private func ctaPill(title: String, onTap: @escaping () -> Void) -> some View {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            }) {
                Text(title.lowercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(height: 32)
                    .background(
                        Capsule(style: .continuous)
                            .fill(CD.ColorToken.card)
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(ThemeManager.shared.currentAccentFill.opacity(0.9), lineWidth: 1.5)
                            )
                    )
            }
            .buttonStyle(.plain)
        }

        public var body: some View {
            let size = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteCardHeight)
            let sectionChrome: CardDS.SectionChrome = .seps
            let chromeStyle: CardDS.ChromeStyle = .cards
            let chipTitle = (categoryChip?.isEmpty == false ? categoryChip! : label)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            CardNoteBase(
                label: nil,
                topTrailing: AnyView(
                    VStack(alignment: .trailing, spacing: 6) {
                        if showsProBadge {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                                .frame(width: 18, height: 18, alignment: .center)
                                .allowsHitTesting(false)
                        }
                        if !chipTitle.isEmpty {
                            AppMiniChip(
                                title: chipTitle,
                                style: .accent
                            ) { }
                            .allowsHitTesting(false)
                        }
                    }
                ),
                size: size,
                sectionChrome: sectionChrome,
                chromeStyle: chromeStyle,
                contentTopSpacer: 16,
                contentBottomSpacer: 20,
                contentInsetsY: 18,
                content: {
                    // main block: centered vertically, left-aligned text (stable for different subtitle lengths)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(title.lowercased())
                                .font(.taikaTitle(24))
                                .foregroundStyle(CD.ColorToken.text)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                                .allowsTightening(true)

                            Text(subtitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let p = progress {
                                if let progressText, !progressText.isEmpty {
                                    Text(progressText)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                        .lineLimit(1)
                                }

                                CourseInlineProgressView(fraction: p)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                },
                bottom: {
                    // cta: bottom-right, aligned with the top-right chips
                    HStack {
                        Spacer(minLength: 0)

                        if let actionKind, let onActionTap {
                            actionPill(kind: actionKind, onTap: onActionTap)
                        } else if let ctaTitle, !ctaTitle.isEmpty, let onTap {
                            ctaPill(title: ctaTitle, onTap: onTap)
                        } else if let ctaTitle, !ctaTitle.isEmpty {
                            // visual-only fallback (no tap)
                            ctaPill(title: ctaTitle, onTap: { })
                                .allowsHitTesting(false)
                        }
                    }
                }
            )
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
        }
    }

    // Back-compat exposure
    typealias NoteCourseCard = NoteCourseCardV
}

// Back-compat (non-namespaced)
public typealias NoteCourseCard = CardDS.NoteCourseCardV

/// note-text: mini lifehack-like block (shorter, denser)
public struct NoteTextCard: View {
    public let label: String
    public let text: String
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle

    public init(
        label: String = "заметка",
        text: String,
        size: CGSize = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteCardHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards
    ) {
        self.label = label
        self.text = text
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
    }

    public var body: some View {
        CardNoteBase(
            label: label,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .lineLimit(8)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// note-step: step-like mini card (same shell as CardNoteBase, step-like content inside)
public struct NoteStepCard: View {
    public let label: String
    public let order: Int?
    public let wordTitle: String
    public let accentSubtitle: String
    public let meta: String

    public let showsProBadge: Bool

    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle

    public init(
        label: String = "шаг",
        order: Int? = nil,
        wordTitle: String,
        accentSubtitle: String,
        meta: String,
        showsProBadge: Bool = true,
        size: CGSize = CGSize(width: CardDS.Metrics.noteCardWidth, height: CardDS.Metrics.noteStepHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards
    ) {
        self.label = label
        self.order = order
        self.wordTitle = wordTitle
        self.accentSubtitle = accentSubtitle
        self.meta = meta
        self.showsProBadge = showsProBadge
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
    }

    public var body: some View {
        CardNoteBase(
            label: nil,
            topTrailing: AnyView(
                Group {
                    if showsProBadge {
                        AppProChip(title: "pro")
                    }
                }
            ),
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            contentTopSpacer: 0,
            contentBottomSpacer: 0,
            contentInsetsY: 12,
            content: {
                // centered step preview text
                VStack(spacing: 10) {
                    Text(wordTitle.lowercased())
                        .font(.taikaTitle(22))
                        .foregroundStyle(CD.ColorToken.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity)

                    Text(accentSubtitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity)

                    Text(meta.lowercased())
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .lineSpacing(1)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            },
            bottom: {
                // bottom chip centered horizontally (improved centering)
                let chipTitle = order.map { "\($0). \(label.lowercased())" } ?? label.lowercased()
                HStack {
                    AppMiniChip(
                        title: chipTitle,
                        style: .neutral
                    ) { }
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, CardDS.Metrics.noteBottomPadding)
            }
        )
    }
}



// shared pill shape for taika bubbles (no tail)
fileprivate struct TaikaBubblePillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corner = min(rect.height / 2, 22)
        let bodyRect = rect.insetBy(dx: 0, dy: 0)
        path.addRoundedRect(
            in: bodyRect,
            cornerSize: CGSize(width: corner, height: corner)
        )
        return path
    }
}

// MARK: - Taika FM message bubble (universal shell). showBubble: false — только маскот и текст, без бабла (фокус на карточках)
public struct TaikaFMBubble<Content: View>: View {
    public let label: String
    public let reactions: [String]
    public let onReactionTap: ((String) -> Void)?
    public let showBubble: Bool
    private let content: Content

    public init(
        label: String = "taika fm",
        reactions: [String] = [],
        onReactionTap: ((String) -> Void)? = nil,
        showBubble: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.reactions = reactions
        self.onReactionTap = onReactionTap
        self.showBubble = showBubble
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("mascot.course")
                .resizable()
                .scaledToFit()
                .scaleEffect(x: -1, y: 1, anchor: .center)
                .frame(width: 60, height: 60)
                .taikaMascotChrome()

            if showBubble {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 52)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(
                        Theme.Surfaces.card(
                            TaikaBubblePillShape()
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320, alignment: .leading)
            } else {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

// MARK: - Search bubble (нативный поиск без маскота, в айдентике приложения)
public struct TaikaSearchBubble: View {
    @Binding public var query: String
    public let placeholder: String
    public let onSubmit: ((String) -> Void)?

    public init(
        query: Binding<String>,
        placeholder: String = "поиск",
        onSubmit: ((String) -> Void)? = nil
    ) {
        self._query = query
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.8))

            TextField("", text: $query, prompt: Text(placeholder).foregroundStyle(CD.ColorToken.textSecondary.opacity(0.75)))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(CD.ColorToken.text)
                .tint(ThemeManager.shared.currentAccentFill)
                .submitLabel(.search)
                .onSubmit { onSubmit?(query) }

            if !query.isEmpty {
                Button(action: {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    query = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Theme.Surfaces.card(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        )
    }
}

// MARK: - Taika FM message bubble typing animation

// lightweight inline chunk model for [[accent]] parsing (shared: CardDS, FavoriteDS)
struct TaikaFMInlineChunk {
    let text: String
    let isAccent: Bool
}

/// Parses `[[…]]` and markdown `**…**` into accent teaching spans (markers stripped).
func taikaFMParseAccentChunks(_ raw: String) -> [TaikaFMInlineChunk] {
    var result: [TaikaFMInlineChunk] = []
    var buffer = ""
    var isAccent = false
    /// Tracks which opener started the current accent span (`[[` vs `**`).
    var accentCloser: String? = nil

    var index = raw.startIndex

    func flushBuffer() {
        guard !buffer.isEmpty else { return }
        result.append(TaikaFMInlineChunk(text: buffer, isAccent: isAccent))
        buffer.removeAll(keepingCapacity: true)
    }

    while index < raw.endIndex {
        if !isAccent, raw[index...].hasPrefix("[[") {
            flushBuffer()
            isAccent = true
            accentCloser = "]]"
            index = raw.index(index, offsetBy: 2)
            continue
        }
        if !isAccent, raw[index...].hasPrefix("**") {
            flushBuffer()
            isAccent = true
            accentCloser = "**"
            index = raw.index(index, offsetBy: 2)
            continue
        }
        if isAccent, let closer = accentCloser, raw[index...].hasPrefix(closer) {
            flushBuffer()
            isAccent = false
            accentCloser = nil
            index = raw.index(index, offsetBy: closer.count)
            continue
        }

        buffer.append(raw[index])
        index = raw.index(after: index)
    }

    flushBuffer()
    return result
}

/// builds styled Text from raw string with [[accent]] / **accent** highlighting (ThemeManager accent). Shared: CardDS, FavoriteDS.
/// baseColor: для лайфхаков передать textSecondary/white, иначе используется text.
func taikaFMStyledText(_ s: String, baseColor: Color? = nil) -> Text {
    let chunks = taikaFMParseAccentChunks(s)
    let mapped = chunks.map { TaikaFMChunk(text: $0.text, isAccent: $0.isAccent) }
    if mapped.isEmpty {
        let nonAccentColor = baseColor ?? CD.ColorToken.text
        return Text(s).foregroundStyle(nonAccentColor)
    }
    return taikaFMStyledText(chunks: mapped, baseColor: baseColor)
}

/// Styled `Text` from pre-parsed FM chunks (same accent rules as string variant).
func taikaFMStyledText(chunks: [TaikaFMChunk], baseColor: Color? = nil) -> Text {
    let nonAccentColor = baseColor ?? CD.ColorToken.text
    guard !chunks.isEmpty else {
        return Text("")
    }
    var result = Text("")
    for chunk in chunks {
        let base = Text(chunk.text)
        if chunk.isAccent {
            // Teaching anchors: brand gradient + bold weight.
            result = result + base
                .fontWeight(.bold)
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
        } else {
            result = result + base.foregroundStyle(nonAccentColor)
        }
    }
    return result
}

public struct TaikaFMBubbleTyping: View {
    public let messages: [String]
    public let reactions: [[String]]
    public let repeats: Bool
    public let showBubble: Bool

    private enum Phase {
        case typing
        case showing
    }

    @State private var phase: Phase = .typing
    @State private var phaseStart: Date = .init()
    @State private var dotsStep: Int = 0
    @State private var currentIndex: Int = 0
    @State private var didCompleteCycle: Bool = false

    // один таймер, который крутит и точки, и фазы
    @State private var timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    /// основной инициализатор: массив сообщений + опциональные реакции. showBubble: false — только маскот и текст
    public init(messages: [String], reactions: [[String]] = [], repeats: Bool = true, showBubble: Bool = true) {
        self.messages = messages
        self.reactions = reactions
        self.repeats = repeats
        self.showBubble = showBubble
    }

    /// совместимость со старым контрактом (один текст, без реакций)
    public init(text: String, repeats: Bool = true, showBubble: Bool = true) {
        self.init(messages: [text], reactions: [], repeats: repeats, showBubble: showBubble)
    }

    /// Никогда не оставляем список пустым: иначе фаза «печатает» зацикливается без текста (см. Step без tip в JSON).
    private var effectiveMessages: [String] {
        if !messages.isEmpty { return messages }
        let scope = TaikaFMData.shared.messages(for: .step)
        if !scope.isEmpty { return scope }
        return ["Листай карточки — рядом [[подсказки]] по уроку."]
    }

    private var currentText: String {
        let msgs = effectiveMessages
        guard !msgs.isEmpty else { return "" }
        let safeIndex = min(currentIndex, msgs.count - 1)
        return msgs[safeIndex]
    }

    private var currentReactions: [String] {
        guard !reactions.isEmpty else { return [] }
        let safeIndex = min(currentIndex, reactions.count - 1)
        return reactions[safeIndex]
    }

    public var body: some View {
        let bubbleReactions: [String] = []
        TaikaFMBubble(label: "taika fm", reactions: [], onReactionTap: nil, showBubble: showBubble) {
            Group {
                switch phase {
                case .typing:
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { idx in
                            Circle()
                                .frame(width: 6, height: 6)
                                .foregroundStyle(CD.ColorToken.text.opacity(0.85))
                                .opacity(dotsStep >= idx ? 1.0 : 0.25)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 13, weight: .regular))

                case .showing:
                    taikaFMStyledText(currentText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.95))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onAppear {
            phase = .typing
            phaseStart = Date()
            dotsStep = 0
            currentIndex = 0
            didCompleteCycle = false
        }
        .onDisappear {
            phase = .typing
            dotsStep = 0
            currentIndex = 0
            didCompleteCycle = false
        }
        .onReceive(timer) { _ in
            let msgs = effectiveMessages
            let now = Date()
            let typingDuration: TimeInterval = 1.8   // сколько таика "печатает"
            let showDuration: TimeInterval = 6.0     // сколько держим показанным текст

            switch phase {
            case .typing:
                // анимируем точки, пока идёт фаза печати
                dotsStep = (dotsStep + 1) % 4
                if now.timeIntervalSince(phaseStart) >= typingDuration {
                    phase = .showing
                    phaseStart = now
                }

            case .showing:
                // если ещё есть следующие сообщения — переходим к следующему
                if now.timeIntervalSince(phaseStart) >= showDuration {
                    let lastIndex = max(0, msgs.count - 1)
                    if currentIndex < lastIndex {
                        currentIndex += 1
                        phase = .typing
                        phaseStart = now
                        dotsStep = 0
                    } else {
                        // достигли конца списка
                        if repeats {
                            currentIndex = 0
                            phase = .typing
                            phaseStart = now
                            dotsStep = 0
                        } else {
                            didCompleteCycle = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Taika FM unified section (все экраны)

public enum TaikaFMDisplayMode {
    /// Одна строка на день / вкладку — без таймера, не дёргает scroll.
    case dailyRotate
    /// Анимация «печатает» + ротация по списку.
    case typing
}

/// Строка бабла без заголовка секции (Step, Speaker, вложенные блоки).
public struct TaikaFMRow: View {
    public var scope: TaikaFMScope
    public var overrideMessages: [String]?
    public var rotationExtra: String
    public var mode: TaikaFMDisplayMode
    public var showBubble: Bool
    public var repeats: Bool

    public init(
        scope: TaikaFMScope,
        overrideMessages: [String]? = nil,
        rotationExtra: String = "",
        mode: TaikaFMDisplayMode = .dailyRotate,
        showBubble: Bool = false,
        repeats: Bool = true
    ) {
        self.scope = scope
        self.overrideMessages = overrideMessages
        self.rotationExtra = rotationExtra
        self.mode = mode
        self.showBubble = showBubble
        self.repeats = repeats
    }

    private var effectiveMessages: [String] {
        if let overrideMessages, !overrideMessages.isEmpty { return overrideMessages }
        return TaikaFMData.shared.rotatedMessages(for: scope, extra: rotationExtra)
    }

    public var body: some View {
        Group {
            switch mode {
            case .dailyRotate:
                TaikaFMBubble(label: "taika fm", reactions: [], onReactionTap: nil, showBubble: showBubble) {
                    taikaFMStyledText(
                        effectiveMessages.first ?? "",
                        baseColor: CD.ColorToken.textSecondary.opacity(0.95)
                    )
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                }
            case .typing:
                TaikaFMBubbleTyping(
                    messages: effectiveMessages,
                    reactions: TaikaFMData.shared.reactionGroups(for: scope),
                    repeats: repeats,
                    showBubble: showBubble
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Секция «ТАЙКА FM» — заголовок + бабл; единый вид на Main, Course, Favorites и т.д.
public struct TaikaFMSection: View {
    public var title: String
    public var scope: TaikaFMScope
    public var overrideMessages: [String]?
    public var rotationExtra: String
    public var mode: TaikaFMDisplayMode
    public var showBubble: Bool
    public var showTitle: Bool
    public var repeats: Bool
    public var horizontalPadding: CGFloat

    public init(
        title: String = "ТАЙКА FM",
        scope: TaikaFMScope,
        overrideMessages: [String]? = nil,
        rotationExtra: String = "",
        mode: TaikaFMDisplayMode = .dailyRotate,
        showBubble: Bool = false,
        showTitle: Bool = true,
        repeats: Bool = true,
        horizontalPadding: CGFloat = CD.Spacing.screen
    ) {
        self.title = title
        self.scope = scope
        self.overrideMessages = overrideMessages
        self.rotationExtra = rotationExtra
        self.mode = mode
        self.showBubble = showBubble
        self.showTitle = showTitle
        self.repeats = repeats
        self.horizontalPadding = horizontalPadding
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: showTitle ? Theme.Layout.sectionTitleToContent : 0) {
            if showTitle {
                Text(title.uppercased())
                    .taikaSectionTitleStyle()
                    .padding(.horizontal, horizontalPadding)
            }

            TaikaFMRow(
                scope: scope,
                overrideMessages: overrideMessages,
                rotationExtra: rotationExtra,
                mode: mode,
                showBubble: showBubble,
                repeats: repeats
            )
            .padding(.horizontal, horizontalPadding)
        }
        .padding(.top, showTitle ? Theme.Layout.sectionTop : 0)
    }
}

// MARK: - Inline progress view for CourseLessonCard + Step completion overlay (единая «полоска зачёта»)
struct CourseInlineProgressView: View {
    let fraction: Double
    let secondaryText: String?
    /// Единый основной gradient для прогресса курса и урока.
    let progressFill: AnyShapeStyle
    /// Компаньон-цвет для компактных текстовых меток.
    let progressColor: Color

    @State private var animatedFraction: Double = 0

    init(
        fraction: Double,
        secondaryText: String? = nil,
        progressFill: AnyShapeStyle = AnyShapeStyle(ThemeManager.shared.currentAccentFill),
        progressColor: Color = ThemeManager.shared.currentAccentTintColor
    ) {
        self.fraction = fraction
        self.secondaryText = secondaryText
        self.progressFill = progressFill
        self.progressColor = progressColor
    }

    var body: some View {
        let clamped = fraction.clamped01
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let barH: CGFloat = 6
                RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: w, height: barH)
                    .overlay(
                        RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                            .fill(progressFill)
                            .frame(
                                width: max(0, w * CGFloat(animatedFraction)),
                                height: barH
                            ),
                        alignment: .leading
                    )
            }
            .frame(height: 12)

            Text("\(Int((animatedFraction * 100).rounded()))% пройдено")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(animatedFraction >= 0.999 ? progressColor.opacity(0.92) : CD.ColorToken.textSecondary.opacity(0.9))
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.45), value: animatedFraction)

            if let secondaryText, !secondaryText.isEmpty {
                Text(secondaryText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(animatedFraction >= 0.999 ? progressColor.opacity(0.84) : CD.ColorToken.textSecondary.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .onAppear {
            animatedFraction = 0
            withAnimation(.spring(response: 0.72, dampingFraction: 0.84).delay(0.08)) {
                animatedFraction = clamped
            }
        }
        .onChange(of: fraction) { _, new in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                animatedFraction = new.clamped01
            }
        }
    }
}

// MARK: - Pro wash (как Main «подборка дня»)
/// Split into tiny views + method-ref TimelineView so the type-checker stays fast.
private struct CourseProCardWash: View {
    var cornerRadius: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            washLayers(at: context.date)
        }
    }

    private func washLayers(at date: Date) -> CourseProCardWashLayers {
        CourseProCardWashLayers(
            cornerRadius: cornerRadius,
            phase: date.timeIntervalSinceReferenceDate * 0.22,
            tint: ThemeManager.shared.currentAccentTintColor
        )
    }
}

private struct CourseProCardWashLayers: View {
    var cornerRadius: CGFloat
    var phase: Double
    var tint: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(washGradient)
            waveCanvas.mask(waveMask)
        }
        .clipShape(shape)
    }

    private var washGradient: LinearGradient {
        LinearGradient(
            colors: [tint.opacity(0.16), Color.clear, tint.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var waveMask: LinearGradient {
        LinearGradient(
            colors: [.clear, .white.opacity(0.55), .white],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var waveCanvas: some View {
        Canvas { context, size in
            CourseProCardWashDrawer.drawWaves(
                context: context,
                size: size,
                phase: phase,
                tint: tint
            )
        }
    }
}

private enum CourseProCardWashDrawer {
    static func drawWaves(
        context: GraphicsContext,
        size: CGSize,
        phase: Double,
        tint: Color
    ) {
        for i in 0..<6 {
            let t = Double(i) / 5.0
            var path = Path()
            let y0 = size.height * (0.35 + t * 0.45)
            let amp = 8.0 + t * 10.0
            var x: CGFloat = 0
            while x <= size.width {
                let xn = Double(x / max(size.width, 1))
                let y = y0 + sin((xn * 2.2 + t + phase) * .pi * 2) * amp
                let pt = CGPoint(x: x, y: y)
                if x == 0 {
                    path.move(to: pt)
                } else {
                    path.addLine(to: pt)
                }
                x += 4
            }
            let opacity = 0.10 + (1 - t) * 0.12
            context.stroke(path, with: .color(tint.opacity(opacity)), lineWidth: 0.9)
        }
    }
}

/// Вовлекающая корона Taika+ — лёгкий pulse + soft glow, без текста «Taika+».
private struct CourseProAnimatedCrown: View {
    var onTap: (() -> Void)? = nil
    var size: CGFloat = 28

    @State private var pulse = false

    var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        Button {
            onTap?()
        } label: {
            ZStack {
                Circle()
                    .fill(accent.opacity(pulse ? 0.24 : 0.10))
                    .frame(width: size + 10, height: size + 10)
                    .scaleEffect(pulse ? 1.1 : 0.92)
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(accent)
                    .scaleEffect(pulse ? 1.06 : 0.96)
            }
            .frame(width: size + 10, height: size + 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .allowsHitTesting(onTap != nil)
        .accessibilityLabel("Taika+")
        .accessibilityHint(onTap == nil ? "" : "Открыть Taika+")
        .onAppear {
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Ready wrapper for Course/Lesson cards (uses AppDS atoms)
private struct CardBackActionButtonStyle: ButtonStyle {
    let isPrimary: Bool
    var isMastery: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isMastery ? AnyShapeStyle(TaikaMasteryTokens.greenGradient) : AnyShapeStyle(Color.white.opacity(0.86)))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isMastery
                        ? AnyShapeStyle(TaikaMasteryTokens.greenGradient.opacity(0.14))
                        : AnyShapeStyle(Color.clear)
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isMastery
                        ? AnyShapeStyle(TaikaMasteryTokens.greenGradient)
                        : AnyShapeStyle(Color.white.opacity(0.28)),
                        lineWidth: 1
                    )
            )
            .contentShape(Capsule(style: .continuous))
            .opacity(configuration.isPressed ? 0.68 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

fileprivate struct CDOrganicWaveShape: Shape {
    var phase: CGFloat
    var seed: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let shift = sin(phase * .pi * 2 + seed) * 18
        let y = rect.height * (0.68 + 0.08 * sin(seed))
        var path = Path()
        path.move(to: CGPoint(x: -28, y: y + shift))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.54 + shift * 0.35),
            control1: CGPoint(x: rect.width * 0.14, y: rect.height * 0.42 - shift),
            control2: CGPoint(x: rect.width * 0.20, y: rect.height * 0.82 + shift)
        )
        path.addCurve(
            to: CGPoint(x: rect.width + 28, y: rect.height * 0.34 - shift * 0.25),
            control1: CGPoint(x: rect.width * 0.60, y: rect.height * 0.28 + shift),
            control2: CGPoint(x: rect.width * 0.78, y: rect.height * 0.56 - shift)
        )
        return path
    }
}

fileprivate struct CDOrganicLearnedTreatment: View {
    let glow: Color
    let isFavorite: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous)
                .fill(Color.black.opacity(0.12))

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [glow.opacity(0.16), glow.opacity(0.035), Color.clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 132
                    )
                )
                .frame(width: 210, height: 150)
                .blur(radius: 18)
                .offset(x: 70, y: -70)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [glow.opacity(0.09), Color.clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 118
                    )
                )
                .frame(width: 180, height: 130)
                .blur(radius: 22)
                .offset(x: -74, y: 78)

            if isFavorite {
                ForEach(Array([0.55, 1.7, 3.1].enumerated()), id: \.offset) { index, seed in
                    CDOrganicWaveShape(
                        phase: reduceMotion ? 0 : phase,
                        seed: seed
                    )
                    .stroke(
                        AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(index == 1 ? 0.34 : 0.18)),
                        style: StrokeStyle(lineWidth: index == 1 ? 1.2 : 0.72, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: index == 1 ? 0.1 : 0.45)
                    .offset(x: CGFloat(index - 1) * 14, y: CGFloat(index - 1) * 14)
                }
            }

            ForEach(Array([0.2, 1.35, 2.5, 3.7, 4.9].enumerated()), id: \.offset) { index, seed in
                CDOrganicWaveShape(
                    phase: reduceMotion ? 0 : phase,
                    seed: seed
                )
                .stroke(
                    glow.opacity(index == 2 ? 0.36 : 0.16),
                    style: StrokeStyle(
                        lineWidth: index == 2 ? 1.45 : 0.82,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .blur(radius: index == 2 ? 0.12 : 0.5)
                .scaleEffect(1 + CGFloat(index - 2) * 0.028)
                .offset(x: index.isMultiple(of: 2) ? -10 : 10, y: CGFloat(index - 2) * 6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous))
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

private struct CDCourseStatusPill: View {
    let title: String
    let icon: String
    let trailingIcon: String

    init(title: String, icon: String, trailingIcon: String = "arrow.right") {
        self.title = title
        self.icon = icon
        self.trailingIcon = trailingIcon
    }

    var body: some View {
        HStack(spacing: 6) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
            }
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .allowsTightening(true)
                .layoutPriority(1)
            Image(systemName: trailingIcon)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(Color.black.opacity(0.92))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(AnyShapeStyle(TaikaMasteryTokens.greenBadgeGradient))
        )
        .shadow(
            color: TaikaMasteryTokens.green.opacity(0.28),
            radius: 8,
            y: 2
        )
    }
}

public struct CourseLessonCard: View {
    // Content
    public let title: String
    public let subtitle: String?
    public let lessonsCount: Int?
    public let durationText: String?
    public let statusKind: AppStatusKind?
    /// Optional explicit status copy used when completion needs to be immediately legible.
    public let statusChipTitle: String?
    public let courseCategory: String?
    public let isPro: Bool
    public let showProCrown: Bool
    public let tags: [String]
    public let brandText: String?

    // Layout
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let accentTreatment: CardDS.AccentTreatment

    // CTA
    public let primaryCTA: AppCTAType
    public let scale: AppCTAScale
    /// Informational cards can reuse the canonical course surface without implying a launch action.
    public let showsPrimaryAction: Bool

    // Actions
    public let onPrimaryTap: (() -> Void)?

    // Icon states (visual-only here)
    public let isFavoriteActive: Bool
    public let isConsoleEnabled: Bool
    // Drives console availability based on lesson completion
    public let completionFraction: Double?

    /// Optional row of stars under the top-right status chip (used for course cards).
    /// When provided, we render up to `maxStars` filled stars using the given 0...1 fraction.
    public let statusStarsFraction: Double?

    /// Optional averaged pronunciation score for this course/lesson (0...100).
    /// Rendered on the back face mastery summary.
    public let pronunciationPercent: Int?
    /// Optional real reinforcement score (0...100), derived from game sessions.
    public let reinforcementScore: Int?
    /// Number of real reinforcement sessions represented by reinforcementScore.
    public let reinforcementSessions: Int
    /// Number of source cards encountered in Game Park for this course.
    public let reinforcementCoveredCards: Int

    // MARK: - Optional flip (course grade sheet vs lesson reminders)
    public enum BackFaceKind: Equatable {
        /// Default: reinforcement / pronunciation / dialogue summary (course cards).
        case courseGradeSheet
        /// Lesson card: short actionable reminders (no duplicate course metrics).
        case lessonReminders(lines: [String])
        /// Completed lesson: compact progress summary with one primary reinforcement action.
        case lessonCompletion
    }

    // MARK: - Optional flip (course -> "what to do next" back face)
    public let flipEnabled: Bool
    public let backFaceKind: BackFaceKind
    /// Stable course id key for cross-feature aggregates (reinforcement, speaker averages, etc.).
    /// When nil, back-face grade sheet will fall back to placeholders.
    public let courseKey: String?
    /// текущий статус подписки юзера (для PRO-gating строк на back-face)
    public let isProUser: Bool
    /// Called when user taps a checklist item on the back face.
    /// Available only when `flipEnabled == true`.
    /// Parameter is `gameType` (raw value from `GameModeType`).
    public let onBackSelectGameMode: ((String) -> Void)?
    /// Optional post-lesson actions shown on the completed card back face.
    public let backPrimaryActionTitle: String?
    public let onBackPrimaryAction: (() -> Void)?
    public let backSecondaryActionTitle: String?
    public let onBackSecondaryAction: (() -> Void)?

    // Controls whether we show inline progress on the card face
    public let showsInlineProgress: Bool

    // Optional favorite counter (if set, we show counter instead of toggle)
    public let favoriteCount: Int?

    // Optional taps (can be nil to keep visual-only)
    public let onFavoriteTap: (() -> Void)?
    public let onConsoleTap: (() -> Void)?
    /// Открыть Спикер для практики произношения по этому уроку (иконка mic вместо info).
    public let onSpeakerTap: (() -> Void)?
    /// Открыть превью курса (описание + «Открыть курс»). Иконка info на карточке.
    public let onTapInfo: (() -> Void)?

    // Icons
    public let showFavorite: Bool
    public let showConsole: Bool

    // Optional visual modifiers for carousel (non-breaking; default = identity)
    public let visualScale: CGFloat
    public let visualOpacity: CGFloat
    public let visualRotateY: Double

    public init(
        title: String,
        subtitle: String? = nil,
        lessonsCount: Int? = nil,
        durationText: String? = nil,
        statusKind: AppStatusKind? = nil,
        statusChipTitle: String? = nil,
        courseCategory: String? = nil,
        isPro: Bool = false,
        showProCrown: Bool = false,
        tags: [String] = [],
        brandText: String? = nil,
        size: CGSize = CGSize(width: CardDS.Metrics.courseWidth, height: CardDS.Metrics.courseHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        accentTreatment: CardDS.AccentTreatment = .none,
        primaryCTA: AppCTAType = .start,
        scale: AppCTAScale = .s,
        showsPrimaryAction: Bool = true,
        showFavorite: Bool = true,
        showConsole: Bool = true,
        onPrimaryTap: (() -> Void)? = nil,
        isFavoriteActive: Bool = false,
        isConsoleEnabled: Bool = false,
        completionFraction: Double? = nil,
        statusStarsFraction: Double? = nil,
        pronunciationPercent: Int? = nil,
        reinforcementScore: Int? = nil,
        reinforcementSessions: Int = 0,
        reinforcementCoveredCards: Int = 0,
        flipEnabled: Bool = false,
        backFaceKind: BackFaceKind = .courseGradeSheet,
        courseKey: String? = nil,
        isProUser: Bool = false,
        onBackSelectGameMode: ((String) -> Void)? = nil,
        backPrimaryActionTitle: String? = nil,
        onBackPrimaryAction: (() -> Void)? = nil,
        backSecondaryActionTitle: String? = nil,
        onBackSecondaryAction: (() -> Void)? = nil,
        favoriteCount: Int? = nil,
        onFavoriteTap: (() -> Void)? = nil,
        onConsoleTap: (() -> Void)? = nil,
        onSpeakerTap: (() -> Void)? = nil,
        onTapInfo: (() -> Void)? = nil,
        showsInlineProgress: Bool = false,
        visualScale: CGFloat = 1.0,
        visualOpacity: CGFloat = 1.0,
        visualRotateY: Double = 0.0
    ) {
        self.title = title
        self.subtitle = subtitle
        self.lessonsCount = lessonsCount
        self.durationText = durationText
        self.statusKind = statusKind
        self.statusChipTitle = statusChipTitle
        self.courseCategory = courseCategory
        self.isPro = isPro
        self.showProCrown = showProCrown
        self.tags = tags
        self.brandText = brandText
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.accentTreatment = accentTreatment
        self.primaryCTA = primaryCTA
        self.scale = scale
        self.showsPrimaryAction = showsPrimaryAction
        self.showFavorite = showFavorite
        self.showConsole = showConsole
        self.onPrimaryTap = onPrimaryTap
        self.isFavoriteActive = isFavoriteActive
        self.isConsoleEnabled = isConsoleEnabled
        self.completionFraction = completionFraction
        self.statusStarsFraction = statusStarsFraction
        self.pronunciationPercent = pronunciationPercent
        self.reinforcementScore = reinforcementScore
        self.reinforcementSessions = max(0, reinforcementSessions)
        self.reinforcementCoveredCards = max(0, reinforcementCoveredCards)
        self.flipEnabled = flipEnabled
        self.backFaceKind = backFaceKind
        self.courseKey = courseKey
        self.isProUser = isProUser
        self.onBackSelectGameMode = onBackSelectGameMode
        self.backPrimaryActionTitle = backPrimaryActionTitle
        self.onBackPrimaryAction = onBackPrimaryAction
        self.backSecondaryActionTitle = backSecondaryActionTitle
        self.onBackSecondaryAction = onBackSecondaryAction
        self.favoriteCount = favoriteCount
        self.onFavoriteTap = onFavoriteTap
        self.onConsoleTap = onConsoleTap
        self.onSpeakerTap = onSpeakerTap
        self.onTapInfo = onTapInfo
        self.showsInlineProgress = showsInlineProgress
        self.visualScale = visualScale
        self.visualOpacity = visualOpacity
        self.visualRotateY = visualRotateY
    }

    @State private var isFlipped: Bool = false
    @State private var lockedActionHint: String? = nil
    @State private var lockedHintHideTask: DispatchWorkItem? = nil
    @Environment(\.stepCarouselCellSize) private var stepCarouselCellSize

    private func showLockedActionHint(_ text: String) {
        lockedHintHideTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            lockedActionHint = text
        }
        let work = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.22)) {
                lockedActionHint = nil
            }
        }
        lockedHintHideTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }

    private var showsProWash: Bool { isPro || showProCrown }

    @ViewBuilder
    private var courseProWashOverlay: some View {
        if showsProWash {
            CourseProCardWash(cornerRadius: CardDS.Metrics.radius)
                .clipShape(RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    private var courseProShadowColor: Color {
        showsProWash ? ThemeManager.shared.currentAccentTintColor.opacity(0.18) : .clear
    }

    private var courseProShadowRadius: CGFloat { showsProWash ? 12 : 0 }
    private var courseProShadowY: CGFloat { showsProWash ? 5 : 0 }

    private var effectiveAccentTreatment: CardDS.AccentTreatment {
        if case .none = accentTreatment {
            if statusKind == .completed {
                return .taikaValues(
                    fill: AnyShapeStyle(TaikaMasteryTokens.greenGradient),
                    glow: TaikaMasteryTokens.greenGlow
                )
            }
            if isFavoriteActive {
                return .taikaValues(
                    fill: AnyShapeStyle(ThemeManager.shared.currentAccentFill),
                    glow: ThemeManager.shared.currentAccentTintColor
                )
            }
        }
        return accentTreatment
    }

    @ViewBuilder
    private var accentTreatmentOverlay: some View {
        switch effectiveAccentTreatment {
        case .none:
            EmptyView()
        case let .taikaValues(_, glow):
            CDOrganicLearnedTreatment(
                glow: glow,
                isFavorite: isFavoriteActive
            )
        }
    }

    public var body: some View {
        let resolvedSize: CGSize = stepCarouselCellSize ?? size

        let consoleIsEnabled = isConsoleEnabled || ((completionFraction ?? 0) >= 0.999)
        // Pro-карточка: либо чип Taika+ (не открыт), либо статус (уже открыт) — никогда вместе.
        let courseOpened =
            (completionFraction ?? 0) > 0.01
            || statusKind == .inProgress
            || statusKind == .completed
        let showProTeaserChip = isPro && !showProCrown && !courseOpened
        let showStatusOnFace = !showProCrown && !showProTeaserChip && statusKind != nil
        let progressFraction: Double? = {
            guard showsInlineProgress else { return nil }
            if showProCrown || showProTeaserChip { return nil }
            // Detailed mastery belongs to the back-side course grade sheet.
            if statusKind == .completed { return nil }
            return (completionFraction ?? 0).clamped01
        }()
        @ViewBuilder
        func statusControl(isBack: Bool) -> some View {
            if showStatusOnFace, let statusKind {
                Button {
                    if flipEnabled {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                            isFlipped.toggle()
                        }
                    }
                } label: {
                    if statusKind == .completed && backFaceKind == .courseGradeSheet {
                        CDCourseStatusPill(
                            title: isBack ? "ЗАКРЕПЛЕНИЕ" : "КУРС ПРОЙДЕН",
                            icon: "",
                            trailingIcon: isBack ? "arrow.left" : "arrow.right"
                        )
                    } else if statusKind == .completed && backFaceKind == .lessonCompletion {
                        CDCourseStatusPill(
                            title: "УРОК ПРОЙДЕН",
                            icon: "checkmark",
                            trailingIcon: isBack ? "arrow.left" : "arrow.right"
                        )
                    } else if statusKind == .completed {
                        AppStatusChip(kind: .completed, title: "УРОК ПРОЙДЕН")
                    } else {
                        AppStatusChip(kind: statusKind, title: statusChipTitle)
                    }
                }
                .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
                .accessibilityLabel(isBack ? "Вернуться к лицевой стороне урока" : "Открыть зачёт урока")
            }
        }

        @ViewBuilder
        func topContent(isBack: Bool) -> some View {
            if isBack {
                HStack(alignment: .center, spacing: 8) {
                    Spacer(minLength: 0)
                    statusControl(isBack: true)
                }
                .padding(.top, 18)
                .padding(.bottom, 0)
            } else {
                HStack(alignment: .center, spacing: 8) {
                    if statusKind == .completed && (backFaceKind == .courseGradeSheet || backFaceKind == .lessonCompletion) {
                        statusControl(isBack: false)
                        Spacer(minLength: 0)
                    } else {
                        TaikaWordmarkLockup(
                            fontSize: 16,
                            accentColor: statusKind == .completed ? TaikaMasteryTokens.green : nil
                        )
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        if statusKind != .completed, let onTapInfo {
                            Button(action: onTapInfo) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.9)))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                        }

                        if showProCrown {
                            CourseProAnimatedCrown(onTap: { onPrimaryTap?() })
                        } else if showProTeaserChip {
                            CourseProAnimatedCrown(onTap: nil)
                        } else if !(statusKind == .completed && (backFaceKind == .courseGradeSheet || backFaceKind == .lessonCompletion)) {
                            statusControl(isBack: false)
                        }
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 0)
            }
        }

        @ViewBuilder
        func bottomContent() -> some View {
            // Locked hint replaces the whole console row in-place (not a floating toast).
            if let lockedActionHint {
                Button {
                    lockedHintHideTask?.cancel()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        self.lockedActionHint = nil
                    }
                } label: {
                    Text(lockedActionHint)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(PD.ColorToken.chip.opacity(0.96))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .accessibilityLabel(lockedActionHint)
                .accessibilityHint("Закрыть")
            } else if showsPrimaryAction {
                // Порядок: Play → лайки → консоль → Спикер
                HStack(spacing: 20) {
                    AppCardIconButton(
                        kind: .play,
                        forceMasteryGreen: statusKind == .completed,
                        onTap: { onPrimaryTap?() }
                    )
                    .contentShape(Rectangle())
                    .opacity(showProCrown ? 0.72 : 1)
                    .accessibilityLabel(showProCrown ? "Открыть с Taika+" : "Открыть курс")
                    if showFavorite {
                        if let count = favoriteCount {
                            AppFavCounterMinimal(
                                count: count,
                                onTap: { onFavoriteTap?() }
                            )
                        } else {
                            AppCardIconButton(
                                kind: .favorite,
                                isActive: isFavoriteActive,
                                onTap: { onFavoriteTap?() }
                            )
                        }
                    }
                    if showConsole {
                        AppCardIconButton(
                            kind: .console,
                            isEnabled: consoleIsEnabled,
                            forceMasteryGreen: statusKind == .completed,
                            onLockedTap: {
                                showLockedActionHint("Игры откроются после первого урока")
                            },
                            onTap: { onConsoleTap?() }
                        )
                    }
                    if let onSpeaker = onSpeakerTap {
                        AppCardIconButton(
                            kind: .speaker,
                            isEnabled: consoleIsEnabled,
                            forceMasteryGreen: statusKind == .completed && consoleIsEnabled,
                            onLockedTap: {
                                showLockedActionHint("Спикер курса откроется после первого урока")
                            },
                            onTap: onSpeaker
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 18)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }

        func metaContent(isBack: Bool) -> some View {
            HStack(spacing: 8) {
                if !isBack, statusKind != .completed, let courseCategory, !courseCategory.isEmpty {
                    AppMiniChip(
                        title: courseCategory.lowercased(),
                        style: .neutral
                    ) { }
                }
            }
            .padding(.bottom, 2)
        }

        func tagsContent(isBack: Bool) -> some View {
            HStack(spacing: 10) {
                if !isBack {
                    ForEach(tags, id: \.self) { t in
                        Text(t)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                }
            }
        }

        func planRow(icon: String, title: String, subtitle: String?, onTap: @escaping () -> Void) -> some View {
            Button { onTap() } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .frame(width: 22, alignment: .center)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
        }

        func gradeMetric(value: String, label: String) -> some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(Theme.Fonts.metric(17))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .kerning(0.45)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        func gradeRow(title: String, value: String?) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .kerning(0.35)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let value, !value.isEmpty {
                    Text(value)
                        .font(Theme.Fonts.metric(18))
                        .foregroundStyle(value == "ещё нет" ? AnyShapeStyle(Color.white.opacity(0.52)) : AnyShapeStyle(Color.white.opacity(0.98)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 5)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }
        }

        @ViewBuilder
        func backPlanBelowTitle() -> some View {
            switch backFaceKind {
            case .lessonCompletion:
                VStack(alignment: .leading, spacing: 10) {
                    Text("ЗАЧЁТ ПО УРОКУ")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.76))
                        .textCase(.uppercase)
                        .kerning(0.7)

                    gradeRow(title: "Пройдено", value: "100%")
                    gradeRow(title: "Произношение", value: pronunciationPercent.map { "\($0)%" } ?? "ещё нет")
                    gradeRow(
                        title: "Закрепление",
                        value: reinforcementScore.map { "\($0)%" } ?? (reinforcementSessions > 0 ? "\(reinforcementSessions) игр" : "доступно")
                    )
                }

            case .lessonReminders(let lines):
                VStack(alignment: .leading, spacing: 6) {
                    Text("напоминание")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.96))

                    Text("Закрепляй урок через консоль внизу экрана курса — микрофон и мини‑игры.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .lineSpacing(1)
                        .lineLimit(3)

                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(TaikaMasteryTokens.green.opacity(0.62))
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(line)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if backPrimaryActionTitle != nil || backSecondaryActionTitle != nil {
                        HStack(spacing: 8) {
                            if let title = backPrimaryActionTitle, let action = onBackPrimaryAction {
                                Button(title, action: action)
                                    .buttonStyle(CardBackActionButtonStyle(isPrimary: true))
                            }
                            if let title = backSecondaryActionTitle, let action = onBackSecondaryAction {
                                Button(title, action: action)
                                    .buttonStyle(CardBackActionButtonStyle(isPrimary: false))
                            }
                        }
                        .padding(.top, 6)
                    }
                }

            case .courseGradeSheet:
                VStack(alignment: .leading, spacing: 9) {
                    Spacer(minLength: 16)
                    Text("Закрепи пройденный курс")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(reinforcementScore == nil ? "Результат курса готов. Теперь удержи навык практикой." : "Курс пройден. Подними результат коротким повторением.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.76))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        gradeMetric(value: reinforcementScore.map { "\($0)%" } ?? "—", label: "игры")
                        gradeMetric(value: pronunciationPercent.map { "\($0)%" } ?? "—", label: "голос")
                        gradeMetric(value: reinforcementCoveredCards > 0 ? "\(reinforcementCoveredCards)" : "—", label: "карточки")
                    }
                    .padding(.top, 2)

                    Text("Следующий шаг")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.64))
                        .padding(.top, 2)

                    Spacer(minLength: 10)
                    if let action = onBackSelectGameMode {
                        Button {
                            action("match")
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "gamecontroller.fill")
                                Text("Закрепить в игре")
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(AnyShapeStyle(TaikaMasteryTokens.green))
                        }
                        .buttonStyle(CardBackActionButtonStyle(isPrimary: true, isMastery: true))
                    }

                    if let action = onSpeakerTap {
                        Button {
                            action()
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "mic.fill")
                                Text("Тренировать в Спикере")
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(AnyShapeStyle(Color.white.opacity(0.94)))
                        }
                        .buttonStyle(CardBackActionButtonStyle(isPrimary: false, isMastery: false))
                    }
                }
            }
        }

        let frontCard = CardBase(
            title: title.lowercased(),
            subtitle: subtitle,
            size: resolvedSize,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: true,
            isFluidWidth: false,
            brandText: brandText,
            top: { topContent(isBack: false) },
            bottom: { bottomContent() },
            meta: { metaContent(isBack: false) },
            tags: { tagsContent(isBack: false) },
            belowTitle: {
                // Locked / teaser Pro — продающая подпись как Main-подборка, без «0% пройдено».
                if showProCrown {
                    Text("откроется с Taika+")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                } else if showProTeaserChip {
                    Text(isProUser ? "ещё не начат" : "расширь практику с Taika+")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                } else if let f = progressFraction {
                    let isLearned = f >= 0.999
                    let showPlanHint = flipEnabled && !isFlipped && isLearned
                    CourseInlineProgressView(
                         fraction: f,
                        secondaryText: isLearned
                            ? "выучено · закрепление доступно"
                            : (showPlanHint ? "закрепление доступно" : nil),
                        progressFill: AnyShapeStyle(ThemeManager.shared.currentAccentFill),
                        progressColor: ThemeManager.shared.currentAccentTintColor
                    )
                }
            }
        )

        let backCard = CardBase(
            title: title.lowercased(),
            subtitle: nil,
            size: resolvedSize,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            isFluidWidth: false,
            brandText: brandText,
            top: { topContent(isBack: true) },
            bottom: { EmptyView() },
            meta: { metaContent(isBack: true) },
            tags: { tagsContent(isBack: true) },
            belowTitle: { backPlanBelowTitle() }
        )

        return Group {
            if flipEnabled {
                Group {
                    if isFlipped {
                        // Counter-rotate the back face so text doesn't mirror.
                        // Parent rotation (Y: 180) flips the entire view; back face needs +180 to face front.
                        backCard
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    } else {
                        frontCard
                    }
                }
                // Internal card treatment belongs to the same rotating surface as the face.
                // This keeps the organic waves physically attached during the flip.
                .overlay { accentTreatmentOverlay }
                .overlay { courseProWashOverlay }
                // Only one face is measured at a time (prevents layout shifts).
                .transition(.opacity)
                .compositingGroup()
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.9)
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: isFlipped)
            } else {
                frontCard
                    .overlay { accentTreatmentOverlay }
                    .overlay { courseProWashOverlay }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: lockedActionHint)
        .frame(width: resolvedSize.width, height: resolvedSize.height)
        .id(courseKey ?? title)
        .compositingGroup()
        // Internal treatments are attached above to the rotating face/back surface.
        .clipShape(RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous))
        .shadow(color: courseProShadowColor, radius: courseProShadowRadius, y: courseProShadowY)
        .scaleEffect(visualScale)
        .rotation3DEffect(.degrees(flipEnabled ? 0 : visualRotateY), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
        .opacity(visualOpacity)
        .padding(.horizontal, 0)
        // Prevent state leak between reused carousel cells.
        .onChange(of: flipEnabled) { _ in isFlipped = false }
        .onChange(of: title) { _ in isFlipped = false }
        .onChange(of: courseKey) { _ in isFlipped = false }
    }
}

// MARK: - Thailand calendar helpers (UI must match MainManager)
fileprivate enum BangkokCalendar {
    static let tz: TimeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
    static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }()
}

// MARK: - WeeklyResumeStrip (7-day calendar style “Continue”)

// MARK: - WeeklyResumeStrip (7-day calendar style “Continue”)

/// Lightweight model for a single day cell.
public struct WeeklyResumeItem: Identifiable, Hashable {
    public let id = UUID()
    public let weekdayShort: String    // "Пн", "Вт", ...
    public let date: Date              // for comparisons
    public let title: String?          // optional short title
    public let progress: Double?       // 0...1 or nil
    public let secondaryTitle: String?
    public let secondaryProgress: Double?
    public let coursesCount: Int?
    public let isToday: Bool
    public let isEmpty: Bool
    /// optional daily counters for calendar card footer
    public let learnedCount: Int?
    public let favCount: Int?
    public let audioMinutes: Int?

    public var dayKey: String {
        let cal = BangkokCalendar.cal
        let dc = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", dc.year ?? 0, dc.month ?? 0, dc.day ?? 0)
    }

    public init(
        weekdayShort: String,
        date: Date,
        title: String? = nil,
        progress: Double? = nil,
        secondaryTitle: String? = nil,
        secondaryProgress: Double? = nil,
        coursesCount: Int? = nil,
        isToday: Bool = false,
        isEmpty: Bool = false,
        learnedCount: Int? = nil,
        favCount: Int? = nil,
        audioMinutes: Int? = nil
    ) {
        self.weekdayShort = weekdayShort
        self.date = date
        self.title = title
        self.progress = progress
        self.secondaryTitle = secondaryTitle
        self.secondaryProgress = secondaryProgress
        self.coursesCount = coursesCount
        self.isToday = isToday
        self.isEmpty = isEmpty
        self.learnedCount = learnedCount
        self.favCount = favCount
        self.audioMinutes = audioMinutes
    }
}

public enum WeeklyResumeLayout { case board, row, carousel }

/// `.full` — большие day-board ячейки; `.compact` — pill-ряд для Main.
public enum WeeklyResumeCellStyle { case full, compact }

// lightweight day summary adapter so CardDS can render the same panel as MainDS without importing it
public struct CardDS_DaySummary {
    public let learned: Int
    public let favs: Int
    public let audioMinutes: Int
    public init(learned: Int, favs: Int, audioMinutes: Int) {
        self.learned = learned
        self.favs = favs
        self.audioMinutes = audioMinutes
    }
}

// Helper to avoid overlay type-inference ambiguity
fileprivate struct DayBadgeBorder: View {
    let isToday: Bool
    var body: some View {
        Capsule()
            .stroke(isToday ? Color.black.opacity(0.10) : Color.white.opacity(0.10), lineWidth: 1)
    }
}

// MARK: - Weekly calendar atoms (exposed for reuse in MainDS)
public struct WeeklyDayBadge: View {
    let item: WeeklyResumeItem
    let isSelected: Bool
    public var body: some View {
        // Precompute values to help the type-checker
        let dayNumber = BangkokCalendar.cal.component(.day, from: item.date)
        let isToday = BangkokCalendar.cal.isDateInToday(item.date)

        HStack(spacing: 6) {
            Text(item.weekdayShort.uppercased())
                .font(.system(size: 11, weight: .bold))
            Text("\(dayNumber)")
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.9)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(CD.ColorToken.text)
        .background(
            Capsule(style: .continuous)
                .fill(CD.ColorToken.card)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(CD.ColorToken.stroke.opacity(0.35), lineWidth: 1)
                )
        )
        .overlay(
            Group {
                if isSelected {
                    Capsule(style: .continuous)
                        .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 2)
                }
            }
        )
    }
}

fileprivate struct WeeklyResumePill: View {
    let item: WeeklyResumeItem
    let isSelected: Bool
    let onTap: (WeeklyResumeItem) -> Void
    var body: some View {
        Button(action: { onTap(item) }) {
            WeeklyDayBadge(item: item, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.weekdayShort), \(BangkokCalendar.cal.component(.day, from: item.date))"))
    }
}

/// Компактный день для горизонтального ряда на Main.
public struct WeeklyResumeCompactCell: View {
    let item: WeeklyResumeItem
    let isSelected: Bool
    let onTap: (WeeklyResumeItem) -> Void

    public init(item: WeeklyResumeItem, isSelected: Bool, onTap: @escaping (WeeklyResumeItem) -> Void) {
        self.item = item
        self.isSelected = isSelected
        self.onTap = onTap
    }

    private var hasActivity: Bool {
        (item.progress ?? 0) > 0.0001
            || (item.learnedCount ?? 0) > 0
            || (item.favCount ?? 0) > 0
            || (item.audioMinutes ?? 0) > 0
    }

    private var isToday: Bool { BangkokCalendar.cal.isDateInToday(item.date) }

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        let weekdayColor: Color = (isSelected || isToday)
            ? CD.ColorToken.text
            : CD.ColorToken.textSecondary.opacity(0.85)
        let dotFill: Color = hasActivity
            ? CD.ColorToken.text
            : CD.ColorToken.textSecondary.opacity(0.25)
        let strokeColor: Color = isSelected
            ? CD.ColorToken.text.opacity(0.35)
            : CD.ColorToken.stroke.opacity(0.35)

        Button(action: { onTap(item) }) {
            VStack(spacing: 5) {
                Text(item.weekdayShort.prefix(2).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(weekdayColor)
                Text("\(BangkokCalendar.cal.component(.day, from: item.date))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                Circle()
                    .fill(dotFill)
                    .overlay(Circle().fill(accent).opacity(hasActivity ? 1 : 0))
                    .frame(width: 5, height: 5)
            }
            .frame(width: CardDS.Metrics.weeklyRowCompactWidth, height: CardDS.Metrics.weeklyRowCompactHeight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent, lineWidth: isSelected ? 1.5 : 0)
                    .opacity(isSelected ? 0.55 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(item.weekdayShort), \(BangkokCalendar.cal.component(.day, from: item.date))"))
    }
}


/// Small cell view for a single day (uses AppDS visual tokens through CD.ColorToken).
/// small calendar day cell used by WeeklyResumeStrip.
/// shows a weekday badge + a mini card area with optional progress bar.
/// public so it can be previewed or composed directly in MainDS without using the full strip.

// unified counters panel (matches MainDS pill style)

fileprivate struct WeeklyAppIconChip: View {
    enum Kind {
        case courses
        case planned
    }

    let kind: Kind
    let count: Int

    private var iconName: String {
        switch kind {
        case .courses: return "graduationcap.fill"
        case .planned: return "alarm.fill"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
                .opacity(0.95)

            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.92)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(CD.ColorToken.text)
        .background(
            Capsule(style: .continuous)
                .fill(CD.ColorToken.card)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(CD.ColorToken.stroke.opacity(0.35), lineWidth: 1)
                )
        )
        .frame(height: 24)
    }
}

public struct WeeklyResumeCell: View {
    let item: WeeklyResumeItem
    let isSelected: Bool
    let onTap: (WeeklyResumeItem) -> Void
    // optional adapter for pulling real DaySummary from MainDS (by date)
    let daySummaryProvider: ((Date) -> CardDS_DaySummary?)?

    public init(
        item: WeeklyResumeItem,
        isSelected: Bool,
        onTap: @escaping (WeeklyResumeItem) -> Void,
        daySummaryProvider: ((Date) -> CardDS_DaySummary?)? = nil
    ) {
        self.item = item
        self.isSelected = isSelected
        self.onTap = onTap
        self.daySummaryProvider = daySummaryProvider
    }

    public var body: some View {
        // calendar cell background
        let cellShape = RoundedRectangle(cornerRadius: CardDS.Metrics.radius, style: .continuous)

        let cal = BangkokCalendar.cal
        let todayStart = cal.startOfDay(for: Date())
        let itemDayStart = cal.startOfDay(for: item.date)

        let isTrulyEmpty: Bool = item.isEmpty || ((item.title == nil || item.title?.isEmpty == true) && item.progress == nil)
        let isPastEmptyDay: Bool = isTrulyEmpty && itemDayStart < todayStart
        let isDisabled: Bool = isPastEmptyDay
        let isPastDay: Bool = itemDayStart < todayStart

        let tapAction: () -> Void = {
            if isDisabled { return }
            onTap(item)
        }

        let primaryCount: Int = (item.title == nil || item.title?.isEmpty == true) ? 0 : 1
        let secondaryCount: Int = (item.secondaryTitle == nil || item.secondaryTitle?.isEmpty == true) ? 0 : 1
        let inferredCoursesCount: Int = primaryCount + secondaryCount
        let totalCoursesCount: Int = item.coursesCount ?? inferredCoursesCount
        // planned-only: course(s) selected for the day, but no learning activity yet
        let isPlannedOnly: Bool = totalCoursesCount > 0
            && (item.learnedCount ?? 0) == 0
            && (item.favCount ?? 0) == 0
            && (item.audioMinutes ?? 0) == 0
            && ((item.progress ?? 0) <= 0.0001)
            && ((item.secondaryProgress ?? 0) <= 0.0001)

        let isTodayDay: Bool = BangkokCalendar.cal.isDateInToday(item.date)
        let isTodayPlanned: Bool = isTodayDay && isPlannedOnly

        // planned state (works for both: empty planned stub and chosen planned day)
        let isPlanned: Bool = totalCoursesCount > 0
            && (item.learnedCount ?? 0) == 0
            && (item.favCount ?? 0) == 0
            && (item.audioMinutes ?? 0) == 0
            && ((item.progress ?? 0) <= 0.0001)
            && ((item.secondaryProgress ?? 0) <= 0.0001)
        let isPastPlannedFailed: Bool = isPastDay && totalCoursesCount > 0 && isPlanned

        let coursesChipView: AnyView = {
            if totalCoursesCount > 0 {
                return AnyView(
                    Group {
                        if isPlanned {
                            WeeklyAppIconChip(kind: .planned, count: totalCoursesCount)
                        } else {
                            WeeklyAppIconChip(kind: .courses, count: totalCoursesCount)
                        }
                    }
                    .offset(y: 16)
                )
            }
            return AnyView(EmptyView())
        }()

        return Button(action: tapAction) {
            VStack(spacing: 12) {
                WeeklyDayBadge(item: item, isSelected: isSelected)
                    .frame(maxWidth: .infinity, alignment: .center)

                // board cell — тот же surface, что и у остальных карточек, плюс stub title/progress
                ZStack {
                    CardChrome(style: .cards)
                        .clipShape(cellShape)
                        .overlay(
                            Group {
                                if isTodayPlanned {
                                    cellShape
                                        .stroke(ThemeManager.shared.currentAccentFill.opacity(0.55), lineWidth: 2)
                                }
                            }
                        )

                    if isTrulyEmpty {
                        VStack(spacing: 10) {
                            Spacer(minLength: 0)

                            VStack(spacing: 8) {
                                if isPastEmptyDay {
                                    if isPastPlannedFailed {
                                        Image(systemName: "alarm.waves.left.and.right")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                            .opacity(0.65)

                                        VStack(spacing: 4) {
                                            Text("план проспан")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)

                                            Text("\(totalCoursesCount) курс\(totalCoursesCount == 1 ? "" : (totalCoursesCount >= 2 && totalCoursesCount <= 4 ? "а" : "ов")) • 0 из \(totalCoursesCount)")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                    } else {
                                        Image(systemName: "moon.zzz.fill")
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                            .opacity(0.65)

                                        VStack(spacing: 4) {
                                            Text("без активности")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)

                                            Text("в этот день ты ничего не учил")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                    }
                                } else {
                                    // empty day for today / future.
                                    let isTodayDay = BangkokCalendar.cal.isDateInToday(item.date)

                                    if isTodayDay {
                                        Image(systemName: "dice.fill")
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)

                                        VStack(spacing: 4) {
                                            Text("случайный курс")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)

                                            Text("тап → открыть рандомный курс")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                    } else {
                                        Image(systemName: "plus")
                                            .font(.system(size: 32, weight: .semibold))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)

                                        VStack(spacing: 4) {
                                            Text("добавить курс")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)

                                            Text("выбрать курс на эту неделю")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 72)
                            .padding(.horizontal, 4)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .opacity(isPastEmptyDay ? 0.95 : 1.0)
                    } else {
                        // planned-only: keep "+" identity + show planned alarm + show chosen course names (no progress)
                        if isPlannedOnly {
                            VStack {
                                Spacer(minLength: 10)

                                VStack(alignment: .leading, spacing: 12) {
                                    // primary icon: future planned = plus, today planned = alarm (reminder)
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: isTodayDay ? "alarm.fill" : "plus")
                                            .font(.system(size: 26, weight: .semibold))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                            .padding(.top, 2)

                                        VStack(alignment: .leading, spacing: 6) {
                                            // title(s)
                                            if let t = item.title, !t.isEmpty {
                                                Text(t.lowercased())
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(CD.ColorToken.text)
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.leading)
                                                    .minimumScaleFactor(0.85)
                                            } else {
                                                Text(BangkokCalendar.cal.isDateInToday(item.date) ? "план на сегодня" : "план на день")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(CD.ColorToken.text)
                                                    .lineLimit(1)
                                            }

                                            if let t2 = item.secondaryTitle, !t2.isEmpty {
                                                Text(t2.lowercased())
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.95))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.9)
                                            }

                                            Text("\(totalCoursesCount) курс\(totalCoursesCount == 1 ? "" : (totalCoursesCount >= 2 && totalCoursesCount <= 4 ? "а" : "ов")) • запланировано")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.88))
                                                .lineLimit(1)
                                        }

                                        Spacer(minLength: 0)
                                    }

                                    Text(isTodayDay ? "сегодня: тап → открыть • изменить план" : "тап → открыть • плюс → изменить")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                                        .lineLimit(1)
                                        .padding(.top, 2)
                                }

                                Spacer(minLength: 16)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else {
                            VStack {
                                // spacer to push content slightly down from the very top
                                Spacer(minLength: 10)

                                VStack(alignment: .leading, spacing: 10) {
                                    // first course
                                    if let t = item.title, !t.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(t.lowercased())
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                                .minimumScaleFactor(0.85)

                                            if let p = item.progress {
                                                let clamped = max(0.0, min(1.0, p))
                                                VStack(alignment: .leading, spacing: 4) {
                                                    GeometryReader { geo in
                                                        let w = geo.size.width
                                                        let barH: CGFloat = 6
                                                        RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                                                            .fill(Color.white.opacity(0.14))
                                                            .frame(width: w, height: barH)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                                                                    .fill(ThemeManager.shared.currentAccentFill)
                                                                    .frame(
                                                                        width: max(0, w * CGFloat(clamped)),
                                                                        height: barH
                                                                    ),
                                                                alignment: .leading
                                                            )
                                                    }
                                                    .frame(height: 12)

                                                    Text("\(Int(clamped * 100))% пройдено")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                }
                                            }
                                        }
                                    }

                                    // second course (optional)
                                    if let t2 = item.secondaryTitle, !t2.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(t2.lowercased())
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                                .minimumScaleFactor(0.85)

                                            if let p2 = item.secondaryProgress {
                                                let clamped2 = max(0.0, min(1.0, p2))
                                                VStack(alignment: .leading, spacing: 4) {
                                                    GeometryReader { geo in
                                                        let w = geo.size.width
                                                        let barH: CGFloat = 6
                                                        RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                                                            .fill(Color.white.opacity(0.14))
                                                            .frame(width: w, height: barH)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: barH / 2, style: .continuous)
                                                                    .fill(ThemeManager.shared.currentAccentFill)
                                                                    .frame(
                                                                        width: max(0, w * CGFloat(clamped2)),
                                                                        height: barH
                                                                    ),
                                                                alignment: .leading
                                                            )
                                                    }
                                                    .frame(height: 12)

                                                    Text("\(Int(clamped2 * 100))% пройдено")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                                                }
                                            }
                                        }
                                    }
                                }

                                // extra spacer so content не прилипает к низу, но и не уезжает слишком высоко
                                Spacer(minLength: 16)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
                .overlay(coursesChipView, alignment: .bottom)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .contentShape(cellShape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(item.weekdayShort), \(BangkokCalendar.cal.component(.day, from: item.date))")
        )
    }
}

// production: use .carousel; .board/.row are legacy/preview-only
/// Seven-day horizontal strip. Supply exactly 7 items for a full week.
public struct WeeklyResumeStrip: View {
    public let items: [WeeklyResumeItem]            // legacy: can be empty when using provider
    public let onTapDay: (WeeklyResumeItem) -> Void
    public let layout: WeeklyResumeLayout
    public let cellStyle: WeeklyResumeCellStyle
    @State private var selected: WeeklyResumeItem?
    @State private var didInitialCenter: Bool = false

    // optional, used to fetch real DaySummary from MainDS by date
    public let daySummaryProvider: ((Date) -> CardDS_DaySummary?)?

    // NEW: optional provider for week-based data and current offset from the current week (0 = this week)
    public let weekProvider: ((Int) -> [WeeklyResumeItem])?
    @State private var itemsState: [WeeklyResumeItem] = []

    // Legacy init — uses static items (no week navigation)
    public init(
        items: [WeeklyResumeItem],
        layout: WeeklyResumeLayout = .board,
        cellStyle: WeeklyResumeCellStyle = .full,
        daySummaryProvider: ((Date) -> CardDS_DaySummary?)? = nil,
        onTapDay: @escaping (WeeklyResumeItem) -> Void
    ) {
        self.items = items
        self.onTapDay = onTapDay
        self.weekProvider = nil
        self.layout = layout
        self.cellStyle = cellStyle
        self.daySummaryProvider = daySummaryProvider
        _itemsState = State(initialValue: [])
        let defaultSelected = items.first(where: { $0.isToday })
            ?? items.first(where: { ($0.progress ?? 0) > 0 })
            ?? items.first
        _selected = State(initialValue: defaultSelected)
    }

    // New init — supplies a provider for fixed-week data (supports swipe between weeks)
    public init(
        weekProvider: @escaping (Int) -> [WeeklyResumeItem],
        layout: WeeklyResumeLayout = .board,
        cellStyle: WeeklyResumeCellStyle = .full,
        daySummaryProvider: ((Date) -> CardDS_DaySummary?)? = nil,
        onTapDay: @escaping (WeeklyResumeItem) -> Void
    ) {
        self.items = []
        self.onTapDay = onTapDay
        self.weekProvider = weekProvider
        self.layout = layout
        self.cellStyle = cellStyle
        self.daySummaryProvider = daySummaryProvider

        // Fetch initial items from provider once; no week navigation logic here
        let baseItems = weekProvider(0)
        _itemsState = State(initialValue: baseItems)

        let defaultSelected = baseItems.first(where: { $0.isToday })
            ?? baseItems.first(where: { ($0.progress ?? 0) > 0 })
            ?? baseItems.first
        _selected = State(initialValue: defaultSelected)
    }

    public var body: some View {
        let currentItems: [WeeklyResumeItem] = {
            if let weekProvider { return weekProvider(0) }
            return items
        }()
        // decide columns: 7 -> board mode (4 columns => 2 rows 4+3), 8–10 -> 5 columns, otherwise compact
        let columnsCount: Int = {
            if currentItems.count == 7 { return 4 }
            if currentItems.count >= 8 { return 5 }
            return max(3, currentItems.count)
        }()
        let cellSpacing: CGFloat = 20
        let columns = Array(repeating: GridItem(.flexible(), spacing: cellSpacing, alignment: .top), count: columnsCount)
        // grid of big day cards
        let board = LazyVGrid(columns: columns, alignment: .center, spacing: cellSpacing) {
            ForEach(currentItems) { item in
                let isSel: Bool = {
                    if let s = selected { return BangkokCalendar.cal.isDate(s.date, inSameDayAs: item.date) }
                    return false
                }()
                WeeklyResumeCell(item: item, isSelected: isSel, onTap: { tapped in
                    onTapDay(tapped)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { selected = tapped }
                }, daySummaryProvider: daySummaryProvider)
            }
        }
        .padding(.horizontal, CardDS.Metrics.contentX)
        .padding(.top, 6)
        .padding(.bottom, 2)
        // (gesture removed)

        let rowHeight: CGFloat = {
            if cellStyle == .compact {
                return CardDS.Metrics.weeklyRowCompactHeight + 12
            }
            return CardDS.Metrics.weeklyCellHeight + 36
        }()

        let compactRow = TaikaCarouselScroll {
            LazyHStack(spacing: 8) {
                ForEach(currentItems) { item in
                    let isSel: Bool = {
                        if let s = selected { return BangkokCalendar.cal.isDate(s.date, inSameDayAs: item.date) }
                        return false
                    }()
                    WeeklyResumeCompactCell(item: item, isSelected: isSel, onTap: { tapped in
                        onTapDay(tapped)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { selected = tapped }
                    })
                }
            }
            .padding(.horizontal, CardDS.Metrics.contentX)
            .padding(.vertical, 4)
        }
        .frame(height: rowHeight)

        let row = Group {
            if cellStyle == .compact {
                compactRow
            } else {
                TaikaCarouselScroll {
                    LazyHStack(spacing: 12) {
                        ForEach(currentItems) { item in
                            let isSel: Bool = {
                                if let s = selected { return BangkokCalendar.cal.isDate(s.date, inSameDayAs: item.date) }
                                return false
                            }()
                            WeeklyResumeCell(item: item, isSelected: isSel, onTap: { tapped in
                                onTapDay(tapped)
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { selected = tapped }
                            }, daySummaryProvider: daySummaryProvider)
                            .frame(width: CardDS.Metrics.weeklyCellWidth)
                        }
                    }
                    .padding(.horizontal, CardDS.Metrics.contentX)
                    .padding(.vertical, 8)
                }
                .frame(height: rowHeight)
            }
        }

        let carouselHeight = CardDS.Metrics.weeklyCellHeight + 24
        let carousel = Color.clear
            .frame(height: carouselHeight)
            .overlay {
                GeometryReader { outer in
                    // compute side inset so the first/last cell can sit centered in the viewport
                    let cellW = CardDS.Metrics.weeklyCellWidth * 1.5
                    let sideInset = max(0, (outer.size.width - cellW) / 2)
                    ScrollViewReader { proxy in
                        TaikaCarouselScroll {
                            LazyHStack(spacing: CardDS.Metrics.carouselSpacing * 0.5) {
                                ForEach(currentItems) { item in
                                    GeometryReader { cellGeo in
                                        let isSel: Bool = {
                                            if let s = selected { return BangkokCalendar.cal.isDate(s.date, inSameDayAs: item.date) }
                                            return false
                                        }()
                                        // distance of cell midX to the visible viewport center
                                        let viewportCenterX = outer.size.width / 2
                                        let cellCenterX = cellGeo.frame(in: .named("weeklyCarousel")).midX
                                        let dist = abs(cellCenterX - viewportCenterX)
                                        // normalize and derive visual weights (with 3D rotation)
                                        let norm = min(1.0, dist / max(1.0, outer.size.width * 0.65))
                                        let scale = 0.85 + 0.25 * (1.0 - norm)   // center ≈1.10, sides ≈0.85 (stronger depth)
                                        let opacity = 0.45 + 0.55 * (1.0 - norm) // center 1.0, sides ≈0.45

                                        WeeklyResumeCell(item: item, isSelected: isSel, onTap: { tapped in
                                            if !(selected?.date == tapped.date) {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                            onTapDay(tapped)
                                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                                selected = tapped
                                                proxy.scrollTo(item.dayKey, anchor: .center)
                                            }
                                        }, daySummaryProvider: daySummaryProvider)
                                        .frame(width: CardDS.Metrics.weeklyCellWidth * 1.5, height: CardDS.Metrics.weeklyCellHeight)
                                        .padding(.horizontal, 4)
                                        .scaleEffect(scale)
                                        .rotation3DEffect(
                                            .degrees(Double((cellCenterX - viewportCenterX) / -10.0)),
                                            axis: (x: 0, y: 1, z: 0),
                                            perspective: 0.8
                                        )
                                        .opacity(opacity)
                                        .shadow(color: Color.black.opacity(scale >= 1.08 ? 0.28 : 0.10),
                                                radius: scale >= 1.08 ? 8 : 2,
                                                x: 0,
                                                y: scale >= 1.08 ? 3 : 1)
                                        .zIndex(Double(1.0 - norm))
                                    }
                                    .frame(width: CardDS.Metrics.weeklyCellWidth * 1.5, height: CardDS.Metrics.weeklyCellHeight)
                                    .id(item.dayKey)
                                }
                            }
                            .padding(.horizontal, sideInset)
                        }
                        .onAppear {
                            // center only once on initial render; never auto-recenter later
                            guard didInitialCenter == false else { return }
                            didInitialCenter = true
                            if let sel = selected {
                                proxy.scrollTo(sel.dayKey, anchor: .center)
                            }
                        }
                    }
                    .coordinateSpace(name: "weeklyCarousel")
                }
            }

        return VStack(spacing: 12) {
            switch layout {
            case .board:
                board
            case .row:
                row
            case .carousel:
                carousel
            }
        }
        .padding(.top, 8)
        .background(Color.clear)
        .padding(.bottom, 0)
        // .onAppear and .onReceive removed
        .onChange(of: items) { newItems in
            guard weekProvider == nil else { return }

            // keep current selection if it's still present in the newItems (same day)
            if let sel = selected, newItems.contains(where: { BangkokCalendar.cal.isDate($0.date, inSameDayAs: sel.date) }) {
                return
            }

            let defaultSelected = newItems.first(where: { BangkokCalendar.cal.isDateInToday($0.date) })
                ?? newItems.first(where: { ($0.progress ?? 0) > 0 })
                ?? newItems.first

            selected = defaultSelected
            // allow initial centering again only if selection became nil (rare)
            if selected == nil { didInitialCenter = false }
        }
    }
}


// MARK: - StepWordCard (DS atom: large word card)
public struct StepWordCard: View {
    public let title: String       // русское слово, крупным
    public let translit: String    // латиницей, акцентным цветом
    public let thai: String        // тайский текст, вторичный
    public let label: String       // чип в правом верхнем углу, по умолчанию "слово"
    public let size: CGSize
    public let sectionChrome: CardDS.SectionChrome
    public let chromeStyle: CardDS.ChromeStyle
    public let phoneticView: AnyView?
    public let isFavorite: Bool
    public let isLearned: Bool
    public let allowLearn: Bool
    public let isAudioPlaying: Bool
    /// When true, renders a slightly smaller action bar (useful for mini variants like Favorites).
    public let compactActionBar: Bool
    /// См. `StepCardActionBar.miniLearnedCheckmarkOnly` — для мини-карточек в избранном.
    public let miniLearnedCheckmarkOnly: Bool
    /// «слово / фраза» справа сверху; для PRO-витрины выключить и показать корону.
    public let showsTypeChip: Bool
    public let onPlay: (() -> Void)?
    public let onFavorite: () -> Void
    public let onLearn: () -> Void

    public init(
        title: String,
        translit: String,
        thai: String,
        label: String = "слово",
        size: CGSize = CGSize(width: CardDS.Metrics.stepWordWidth, height: CardDS.Metrics.stepWordHeight),
        sectionChrome: CardDS.SectionChrome = .seps,
        chromeStyle: CardDS.ChromeStyle = .cards,
        phoneticView: AnyView? = nil,
        isFavorite: Bool = false,
        isLearned: Bool = false,
        allowLearn: Bool = true,
        isAudioPlaying: Bool = false,
        compactActionBar: Bool = false,
        miniLearnedCheckmarkOnly: Bool = false,
        showsTypeChip: Bool = true,
        onPlay: (() -> Void)? = nil,
        onFavorite: @escaping () -> Void = {},
        onLearn: @escaping () -> Void = {}
    ) {
        self.title = title
        self.translit = translit
        self.thai = thai
        self.label = label
        self.size = size
        self.sectionChrome = sectionChrome
        self.chromeStyle = chromeStyle
        self.phoneticView = phoneticView
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.allowLearn = allowLearn
        self.isAudioPlaying = isAudioPlaying
        self.compactActionBar = compactActionBar
        self.miniLearnedCheckmarkOnly = miniLearnedCheckmarkOnly
        self.showsTypeChip = showsTypeChip
        self.onPlay = onPlay
        self.onFavorite = onFavorite
        self.onLearn = onLearn
    }

    public var body: some View {
        CardBase(
            title: title,
            subtitle: nil,
            size: size,
            sectionChrome: sectionChrome,
            chromeStyle: chromeStyle,
            showTitle: false,
            cornerRadius: CardDS.Metrics.stepCardContentRadius,
            contentLayout: .stepSymmetric,
            top: {
                StepCardBalancedTopChrome {
                    StepCardInlineWordmarkSlot()
                } trailing: {
                    Group {
                        if showsTypeChip {
                            AppMiniChip(
                                title: label.lowercased(),
                                style: stepCardTypeChipStyle(forLabel: label)
                            ) { }
                        } else {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        }
                    }
                }
                .padding(.top, 6)
            },
            bottom: {
                let bar = StepCardActionBar(
                    isFavorite: isFavorite,
                    isLearned: isLearned,
                    allowLearn: allowLearn,
                    isTip: false,
                    tipShowsLearnSlot: false,
                    showsPlayAndFavorite: true,
                    isAudioPlaying: isAudioPlaying,
                    onPlay: onPlay,
                    onFavorite: onFavorite,
                    onLearn: onLearn,
                    onNext: nil,
                    onExpand: nil,
                    miniLearnedCheckmarkOnly: miniLearnedCheckmarkOnly
                )
                if compactActionBar {
                    bar
                        .scaleEffect(0.92)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                } else {
                    bar
                }
            },
            meta: {
                // Тайский → RU → транслит, один связный блок по центру зоны meta (без Spacer’ов, ломавших квадрат).
                VStack(spacing: Theme.StepCardText.blockSpacing) {
                    Text(thai)
                        .font(.system(size: Theme.StepCardText.thaiFontSize, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(Theme.StepCardText.thaiLines)
                        .minimumScaleFactor(Theme.StepCardText.thaiScale)
                        .allowsTightening(true)

                    Text(title)
                        .font(.system(size: Theme.StepCardText.titleFontSize, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(Theme.StepCardText.titleLines)
                        .minimumScaleFactor(Theme.StepCardText.titleScale)
                        .allowsTightening(true)

                    if let phoneticView {
                        phoneticView
                            .multilineTextAlignment(.center)
                            .lineLimit(Theme.StepCardText.phoneticLines)
                            .minimumScaleFactor(Theme.StepCardText.phoneticScale)
                            .allowsTightening(true)
                    } else {
                        phoneticStyledText(translit)
                            .font(.system(size: Theme.StepCardText.phoneticFontSize, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(Theme.StepCardText.phoneticLines)
                            .minimumScaleFactor(Theme.StepCardText.phoneticScale)
                            .allowsTightening(true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.vertical, 6)
            },
            tags: {
                EmptyView()
            },
            belowTitle: {
                EmptyView()
            }
        )
    }
}

/// Продающая карточка карусели Спикера — тот же язык, что StepProTeaserCard в разминке.
/// CTA только внутри карточки.
public struct SpeakerTeaserCard: View {
    public let icon: String
    public let title: String
    public let subtitle: String
    public let chipTitle: String
    public let ctaTitle: String
    public let size: CGSize
    public let onCTA: () -> Void

    public init(
        icon: String,
        title: String,
        subtitle: String,
        chipTitle: String,
        ctaTitle: String,
        size: CGSize = CGSize(width: CardDS.Metrics.stepCardWidth, height: CardDS.Metrics.stepCardWidth),
        onCTA: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.chipTitle = chipTitle
        self.ctaTitle = ctaTitle
        self.size = size
        self.onCTA = onCTA
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: CardDS.Metrics.stepCardContentRadius, style: .continuous)
        let accent = ThemeManager.shared.currentAccentFill
        let tint = ThemeManager.shared.currentAccentTintColor

        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                StepCardInlineWordmarkSlot()
                Spacer(minLength: 4)
                Text(chipTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(accent, lineWidth: 1.2)
                    )
            }
            .padding(.horizontal, CardDS.Metrics.contentX + CardDS.Metrics.stepCardHeaderEdgeInset)
            .frame(height: CardDS.Metrics.stepCardTopBandHeight)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 8)

            Button(action: onCTA) {
                Text(ctaTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule(style: .continuous).fill(accent))
            }
            .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .frame(width: size.width, height: size.height)
        .background(Theme.Surfaces.card(shape))
        .overlay(
            shape.stroke(accent.opacity(0.45), lineWidth: Theme.Strokes.strokeCardLineWidth + 0.4)
        )
        .shadow(color: tint.opacity(0.18), radius: 12, y: 5)
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). \(ctaTitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onCTA() }
    }
}

/// PRO-заглушка в карусели разминки: продающая карточка, не «пустой» StepWordCard.
public struct StepProTeaserCard: View {
    public let title: String
    public let subtitle: String
    public let ctaTitle: String
    public let size: CGSize
    public let onOpen: () -> Void

    public init(
        title: String = "ещё 5 карточек",
        subtitle: String = "расширь разминку с Taika+",
        ctaTitle: String = "открыть Taika+",
        size: CGSize = CGSize(width: CardDS.Metrics.stepWordWidth, height: CardDS.Metrics.stepWordHeight),
        onOpen: @escaping () -> Void = {}
    ) {
        self.title = title
        self.subtitle = subtitle
        self.ctaTitle = ctaTitle
        self.size = size
        self.onOpen = onOpen
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: CardDS.Metrics.stepCardContentRadius, style: .continuous)
        let accent = ThemeManager.shared.currentAccentFill
        let tint = ThemeManager.shared.currentAccentTintColor

        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                StepCardInlineWordmarkSlot()
                Spacer(minLength: 4)
                AppProChip(scale: 0.86)
            }
            .padding(.horizontal, CardDS.Metrics.contentX + CardDS.Metrics.stepCardHeaderEdgeInset)
            .frame(height: CardDS.Metrics.stepCardTopBandHeight)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 8)

            Text(ctaTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Capsule(style: .continuous).fill(accent))
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
        }
        .frame(width: size.width, height: size.height)
        .background(Theme.Surfaces.card(shape))
        .overlay(
            shape.stroke(accent.opacity(0.55), lineWidth: Theme.Strokes.strokeCardLineWidth + 0.4)
        )
        .shadow(color: tint.opacity(0.22), radius: 12, y: 5)
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). \(ctaTitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onOpen() }
    }
}

/// Убираем дефисы между слогами для отображения (разделитель — стрелка тона и пробел).
fileprivate func phoneticDisplayWithoutHyphens(_ s: String) -> String {
    var result = s.trimmingCharacters(in: .whitespacesAndNewlines)
    for arrow in ["→", "↓", "↘", "↑", "↗"] {
        result = result.replacingOccurrences(of: arrow + "-", with: arrow + " ")
    }
    return result
}

fileprivate func phoneticStyledText(_ s: String) -> Text {
    // 1) Для отображения убираем дефисы после стрелок тона (слог→-слог → слог→ слог).
    let normalized = phoneticDisplayWithoutHyphens(s)
    // 2) Стрелки тона (→↗↘↑↓) — акцентным цветом; слоги — по диакритике или вторичный цвет.
    let toneArrows: Set<Character> = ["→", "↓", "↘", "↑", "↗"]
    let accentScalars: Set<UnicodeScalar> = [
        UnicodeScalar(0x0301)!, UnicodeScalar(0x00B4)!, UnicodeScalar(0x02CA)!,
        UnicodeScalar(0x0300)!, UnicodeScalar(0x02CB)!, UnicodeScalar(0x0302)!,
        UnicodeScalar(0x02C6)!, UnicodeScalar(0x0306)!, UnicodeScalar(0x02D8)!,
        UnicodeScalar(0x030C)!, UnicodeScalar(0x02C7)!
    ]

    func chunkHasAccent(_ chunk: String) -> Bool {
        chunk.unicodeScalars.contains { accentScalars.contains($0) }
    }

    let separators: Set<Character> = [" ", "-", "·"]
    var result = Text("")
    var currentChunk = ""

    func flushChunk() {
        guard !currentChunk.isEmpty else { return }
        let isAccentChunk = chunkHasAccent(currentChunk)
        let base = Text(currentChunk)
        if isAccentChunk {
            result = result + base.foregroundStyle(ThemeManager.shared.currentAccentFill)
        } else {
            result = result + base.foregroundStyle(CD.ColorToken.textSecondary.opacity(0.96))
        }
        currentChunk = ""
    }

    for ch in normalized {
        if toneArrows.contains(ch) {
            flushChunk()
            result = result + Text(String(ch)).foregroundStyle(ThemeManager.shared.currentAccentFill)
        } else if separators.contains(ch) {
            flushChunk()
            result = result + Text(String(ch)).foregroundStyle(CD.ColorToken.textSecondary.opacity(0.96))
        } else {
            currentChunk.append(ch)
        }
    }
    flushChunk()

    return result
}


fileprivate extension Double {
    var clamped01: Double { min(1, max(0, self)) }
}



fileprivate struct CardNoteCarouselPreviewView: View {
    fileprivate enum Item: Identifiable {
        case course(label: String, title: String, subtitle: String, progress: Double?, cta: String?)
        case text(label: String, text: String)
        case step(label: String, title: String)

        var id: String {
            switch self {
            case let .course(label, title, _, _, _):
                return "course:\(label):\(title)"
            case let .text(label, text):
                return "text:\(label):\(text.prefix(12))"
            case let .step(label, title):
                return "step:\(label):\(title)"
            }
        }
    }

    private let items: [Item] = [
        .course(label: "заметка", title: "как учиться", subtitle: "10 минут в день лучше, чем 2 часа раз в неделю.", progress: 0.42, cta: "продолжить"),
        .step(label: "шаг", title: "мини‑карточка"),
        .text(label: "лайфхак", text: "говори медленнее — тайцы ценят интонацию сильнее скорости. и да, паузы — это ок."),
        .course(label: "pro", title: "расширь подборку", subtitle: "открой pro и получи ещё карточки в подборке дня.", progress: nil, cta: "открыть pro"),
        .step(label: "слово", title: "как в избранном"),
        .text(label: "заметка", text: "если сегодня нет сил — просто открой один шаг. привычка важнее объёма.")
    ]

    var body: some View {
        GeometryReader { outer in
            let cardW: CGFloat = CardDS.Metrics.noteCardWidth
            let cardH: CGFloat = CardDS.Metrics.noteCardHeight
            let spacing: CGFloat = 15
            let sideInset: CGFloat = max(0, (outer.size.width - cardW) / 2)

            TaikaCarouselScroll {
                LazyHStack(spacing: spacing) {
                    ForEach(Array(items.enumerated()), id: \.1.id) { idx, item in
                        let itemH: CGFloat = {
                            switch item {
                            case .step:
                                return CardDS.Metrics.noteStepHeight
                            default:
                                return cardH
                            }
                        }()
                        NoteCarouselCellPreview(
                            idx: idx,
                            item: item,
                            cardW: cardW,
                            cardH: itemH,
                            outerWidth: outer.size.width
                        )
                    }
                }
                .padding(.horizontal, sideInset)
                .padding(.vertical, 8)
            }
            .coordinateSpace(name: "noteCarouselPreview")
        }
    }

    // MARK: - cell preview (extracted to help the compiler)
    fileprivate struct NoteCarouselCellPreview: View {
        let idx: Int
        let item: Item
        let cardW: CGFloat
        let cardH: CGFloat
        let outerWidth: CGFloat

        var body: some View {
            GeometryReader { geo in
                // precompute all values outside of modifiers to help type-checker
                let viewportCenterX: CGFloat = outerWidth / 2
                let cellCenterX: CGFloat = geo.frame(in: .named("noteCarouselPreview")).midX
                let dist: CGFloat = abs(cellCenterX - viewportCenterX)
                let denom: CGFloat = max(1.0, outerWidth * 0.65)
                let norm: CGFloat = min(1.0, dist / denom)

                let scale: CGFloat = 0.90 + 0.16 * (1.0 - norm)
                let opacity: CGFloat = 0.45 + 0.55 * (1.0 - norm)
                let angleDeg: Double = Double((cellCenterX - viewportCenterX) / -14.0)

                content
                    .frame(width: cardW, height: cardH)
                    .scaleEffect(scale)
                    .rotation3DEffect(
                        .degrees(angleDeg),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.8
                    )
                    .opacity(opacity)
                    .shadow(
                        color: Color.black.opacity(scale >= 1.04 ? 0.26 : 0.10),
                        radius: scale >= 1.04 ? 7 : 2,
                        x: 0,
                        y: scale >= 1.04 ? 3 : 1
                    )
                    .zIndex(Double(1.0 - norm))
            }
            .frame(width: cardW, height: cardH)
            .id(idx)
        }

        @ViewBuilder
        private var content: some View {
            switch item {
            case let .course(label, title, subtitle, progress, cta):
                CardDS.NoteCourseCardV(
                    label: label,
                    categoryChip: nil,
                    title: title,
                    subtitle: subtitle,
                    progressFraction: progress,
                    ctaTitle: cta,
                    onCTATap: nil,
                    topRightChip: nil
                )

            case let .text(label, text):
                NoteTextCard(
                    label: label,
                    text: text,
                    size: CGSize(width: cardW, height: cardH),
                    sectionChrome: .seps,
                    chromeStyle: .cards
                )

            case let .step(label, title):
                NoteStepCard(
                    label: label,
                    wordTitle: title,
                    accentSubtitle: "мини‑превью шага",
                    meta: "6 карточек · pro",
                    showsProBadge: true,
                    size: CGSize(width: cardW, height: cardH),
                    sectionChrome: .seps,
                    chromeStyle: .cards
                )
            }
        }

        // lightweight stub extracted to reduce builder complexity
        fileprivate struct NoteStepMiniStub: View {
            var body: some View {
                HStack(spacing: 10) {
                    ForEach(1...6, id: \.self) { i in
                        Text("\(i)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(CD.ColorToken.card.opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(CD.ColorToken.stroke.opacity(0.25), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

struct CardNoteBaseCarousel_Previews: PreviewProvider {
    static var previews: some View {
        CardNoteCarouselPreviewView()
            .frame(width: 680)
            .padding(12)
            .background(Color.black)
            .previewDisplayName("CardNoteBase — carousel (preview)")
            .environmentObject(ThemeManager.shared)
    }
}

struct WeeklyResumeCell_PlannedStub_Previews: PreviewProvider {
    static var previews: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let in2 = cal.date(byAdding: .day, value: 2, to: today) ?? today
        let in3 = cal.date(byAdding: .day, value: 3, to: today) ?? today


        // 2) planned-only with title + plus (your target after selecting 1 course from “+”)
        let plannedChosen = WeeklyResumeItem(
            weekdayShort: "ср",
            date: in2,
            title: "thai basics",
            progress: 0.0,
            secondaryTitle: nil,
            secondaryProgress: nil,
            coursesCount: 1,
            isToday: false,
            isEmpty: false,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 3) planned-only with 2 courses chosen
        let plannedChosen2 = WeeklyResumeItem(
            weekdayShort: "чт",
            date: in3,
            title: "thai basics",
            progress: 0.0,
            secondaryTitle: "thai basics: food",
            secondaryProgress: 0.0,
            coursesCount: 2,
            isToday: false,
            isEmpty: false,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 3a) today planned (planned-only on today — should show accent outline)
        let todayPlanned = WeeklyResumeItem(
            weekdayShort: "пн",
            date: today,
            title: "thai basics",
            progress: 0.0,
            secondaryTitle: nil,
            secondaryProgress: nil,
            coursesCount: 1,
            isToday: true,
            isEmpty: false,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 3b) today empty (random course dice state)
        let todayEmptyRandom = WeeklyResumeItem(
            weekdayShort: "пн",
            date: today,
            title: nil,
            progress: nil,
            coursesCount: 0,
            isToday: true,
            isEmpty: true,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 4) empty future day (plus)
        let emptyFuture = WeeklyResumeItem(
            weekdayShort: "пт",
            date: cal.date(byAdding: .day, value: 4, to: today) ?? today,
            title: nil,
            progress: nil,
            coursesCount: 0,
            isToday: false,
            isEmpty: true
        )

        // 5) past empty day (disabled “no activity” state)
        let pastEmpty = WeeklyResumeItem(
            weekdayShort: "вс",
            date: yesterday,
            title: nil,
            progress: nil,
            coursesCount: 0,
            isToday: false,
            isEmpty: true
        )

        // 5b) past planned but failed day (planned courses, no activity)
        let pastPlannedFailed = WeeklyResumeItem(
            weekdayShort: "ср",
            date: cal.date(byAdding: .day, value: -3, to: today) ?? today,
            title: "thai basics",
            progress: 0.0,
            secondaryTitle: nil,
            secondaryProgress: nil,
            coursesCount: 2,
            isToday: false,
            isEmpty: true,
            learnedCount: 0,
            favCount: 0,
            audioMinutes: 0
        )

        // 6) active day (single course)
        let active = WeeklyResumeItem(
            weekdayShort: "пн",
            date: today,
            title: "thai basics",
            progress: 0.35,
            secondaryTitle: nil,
            secondaryProgress: nil,
            coursesCount: 1,
            isToday: true,
            isEmpty: false,
            learnedCount: 4,
            favCount: 2,
            audioMinutes: 8
        )

        // 7) active day (two courses)
        let active2 = WeeklyResumeItem(
            weekdayShort: "сб",
            date: cal.date(byAdding: .day, value: -2, to: today) ?? today,
            title: "thai basics",
            progress: 0.62,
            secondaryTitle: "thai basics: food",
            secondaryProgress: 0.18,
            coursesCount: 2,
            isToday: false,
            isEmpty: false,
            learnedCount: 7,
            favCount: 1,
            audioMinutes: 12
        )

        let samples: [(String, WeeklyResumeItem, Bool)] = [
            ("planned chosen (title + plus)", plannedChosen, false),
            ("planned chosen (2 courses)", plannedChosen2, false),
            ("today planned (accent)", todayPlanned, true),
            ("today empty (random dice)", todayEmptyRandom, false),
            ("empty future (+)", emptyFuture, false),
            ("past empty (disabled)", pastEmpty, false),
            ("past planned failed", pastPlannedFailed, false),
            ("active (today)", active, true),
            ("active (2 courses)", active2, false)
        ]

        return TaikaRootVerticalScroll(showsScrollIndicators: true) {
            VStack(spacing: 16) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, s in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(s.0.lowercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .padding(.horizontal, 2)

                        WeeklyResumeCell(item: s.1, isSelected: s.2, onTap: { _ in })
                            .frame(width: 240, height: 300)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.black)
        .environmentObject(ThemeManager.shared)
        .previewDisplayName("weekly resume — all states")
    }
}
// MARK: - shared word carousel (favorite + speaker)
public extension CardDS {

    // shared carousel model (used by Favorite + Speaker)
    struct CDWordCarouselItem: Identifiable, Hashable {
        public let id: String
        public let title: String            // ru
        public let phonetic: String         // latin
        public let thai: String             // thai
        public let label: String            // top-right chip

        // optional extra strings (Speaker can reuse)
        public let subtitle: String?        // optional
        public let meta: String?            // e.g. tone hint (optional)
        public let lessonTitle: String?     // optional (ignored for now)

        public let isFavorite: Bool
        public let isLearned: Bool

        public init(
            id: String,
            title: String,
            phonetic: String,
            thai: String,
            label: String = "слово",
            subtitle: String? = nil,
            meta: String? = nil,
            lessonTitle: String? = nil,
            isFavorite: Bool = false,
            isLearned: Bool = false
        ) {
            self.id = id
            self.title = title
            self.phonetic = phonetic
            self.thai = thai
            self.label = label
            self.subtitle = subtitle
            self.meta = meta
            self.lessonTitle = lessonTitle
            self.isFavorite = isFavorite
            self.isLearned = isLearned
        }
    }

    // shared mini card (visual parity with FavoriteDS word tile)
    struct CDWordMiniCard: View {
        public let item: CDWordCarouselItem
        public let size: CGSize

        public let onPlay: (() -> Void)?
        public let onFavorite: (() -> Void)?
        public let onPractice: (() -> Void)?

        @State private var showWave: Bool = false

        public init(
            item: CDWordCarouselItem,
            size: CGSize,
            onPlay: (() -> Void)? = nil,
            onFavorite: (() -> Void)? = nil,
            onPractice: (() -> Void)? = nil
        ) {
            self.item = item
            self.size = size
            self.onPlay = onPlay
            self.onFavorite = onFavorite
            self.onPractice = onPractice
        }

        public var body: some View {
            CardBase(
                title: item.title,
                subtitle: nil,
                size: size,
                sectionChrome: .seps,
                chromeStyle: .cards,
                showTitle: false,
                top: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            TaikaWordmarkLockup(fontSize: 16)

                            Spacer(minLength: 0)

                            // top-right tag: word/phrase/slang (card type)
                            if !item.label.isEmpty {
                                AppMiniChip(
                                    title: item.label.lowercased(),
                                    style: .neutral
                                ) { }
                            }
                        }
                    }
                    .padding(.horizontal, CardDS.Metrics.contentX)
                    .padding(.top, 12)
                },
                bottom: {
                    HStack {
                        Spacer(minLength: 0)

                        // lesson title chip (favorite-style accent capsule)
                        if let lessonTitle = item.lessonTitle, !lessonTitle.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.92))

                                Text(lessonTitle.lowercased())
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.92))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(
                                Capsule().fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            )
                            .overlay(
                                Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                            )
                            .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, CardDS.Metrics.contentX)
                    .padding(.bottom, 14)
                },
                meta: {
                    VStack(spacing: 0) {
                        Spacer(minLength: 18)

                        VStack(spacing: 12) {
                            // speaker control above the title (icon-only; waveform overlays inside the same capsule)
                            AppAudioWaveButton(isPlaying: showWave) {
                                onPlay?()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()

                                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                                    showWave = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showWave = false
                                    }
                                }
                            }
                            .accessibilityLabel(Text("прослушать"))

                            // ru title (primary)
                            Text(item.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(CD.ColorToken.text)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                                .allowsTightening(true)

                            // phonetic (accent)
                            phoneticStyledText(item.phonetic)
                                .font(.system(size: 16, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                                .allowsTightening(true)

                            // thai (secondary)
                            Text(item.thai)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .allowsTightening(true)

                            // optional meta (tone hint etc.)
                            if let m = item.meta, !m.isEmpty {
                                Text(m)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.9)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Spacer(minLength: 18)
                    }
                    .padding(.horizontal, CardDS.Metrics.contentX)
                    .padding(.vertical, 10)
                },
                tags: { EmptyView() },
                belowTitle: { EmptyView() }
            )
        }
    }

    // Small helper waveform view for CDWordMiniCard
    fileprivate struct CDMiniWaveform: View {
        let isActive: Bool

        init(isActive: Bool) {
            self.isActive = isActive
        }

        var body: some View {
            Group {
                if isActive {
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        bars(time: t)
                    }
                } else {
                    // static baseline (no animation)
                    bars(time: 0)
                }
            }
        }

        @ViewBuilder
        private func bars(time t: TimeInterval) -> some View {
            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { i in
                    let base: CGFloat = 6
                    let amp: CGFloat = 10
                    let phase = t * 6.0 + Double(i) * 0.55
                    let h: CGFloat = isActive ? (base + abs(sin(phase)) * amp) : (base + (CGFloat(i % 3) * 2))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(CD.ColorToken.textSecondary.opacity(0.55))
                        .frame(width: 3, height: h)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.clear)
            )
        }
    }

    // shared carousel view (Favorite + Speaker)
    struct CDWordCarousel: View {
        public let items: [CDWordCarouselItem]
        public let cardSize: CGSize

        public let onPlay: ((CDWordCarouselItem) -> Void)?
        public let onFavorite: ((CDWordCarouselItem) -> Void)?
        public let onPractice: ((CDWordCarouselItem) -> Void)?
        public let onDelete: ((CDWordCarouselItem) -> Void)?

        @Binding public var isEditing: Bool

        public init(
            items: [CDWordCarouselItem],
            cardSize: CGSize = CGSize(width: 280, height: 220),
            isEditing: Binding<Bool> = .constant(false),
            onPlay: ((CDWordCarouselItem) -> Void)? = nil,
            onFavorite: ((CDWordCarouselItem) -> Void)? = nil,
            onPractice: ((CDWordCarouselItem) -> Void)? = nil,
            onDelete: ((CDWordCarouselItem) -> Void)? = nil
        ) {
            self.items = items
            self.cardSize = cardSize
            self._isEditing = isEditing
            self.onPlay = onPlay
            self.onFavorite = onFavorite
            self.onPractice = onPractice
            self.onDelete = onDelete
        }

        public var body: some View {
            GeometryReader { outer in
                let cardW = cardSize.width
                let cardH = cardSize.height
                let spacing: CGFloat = 14
                let sideInset: CGFloat = max(0, (outer.size.width - cardW) / 2)

                TaikaCarouselScroll {
                    LazyHStack(spacing: spacing) {
                        ForEach(items) { item in
                            GeometryReader { cellGeo in
                                let viewportCenterX: CGFloat = outer.size.width / 2
                                let cellCenterX: CGFloat = cellGeo.frame(in: .named("cdWordCarousel")).midX
                                let dist: CGFloat = abs(cellCenterX - viewportCenterX)
                                let denom: CGFloat = max(1.0, outer.size.width * 0.65)
                                let norm: CGFloat = min(1.0, dist / denom)

                                // favorite-style depth: center is bigger + clearer
                                let scale: CGFloat = 0.90 + 0.16 * (1.0 - norm)
                                let opacity: CGFloat = 0.55 + 0.45 * (1.0 - norm)
                                let angleDeg: Double = Double((cellCenterX - viewportCenterX) / -14.0)

                                CDWordCarouselCell(
                                    item: item,
                                    size: cardSize,
                                    isEditing: $isEditing,
                                    onPlay: { tapped in onPlay?(tapped) },
                                    onFavorite: { tapped in onFavorite?(tapped) },
                                    onPractice: { tapped in onPractice?(tapped) },
                                    onDelete: { tapped in onDelete?(tapped) }
                                )
                                .frame(width: cardW, height: cardH)
                                .scaleEffect(scale)
                                .rotation3DEffect(
                                    .degrees(angleDeg),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.8
                                )
                                .opacity(opacity)
                                .shadow(
                                    color: Color.black.opacity(scale >= 1.04 ? 0.26 : 0.10),
                                    radius: scale >= 1.04 ? 7 : 2,
                                    x: 0,
                                    y: scale >= 1.04 ? 3 : 1
                                )
                                .zIndex(Double(1.0 - norm))
                            }
                            .frame(width: cardW, height: cardH)
                        }
                    }
                    .padding(.horizontal, sideInset)
                    .padding(.vertical, 8)
                }
            }
            .coordinateSpace(name: "cdWordCarousel")
            .frame(height: cardSize.height + 16)
        }

        // MARK: - single cell
        fileprivate struct CDWordCarouselCell: View {
            let item: CDWordCarouselItem
            let size: CGSize
            @Binding var isEditing: Bool

            let onPlay: (CDWordCarouselItem) -> Void
            let onFavorite: (CDWordCarouselItem) -> Void
            let onPractice: (CDWordCarouselItem) -> Void
            let onDelete: (CDWordCarouselItem) -> Void

            @State private var isJiggling: Bool = false

            var body: some View {
                CDWordMiniCard(
                    item: item,
                    size: size,
                    onPlay: { onPlay(item) },
                    onFavorite: { onFavorite(item) },
                    onPractice: { onPractice(item) }
                )
                .overlay(alignment: .topTrailing) {
                    if isEditing {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onDelete(item)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(CD.ColorToken.text)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(CD.ColorToken.card))
                                .overlay(
                                    Circle().stroke(CD.ColorToken.stroke.opacity(0.35), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                }
                .rotationEffect(.degrees(isEditing ? (isJiggling ? -1.2 : 1.2) : 0))
                .animation(
                    isEditing ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true) : .default,
                    value: isJiggling
                )
                .onChange(of: isEditing) { editing in
                    isJiggling = editing
                }
            }
        }
    }
}
