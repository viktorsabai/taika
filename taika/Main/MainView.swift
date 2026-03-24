
import SwiftUI
import UIKit

@MainActor
final class _Ignore_Compile_Helper: ObservableObject {}

struct MainView: View {

    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent
    @ObservedObject private var main = MainManager.shared
    @ObservedObject private var pro = ProManager.shared
    @ObservedObject private var session = UserSession.shared
    @ObservedObject private var progress = ProgressManager.shared
    @State private var dailyIndex: Int = 1
    @State private var doneHaptic = UINotificationFeedbackGenerator()
    @State private var learnedIds: Set<String> = []
    @State private var favoriteIds: Set<String> = []
    @State private var lessonsTick: Int = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var navPushInFlight: Bool = false

    // MARK: - Search (OverlayPresenter contract)
    @State private var didConfigureSearchIndex: Bool = false
    @State private var searchCourseById: [String: CourseBundle] = [:]
    @State private var searchLessonHitById: [String: SearchLessonHit] = [:]
    @FocusState private var isSearchFocused: Bool
    @State private var mainSearchStub: String = ""

    private enum CalendarSheet: Equatable {
        case add(Date)
        case summary(Date)

        var day: Date {
            switch self {
            case .add(let d): return d
            case .summary(let d): return d
            }
        }
        var isAdd: Bool {
            if case .add = self { return true }
            return false
        }
    }

    @State private var calendarDayCourses: [MainManager.CourseCardModel] = []
    @State private var calendarSummaryPlannedOnly: Bool = false
    @State private var refreshWork: DispatchWorkItem? = nil
    @State private var addOverlayShuffleToken: Int = 0
    @State private var addOverlayReloadToken: Int = 0
    /// В оверлее «добавить курс»: выбранный день (полоска 7 дней); синхронизируется с sheet.day при появлении.
    @State private var calendarOverlaySelectedDay: Date = Date()
    @State private var kunKruCourses: [MainManager.CourseCardModel] = []
    /// Умная подборка курсов: показывается в секции «ДЛЯ ТЕБЯ» после тапа «Подборка для тебя».
    @State private var forYouCourses: [MainManager.CourseCardModel] = []

