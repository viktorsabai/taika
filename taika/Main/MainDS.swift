
//  MainDS.swift
//  taika
//
//  Created by product on 23.08.2025.
//


import SwiftUI
import Combine
import Foundation

// MARK: - Thailand canonical calendar (Asia/Bangkok) for DS date logic
fileprivate enum MDBangkokCalendar {
    static let tz: TimeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
    static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }()
}

// MARK: - Brand gradient helper (local to MainDS)
private struct BrandGradient {
    // Unified accent gradient used across Main DS components
    private static let colors: [Color] = [
        // deeper start for better contrast, then the two brand-pinks
        Color(red: 0.96, green: 0.32, blue: 0.67),
        Color(red: 0.98, green: 0.52, blue: 0.80),
        Color(red: 0.91, green: 0.62, blue: 0.98)
    ]

    static let linear = LinearGradient(
        colors: colors,
        startPoint: .leading,
        endPoint: .trailing
    )
}

// Safe index access for arrays (file-scope)
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: CTA pill (sticker style)
private struct MDCTAPill: View {
    enum Style { case fill, outline }
    var title: String
    var icon: String? = nil
    var style: Style = .outline
    var shadowed: Bool = false
    var wide: Bool = false

    var body: some View {
        let label = HStack(spacing: 6) {
            if let icon { Image(systemName: icon) }
            Text(title)
        }
        .font(PD.FontToken.caption(12, weight: Font.Weight.semibold))
        .kerning(0.6)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Capsule())

        switch style {
        case .fill:
            label
                .foregroundStyle(Color.black)
                .background(Capsule().fill(BrandGradient.linear))
                .overlay(Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
                .shadow(color: shadowed ? Color.black.opacity(0.15) : .clear, radius: 10, y: shadowed ? 6 : 0)
                .frame(height: 36)
                .frame(maxWidth: wide ? .infinity : nil, alignment: .center)
        case .outline:
            label
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .background(Capsule().fill(Color.clear))
                .overlay(Capsule().stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1.2))
                .frame(height: 36)
                .frame(maxWidth: wide ? .infinity : nil, alignment: .center)
        }
    }
}


private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

public struct MDContinueSection: View {
    public var title: String
    public var items: [(String, Double)]
    public var onTap: (Int) -> Void

    public typealias BannerInfo = (title: String, progress: Double, category: String)
    public typealias WeeklyStats = (stars: Int, likes: Int, drills: Int)
    public var bannerProvider: ((Date) -> BannerInfo)? = nil
    public var weekProvider: ((Int) -> [WeeklyResumeItem])? = nil
    public var statsProvider: ((Int) -> WeeklyStats)? = nil // input: weekOffset
    public var onTapEmptyDay: ((WeeklyResumeItem) -> Void)? = nil
    public var onTapDaySummary: ((WeeklyResumeItem) -> Void)? = nil

    @State private var selected: Int = 3
    public var selectedIndex: Binding<Int>? = nil
    @State private var weekOffset: Int = 0
    @State private var didInit: Bool = false

    public init(
        _ title: String = "ПРОДОЛЖИТЬ",
        items: [(String, Double)],
        bannerProvider: ((Date) -> BannerInfo)? = nil,
        weekProvider: ((Int) -> [WeeklyResumeItem])? = nil,
        statsProvider: ((Int) -> WeeklyStats)? = nil,
        onTapEmptyDay: ((WeeklyResumeItem) -> Void)? = nil,
        onTapDaySummary: ((WeeklyResumeItem) -> Void)? = nil,
        selectedIndex: Binding<Int>? = nil,
        onTap: @escaping (Int) -> Void
    ) {
        self.title = title
        self.items = items
        self.bannerProvider = bannerProvider
        self.weekProvider = weekProvider
        self.statsProvider = statsProvider
        self.onTapEmptyDay = onTapEmptyDay
        self.onTapDaySummary = onTapDaySummary
        self.selectedIndex = selectedIndex
        self.onTap = onTap
    }


    public var body: some View {
        // Precompute week slice and header outside ViewBuilder
        let week: [WeeklyResumeItem] = {
            let cal = MDBangkokCalendar.cal
            let now = Date()
            let startThisWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: startThisWeek) ?? startThisWeek
            if let makeWeek = weekProvider { return makeWeek(weekOffset) }
            return (0..<7).map { i in
                let day = cal.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
                let weekdayIndex = max(1, min(7, cal.component(.weekday, from: day)))
                let wd = cal.shortWeekdaySymbols[weekdayIndex - 1].lowercased()
                return WeeklyResumeItem(weekdayShort: wd, date: day)
            }
        }()

        VStack(alignment: .leading, spacing: 12) {

            // --- Section title row: only title now, без календаря и стрелок
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .taikaSectionTitleStyle()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)

            WeeklyResumeStrip(
                items: week,
                layout: .carousel,
                onTapDay: { tapped in
                    if let idx = week.firstIndex(where: { MDBangkokCalendar.cal.isDate($0.date, inSameDayAs: tapped.date) }) {
                        if let selectedIndex {
                            selectedIndex.wrappedValue = idx
                        } else {
                            selected = idx
                        }
                    }
                    if tapped.isEmpty {
                        onTapEmptyDay?(tapped)
                    } else {
                        onTapDaySummary?(tapped)
                    }
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.vertical, 2)

        }
        .padding(.top, 20)
        .padding(.bottom, 4)
        .onAppear {
            // if selection is controlled by the View layer, do not auto-reset here
            guard selectedIndex == nil else { return }
            guard !didInit else { return }
            didInit = true

            let hasItems = !items.isEmpty
            let weekMax = max(0, week.count - 1)
            let itemsMax = hasItems ? max(0, items.count - 1) : weekMax
            let effectiveMax = min(weekMax, itemsMax)

            // for the fixed [-3,+3] carousel today is always index 3
            if selected < 0 || selected > effectiveMax {
                selected = min(max(0, 3), effectiveMax)
            }
        }
        .onChange(of: weekOffset) { _, _ in
            guard selectedIndex == nil else { return }
            let hasItems = !items.isEmpty
            let weekMax = max(0, week.count - 1)
            let itemsMax = hasItems ? max(0, items.count - 1) : weekMax
            let effectiveMax = min(weekMax, itemsMax)

            let prevIndex = selected
            let clampedPrev = max(0, min(prevIndex, effectiveMax))

            selected = clampedPrev
        }
    }
}

// MARK: - Lightweight exports for View-layer composition

/// minimal calendar carousel without headers/stats/cta
public struct MDWeekCarousel: View {
    public var items: [WeeklyResumeItem]
    @Binding public var selected: Int
    public var onTapDay: ((WeeklyResumeItem) -> Void)?

    public init(
        items: [WeeklyResumeItem],
        selected: Binding<Int>,
        onTapDay: ((WeeklyResumeItem) -> Void)? = nil
    ) {
        self.items = items
        self._selected = selected
        self.onTapDay = onTapDay
    }

