
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
                TaikaSectionHeaderRow(sectionCountdownTitle) {
                    if !items.isEmpty {
                        Text("\(activeIndex + 1)/\(items.count)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .monospacedDigit()
                    }
                }

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

                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Group {
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
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Открыть курс \(courseTitle)")
                            } else {
                                Color.clear.frame(height: 1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if showsLesson {
                            Button {
                                onTapLesson(activeIndex)
                            } label: {
                                Text(lessonTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                                    .truncationMode(.tail)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .trailing)
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
    public static let cardWidth: CGFloat = 184
    public static let cardHeight: CGFloat = 258
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
                    .foregroundStyle(PD.ColorToken.text.opacity(0.92))
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
        let neutralStroke = Color.white.opacity(0.24)
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
                                .fill(Color.white.opacity(0.55))
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
                        .foregroundStyle(PD.ColorToken.text.opacity(0.92))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule(style: .continuous)
                                .stroke(neutralStroke, lineWidth: 1.2)
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
    public var isCentered: Bool
    /// One pass through all lines, then stop (boot / splash).
    public var playOnce: Bool
    public var onSequenceFinished: (() -> Void)?

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
        digitSize: CGFloat = 26,
        isCentered: Bool = false,
        playOnce: Bool = false,
        onSequenceFinished: (() -> Void)? = nil
    ) {
        self.lines = lines.filter { !$0.isEmpty }
        self.font = font
        self.holdSeconds = holdSeconds
        self.charInterval = charInterval
        self.minHeight = minHeight
        self.accentDigits = accentDigits
        self.digitSize = digitSize
        self.isCentered = isCentered
        self.playOnce = playOnce
        self.onSequenceFinished = onSequenceFinished
    }

    private var currentLine: String {
        guard !lines.isEmpty else { return "" }
        return lines[lineIndex % lines.count]
    }

    public var body: some View {
        let visible = String(currentLine.prefix(visibleCount))
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            styledVisibleText(visible)
                .lineLimit(2)
                .multilineTextAlignment(isCentered ? .center : .leading)
                .minimumScaleFactor(0.82)
                .animation(nil, value: visibleCount)
            Text("▍")
                .font(font)
                .foregroundStyle(PD.ColorToken.text.opacity(0.72))
                .opacity(cursorOn ? 1 : 0.12)
        }
        .frame(minHeight: minHeight)
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
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
                if playOnce, lineIndex >= lines.count - 1 {
                    onSequenceFinished?()
                    return
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
public enum MDVoiceSphereSize {
    /// Onboarding / Main hero.
    case hero
    /// Compact Speaker «Скажи сам» — та же визуальная идентичность, меньше.
    case compact

    var ellipse: CGSize {
        switch self {
        case .hero: return CGSize(width: 280, height: 120)
        case .compact: return CGSize(width: 210, height: 90)
        }
    }

    var ringInner: CGFloat { self == .hero ? 148 : 112 }
    var ringOuter: CGFloat { self == .hero ? 172 : 130 }
    var glow: CGFloat { self == .hero ? 190 : 144 }
    var core: CGFloat { self == .hero ? 96 : 72 }
    var icon: CGFloat { self == .hero ? 34 : 26 }
    var height: CGFloat { self == .hero ? 200 : 168 }
    var glowEndRadius: CGFloat { self == .hero ? 90 : 68 }
    var ellipseEndRadius: CGFloat { self == .hero ? 150 : 110 }
    var shadowRadius: CGFloat { self == .hero ? 24 : 18 }
}

public struct MDVoiceSphere: View {
    public let symbol: String
    public let accessibilityLabel: String
    public let meter: Double
    public let size: MDVoiceSphereSize
    /// Idle pulse rings. Recording/processing can intensify via meter alone.
    public let pulseEnabled: Bool
    public let action: () -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseOut = false

    public init(
        symbol: String = "mic.fill",
        accessibilityLabel: String = "Открыть спикер и начать запись",
        meter: Double = 0,
        size: MDVoiceSphereSize = .hero,
        pulseEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.accessibilityLabel = accessibilityLabel
        self.meter = meter
        self.size = size
        self.pulseEnabled = pulseEnabled
        self.action = action
    }

    public var body: some View {
        let accent = theme.currentAccentFill
        let tint = theme.currentAccentTintColor
        let voiceLevel = reduceMotion ? 0 : min(max(meter, 0), 1)
        let listeningBoost = 1.0 + voiceLevel * 0.06

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
                            endRadius: size.ellipseEndRadius
                        )
                    )
                    .frame(width: size.ellipse.width, height: size.ellipse.height)
                    .blur(radius: 8)
                    .opacity(0.9)
                    .scaleEffect(listeningBoost)

                ZStack {
                    Circle()
                        .stroke(tint.opacity(pulseOut ? 0 : 0.55), lineWidth: size == .hero ? 1.4 : 1.2)
                        .frame(width: size.ringInner, height: size.ringInner)
                        .scaleEffect(pulseOut ? 1.28 : 1.0)

                    Circle()
                        .stroke(tint.opacity(pulseOut ? 0 : 0.28), lineWidth: 1)
                        .frame(width: size.ringOuter, height: size.ringOuter)
                        .scaleEffect(pulseOut ? 1.18 : 1.0)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [tint.opacity(0.55), tint.opacity(0.12), tint.opacity(0)],
                                center: .center,
                                startRadius: 2,
                                endRadius: size.glowEndRadius
                            )
                        )
                        .frame(width: size.glow, height: size.glow)
                        .scaleEffect(listeningBoost)

                    Circle()
                        .fill(accent)
                        .frame(width: size.core, height: size.core)
                        .shadow(
                            color: tint.opacity(0.65 + voiceLevel * 0.12),
                            radius: size.shadowRadius,
                            y: size == .hero ? 8 : 6
                        )
                        .scaleEffect(1.0 + voiceLevel * 0.04)

                    Image(systemName: symbol)
                        .font(.system(size: size.icon, weight: .bold))
                        .foregroundStyle(Color.black)
                        .contentTransition(.symbolEffect(.replace))
                }
                .animation(.easeOut(duration: 0.12), value: meter)
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            guard pulseEnabled, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.1).repeatForever(autoreverses: false)) {
                pulseOut = true
            }
        }
        .onChange(of: pulseEnabled) { _, enabled in
            if enabled, !reduceMotion {
                pulseOut = false
                withAnimation(.easeOut(duration: 2.1).repeatForever(autoreverses: false)) {
                    pulseOut = true
                }
            } else {
                pulseOut = false
            }
        }
    }
}

