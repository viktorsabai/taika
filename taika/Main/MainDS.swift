
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
        let cal = MDBangkokCalendar.cal
        let dayStart = cal.startOfDay(for: now)
        guard let nextMidnight = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            return "обновление завтра"
        }
        let remaining = max(0, Int(nextMidnight.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        if hours > 0 {
            return "через \(hours) ч \(minutes) мин"
        }
        if minutes > 0 {
            return "через \(minutes) мин"
        }
        return "скоро"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
            VStack(alignment: .leading, spacing: 8) {
                TaikaSectionHeaderRow(title) {
                    Text(refreshCountdownLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PD.ColorToken.text)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(ThemeManager.shared.currentAccentTintColor.opacity(0.28))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    ThemeManager.shared.currentAccentFill.opacity(0.55),
                                    lineWidth: Theme.Strokes.strokeLineWidth
                                )
                        )
                        .accessibilityLabel("Обновление подборки \(refreshCountdownLabel)")
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

                    VStack(alignment: .leading, spacing: 5) {
                        if isProActive {
                            Text("Taika+ · подборка дня")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                .lineLimit(1)
                        } else if !courseTitle.isEmpty {
                            Button {
                                onOpenCourse(activeIndex)
                            } label: {
                                Text(courseTitle)
                                    .font(.system(size: 13, weight: .semibold))
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
        waveSeed: Int = 0
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
            waveSeed: 0
        )
    }
}

/// Абстрактная «mesh»-волна справа: тонкие линии + accent, без фото и без перегруза.
private struct MDTechWaveMesh: View {
    var seed: Int
    var intensity: Double = 1
    var phase: Double = 0

    var body: some View {
        let tint = ThemeManager.shared.currentAccentTintColor
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let phaseBase = Double(seed % 7) * 0.37 + phase
            let lineCount = 9

            for i in 0..<lineCount {
                let t = Double(i) / Double(max(lineCount - 1, 1))
                var path = Path()
                let amp = (10.0 + t * 18.0) * intensity
                let y0 = h * (0.18 + t * 0.62)
                let freq = 1.6 + t * 0.9 + phaseBase * 0.15
                let step: CGFloat = 3
                var x: CGFloat = 0
                while x <= w {
                    let xn = Double(x / w)
                    let y = y0
                        + sin((xn * freq + phaseBase + t * 0.55) * .pi * 2) * amp
                        + cos((xn * (freq * 0.55) + t) * .pi * 2) * (amp * 0.28)
                    let pt = CGPoint(x: x, y: y)
                    if x == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    x += step
                }

                let alpha = (0.10 + (1 - t) * 0.22) * intensity
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            tint.opacity(0.02),
                            tint.opacity(alpha),
                            tint.opacity(alpha * 0.55),
                            tint.opacity(0.02)
                        ]),
                        startPoint: .init(x: 0, y: y0),
                        endPoint: .init(x: w, y: y0)
                    ),
                    lineWidth: i % 3 == 0 ? 1.35 : 0.75
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Баннер «продолжить»: eyebrow → title → detail → motivation chip → stats + CTA.
public struct MDTechResumeBannerCard: View {
    public let model: MDTechResumeBannerModel
    public let onContinue: () -> Void

    public init(model: MDTechResumeBannerModel, onContinue: @escaping () -> Void) {
        self.model = model
        self.onContinue = onContinue
    }

    private let corner: CGFloat = 28
    static let cardHeight: CGFloat = 228

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        let tint = ThemeManager.shared.currentAccentTintColor
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        Button(action: onContinue) {
            ZStack(alignment: .bottomTrailing) {
                Theme.Surfaces.card(shape)
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.045),
                                Color.clear,
                                tint.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate * 0.12
                    MDTechWaveMesh(
                        seed: model.waveSeed,
                        intensity: model.isEmpty ? 0.5 : 1,
                        phase: phase
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.22), .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.leading, 64)
                    .opacity(0.95)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(model.eyebrow)
                        .font(.system(size: 12, weight: .bold))
                        .kerning(0.9)
                        .foregroundStyle(accent)
                        .textCase(.uppercase)
                        .padding(.trailing, model.motivationChip == nil ? 0 : 88)

                    Text(model.title)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .padding(.top, 10)
                        .padding(.trailing, model.motivationChip == nil ? 0 : 72)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = model.detailLine, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.92))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .padding(.top, 6)
                            .padding(.trailing, 36)
                    }

                    Spacer(minLength: 12)

                    HStack(alignment: .center, spacing: 10) {
                        if let stats = model.statsLine, !stats.isEmpty {
                            Text(stats)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.95))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(PD.ColorToken.chip)
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                                )
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 5) {
                            Text(model.ctaTitle)
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Color.black.opacity(0.88))
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule(style: .continuous).fill(accent))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if let chip = model.motivationChip, !chip.isEmpty {
                    AppStatusChip(kind: model.motivationKind, scale: .s, title: chip.lowercased())
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.cardHeight, maxHeight: Self.cardHeight)
            .clipShape(shape)
            .contentShape(shape)
            .shadow(color: tint.opacity(0.14), radius: 16, y: 8)
        }
        .buttonStyle(PressDownStyle(scale: 0.978, fade: 0.97))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.eyebrow). \(model.title). \(model.ctaTitle)")
    }
}