    public var body: some View {
        WeeklyResumeStrip(
            items: items,
            layout: .carousel,
            onTapDay: { tapped in
                // update selection to the tapped day
                if let idx = items.firstIndex(where: { MDBangkokCalendar.cal.isDate($0.date, inSameDayAs: tapped.date) }) {
                    selected = idx
                }
                onTapDay?(tapped)
            }
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - DS: two-row carousel (free row + pro row)

/// A pure-DS layout helper: renders two horizontal rows (Free then Pro).
/// Card visuals are provided by the caller via `card` builder.
public struct MDTwoRowCourseCarousel<Item: Identifiable, Card: View>: View {

    public struct RowConfig: Equatable {
        public var title: String
        public var showsTitle: Bool
        public var topPadding: CGFloat
        public var bottomPadding: CGFloat

        public init(title: String, showsTitle: Bool = false, topPadding: CGFloat = 8, bottomPadding: CGFloat = 6) {
            self.title = title
            self.showsTitle = showsTitle
            self.topPadding = topPadding
            self.bottomPadding = bottomPadding
        }
    }

    public var freeTitle: RowConfig
    public var proTitle: RowConfig

    public var free: [Item]
    public var pro: [Item]

    public var cardWidth: CGFloat
    public var cardSpacing: CGFloat

    @ViewBuilder public var card: (Item) -> Card

    public init(
        freeTitle: RowConfig = .init(title: "free", showsTitle: false),
        proTitle: RowConfig  = .init(title: "pro", showsTitle: false),
        free: [Item],
        pro: [Item],
        cardWidth: CGFloat = 268,
        cardSpacing: CGFloat = 12,
        @ViewBuilder card: @escaping (Item) -> Card
    ) {
        self.freeTitle = freeTitle
        self.proTitle = proTitle
        self.free = free
        self.pro = pro
        self.cardWidth = cardWidth
        self.cardSpacing = cardSpacing
        self.card = card
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            if !free.isEmpty {
                row(title: freeTitle, items: free)
            }

            if !pro.isEmpty {
                row(title: proTitle, items: pro)
            }
        }
    }

    @ViewBuilder
    private func row(title: RowConfig, items: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if title.showsTitle {
                Text(title.title.uppercased())
                    .taikaSectionTitleStyle()
                    .padding(.horizontal, Theme.Layout.pageHorizontal)
            }

            GeometryReader { outer in
                let allowsPeek = items.count > 1
                let effectiveCardW = allowsPeek
                    ? cardWidth
                    : min(cardWidth, max(0, outer.size.width - (PD.Spacing.screen * 2)))
                let sideInset = max(0, (outer.size.width - effectiveCardW) / 2)
                TaikaCarouselScroll {
                    LazyHStack(spacing: allowsPeek ? cardSpacing : 0) {
                        ForEach(items) { it in
                            GeometryReader { cellGeo in
                                let viewportCenterX = outer.size.width / 2
                                let cellCenterX = cellGeo.frame(in: .named("mdRowCarousel")).midX
                                let dist = abs(cellCenterX - viewportCenterX)
                                let norm = allowsPeek
                                    ? min(1.0, dist / max(1.0, outer.size.width * Theme.Layout.carouselDepthNormWidthFactor))
                                    : 0
                                let scale = Theme.Layout.carouselDepthScaleSide + (Theme.Layout.carouselDepthScaleCenter - Theme.Layout.carouselDepthScaleSide) * (1.0 - norm)
                                let opacity = Theme.Layout.carouselDepthOpacitySide + (Theme.Layout.carouselDepthOpacityCenter - Theme.Layout.carouselDepthOpacitySide) * (1.0 - norm)
                                let yOffset = -(1.0 - norm) * Theme.Layout.carouselDepthYOffsetMax

                                card(it)
                                    .frame(width: effectiveCardW)
                                    .scaleEffect(scale)
                                    .opacity(opacity)
                                    .offset(y: yOffset)
                                    .zIndex(Double(1.0 - norm))
                            }
                            .frame(width: effectiveCardW)
                            .id(it.id)
                        }
                    }
                    .padding(.horizontal, sideInset)
                    .padding(.vertical, Theme.Layout.carouselVPad)
                }
                .coordinateSpace(name: "mdRowCarousel")
                .scrollDisabled(!allowsPeek)
            }
            .frame(height: 220)
        }
        .padding(.top, title.topPadding)
        .padding(.bottom, title.bottomPadding)
    }
}

// MARK: - DS: Add Courses overlay content (two rows: free + pro)

/// Pure DS content for the "add courses" overlay.
/// Renders two horizontal rows: Free (tap-enabled in View layer) and Pro (disabled/upsell in View layer).
/// Visuals are provided by the caller via `card` builder.
public struct MDAddCoursesOverlayContent<Item: Identifiable, Card: View>: View {

    public struct Texts: Equatable {
        public var title: String
        public var subtitle: String

        public init(
            title: String = "добавить курс",
            subtitle: String = "выбери курс, чтобы добавить его в план на этот день"
        ) {
            self.title = title
            self.subtitle = subtitle
        }
    }

    public var texts: Texts

    public var free: [Item]
    public var pro: [Item]

    public var cardWidth: CGFloat
    public var cardSpacing: CGFloat

    @ViewBuilder public var card: (Item) -> Card

    public init(
        texts: Texts = .init(),
        free: [Item],
        pro: [Item],
        cardWidth: CGFloat = 268,
        cardSpacing: CGFloat = 12,
        @ViewBuilder card: @escaping (Item) -> Card
    ) {
        self.texts = texts
        self.free = free
        self.pro = pro
        self.cardWidth = cardWidth
        self.cardSpacing = cardSpacing
        self.card = card
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            VStack(alignment: .leading, spacing: 6) {
                Text(texts.title)
                    .font(PD.FontToken.title(22, weight: Font.Weight.semibold))
                    .foregroundColor(PD.ColorToken.text)

                Text(texts.subtitle)
                    .font(PD.FontToken.body(14, weight: .regular))
                    .foregroundColor(PD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.top, 4)

            if free.isEmpty && pro.isEmpty {
                // DS-only empty state (View can override with its own)
                RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                    .fill(PD.ColorToken.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                            .stroke(PD.ColorToken.stroke, lineWidth: 1)
                    )
                    .frame(height: 120)
                    .overlay(
                        VStack(spacing: 6) {
                            Text("нет курсов")
                                .font(PD.FontToken.body(14, weight: Font.Weight.semibold))
                                .foregroundColor(PD.ColorToken.text)
                            Text("выбери курс для добавления")
                                .font(PD.FontToken.body(13, weight: .regular))
                                .foregroundColor(PD.ColorToken.textSecondary)
                        }
                        .padding(.horizontal, Theme.Layout.pageHorizontal)
                    )
                    .padding(.horizontal, Theme.Layout.pageHorizontal)
            } else {
                // Variant B: two separate rows (visually clean)
                MDTwoRowCourseCarousel(
                    freeTitle: .init(title: "free", showsTitle: true, topPadding: 2, bottomPadding: 6),
                    proTitle:  .init(title: "pro",  showsTitle: true, topPadding: 6, bottomPadding: 2),
                    free: free,
                    pro: pro,
                    cardWidth: cardWidth,
                    cardSpacing: cardSpacing,
                    card: card
                )
            }
        }
        .padding(.bottom, 6)
    }
}

/// Convenience splitter for callers (e.g. split by `isPro` flag in View layer).
public enum MDCourseRowSplit {
    public static func split<T>(
        _ items: [T],
        isPro: (T) -> Bool
    ) -> (free: [T], pro: [T]) {
        var free: [T] = []
        var pro: [T] = []
        free.reserveCapacity(items.count)
        pro.reserveCapacity(items.count)
        for it in items {
            if isPro(it) { pro.append(it) } else { free.append(it) }
        }
        return (free, pro)
    }
}

/// tiny helpers to reuse date/label logic from DS in Views without pulling the whole section
public enum MDWeekHelpers {
    /// "Неделя N · 1–7 окт" (TH locale uses Buddhist calendar & "d MMM y")
    public static func label(forWeekOffset weekOffset: Int, locale: Locale = .current) -> String {
        let cal = MDBangkokCalendar.cal
        let startThisWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: startThisWeek) ?? startThisWeek
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let weekNumber = cal.component(.weekOfYear, from: weekStart)

