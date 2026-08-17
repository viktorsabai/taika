
import SwiftUI
import UIKit
import Foundation

@MainActor
final class _Ignore_Compile_Helper: ObservableObject {}

struct MainView: View {
    private static var didRunInitialBootstrapShared: Bool = false

    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent
    @ObservedObject private var main = MainManager.shared
    private let pro = ProManager.shared
    private let session = UserSession.shared
    private let progress = ProgressManager.shared
    @State private var dailyIndex: Int = 1
    /// Разминка больше не занимает весь скролл главной инлайн — открывается по тапу с компактной карточки.
    @State private var showDailyPicksSheet: Bool = false
    @State private var doneHaptic = UINotificationFeedbackGenerator()
    @State private var learnedIds: Set<String> = []
    @State private var favoriteIds: Set<String> = []
    @State private var lessonsTick: Int = 0
    @State private var keyboardHeight: CGFloat = 0
    @State private var navPushInFlight: Bool = false
    @State private var suppressReactiveRefreshUntil: Date = .distantPast
    @State private var lastReactiveRefreshAt: Date = .distantPast
    @State private var weekProgressState: ProfileDashboardState = ProgressManager.shared.publishedState

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
    @State private var addOverlayShuffleToken: Int = 0
    @State private var addOverlayReloadToken: Int = 0
    /// В оверлее «добавить курс»: выбранный день (полоска 7 дней); синхронизируется с sheet.day при появлении.
    @State private var calendarOverlaySelectedDay: Date = Date()
    @State private var kunKruCourses: [MainManager.CourseCardModel] = []
    /// Умная подборка курсов: показывается в секции «ПОДБОРКА ДНЯ».
    @State private var forYouCourses: [MainManager.CourseCardModel] = []
    @State private var didCenterForYouCarousel = false
    @State private var forYouAutoIndex: Int = 0
    @State private var forYouAutoScrollPausedUntil: Date = .distantPast
    private let forYouAutoScrollTimer = Timer.publish(every: 3.6, on: .main, in: .common).autoconnect()
    /// Нативный индикатор при «Начни обучение» — без кастомного «случайный курс…» оверлея.
    @State private var isStartingRandomCourse = false

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