/// Автокарусель tech-баннеров: свайп вручную + автолистание, пауза при взаимодействии.
public struct MDTechResumeBannerCarousel: View {
    public let models: [MDTechResumeBannerModel]
    public let onSelect: (MDTechResumeBannerModel) -> Void

    @State private var page: Int = 0
    @State private var isUserInteracting = false
    @State private var resumeAutoAt: Date = .distantPast

    private let timer = Timer.publish(every: 4.6, on: .main, in: .common).autoconnect()

    public init(
        models: [MDTechResumeBannerModel],
        onSelect: @escaping (MDTechResumeBannerModel) -> Void
    ) {
        self.models = models
        self.onSelect = onSelect
    }

    public var body: some View {
        let safeModels = models.isEmpty ? [MDTechResumeBannerModel.emptyState()] : models
        let clampedPage = min(max(0, page), max(0, safeModels.count - 1))

        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(safeModels.enumerated()), id: \.element.id) { idx, model in
                    MDTechResumeBannerCard(model: model) {
                        onSelect(model)
                    }
                    .padding(.horizontal, PD.Spacing.screen)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: MDTechResumeBannerCard.cardHeight)
            .animation(.easeInOut(duration: 0.42), value: page)

            MDCarouselPageDots(count: safeModels.count, activeIndex: Binding(
                get: { clampedPage },
                set: { newValue in
                    page = newValue
                    pauseAutoBriefly()
                }
            ))
            .padding(.top, 8)
        }
        .onAppear {
            if page >= safeModels.count { page = 0 }
        }
        .onChange(of: safeModels.map(\.id)) { _, _ in
            if page >= safeModels.count { page = 0 }
        }
        .onReceive(timer) { _ in
            guard safeModels.count > 1 else { return }
            guard !isUserInteracting, Date() >= resumeAutoAt else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                page = (page + 1) % safeModels.count
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { _ in
                    isUserInteracting = true
                    pauseAutoBriefly()
                }
                .onEnded { _ in
                    isUserInteracting = false
                    pauseAutoBriefly()
                }
        )
    }

    private func pauseAutoBriefly() {
        resumeAutoAt = Date().addingTimeInterval(6.5)
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

/// Карточка «Продолжить» на Main: курс, кольцо прогресса, мини-календарь, CTA.
public struct MDContinueHeroCard: View {
    public let model: MDContinueHeroModel
    public let weekItems: [WeeklyResumeItem]
    public let onContinue: () -> Void
    public let onTapDay: (WeeklyResumeItem) -> Void

    public init(
        model: MDContinueHeroModel,
        weekItems: [WeeklyResumeItem],
        onContinue: @escaping () -> Void,
        onTapDay: @escaping (WeeklyResumeItem) -> Void
    ) {
        self.model = model
        self.weekItems = weekItems
        self.onContinue = onContinue
        self.onTapDay = onTapDay
    }

    private let cardCorner: CGFloat = Theme.Radii.card

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        let shape = RoundedRectangle(cornerRadius: cardCorner, style: .continuous)

        VStack(spacing: 0) {
            Button(action: onContinue) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.courseTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.text)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        if let meta = model.metaLine, !meta.isEmpty {
                            Text(meta)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                                .lineLimit(1)
                        }

                        if let focus = model.focusLessonTitle, !focus.isEmpty {
                            Text(focus)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accent)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                        }

                        if let mins = model.durationMinutes, mins > 0 {
                            HStack(spacing: 5) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("≈ \(mins) \(minutesLabel(mins))")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.88))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    progressRing
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 14)

            HStack(alignment: .center, spacing: 10) {
                weekDotsRow
                Spacer(minLength: 4)
                Button(action: onContinue) {
                    HStack(spacing: 4) {
                        Text(model.isEmpty ? "Начать" : "Продолжить")
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(accent, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Theme.Surfaces.card(shape))
        .overlay(shape.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var progressRing: some View {
        let pct = max(0, min(100, Int((model.progress * 100).rounded())))
        let accent = ThemeManager.shared.currentAccentFill
        return ZStack {
            AppDonut(value: CGFloat(model.progress), size: 54, lineWidth: 5)
                .shadow(color: Color.pink.opacity(model.progress > 0.02 ? 0.28 : 0), radius: 8)
            Text("\(pct)%")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
                .monospacedDigit()
        }
        .frame(width: 58, height: 58)
        .accessibilityLabel("Прогресс курса \(pct) процентов")
    }

    private var weekDotsRow: some View {
        HStack(spacing: 9) {
            ForEach(weekItems) { item in
                weekDotButton(item)
            }
        }
    }

    private func weekDotButton(_ item: WeeklyResumeItem) -> some View {
        let cal = MDBangkokCalendar.cal
        let dayNum = cal.component(.day, from: item.date)
        let hasActivity = dayHasActivity(item)
        let accent = ThemeManager.shared.currentAccentFill

        return Button {
            onTapDay(item)
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if item.isToday {
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                            .frame(width: 14, height: 14)
                    }
                    Circle()
                        .fill(dotFill(hasActivity: hasActivity, isToday: item.isToday, accent: AnyShapeStyle(accent)))
                        .frame(width: item.isToday ? 8 : 7, height: item.isToday ? 8 : 7)
                }
                .frame(width: 16, height: 16)

                Text("\(dayNum)")
                    .font(.system(size: 10, weight: item.isToday ? .bold : .medium))
                    .foregroundStyle(dayNumberColor(isToday: item.isToday, hasActivity: hasActivity, accent: accent))
                    .monospacedDigit()
            }
            .frame(minWidth: 22)
        }
        .buttonStyle(.plain)
    }

    private func dayHasActivity(_ item: WeeklyResumeItem) -> Bool {
        if (item.progress ?? 0) > 0.0001 { return true }
        if (item.learnedCount ?? 0) > 0 { return true }
        if (item.favCount ?? 0) > 0 { return true }
        if (item.audioMinutes ?? 0) > 0 { return true }
        return false
    }

    private func dayNumberColor(isToday: Bool, hasActivity: Bool, accent: LinearGradient) -> AnyShapeStyle {
        if isToday { return AnyShapeStyle(accent) }
        if hasActivity { return AnyShapeStyle(PD.ColorToken.text.opacity(0.9)) }
        return AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.55))
    }

    private func dotFill(hasActivity: Bool, isToday: Bool, accent: AnyShapeStyle) -> AnyShapeStyle {
        if hasActivity || isToday {
            return accent
        }
        return AnyShapeStyle(Color.white.opacity(0.14))
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