        let isThai = locale.identifier.lowercased().contains("_th") || locale.language.languageCode?.identifier.lowercased() == "th"
        let df = DateFormatter()
        df.locale = locale
        if isThai {
            df.calendar = Calendar(identifier: .buddhist)
            df.dateFormat = "d MMM y"
        } else {
            df.calendar = cal
            df.dateFormat = "d MMM"
        }
        return "Неделя \(weekNumber) · \(df.string(from: weekStart))–\(df.string(from: weekEnd))"
    }
}

// MARK: - Daily Picks (stub, non-bloating)
#if DEBUG
/// demo-only wrapper for previews; do not use in production.
/// use `MDDailyPicksComposite` from the View layer with real data + callbacks.
@available(*, deprecated, message: "demo-only; use MDDailyPicksComposite from View layer with real data")
internal struct MDDailyPicksDemoSection: View {
    @State private var steps: [SDStepItem] = []
    @State private var activeIndex: Int = 0
    init() {}
    var body: some View {
        SDStepCarousel(
            title: "ПОДБОРКА ДНЯ",
            items: steps,
            activeIndex: $activeIndex,
            isOverlay: false
        )
        .padding(.top, 12)
        .onAppear {
            // local preview/demo data — not compiled into release
            let base: [StepItem] = StepData.shared.allItems()
            let picked = Array(base.shuffled().prefix(5))
            self.steps = picked.map { it in
                let mappedKind: SDStepItem.Kind = {
                    switch it.kind {
                    case .word:   return .word
                    case .phrase: return .phrase
                    default:      return .phrase
                    }
                }()
                return SDStepItem(
                    kind: mappedKind,
                    titleRU: it.ru ?? "",
                    subtitleTH: it.thai ?? "",
                    phonetic: it.phonetic ?? ""
                )
            }
        }
    }
}
#endif

// MARK: - Daily Picks + Meta (course chip • lesson link • CTA)
// Pure DS: visuals only; actions are passed in from View layer.
public struct MDDailyPicksMetaRow: View {
    public var courseShort: String
    public var lessonShort: String
    public var onTapCourse: () -> Void
    public var onTapLesson: () -> Void
    public var onOpenCourse: () -> Void

    public init(
        courseShort: String,
        lessonShort: String,
        onTapCourse: @escaping () -> Void,
        onTapLesson: @escaping () -> Void,
        onOpenCourse: @escaping () -> Void
    ) {
        self.courseShort = courseShort
        self.lessonShort = lessonShort
        self.onTapCourse = onTapCourse
        self.onTapLesson = onTapLesson
        self.onOpenCourse = onOpenCourse
    }

    public var body: some View {
        let trimmedCourse = courseShort.trimmingCharacters(in: .whitespacesAndNewlines)
        // let trimmedLesson = lessonShort.trimmingCharacters(in: .whitespacesAndNewlines)
        let leftLabel = trimmedCourse

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if !leftLabel.isEmpty {
                Text(leftLabel)
                    .font(PD.FontToken.body(13, weight: Font.Weight.semibold))
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Button(action: onOpenCourse) {
                Text("ОТКРЫТЬ КУРС")
                    .taikaSubsectionStyle(accent: true)
            }
        }
        .padding(.horizontal, PD.Spacing.screen)
    }
}

public struct MDDailyPicksComposite: View {
    public var title: String
    public var items: [SDStepItem]
    public var courseShortNames: [String]     // parallel to items
    public var lessonShortNames: [String]     // parallel to items
    public var learned: Set<Int>
    public var favorites: Set<Int>
    @Binding public var activeIndex: Int
    public var onTapCourse: (Int) -> Void
    public var onTapLesson: (Int) -> Void
    public var onOpenCourse: (Int) -> Void
    public var onTapItem: ((Int) -> Void)?
    public var onPlay: ((Int) -> Void)?
    public var onDone: ((Int) -> Bool)?
    public var onFav: ((Int) -> Bool)?
    public var onIndexChange: ((Int) -> Void)?
    /// Когда false — не рисовать мини-прогресс (точки) внутри секции; вынести в MainView за рамки секции.
    public var showProgressRow: Bool = true

    public init(
        title: String = "ПОДБОРКА ДНЯ",
        items: [SDStepItem],
        courseShortNames: [String] = [],
        lessonShortNames: [String] = [],
        learned: Set<Int> = [],
        favorites: Set<Int> = [],
        activeIndex: Binding<Int>,
        onTapCourse: @escaping (Int) -> Void = { _ in },
        onTapLesson: @escaping (Int) -> Void = { _ in },
        onOpenCourse: @escaping (Int) -> Void = { _ in },
        onTapItem: ((Int) -> Void)? = nil,
        onPlay: ((Int) -> Void)? = nil,
        onDone: ((Int) -> Bool)? = nil,
        onFav: ((Int) -> Bool)? = nil,
        onIndexChange: ((Int) -> Void)? = nil,
        showProgressRow: Bool = true
    ) {
        self.title = title
        self.items = items
        self.courseShortNames = courseShortNames
        self.lessonShortNames = lessonShortNames
        self.learned = learned
        self.favorites = favorites
        self._activeIndex = activeIndex
        self.onTapCourse = onTapCourse
        self.onTapLesson = onTapLesson
        self.onOpenCourse = onOpenCourse
        self.onTapItem = onTapItem
        self.onPlay = onPlay
        self.onDone = onDone
        self.onFav = onFav
        self.onIndexChange = onIndexChange
        self.showProgressRow = showProgressRow
    }

    public init(
        title: String = "ПОДБОРКА ДНЯ",
        items: [SDStepItem],
        courseShortNames: [String] = [],
        lessonShortNames: [String] = [],
        learnedMask: [Bool] = [],
        favoritesMask: [Bool] = [],
        activeIndex: Binding<Int>,
        onTapCourse: @escaping (Int) -> Void = { _ in },
        onTapLesson: @escaping (Int) -> Void = { _ in },
        onOpenCourse: @escaping (Int) -> Void = { _ in },
        onTapItem: ((Int) -> Void)? = nil,
        onPlay: ((Int) -> Void)? = nil,
        onDone: ((Int) -> Bool)? = nil,
        onFav: ((Int) -> Bool)? = nil,
        onIndexChange: ((Int) -> Void)? = nil
    ) {
        self.title = title
        self.items = items
        self.courseShortNames = courseShortNames
        self.lessonShortNames = lessonShortNames
        let maxCount = items.count
        var learnedSet: Set<Int> = []
        var favoritesSet: Set<Int> = []
        for i in 0..<maxCount {
            if i < learnedMask.count, learnedMask[i] { learnedSet.insert(i) }
            if i < favoritesMask.count, favoritesMask[i] { favoritesSet.insert(i) }
        }
        self.learned = learnedSet
        self.favorites = favoritesSet
        self._activeIndex = activeIndex
        self.onTapCourse = onTapCourse
        self.onTapLesson = onTapLesson
        self.onOpenCourse = onOpenCourse
        self.onTapItem = onTapItem
        self.onPlay = onPlay
        self.onDone = onDone
        self.onFav = onFav
        self.onIndexChange = onIndexChange
    }