// MARK: - Taika Assistant Screen (единая композиция: гайд → сфера → чипы/CTA)

public enum TaikaAssistantLayout {
    /// Внутри скролла (Main).
    case embedded
    /// На весь экран (пустые состояния, Game Park).
    case fullscreen
}

public struct TaikaNeutralChipItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public var isSelected: Bool
    public var isEnabled: Bool
    public var trailingIcon: String?

    public init(
        id: String,
        title: String,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        trailingIcon: String? = nil
    ) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.trailingIcon = trailingIcon
    }
}

/// Нейтральный чип в стиле Main marquee — без розового акцента.
public struct TaikaNeutralChip: View {
    public var title: String
    public var isSelected: Bool
    public var isEnabled: Bool
    public var trailingIcon: String?
    public var action: () -> Void

    public init(
        title: String,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        trailingIcon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.trailingIcon = trailingIcon
        self.action = action
    }

    public var body: some View {
        Button {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundStyle(
                isEnabled
                ? (isSelected ? PD.ColorToken.text : PD.ColorToken.textSecondary.opacity(0.88))
                : PD.ColorToken.textSecondary.opacity(0.38)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isSelected && isEnabled
                        ? Color.white.opacity(0.10)
                        : Color.white.opacity(0.05)
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isSelected && isEnabled
                        ? Color.white.opacity(0.22)
                        : Theme.Strokes.strokeSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Горизонтальный ряд нейтральных чипов по центру.
public struct TaikaNeutralChipRow: View {
    public var items: [TaikaNeutralChipItem]
    public var onSelect: (String) -> Void

    public init(items: [TaikaNeutralChipItem], onSelect: @escaping (String) -> Void) {
        self.items = items
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        TaikaNeutralChip(
                            title: item.title,
                            isSelected: item.isSelected,
                            isEnabled: item.isEnabled,
                            trailingIcon: item.trailingIcon
                        ) {
                            onSelect(item.id)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .frame(minWidth: geo.size.width, alignment: .center)
            }
        }
        .frame(height: 34)
        .frame(maxWidth: .infinity)
    }
}

/// Главная pill-CTA внизу hub-экранов.
public struct TaikaAssistantHubPrimaryCTA {
    public var title: String
    public var icon: String
    public var isEnabled: Bool
    public var accent: Color?
    public var action: () -> Void

    public init(
        title: String,
        icon: String = "graduationcap.fill",
        isEnabled: Bool = true,
        accent: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.accent = accent
        self.action = action
    }
}

/// Вторичная ghost-команда под pill (как «Разминка» на Main).
public struct TaikaAssistantHubGhostCTA {
    public var icon: String
    public var title: String
    public var accent: Color?
    public var action: () -> Void

    public init(icon: String, title: String, accent: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.accent = accent
        self.action = action
    }
}

/// Единый регистр и копирайт hub-кнопок — как «Разминка» / «Продолжить» на Main.
public enum TaikaHubButtonCopy {
    public static func display(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return trimmed }
        return first.uppercased() + trimmed.dropFirst()
    }
}

public enum TaikaAssistantHubLayout {
    /// Main: hero по центру, dock прибит к низу.
    case mainEmbedded
    /// Таб / drawer: на всю высоту.
    case tabFullscreen
}

/// Единый hub: сфера → typewriter → чипы → pill (каскад после assemble).
public struct TaikaAssistantHub<ChipZone: View>: View {
    public var lines: [String]
    public var assembleGateKey: String?
    public var layout: TaikaAssistantHubLayout
    public var primaryCTA: TaikaAssistantHubPrimaryCTA?
    public var ghostCTA: TaikaAssistantHubGhostCTA?
    public var showsGhostSlot: Bool
    public var bottomInset: CGFloat
    @ViewBuilder public var hero: () -> AnyView
    @ViewBuilder public var chipZone: () -> ChipZone
    @ViewBuilder public var ghostSlot: () -> AnyView

    @StateObject private var assembleCoordinator = TaikaAssembleCoordinator()
    @State private var showDock = false
    @State private var cascadeTask: Task<Void, Never>?

    public init(
        lines: [String],
        assembleGateKey: String? = nil,
        layout: TaikaAssistantHubLayout = .tabFullscreen,
        primaryCTA: TaikaAssistantHubPrimaryCTA? = nil,
        ghostCTA: TaikaAssistantHubGhostCTA? = nil,
        showsGhostSlot: Bool = false,
        bottomInset: CGFloat = Theme.Layout.bottomToolbarHeight + 12,
        @ViewBuilder hero: @escaping () -> some View,
        @ViewBuilder chipZone: @escaping () -> ChipZone,
        @ViewBuilder ghostSlot: @escaping () -> some View = { EmptyView() }
    ) {
        self.lines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.assembleGateKey = assembleGateKey
        self.layout = layout
        self.primaryCTA = primaryCTA
        self.ghostCTA = ghostCTA
        self.showsGhostSlot = showsGhostSlot
        self.bottomInset = bottomInset
        self.hero = { AnyView(hero()) }
        self.chipZone = chipZone
        self.ghostSlot = { AnyView(ghostSlot()) }
        // Без gate — сразу UI; с gate — ждём сборку сферы, кроме холодного старта после сплэша.
        _showDock = State(initialValue: assembleGateKey == nil || TaikaCatalogBoot.isReady)
    }

    private var screenLayout: TaikaAssistantLayout { .embedded }

    private var topBreathing: CGFloat {
        layout == .mainEmbedded ? 0 : 0
    }

    private var showsDock: Bool {
        primaryCTA != nil || ghostCTA != nil || showsGhostSlot
    }

    private var dockContentId: String {
        let accentKey: String = {
            guard let c = primaryCTA?.accent else { return "n" }
            // Stable-enough fingerprint so mode tint swaps animate even if title stays.
            return String(format: "%.2f", c.cgColor?.components?.first ?? 0)
        }()
        return [
            primaryCTA?.title ?? "",
            primaryCTA?.icon ?? "",
            ghostCTA?.title ?? "",
            ghostCTA?.icon ?? "",
            accentKey
        ].joined(separator: "|")
    }

    public var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer(minLength: topBreathing)

                TaikaAssistantScreen(
                    lines: lines,
                    layout: screenLayout,
                    assembleGateKey: assembleGateKey
                ) {
                    hero()
                } footer: {
                    chipZone()
                }
                .environmentObject(assembleCoordinator)

                Spacer(minLength: 16)

                if showsDock {
                    VStack(spacing: 0) {
                        if let primaryCTA {
                            TaikaHubAgentSwitchCTA(
                                title: primaryCTA.title,
                                icon: primaryCTA.icon,
                                isEnabled: primaryCTA.isEnabled,
                                accent: primaryCTA.accent,
                                action: primaryCTA.action
                            )
                        }
                        if let ghostCTA {
                            TaikaHubGhostCTA(
                                icon: ghostCTA.icon,
                                title: ghostCTA.title,
                                accent: ghostCTA.accent,
                                action: ghostCTA.action
                            )
                        }
                        if showsGhostSlot {
                            ghostSlot()
                        }
                    }
                    .id(dockContentId)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 1.02))
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Layout.pageHorizontal)
                    .opacity(showDock ? 1 : 0)
                    .offset(y: showDock ? 0 : 10)
                    .allowsHitTesting(showDock)
                    .animation(.easeOut(duration: 0.34), value: showDock)
                    .animation(.spring(response: 0.38, dampingFraction: 0.86), value: dockContentId)
                }
            }
            .padding(.bottom, bottomInset)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .onAppear {
            if assembleGateKey == nil || TaikaCatalogBoot.isReady {
                assembleCoordinator.skipToComplete()
                showDock = true
            } else if !assembleCoordinator.isComplete {
                showDock = false
            }
        }
        .onChange(of: assembleCoordinator.isComplete) { _, done in
            if !done { showDock = false }
        }
        .onChange(of: assembleCoordinator.revealGeneration) { _, _ in
            syncDockReveal(complete: assembleCoordinator.isComplete)
        }
        .onChange(of: assembleCoordinator.shouldCascadeUI) { _, cascading in
            if cascading, !assembleCoordinator.isComplete {
                showDock = false
            }
        }
        .onDisappear {
            cascadeTask?.cancel()
            cascadeTask = nil
        }
    }

    private func syncDockReveal(complete: Bool) {
        cascadeTask?.cancel()
        guard complete else {
            showDock = false
            return
        }
        guard assembleCoordinator.shouldCascadeUI else {
            showDock = true
            return
        }
        // typewriter ~100ms, chips ~280ms, dock ~420ms после complete
        cascadeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.34)) {
                showDock = true
            }
        }
    }
}

