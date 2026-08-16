//
//  CourseView.swift
//  taika
//
//  Created by product on 24.08.2025.
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Temporary loader (will be swapped to CourseData once final)
private enum _JSONLoader {
    static func courses(from resource: String) -> [Course] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Course].self, from: data)
        } catch {
            return []
        }
    }
}

private enum PersistedCourseCarousel {
    case none
    case base
    case all([Course])
}

// MARK: - View
struct CourseView: View {

    // Data facade
    private let courseData = CourseData()
    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent
    @StateObject private var favs = FavoriteManager.shared
    @StateObject private var personalPack = PersonalPackManager.shared
    @ObservedObject private var userSession = UserSession.shared
    private let lessonsManager = LessonsManager.shared
    private let pro = ProManager.shared

    private func isFavorite(_ c: Course) -> Bool {
        favs.items.contains { $0.id == "course:\(c.id)" }
    }
    private func toggleFavorite(_ c: Course) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            FavoriteManager.shared.toggle(item: c)
        }
    }

    private func handleTapCourse(_ c: Course, persistCarousel: PersistedCourseCarousel = .none) {
        // debug: trace taps / routing
        #if DEBUG
        print("[CourseView] tap course id=\(c.id) title=\(c.title) isPro=\(c.isPro) proUser=\(pro.isPro)")
        #endif

        switch persistCarousel {
        case .base:
            if let idx = filteredBasa.firstIndex(where: { $0.id == c.id }) {
                CarouselScrollPersistence.setBaseIndex(idx)
            }
        case .all(let rows):
            if let idx = rows.firstIndex(where: { $0.id == c.id }) {
                CarouselScrollPersistence.setAllCoursesIndex(idx)
            }
        case .none:
            break
        }

        // gate: free user taps PRO course
        if c.isPro && !pro.isPro {
            #if DEBUG
            print("[CourseView] -> PAYWALL courseId=\(c.id)")
            #endif
            overlay.presentPro(reason: .lockedCourse, courseId: c.id)
            #if os(iOS)
            let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.warning)
            #endif
            return
        }

        #if DEBUG
        print("[CourseView] markActive courseId=\(c.id)")
        #endif
        UserSession.shared.markActive(courseId: c.id)

        #if DEBUG
        print("[CourseView] nav.go -> .lessons(courseId: \(c.id))")
        #endif
        // navigate to lessons (single source of truth: NavigationIntent)
        nav.go(.lessons(courseId: c.id))
    }

    // NOTE: replace these two lines with calls to CourseData when ready
    @State private var all: [Course]  = _JSONLoader.courses(from: "taika_basa_course") // demo: single JSON for now
    private var basa: [Course] {
        // "База от Тайки" живёт в этой же выборке; остальные пойдут в "Курсы"
        var b: [Course] = []
        for c in all where c.category == "База от Тайки" { b.append(c) }
        return b
    }
    private var other: [Course] {
        deduplicateByID(all.filter { $0.category != "База от Тайки" })
    }

    // EPIC 2: search in header overlay; tabs replace filters on Course screen
    @State private var sortActive: Bool = false
    /// Кэш: `loadAll()` декодит UserDefaults на каждый проход `body` — при скролле курса даёт джанк.
    @State private var speakerAttemptsSnapshot: [String: SpeakerAttemptResult] = SpeakerAttemptsStore.loadAll()
    private struct _SelectedCourse: Identifiable { let id: String }
    @State private var selectedCourse: _SelectedCourse? = nil

    // Game mode state for course-level flow
    @State private var showGameModePicker: Bool = false
    @State private var selectedGameMode: GameModeType = .match
    @State private var pendingGameCourseId: String? = nil
    @State private var selectedCourseTab: CourseScreenTab = CourseCatalogTabState.shared.selectedTab
    @ObservedObject private var catalogTabState = CourseCatalogTabState.shared
    /// Активная категория на вкладке «Сценарии» (один ряд карточек).
    @State private var selectedScenarioCategory: String = ""

    // Search state (UI only; logic delegated to CourseSearch)
    @State private var isSearchExpanded: Bool = true
    @State private var searchText: String = ""
    // Debounced query to avoid recomputing on every keystroke
    @State private var debouncedQuery: String = ""
    @State private var debounceWork: DispatchWorkItem?
    // expanded state per category (collapsed by default)
    @State private var expandedCategories: [String: Bool] = [:]
    // visible items per category (for smooth incremental reveal)
    @State private var visibleCountByCategory: [String: Int] = [:]
    // Controls only the visibility of the input field (section stays open)
    @State private var isSearchFieldVisible: Bool = false
    // category to scroll to when expanded
    @State private var scrollToCategory: String? = nil

    // Keyboard
    @State private var kbHeight: CGFloat = 0
    // Detect Xcode Previews to avoid side-effects in Canvas
    private var isPreviewEnv: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }


    // Known order for scenario categories
    private let knownCategories: [String] = ["Тайский для жизни", "На одной волне", "Тайский для души"]

    private var safeBottomInset: CGFloat {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0
        #else
        return 0
        #endif
    }
    private var bottomContentInset: CGFloat {
        max(Theme.Layout.bottomInsetMin, safeBottomInset + Theme.Layout.bottomToolbarHeight)
    }

    // MARK: - Keyboard observers
    private func installKeyboardObservers() {
        #if os(iOS)
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { note in
            guard
                let info = note.userInfo,
                let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)
            else { return }
            let screenH = UIScreen.main.bounds.height
            let height = max(0, screenH - endFrame.origin.y)
            withAnimation(.easeInOut(duration: 0.2)) { kbHeight = height }
        }
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { kbHeight = 0 }
        }
        #endif
    }

    // MARK: - Search helpers

    // Generic stable dedupe by String key
    private func stableUnique<T>(_ items: [T], key: (T) -> String) -> [T] {
        var seen = Set<String>()
        var result: [T] = []
        result.reserveCapacity(items.count)
        for x in items {
            let k = key(x)
            if seen.insert(k).inserted { result.append(x) }
        }
        return result
    }

    // Convenience: dedupe courses by textual fingerprint (title + description) – preserves order
    private func deduplicateByText(_ items: [Course]) -> [Course] {
        stableUnique(items) { "\($0.title)|\($0.description)" }
    }

    // Convenience: dedupe courses by id – preserves order
    private func deduplicateByID(_ items: [Course]) -> [Course] {
        stableUnique(items) { $0.id }
    }

    /// Perf: pre-aggregate pronunciation scores once per render pass instead of
    /// filtering all attempts for every course card.
    private func pronunciationMaps(
        from attempts: [String: SpeakerAttemptResult],
        includeAdvanced: Bool
    ) -> (heard: [String: Int], advanced: [String: Int]) {
        var heardBuckets: [String: (sum: Int, count: Int)] = [:]
        var advancedBuckets: [String: (sum: Int, count: Int)] = [:]

        for attempt in attempts.values {
            let canonicalCourseId = ProgressManager.shared.canonicalize(attempt.courseId)
            if attempt.heardConfidence > 0 {
                let prev = heardBuckets[canonicalCourseId] ?? (0, 0)
                heardBuckets[canonicalCourseId] = (prev.sum + attempt.heardConfidence, prev.count + 1)
            }
            if includeAdvanced, let score = attempt.advancedScore {
                let prev = advancedBuckets[canonicalCourseId] ?? (0, 0)
                advancedBuckets[canonicalCourseId] = (prev.sum + score, prev.count + 1)
            }
        }

        let heard = heardBuckets.reduce(into: [String: Int]()) { out, entry in
            let (sum, count) = entry.value
            guard count > 0 else { return }
            out[entry.key] = max(0, min(100, Int((Double(sum) / Double(count)).rounded())))
        }
        let advanced = advancedBuckets.reduce(into: [String: Int]()) { out, entry in
            let (sum, count) = entry.value
            guard count > 0 else { return }
            out[entry.key] = max(0, min(100, Int((Double(sum) / Double(count)).rounded())))
        }
        return (heard: heard, advanced: advanced)
    }

    // Normalizes a title into a stable slug (case/space/punctuation insensitive)
    private func titleSlug(_ t: String) -> String {
        let lowered = t.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " ".unicodeScalars.first! }
        let cleaned = String(String.UnicodeScalarView(allowed))
        let singleSpaced = cleaned.split{ $0.isWhitespace }.joined(separator: " ")
        return singleSpaced.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Dedupe by normalized title (best-effort collapse of same-named courses from different JSON entries)
    private func deduplicateByTitle(_ items: [Course]) -> [Course] {
        stableUnique(items) { titleSlug($0.title) }
    }

    /// Поиск по курсам и урокам: по названию курса или по названию любого урока в курсе. Ищет во всех курсах (База + остальные).
    private func searchIDs(for query: String) -> Set<String> {
        let q = titleSlug(query)
        guard !q.isEmpty else { return Set(all.map { $0.id }) }
        var ids: Set<String> = []
        let lessonsData = LessonsData.shared
        for c in all {
            let courseSlug = titleSlug(c.title)
            if courseSlug.contains(q) {
                ids.insert(c.id)
                continue
            }
            for lesson in lessonsData.lessons(for: c.id) {
                let lessonTitle = LessonsManager.shared.lessonTitle(for: lesson.lessonID)
                if titleSlug(lessonTitle).contains(q) {
                    ids.insert(c.id)
                    break
                }
            }
        }
        return ids
    }

    /// База без фильтра по поиску (поиск только в оверлее).
    private var filteredBasa: [Course] {
        basa
    }
    private var filteredCourses: [Course] {
        deduplicateByText(other)
    }


    /// Курсы каталога, которые пользователь уже начал или добавил в избранное.
    private func inProgressCourses(in pool: [Course]) -> [Course] {
        let started = pool.filter { c in
            if isFavorite(c) { return true }
            let (done, _) = lessonsManager.headerCounts(for: c.id, lessonsTotal: c.lessonCount)
            return done > 0
        }
        return deduplicateByText(started)
    }


    private var scenarioCategoriesOrdered: [String] {
        let cats = Set(filteredCourses.map(\.category))
        let head = knownCategories.filter { cats.contains($0) }
        let tail = cats.subtracting(Set(knownCategories)).sorted()
        return head + tail
    }

    private func mapCourseItems(
        from courses: [Course],
        persistCarousel: PersistedCourseCarousel = .none
    ) -> [CDCourseItem] {
        let speakerAttemptsAll = speakerAttemptsSnapshot
        let pronunciation = pronunciationMaps(from: speakerAttemptsAll, includeAdvanced: pro.isPro)
        return courses.map { c in
            let isTheoryBonus = courseExperienceKind(for: c.id) == .theoryBonus
            let (done, total) = lessonsManager.headerCounts(for: c.id, lessonsTotal: c.lessonCount)
            let courseCompleted = total > 0 && done >= total
            let courseProgress = lessonsManager.coursePercent(for: c.id)
            let canonCourseId = ProgressManager.shared.canonicalize(c.id)
            let pronunciationPercent: Int? = pronunciation.heard[canonCourseId]
            let pronunciationAdvancedPercent: Int? = pro.isPro ? pronunciation.advanced[canonCourseId] : nil
            let sanitizedDescription = c.description
                .replacingOccurrences(of: "[[", with: "")
                .replacingOccurrences(of: "]]", with: "")
            let subtitleResolved: String = {
                if isTheoryBonus {
                    let hint = "Бонус · только теория"
                    return sanitizedDescription.isEmpty ? hint : "\(hint)\n\(sanitizedDescription)"
                }
                return sanitizedDescription
            }()
            return CDCourseItem(
                id: stableUUID(c.id),
                title: c.title,
                subtitle: subtitleResolved,
                category: c.category,
                lessons: c.lessonCount,
                durationMin: c.durationMinutes,
                cta: done == 0 ? "Начать" : (done < total ? "Продолжить" : "Повторить"),
                isPro: c.isPro,
                showProCrown: c.isPro && !pro.isPro,
                status: done == 0 ? .new : (done < total ? .inProgress : .done),
                progress: courseProgress,
                statusStarsFraction: nil,
                pronunciationPercent: pro.isPro ? (pronunciationAdvancedPercent ?? pronunciationPercent) : pronunciationPercent,
                isProUser: pro.isPro,
                flipEnabled: courseCompleted && !isTheoryBonus,
                onBackSelectGameMode: (courseCompleted && !isTheoryBonus) ? { gameType in
                    nav.go(.game(courseId: c.id, lessonId: nil, gameType: gameType))
                } : nil,
                homeworkTotal: total,
                homeworkDone: done,
                isActive: false,
                onTap: { handleTapCourse(c, persistCarousel: persistCarousel) },
                isFavorite: isFavorite(c),
                onToggleFavorite: { toggleFavorite(c) },
                onTapConsole: isTheoryBonus ? nil : {
                    let cards = CourseManager.shared.cardsForGame(courseId: c.id)
                    guard !cards.isEmpty else {
#if os(iOS)
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
#endif
                        return
                    }
                    selectedGameMode = .match
                    pendingGameCourseId = c.id
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                        showGameModePicker = true
                    }
                },
                onTapSpeaker: isTheoryBonus ? nil : {
                    UserSession.shared.markActive(courseId: c.id)
                    NotificationCenter.default.post(name: Notification.Name("Step.progressDidChange"), object: nil)
                    SpeakerRequestedCourseId.shared.set(c.id)
                    nav.requestTab(2)
                },
                onTapInfo: { overlay.present(.courseInfoPreview(courseId: c.id)) },
                key: c.id
            )
        }
    }

    /// «Продолжить» только если есть начатые/избранные курсы — иначе новичок сразу в Базе.
    private var visibleCourseTabs: [CourseScreenTab] {
        if allCatalogInProgress.isEmpty {
            return CourseScreenTab.mvpTabs.filter { $0 != .resume }
        }
        return CourseScreenTab.mvpTabs
    }

    private func courseScreenHeaderView() -> some View {
        TaikaScreenPageTitle(title: "Курсы") {
            CDCourseTabBar(selection: $selectedCourseTab, tabs: visibleCourseTabs)
        }
        .padding(.top, 4)
    }

    private func ensureValidCourseTabSelection() {
        let tabs = visibleCourseTabs
        if !tabs.contains(selectedCourseTab) {
            selectedCourseTab = tabs.contains(.base) ? .base : (tabs.first ?? .base)
        }
    }

    @ViewBuilder
    private func courseTabContentView() -> some View {
        switch selectedCourseTab {
        case .resume:
            resumeTabContentView()
        case .base:
            baseTabContentView()
        case .scenarios:
            scenariosTabContentView()
        case .dictionary, .mine:
            // MVP: вкладки скрыты — редирект на Базу.
            baseTabContentView()
        }
    }

    private var allCatalogInProgress: [Course] {
        inProgressCourses(in: deduplicateByID(basa + other))
    }

    private func resumeTabContentView() -> some View {
        let courses = allCatalogInProgress
        let items = mapCourseItems(from: courses)
        // Пустой «Продолжить» не показываем — вкладка скрыта, selection уезжает на Базу.
        return Group {
            if items.isEmpty {
                Color.clear
                    .frame(height: 1)
                    .onAppear { ensureValidCourseTabSelection() }
            } else {
                CDAllCoursesSection(title: "В процессе", items: items, initialCarouselIndex: 0)
            }
        }
    }

    private func baseTabContentView() -> some View {
        baseSectionView()
    }

    private func dictionaryTabContentView() -> some View {
        dictionaryPhrasesView()
    }

    private func presentPersonalCourseCreate() {
        overlay.present(.personalCourseCreate)
    }

    private func personalLessonHeroView() -> some View {
        let isProUser = pro.isPro
        return Button {
#if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
            if isProUser {
                presentPersonalCourseCreate()
            } else {
                overlay.presentPro(reason: .personalPath)
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    if !isProUser {
                        CDProBadge()
                    }
                    Text("Урок из моих фраз")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(CD.ColorToken.text)
                    Text("Спикер → словарь → собери карточки и тренируй")
                        .font(CD.FontToken.caption(13))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .strokeBorder(
                            CD.ColorToken.textSecondary.opacity(0.28),
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "bookmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CD.ColorToken.card.opacity(0.5))
            )
            .padding(.horizontal, CD.Spacing.screen)
        }
        .buttonStyle(.plain)
    }

    private func mineTabContentView() -> some View {
        let packItems = personalPack.carouselItems()
        let dictCount = favs.smartSpeakerDictionaryCardsDTO.count
        let isProUser = pro.isPro

        return VStack(spacing: Theme.Layout.sectionGap) {
            if isProUser, !packItems.isEmpty {
                personalPackBuiltView(packItems: packItems)
            } else {
                personalLessonHeroView()
                if dictCount == 0 {
                    personalCourseEmptyHint(goToDictionary: true)
                } else if isProUser {
                    personalCourseEmptyHint(goToDictionary: false)
                }
            }
        }
    }

    private func scenariosTabContentView() -> some View {
        let categories = scenarioCategoriesOrdered
        return Group {
            if categories.isEmpty {
                courseEmptyState(
                    title: "Сценарии не нашлись",
                    subtitle: "Пока нет курсов в этой категории",
                    actionTitle: "К базе"
                ) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedCourseTab = .base
                    }
                }
            } else {
                let selected = resolvedScenarioCategory(in: categories)
                let rows = filteredCourses.filter { $0.category == selected }
                let items = mapCourseItems(from: rows)
                let selectedIndex = categories.firstIndex(of: selected) ?? 0

                CDAllCoursesSection(
                    title: selected,
                    items: items,
                    initialCarouselIndex: 0
                ) {
                    // Заголовок секции = полное имя сценария; в чипе только стрелка.
                    // В меню — те же полные названия (без «Жизнь / Волна»).
                    if categories.count > 1 {
                        AppInlineFilterPicker(
                            titles: categories,
                            selectedIndex: selectedIndex,
                            showsSelectedTitle: false
                        ) { index in
                            guard categories.indices.contains(index) else { return }
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                selectedScenarioCategory = categories[index]
                            }
                        }
                    }
                }
                .onAppear {
                    if selectedScenarioCategory.isEmpty || !categories.contains(selectedScenarioCategory) {
                        selectedScenarioCategory = selected
                    }
                }
                .onChange(of: categories) { _, newCats in
                    if selectedScenarioCategory.isEmpty || !newCats.contains(selectedScenarioCategory) {
                        selectedScenarioCategory = newCats.first ?? ""
                    }
                }
            }
        }
    }

    private func resolvedScenarioCategory(in categories: [String]) -> String {
        if categories.contains(selectedScenarioCategory) {
            return selectedScenarioCategory
        }
        return categories.first ?? ""
    }

    /// Курсы в скоупе текущего таба / выбранной категории сценариев.
    private func rhythmScopeCourseIds() -> Set<String> {
        switch selectedCourseTab {
        case .resume:
            return Set(allCatalogInProgress.map(\.id))
        case .base:
            return Set(filteredBasa.map(\.id))
        case .scenarios:
            let cats = scenarioCategoriesOrdered
            let selected = resolvedScenarioCategory(in: cats)
            return Set(filteredCourses.filter { $0.category == selected }.map(\.id))
        case .dictionary, .mine:
            return Set(filteredBasa.map(\.id))
        }
    }

    /// Прогресс за **текущую календарную неделю** (Bangkok), только реальное изучение (`stepLearned`).
    /// Раньше брали rolling 7 дней + `lessonOpened` → минуты прошлой недели «липли» в новую.
    private func weeklyRhythmModel() -> CDWeeklyRhythmModel {
        _ = userSession.snapshot.lastEventAt // observe session updates
        let scope = rhythmScopeCourseIds()
        guard !scope.isEmpty else { return .empty }

        var cal = UserSession.bangkokCal
        cal.firstWeekday = 2 // понедельник — как ожидает «эта неделя»
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let dayCount = max(1, (cal.dateComponents([.day], from: weekStart, to: today).day ?? 0) + 1)
        let dayKeys: [String] = (0..<dayCount).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return userSession.dayKey(for: day)
        }

        var lessonKeys = Set<String>()
        var words = 0
        var minutesFromLessons = 0

        func considerLesson(courseId: String, lessonId: String?) {
            guard let lessonId, !lessonId.isEmpty else { return }
            let key = "\(courseId)|\(lessonId)"
            guard !lessonKeys.contains(key) else { return }
            lessonKeys.insert(key)
            if let mins = LessonsData.shared.lesson(courseID: courseId, lessonID: lessonId)?.durationMinutes,
               mins > 0 {
                minutesFromLessons += mins
            } else {
                minutesFromLessons += 7
            }
        }

        for dayKey in dayKeys {
            let events = userSession.snapshot.activityLog[dayKey] ?? []
            for event in events {
                guard let courseId = event.courseId, scope.contains(courseId) else { continue }
                // Только выученные шаги — не считаем «открыл урок» как минуты учёбы.
                guard event.kind == .stepLearned else { continue }
                words += 1
                considerLesson(courseId: courseId, lessonId: event.lessonId)
            }
        }

        let model = CDWeeklyRhythmModel(
            lessons: lessonKeys.count,
            minutes: minutesFromLessons,
            words: words,
            minuteGoal: 45
        )

        return model
    }

    private func courseEmptyState(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 24)
            Image(systemName: "rectangle.stack")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.7))
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CD.ColorToken.text)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ThemeManager.shared.currentAccentFill)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 48)
            .padding(.top, 4)
            Spacer(minLength: 24)
        }
        .padding(.horizontal, CD.Spacing.screen)
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private func courseFmSection(for tab: CourseScreenTab) -> some View {
        // Без маскота и мелкого FM-бабла: печатающийся гайд по странице, как typewriter на Main.
        MDCyclingTypewriter(
            lines: courseGuideLines(for: tab),
            font: .system(size: 19, weight: .bold),
            holdSeconds: 2.4,
            charInterval: 0.032,
            minHeight: 48
        )
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .id("course-guide-\(tab.rawValue)")
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Подсказки по странице курсов")
    }

    /// Краткий туториал-навигатор по Course View (не «вайб-сообщения» FM).
    private func courseGuideLines(for tab: CourseScreenTab) -> [String] {
        switch tab {
        case .resume:
            return [
                "Продолжи с того места, где остановился",
                "Тап по карточке — сразу в урок",
                "Игра и спикер — иконки внизу карточки"
            ]
        case .base:
            return [
                "Листай курсы — свайп влево и вправо",
                "Сверху переключай База и Сценарии",
                "Начать — открыть курс одним тапом",
                "На карточке: избранное, игра и спикер"
            ]
        case .scenarios:
            return [
                "Сценарии — живые ситуации в Тае",
                "Выбери вайб и нажми Начать",
                "Закрепляй фразы в игре или спикере"
            ]
        case .dictionary, .mine:
            return [
                "Листай курсы — свайп влево и вправо",
                "Сверху переключай вкладки каталога"
            ]
        }
    }

    // EPIC 2: search moved to header; no courseSearchHeader in body

    // Helper for stable UUID from string
    private func stableUUID(_ s: String) -> UUID {
        var hasher = Hasher()
        hasher.combine(s)
        let h = hasher.finalize()
        // map Int hash to UUID bytes deterministically
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: h) { raw in
            for i in 0..<min(16, raw.count) { bytes[i] = raw[i] }
        }
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }


    private func dictionaryPhrasesView() -> some View {
        let cards = favs.smartSpeakerDictionaryCardsDTO
        let isProUser = pro.isPro

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text("СЛОВАРЬ")
                    .taikaSectionTitleStyle()
                if !isProUser {
                    CDProBadge()
                }
                Spacer(minLength: 8)
                if !cards.isEmpty {
                    Text("\(cards.count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, CD.Spacing.screen)

            if cards.isEmpty {
                Text("Пока пусто — скажи фразу в спикере и сохрани в словарь")
                    .font(CD.FontToken.body(14, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .padding(.horizontal, CD.Spacing.screen)

                courseOpenSpeakerButton()
                    .padding(.horizontal, CD.Spacing.screen)
            } else {
                VStack(spacing: 8) {
                    ForEach(cards) { dto in
                        courseDictionaryPhraseRow(dto)
                    }
                }
                .padding(.horizontal, CD.Spacing.screen)

                courseOpenSpeakerButton()
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.top, 4)

                // MVP: вкладка «Мои» / сборка урока скрыта.
            }
        }
    }

    private func courseOpenSpeakerButton() -> some View {
        Button {
#if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
            SpeakerManager.shared.setSpeakerUIMode(.conversation)
            nav.requestTab(2)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Открыть спикер")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(ThemeManager.shared.currentAccentFill)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ThemeManager.shared.currentAccentFill.opacity(0.55), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    private func courseDictionaryPhraseRow(_ dto: FDCardDTO) -> some View {
        let phonetic = dto.meta.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                if !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .lineLimit(1)
                }
                Text(dto.title.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .lineLimit(2)
                let thai = dto.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !thai.isEmpty {
                    Text(thai)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CD.ColorToken.text.opacity(0.88))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                let thai = dto.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !thai.isEmpty { StepAudio.shared.speakThai(thai) }
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(CD.ColorToken.chip))
                    .overlay(Circle().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CD.ColorToken.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
    }

    @ViewBuilder
    private func personalPackBuiltView(packItems: [SDStepItem]) -> some View {
        let learned = ProgressManager.shared.learnedSet(
            courseId: PersonalPackManager.courseId,
            lessonId: PersonalPackManager.lessonId
        )

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text("УРОК ИЗ МОИХ ФРАЗ")
                    .taikaSectionTitleStyle()
                Spacer(minLength: 8)
                Button {
                    presentPersonalCourseCreate()
#if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                } label: {
                    Text("собрать")
                        .taikaSubsectionStyle(accent: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, CD.Spacing.screen)

            Text(personalPack.sectionSubtitle(isPro: true))
                .font(CD.FontToken.body(14, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .padding(.horizontal, CD.Spacing.screen)

            VStack(spacing: 8) {
                ForEach(Array(packItems.enumerated()), id: \.element.id) { index, item in
                    coursePersonalPackPhraseRow(item: item, index: index, isLearned: learned.contains(index))
                }
            }
            .padding(.horizontal, CD.Spacing.screen)

            Button {
#if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                _ = personalPack.buildAndOpenLesson(nav: nav)
            } label: {
                Text("Начать урок")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ThemeManager.shared.currentAccentFill)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, CD.Spacing.screen)
        }
    }

    private func coursePersonalPackPhraseRow(item: SDStepItem, index: Int, isLearned: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                nav.go(.lesson(
                    courseId: PersonalPackManager.courseId,
                    lessonId: PersonalPackManager.lessonId,
                    presentation: .personalPack(startIndex: index)
                ))
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.subtitleTH)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                            .lineLimit(1)
                        Text(item.titleRU)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text)
                            .lineLimit(2)
                        if !item.phonetic.isEmpty {
                            Text(item.phonetic)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.72))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isLearned {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.55))
                    }
                }
            }
            .buttonStyle(.plain)

            Button {
                StepAudio.shared.speakThai(item.subtitleTH, stepItemId: item.id)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CD.ColorToken.stroke.opacity(0.45), lineWidth: 0.8)
        )
    }

    private func personalCourseEmptyHint(goToDictionary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(
                goToDictionary
                ? "Сначала добавь фразы из умного спикера (кнопка «в словарь» после перевода)"
                : "Нажми «Урок из моих фраз» выше — соберу карточки в урок"
            )
            .font(CD.FontToken.body(14, weight: .regular))
            .foregroundStyle(CD.ColorToken.textSecondary)
        }
        .padding(.horizontal, CD.Spacing.screen)
    }

    private func baseSectionView() -> some View {
        let items = mapCourseItems(from: filteredBasa, persistCarousel: .base)
        return CDBaseSection(
            title: "БАЗА",
            items: items,
            initialCarouselIndex: items.isEmpty ? nil : CarouselScrollPersistence.baseIndex(max: items.count),
            onTapItem: { item in
                item.onTap?()
            },
            onTapStart: {
                if let course = filteredBasa.first {
                    handleTapCourse(course, persistCarousel: .base)
                }
            }
        )
    }

    // Legacy: flat «все курсы» list (unused while tabs are active).
    private func coursesSectionView() -> some View {
        let visible = deduplicateByTitle(filteredCourses)
        let allItems = mapCourseItems(from: visible)
        return CDAllCoursesSection(
            items: allItems,
            initialCarouselIndex: allItems.isEmpty ? nil : 0
        )
    }

    /// Единая проверка завершения курса для unlock логики (модалка выбора игр + карточки).
    /// Сначала опираемся на headerCounts (done/total), затем на courseStatus по id-вариантам.
    private func isCourseCompletedForGames(_ rawCourseId: String) -> Bool {
        let ids = [rawCourseId, rawCourseId.replacingOccurrences(of: "_", with: "-"), rawCourseId.replacingOccurrences(of: "-", with: "_")]
        for cid in ids {
            let lessonsTotal = LessonsData.shared.lessons(for: cid).count
            let (done, total) = lessonsManager.headerCounts(for: cid, lessonsTotal: lessonsTotal)
            if total > 0 && done >= total { return true }
        }
        return ids.contains { lessonsManager.courseStatus(for: $0) == .completed }
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            let isPaywallPresented: Bool = {
                if let o = overlay.overlay {
                    if case .proCoursePaywall = o { return true }
                }
                return false
            }()
            let isInfoPreviewPresented: Bool = {
                if case .courseInfoPreview = overlay.overlay { return true }
                return false
            }()
            VStack(spacing: 0) {
                courseScreenHeaderView()

                courseFmSection(for: selectedCourseTab)
                    .fixedSize(horizontal: false, vertical: true)

                ScrollViewReader { proxy in
                    TaikaRootVerticalScroll {
                        // Компактный ритм секций: на Базе почти всё влезает без скролла;
                        // скролл оставляем страховкой для Сценариев / высоких экранов.
                        LazyVStack(spacing: max(14, Theme.Layout.sectionGap - 6)) {
                            courseTabContentView()
                            CDWeeklyRhythmSection(
                                model: weeklyRhythmModel(),
                                onStartMain: {
                                    TaikaProductDemoFlags.markCourseSeen()
                                    nav.go(.lessons(courseId: "course_b_0"))
                                },
                                onChooseScenario: {
                                    TaikaProductDemoFlags.markCourseSeen()
                                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                        selectedCourseTab = .scenarios
                                        catalogTabState.selectedTab = .scenarios
                                    }
                                }
                            )
                                .id("weekly-rhythm-\(selectedCourseTab.rawValue)-\(selectedScenarioCategory)")
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.bottom, bottomContentInset)
                    }
                    .environment(\.taikaRootHeaderClearance, 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .onAppear {
                        if let pending = catalogTabState.pendingTab {
                            selectedCourseTab = pending
                            catalogTabState.consumePending()
                        }
                        if selectedCourseTab == .mine || selectedCourseTab == .dictionary {
                            selectedCourseTab = allCatalogInProgress.isEmpty ? .base : .resume
                        }
                        ensureValidCourseTabSelection()
                        personalPack.bootstrapPackIfNeeded(isPro: pro.isPro)
                    }
                    .onChange(of: catalogTabState.pendingTab) { _, pending in
                        guard let pending else { return }
                        selectedCourseTab = pending
                        catalogTabState.consumePending()
                        ensureValidCourseTabSelection()
                    }
                    .onChange(of: selectedCourseTab) { _, tab in
                        catalogTabState.selectedTab = tab
                        if tab == .mine || tab == .dictionary {
                            selectedCourseTab = allCatalogInProgress.isEmpty ? .base : .resume
                        }
                        ensureValidCourseTabSelection()
                    }
                    .onChange(of: allCatalogInProgress.count) { _, _ in
                        ensureValidCourseTabSelection()
                    }
                    .onChange(of: scrollToCategory) { _, target in
                        guard let target else { return }
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        DispatchQueue.main.async { scrollToCategory = nil }
                    }
                }
            }
            .padding(.top, Theme.Layout.rootHeaderClearance)
            .allowsHitTesting(!(isPaywallPresented || showGameModePicker || isInfoPreviewPresented))

            if showGameModePicker {
                GameModePickerDS(
                    selected: $selectedGameMode,
                    isProUser: pro.isPro,
                    onStart: { _ in
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                            showGameModePicker = false
                        }
                        if let courseId = pendingGameCourseId {
                            nav.go(.game(courseId: courseId, lessonId: nil, gameType: selectedGameMode.rawValue))
                            pendingGameCourseId = nil
                        }
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                            showGameModePicker = false
                        }
                    },
                    onLockedTap: { mode in
                        if mode.isPro && !pro.isPro, let cid = pendingGameCourseId {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                                showGameModePicker = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                overlay.presentPro(reason: .games, courseId: cid)
                            }
                        } else {
#if os(iOS)
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.warning)
#endif
                        }
                    },
                    lockedModes: {
                        guard TaikaReleaseFlags.showGrandDialogue,
                              let cid = pendingGameCourseId else { return [] }
                        return isCourseCompletedForGames(cid) ? [] : [.grandDialogue]
                    }(),
                    modes: {
                        guard let cid = pendingGameCourseId else { return GameModeType.modesLessonAndPark }
                        return GameModeType.modesForCourseLauncher(courseCompleted: isCourseCompletedForGames(cid))
                    }()
                )
                .zIndex(3)
                .transition(.scale(scale: 0.98).combined(with: .opacity))
            }

            if isPaywallPresented {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                            overlay.dismiss()
                        }
                    }

                // Превью курса только по иконке инфо на карточке; корона открывает PROView в AppShell, здесь ничего не показываем.
            }

            if isInfoPreviewPresented {
                OverlayEtalonBackground(onDismiss: {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                        overlay.dismiss()
                    }
                })
                .zIndex(4)

                coursePreviewGlass
                    .zIndex(5)
                    .transition(.scale(scale: 0.98).combined(with: .opacity))
            }

        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ProgressDidChange"))) { _ in
            speakerAttemptsSnapshot = SpeakerAttemptsStore.loadAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AppResetAll"))) { _ in
            speakerAttemptsSnapshot = SpeakerAttemptsStore.loadAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("Step.progressDidChange"))) { _ in
            speakerAttemptsSnapshot = SpeakerAttemptsStore.loadAll()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: kbHeight)
        }
        .onAppear {
            if !isPreviewEnv { installKeyboardObservers() }
        }
    }


    @ViewBuilder
    private var coursePreviewGlass: some View {
        let courseId: String? = {
            guard let o = overlay.overlay else { return nil }
            if case let .courseInfoPreview(id) = o { return id }
            return nil
        }()
        if let cid = courseId {
            let course = CourseData.shared.course(with: cid) ?? all.first(where: { $0.id == cid })
            let lessons = lessonsManager.paywallPreviewLessons(for: cid)
            let isProLocked = (course?.isPro == true) && !pro.isPro
            CourseInfoPreviewGlass(
                course: course,
                lessons: lessons,
                isProLocked: isProLocked,
                onClose: {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) { overlay.dismiss() }
                },
                onOpenCourse: {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                        overlay.dismiss()
                        nav.go(.lessons(courseId: cid))
                    }
                },
                onOpenPro: {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                        overlay.presentPro(reason: .lockedCourse, courseId: cid)
                    }
                }
            )
        } else {
            EmptyView()
        }
    }
}