    public init(
        title: String = "ПОДБОРКА ДНЯ",
        items: [SDStepItem]
    ) {
        self.title = title
        self.items = items
        self.courseShortNames = []
        self.lessonShortNames = []
        self.learned = []
        self.favorites = []
        self._activeIndex = .constant(0)
        self.onTapCourse = { _ in }
        self.onTapLesson = { _ in }
        self.onOpenCourse = { _ in }
        self.onTapItem = nil
        self.onPlay = nil
        self.onDone = nil
        self.onFav = nil
        self.onIndexChange = nil
    }

    private func lessonNameDerived(at i: Int) -> String {
        if i >= 0, i < lessonShortNames.count {
            let val = lessonShortNames[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if !val.isEmpty { return val }
        }
        return ""
    }
    private func courseNameDerived(at i: Int) -> String {
        if i >= 0, i < courseShortNames.count, !courseShortNames[i].isEmpty { return courseShortNames[i] }
        return ""
    }

    private func nextIndex(from i: Int) -> Int { min(max(0, i + 1), max(0, items.count - 1)) }
    private func prevIndex(from i: Int) -> Int { max(0, min(items.count - 1, i - 1)) }

    @State private var now: Date = Date()

    private var refreshCountdownLabel: String {
        MDDailyRefreshCountdown.label(now: now)
    }

    private var sectionCountdownTitle: String {
        let label = refreshCountdownLabel.uppercased()
        if label == "СКОРО" { return "СКОРО ОБНОВЛЕНИЕ" }
        return "ЧЕРЕЗ \(label)"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
            VStack(alignment: .leading, spacing: 8) {
                // Таймер — это название секции (стиль pip + caps), без отдельного бейджа и без дубля «РАЗМИНКА».
                TaikaSectionHeaderRow(sectionCountdownTitle)

                if !items.isEmpty {
                    let courseTitle = courseNameDerived(at: activeIndex)
                    let lessonTitle = lessonNameDerived(at: activeIndex)
                    let normalizedCourse = courseTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let normalizedLesson = lessonTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let isProActive = activeIndex >= 0
                        && activeIndex < items.count
                        && items[activeIndex].isPro
                    let showsLesson = !isProActive
                        && !lessonTitle.isEmpty
                        && normalizedLesson != normalizedCourse

                    VStack(alignment: .leading, spacing: 5) {
                        if isProActive {
                            Text("TAIKA+ · ПОДБОРКА ДНЯ")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                .lineLimit(1)
                        } else if !courseTitle.isEmpty {
                            Button {
                                onOpenCourse(activeIndex)
                            } label: {
                                Text(courseTitle.uppercased())
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Открыть курс \(courseTitle)")
                        }

                        if showsLesson {
                            Button {
                                onTapLesson(activeIndex)
                            } label: {
                                Text(lessonTitle)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Открыть урок \(lessonTitle)")
                        }
                    }
                }
            }
            .padding(.horizontal, PD.Spacing.screen)
            .animation(.easeOut(duration: 0.2), value: activeIndex)
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
                let prevDay = MDBangkokCalendar.cal.startOfDay(for: now)
                now = date
                let newDay = MDBangkokCalendar.cal.startOfDay(for: date)
                if newDay != prevDay {
                    NotificationCenter.default.post(name: Notification.Name("DailyPicksDidReset"), object: nil)
                }
            }

            // Карусель + прогресс-ряд: отступ сверху как в CDSectionWithAction (sectionTitleToContent)
            VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
                ZStack(alignment: .center) {
                    SDStepCarousel(
                        title: "",
                        items: items,
                        activeIndex: $activeIndex,
                        learned: learned,
                        favorites: favorites,
                        onTap: { item in
                            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                onTapItem?(idx)
                            }
                        },
                        onPlay: { item in
                            if let idx = items.firstIndex(where: { $0.id == item.id }) { onPlay?(idx) }
                        },
                        onFav: { item in
                            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                // Лайк/избранное — только тоггл, без перелистывания.
                                // Листает только «запомнил» (onDone).
                                _ = onFav?(idx)
                            }
                        },
                        onDone: { item in
                            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                let shouldAdvance = onDone?(idx) ?? true
                                if shouldAdvance {
                                    let delay: TimeInterval = 0.2
                                    let next = min(max(0, activeIndex + 1), max(0, items.count - 1))
                                    if next != activeIndex {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                                activeIndex = next
                                            }
                                            onIndexChange?(activeIndex)
                                        }
                                    }
                                }
                            }
                        },
                        isOverlay: false,
                        loop: false,
                        compactSection: true
                    )
                    .environment(\.taikaStepActionCaptions, true)
                    .onChange(of: activeIndex) { _, newValue in
                        onIndexChange?(newValue)
                    }
                }
                .frame(maxWidth: .infinity)

                if showProgressRow, !items.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(0..<items.count), id: \.self) { (idx: Int) in
                            let isActive = (idx == activeIndex)
                            let isPro = items[idx].isPro
                            let isLearned = isPro ? true : learned.contains(idx)
                            let isFavorite = isPro ? false : favorites.contains(idx)
                            SDStepProgressSegment(
                                width: 22,
                                isActive: isActive,
                                isLearned: isLearned,
                                isFavorite: isFavorite,
                                isPro: isPro,
                                index: idx,
                                onTap: { tapped in
                                    guard tapped >= 0, tapped < items.count else { return }
                                    activeIndex = tapped
                                    onIndexChange?(activeIndex)
                                }
                            )
                            .accessibilityLabel(isPro ? "pro" : "")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, Theme.Layout.sectionTitleToContent)
        }
    }
}

// MARK: - Портретные карусели Main (как Favorites / Подборка дня)
public enum MDPortraitCarouselMetrics {
    public static let cardWidth: CGFloat = 200
    public static let cardHeight: CGFloat = 286
    public static let spacing: CGFloat = 14
    public static let slotHeight: CGFloat = cardHeight + 36
}

/// Точки пагинации карусели (легче, чем SDStepProgressSegment).
public struct MDCarouselPageDots: View {
    public let count: Int
    @Binding public var activeIndex: Int
    public var onSelect: (Int) -> Void

    public init(count: Int, activeIndex: Binding<Int>, onSelect: @escaping (Int) -> Void = { _ in }) {
        self.count = count
        self._activeIndex = activeIndex
        self.onSelect = onSelect
    }