/// Лёгкий primary в стиле AI-агента: текст + иконка, без серой «таблетки».
public struct TaikaHubAgentSwitchCTA: View {
    public var title: String
    public var icon: String
    public var isEnabled: Bool
    public var accent: Color?
    public var action: () -> Void

    public init(
        title: String,
        icon: String = "graduationcap.fill",
        isEnabled: Bool = true,
        accent: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconStyle)
                    .contentTransition(.symbolEffect(.replace))

                Text(TaikaHubButtonCopy.display(title))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle(scale: 0.985, fade: 0.9))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(TaikaHubButtonCopy.display(title))
    }

    /// Brand gradient (header kAAA family) — never a flat red solid.
    private var iconStyle: AnyShapeStyle {
        if let accent {
            return AnyShapeStyle(accent.opacity(0.92))
        }
        return AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }
}

/// Ghost-команда под primary — лёгкая системная строка (без «прогресс-бара»).
public struct TaikaHubGhostCTA: View {
    public var icon: String
    public var title: String
    public var accent: Color?
    public var action: () -> Void

    public init(icon: String, title: String, accent: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconStyle)
                    .contentTransition(.symbolEffect(.replace))
                Text(TaikaHubButtonCopy.display(title))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PD.ColorToken.text.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PressDownStyle(scale: 0.985, fade: 0.88))
    }

    private var iconStyle: AnyShapeStyle {
        if let accent {
            return AnyShapeStyle(accent.opacity(0.85))
        }
        return AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }
}