    // MARK: - Thailand canonical calendar (match MainManager)
    private static let bangkokTZ: TimeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
    private static var bangkokCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = bangkokTZ
        return cal
    }()

    // MARK: - Extracted blocks to help the type-checker
    private var dailyPicksBlock: some View {
        let picks = main.dailyPicks
        let items = picks.items
        let refs  = picks.refs

        let refCourseIds = refs.map { $0.courseId }
        let refLessonIds = refs.map { $0.lessonId }
        let refIndices   = refs.map { $0.index }

        let learnedIdx = computeLearnedIdx(
            itemsCount: items.count,
            courseIds: refCourseIds,
            lessonIds: refLessonIds,
            indices: refIndices
        )
        let favoriteIdx = computeFavoriteIdx(
            itemsCount: items.count,
            courseIds: refCourseIds,
            lessonIds: refLessonIds,
            indices: refIndices
        )

        return VStack(alignment: .leading, spacing: 4) {
            MDDailyPicksComposite(
                title: "Разминка",
                items: items,
                courseShortNames: picks.courseShort,
                lessonShortNames: picks.lessonShort,
                learned: learnedIdx,
                favorites: favoriteIdx,
                activeIndex: $dailyIndex,
                onTapCourse: { i in
                    guard i >= 0, i < refs.count else { return }
                    let ref = refs[i]
                    if ref.courseId == "__pro__" {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.present(.proCoursePaywall(courseId: ""))
                        }
                        return
                    }
                    openCourse(ref.courseId)
                },
                onTapLesson: { i in
                    guard i >= 0, i < refs.count else { return }
                    let ref = refs[i]
                    if ref.courseId == "__pro__" {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.present(.proCoursePaywall(courseId: ""))
                        }
                        return
                    }
                    openLesson(courseId: ref.courseId, lessonId: ref.lessonId)
                },
                onOpenCourse: { i in
                    guard i >= 0, i < refs.count else { return }
                    let ref = refs[i]
                    if ref.courseId == "__pro__" {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.present(.proCoursePaywall(courseId: ""))
                        }
                        return
                    }
                    openCourse(ref.courseId)
                },
                onTapItem: { i in
                    guard i >= 0, i < items.count, i < refs.count else { return }
                    if items[i].isPro || refs[i].courseId == "__pro__" {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.present(.proCoursePaywall(courseId: ""))
                        }
                        return
                    }
                    // Тап по карточке — только менеджерские действия (прогресс, лайк и т.д.); переход на курс только по тапу на название курса в заголовке (onTapCourse).
                },
                onPlay: { i in
                    guard i >= 0, i < items.count else { return }
                    handlePlayItem(items[i])
                },
                onDone: { i in
                    guard i >= 0, i < items.count else { return false }
                    return handleDoneItem(items[i])
                },
                onFav: { i in
                    guard i >= 0, i < items.count, i < refs.count else { return false }
                    let item = items[i]
                    let ref  = refs[i]

                    // was it liked before?
                    let was = FavoriteManager.shared.isLiked(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index)

                    // toggle like
                    FavoriteManager.shared.toggle(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index)

                    // refresh local DS highlight state
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        rebuildFavoritesState()
                    }

                    // return true only when we ADDED like (so DS will advance). On unlike — return false (no scroll).
                    return !was
                },
                onIndexChange: { i in
                    dailyIndex = i
                    // keep DS highlights in sync for the newly active card
                    rebuildLearnedState()
                    rebuildFavoritesState()
                },
                showProgressRow: false
            )
            MDDailyPicksProgressRow(
                items: items,
                activeIndex: $dailyIndex,
                learned: learnedIdx,
                favorites: favoriteIdx,
                onIndexChange: { i in
                    dailyIndex = i
                    rebuildLearnedState()
                    rebuildFavoritesState()
                }
            )
        }
    }

    // MARK: - Секция «Продолжить» — 1-1 как карусель «Курсы» в Favorites: та же карточка (FDFavCourseCard), те же размеры и эффект
    private let continueSectionLimit = 4
    private let continueCardW: CGFloat = 268
    private let continueCardH: CGFloat = 196
    private let continueSpacing: CGFloat = 14
    private let continueSlotHeight: CGFloat = 196 + 36

    private func continueDisplayItems() -> [MainBannerItem] {
        let items = Array(main.resumeItems.prefix(continueSectionLimit))
        return items.isEmpty
            ? [MainBannerItem(id: "continue-empty", title: "Начни обучение", kind: .course, progress: 0)]
            : items
    }

    private func continueDTOs(from displayItems: [MainBannerItem]) -> [FDCourseDTO] {
        displayItems.map { item in
            let isEmpty = item.id == "continue-empty"
            return FDCourseDTO(
                courseId: item.id,
                title: item.title,
                subtitle: isEmpty ? "выбери курс и начни с первого урока" : "",
                addedAt: Date()
            )
        }
    }

    @ViewBuilder
    private var continueSingleCardBlock: some View {
        let displayItems = continueDisplayItems()
        let continueDTOs = continueDTOs(from: displayItems)
        let reelItems: [FDCourseDTO] = continueDTOs.isEmpty ? [] : (continueDTOs + continueDTOs + continueDTOs)
        let centerIndex = continueDTOs.count
        let sideInset: CGFloat = PD.Spacing.screen

        VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
            Text("ПРОДОЛЖИТЬ")
                .font(PD.FontToken.caption(12, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(PD.ColorToken.textSecondary)
                .padding(.horizontal, Theme.Layout.pageHorizontal)

            continueCarouselBody(
                displayItems: displayItems,
                continueDTOs: continueDTOs,
                reelItems: reelItems,
                centerIndex: centerIndex,
                sideInset: sideInset
            )
            .padding(.top, Theme.Layout.sectionTitleToContent)
        }
    }

    @ViewBuilder
    private func continueCarouselBody(
        displayItems: [MainBannerItem],
        continueDTOs: [FDCourseDTO],
        reelItems: [FDCourseDTO],
        centerIndex: Int,
        sideInset: CGFloat
    ) -> some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: continueSpacing) {
                        ForEach(Array(reelItems.enumerated()), id: \.offset) { idx, dto in
                            continueCarouselCell(
                                idx: idx,
                                dto: dto,
                                displayItems: displayItems,
                                continueDTOsCount: continueDTOs.count,
                                geo: geo
                            )
                        }
                    }
                    .padding(.horizontal, sideInset)
                    .padding(.vertical, 4)
                    .frame(height: continueCardH + 36)
                }
                .onAppear {
                    if !reelItems.isEmpty {
                        proxy.scrollTo(centerIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(height: continueSlotHeight)
        .frame(maxWidth: .infinity)
    }

    private func continueCarouselCell(
        idx: Int,
        dto: FDCourseDTO,
        displayItems: [MainBannerItem],
        continueDTOsCount: Int,
        geo: GeometryProxy
    ) -> some View {
        let baseIndex = idx % continueDTOsCount
        let bannerItem = displayItems[baseIndex]
        let (courseName, lessonName): (String, String) = {
            if bannerItem.id == "continue-empty" {
                return (dto.title, "")
            }
            if bannerItem.kind == .lesson, let colonIdx = bannerItem.id.firstIndex(of: ":") {
                let courseId = String(bannerItem.id[..<colonIdx])
                return (courseTitle(courseId), bannerItem.title)
            }
            return (bannerItem.title, "")
        }()
        let progressValue: Double = bannerItem.id == "continue-empty" ? 0 : bannerItem.progress
        return GeometryReader { itemGeo in
            let midX = itemGeo.frame(in: .global).midX
            let containerMidX = geo.frame(in: .global).midX
            let distance = abs(midX - containerMidX)
            let maxDistance = continueCardW + continueSpacing
            let t = min(distance / maxDistance, 1)
            let scale: CGFloat = 0.9 + (1 - t) * 0.12
            let opacity: Double = 0.45 + (1 - t) * 0.55
            let yOffset: CGFloat = t * 18

            FDContinueCourseCard(
                courseName: courseName,
                lessonName: lessonName,
                progress: progressValue,
                onOpen: {
                    if bannerItem.id == "continue-empty" {
                        startRandomCourseQuickstart()
                    } else {
                        openResumeItem(bannerItem)
                    }
                }
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: yOffset)
        }
        .frame(width: continueCardW, height: continueCardH)
        .id(idx)
    }

    private func openResumeItem(_ item: MainBannerItem) {
        if item.kind == .lesson, let colonIdx = item.id.firstIndex(of: ":") {
            let courseId = String(item.id[..<colonIdx])
            let lessonId = String(item.id[item.id.index(after: colonIdx)...])
            openLesson(courseId: courseId, lessonId: lessonId)
        } else {
            openCourse(item.id)
        }
    }

    // MARK: - Week progress (Profile-style compact indicators)
    @ViewBuilder
    private var weekProgressBlock: some View {
        let state = progress.publishedState
        let accent = AnyShapeStyle(ThemeManager.shared.currentAccentFill)

        VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
            Text("ЗА НЕДЕЛЮ")
                .font(PD.FontToken.caption(12, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(PD.ColorToken.textSecondary)
                .padding(.horizontal, Theme.Layout.pageHorizontal)

            HStack(spacing: PD.Spacing.inner) {
                weekProgressChip(label: "выучено", value: "\(state.totalStableSteps)", accent: false, progress: nil)
                weekProgressChip(label: "дней подряд", value: "\(state.currentStreak)", accent: false, progress: nil)
                weekProgressChip(label: "прогресс", value: "\(state.totalMasteryPercent)%", accent: true, progress: nil)
            }
            .padding(.horizontal, PD.Spacing.screen)
            .padding(.top, Theme.Layout.sectionTitleToContent)
        }
        .onReceive(NotificationCenter.default.publisher(for: .ProgressDidChange)) { _ in
            progress.refreshProfileState()
        }
    }

    /// Инфографика без рамок: значение + подпись + опциональный прогресс-бар.
    private func weekProgressChip(label: String, value: String, accent: Bool, progress: Double? = nil) -> some View {
        let fill = accent ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(PD.ColorToken.textSecondary)
        return VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(fill)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(PD.ColorToken.textSecondary)
            if let frac = progress, frac >= 0 {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PD.ColorToken.textSecondary.opacity(0.2))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(accent ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(PD.ColorToken.textSecondary))
                            .frame(width: max(0, g.size.width * min(1, frac)), height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    // MARK: - Подборка дня: карусель курсов (мини-карточки с чипом категории), данные грузятся в .task при открытии Main
    @ViewBuilder
    private var forYouSection: some View {
        if forYouCourses.isEmpty {
            EmptyView()
        } else {
            forYouReelContent
        }
    }

    private let forYouCardW: CGFloat = 200
    private let forYouCardH: CGFloat = 286
    private let forYouSpacing: CGFloat = 14
    private let forYouSlotHeight: CGFloat = 286 + 36

    @ViewBuilder
    private var forYouReelContent: some View {
        let dtos = forYouDTOs()
        let reelItems = dtos.isEmpty ? [] : (dtos + dtos + dtos)
        let centerIndex = dtos.count
        let sideInset: CGFloat = PD.Spacing.screen

        VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
            Text("ПОДБОРКА ДНЯ")
                .font(PD.FontToken.caption(12, weight: .semibold))
                .kerning(0.6)
                .foregroundColor(PD.ColorToken.textSecondary)
                .padding(.horizontal, Theme.Layout.pageHorizontal)

            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: forYouSpacing) {
                            ForEach(Array(reelItems.enumerated()), id: \.offset) { idx, dto in
                                forYouCarouselCell(idx: idx, dto: dto, dtos: dtos, geo: geo)
                            }
                        }
                        .padding(.horizontal, sideInset)
                        .padding(.vertical, 4)
                        .frame(height: forYouCardH + 36)
                    }
                    .onAppear {
                        if !reelItems.isEmpty {
                            proxy.scrollTo(centerIndex, anchor: .center)
                        }
                    }
                }
            }
            .frame(height: forYouSlotHeight)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Layout.sectionTitleToContent)
        }
    }

    private func forYouDTOs() -> [FDCourseDTO] {
        forYouCourses.map { model in
            FDCourseDTO(
                courseId: model.courseId,
                title: model.title,
                subtitle: model.subtitle,
                addedAt: Date()
            )
        }
    }

    private func forYouCarouselCell(idx: Int, dto: FDCourseDTO, dtos: [FDCourseDTO], geo: GeometryProxy) -> some View {
        let baseIndex = idx % max(1, dtos.count)
        let model = forYouCourses[baseIndex]
        return GeometryReader { itemGeo in
            let midX = itemGeo.frame(in: .global).midX
            let containerMidX = geo.frame(in: .global).midX
            let distance = abs(midX - containerMidX)
            let maxDistance = forYouCardW + forYouSpacing
            let t = min(distance / maxDistance, 1)
            let scale: CGFloat = 0.9 + (1 - t) * 0.12
            let opacity: Double = 0.45 + (1 - t) * 0.55
            let yOffset: CGFloat = t * 18

            FDMiniCourseCard(
                item: dto,
                categoryChip: model.categoryChip,
                onOpen: { openCourse(model.courseId) }
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: yOffset)
        }
        .frame(width: forYouCardW, height: forYouCardH)
        .id(idx)
    }

    private func startRandomCourseQuickstart() {
        // avoid stacking overlays
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.present(.randomCourseLoading)
        }

        Task { @MainActor in
            // a tiny delay for the loading animation
            try? await Task.sleep(nanoseconds: 950_000_000)

            // pick a random course according to current business rules
            // (pro: any; free: only free courses)
            let pick = await main.randomCourseForToday(isProUser: pro.isPro)
            let courseId = pick?.id

            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                overlay.dismiss()
            }

            guard let courseId else {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    overlay.present(.kunKruSuggestions)
                }
                return
            }
            openCourse(courseId)
        }
    }

    private func handleTapDayCard(_ item: WeeklyResumeItem) {
        let cal = Self.bangkokCal
        let today = cal.startOfDay(for: Date())
        let tapped = cal.startOfDay(for: item.date)

        Task { @MainActor in
            let resolved = await main.dayState(for: tapped)

            switch resolved.state {
            case .active:
                calendarSummaryPlannedOnly = false
                overlay.present(.calendarSummary(resolved.dayStart))

            case .plannedOnly:
                // planned-only day:
                // - future/today: open plan editor (add/remove)
                // - past: treat as "missed" → open summary (read-only)
                if resolved.dayStart < today {
                    calendarSummaryPlannedOnly = true
                    overlay.present(.calendarSummary(resolved.dayStart))
                } else {
                    calendarSummaryPlannedOnly = false
                    overlay.present(.calendarAdd(resolved.dayStart))
                }

            case .empty:
                // past empty day: do nothing
                if resolved.dayStart < today { return }

                // today empty: random
                if cal.isDateInToday(resolved.dayStart) {
                    startRandomCourseQuickstart()
                    return
                }

                // future empty: add
                calendarSummaryPlannedOnly = false
                overlay.present(.calendarAdd(resolved.dayStart))
            }
        }
    }


    private func bannerFor(date: Date) -> MDContinueSection.BannerInfo {
        let cal = Self.bangkokCal
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let idx = max(0, min(6, cal.dateComponents([.day], from: weekStart, to: date).day ?? 0))
        if idx < main.resumeItems.count {
            let it = main.resumeItems[idx]
            let category = (it.kind == .course ? "Курс" : "Урок")
            return (it.title, Double(it.progress), category)
        }
        let f = main.resumeItems.first
        return (f?.title ?? "", Double(f?.progress ?? 0), (f?.kind == .course ? "Курс" : "Урок"))
    }

    private func daySummary(for date: Date) -> CardDS_DaySummary? {
        return main.daySummary(for: date)
    }

    private func weekFor(offset: Int) -> [WeeklyResumeItem] {
        let cal = Self.bangkokCal
        let today = cal.startOfDay(for: Date())

        // source of truth: published weekSummary from MainManager
        // (offset is currently unused; the weekSummary itself is already aligned to today -3...+3)
        let days = main.weekSummary

        return days.map { ds in
            let dayStart = cal.startOfDay(for: ds.date)
            let weekdayIndex = max(1, min(7, cal.component(.weekday, from: dayStart)))
            let wd = cal.shortWeekdaySymbols[weekdayIndex - 1].lowercased()

            let raw1 = ds.courses.first?.trimmingCharacters(in: .whitespacesAndNewlines)
            let raw2 = ds.courses.dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines)

            let isPast = (dayStart < today)
            let hasPlannedCourses = (ds.totalCourses > 0)
            let isPlannedOnly = ds.isPlanned
            let isMissed = isPast && isPlannedOnly && hasPlannedCourses && (ds.progress <= 0.0001)

            // titles: for missed plan we show a dedicated placeholder card (no titles)
            let t1: String? = isMissed ? nil : ((raw1?.isEmpty == false) ? raw1 : nil)
            let t2: String? = isMissed ? nil : ((raw2?.isEmpty == false) ? raw2 : nil)

            // Strictly render from DaySummary: isEmpty, p1, p2
            // - empty past planned day => render as "missed" (isEmpty=true, coursesCount>0)
            // - empty non-planned day => render as empty
            let isEmpty = isMissed || (!isPlannedOnly && ds.totalCourses == 0)

            let p1: Double? = {
                if isEmpty { return nil }
                if isPlannedOnly { return 0.0 }
                return max(0.02, min(1.0, ds.progress))
            }()

            let p2: Double? = (t2 != nil) ? p1 : nil

            return WeeklyResumeItem(
                weekdayShort: wd,
                date: dayStart,
                title: t1,
                progress: p1,
                secondaryTitle: t2,
                secondaryProgress: p2,
                coursesCount: ds.totalCourses,
                isToday: cal.isDateInToday(dayStart),
                isEmpty: isEmpty
            )
        }
    }

    private func courseTitle(_ courseId: String) -> String {
        let t = LessonsManager.shared.courseTitle(for: courseId)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? courseId : t
    }

    private func courseProgress(_ courseId: String, isActive: Bool) -> Double? {
        // canonical source of truth: ProgressManager
        let v = ProgressManager.shared.progress(for: courseId, lessonId: nil)
        let clamped = max(0.0, min(1.0, v))

        if isActive {
            return max(0.02, clamped)
        }
        return clamped
    }

    private func stepKey(for idx: Int) -> String? {
        guard idx >= 0, idx < main.dailyPicks.refs.count else { return nil }
        let r = main.dailyPicks.refs[idx]
        guard r.index >= 0, r.courseId != "__pro__", r.lessonId != "__pro__" else { return nil }
        return "step:\(r.courseId):\(r.lessonId):idx\(r.index)"
    }

    private func computeLearnedIdx(
        itemsCount: Int,
        courseIds: [String],
        lessonIds: [String],
        indices: [Int]
    ) -> Set<Int> {
        var out: Set<Int> = []
        let n = min(itemsCount, courseIds.count, lessonIds.count, indices.count)
        guard n > 0 else { return out }

        for i in 0..<n {
            let c = courseIds[i]
            let l = lessonIds[i]
            let idx = indices[i]
            guard idx >= 0, c != "__pro__", l != "__pro__" else { continue }
            let key = "step:\(c):\(l):idx\(idx)"
            if learnedIds.contains(key) {
                out.insert(i)
            }
        }
        return out
    }

    private func computeFavoriteIdx(
        itemsCount: Int,
        courseIds: [String],
        lessonIds: [String],
        indices: [Int]
    ) -> Set<Int> {
        var out: Set<Int> = []
        let n = min(itemsCount, courseIds.count, lessonIds.count, indices.count)
        guard n > 0 else { return out }

        for i in 0..<n {
            let c = courseIds[i]
            let l = lessonIds[i]
            let idx = indices[i]
            guard idx >= 0, c != "__pro__", l != "__pro__" else { continue }
            let key = "step:\(c):\(l):idx\(idx)"
            if favoriteIds.contains(key) {
                out.insert(i)
            }
        }
        return out
    }

    private var mainScrollBlock: some View {
        let isModalPresented = overlay.isPresented

        return ScrollView {
            VStack(spacing: Theme.Layout.sectionGap) {
                fmSection
                    .padding(.top, Theme.Layout.sectionTop)

                weekProgressBlock
                    .padding(.top, Theme.Layout.sectionTop)

                forYouSection
                    .padding(.top, Theme.Layout.sectionTop)

                dailyPicksBlock
                    .padding(.top, Theme.Layout.sectionTop)

                continueSingleCardBlock
                    .padding(.top, Theme.Layout.sectionTop)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .modifier(_ContentMarginsCompat(horizontal: PD.Spacing.screen))
            .scaleEffect(isModalPresented ? 0.985 : 1)
            .opacity(isModalPresented ? 0.88 : 1)
            .overlay(
                Color.black
                    .opacity(isModalPresented ? 0.18 : 0)
                    .allowsHitTesting(false)
            )
            .allowsHitTesting(!isModalPresented)
        }
        .onAppear {
            progress.refreshProfileState()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProgressDidChange"))) { _ in
            rebuildLearnedState()
            scheduleMainRefresh(delay: 0.45)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FavoritesDidChange"))) { _ in
            Task { @MainActor in
                rebuildFavoritesState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LessonsDidChange"))) { _ in
            Task { @MainActor in
                lessonsTick &+= 1
                scheduleMainRefresh(delay: 0.45)
                rebuildLearnedState()
                rebuildFavoritesState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CoursePlanDidChange"))) { _ in
            // realtime calendar updates come from MainManager.weekSummary (@Published) via quick update;
            // do NOT force a full refresh here.
            lessonsTick &+= 1
        }
        .onReceive(session.objectWillChange) { _ in
            // avoid full refresh storms; calendar will update via weekSummary publishes
            lessonsTick &+= 1
        }
        .onChange(of: main.dailyPicks.refs) { _ in
            rebuildLearnedState()
            rebuildFavoritesState()
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.bottom, Theme.Layout.pageBottomSafeGap)
        .task {
            StepData.shared.preload()
            await main.refresh()
            await main.reloadDailyPicks()
            if main.weekSummary.isEmpty {
                await main.rebuildWeekSummary()
            }

            let targetIndex: Int = (main.dailyPicks.items.first?.isPro == true && main.dailyPicks.items.count > 1) ? 1 : 0
            dailyIndex = targetIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                dailyIndex = targetIndex
            }

            rebuildLearnedState()
            rebuildFavoritesState()

            let list = await main.availableCoursesForAdd(isProUser: pro.isPro, proShowcaseLimit: 4)
            forYouCourses = list
        }
    }

var body: some View {
    ZStack {
        PD.ColorToken.background
            .ignoresSafeArea()

        mainScrollBlock

        if let o = overlay.overlay {
            switch o {
            case .game:
                EmptyView()
            case .search:
                // Поиск показывается в AppShell поверх любого таба (Course или Main)
                EmptyView()
            case .calendarAdd(let d):
                calendarOverlay(sheet: CalendarSheet.add(d))
            case .calendarSummary(let d):
                calendarOverlay(sheet: CalendarSheet.summary(d))
            case .kunKruSuggestions:
                kunKruOverlay
            case .randomCourseLoading:
                randomCourseLoadingOverlay
            case .proCoursePaywall(_):
                // Shown at AppShell level so paywall works from any tab (EPIC 3)
                EmptyView()
            case .speakerPaywall:
                EmptyView()
            case .accentPicker:
                Color.clear
            default:
                EmptyView()
            }
        }
    }
    .ignoresSafeArea(.keyboard, edges: .bottom)
}
    // MARK: - Search overlay

    private var searchOverlay: some View {
        ZStack {
            searchOverlayBackdrop
            searchOverlayCard
        }
    }

    private var searchOverlayBackdrop: some View {
        Color.black.opacity(0.28)
            .ignoresSafeArea()
            .onTapGesture {
                dismissSearchOverlay()
            }
    }

    private var searchOverlayCard: some View {
        VStack(spacing: 12) {
            searchOverlayHeader
            searchOverlayField
            searchOverlayResults
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 22, y: 10)
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        // avoid double keyboard-avoidance (we ignore keyboard safe area globally)
        // lift the card slightly, but keep enough space for a full-size course card
        .padding(.bottom, keyboardHeight > 0 ? max(18, min(180, keyboardHeight * 0.45)) : 0)
        .transition(.scale(scale: 0.98).combined(with: .opacity))
        .onAppear {
            // best-effort ensure index is configured; results are produced by OverlayPresenter
            Task { @MainActor in
                await ensureOverlaySearchIndexConfigured()
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard overlay.overlay == .search else { return }
            guard let endFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

            let screenH = UIScreen.main.bounds.height
            let h = max(0, screenH - endFrame.minY)

            withAnimation(.easeOut(duration: 0.22)) {
                keyboardHeight = h
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            guard overlay.overlay == .search else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                keyboardHeight = 0
            }
        }
    }

    private var searchOverlayHeader: some View {
        HStack(spacing: 10) {
            Text("поиск")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 12)

            Button {
                dismissSearchOverlay()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }

    private var searchOverlayField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))

            TextField("введи слово", text: $overlay.searchQuery)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.92))
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)

            if !overlay.searchQuery.isEmpty {
                Button {
                    overlay.searchQuery = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isSearchFocused = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            Theme.Surfaces.card(Capsule(style: .continuous))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(ThemeManager.shared.currentAccentFill.opacity(isSearchFocused ? 0.95 : 0.0), lineWidth: 1.2)
        )
    }

    @ViewBuilder
    private var searchOverlayResults: some View {
        let q = overlay.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmptyQuery = q.isEmpty

        if isEmptyQuery {
            Color.clear
                .frame(height: 10)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if !overlay.searchCourseIds.isEmpty || searchViaLessonCourseIds().count > 0 {
                        Text("Курсы")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .kerning(0.5)
                        searchCoursesUnifiedSection()
                    }
                    if !overlay.searchLessonIds.isEmpty {
                        Text("Уроки")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .kerning(0.5)
                        searchLessonsSection()
                    }
                    if overlay.searchCourseIds.isEmpty && overlay.searchLessonIds.isEmpty && searchViaLessonCourseIds().isEmpty {
                        Text("ничего не найдено")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.62))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 380)
        }
    }

    private func searchViaLessonCourseIds() -> [String] {
        var ids: [String] = []
        for hitId in overlay.searchLessonIds {
            if let hit = searchLessonHitById[hitId] {
                ids.append(hit.courseId)
            }
        }
        return Array(Set(ids))
    }

    private func searchLessonsSection() -> some View {
        let hits = overlay.searchLessonIds.compactMap { searchLessonHitById[$0] }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(hits.prefix(8)), id: \.id) { hit in
                Button {
                    openLesson(courseId: hit.courseId, lessonId: hit.lessonId)
                    dismissSearchOverlay()
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hit.lessonTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CD.ColorToken.text)
                            Text(hit.courseTitle)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(CD.ColorToken.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func searchCoursesUnifiedSection() -> some View {
        let directCourseIds = overlay.searchCourseIds
        let lessonHitIds = overlay.searchLessonIds

        // courses that matched via lessons
        var viaLessonCourseIds: [String] = []
        viaLessonCourseIds.reserveCapacity(min(12, lessonHitIds.count))
        for hitId in lessonHitIds {
            if let hit = searchLessonHitById[hitId] {
                viaLessonCourseIds.append(hit.courseId)
            }
        }

        // stable unique order: direct matches first, then courses with lesson matches
        var seen: Set<String> = []
        var combined: [String] = []
        combined.reserveCapacity(min(12, directCourseIds.count + viaLessonCourseIds.count))

        for id in directCourseIds {
            if seen.insert(id).inserted {
                combined.append(id)
            }
        }
        for id in viaLessonCourseIds {
            if seen.insert(id).inserted {
                combined.append(id)
            }
        }

        // cap results for UI
        let ids = Array(combined.prefix(8))

        if ids.isEmpty {
            return AnyView(
                Text("ничего не найдено")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(ids, id: \.self) { courseId in
                        if let c = searchCourseById[courseId] {
                            let p = courseProgress(c.courseID, isActive: true) ?? 0.0

                            // if the course did not match directly, it came from a lesson hit → show a subtle hint
                            let isDirect = directCourseIds.contains(courseId)
                            let hint: String? = {
                                guard !isDirect else { return nil }
                                // pick the first lesson hit inside this course
                                if let first = lessonHitIds
                                    .compactMap({ searchLessonHitById[$0] })
                                    .first(where: { $0.courseId == courseId }) {
                                    let t = first.lessonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    return t.isEmpty ? nil : ("в уроке: " + t)
                                }
                                return nil
                            }()

                            _SearchCourseCard(
                                course: c,
                                progress: p,
                                subtitleOverride: hint,
                                onTap: {
                                    openCourse(c.courseID)
                                    dismissSearchOverlay()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            // fixed carousel height = stable layout; no "bottomless" empty area when keyboard is hidden
            .frame(height: 340)
        )
    }


    private func dismissSearchOverlay() {
        isSearchFocused = false
        keyboardHeight = 0
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.dismiss()
        }
    }

    // MARK: - Кун Кру: подборка курсов (без выбора дня)
    private var kunKruOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        overlay.dismiss()
                        kunKruCourses = []
                    }
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("Подборка для тебя")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer(minLength: 12)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.dismiss()
                            kunKruCourses = []
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }

                Text("Таика подобрала курсы по твоему прогрессу — выбери и продолжай")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.82))

                kunKruCarousel
                    .padding(.top, 6)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 22, y: 10)
            .frame(maxWidth: 420)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            let isProUser = pro.isPro
            let list = await main.availableCoursesForAdd(isProUser: isProUser, proShowcaseLimit: 10)
            kunKruCourses = list
        }
        .onDisappear { kunKruCourses = [] }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }

    /// Единая карусель как в CourseDS: spacing 32, запас по высоте под scale+yOffset.
    private var kunKruCarousel: some View {
        let peekMin: CGFloat = 24
        let cardH: CGFloat = 220
        let scaleExtra = (Theme.Layout.carouselDepthScaleCenter - 1) * cardH / 2
        let vPad = Theme.Layout.carouselDepthYOffsetMax + scaleExtra + Theme.Layout.carouselVPad
        let slotHeight = cardH + 2 * vPad
        let carouselSpacing: CGFloat = 32

        return GeometryReader { outer in
            let cardW = min(220, outer.size.width - (peekMin * 2))
            let sideInset = max(0, (outer.size.width - cardW) / 2)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: carouselSpacing) {
                        ForEach(Array(kunKruCourses.enumerated()), id: \.element.id) { idx, model in
                            GeometryReader { cellGeo in
                                let viewportCenterX = outer.size.width / 2
                                let cellCenterX = cellGeo.frame(in: .named("kunKruCarousel")).midX
                                let dist = abs(cellCenterX - viewportCenterX)
                                let norm = min(1.0, dist / max(1.0, outer.size.width * Theme.Layout.carouselDepthNormWidthFactor))
                                let scale = Theme.Layout.carouselDepthScaleSide + (Theme.Layout.carouselDepthScaleCenter - Theme.Layout.carouselDepthScaleSide) * (1.0 - norm)
                                let opacity = Theme.Layout.carouselDepthOpacitySide + (Theme.Layout.carouselDepthOpacityCenter - Theme.Layout.carouselDepthOpacitySide) * (1.0 - norm)
                                let yOffset = -(1.0 - norm) * Theme.Layout.carouselDepthYOffsetMax

                                kunKruCourseCard(model)
                                    .frame(width: cardW, height: cardH)
                                    .scaleEffect(scale)
                                    .opacity(opacity)
                                    .offset(y: yOffset)
                                    .zIndex(Double(1.0 - norm))
                            }
                            .frame(width: cardW, height: cardH)
                            .id(model.id)
                        }

                        if kunKruCourses.isEmpty {
                            CardDS.NoteCourseCardV(
                                label: "заметка",
                                title: "Загрузка…",
                                subtitle: "подбираем курсы",
                                progress: 0,
                                ctaTitle: nil,
                                onTap: { },
                                topRightChip: nil
                            )
                            .frame(width: cardW, height: cardH)
                        }
                    }
                    .padding(.horizontal, sideInset)
                    .padding(.vertical, vPad)
                }
                .coordinateSpace(name: "kunKruCarousel")
                .onAppear {
                    guard let first = kunKruCourses.first else { return }
                    withAnimation(.none) { proxy.scrollTo(first.id, anchor: .center) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: slotHeight)
    }

    private func kunKruCourseCard(_ model: MainManager.CourseCardModel) -> some View {
        let progress = courseProgress(model.courseId, isActive: true) ?? 0.0
        return CardDS.NoteCourseCardV(
            label: model.categoryChip ?? "курс",
            title: model.title,
            subtitle: model.subtitle,
            progress: progress,
            ctaTitle: "Открыть",
            onTap: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    overlay.dismiss()
                    kunKruCourses = []
                }
                openCourse(model.courseId)
            },
            topRightChip: model.categoryChip
        )
    }

    fileprivate struct _SearchCourseCard: View {
        let course: CourseBundle
        let progress: Double
        let subtitleOverride: String?
        let onTap: () -> Void

        var body: some View {
            let base = (course.courseDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = (subtitleOverride?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? base

            CardDS.NoteCourseCardV(
                label: "курс",
                categoryChip: nil,
                title: course.courseTitle,
                subtitle: subtitle,
                progress: progress,
                ctaTitle: "открыть",
                onTap: onTap,
                topRightChip: nil
            )
        }
    }


    @MainActor
    private func ensureOverlaySearchIndexConfigured() async {
        if didConfigureSearchIndex, !searchCourseById.isEmpty { return }

        // load JSON
        LessonsData.shared.preload()
        let allCourses = LessonsData.shared.allCourses()

        let built = await Task.detached(priority: .userInitiated) { () -> (byCourse: [String: CourseBundle], byLessonHit: [String: SearchLessonHit], courseEntries: [OverlayPresenter.SearchIndex.Entry], lessonEntries: [OverlayPresenter.SearchIndex.Entry]) in
            // build id->model maps (fast lookup for UI)
            var byCourse: [String: CourseBundle] = [:]
            byCourse.reserveCapacity(allCourses.count)

            var byLessonHit: [String: SearchLessonHit] = [:]
            byLessonHit.reserveCapacity(allCourses.count * 6)

            // build normalized haystacks for index
            func norm(_ s: String) -> String {
                s.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var courseEntries: [OverlayPresenter.SearchIndex.Entry] = []
            courseEntries.reserveCapacity(allCourses.count)

            var lessonEntries: [OverlayPresenter.SearchIndex.Entry] = []
            lessonEntries.reserveCapacity(allCourses.count * 6)

            for c in allCourses {
                byCourse[c.courseID] = c

                let courseHay = [
                    norm(c.courseTitle),
                    norm(c.courseDescription ?? "")
                ].joined(separator: " | ")

                courseEntries.append(.init(id: c.courseID, haystack: courseHay))

                for l in c.lessons {
                    let contentText = l.content.map { $0.text }.joined(separator: " ")
                    let hay = [
                        norm(l.title),
                        norm(l.subtitle),
                        norm(contentText),
                        norm(c.courseTitle)
                    ].joined(separator: " | ")

                    let hit = SearchLessonHit(
                        courseId: c.courseID,
                        lessonId: l.lessonID,
                        courseTitle: c.courseTitle,
                        lessonTitle: l.title,
                        lessonSubtitle: l.subtitle
                    )

                    byLessonHit[hit.id] = hit
                    lessonEntries.append(.init(id: hit.id, haystack: hay))
                }
            }

            return (byCourse, byLessonHit, courseEntries, lessonEntries)
        }.value

        // publish caches
        searchCourseById = built.byCourse
        searchLessonHitById = built.byLessonHit
        didConfigureSearchIndex = true

        // configure overlay index (it will debounce + search on its own)
        overlay.configureSearchIndex(courses: built.courseEntries, lessons: built.lessonEntries)
    }

    private var searchSection: some View {
        MDSearchSection(
            query: $mainSearchStub,
            placeholder: "поиск"
        )
        .disabled(true)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                overlay.presentSearch()
            }
            Task { @MainActor in
                await ensureOverlaySearchIndexConfigured()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isSearchFocused = true
                }
            }
        }
    }

    private var fmSection: some View {
        // DS-driven section (title from DS, no mascot param)
        MDFMSection(
            "ТАЙКА FM",
            messages: TaikaFMData.shared.messages(for: .main)
        )
    }

    private func scheduleMainRefresh(delay: Double = 0.35) {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak main] in
            Task { @MainActor in
                await main?.refresh()
            }
        }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    // MARK: - Random course loading overlay (scoped to MainView)

    private var randomCourseLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            TaikaLoadingView(label: "случайный курс…")
                .padding(.vertical, 18)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.black.opacity(0.18))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 22, y: 10)
                .frame(maxWidth: 280)
                .padding(.horizontal, 16)
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }

    // MARK: - Step handlers (mirror StepView)

    private func rebuildLearnedState() {
        var next: Set<String> = []
        for (i, ref) in main.dailyPicks.refs.enumerated() {
            guard ref.index >= 0 else { continue }
            if ProgressManager.shared.learnedSet(courseId: ref.courseId, lessonId: ref.lessonId).contains(ref.index),
               let key = stepKey(for: i) {
                next.insert(key)
            }
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            self.learnedIds = next
        }
    }

    private func rebuildFavoritesState() {
        var next: Set<String> = []
        for (i, item) in main.dailyPicks.items.enumerated() {
            let ref = main.dailyPicks.refs[i]
            guard ref.index >= 0, !item.isPro else { continue }
            if FavoriteManager.shared.isLiked(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index),
               let key = stepKey(for: i) {
                next.insert(key)
            }
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            self.favoriteIds = next
        }
    }

    private func handlePlayItem(_ item: SDStepItem) {
        StepAudio.shared.speakThai(item.subtitleTH)
    }
    private func handleFavItem(_ item: SDStepItem) {
        guard !item.isPro else { return }
        guard let idx = main.dailyPicks.items.firstIndex(where: { $0.id == item.id }) else { return }
        guard idx >= 0, idx < main.dailyPicks.refs.count else { return }
        let ref = main.dailyPicks.refs[idx]
        guard ref.index >= 0 else { return }

        FavoriteManager.shared.toggle(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            rebuildFavoritesState()
        }
    }
    private func handleDoneItem(_ item: SDStepItem) -> Bool {
        guard let idx = main.dailyPicks.items.firstIndex(where: { $0.id == item.id }) else { return false }
        guard idx >= 0, idx < main.dailyPicks.refs.count else { return false }
        let ref = main.dailyPicks.refs[idx]
        guard ref.index >= 0, !item.isPro else { return false }

        // toggle learned
        let wasLearned = ProgressManager.shared
            .learnedSet(courseId: ref.courseId, lessonId: ref.lessonId)
            .contains(ref.index)

        // 1) local UI update immediately
        if let key = stepKey(for: idx) {
            if wasLearned {
                learnedIds.remove(key)
            } else {
                learnedIds.insert(key)
            }
        }

        if wasLearned {
            doneHaptic.notificationOccurred(.warning)
        } else {
            doneHaptic.notificationOccurred(.success)
        }

        // 2) commit progress via StepManager (single writer path)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            StepManager.shared.setLearned(
                courseId: ref.courseId,
                lessonId: ref.lessonId,
                index: ref.index,
                isLearned: !wasLearned
            )
        }

        // advance only when we mark as learned; on unlearn do not advance
        return !wasLearned
    }
    // MARK: - Calendar overlay (scoped to MainView)

    private func calendarCourseCard(_ model: MainManager.CourseCardModel, sheetDay: Date) -> some View {
        CardDS.NoteCourseCardV(
            label: (model.cta == .add ? "добавить" : "курс"),
            categoryChip: nil,
            title: model.title,
            subtitle: model.subtitle,
            progress: (courseProgress(model.courseId, isActive: model.cta != .add) ?? 0.0),
            ctaTitle: (calendarSummaryPlannedOnly ? "открыть" : model.cta.title),
            onTap: {
                if calendarSummaryPlannedOnly {
                    openCourse(model.courseId)
                    calendarDayCourses = []
                    return
                }
                switch model.cta {
                case .add:
                    // 1) request add for the currently opened day
                    NotificationCenter.default.post(
                        name: Notification.Name("AddCourseToDayRequested"),
                        object: nil,
                        userInfo: [
                            "courseId": model.courseId,
                            "day": Self.bangkokCal.startOfDay(for: sheetDay)
                        ]
                    )
                    lessonsTick &+= 1
                    addOverlayReloadToken &+= 1
                case .continue:
                    openCourse(model.courseId)
                }

                if case .continue = model.cta {
            // overlay.dismiss() handled in openCourse(courseId)
                    calendarDayCourses = []
                }
            },
            topRightChip: model.categoryChip
        )
    }

    @ViewBuilder
    private func calendarOverlay(sheet: CalendarSheet) -> some View {
        let day = sheet.day
        let effectiveDay = sheet.isAdd ? calendarOverlaySelectedDay : day
        let taskId = calendarOverlayTaskId(day: effectiveDay, isAdd: sheet.isAdd, shuffle: addOverlayShuffleToken, reload: addOverlayReloadToken)

        Color.black.opacity(0.28)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    overlay.dismiss()
                    calendarDayCourses = []
                }
            }

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                calendarOverlayHeader(sheet: sheet)

                if sheet.isAdd {
                    calendarOverlayWeekStrip(selectedDay: $calendarOverlaySelectedDay, initialDay: day)
                }

                Text(effectiveDay.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))

                Text(sheet.isAdd
                     ? "выбери курс для этого дня"
                     : (calendarSummaryPlannedOnly
                        ? "открой курс и начни занятия"
                        : "продолжи с того места, где остановился"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.82))

                calendarOverlayCarousel(sheet: sheet, day: effectiveDay)
                    .padding(.top, 6)

            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 22, y: 10)
            .frame(maxWidth: 420)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: taskId) {
            if sheet.isAdd {
                let isProUser = pro.isPro
                let fetched = await main.availableCoursesForAdd(isProUser: isProUser, proShowcaseLimit: 8)

                let dayStart = Self.bangkokCal.startOfDay(for: effectiveDay)
                let lastId = session.lastPlannedCourseId(on: dayStart)

                // stable sort:
                // 1) last planned for this day (if any) goes first
                // 2) other planned courses for this day
                // 3) the rest, keeping original order
                let indexed = fetched.enumerated().map { (idx: $0.offset, model: $0.element) }
                let sorted = indexed.sorted { a, b in
                    let aSelected = session.isCoursePlanned(courseId: a.model.courseId, on: dayStart)
                    let bSelected = session.isCoursePlanned(courseId: b.model.courseId, on: dayStart)

                    let aIsLast = (lastId != nil && a.model.courseId == lastId)
                    let bIsLast = (lastId != nil && b.model.courseId == lastId)

                    if aIsLast != bIsLast { return aIsLast && !bIsLast }
                    if aSelected != bSelected { return aSelected && !bSelected }
                    return a.idx < b.idx
                }.map { $0.model }

                calendarDayCourses = sorted
            } else {
                calendarDayCourses = await main.activeCoursesForDay(effectiveDay, limit: 10)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CoursePlanDidChange"))) { _ in
            guard sheet.isAdd else { return }
            // force overlay content refresh (CTA/selected state) without leaving MainView
            addOverlayReloadToken &+= 1
        }
        .onAppear {
            if sheet.isAdd { calendarOverlaySelectedDay = sheet.day }
        }
        .transition(.scale(scale: 0.98).combined(with: .opacity))
    }

    /// Полоска 7 дней (сегодня −3…+3) для выбора дня в оверлее «План на неделю».
    private func calendarOverlayWeekStrip(selectedDay: Binding<Date>, initialDay: Date) -> some View {
        let cal = Self.bangkokCal
        let today = cal.startOfDay(for: Date())
        let days: [Date] = (-3...3).compactMap { cal.date(byAdding: .day, value: $0, to: today) }.map { cal.startOfDay(for: $0) }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.timeIntervalSince1970) { d in
                    let isSelected = cal.isDate(d, inSameDayAs: selectedDay.wrappedValue)
                    Button {
                        selectedDay.wrappedValue = d
                    } label: {
                        VStack(spacing: 2) {
                            Text(cal.shortWeekdaySymbols[cal.component(.weekday, from: d) - 1])
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.7))
                            Text("\(cal.component(.day, from: d))")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.85))
                        }
                        .frame(minWidth: 44)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 4)
    }

    private func calendarOverlayTaskId(day: Date, isAdd: Bool, shuffle: Int, reload: Int) -> String {
        "\(Self.bangkokCal.startOfDay(for: day).timeIntervalSinceReferenceDate)|\(isAdd ? 1 : 0)|\(shuffle)|\(reload)"
    }

    private func calendarOverlayHeader(sheet: CalendarSheet) -> some View {
        HStack(spacing: 10) {
            Text(sheet.isAdd ? "добавить курс" : "активность за день")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 12)

            if sheet.isAdd {
                Button {
                    addOverlayShuffleToken &+= 1
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    overlay.dismiss()
                    calendarDayCourses = []
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }


    private func addOverlayCourseCard(_ model: MainManager.CourseCardModel, day: Date) -> some View {
        let cal = Self.bangkokCal
        let dayStart = cal.startOfDay(for: day)
        let isToday = cal.isDateInToday(dayStart)
        let selected = session.isCoursePlanned(courseId: model.courseId, on: dayStart)

        // variant a hint: already planned on other visible days (today -3 ... today +3), excluding current day
        let today = cal.startOfDay(for: Date())
        var elsewhereDays: [Date] = []
        for off in -3...3 {
            guard let d = cal.date(byAdding: .day, value: off, to: today) else { continue }
            let d0 = cal.startOfDay(for: d)
            if cal.isDate(d0, inSameDayAs: dayStart) { continue }
            if session.isCoursePlanned(courseId: model.courseId, on: d0) {
                elsewhereDays.append(d0)
            }
        }

        let plannedElsewhereHint: String? = {
            guard !elsewhereDays.isEmpty else { return nil }
            if elsewhereDays.count >= 3 {
                return "уже в плане: \(elsewhereDays.count) дня"
            }
            let names: [String] = elsewhereDays.map { d in
                let wd = cal.component(.weekday, from: d)
                return cal.shortWeekdaySymbols[max(0, min(cal.shortWeekdaySymbols.count - 1, wd - 1))].lowercased()
            }
            return "уже в плане: " + names.joined(separator: ", ")
        }()

        let subtitleText: String = {
            let base = model.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let hint = plannedElsewhereHint else { return base }
            if base.isEmpty { return hint }
            return base + " • " + hint
        }()

        let ctaText: String = {
            if selected {
                return isToday ? "продолжить" : "добавлено"
            } else {
                return "добавить"
            }
        }()

        return CardDS.NoteCourseCardV(
            label: selected ? "выбрано" : "добавить",
            categoryChip: nil,
            title: model.title,
            subtitle: subtitleText,
            progress: (courseProgress(model.courseId, isActive: true) ?? 0.0),
            ctaTitle: ctaText,
            onTap: {
                // --- REPLACEMENT LOGIC START ---
                if selected {
                    // already planned for this exact day
                    if isToday {
                        openCourse(model.courseId)
                        return
                    }
                    // toggle off for non-today
                    NotificationCenter.default.post(
                        name: Notification.Name("RemoveCourseFromDayRequested"),
                        object: nil,
                        userInfo: [
                            "courseId": model.courseId,
                            "day": dayStart
                        ]
                    )
                } else {
                    // feature-gated via ProManager (no inline pro checks)
                    if !pro.isPro {
                        let existing = session.plannedCourseIds(on: dayStart)
                        if !existing.isEmpty {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                overlay.present(.proCoursePaywall(courseId: model.courseId))
                            }
                            return
                        }
                    }

                    // add strictly to the currently opened calendar day
                    NotificationCenter.default.post(
                        name: Notification.Name("AddCourseToDayRequested"),
                        object: nil,
                        userInfo: [
                            "courseId": model.courseId,
                            "day": dayStart
                        ]
                    )
                }

                lessonsTick &+= 1
                addOverlayReloadToken &+= 1
                // --- REPLACEMENT LOGIC END ---
            },
            topRightChip: model.categoryChip
        )
    }

    /// Единая карусель как в CourseDS: spacing 32, запас по высоте под scale+yOffset.
    private func calendarOverlayCarousel(sheet: CalendarSheet, day: Date) -> some View {
        let peekMin: CGFloat = 24
        let cardH: CGFloat = 220
        let scaleExtra = (Theme.Layout.carouselDepthScaleCenter - 1) * cardH / 2
        let vPad = Theme.Layout.carouselDepthYOffsetMax + scaleExtra + Theme.Layout.carouselVPad
        let slotHeight = cardH + 2 * vPad
        let carouselSpacing: CGFloat = 32

        return GeometryReader { outer in
            let cardW = min(220, outer.size.width - (peekMin * 2))
            let sideInset = max(0, (outer.size.width - cardW) / 2)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: carouselSpacing) {
                        ForEach(Array(calendarDayCourses.enumerated()), id: \.element.id) { idx, model in
                            GeometryReader { cellGeo in
                                let viewportCenterX = outer.size.width / 2
                                let cellCenterX = cellGeo.frame(in: .named("calendarOverlayCarousel")).midX
                                let dist = abs(cellCenterX - viewportCenterX)
                                let norm = min(1.0, dist / max(1.0, outer.size.width * Theme.Layout.carouselDepthNormWidthFactor))
                                let scale = Theme.Layout.carouselDepthScaleSide + (Theme.Layout.carouselDepthScaleCenter - Theme.Layout.carouselDepthScaleSide) * (1.0 - norm)
                                let opacity = Theme.Layout.carouselDepthOpacitySide + (Theme.Layout.carouselDepthOpacityCenter - Theme.Layout.carouselDepthOpacitySide) * (1.0 - norm)
                                let yOffset = -(1.0 - norm) * Theme.Layout.carouselDepthYOffsetMax

                                Group {
                                    if sheet.isAdd {
                                        addOverlayCourseCard(model, day: day)
                                    } else {
                                        calendarCourseCard(model, sheetDay: day)
                                    }
                                }
                                .frame(width: cardW, height: cardH)
                                .scaleEffect(scale)
                                .opacity(opacity)
                                .offset(y: yOffset)
                                .zIndex(Double(1.0 - norm))
                            }
                            .frame(width: cardW, height: cardH)
                            .id(model.id)
                        }

                        if calendarDayCourses.isEmpty {
                            CardDS.NoteCourseCardV(
                                label: "заметка",
                                title: sheet.isAdd ? "выбери курс" : "нет активности",
                                subtitle: sheet.isAdd ? "добавь курс в план на этот день" : "в этот день занятий не было",
                                progress: 0,
                                ctaTitle: nil,
                                onTap: { },
                                topRightChip: nil
                            )
                            .frame(width: cardW, height: cardH)
                        }
                    }
                    .padding(.horizontal, sideInset)
                    .padding(.vertical, vPad)
                }
                .coordinateSpace(name: "calendarOverlayCarousel")
                .onAppear {
                    guard let first = calendarDayCourses.first else { return }
                    withAnimation(.none) { proxy.scrollTo(first.id, anchor: .center) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: slotHeight)
    }
}