    public var body: some View {
        if count <= 1 {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { idx in
                    let isActive = idx == activeIndex
                    Button {
                        guard idx != activeIndex else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        activeIndex = idx
                        onSelect(idx)
                    } label: {
                        Capsule(style: .continuous)
                            .fill(
                                isActive
                                ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.28))
                            )
                            .frame(width: isActive ? 18 : 6, height: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Карточка \(idx + 1) из \(count)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
        }
    }
}

/// Портретная карточка разминки — тот же каркас, что `FDFavPhraseCard`.
public struct MDWarmupPhraseCard: View {
    public let thai: String
    public let titleRU: String
    public let phonetic: String
    public let lessonCaption: String
    public var layoutWidth: CGFloat = MDPortraitCarouselMetrics.cardWidth
    public var layoutHeight: CGFloat = MDPortraitCarouselMetrics.cardHeight
    public var isFavorite: Bool
    public var isLearned: Bool
    public var isPro: Bool
    public var onSpeak: () -> Void
    public var onFavorite: () -> Void
    public var onLearn: () -> Void
    public var onTap: () -> Void

    public init(
        thai: String,
        titleRU: String,
        phonetic: String,
        lessonCaption: String,
        layoutWidth: CGFloat = MDPortraitCarouselMetrics.cardWidth,
        layoutHeight: CGFloat = MDPortraitCarouselMetrics.cardHeight,
        isFavorite: Bool,
        isLearned: Bool,
        isPro: Bool,
        onSpeak: @escaping () -> Void,
        onFavorite: @escaping () -> Void,
        onLearn: @escaping () -> Void,
        onTap: @escaping () -> Void
    ) {
        self.thai = thai
        self.titleRU = titleRU
        self.phonetic = phonetic
        self.lessonCaption = lessonCaption
        self.layoutWidth = layoutWidth
        self.layoutHeight = layoutHeight
        self.isFavorite = isFavorite
        self.isLearned = isLearned
        self.isPro = isPro
        self.onSpeak = onSpeak
        self.onFavorite = onFavorite
        self.onLearn = onLearn
        self.onTap = onTap
    }

    public var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        let thaiSize = min(22, max(16, layoutWidth * 0.105))
        let phon = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = lessonCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "урок" : lessonCaption

        VStack(alignment: .leading, spacing: 12) {
            Text("taikA")
                .font(Font.custom("ONMARK Trial", size: 14))
                .foregroundStyle(PD.ColorToken.textSecondary)

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Text(thai)
                    .font(.system(size: thaiSize, weight: .medium))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)

                Text(titleRU)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                    .frame(maxWidth: .infinity)

                if !phon.isEmpty {
                    Text(phon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                }

                Text(caption)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSpeak()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(minWidth: 34, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            isFavorite
                            ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                            : AnyShapeStyle(PD.ColorToken.textSecondary)
                        )
                        .frame(minWidth: 34, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if isLearned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .frame(minWidth: 28, minHeight: 32)
                        .allowsHitTesting(false)
                } else {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onLearn()
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .frame(minWidth: 28, minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: layoutWidth, height: layoutHeight, alignment: .topLeading)
        .background(Theme.Surfaces.card(round))
        .contentShape(round)
        .onTapGesture { onTap() }
        .opacity(isPro ? 0.88 : 1)
    }
}

// MARK: - Разминка: мини-прогресс (legacy; на Main — `MDCarouselPageDots`)
public struct MDDailyPicksProgressRow: View {
    public let items: [SDStepItem]
    @Binding public var activeIndex: Int
    public let learned: Set<Int>
    public let favorites: Set<Int>
    public var onIndexChange: (Int) -> Void

    @ViewBuilder
    public var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                ForEach(Array(0..<items.count), id: \.self) { (idx: Int) in
                    let isActive = (idx == activeIndex)
                    let isPro = items[idx].isPro
                    let isLearned = isPro ? true : learned.contains(idx)
                    let isFavorite = isPro ? false : favorites.contains(idx)
                    SDStepProgressSegment(
                        width: 22,
                        isActive: isActive,
                        isLearned: isLearned,
                        isFavorite: isFavorite,
                        isPro: isPro,
                        index: idx,
                        onTap: { tapped in
                            guard tapped >= 0, tapped < items.count else { return }
                            activeIndex = tapped
                            onIndexChange(tapped)
                        }
                    )
                    .accessibilityLabel(isPro ? "pro" : "")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: Vertical "reels" style card for horizontal carousel


// MARK: Vertical list section (editorial picks)



// MARK: - DS: Tech resume banners (Main) — минималистичные баннеры + автокарусель

public struct MDTechResumeBannerModel: Identifiable, Equatable {
    public let id: String
    public let eyebrow: String
    public let title: String
    /// Короткое описание курса / контекст урока.
    public let detailLine: String?
    /// Мотивационный статус (как chip статуса курса) — угол карточки.
    public let motivationChip: String?
    public let motivationKind: AppStatusKind
    public let statsLine: String?
    public let ctaTitle: String
    public let isEmpty: Bool
    /// Вариация волны на фоне (чтобы карточки в карусели не были клонами).
    public let waveSeed: Int
    /// Прогресс курса/урока 0...1 — для кольца на карточке «Продолжить».
    public let progressFraction: Double

    public init(
        id: String,
        eyebrow: String,
        title: String,
        detailLine: String?,
        motivationChip: String?,
        motivationKind: AppStatusKind = .inProgress,
        statsLine: String?,
        ctaTitle: String,
        isEmpty: Bool = false,
        waveSeed: Int = 0,
        progressFraction: Double = 0
    ) {
        self.id = id
        self.eyebrow = eyebrow
        self.title = title
        self.detailLine = detailLine
        self.motivationChip = motivationChip
        self.motivationKind = motivationKind
        self.statsLine = statsLine
        self.ctaTitle = ctaTitle
        self.isEmpty = isEmpty
        self.waveSeed = waveSeed
        self.progressFraction = progressFraction
    }

    public static func emptyState() -> MDTechResumeBannerModel {
        MDTechResumeBannerModel(
            id: "continue-empty",
            eyebrow: "СТАРТ",
            title: "Твой первый курс",
            detailLine: "Открой каталог — продолжение появится здесь",
            motivationChip: "новый",
            motivationKind: .new,
            statsLine: nil,
            ctaTitle: "Выбрать",
            isEmpty: true,
            waveSeed: 0,
            progressFraction: 0
        )
    }
}


// MARK: - DS: Continue hero (Main) — единая карточка: курс + кольцо + неделя + CTA

public struct MDContinueHeroModel: Equatable {
    public let courseTitle: String
    /// «Урок 12 из 24» или короткий контекст урока.
    public let metaLine: String?
    /// Следующий урок — только если отличается от названия курса.
    public let focusLessonTitle: String?
    public let durationMinutes: Int?
    public let progress: Double
    public let isEmpty: Bool

    public init(
        courseTitle: String,
        metaLine: String?,
        focusLessonTitle: String? = nil,
        durationMinutes: Int?,
        progress: Double,
        isEmpty: Bool = false
    ) {
        self.courseTitle = courseTitle
        self.metaLine = metaLine
        self.focusLessonTitle = focusLessonTitle
        self.durationMinutes = durationMinutes
        self.progress = progress
        self.isEmpty = isEmpty
    }

    public static func emptyState() -> MDContinueHeroModel {
        MDContinueHeroModel(
            courseTitle: "Начни обучение",
            metaLine: "Выбери курс в каталоге",
            focusLessonTitle: nil,
            durationMinutes: nil,
            progress: 0,
            isEmpty: true
        )
    }
}

/// Карточка «Продолжить» на Main: только курс, время, CTA. Без кольца и лишних строк.
public struct MDContinueHeroCard: View {
    public let model: MDContinueHeroModel
    public let onContinue: () -> Void

    public init(
        model: MDContinueHeroModel,
        onContinue: @escaping () -> Void
    ) {
        self.model = model
        self.onContinue = onContinue
    }

    private let cardCorner: CGFloat = Theme.Radii.card

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        let shape = RoundedRectangle(cornerRadius: cardCorner, style: .continuous)

        Button(action: onContinue) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.courseTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let mins = model.durationMinutes, mins > 0 {
                    Text("≈ \(mins) \(minutesLabel(mins))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                } else if let meta = model.metaLine, !meta.isEmpty {
                    Text(meta)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .lineLimit(1)
                }

                Text(model.isEmpty ? "Начать →" : "Продолжить →")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Theme.Surfaces.card(shape))
    }

    private func minutesLabel(_ mins: Int) -> String {
        let mod10 = mins % 10
        let mod100 = mins % 100
        if mod10 == 1 && mod100 != 11 { return "минута" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "минуты" }
        return "минут"
    }
}

// MARK: - DS: Continue (Main) — legacy compact card (fallback)

/// Карточка последнего урока/курса: заголовок, прогресс, одна кнопка CTA. Без «тап — продолжить».
public struct MDContinueCard: View {
    public var title: String
    public var progress: Double
    public var isEmpty: Bool
    /// Текст чипа: nil = по умолчанию (старт/курс), иначе «урок»/«курс»
    public var chipTitle: String?
    public var onTap: () -> Void