/// Общая разметка ghost-строки (кнопка или меню).
public struct TaikaHubGhostCTALabel: View {
    public var icon: String
    public var title: String
    public var showsChevron: Bool

    public init(icon: String, title: String, showsChevron: Bool = false) {
        self.icon = icon
        self.title = title
        self.showsChevron = showsChevron
    }

    public var body: some View {
        ZStack {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Text(TaikaHubButtonCopy.display(title))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PD.ColorToken.text.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if showsChevron {
                HStack {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.55))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
    }
}

/// Ghost-меню под pill — выбор колоды / курса (как «Разминка», но с picker).
public struct TaikaHubGhostMenu: View {
    public var icon: String
    public var title: String
    public var options: [TaikaHubGhostMenuOption]
    public var onSelect: (String) -> Void

    public init(
        icon: String,
        title: String,
        options: [TaikaHubGhostMenuOption],
        onSelect: @escaping (String) -> Void
    ) {
        self.icon = icon
        self.title = title
        self.options = options
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    guard option.isEnabled else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(option.id)
                } label: {
                    if option.isSelected {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
                .disabled(!option.isEnabled)
            }
        } label: {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay {
                    TaikaHubGhostCTALabel(icon: icon, title: title, showsChevron: true)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .frame(maxWidth: .infinity)
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.88))
    }
}