private struct CourseInfoPreviewGlass: View {
    var course: Course?
    var lessons: [LessonBundle]
    var isProLocked: Bool
    var onClose: () -> Void
    var onOpenCourse: () -> Void
    var onOpenPro: () -> Void

    private var subtitleText: String {
        let raw = (course?.description ?? "")
            .replacingOccurrences(of: "[[", with: "")
            .replacingOccurrences(of: "]]", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let limit = 160
        if raw.count <= limit { return raw }
        let i = raw.index(raw.startIndex, offsetBy: limit)
        return String(raw[..<i]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    var body: some View {
        let title = (course?.title ?? "Курс").trimmingCharacters(in: .whitespacesAndNewlines)
        let items = lessons.sorted { $0.order < $1.order }

        return OverlayEtalonCard(title: "О курсе", onDismiss: onClose) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(PD.FontToken.title(22, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                    if isProLocked {
                        CDProBadge(style: .locked)
                            .padding(.top, 2)
                    }
                }

                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(PD.FontToken.body(14, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.94))
                        .lineLimit(4)
                        .lineSpacing(1.5)
                }

                if !items.isEmpty {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        Text("Фразы из уроков")
                            .font(PD.FontToken.caption(12, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                    }
                    .padding(.top, 2)

                    TaikaCarouselScroll {
                        HStack(spacing: 12) {
                            ForEach(items.prefix(8)) { l in
                                CourseInfoMiniPhraseCard(
                                    lessonTitle: l.title,
                                    phrase: l.previewPrimary,
                                    phonetic: l.previewSecondary,
                                    meta: l.outcomes.first ?? ""
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                    .frame(height: Theme.Layout.paywallCarouselHeight)
                }

                OverlayEtalonPrimaryButton(
                    title: isProLocked ? "Открыть с Taika+" : "Открыть курс",
                    action: isProLocked ? onOpenPro : onOpenCourse
                )
                    .padding(.top, 6)
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, Theme.Layout.paywallInnerHPad)
        .padding(.vertical, Theme.Layout.paywallInnerVPad)
    }
}

private struct CourseInfoMiniPhraseCard: View {
    let lessonTitle: String
    let phrase: String
    let phonetic: String
    let meta: String

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("taikA")
                    .font(.custom("ONMARK Trial", size: 14))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.text)
                Spacer(minLength: 6)
            }

            Spacer(minLength: 0)

            // Mirror Speaker/Favorites mini card rhythm: accent translit + RU phrase + subtle meta.
            VStack(alignment: .center, spacing: 8) {
                if !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Text(phrase)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if !meta.isEmpty {
                    Text(meta)
                        .font(.footnote)
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .opacity(0.86)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }

            Spacer(minLength: 0)

            HStack {
                if !lessonTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(lessonTitle)
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
                    .allowsHitTesting(false)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(width: 268, height: 196, alignment: .topLeading)
        .background(Theme.Surfaces.card(round))
    }
}

private struct ProCoursePaywallGlass: View {
    var course: Course?
    var lessons: [LessonBundle]
    var onClose: () -> Void
    var onOpenPro: () -> Void
    /// Когда задан — показываем «Открыть курс» и переходим в уроки; иначе «открыть pro».
    var onOpenCourse: (() -> Void)? = nil

    var body: some View {
        let title = course?.title ?? "этот курс"
        let subtitleRaw = (course?.description ?? "")
            .replacingOccurrences(of: "[[", with: "")
            .replacingOccurrences(of: "]]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // paywall: keep header stable even for long descriptions
        let subtitle: String = {
            let s = subtitleRaw
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
            let limit = 140
            if s.count <= limit { return s }
            let i = s.index(s.startIndex, offsetBy: limit)
            return String(s[..<i]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }()

        // preview carousel (steps)
        let items = lessons.sorted { $0.order < $1.order }

        // header slots should reflect the course size even if user can’t open it
        let slotsCount = max(course?.lessonCount ?? 0, 0)
        let placeholderSlots = Array(repeating: 0.0, count: slotsCount)

        // layout tokens (unified via theme.layout)
        let hPad: CGFloat = Theme.Layout.paywallHPad
        let chromeReserve: CGFloat = Theme.Layout.paywallChromeReserve
        let minSectionGap: CGFloat = Theme.Layout.paywallMinSectionGap
        let bottomInset: CGFloat = Theme.Layout.paywallBottomInset
        let carouselHeight: CGFloat = Theme.Layout.paywallCarouselHeight

        return AppProFrameChrome(
            cornerRadius: 26,
            strokeWidth: 0,
            inset: hPad,
            topLeft: AnyView(EmptyView()),
            topRight: AnyView(
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .padding(10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            )
        ) {
            // non-scroll layout: distribute remaining space so gaps don’t collapse
            let paywallBodyFit = VStack(spacing: 0) {
                LSLessonHeader(
                    title: title,
                    subtitle: subtitle,
                    progressSlots: placeholderSlots,
                    selectedIndex: nil,
                    onTapSlot: { _ in }
                )
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

                Spacer(minLength: minSectionGap)

                if !items.isEmpty {
                    TaikaCarouselScroll {
                        HStack(spacing: 12) {
                            ForEach(items) { l in
                                NoteStepCard(
                                    label: l.title,
                                    wordTitle: l.previewPrimary,
                                    accentSubtitle: l.previewSecondary,
                                    meta: l.outcomes.first ?? "",
                                    showsProBadge: false
                                )
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                    }
                    .frame(height: carouselHeight)
                }

                Spacer(minLength: minSectionGap)

                Button(action: onOpenCourse ?? onOpenPro) {
                    Text(onOpenCourse != nil ? "Открыть курс" : "открыть pro")
                        .font(PD.FontToken.body(16, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ThemeManager.shared.currentAccentFill)
                        .clipShape(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                        )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.top, chromeReserve)
            .padding(.horizontal, hPad)
            .padding(.bottom, bottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // scroll layout: no Spacer() so the scroll content height is natural
            let paywallBodyScroll = VStack(spacing: minSectionGap) {
                LSLessonHeader(
                    title: title,
                    subtitle: subtitle,
                    progressSlots: placeholderSlots,
                    selectedIndex: nil,
                    onTapSlot: { _ in }
                )
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

                if !items.isEmpty {
                    TaikaCarouselScroll {
                        HStack(spacing: 12) {
                            ForEach(items) { l in
                                NoteStepCard(
                                    label: l.title,
                                    wordTitle: l.previewPrimary,
                                    accentSubtitle: l.previewSecondary,
                                    meta: l.outcomes.first ?? "",
                                    showsProBadge: false
                                )
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                    }
                    .frame(height: carouselHeight)
                }

                Button(action: onOpenCourse ?? onOpenPro) {
                    Text(onOpenCourse != nil ? "Открыть курс" : "открыть pro")
                        .font(PD.FontToken.body(16, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(ThemeManager.shared.currentAccentFill)
                        .clipShape(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, chromeReserve)
            .padding(.horizontal, hPad)
            .padding(.bottom, bottomInset)
            .frame(maxWidth: .infinity, alignment: .top)

            ViewThatFits(in: .vertical) {
                paywallBodyFit
                TaikaRootVerticalScroll {
                    paywallBodyScroll
                }
            }
        }
        .frame(
            height: items.isEmpty ? Theme.Layout.paywallCardHeightEmpty : Theme.Layout.paywallCardHeightFull,
            alignment: .top
        )
        .clipped()
        .shadow(color: Color.black.opacity(0.55), radius: 22, x: 0, y: 14)
        .frame(maxWidth: 420)
        .padding(.horizontal, Theme.Layout.paywallInnerHPad)
        .padding(.vertical, Theme.Layout.paywallInnerVPad)
    }
}

#if true
// Deduplicate array while preserving order
private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return self.filter { seen.insert($0).inserted }
    }
}
#endif


// MARK: - Preview
#Preview("CourseView") {
    CourseView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(OverlayPresenter.shared)
        .environmentObject(NavigationIntent())
}


// MARK: - Favoritable conformance
extension Course: Favoritable {
    var favoriteId: String { "course:\(id)" }
    var favoriteTitle: String { title }
    var favoriteSubtitle: String {
        description
            .replacingOccurrences(of: "[[", with: "")
            .replacingOccurrences(of: "]]", with: "")
    }
    var favoriteMeta: String { "уроков: \(lessonCount) • ~\(durationMinutes) мин" }
    var favoriteCourseId: String { id }
    var favoriteLessonId: String { "" }
}


#if !DEBUG
#endif