        return AnyView(VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
            MDDailyPicksComposite(
                title: "РАЗМИНКА",
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
                            overlay.presentPro(reason: .dailyPicks)
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
                            overlay.presentPro(reason: .dailyPicks)
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
                            overlay.presentPro(reason: .dailyPicks)
                        }
                        return
                    }
                    openCourse(ref.courseId)
                },
                onTapItem: { i in
                    guard i >= 0, i < items.count, i < refs.count else { return }
                    if items[i].isPro || refs[i].courseId == "__pro__" {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.presentPro(reason: .dailyPicks)
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
                    guard !item.isPro, ref.courseId != "__pro__" else { return false }

                    // was it liked before?
                    let was = FavoriteManager.shared.isLiked(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index)

                    // toggle like
                    FavoriteManager.shared.toggle(step: item, courseId: ref.courseId, lessonId: ref.lessonId, order: ref.index)

                    // refresh local DS highlight state
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        rebuildFavoritesState()
                    }

                    // true = сейчас в избранном (для UI); перелистывание только у «запомнил».
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
        })
    }

    /// Полноэкранный оверлей с полной интерактивной разминкой (карточки + прогресс-ряд).
    /// Важно: постоянный хедер приложения (логотип/иконки) рисуется поверх всего таба
    /// с zIndex 50 в AppShell, поэтому свой заголовок и кнопку закрытия нужно опускать
    /// ниже `rootHeaderClearance` — иначе они уезжают под персистентный хедер и выглядят
    /// как «нет пути назад». Контент центрируем по высоте, а не прижимаем к верху.
    @ViewBuilder
    private var dailyPicksFullOverlay: some View {
        if showDailyPicksSheet {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) { showDailyPicksSheet = false }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Главная")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Назад на главную")

                    Spacer(minLength: 12)

                    Text("Разминка")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .frame(minHeight: 44, alignment: .trailing)
                }
                .padding(.horizontal, Theme.Layout.pageHorizontal)
                .padding(.bottom, 6)

                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            dailyPicksBlock
                                .padding(.vertical, 10)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: proxy.size.height)
                    }
                }
            }
            .padding(.top, Theme.Layout.rootHeaderClearance + 6)
            .padding(.bottom, ToolBar.recommendedBottomInset + 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(PD.ColorToken.background.ignoresSafeArea())
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard value.translation.height > 70,
                              abs(value.translation.height) > abs(value.translation.width) else { return }
                        withAnimation(.easeInOut(duration: 0.2)) { showDailyPicksSheet = false }
                    }
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .zIndex(20)
        }
    }

    // MARK: - Продолжить + Разминка (отдельно)

    /// Базовый курс «Разговорный старт», если продолжать нечего.
    private static let conversationalStartCourseId = "course_b_1"

    private func activeResumeItem() -> MainBannerItem? {
        main.resumeItems.first { $0.id != "continue-empty" }
    }

    private func handleContinueCardTap() {
        if let item = activeResumeItem() {
            openResumeItem(item)
            return
        }
        openCourse(Self.conversationalStartCourseId)
    }

    private func continuePillTitle() -> String {
        guard let item = activeResumeItem() else {
            return "Начать обучение"
        }
        let (courseId, _) = parseResumeItemIds(item)
        let courseTitle = LessonsManager.shared.courseTitle(for: courseId)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = courseTitle.isEmpty ? item.title : courseTitle
        return name.isEmpty ? "Продолжить" : "Продолжить \(name)"
    }

    /// Одна строка: «Разминка · 13ч 39м» (+ секунды ближе к концу).
    private func warmupPillTitle(now: Date = Date()) -> String {
        let label = MDDailyRefreshCountdown.label(now: now)
        if label == "скоро" { return "Разминка · скоро" }
        return "Разминка · \(label)"
    }

    private var warmupRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            MDMainOutlinePillCTA(
                title: warmupPillTitle(now: context.date),
                icon: "bolt.fill",
                progressFill: MDDailyRefreshCountdown.remainingFraction(now: context.date)
            ) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                    showDailyPicksSheet = true
                }
            }
        }
        .accessibilityLabel("Разминка, таймер до обновления")
    }

    private var dictionaryMainButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            overlay.present(.dictionaryQuickDrawer)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Мой словарь")
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                let count = FavoriteManager.shared.smartSpeakerDictionaryCardsDTO.count
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(Capsule().fill(PD.ColorToken.background.opacity(0.24)))
                }
            }
            .foregroundStyle(PD.ColorToken.text)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PD.ColorToken.card.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ThemeManager.shared.currentAccentFill.opacity(0.54), lineWidth: 1)
            )
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
        .accessibilityLabel("Мой словарь")
    }

    private var mainUtilityRow: some View {
        HStack(spacing: 10) {
            warmupRow
                .frame(maxWidth: .infinity)
            dictionaryMainButton
                .frame(width: 142)
        }
        .padding(.horizontal, Theme.Layout.pageHorizontal)
    }

    private func dayWord(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "дней" }
        switch mod10 {
        case 1: return "день"
        case 2, 3, 4: return "дня"
        default: return "дней"
        }
    }

    private func resolveNextLessonTitle(
        courseId: String,
        lessonId: String?,
        item: MainBannerItem,
        lessons: [LessonBundle]
    ) -> (title: String, minutes: Int?, subtitle: String?) {
        if let lid = lessonId,
           let lesson = lessons.first(where: { $0.lessonID == lid }) {
            let title = item.title.isEmpty ? lesson.title : item.title
            return (title, item.lessonMinutes ?? lesson.durationMinutes, lesson.subtitle)
        }
        for lesson in lessons {
            let p = LessonsManager.shared.lessonPercent(courseId: courseId, lessonId: lesson.lessonID)
            if p < 0.999 {
                return (lesson.title, lesson.durationMinutes, lesson.subtitle)
            }
        }
        if let first = lessons.first {
            return (first.title, first.durationMinutes, first.subtitle)
        }
        return (item.title, item.lessonMinutes, nil)
    }

    private func parseResumeItemIds(_ item: MainBannerItem) -> (courseId: String, lessonId: String?) {
        if item.kind == .lesson, let colon = item.id.firstIndex(of: ":") {
            let courseId = String(item.id[..<colon])
            let lessonId = String(item.id[item.id.index(after: colon)...])
            return (courseId, lessonId)
        }
        return (item.id, nil)
    }

    private func presentWarmupProPaywall() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.presentPro(reason: .dailyPicks)
        }
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

    // MARK: - Week progress — лёгкая подпись-строка, а не отдельная секция с рамкой и заголовком.
    // Раньше это была своя зона («ЗА НЕДЕЛЮ» + панель с 3 показателями) — дублировала Профиль
    // и добавляла лишний блок между «Скажи сам» и «Подборкой дня». Сводим к одной строке-подписи.
    private func weekStreakCaptionText() -> String? {
        let state = weekProgressState
        var parts: [String] = []
        if state.currentStreak > 0 {
            parts.append("🔥 серия \(state.currentStreak) \(dayWord(state.currentStreak))")
        }
        if state.totalMasteryPercent > 0 {
            parts.append("\(state.totalMasteryPercent)% усвоено")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "   ·   ")
    }

    @ViewBuilder
    private var weekStreakCaption: some View {
        if let caption = weekStreakCaptionText() {
            Text(caption)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Layout.pageHorizontal + 4)
                .padding(.top, 12)
        }
    }

    // MARK: - Подборка дня: карусель курсов (мини-карточки с чипом категории), данные грузятся
    // в .task при открытии Main. Возвращено как было — карточки, а не текст/иконки.
    @ViewBuilder
    private var forYouSection: some View {
        if forYouCourses.isEmpty {
            forYouPlaceholderSection
        } else {
            forYouReelContent
        }
    }

    private let forYouSpacing: CGFloat = MDPortraitCarouselMetrics.spacing
    private let forYouSlotHeight: CGFloat = MDPortraitCarouselMetrics.slotHeight

    @ViewBuilder
    private var forYouPlaceholderSection: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
            HStack(spacing: 8) {
                TaikaSectionLabel(title: "ПОДБОРКА ДНЯ")
                Spacer(minLength: 8)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    nav.openCourseCatalog(tab: .scenarios)
                } label: {
                    Text("ВСЕ КУРСЫ")
                        .taikaSubsectionStyle(accent: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PD.Spacing.screen)

            GeometryReader { outer in
                let cardW = min(MDPortraitCarouselMetrics.cardWidth, outer.size.width - (PD.Spacing.screen * 2))
                HStack(spacing: forYouSpacing) {
                    RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                        .fill(PD.ColorToken.card.opacity(0.62))
                        .overlay(
                            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                        )
                        .frame(width: cardW, height: MDPortraitCarouselMetrics.cardHeight)
                        .redacted(reason: .placeholder)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, PD.Spacing.screen)
                .padding(.vertical, 4)
            }
            .frame(height: forYouSlotHeight)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Layout.sectionTitleToContent)
        }
    }

    @ViewBuilder
    private var forYouReelContent: some View {
        let dtos = forYouDTOs()
        let baseCount = dtos.count
        let allowsPeek = baseCount > 1
        // Тройной буфер — автоскролл по кругу без рывка на краю.
        let loopedCount = allowsPeek ? baseCount * 3 : baseCount
        let sideInset: CGFloat = PD.Spacing.screen

        VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
            HStack(spacing: 8) {
                TaikaSectionLabel(title: "ПОДБОРКА ДНЯ")
                Spacer(minLength: 8)
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    nav.openCourseCatalog(tab: .scenarios)
                }) {
                    Text("ВСЕ КУРСЫ")
                        .taikaSubsectionStyle(accent: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PD.Spacing.screen)

            GeometryReader { outer in
                let cardW = MDPortraitCarouselMetrics.cardWidth
                let singleSideInset = max(0, (outer.size.width - cardW) / 2)
                ScrollViewReader { proxy in
                    TaikaCarouselScroll {
                        HStack(alignment: .top, spacing: allowsPeek ? forYouSpacing : 0) {
                            ForEach(0..<loopedCount, id: \.self) { renderIdx in
                                let baseIdx = allowsPeek ? (renderIdx % baseCount) : renderIdx
                                let dto = dtos[baseIdx]
                                forYouCarouselCell(idx: baseIdx, dto: dto, dtos: dtos)
                                    .id(renderIdx)
                            }
                        }
                        .padding(.horizontal, allowsPeek ? sideInset : singleSideInset)
                        .padding(.vertical, 4)
                        .frame(height: MDPortraitCarouselMetrics.cardHeight + 36)
                    }
                    .scrollDisabled(!allowsPeek)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { _ in
                                forYouAutoScrollPausedUntil = Date().addingTimeInterval(6)
                            }
                    )
                    .onAppear {
                        guard !didCenterForYouCarousel, baseCount > 0 else { return }
                        didCenterForYouCarousel = true
                        let start = allowsPeek ? baseCount : 0
                        forYouAutoIndex = start
                        DispatchQueue.main.async {
                            withAnimation(.none) {
                                proxy.scrollTo(start, anchor: .center)
                            }
                        }
                    }
                    .onReceive(forYouAutoScrollTimer) { _ in
                        guard allowsPeek, baseCount > 1 else { return }
                        guard Date() >= forYouAutoScrollPausedUntil else { return }
                        guard !overlay.isPresented, !showDailyPicksSheet else { return }

                        var next = forYouAutoIndex + 1
                        // Держим индекс в среднем блоке, чтобы круг не упирался в край.
                        if next >= baseCount * 2 {
                            next = baseCount + (next % baseCount)
                            withAnimation(.none) {
                                proxy.scrollTo(next - 1, anchor: .center)
                            }
                        }
                        forYouAutoIndex = next
                        withAnimation(.easeInOut(duration: 0.55)) {
                            proxy.scrollTo(next, anchor: .center)
                        }
                    }
                    .onChange(of: baseCount) { _, newCount in
                        guard newCount > 0 else { return }
                        didCenterForYouCarousel = false
                        let start = newCount > 1 ? newCount : 0
                        forYouAutoIndex = start
                        DispatchQueue.main.async {
                            withAnimation(.none) {
                                proxy.scrollTo(start, anchor: .center)
                            }
                            didCenterForYouCarousel = true
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

    private func forYouCarouselCell(idx: Int, dto: FDCourseDTO, dtos: [FDCourseDTO]) -> some View {
        let baseIndex = idx
        let model = forYouCourses[baseIndex]
        return FDMiniCourseCard(
            item: dto,
            layoutWidth: MDPortraitCarouselMetrics.cardWidth,
            layoutHeight: MDPortraitCarouselMetrics.cardHeight,
            isPro: model.isPro,
            categoryChip: model.categoryChip,
            learningOutcomes: model.learningOutcomes,
            lessonCount: model.lessonCount,
            durationMinutes: model.durationMinutes,
            onOpen: { openCourse(model.courseId) }
        )
        .frame(width: MDPortraitCarouselMetrics.cardWidth, height: MDPortraitCarouselMetrics.cardHeight)
    }

    private func startRandomCourseQuickstart() {
        guard !isStartingRandomCourse else { return }
        isStartingRandomCourse = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task { @MainActor in
            let pick = await main.randomCourseForToday(isProUser: pro.isPro)
            isStartingRandomCourse = false

            guard let courseId = pick?.id else {
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
            let activity = main.daySummary(for: dayStart)

            return WeeklyResumeItem(
                weekdayShort: wd,
                date: dayStart,
                title: t1,
                progress: p1,
                secondaryTitle: t2,
                secondaryProgress: p2,
                coursesCount: ds.totalCourses,
                isToday: cal.isDateInToday(dayStart),
                isEmpty: isEmpty,
                learnedCount: activity?.learned,
                favCount: activity?.favs,
                audioMinutes: activity?.audioMinutes
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

    /// Приветствие в духе AI-инструмента: время суток в Бангкоке + имя, если пользователь входил
    /// через Sign in with Apple.
    private func timeGreeting() -> String {
        let hour = Self.bangkokCal.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        case 18..<23: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }

    private var heroGreetingText: String {
        let base = timeGreeting()
        guard let raw = AuthService.shared.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return "\(base) 👋" }
        let firstName = raw.split(separator: " ").first.map(String.init) ?? raw
        return "\(base), \(firstName) 👋"
    }

    private var continueSection: some View {
        MDMainFilledPillCTA(
            title: continuePillTitle(),
            icon: "graduationcap.fill"
        ) {
            handleContinueCardTap()
        }
        .padding(.horizontal, Theme.Layout.pageHorizontal)
    }

    private var mainScrollBlock: some View {
        let isModalPresented = overlay.isPresented

        // Главная: герой → продолжить → разминка → подборка курсов.
        let sectionBreath: CGFloat = 32

        return TaikaRootVerticalScroll {
            VStack(spacing: 0) {
                MDPromptHero(
                    greeting: heroGreetingText,
                    onOpenSpeaker: openSpeakerConversationFromSandbox
                )
                .padding(.top, 6)

                continueSection
                    .padding(.top, sectionBreath)

                mainUtilityRow
                    .padding(.top, 12)

                forYouSection
                    .padding(.top, sectionBreath)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.bottom, ToolBar.recommendedBottomInset + 12)
            .allowsHitTesting(!isModalPresented)
        }
        .onAppear {
            suppressReactiveRefreshUntil = Date().addingTimeInterval(0.55)
            progress.refreshProfileState()
            weekProgressState = progress.publishedState
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProgressDidChange"))) { _ in
            guard Date() >= suppressReactiveRefreshUntil else { return }
            guard allowReactiveRefresh(minInterval: 0.28) else { return }
            progress.refreshProfileState()
            weekProgressState = progress.publishedState
            rebuildLearnedState()
            Task { await main.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FavoritesDidChange"))) { _ in
            guard allowReactiveRefresh(minInterval: 0.22) else { return }
            Task { @MainActor in
                rebuildFavoritesState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LessonsDidChange"))) { _ in
            guard Date() >= suppressReactiveRefreshUntil else { return }
            guard allowReactiveRefresh(minInterval: 0.4) else { return }
            Task { @MainActor in
                lessonsTick &+= 1
                rebuildLearnedState()
                rebuildFavoritesState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CoursePlanDidChange"))) { _ in
            // realtime calendar updates come from MainManager.weekSummary (@Published) via quick update;
            // do NOT force a full refresh here.
            lessonsTick &+= 1
        }
        .onChange(of: main.dailyPicks.refs) { _, _ in
            rebuildLearnedState()
            rebuildFavoritesState()
        }
        .onChange(of: pro.isPro) { _, _ in
            Task { @MainActor in
                await main.reloadDailyPicks()
                await main.reloadDailyCoursePicks()
                forYouCourses = main.dailyCourseCards
                let targetIndex: Int = (main.dailyPicks.items.first?.isPro == true && main.dailyPicks.items.count > 1) ? 1 : 0
                dailyIndex = min(targetIndex, max(0, main.dailyPicks.items.count - 1))
                rebuildLearnedState()
                rebuildFavoritesState()
            }
        }
        .safeAreaPadding(.bottom, Theme.Layout.pageBottomSafeGap)
        .task {
            if Self.didRunInitialBootstrapShared {
                // On re-appear keep current feed stable and only refresh lightweight local state.
                progress.refreshProfileState()
                weekProgressState = progress.publishedState
                // Пересобираем при смене PRO/free (кэш иначе оставляет 10 карточек free-юзеру).
                await main.reloadDailyPicks()
                if main.weekSummary.isEmpty {
                    await main.rebuildWeekSummary()
                }
                await main.reloadDailyCoursePicks()
                forYouCourses = main.dailyCourseCards
                rebuildLearnedState()
                rebuildFavoritesState()
                return
            }
            Self.didRunInitialBootstrapShared = true

            StepData.shared.preload()
            await main.refresh()
            progress.refreshProfileState()
            weekProgressState = progress.publishedState
            await main.reloadDailyPicks()
            if main.weekSummary.isEmpty {
                await main.rebuildWeekSummary()
            }

            let targetIndex: Int = (main.dailyPicks.items.first?.isPro == true && main.dailyPicks.items.count > 1) ? 1 : 0
            dailyIndex = targetIndex

            rebuildLearnedState()
            rebuildFavoritesState()

            // Daily course picks: stable set for the current Bangkok day (prepared by MainManager).
            await main.reloadDailyCoursePicks()
            forYouCourses = main.dailyCourseCards

            // Прогрев индекса поиска в фоне: к первому открытию оверлея данные чаще уже собраны.
            Task(priority: .utility) {
                await SearchOverlayState.shared.ensureConfigured(overlay: OverlayPresenter.shared)
            }
        }
    }


var body: some View {
    ZStack {
        PD.ColorToken.background
            .ignoresSafeArea()

        VStack(spacing: 0) {
            mainScrollBlock
                // Clearance уже на внешней VStack — внутри скролла не дублируем (как в CourseView).
                .environment(\.taikaRootHeaderClearance, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, Theme.Layout.rootHeaderClearance)

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
                // Legacy path — больше не показываем кастомный «случайный курс…».
                EmptyView()
            case .proCoursePaywall(_, _):
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

        if isStartingRandomCourse {
            nativeCourseStartOverlay
        }

        dailyPicksFullOverlay
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
        OverlayEtalonBackground(onDismiss: dismissSearchOverlay)
    }

    private var searchOverlayCard: some View {
        VStack(spacing: 12) {
            searchOverlayHeader
            searchOverlayField
            searchOverlayResults
        }
        .padding(16)
        .taikaBlackGlassBackground(cornerRadius: 26)
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CD.ColorToken.text)

            Spacer(minLength: 12)

            Button {
                dismissSearchOverlay()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
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
            TaikaRootVerticalScroll {
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
            TaikaCarouselScroll {
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
            OverlayEtalonBackground(onDismiss: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    overlay.dismiss()
                    kunKruCourses = []
                }
            })

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("Подборка для тебя")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                    Spacer(minLength: 12)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.dismiss()
                            kunKruCourses = []
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Закрыть")
                }

                Text("Таика подобрала курсы по твоему прогрессу — выбери и продолжай")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)

                kunKruCarousel
                    .padding(.top, 6)
            }
            .padding(16)
            .taikaBlackGlassBackground(cornerRadius: 26)
            .frame(maxWidth: 420)
            .padding(.horizontal, 16)
            .padding(.top, 60)
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
    /// Peek соседей — только если карточек больше одной.
    private var kunKruCarousel: some View {
        let allowsPeek = kunKruCourses.count > 1
        let peekMin: CGFloat = allowsPeek ? 24 : 0
        let cardH: CGFloat = 220
        let scaleExtra = (Theme.Layout.carouselDepthScaleCenter - 1) * cardH / 2
        let vPad = Theme.Layout.carouselDepthYOffsetMax + scaleExtra + Theme.Layout.carouselVPad
        let slotHeight = cardH + 2 * vPad
        let carouselSpacing: CGFloat = allowsPeek ? 32 : 0

        return GeometryReader { outer in
            let cardW = allowsPeek
                ? min(220, outer.size.width - (peekMin * 2))
                : min(220, max(0, outer.size.width - (PD.Spacing.screen * 2)))
            let sideInset = max(0, (outer.size.width - cardW) / 2)
            ScrollViewReader { proxy in
                TaikaCarouselScroll {
                    LazyHStack(spacing: carouselSpacing) {
                        ForEach(Array(kunKruCourses.enumerated()), id: \.element.id) { idx, model in
                            GeometryReader { cellGeo in
                                let viewportCenterX = outer.size.width / 2
                                let cellCenterX = cellGeo.frame(in: .named("kunKruCarousel")).midX
                                let dist = abs(cellCenterX - viewportCenterX)
                                let norm = allowsPeek
                                    ? min(1.0, dist / max(1.0, outer.size.width * Theme.Layout.carouselDepthNormWidthFactor))
                                    : 0
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
                .scrollDisabled(!allowsPeek)
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
                label: "",
                categoryChip: nil,
                title: course.courseTitle,
                subtitle: subtitle,
                progress: progress,
                ctaTitle: "открыть",
                onTap: onTap,
                topRightChip: nil
            )
            .frame(width: 258, height: 320, alignment: .topLeading)
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

    // Taika FM убран с главной (был дублем: он уже есть в разделе «Курсы» — courseFmSection).

    private func allowReactiveRefresh(minInterval: TimeInterval) -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastReactiveRefreshAt) >= minInterval else { return false }
        lastReactiveRefreshAt = now
        return true
    }
    // MARK: - Random course loading overlay (scoped to MainView)

    /// Нативный индикатор старта курса — системный ProgressView, без кастомного макета.
    private var nativeCourseStartOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.15)
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        }
        .transition(.opacity)
        .zIndex(30)
        .accessibilityLabel("Загрузка курса")
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
        self.learnedIds = next
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
        self.favoriteIds = next
    }

    private func handlePlayItem(_ item: SDStepItem) {
        if item.isPro {
            presentWarmupProPaywall()
            return
        }
        StepAudio.shared.speakThai(item.subtitleTH, stepItemId: item.id)
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

        // 2) commit progress via StepManager (single writer path) — без лишней паузы 220ms
        Task { @MainActor in
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

        OverlayEtalonBackground(onDismiss: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                overlay.dismiss()
                calendarDayCourses = []
            }
        })

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
            .taikaBlackGlassBackground(cornerRadius: 26)
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
        return TaikaCarouselScroll {
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
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
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
                                overlay.presentPro(reason: .lockedCourse, courseId: model.courseId)
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
    /// Peek соседей — только если карточек больше одной.
    private func calendarOverlayCarousel(sheet: CalendarSheet, day: Date) -> some View {
        let allowsPeek = calendarDayCourses.count > 1
        let peekMin: CGFloat = allowsPeek ? 24 : 0
        let cardH: CGFloat = 220
        let scaleExtra = (Theme.Layout.carouselDepthScaleCenter - 1) * cardH / 2
        let vPad = Theme.Layout.carouselDepthYOffsetMax + scaleExtra + Theme.Layout.carouselVPad
        let slotHeight = cardH + 2 * vPad
        let carouselSpacing: CGFloat = allowsPeek ? 32 : 0

        return GeometryReader { outer in
            let cardW = allowsPeek
                ? min(220, outer.size.width - (peekMin * 2))
                : min(220, max(0, outer.size.width - (PD.Spacing.screen * 2)))
            let sideInset = max(0, (outer.size.width - cardW) / 2)
            ScrollViewReader { proxy in
                TaikaCarouselScroll {
                    LazyHStack(spacing: carouselSpacing) {
                        ForEach(Array(calendarDayCourses.enumerated()), id: \.element.id) { idx, model in
                            GeometryReader { cellGeo in
                                let viewportCenterX = outer.size.width / 2
                                let cellCenterX = cellGeo.frame(in: .named("calendarOverlayCarousel")).midX
                                let dist = abs(cellCenterX - viewportCenterX)
                                let norm = allowsPeek
                                    ? min(1.0, dist / max(1.0, outer.size.width * Theme.Layout.carouselDepthNormWidthFactor))
                                    : 0
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
                .scrollDisabled(!allowsPeek)
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
    /// Deep link: вкладка Спикер + режим «Скажи сам» + сразу запись (мы же зовём говорить).
    private func openSpeakerConversationFromSandbox() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            overlay.dismiss()
        }
        SpeakerReturnContext.shared.clear()
        SpeakerManager.shared.setSpeakerUIMode(.conversation)
        SpeakerManager.shared.pendingConversationAutoRecord = true
        nav.popToRoot()
        nav.requestTab(2)
    }

    private func openCourse(_ courseId: String) {
        // prevent double pushes in the same frame (DailyPicks can fire multiple callbacks)
        guard !navPushInFlight else { return }
        if let c = CourseData.shared.course(with: courseId), c.isPro, !pro.isPro {
            overlay.presentPro(reason: .lockedCourse, courseId: courseId)
            return
        }
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
        if let c = CourseData.shared.course(with: courseId), c.isPro, !pro.isPro {
            overlay.presentPro(reason: .lockedCourse, courseId: courseId)
            return
        }
        navPushInFlight = true

        // Открываем список уроков курса; целевой урок — через нотификацию (LessonsView подхватывает).
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
        StepData.shared.preload()
        let allCourses = LessonsData.shared.allCourses()
        // Раньше весь hay по steps.json собирался на main до detached — первый открытый поиск подвисал.
        // Собираем на MainActor, но периодически yield, чтобы анимация оверлея и клавиатура успевали.
        var stepHayByLessonId: [String: String] = [:]
        stepHayByLessonId.reserveCapacity(min(allCourses.reduce(0) { $0 + $1.lessons.count }, 256))
        var lessonYieldCounter = 0
        for c in allCourses {
            for l in c.lessons {
                let items = StepData.shared.items(for: l.lessonID)
                guard !items.isEmpty else { continue }
                let parts = items.map { item in
                    let f = StepData.shared.face(for: item)
                    return [f.titleRU, f.subtitleTH, f.phonetic]
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        .joined(separator: " ")
                }
                if !parts.isEmpty {
                    stepHayByLessonId[l.lessonID] = parts.joined(separator: " | ")
                }
                lessonYieldCounter += 1
                if lessonYieldCounter % 14 == 0 {
                    await Task.yield()
                }
            }
        }
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
                let courseHay = [
                    norm(c.courseTitle),
                    norm(c.courseDescription ?? ""),
                    norm(CourseData.shared.category(for: c.courseID) ?? "")
                ].joined(separator: " | ")
                courseEntries.append(.init(id: c.courseID, haystack: courseHay))
                for l in c.lessons {
                    let contentText = l.content.map { $0.text }.joined(separator: " ")
                    let outcomes = l.outcomes.joined(separator: " ")
                    let tags = l.tags.joined(separator: " ")
                    // Smart search: include prebuilt lesson card text from steps.json.
                    let stepText = stepHayByLessonId[l.lessonID] ?? ""
                    let hay = [
                        norm(l.title),
                        norm(l.subtitle),
                        norm(l.previewPhrase),
                        outcomes,
                        tags,
                        contentText,
                        stepText,
                        norm(c.courseTitle),
                        norm(CourseData.shared.category(for: c.courseID) ?? "")
                    ].joined(separator: " | ")
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
    @ObservedObject private var pro = ProManager.shared
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
            let hasCourseMatches = (!overlay.searchCourseIds.isEmpty || !searchViaLessonCourseIds().isEmpty)
            let hasLessonMatches = !overlay.searchLessonIds.isEmpty
            let hasAny = hasCourseMatches || hasLessonMatches
            TaikaRootVerticalScroll {
                VStack(alignment: .leading, spacing: 16) {
                    if hasLessonMatches {
                        Text("Уроки")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                            .kerning(0.5)
                        searchLessonsSection
                    }
                    if hasCourseMatches {
                        Text("Курсы")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                            .kerning(0.5)
                        searchCoursesSection
                    }
                    if !hasAny {
                        VStack(spacing: 12) {
                            Image("mascot.profile")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 92, height: 92)
                                .taikaMascotChrome()

                            Text("Ничего не нашли")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(CD.ColorToken.text)
                                .frame(maxWidth: .infinity, alignment: .center)

                            Text("Попробуй другое слово. Можно искать по фразам из уроков и по тексту карточек.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)

                            // Smart suggestions (one-tap queries)
                            let suggestions: [String] = [
                                "привет",
                                "спасибо",
                                "такси",
                                "еда",
                                "рынок",
                                "время"
                            ]
                            let suggestionColumns = [GridItem(.adaptive(minimum: 84), spacing: 8)]
                            LazyVGrid(columns: suggestionColumns, alignment: .center, spacing: 8) {
                                ForEach(suggestions, id: \.self) { s in
                                    Button {
                                        overlay.searchQuery = s
                                        isSearchFocused = true
                                    } label: {
                                        Text(s)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(CD.ColorToken.card.opacity(0.70))
                                            )
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .strokeBorder(AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.9)), lineWidth: 1.1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 2)

                            Button {
                                overlay.searchQuery = ""
                                isSearchFocused = true
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                                    .frame(width: 42, height: 36)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(CD.ColorToken.card.opacity(0.70))
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(AnyShapeStyle(ThemeManager.shared.currentAccentFill), lineWidth: 1.2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Очистить")
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
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
            ForEach(Array(hits.prefix(6)), id: \.id) { hit in
                Button {
                    dismissSearch()
                    nav.popToRoot()
                    nav.go(.lesson(courseId: hit.courseId, lessonId: hit.lessonId, presentation: .canonical))
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

        // stable unique order: direct matches first, then courses with lesson matches
        var seen: Set<String> = []
        var combined: [String] = []
        for id in directCourseIds { if seen.insert(id).inserted { combined.append(id) } }
        for id in viaLessonCourseIds { if seen.insert(id).inserted { combined.append(id) } }
        let ids = Array(combined.prefix(6))

        if ids.isEmpty {
            return AnyView(Text("ничего не найдено").font(.system(size: 13)).foregroundStyle(Color.white.opacity(0.62)))
        }

        return AnyView(
            TaikaCarouselScroll {
                LazyHStack(spacing: 12) {
                    ForEach(ids, id: \.self) { courseId in
                        if let c = searchState.searchCourseById[courseId] {
                            let p = ProgressManager.shared.progress(for: c.courseID, lessonId: nil)
                            let progress = max(0, min(1, p))
                            let subtitleOverride: String? = {
                                guard let course = CourseData.shared.course(with: c.courseID) else { return nil }
                                let tags = course.learningOutcomes.map(\.type).filter { !$0.isEmpty }
                                if !tags.isEmpty {
                                    return Array(tags.prefix(2)).joined(separator: " • ")
                                }
                                return nil
                            }()
                            MainView._SearchCourseCard(
                                course: c,
                                progress: progress,
                                subtitleOverride: subtitleOverride,
                                onTap: {
                                    dismissSearch()
                                    nav.popToRoot()
                                    if let course = CourseData.shared.course(with: c.courseID), course.isPro, !pro.isPro {
                                        overlay.presentPro(reason: .lockedCourse, courseId: c.courseID)
                                        return
                                    }
                                    nav.go(.lessons(courseId: c.courseID))
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 324)
        )
    }

    private func dismissSearch() {
        isSearchFocused = false
        keyboardHeight = 0
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { overlay.dismiss() }
    }
}

#Preview {
    MainView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(MainManager.shared)
        .environmentObject(OverlayPresenter.shared)
        .environmentObject(NavigationIntent())
}