public struct TaikaHubGhostMenuOption: Identifiable {
    public let id: String
    public let title: String
    public var isSelected: Bool
    public var isEnabled: Bool

    public init(id: String, title: String, isSelected: Bool = false, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
        self.isEnabled = isEnabled
    }
}

/// Элемент бесконечной карусели нейтральных чипов.
public struct TaikaMarqueeChipItem: Identifiable {
    public let id: String
    public let title: String
    public var trailingIcon: String?

    public init(id: String, title: String, trailingIcon: String? = nil) {
        self.id = id
        self.title = title
        self.trailingIcon = trailingIcon
    }
}

/// Бесконечная карусель нейтральных чипов (фразы, курсы и т.д.).
public struct TaikaNeutralChipMarquee: View {
    public var items: [TaikaMarqueeChipItem]
    public var onSelect: (String) -> Void
    public var accessibilityLabel: String

    @State private var rowWidth: CGFloat = 0

    public init(
        items: [TaikaMarqueeChipItem],
        accessibilityLabel: String,
        onSelect: @escaping (String) -> Void
    ) {
        self.items = items
        self.accessibilityLabel = accessibilityLabel
        self.onSelect = onSelect
    }

    public var body: some View {
        Group {
            if items.isEmpty {
                Color.clear.frame(height: 34)
            } else {
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
                                chipRow
                                    .background(
                                        GeometryReader { g in
                                            Color.clear.preference(key: MDMarqueeWidthKey.self, value: g.size.width)
                                        }
                                    )
                                chipRow
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
                    .accessibilityLabel(accessibilityLabel)
            }
        }
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                TaikaNeutralChip(
                    title: item.title,
                    trailingIcon: item.trailingIcon
                ) {
                    onSelect(item.id)
                }
            }
        }
        .padding(.trailing, 8)
    }
}

/// Курс для карусели на пустых hub-экранах.
public struct TaikaCourseMarqueeItem: Identifiable, Equatable {
    public let courseId: String
    public let title: String
    public var isPro: Bool