    public init(
        title: String,
        progress: Double = 0,
        isEmpty: Bool = false,
        chipTitle: String? = nil,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.progress = progress
        self.isEmpty = isEmpty
        self.chipTitle = chipTitle
        self.onTap = onTap
    }

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Layout.Section.itemGap) {
                HStack(alignment: .top) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    AppMiniChip(title: chipTitle ?? (isEmpty ? "старт" : "курс"), style: .neutral) { }
                        .allowsHitTesting(false)
                }

                if !isEmpty && progress >= 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(PD.ColorToken.textSecondary.opacity(0.2))
                                .frame(maxWidth: .infinity, maxHeight: 6)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(AnyShapeStyle(accent))
                                .scaleEffect(x: max(0.001, CGFloat(progress)), y: 1, anchor: .leading)
                                .frame(maxWidth: .infinity, maxHeight: 6)
                        }
                        .frame(height: 6)
                        Text("\(Int(round(progress * 100)))% пройдено")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                }

                HStack {
                    Spacer(minLength: 0)
                    Text(isEmpty ? "Начать" : "Продолжить")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .stroke(accent, lineWidth: 1.5)
                        )
                }
            }
            .padding(Theme.Layout.Section.contentHorizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 100)
            .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: Theme.Radii.card, style: .continuous)))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radii.card, style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - DS: Search (Main)

/// Pure DS search bar for Main screen.
/// View-layer decides how to handle filtering/navigation; DS renders only visuals.
public struct MDSearchSection: View {
    @Binding public var query: String
    public var placeholder: String

    public init(
        query: Binding<String>,
        placeholder: String = "поиск по курсам и урокам"
    ) {
        self._query = query
        self.placeholder = placeholder
    }

    public var body: some View {
        let hPad = max(0, PD.Spacing.screen - 4)

        return VStack(alignment: .leading, spacing: 10) {
            Text("ПОИСК")
                .taikaSectionTitleStyle()
                .padding(.horizontal, PD.Spacing.screen)

            TaikaSearchBubble(
                query: $query,
                placeholder: placeholder,
                onSubmit: { _ in }
            )
            .padding(.horizontal, hPad)
        }
        .padding(.top, Theme.Layout.Section.contentTop)
        .padding(.bottom, Theme.Layout.Section.contentBottom)
    }
}


// MARK: - DS: Taika FM Section
public struct MDFMSection: View {
    public var title: String
    public var messages: [String]

    public init(_ title: String = "ТАЙКА FM", messages: [String] = []) {
        self.title = title
        self.messages = messages
    }

    public var body: some View {
        TaikaFMSection(
            title: title,
            scope: .main,
            overrideMessages: messages.isEmpty ? nil : messages,
            mode: .typing,
            showBubble: false,
            repeats: true
        )
    }
}


// MARK: - Preview helpers
#if DEBUG
private struct MDDailyPicksPreviewHost: View {
    @State private var idx: Int = 0
    let demoItems: [SDStepItem]
    let courseNames: [String]
    let lessonNames: [String]

    var body: some View {
        MDDailyPicksComposite(
            title: "ПОДБОРКА ДНЯ",
            items: demoItems,
            courseShortNames: courseNames,
            lessonShortNames: lessonNames,
            learnedMask: [],
            favoritesMask: [],
            activeIndex: $idx,
            onTapCourse: { _ in },
            onTapLesson: { _ in },
            onOpenCourse: { _ in }
        )
    }
}

private struct MDSearchPreviewHost: View {
    @State private var q: String = ""
    var body: some View {
        MDSearchSection(query: $q)
    }
}
#endif

// MARK: - Instant Speaker portal (Main → «Скажи сам»)

/// Canned demo для tone-aha перед paywall (не на Main).
public enum MainInstantSpeakerDemo {
    public static let thai = "ไม่เผ็ด"
    public static let ru = "Без острого"
    public static let phonetic = "май→ пхет↘"
    public static let toneLabels: [(syllable: String, arrow: String, toneRU: String)] = [
        ("май", "→", "средний"),
        ("пхет", "↘", "падающий")
    ]
}

/// Печатающийся заголовок как на taikaa.online: набор → пауза → стирание → следующая фраза.
/// Говорит от лица Taika: что делать на главной прямо сейчас.
public struct MDCyclingTypewriter: View {
    public var lines: [String]
    public var font: Font
    public var holdSeconds: TimeInterval
    public var charInterval: TimeInterval
    public var minHeight: CGFloat
    /// Цифры в строке — акцент + Skifer (для норм/статов внутри сообщения).
    public var accentDigits: Bool
    public var digitSize: CGFloat

    @State private var lineIndex = 0
    @State private var visibleCount = 0
    @State private var cursorOn = true
    @State private var task: Task<Void, Never>?

    public init(
        lines: [String],
        font: Font = .system(size: 24, weight: .bold),
        holdSeconds: TimeInterval = 2.2,
        charInterval: TimeInterval = 0.034,
        minHeight: CGFloat = 58,
        accentDigits: Bool = false,
        digitSize: CGFloat = 26
    ) {
        self.lines = lines.filter { !$0.isEmpty }
        self.font = font
        self.holdSeconds = holdSeconds
        self.charInterval = charInterval
        self.minHeight = minHeight
        self.accentDigits = accentDigits
        self.digitSize = digitSize
    }

    private var currentLine: String {
        guard !lines.isEmpty else { return "" }
        return lines[lineIndex % lines.count]
    }

    public var body: some View {
        let tint = ThemeManager.shared.currentAccentTintColor
        let visible = String(currentLine.prefix(visibleCount))
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            styledVisibleText(visible)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .animation(nil, value: visibleCount)
            Text("▍")
                .font(font)
                .foregroundStyle(tint)
                .opacity(cursorOn ? 1 : 0.12)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .onAppear { startLoop() }
        .onChange(of: lines) { _, _ in startLoop() }
        .onDisappear { task?.cancel() }
        .accessibilityLabel(currentLine)
    }

