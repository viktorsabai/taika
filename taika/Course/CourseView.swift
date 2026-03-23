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

// MARK: - View
struct CourseView: View {

    // Data facade
    private let courseData = CourseData()
    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent
    @StateObject private var favs = FavoriteManager.shared
    @ObservedObject private var session = UserSession.shared
    @ObservedObject private var lessonsManager = LessonsManager.shared
    @ObservedObject private var pro = ProManager.shared

    private func isFavorite(_ c: Course) -> Bool {
        favs.items.contains { $0.id == "course:\(c.id)" }
    }
    private func toggleFavorite(_ c: Course) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            FavoriteManager.shared.toggle(item: c)
        }
    }

    private func handleTapCourse(_ c: Course) {
        // debug: trace taps / routing
        #if DEBUG
        print("[CourseView] tap course id=\(c.id) title=\(c.title) isPro=\(c.isPro) proUser=\(pro.isPro)")
        #endif

        // gate: free user taps PRO course
        if c.isPro && !pro.isPro {
            #if DEBUG
            print("[CourseView] -> PAYWALL courseId=\(c.id)")
            #endif
            overlay.present(.proCoursePaywall(courseId: c.id))
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

    // EPIC 2: filters state in shared object (header opens overlay; CourseView reads from it)
    @ObservedObject private var courseFilters = CourseFiltersState.shared
    @State private var sortActive: Bool = false
    // forces recomputation of progress-dependent UI (used on reset / progress changes)
    @State private var progressReloadToken: UUID = UUID()
    private struct _SelectedCourse: Identifiable { let id: String }
    @State private var selectedCourse: _SelectedCourse? = nil

    // Game mode state for course-level flow
    @State private var showGameModePicker: Bool = false
    @State private var selectedGameMode: GameModeType = .match
    @State private var pendingGameCourseId: String? = nil


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


    // базовые фильтры
    private let primaryChips: [String]   = ["Новый", "В процессе", "Завершено"]
    private let secondaryChips: [String] = ["Free", "Pro"]

    // Known order for categories, others will follow alphabetically
    private let knownCategories: [String] = ["Тайский для жизни", "На одной волне", "Тайский для души"]

    private var categoryChips: [String] {
        // preserve order of first occurrence
        var seen = Set<String>()
        var ordered: [String] = []
        for c in other.map({ $0.category }).filter({ $0 != "База от Тайки" }) {
            if seen.insert(c).inserted { ordered.append(c) }
        }
        let head = knownCategories.filter { ordered.contains($0) }
        let tail = ordered.filter { !knownCategories.contains($0) }.sorted()
        return head + tail
    }

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
        // Поиск только в оверлее; здесь — только фильтры по чипам
        let base: [Course] = other

        // 2) Фильтр по доступу (Free/Pro)
        let accessFiltered: [Course] = {
            switch courseFilters.selectedSecondary {
            case 0: // Free
                return base.filter { !$0.isPro }
            case 1: // Pro
                return base.filter { $0.isPro }
            default:
                return base
            }
        }()

        // 3) Фильтр по категории (чипы "Категории")
        let catFiltered: [Course] = {
            guard courseFilters.selectedCategory >= 0, courseFilters.selectedCategory < categoryChips.count else { return accessFiltered }
            let cat = categoryChips[courseFilters.selectedCategory]
            return accessFiltered.filter { $0.category == cat }
        }()

        // 4) Фильтр по статусу курса (Новый / В процессе / Завершено)
        let statusFiltered: [Course] = {
            guard courseFilters.selectedPrimary >= 0 else { return catFiltered }
            return catFiltered.filter { c in
                let (done, total) = lessonsManager.headerCounts(for: c.id, lessonsTotal: c.lessonCount)
                switch courseFilters.selectedPrimary {
                case 0: // "Новый"
                    return done == 0
                case 1: // "В процессе"
                    return done > 0 && done < total
                case 2: // "Завершено"
                    return done >= total && total > 0
                default:
                    return true
                }
            }
        }()

        return deduplicateByText(statusFiltered)
    }

    
    private var marqueeSectionView: some View {
        CDMarqueeSection(
            title: "TAЙKA FM",
            messages: [],
            mascot: Image("mascot.course")
        )
        .frame(maxWidth: .infinity)
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


    private func baseSectionView() -> some View {
        // Маппим наши Course -> CDCourseItem для DS-компонента (с учётом поиска — filteredBasa)
        let items: [CDCourseItem] = filteredBasa.map { c in
            let (done, total) = lessonsManager.headerCounts(for: c.id, lessonsTotal: c.lessonCount)
            let courseProgress = lessonsManager.coursePercent(for: c.id)
            let sanitizedDescription = c.description
                .replacingOccurrences(of: "[[", with: "")
                .replacingOccurrences(of: "]]", with: "")
            return CDCourseItem(
                id: stableUUID(c.id),
                title: c.title,
                subtitle: sanitizedDescription,
                category: c.category,
                lessons: c.lessonCount,
                durationMin: c.durationMinutes,
                cta: done == 0 ? "Начать" : (done < total ? "Продолжить" : "Повторить"),
                isPro: c.isPro,
                status: done == 0 ? .new : (done < total ? .inProgress : .done),
                progress: courseProgress,
                homeworkTotal: total,
                homeworkDone: done,
                isActive: false,
                onTap: { handleTapCourse(c) },
                isFavorite: isFavorite(c),
                onToggleFavorite: { toggleFavorite(c) },
                onTapConsole: {
                    let cards = CourseManager.shared.cardsForGame(courseId: c.id)
                    guard !cards.isEmpty else {
                        #if os(iOS)
                        let gen = UINotificationFeedbackGenerator()
                        gen.notificationOccurred(.warning)
                        #endif
                        return
                    }

                    // reset mode to default for course-level training
                    selectedGameMode = .match
                    pendingGameCourseId = c.id
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                        showGameModePicker = true
                    }
                },
                onTapSpeaker: {
                    UserSession.shared.markActive(courseId: c.id)
                    NotificationCenter.default.post(name: Notification.Name("Step.progressDidChange"), object: nil)
                    SpeakerRequestedCourseId.shared.set(c.id)
                    nav.requestTab(2)
                },
                onTapInfo: { overlay.present(.courseInfoPreview(courseId: c.id)) },
                key: c.id
            )
        }

        return CDBaseSection(
            items: items,
            onTapItem: { item in
                #if DEBUG
                print("[CourseView] CDBaseSection.onTapItem -> id=\(item.key)")
                #endif
                // forward to the item's own navigation callback
                item.onTap?()
            },
            onTapStart: {
                #if DEBUG
                print("[CourseView] CDBaseSection.onTapStart")
                #endif
                if let course = filteredBasa.first {
                    handleTapCourse(course)
                }
            }
        )
    }

    private func coursesSectionView() -> some View {
        VStack(spacing: 0) {
            // EPIC 2: filters/categories moved to header overlay; only course list here
            // 4. ВСЕ КУРСЫ (DS)
            let visible = deduplicateByTitle(filteredCourses)
            let isFilteringActive = courseFilters.selectedPrimary != -1 || courseFilters.selectedSecondary != -1 || courseFilters.selectedCategory != -1
            let allItems: [CDCourseItem] = visible.map { c in
                let (done, total) = lessonsManager.headerCounts(for: c.id, lessonsTotal: c.lessonCount)
                let courseProgress = lessonsManager.coursePercent(for: c.id)
                let sanitizedDescription = c.description
                    .replacingOccurrences(of: "[[", with: "")
                    .replacingOccurrences(of: "]]", with: "")
                return CDCourseItem(
                    id: stableUUID(c.id),
                    title: c.title,
                    subtitle: sanitizedDescription,
                    category: c.category,
                    lessons: c.lessonCount,
                    durationMin: c.durationMinutes,
                    cta: done == 0 ? "Начать" : (done < total ? "Продолжить" : "Повторить"),
                    isPro: c.isPro,
                    status: done == 0 ? .new : (done < total ? .inProgress : .done),
                    progress: courseProgress,
                    homeworkTotal: total,
                    homeworkDone: done,
                    isActive: false,
                    onTap: { handleTapCourse(c) },
                    isFavorite: isFavorite(c),
                    onToggleFavorite: { toggleFavorite(c) },
                    onTapConsole: {
                        let cards = CourseManager.shared.cardsForGame(courseId: c.id)
                        guard !cards.isEmpty else {
                            #if os(iOS)
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.warning)
                            #endif
                            return
                        }

                        // reset mode to default for course-level training
                        selectedGameMode = .match
                        pendingGameCourseId = c.id
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                            showGameModePicker = true
                        }
                    },
                    onTapSpeaker: {
                        UserSession.shared.markActive(courseId: c.id)
                        NotificationCenter.default.post(name: Notification.Name("Step.progressDidChange"), object: nil)
                        SpeakerRequestedCourseId.shared.set(c.id)
                        nav.requestTab(2)
                    },
                    onTapInfo: { overlay.present(.courseInfoPreview(courseId: c.id)) },
                    key: c.id
                )
            }
            // NOTE: CDCourseItem does not expose favorite hook yet; use isFavorite/toggleFavorite if needed later.
            CDAllCoursesSection(items: allItems)

            // 5. Пустое состояние, когда поиск/фильтры не дали ни курсов из Базы, ни из списка
            if filteredBasa.isEmpty && visible.isEmpty && isFilteringActive {
                VStack(spacing: 14) {
                    Image("mascot.profile")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)

                    Text("Курсы не нашлись")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)

                    Text("Попробуй изменить запрос или сбросить фильтры каа")
                        .font(CD.FontToken.caption(14))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            searchText = ""
                            courseFilters.selectedPrimary = -1
                            courseFilters.selectedSecondary = -1
                            courseFilters.selectedCategory = -1
                        }
                    } label: {
                        Text("Сбросить фильтры")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(CD.ColorToken.accent.opacity(0.16))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: searchText) { _, text in
            // простой дебаунс без Combine
            debounceWork?.cancel()
            let work = DispatchWorkItem {
                debouncedQuery = text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    withAnimation(.easeInOut(duration: 0.2)) { isSearchFieldVisible = true }
                }
            }
            debounceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }
        .onDisappear {
            debounceWork?.cancel()
        }
        .onAppear {
            debouncedQuery = searchText
        }
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            let isPaywallPresented: Bool = {
                if let o = overlay.overlay {
                    if case .proCoursePaywall = o { return true }
                    if case .courseInfoPreview = o { return true }
                }
                return false
            }()
            /// Локальные blur/scale/opacity только для локального пикера и превью курса; при proCoursePaywall блюр уже на уровне AppShell.
            let contentBlurred: Bool = showGameModePicker || (overlay.overlay != nil && (overlay.overlay.map { if case .courseInfoPreview = $0 { return true }; return false } ?? false))

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: Theme.Layout.sectionGap) {
                            baseSectionView()
                            marqueeSectionView
                            coursesSectionView()
                        }
                        .padding(.bottom, bottomContentInset)
                    }
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: scrollToCategory) { _, target in
                        guard let target else { return }
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        DispatchQueue.main.async { scrollToCategory = nil }
                    }
                }
            }
            .id(progressReloadToken)
            .blur(radius: contentBlurred ? 10 : 0)
            .scaleEffect(contentBlurred ? 0.98 : 1)
            .opacity(contentBlurred ? 0.92 : 1)
            .allowsHitTesting(!(isPaywallPresented || showGameModePicker))
            .animation(.spring(response: 0.36, dampingFraction: 0.92), value: isPaywallPresented || showGameModePicker)

            if showGameModePicker {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .zIndex(2)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                            showGameModePicker = false
                        }
                    }

                GameModePickerDS(
                    selected: $selectedGameMode,
                    isProUser: pro.isPro,
                    onStart: { _ in
                        showGameModePicker = false
                        if let courseId = pendingGameCourseId {
                            nav.go(.game(courseId: courseId, lessonId: nil, gameType: selectedGameMode.rawValue))
                            pendingGameCourseId = nil
                        }
                    },
                    onClose: {
                        showGameModePicker = false
                    }
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
                if case .courseInfoPreview = overlay.overlay {
                    coursePreviewGlass
                        .transition(.scale(scale: 0.98).combined(with: .opacity))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ProgressDidChange"))) { _ in
            progressReloadToken = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AppResetAll"))) { _ in
            progressReloadToken = UUID()
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
            if case let .proCoursePaywall(id) = o { return id }
            if case let .courseInfoPreview(id) = o { return id }
            return nil
        }()
        let isInfoPreview: Bool = {
            if case .courseInfoPreview = overlay.overlay { return true }
            return false
        }()
        if let cid = courseId {
            ProCoursePaywallGlass(
                course: all.first(where: { $0.id == cid }),
                lessons: lessonsManager.paywallPreviewLessons(for: cid),
                onClose: {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) { overlay.dismiss() }
                },
                onOpenPro: {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) { overlay.dismiss() }
                },
                onOpenCourse: isInfoPreview ? {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.92)) {
                        overlay.dismiss()
                        nav.go(.lessons(courseId: cid))
                    }
                } : nil
            )
        } else {
            EmptyView()
        }
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
                    ScrollView(.horizontal, showsIndicators: false) {
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
                    .scrollIndicators(.hidden)
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
                    ScrollView(.horizontal, showsIndicators: false) {
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
                    .scrollIndicators(.hidden)
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
                ScrollView(.vertical, showsIndicators: false) {
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
        .preferredColorScheme(.dark)
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