    public var id: String { courseId }

    public init(courseId: String, title: String, isPro: Bool = false) {
        self.courseId = courseId
        self.title = title
        self.isPro = isPro
    }
}

/// Карусель курсов для пустых экранов избранного / словаря.
public struct TaikaCourseMarquee: View {
    public var courses: [TaikaCourseMarqueeItem]
    public var onSelectCourse: (String) -> Void

    public init(
        courses: [TaikaCourseMarqueeItem],
        onSelectCourse: @escaping (String) -> Void
    ) {
        self.courses = courses
        self.onSelectCourse = onSelectCourse
    }

    private var items: [TaikaMarqueeChipItem] {
        courses.map {
            TaikaMarqueeChipItem(
                id: $0.courseId,
                title: $0.title,
                trailingIcon: $0.isPro ? "crown.fill" : nil
            )
        }
    }

    public var body: some View {
        TaikaNeutralChipMarquee(
            items: items,
            accessibilityLabel: "Курсы для начала обучения",
            onSelect: onSelectCourse
        )
    }
}

/// Единый каркас assistant-экранов: сфера → typewriter → footer (чипы).
public struct TaikaAssistantScreen<Footer: View>: View {
    public var lines: [String]
    public var layout: TaikaAssistantLayout
    public var assembleGateKey: String?
    @ViewBuilder public var hero: () -> AnyView
    @ViewBuilder public var footer: () -> Footer

    @EnvironmentObject private var assembleCoordinator: TaikaAssembleCoordinator
    @State private var showTypewriter = false
    @State private var showFooter = false
    @State private var cascadeTask: Task<Void, Never>?

    public init(
        lines: [String],
        layout: TaikaAssistantLayout = .fullscreen,
        assembleGateKey: String? = nil,
        @ViewBuilder hero: @escaping () -> some View,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.lines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.layout = layout
        self.assembleGateKey = assembleGateKey
        self.hero = { AnyView(hero()) }
        self.footer = footer
        let instant = assembleGateKey == nil || TaikaCatalogBoot.isReady
        _showTypewriter = State(initialValue: instant)
        _showFooter = State(initialValue: instant)
    }

    public var body: some View {
        VStack(spacing: 18) {
            if layout == .fullscreen { Spacer(minLength: 0) }

            if !lines.isEmpty {
                ZStack {
                    Color.clear.frame(minHeight: 62)
                    if showTypewriter {
                        MDCyclingTypewriter(
                            lines: lines,
                            font: .system(size: 22, weight: .bold),
                            holdSeconds: 2.6,
                            minHeight: 62,
                            isCentered: true
                        )
                        .transition(
                            .opacity.combined(with: .offset(y: 10))
                        )
                    }
                }
                .animation(.easeOut(duration: 0.32), value: showTypewriter)
            }

            hero()

            footer()
                .opacity(showFooter ? 1 : 0)
                .offset(y: showFooter ? 0 : 8)
                .allowsHitTesting(showFooter)
                .animation(.easeOut(duration: 0.34), value: showFooter)

            if layout == .fullscreen { Spacer(minLength: 0) }
        }
        .padding(.horizontal, Theme.Layout.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: layout == .fullscreen ? .infinity : nil)
        .onAppear {
            if assembleGateKey == nil || TaikaCatalogBoot.isReady {
                assembleCoordinator.skipToComplete()
                showTypewriter = true
                showFooter = true
            } else if !assembleCoordinator.isComplete {
                showTypewriter = false
                showFooter = false
            }
        }
        .onChange(of: assembleCoordinator.isComplete) { _, done in
            if !done {
                showTypewriter = false
                showFooter = false
            }
        }
        .onChange(of: assembleCoordinator.revealGeneration) { _, _ in
            syncChromeReveal(complete: assembleCoordinator.isComplete)
        }
        .onChange(of: assembleCoordinator.shouldCascadeUI) { _, cascading in
            if cascading, !assembleCoordinator.isComplete {
                showTypewriter = false
                showFooter = false
            }
        }
        .onDisappear {
            cascadeTask?.cancel()
            cascadeTask = nil
        }
    }