    @ViewBuilder
    private func styledVisibleText(_ visible: String) -> some View {
        if accentDigits {
            accentDigitText(visible)
        } else {
            Text(visible)
                .font(font)
                .foregroundStyle(PD.ColorToken.text)
        }
    }

    private func accentDigitText(_ visible: String) -> Text {
        var result = Text("")
        var index = visible.startIndex
        while index < visible.endIndex {
            if visible[index].isNumber {
                var end = index
                while end < visible.endIndex, visible[end].isNumber {
                    end = visible.index(after: end)
                }
                result = result + Text(String(visible[index..<end]))
                    .font(.taikaStat(digitSize))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .monospacedDigit()
                index = end
            } else {
                var end = index
                while end < visible.endIndex, !visible[end].isNumber {
                    end = visible.index(after: end)
                }
                result = result + Text(String(visible[index..<end]))
                    .font(font)
                    .foregroundStyle(PD.ColorToken.text)
                index = end
            }
        }
        return result
    }

    private func startLoop() {
        task?.cancel()
        guard !lines.isEmpty else { return }
        lineIndex = 0
        visibleCount = 0
        cursorOn = true
        task = Task { @MainActor in
            while !Task.isCancelled {
                let line = lines[lineIndex % lines.count]
                let chars = Array(line)
                // type
                for i in 0...chars.count {
                    if Task.isCancelled { return }
                    visibleCount = i
                    cursorOn.toggle()
                    if i < chars.count {
                        try? await Task.sleep(nanoseconds: UInt64(charInterval * 1_000_000_000))
                    }
                }
                // hold
                let holdSteps = Int(holdSeconds / 0.35)
                for _ in 0..<max(1, holdSteps) {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    cursorOn.toggle()
                }
                // erase
                for i in stride(from: chars.count, through: 0, by: -1) {
                    if Task.isCancelled { return }
                    visibleCount = i
                    cursorOn.toggle()
                    try? await Task.sleep(nanoseconds: UInt64(charInterval * 0.55 * 1_000_000_000))
                }
                lineIndex = (lineIndex + 1) % lines.count
                try? await Task.sleep(nanoseconds: 180_000_000)
            }
        }
    }
}

/// Canonical Taika voice sphere shared by Main and Speaker.
/// Keep this as the single source of truth for the hero geometry and pulse treatment.
public struct MDVoiceSphere: View {
    public let symbol: String
    public let accessibilityLabel: String
    public let meter: Double
    public let action: () -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseOut = false

    public init(
        symbol: String = "mic.fill",
        accessibilityLabel: String = "Открыть спикер и начать запись",
        meter: Double = 0,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.accessibilityLabel = accessibilityLabel
        self.meter = meter
        self.action = action
    }

    public var body: some View {
        let accent = theme.currentAccentFill
        let tint = theme.currentAccentTintColor
        let voiceLevel = reduceMotion ? 0 : min(max(meter, 0), 1)

        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [tint.opacity(0.35), tint.opacity(0.08), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 150
                        )
                    )
                    .frame(width: 280, height: 120)
                    .blur(radius: 8)
                    .opacity(0.9)

                ZStack {
                    Circle()
                        .stroke(tint.opacity(pulseOut ? 0 : 0.55), lineWidth: 1.4)
                        .frame(width: 148, height: 148)
                        .scaleEffect(pulseOut ? 1.28 : 1.0)
                        .scaleEffect(1 + voiceLevel * 0.12)

                    Circle()
                        .stroke(tint.opacity(pulseOut ? 0 : 0.28), lineWidth: 1)
                        .frame(width: 172, height: 172)
                        .scaleEffect(pulseOut ? 1.18 : 1.0)
                        .scaleEffect(1 + voiceLevel * 0.16)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [tint.opacity(0.55), tint.opacity(0.12), tint.opacity(0)],
                                center: .center,
                                startRadius: 2,
                                endRadius: 90
                            )
                        )
                        .frame(width: 190, height: 190)
                        .scaleEffect(1 + voiceLevel * 0.08)

                    Circle()
                        .fill(accent)
                        .frame(width: 96, height: 96)
                        .scaleEffect(1 + voiceLevel * 0.12)
                        .shadow(color: tint.opacity(0.65), radius: 24, y: 8)

                    Image(systemName: symbol)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.black)
                        .scaleEffect(1 + voiceLevel * 0.08)
                }
                .animation(.easeOut(duration: 0.12), value: meter)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            withAnimation(.easeOut(duration: 2.1).repeatForever(autoreverses: false)) {
                pulseOut = true
            }
        }
    }
}

/// Главный сценарий Main: живой typewriter-заголовок от Taika + микрофон как главный wow.
public struct MDPromptHero: View {
    public var greeting: String
    public var tagline: String
    public var onOpenSpeaker: () -> Void

    public init(
        greeting: String,
        tagline: String = "Говори. Учись. Живи по-тайски.",
        onOpenSpeaker: @escaping () -> Void
    ) {
        self.greeting = greeting
        self.tagline = tagline
        self.onOpenSpeaker = onOpenSpeaker
    }

    private var headlineLines: [String] {
        [
            greeting,
            "Скажи по-русски — я переведу",
            "Учись короткими курсами",
            "Разминка — фразы на сегодня",
            "Жми на микрофон и говори"
        ]
    }

    public var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                MDCyclingTypewriter(
                    lines: headlineLines,
                    font: .system(size: 24, weight: .bold)
                )
                Text(tagline)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MDVoiceSphere(
                symbol: "mic.fill",
                accessibilityLabel: "Открыть спикер и начать запись",
                action: onOpenSpeaker
            )

            MDExamplePhraseMarquee(onTapPhrase: onOpenSpeaker)
        }
        .padding(.horizontal, Theme.Layout.pageHorizontal)
    }
}

/// Бесконечная карусель чипов с примерами фраз — лёгкий marquee без паузы.
public struct MDExamplePhraseMarquee: View {
    public var onTapPhrase: () -> Void

    private static let phrases: [String] = [
        "Можно счёт, пожалуйста",
        "Где туалет?",
        "Сколько стоит?",
        "Без острого",
        "Можно QR?",
        "Я не понимаю",
        "Повторите, пожалуйста",
        "Это слишком дорого",
        "Есть другой вариант?",
        "Как пройти к метро?",
        "Возьмите сдачу",
        "Можно без льда?",
        "Забронировано на моё имя",
        "Wi‑Fi есть?",
        "Подождите минутку"
    ]

    @State private var rowWidth: CGFloat = 0

    public init(onTapPhrase: @escaping () -> Void) {
        self.onTapPhrase = onTapPhrase
    }