// MARK: - Navigation intents (scoped to MainView)
extension MainView {
    private func openCourse(_ courseId: String) {
        // prevent double pushes in the same frame (DailyPicks can fire multiple callbacks)
        guard !navPushInFlight else { return }
        navPushInFlight = true

        // always dismiss overlays before navigating
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.dismiss()
        }

        DispatchQueue.main.async {
            // treat this as a top-level navigation from main
            nav.reset()
            nav.go(.lessons(courseId: courseId))

            // release throttle after the next runloop (and a tiny buffer)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                navPushInFlight = false
            }
        }
    }

    private func openLesson(courseId: String, lessonId: String) {
        // prevent double pushes in the same frame
        guard !navPushInFlight else { return }
        navPushInFlight = true

        // we don't have a dedicated lesson route in NavigationIntent.Route.
        // Navigate to the course screen; lesson deep-linking is handled inside LessonsView (or later).
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.dismiss()
        }

        DispatchQueue.main.async {
            // treat this as a top-level navigation from main
            nav.reset()
            nav.go(.lessons(courseId: courseId))

            // optional: broadcast the intended lesson so LessonsView can react if it listens
            NotificationCenter.default.post(
                name: Notification.Name("OpenLessonRequested"),
                object: nil,
                userInfo: ["courseId": courseId, "lessonId": lessonId]
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                navPushInFlight = false
            }
        }
    }
}