    private func syncChromeReveal(complete: Bool) {
        cascadeTask?.cancel()
        guard complete else {
            showTypewriter = false
            showFooter = false
            return
        }
        guard assembleCoordinator.shouldCascadeUI else {
            showTypewriter = true
            showFooter = true
            return
        }
        // Сфера уже собрана → пауза → текст → чипы.
        cascadeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.32)) {
                showTypewriter = true
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.34)) {
                showFooter = true
            }
        }
    }
}

/// Пустой экран: сфера + карусель курсов + pill внизу.
public struct TaikaAssistantEmptyHero: View {
    public var systemImage: String
    public var lines: [String]
    public var assembleGateKey: String?
    public var primaryCTA: TaikaAssistantHubPrimaryCTA
    public var courses: [TaikaCourseMarqueeItem]
    public var onSelectCourse: (String) -> Void
    public var bottomInset: CGFloat

    @ObservedObject private var main = MainManager.shared

    public init(
        systemImage: String,
        lines: [String],
        assembleGateKey: String? = nil,
        primaryCTA: TaikaAssistantHubPrimaryCTA,
        courses: [TaikaCourseMarqueeItem] = [],
        bottomInset: CGFloat = Theme.Layout.bottomToolbarHeight + 12,
        onSelectCourse: @escaping (String) -> Void
    ) {
        self.systemImage = systemImage
        self.lines = lines
        self.assembleGateKey = assembleGateKey
        self.primaryCTA = primaryCTA
        self.courses = courses
        self.bottomInset = bottomInset
        self.onSelectCourse = onSelectCourse
    }

    private var marqueeCourses: [TaikaCourseMarqueeItem] {
        if !courses.isEmpty { return courses }
        return main.dailyCourseCards.map {
            TaikaCourseMarqueeItem(courseId: $0.courseId, title: $0.title, isPro: $0.isPro)
        }
    }

    public var body: some View {
        let gate = assembleGateKey ?? "empty.\(systemImage)"
        TaikaAssistantHub(
            lines: lines,
            assembleGateKey: gate,
            layout: .mainEmbedded,
            primaryCTA: primaryCTA,
            bottomInset: bottomInset
        ) {
            TaikaEmptyPlanet(systemImage: systemImage, gateKey: gate)
        } chipZone: {
            TaikaCourseMarquee(courses: marqueeCourses, onSelectCourse: onSelectCourse)
        }
        .task {
            if main.dailyCourseCards.isEmpty {
                await main.reloadDailyCoursePicks()
            }
        }
    }
}

/// Главный вход в Спикер: сфера + marquee фраз.
public struct MDPromptHero: View {
    public var lines: [String]
    public var leadPhrases: [String]
    public var onOpenSpeaker: () -> Void
    public var onTapPhrase: (String) -> Void

    public init(
        lines: [String],
        leadPhrases: [String] = [],
        onOpenSpeaker: @escaping () -> Void,
        onTapPhrase: @escaping (String) -> Void
    ) {
        self.lines = lines
        self.leadPhrases = leadPhrases
        self.onOpenSpeaker = onOpenSpeaker
        self.onTapPhrase = onTapPhrase
    }

    public var body: some View {
        TaikaAssistantHub(
            lines: lines,
            assembleGateKey: "tab.main.hero",
            layout: .mainEmbedded,
            primaryCTA: nil,
            ghostCTA: nil
        ) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onOpenSpeaker()
            } label: {
                TaikaAssemblingPlanet(
                    gateKey: "tab.main.hero",
                    kind: .voice,
                    scale: 0.62,
                    inviteTap: true,
                    frameSize: 188
                )
                .clipped()
            }
            .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.98))
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Скажи по-русски")
            .accessibilityHint("Открыть умный спикер")
        } chipZone: {
            MDExamplePhraseMarquee(leadPhrases: leadPhrases) { phrase in
                onTapPhrase(phrase)
            }
        }
    }
}