    public var body: some View {
        Color.clear
            .frame(height: 34)
            .overlay(alignment: .leading) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let speed: CGFloat = 26
                    let shift: CGFloat = {
                        guard rowWidth > 1 else { return 0 }
                        let t = context.date.timeIntervalSinceReferenceDate
                        return CGFloat(t * Double(speed)).truncatingRemainder(dividingBy: rowWidth)
                    }()

                    HStack(spacing: 0) {
                        phraseRow
                            .background(
                                GeometryReader { g in
                                    Color.clear.preference(key: MDMarqueeWidthKey.self, value: g.size.width)
                                }
                            )
                        phraseRow
                            .accessibilityHidden(true)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: -shift)
                }
            }
            .clipped()
            .mask(
                LinearGradient(
                    colors: [.clear, .white, .white, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onPreferenceChange(MDMarqueeWidthKey.self) { rowWidth = $0 }
            .accessibilityLabel("Примеры фраз для спикера")
    }

    private var phraseRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(Self.phrases.enumerated()), id: \.offset) { _, phrase in
                phraseChip(phrase)
            }
        }
        .padding(.trailing, 8)
    }

    private func phraseChip(_ phrase: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTapPhrase()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                Text(phrase)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(PD.ColorToken.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(PD.ColorToken.chip))
        }
        .buttonStyle(.plain)
    }
}

private struct MDMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Main pill CTAs (как «Начать тренировку» в Спикере)

/// Залитая градиентная pill-CTA на Main: «Начать обучение» / «Продолжить …».
public struct MDMainFilledPillCTA: View {
    public var title: String
    public var icon: String
    public var action: () -> Void

    public init(
        title: String,
        icon: String = "graduationcap.fill",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(ThemeManager.shared.currentAccentFill)
            )
            .shadow(
                color: ThemeManager.shared.currentAccentTintColor.opacity(0.32),
                radius: 14,
                y: 4
            )
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
    }
}

/// Outline pill-CTA с опциональной заливкой прогресса (Разминка: остаток суток).
public struct MDMainOutlinePillCTA: View {
    public var title: String
    public var icon: String?
    /// 0...1 — доля заполнения слева направо (полная = 100% суток).
    public var progressFill: CGFloat?
    public var action: () -> Void

    public init(
        title: String,
        icon: String? = nil,
        progressFill: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.progressFill = progressFill
        self.action = action
    }

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        let fill = min(1, max(0, progressFill ?? 0))
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.clear)
                        if progressFill != nil {
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.22))
                                .frame(width: max(0, geo.size.width * fill))
                        }
                    }
                }
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent, lineWidth: 1.6)
            )
            .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
    }
}

/// Daily warmup entry point: one centered copy slot with icon-only lightning motion.
/// The slot alternates between the action name and one short value explanation, never both at once.
public struct MDDailyWarmupPillCTA: View {
    public let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let messages = [
        "случайная подборка на сегодня",
        "пара фраз — разогреть речь",
        "бесплатная практика каждый день"
    ]

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill

        TimelineView(.periodic(from: .now, by: reduceMotion ? 60 : 0.12)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let messageIndex = Int(elapsed / 4.5) % (messages.count + 1)
            let pulse = reduceMotion ? 0.0 : max(0, sin(elapsed * 2.8))
            let copy = messageIndex == 0 ? "Разминка" : messages[messageIndex - 1]

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                action()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                        .scaleEffect(1.0 + pulse * 0.18)
                        .opacity(0.82 + pulse * 0.18)
                        .frame(width: 28, height: 28)

                    ZStack {
                        Text(copy)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .contentTransition(.opacity)
                    }
                    .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: messageIndex)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .opacity(0.72)
                        .frame(width: 28, height: 20, alignment: .center)
                }
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 13)
                .padding(.horizontal, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(PD.ColorToken.chip.opacity(0.54))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(accent.opacity(0.78), lineWidth: 1.2)
                        )
                )
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
            .accessibilityLabel("Разминка, ежедневная подборка фраз")
            .accessibilityHint("Открыть бесплатную практику на сегодня")
        }
    }
}

/// Одно простое действие-строка (например «Разминка»): иконка, заголовок + опциональный бейдж, мета, шеврон.
public struct MDSingleActionCard: View {
    public var icon: String
    public var title: String
    public var titleBadge: String?
    public var subtitle: String
    public var action: () -> Void

    public init(
        icon: String,
        title: String,
        titleBadge: String? = nil,
        subtitle: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.titleBadge = titleBadge
        self.subtitle = subtitle
        self.action = action
    }

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(PD.ColorToken.chip))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.text)
                            .lineLimit(1)
                        if let titleBadge, !titleBadge.isEmpty {
                            Text(titleBadge)
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.5))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
        .background(Theme.Surfaces.card(shape))
    }
}

// MARK: - Daily refresh countdown

/// Подпись и прогресс до полуночи Бангкока — для чипа разминки.
public enum MDDailyRefreshCountdown {
    public static func remainingSeconds(now: Date = Date()) -> Int {
        let cal = MDBangkokCalendar.cal
        let dayStart = cal.startOfDay(for: now)
        guard let nextMidnight = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            return 0
        }
        return max(0, Int(nextMidnight.timeIntervalSince(now)))
    }

    /// Доля оставшихся суток (1 = только что после полуночи, 0 = почти полночь).
    public static func remainingFraction(now: Date = Date()) -> CGFloat {
        CGFloat(remainingSeconds(now: now)) / CGFloat(24 * 3600)
    }

    public static func label(now: Date = Date()) -> String {
        let remaining = remainingSeconds(now: now)
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        if hours > 0 { return "\(hours)ч \(minutes)м" }
        if minutes > 0 { return "\(minutes)м \(seconds)с" }
        if seconds > 0 { return "\(seconds)с" }
        return "скоро"
    }
}

// MARK: - Preview
 #Preview("Main DS") {
    ZStack {
        PD.ColorToken.background.ignoresSafeArea()
        TaikaRootVerticalScroll {
            VStack(spacing: 20) {
            MDFMSection("ТАЙКА FM", messages: [])

            MDContinueSection(
                "ПЛАН НА НЕДЕЛЮ",
                items: [
                    ("Разговорный минимум", 0.25),
                    ("Алфавит и чтение", 0.0),
                    ("Фразы на каждый день", 0.0)
                ],
                onTap: { _ in }
            )

            MDSearchPreviewHost()

            // 3) Подборка дня (как в главном экране)
            let demoItems: [SDStepItem] = [
                SDStepItem(kind: .phrase, titleRU: "привет", subtitleTH: "สวัสดี", phonetic: "sa-wat-dee"),
                SDStepItem(kind: .word,   titleRU: "спасибо", subtitleTH: "ขอบคุณ", phonetic: "khop-khun"),
                SDStepItem(kind: .tip,    titleRU: "лайфхак", subtitleTH: "Свяжи «кхоп-кхун» с благодарностью — говори после помощи.", phonetic: "khop-khun krab"),
                SDStepItem(kind: .phrase, titleRU: "где туалет?", subtitleTH: "ห้องน้ำอยู่ไหน", phonetic: "hong-nam yu nai"),
                SDStepItem(kind: .phrase, titleRU: "сколько стоит?", subtitleTH: "ราคาเท่าเร่าไหร่", phonetic: "ra-kha thao-rai")
            ]
            let courseNames = ["разговорный минимум", "алфавит и чтение", "выживание в тай", "фразы на каждый день"]
            let lessonNames = ["урок 1", "урок 5", "урок 2", "урок 7"]

            MDDailyPicksPreviewHost(demoItems: demoItems, courseNames: courseNames, lessonNames: lessonNames)
            }
            .padding(.vertical, 20)
        }
        .safeAreaPadding(.top, 16)
        .safeAreaPadding(.bottom, 24)
    }
}