// MARK: - Search overlay (общий state и view для показа из AppShell с любого таба)
struct SearchLessonHit: Identifiable, Equatable {
    let id: String
    let courseId: String
    let lessonId: String
    let courseTitle: String
    let lessonTitle: String
    let lessonSubtitle: String
    init(courseId: String, lessonId: String, courseTitle: String, lessonTitle: String, lessonSubtitle: String) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.courseTitle = courseTitle
        self.lessonTitle = lessonTitle
        self.lessonSubtitle = lessonSubtitle
        self.id = "lesson|\(courseId)|\(lessonId)"
    }
}

@MainActor
final class SearchOverlayState: ObservableObject {
    static let shared = SearchOverlayState()
    @Published private(set) var searchCourseById: [String: CourseBundle] = [:]
    @Published private(set) var searchLessonHitById: [String: SearchLessonHit] = [:]
    private var didConfigure = false

    func ensureConfigured(overlay: OverlayPresenter) async {
        if didConfigure, !searchCourseById.isEmpty { return }
        LessonsData.shared.preload()
        let allCourses = LessonsData.shared.allCourses()
        let built = await Task.detached(priority: .userInitiated) { () -> (byCourse: [String: CourseBundle], byLessonHit: [String: SearchLessonHit], courseEntries: [OverlayPresenter.SearchIndex.Entry], lessonEntries: [OverlayPresenter.SearchIndex.Entry]) in
            func norm(_ s: String) -> String {
                s.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            var byCourse: [String: CourseBundle] = [:]
            var byLessonHit: [String: SearchLessonHit] = [:]
            var courseEntries: [OverlayPresenter.SearchIndex.Entry] = []
            var lessonEntries: [OverlayPresenter.SearchIndex.Entry] = []
            for c in allCourses {
                byCourse[c.courseID] = c
                let courseHay = [norm(c.courseTitle), norm(c.courseDescription ?? "")].joined(separator: " | ")
                courseEntries.append(.init(id: c.courseID, haystack: courseHay))
                for l in c.lessons {
                    let contentText = l.content.map { $0.text }.joined(separator: " ")
                    let hay = [norm(l.title), norm(l.subtitle), contentText, norm(c.courseTitle)].joined(separator: " | ")
                    let hit = SearchLessonHit(courseId: c.courseID, lessonId: l.lessonID, courseTitle: c.courseTitle, lessonTitle: l.title, lessonSubtitle: l.subtitle)
                    byLessonHit[hit.id] = hit
                    lessonEntries.append(.init(id: hit.id, haystack: hay))
                }
            }
            return (byCourse, byLessonHit, courseEntries, lessonEntries)
        }.value
        searchCourseById = built.byCourse
        searchLessonHitById = built.byLessonHit
        didConfigure = true
        overlay.configureSearchIndex(courses: built.courseEntries, lessons: built.lessonEntries)
    }
}

struct SearchOverlayView: View {
    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent
    @ObservedObject private var searchState = SearchOverlayState.shared
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: { dismissSearch() })
            OverlayEtalonCard(title: "поиск", onDismiss: { dismissSearch() }) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                        TextField("введи слово", text: $overlay.searchQuery)
                            .font(.system(size: 14)).foregroundStyle(CD.ColorToken.text)
                            .focused($isSearchFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        if !overlay.searchQuery.isEmpty {
                            Button { overlay.searchQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(CD.ColorToken.textSecondary.opacity(0.6))
                            }
                        }
                    }
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(Theme.Surfaces.card(Capsule(style: .continuous)))
                    searchResultsView
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.bottom, keyboardHeight > 0 ? max(18, min(180, keyboardHeight * 0.45)) : 0)
            .onAppear {
                Task { await searchState.ensureConfigured(overlay: overlay) }
                isSearchFocused = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard overlay.overlay == .search else { return }
                guard let endFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                let h = max(0, UIScreen.main.bounds.height - endFrame.minY)
                withAnimation(.easeOut(duration: 0.22)) { keyboardHeight = h }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                guard overlay.overlay == .search else { return }
                withAnimation(.easeOut(duration: 0.18)) { keyboardHeight = 0 }
            }
        }
    }

    @ViewBuilder
    private var searchResultsView: some View {
        let q = overlay.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            Color.clear.frame(height: 10)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if !overlay.searchCourseIds.isEmpty || searchViaLessonCourseIds().count > 0 {
                        Text("Курсы").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white.opacity(0.7)).kerning(0.5)
                        searchCoursesSection
                    }
                    if !overlay.searchLessonIds.isEmpty {
                        Text("Уроки").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.white.opacity(0.7)).kerning(0.5)
                        searchLessonsSection
                    }
                    if overlay.searchCourseIds.isEmpty && overlay.searchLessonIds.isEmpty && searchViaLessonCourseIds().isEmpty {
                        Text("ничего не найдено").font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.62)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 380)
        }
    }

    private func searchViaLessonCourseIds() -> [String] {
        var ids: [String] = []
        for hitId in overlay.searchLessonIds {
            if let hit = searchState.searchLessonHitById[hitId] { ids.append(hit.courseId) }
        }
        return Array(Set(ids))
    }

    private var searchLessonsSection: some View {
        let hits = overlay.searchLessonIds.compactMap { searchState.searchLessonHitById[$0] }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(hits.prefix(8)), id: \.id) { hit in
                Button {
                    dismissSearch()
                    nav.popToRoot()
                    nav.go(.lesson(courseId: hit.courseId, lessonId: hit.lessonId))
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hit.lessonTitle).font(.system(size: 14, weight: .medium)).foregroundStyle(CD.ColorToken.text)
                            Text(hit.courseTitle).font(.system(size: 12)).foregroundStyle(CD.ColorToken.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(ThemeManager.shared.currentAccentFill)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchCoursesSection: some View {
        let directCourseIds = overlay.searchCourseIds
        let lessonHitIds = overlay.searchLessonIds
        var viaLessonCourseIds: [String] = []
        for hitId in lessonHitIds {
            if let hit = searchState.searchLessonHitById[hitId] { viaLessonCourseIds.append(hit.courseId) }
        }
        var seen: Set<String> = []
        var combined: [String] = []
        for id in directCourseIds { if seen.insert(id).inserted { combined.append(id) } }
        for id in viaLessonCourseIds { if seen.insert(id).inserted { combined.append(id) } }
        let ids = Array(combined.prefix(8))
        if ids.isEmpty {
            return AnyView(Text("ничего не найдено").font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.62)))
        }
        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(ids, id: \.self) { courseId in
                        if let c = searchState.searchCourseById[courseId] {
                            let p = ProgressManager.shared.progress(for: c.courseID, lessonId: nil)
                            let progress = max(0, min(1, p))
                            MainView._SearchCourseCard(
                                course: c,
                                progress: progress,
                                subtitleOverride: nil,
                                onTap: {
                                    dismissSearch()
                                    nav.popToRoot()
                                    nav.go(.lessons(courseId: c.courseID))
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 340)
        )
    }

    private func dismissSearch() {
        isSearchFocused = false
        keyboardHeight = 0
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { overlay.dismiss() }
    }
}

private struct _ContentMarginsCompat: ViewModifier {
    let horizontal: CGFloat
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .contentMargins(.horizontal, horizontal)
        } else {
            content
                .padding(.horizontal, horizontal)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(MainManager.shared)
        .environmentObject(OverlayPresenter.shared)
        .environmentObject(NavigationIntent())
}