/// Бесконечная карусель чипов с примерами фраз — лёгкий marquee без паузы.
public struct MDExamplePhraseMarquee: View {
    public var leadPhrases: [String]
    public var onTapPhrase: (String) -> Void

    private static let stockPhrases: [String] = [
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

    public init(leadPhrases: [String] = [], onTapPhrase: @escaping (String) -> Void) {
        self.leadPhrases = leadPhrases
        self.onTapPhrase = onTapPhrase
    }

    private var phrases: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in leadPhrases + Self.stockPhrases {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, seen.insert(t).inserted else { continue }
            out.append(t)
        }
        return out
    }

    public var body: some View {
        TaikaNeutralChipMarquee(
            items: phrases.map { TaikaMarqueeChipItem(id: $0, title: $0) },
            accessibilityLabel: "Примеры фраз для спикера",
            onSelect: onTapPhrase
        )
    }
}

private struct MDMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Main pill CTAs (как «Начать тренировку» в Спикере)

/// Нейтральный chrome для главных pill-кнопок — заметный тап без бренд-розового.
public struct TaikaNeutralPrimaryPillChrome: View {
    public var cornerRadius: CGFloat?

    public init(cornerRadius: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape: RoundedRectangle = {
            if let cornerRadius {
                return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            }
            return RoundedRectangle(cornerRadius: 999, style: .continuous)
        }()

        shape
            .fill(Color.white.opacity(0.10))
            .overlay(
                shape
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
            )
            .overlay(
                shape.stroke(Color.white.opacity(0.24), lineWidth: 1.2)
            )
    }
}

/// Залитая pill-CTA hub-экранов: «Продолжить», «начать закрепление», «к урокам».
public struct MDMainFilledPillCTA: View {
    public var title: String
    public var icon: String
    public var isEnabled: Bool
    public var action: () -> Void

    public init(
        title: String,
        icon: String = "graduationcap.fill",
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(TaikaHubButtonCopy.display(title))
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(PD.ColorToken.text)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .background(TaikaNeutralPrimaryPillChrome())
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
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

/// Secondary funnel chip — half-width, so «Продолжить» stays the only full-width CTA.
private struct MDSecondaryFunnelChip: View {
    let icon: String
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        // Команды агента одного веса: ни одна не красится акцентом.
        // Акцент остаётся у сферы и цифр в тексте кун кру.
        let label: AnyShapeStyle = isEnabled
            ? AnyShapeStyle(PD.ColorToken.text)
            : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.42))
        let glyph: AnyShapeStyle = isEnabled
            ? AnyShapeStyle(PD.ColorToken.textSecondary)
            : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.35))

        Button {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(glyph)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(label)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.08 : 0.03))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: isEnabled ? 1 : 0)
            )
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
        .disabled(!isEnabled)
    }
}

/// Продолжить / начать — главный путь в обучение.
public struct MDMainContinuePillCTA: View {
    public var title: String
    public var accessibilityTitle: String
    public var action: () -> Void

    public init(
        title: String,
        accessibilityTitle: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.accessibilityTitle = accessibilityTitle
        self.action = action
    }

    public var body: some View {
        MDSecondaryFunnelChip(icon: "graduationcap.fill", title: title, action: action)
            .accessibilityLabel(accessibilityTitle)
            .accessibilityHint("Открыть текущий курс")
    }
}

/// Текстовая команда под главным CTA: системный цвет, без чипа и без акцента.
private struct MDMainGhostCommand: View {
    let icon: String
    let title: String
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PD.ColorToken.text.opacity(0.92))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.34)
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.88))
        .disabled(!isEnabled)
    }
}

/// Daily warmup entry point — compact chip; the value copy lives inside the overlay it opens.
public struct MDDailyWarmupPillCTA: View {
    public let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        MDMainGhostCommand(icon: "bolt.fill", title: "Разминка", action: action)
            .accessibilityLabel("Разминка, ежедневная подборка фраз")
            .accessibilityHint("Открыть бесплатную практику на сегодня")
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
#if DEBUG
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
#endif

