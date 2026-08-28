import SwiftUI
import UIKit

// MARK: - Perf profiling (Instruments)
// Шаблон проверки после правок шелла/табов: Time Profiler + SwiftUI template.
// Сценарии: (1) круговой перебор табов 0→4→0 без push; (2) открыть урок → «запомнил» несколько карточек → назад;
// (3) избранное: лайк/анлайк с открытым табом «Курсы». Смотреть body count у MainView/CourseView при неактивном табе.

/// Единственный источник правды для игрового хедера: когда не nil, AppShell рисует в своей полоске таймер/прогресс/попытки.
final class GameHeaderStore: ObservableObject {
    static let shared = GameHeaderStore()
    @Published var config: GameHeaderConfig?
    private init() {}
}

struct AppShell: View {
    @State private var selectedTab: Int = 0
    /// Показываем единый экран входа до первого «Начать» (персистится).
    @AppStorage("taika.welcome.seen.v1") private var welcomeSeen: Bool = false
    /// Value-онбординг + быстрый старт пройдены.
    @AppStorage("taika.onboarding.v2.done") private var onboardingDone: Bool = false
    /// Брендовый сплэш на каждом cold start → дальше Main (только returning).
    @State private var showBootSplash: Bool = true
    @State private var didStartDataPreload: Bool = false
    /// Фаза первого входа после Welcome.
    @State private var firstEntryPhase: FirstEntryPhase = .none
    @State private var pendingQuickStart: TaikaQuickStartAction? = nil

    private enum FirstEntryPhase: Equatable {
        case none
        case splash
        case learn
    }

    /// Hide chrome header while fullscreen park / reinforce overlays are up.
    private var showsShellHeaderChrome: Bool {
        guard welcomeSeen, onboardingDone, !showBootSplash, firstEntryPhase == .none else { return false }
        switch overlay.overlay {
        case .dictionaryQuickDrawer,
             .gamePark,
             .gameParkFromFavorites,
             .gameParkFromDictionary,
             .reinforcePick,
             .gameParkForCourse:
            return false
        default:
            return true
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == 2, selectedTab != 2 {
                    openSpeakerFromToolbarIfNeeded()
                }
                // Avoid extra spring-driven layout work on heavy root tabs.
                selectedTab = newValue
            }
        )
    }

    /// Тап по иконке Спикер в тулбаре → умный спикер, если нет контекста тренировки курса/избранного.
    private func openSpeakerFromToolbarIfNeeded() {
        let trainingIntent =
            speakerPendingCourseId != nil
            || SpeakerManager.shared.speakerContextCourseId != nil
            || SpeakerRequestedCourseId.shared.courseId != nil
        guard !trainingIntent else { return }
        if SpeakerManager.shared.speakerUIMode != .conversation {
            SpeakerManager.shared.setSpeakerUIMode(.conversation)
        }
    }

    @ObservedObject private var overlay = OverlayPresenter.shared
    @ObservedObject private var gameHeaderStore = GameHeaderStore.shared
    @EnvironmentObject private var nav: NavigationIntent
    /// When switching to Speaker tab from course card, pass consumed courseId so Speaker shows full course queue (onAppear may not run in time).
    @State private var speakerPendingCourseId: String? = nil
    @State private var speakerPendingLessonId: String? = nil
    @State private var speakerPendingLessonIds: [String]? = nil

    var body: some View {
        ZStack {
            if onboardingDone {
                TaikaContinuousCanvasBackground()
            } else {
                PD.ColorToken.background
                    .ignoresSafeArea()
            }

            // Вход:
            // • первый раз → единый splash внутри core loop → LessonsView стартового курса
            // • returning → короткий Splash → Main
            if !onboardingDone {
                TaikaCoreLoopOnboardingView(
                    onFinished: { courseId in
                        finishFirstEntry(with: .baseCourse, landingCourseId: courseId)
                    },
                    onRequestPro: {
                        // Paywall поверх offer; first-entry закрываем только через «Открыть первый урок».
                        DispatchQueue.main.async {
                            overlay.presentProDirect(reason: .general)
                        }
                    }
                )
                .transition(.opacity)
            } else if showBootSplash {
                SplashTaikaView {
                    withAnimation(.easeOut(duration: 0.28)) {
                        showBootSplash = false
                    }
                }
                .transition(.opacity)
            } else {
                mainShellContent
            }

            // Оверлеи на уровне шелла (EPIC 2: courseFilters, speakerFilters, voiceSettings, gamePark)
            if let o = overlay.overlay {
                switch o {
                case .search:
                    SearchOverlayView()
                case .speakerPaywall:
                    PROView(courseId: nil, reason: .speakerBreakdown) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.dismiss()
                        }
                    }
                case .proCoursePaywall(let courseId, let reason):
                    PROView(courseId: courseId.isEmpty ? nil : courseId, reason: reason) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.dismiss()
                        }
                    }
                case .speakerToneAha(let courseId, let reason, let fromSpeakerPaywall):
                    SpeakerToneAhaStepView(
                        courseId: courseId,
                        reason: reason,
                        fromSpeakerPaywall: fromSpeakerPaywall,
                        onDismissWithoutPaywall: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                overlay.dismiss()
                            }
                        }
                    )
                case .speakerFirstTip:
                    // Legacy tip removed — Speakers opens into product directly.
                    Color.clear
                        .onAppear {
                            TaikaProductDemoFlags.markSpeakerSeen()
                            overlay.dismiss()
                        }
                case .courseFirstTip:
                    // Legacy case: Course Hub demo removed.
                    Color.clear
                        .onAppear { overlay.dismiss() }
                case .courseFilters:
                    CourseFiltersOverlayView(onDismiss: { overlay.dismiss() })
                case .personalCourseCreate:
                    PersonalCourseCreateOverlayView(onDismiss: { overlay.dismiss() })
                case .courseSearchAndFilters:
                    CourseSearchAndFiltersOverlayView(onDismiss: { overlay.dismiss() })
                case .speakerFilters:
                    SpeakerFiltersOverlayView(onDismiss: { overlay.dismiss() })
                case .speakerCourses:
                    SpeakerCoursesOverlayView(onDismiss: { overlay.dismiss() })
                case .speakerAttempts:
                    SpeakerAttemptsOverlayView(onDismiss: { overlay.dismiss() })
                case .voiceSettings:
                    VoiceSettingsOverlayView(onDismiss: { overlay.dismiss() })
                case .gamePark:
                    GameParkOverlayView(
                        source: .main,
                        onDismiss: { overlay.dismiss() },
                        onOpenCourses: {
                            overlay.dismiss()
                            nav.popToRoot()
                            nav.requestTab(1)
                        }
                    )
                case .gameParkFromFavorites:
                    GameParkOverlayView(
                        source: .favorites,
                        onDismiss: { overlay.dismiss() },
                        onOpenCourses: {
                            overlay.dismiss()
                            nav.popToRoot()
                            nav.requestTab(1)
                        }
                    )
                case .gameParkFromDictionary:
                    GameParkOverlayView(
                        source: .dictionary,
                        onDismiss: { overlay.dismiss() },
                        onOpenCourses: {
                            overlay.dismiss()
                            nav.popToRoot()
                            nav.requestTab(1)
                        }
                    )
                case .reinforcePick:
                    ReinforcePickOverlayView(
                        courses: MainManager.shared.reinforcementCourseCards.map {
                            .init(
                                id: $0.courseId,
                                title: $0.title,
                                subtitle: $0.subtitle.isEmpty ? "Пройденный курс" : $0.subtitle
                            )
                        },
                        hasAllLearnedPool: LearnedGameSource.hasPlayableCards,
                        onDismiss: { overlay.dismiss() },
                        onStartGame: { courseId, mode in
                            nav.go(.game(
                                courseId: courseId,
                                lessonId: nil,
                                gameType: mode.rawValue
                            ))
                        },
                        onStartSpeaker: { courseId in
                            SpeakerReturnContext.shared.save(tab: selectedTab, path: nav.path)
                            if let courseId, !courseId.isEmpty {
                                SpeakerManager.shared.setSpeakerUIMode(.training)
                                SpeakerRequestedCourseId.shared.set(courseId)
                            } else {
                                SpeakerManager.shared.setSpeakerUIMode(.conversation)
                                SpeakerRequestedCourseId.shared.set(nil)
                            }
                            nav.requestTab(2)
                        },
                        onOpenCourses: {
                            overlay.dismiss()
                            nav.popToRoot()
                            nav.requestTab(1)
                        }
                    )
                case .gameParkForCourse(let courseId):
                    GameParkOverlayView(
                        source: .main,
                        courseId: courseId,
                        onDismiss: { overlay.dismiss() },
                        onOpenCourses: {
                            overlay.dismiss()
                            nav.popToRoot()
                            nav.requestTab(1)
                        }
                    )
                case .favoritesFilters:
                    FavoritesFiltersOverlayView(onDismiss: { overlay.dismiss() })
                case .favoritesSearch:
                    FavoritesSearchOverlayView(onDismiss: { overlay.dismiss() })
                case .dictionaryQuickDrawer:
                    DictionaryQuickDrawerView(
                        onDismiss: { overlay.dismiss() },
                        onOpenSpeaker: {
                            overlay.dismiss()
                            guard selectedTab != 2 else { return }
                            SpeakerManager.shared.setSpeakerUIMode(.conversation)
                            SpeakerReturnContext.shared.save(tab: selectedTab, path: nav.path)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                nav.popToRoot()
                                selectedTab = 2
                            }
                        },
                        onTrainInSpeaker: { selectedIds in
                            overlay.dismiss()
                            DictionarySessionSelection.shared.activate(selectedIds)
                            SpeakerManager.shared.setSpeakerUIMode(.training)
                            SpeakerRequestedCourseId.shared.set("__dictionary__")
                            SpeakerManager.shared.startSpecialTraining(poolId: "__dictionary__")
                            SpeakerReturnContext.shared.saveFromDictionary(tab: selectedTab)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                nav.popToRoot()
                                selectedTab = 2
                            }
                        }
                    )
                case .accentPicker:
                    AccentPickerOverlayView(onDismiss: { overlay.dismiss() })
                case .courseResetConfirm(let courseId):
                    CourseResetConfirmOverlayView(courseId: courseId) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.dismiss()
                        }
                    }
                case .lessonResetConfirm(let courseId, let lessonId):
                    CourseResetConfirmOverlayView(courseId: courseId, lessonId: lessonId) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.dismiss()
                        }
                    }
                case .authSoftWall(let masteryPercent, let streakDays):
                    AuthSoftWallSheetHost(
                        masteryPercent: masteryPercent,
                        streakDays: streakDays,
                        onDismiss: { withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { overlay.dismiss() } }
                    )
                default:
                    EmptyView()
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: welcomeSeen)
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: firstEntryPhase)
        .animation(.easeOut(duration: 0.28), value: showBootSplash)
        .onAppear {
            migrateOnboardingFlagIfNeeded()
            if !onboardingDone, firstEntryPhase == .none {
                showBootSplash = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: TaikaProductDemoFlags.debugResetOnboardingNotification)) { _ in
            pendingQuickStart = nil
            showBootSplash = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                firstEntryPhase = .splash
                selectedTab = 0
            }
            nav.popToRoot()
        }
        .overlay(alignment: .top) {
            if showsShellHeaderChrome {
                ZStack(alignment: .top) {
                    // The transition layer is behind the header content and extends
                    // into the canvas without becoming an opaque page strip.
                    TaikaLiquidGlassHeaderBackdrop()
                        .frame(height: 124)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .opacity(0.84)
                        .allowsHitTesting(false)

                    ShellHeaderHost(
                        selectedTab: $selectedTab,
                        speakerPendingCourseId: $speakerPendingCourseId,
                        speakerPendingLessonId: $speakerPendingLessonId
                    )
                    .frame(maxWidth: .infinity)
                    .zIndex(1)
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environmentObject(ThemeManager.shared)
        .environmentObject(FavoriteManager.shared)
        .environmentObject(overlay)
        .environmentObject(ProManager.shared)
        .task(id: showBootSplash) {
            guard welcomeSeen, onboardingDone, showBootSplash, firstEntryPhase == .none else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if showBootSplash {
                withAnimation(.easeOut(duration: 0.28)) {
                    showBootSplash = false
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            ProManager.shared.start(session: UserSession.shared)
            await ProManager.shared.syncRevenueCatIdentity(userId: AuthService.shared.currentUserID)
            await ProManager.shared.syncCustomerInfoFromRevenueCat()
        }
        .onAppear {
            guard !didStartDataPreload else { return }
            didStartDataPreload = true
            Task.detached(priority: .utility) {
                StepData.shared.preload()
                LessonsData.shared.preload()
#if DEBUG
                await MainActor.run {
                    ProgressManager.shared.debugAuditProgressIfEnabled()
                }
#endif
            }
        }
    }

    /// Существующие пользователи с welcome.seen не гоняем через новый онбординг.
    private func migrateOnboardingFlagIfNeeded() {
        if welcomeSeen, UserDefaults.standard.object(forKey: "taika.onboarding.v2.done") == nil {
            onboardingDone = true
        }
        migrateProductDemoFlagsIfNeeded()
    }

    /// Один раз: у тех, кто уже прошёл онбординг до product-demo, не форсим first-visit туры.
    private func migrateProductDemoFlagsIfNeeded() {
        let key = "taika.demo.flags.migrated.v1"
        guard UserDefaults.standard.object(forKey: key) == nil else { return }
        UserDefaults.standard.set(true, forKey: key)
        if onboardingDone {
            TaikaProductDemoFlags.markSpeakerSeen()
            TaikaProductDemoFlags.markCourseSeen()
        }
    }

    private func finishFirstEntry(with action: TaikaQuickStartAction, landingCourseId: String = "course_b_1") {
        pendingQuickStart = nil
        welcomeSeen = true
        onboardingDone = true
        showBootSplash = false

        switch action {
        case .baseCourse:
            let cid = landingCourseId.isEmpty ? "course_b_1" : landingCourseId
            UserSession.shared.markActive(courseId: cid)
            selectedTab = 1
            nav.path = [.lessons(courseId: cid)]
            withAnimation(.easeOut(duration: 0.32)) {
                firstEntryPhase = .none
            }
        case .speakerVoice:
            SpeakerManager.shared.setSpeakerUIMode(.conversation)
            SpeakerReturnContext.shared.clear()
            selectedTab = 2
            withAnimation(.easeOut(duration: 0.32)) {
                firstEntryPhase = .none
            }
        case .catalog:
            selectedTab = 1
            withAnimation(.easeOut(duration: 0.32)) {
                firstEntryPhase = .none
            }
            DispatchQueue.main.async {
                nav.openCourseCatalog(tab: .base)
            }
        }
    }

    @ViewBuilder
    private var mainShellContent: some View {
        NavigationStack(path: $nav.path) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationDestination(for: NavigationIntent.Route.self) { route in
                    switch route {

                    case .course:
                        CourseView()

                    case let .lessons(courseId):
                        LessonsView(courseId: courseId)

                    case let .lesson(courseId, lessonId, presentation):
                        StepView(
                            courseId: courseId,
                            lessonId: lessonId,
                            lessonTitle: LessonsData.shared.lessonTitle(for: lessonId),
                            startIndex: presentation.startIndex,
                            scope: presentation.scope,
                            showKinds: presentation.showKinds,
                            layoutCardsOnly: presentation.layoutCardsOnly,
                            allowLearning: presentation.allowLearning,
                            showBottomProgress: presentation.showBottomProgress,
                            showInternalHeader: presentation.showInternalHeader,
                            useInternalBackground: presentation.useInternalBackground,
                            onBack: nil
                        )

                    case let .game(courseId, lessonId, gameType):
                        GameView(
                            courseId: courseId,
                            lessonId: lessonId,
                            lessonIds: GameRequestedCourseScope.shared.courseId == courseId ? GameRequestedCourseScope.shared.lessonIds : nil,
                            cardKeys: GameRequestedCourseScope.shared.courseId == courseId ? GameRequestedCourseScope.shared.cardKeys : nil,
                            gameType: gameType
                        )

                    case .dictionary:
                        DictionaryFullView(
                            onBack: { nav.popToRoot() },
                            onOpenSpeaker: {
                                SpeakerManager.shared.setSpeakerUIMode(.conversation)
                                SpeakerReturnContext.shared.save(tab: selectedTab, path: nav.path)
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    nav.popToRoot()
                                    selectedTab = 2
                                }
                            },
                            onNavigateToSpeaker: {
                                SpeakerReturnContext.shared.save(tab: selectedTab, path: nav.path)
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                    nav.popToRoot()
                                    selectedTab = 2
                                }
                            }
                        )

                    case let .favoritesAll(initialFilter):
                        Color.clear
                            .onAppear {
                                FavoritesFilterState.shared.selectedTab = FavoriteScreenTab(fdk: initialFilter)
                                nav.popToRoot()
                                nav.requestTab(3)
                            }
                    }
                }
        }
        .background {
            if selectedTab == 2 {
                TaikaContinuousCanvasBackground()
            } else {
                PD.ColorToken.background
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(
            \.taikaRootHeaderClearance,
            gameHeaderStore.config != nil
                ? Theme.Layout.rootHeaderClearanceGame
                : Theme.Layout.rootHeaderClearance
        )
        .overlay(alignment: .bottom) {
            if nav.path.isEmpty {
                ToolBar(selectedTab: tabSelection)
            }
        }
        .onChange(of: nav.requestedTab) { _, newValue in
            guard let tab = newValue, (0...4).contains(tab) else { return }
            if tab == 2 {
                if nav.path.isEmpty {
                    if !SpeakerReturnContext.shared.hasContext {
                        SpeakerReturnContext.shared.clear()
                    }
                } else {
                    SpeakerReturnContext.shared.save(tab: selectedTab, path: nav.path)
                }
                if let ctx = SpeakerRequestedCourseId.shared.consume() {
                    speakerPendingCourseId = ctx.courseId
                    speakerPendingLessonId = ctx.lessonId
                    speakerPendingLessonIds = ctx.lessonIds
                }
            }
            nav.popToRoot()
            selectedTab = tab
            nav.clearRequestedTab()
        }
        .onChange(of: nav.path) { _, newPath in
            let onGame = newPath.last.map { if case .game = $0 { return true }; return false } ?? false
            if !onGame, gameHeaderStore.config != nil {
                gameHeaderStore.config = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taikaOpenSmartSpeakerDictionary)) { _ in
            overlay.present(.dictionaryQuickDrawer)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            MainView()
        case 1:
            CourseView()
        case 2:
                SpeakerView(
                    pendingCourseId: $speakerPendingCourseId,
                    pendingLessonId: $speakerPendingLessonId,
                    pendingLessonIds: $speakerPendingLessonIds,
                    selectedTab: $selectedTab
                )
        case 3:
            FavoriteView()
        case 4:
            ProfileView()
        default:
            MainView()
        }
    }
}

private struct ShellHeaderHost: View {
    @Binding var selectedTab: Int
    @Binding var speakerPendingCourseId: String?
    @Binding var speakerPendingLessonId: String?
    @ObservedObject private var headerDriver = ShellHeaderDriver.shared

    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent

    private var headerStyle: AppHeaderStyle {
        _ = headerDriver.generation
        let speakerManager = SpeakerManager.shared
        let lessonsHeaderStore = LessonsHeaderStore.shared
        let gameHeaderStore = GameHeaderStore.shared
        let stepManager = StepManager.shared

        if selectedTab == 2 && SpeakerReturnContext.shared.hasContext {
            // Back в хедере перегружает Спикер; возврат — нижней CTA «К обучению».
            return .main(tab: 2, onBack: nil)
        }
        if selectedTab == 2, (speakerPendingCourseId != nil || speakerManager.speakerContextCourseId != nil) {
            return .main(tab: 2, onBack: nil)
        }
        if nav.path.count == 0 {
            return .main(tab: selectedTab, onBack: nil)
        }

        let onBack = {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                if !nav.path.isEmpty {
                    nav.path.removeLast()
                }
            }
        }
        let isOnLesson = nav.path.last.map { if case .lesson = $0 { return true }; return false } ?? false
        if !isOnLesson, let gameConfig = gameHeaderStore.config {
            return .game(gameConfig)
        }
        if case .lessons = nav.path.last {
            _ = lessonsHeaderStore.actionsRevision
            return .lessons(
                onBack: onBack,
                onSpeaker: lessonsHeaderStore.onSpeaker,
                onReinforce: lessonsHeaderStore.onReinforce,
                onReset: { lessonsHeaderStore.requestReset() },
                gameParkActive: LearnedGameSource.hasPlayableCards
            )
        }
        return .back(
            onBack: onBack,
            lessonTitle: isOnLesson ? stepManager.stepHeaderLessonTitle : nil,
            timerText: isOnLesson ? stepManager.stepHeaderTimerText : nil,
            showsWordmark: !isOnLesson
        )
    }

    var body: some View {
        let favorites = FavoriteManager.shared
        let pro = ProManager.shared
        let speakerManager = SpeakerManager.shared
        let speakerAttempts = SpeakerDailyAttemptsStore.shared
        let conversationAttempts = SpeakerConversationAttemptsStore.shared

        AppHeader(
            onTapPro: { overlay.presentPro() },
            onTapVoice: { overlay.present(.voiceSettings) },
            onTapGamePark: { overlay.present(.gamePark) },
            onTapCourseSearch: { overlay.presentSearch() },
            onTapCourseFilters: { overlay.present(.courseFilters) },
            onTapPersonalCourseCreate: { overlay.present(.personalCourseCreate) },
            onTapSpeakerFilters: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if SpeakerManager.shared.speakerUIMode == .conversation {
                    overlay.present(.speakerAttempts)
                } else {
                    overlay.present(.speakerCourses)
                }
            },
            speakerDailyAttemptsRemaining: (
                selectedTab == 2 &&
                speakerManager.speakerUIMode == .conversation &&
                !pro.isPro
            )
                ? conversationAttempts.remainingToday
                : speakerAttempts.remainingToday,
            gameParkActive: LearnedGameSource.hasPlayableCards,
            onTapFavoritesFilters: { overlay.present(.favoritesFilters) },
            favoritesTotalCount: favorites.items.count,
            favoritesHasCards: !FavoriteManager.shared.speakerStepIds().isEmpty,
            onTapAccentPicker: { overlay.present(.accentPicker) },
            isPro: pro.isPro,
            style: headerStyle,
            speakerUIMode: selectedTab == 2 ? speakerManager.speakerUIMode : nil,
            onSpeakerUIModeChange: selectedTab == 2 ? { SpeakerManager.shared.setSpeakerUIMode($0) } : nil,
            speakerShuffleOn: selectedTab == 2 ? speakerManager.shuffleQueue : nil,
            onSpeakerShuffleChange: selectedTab == 2 ? { SpeakerManager.shared.shuffleQueue = $0; if $0 { SpeakerManager.shared.shuffle() } } : nil,
            onTapFavoritesSpeaker: {
                speakerPendingCourseId = "__favorites__"
                speakerPendingLessonId = nil
                if nav.path.isEmpty {
                    SpeakerReturnContext.shared.clear()
                } else {
                    SpeakerReturnContext.shared.save(tab: selectedTab, path: nav.path)
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    nav.popToRoot()
                    selectedTab = 2
                }
            },
            onTapFavoritesGamePark: { overlay.present(.gameParkFromFavorites) },
            onTapFavoritesSearch: { overlay.present(.favoritesSearch) },
            onTapDictionary: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if selectedTab == 3 {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        FavoritesFilterState.shared.selectedTab = .dictionary
                    }
                } else {
                    overlay.present(.dictionaryQuickDrawer)
                }
            },
            dictionaryCount: favorites.smartSpeakerDictionaryCardsDTO.count
        )
    }
}

// MARK: - GameView router (тот же UI/UX что и игра из StepView: один сценарий, одна вёрстка)
private struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent
    @ObservedObject private var pro = ProManager.shared
    let courseId: String
    /// nil = course-level (learned cards from entire course); non-nil = lesson-level
    let lessonId: String?
    let lessonIds: [String]?
    let cardKeys: [String]?
    let gameType: String

    private var displayTitle: String? {
        guard let lid = lessonId, !lid.isEmpty else { return nil }
        let t = LessonsData.shared.lessonTitle(for: lid)
        return (t?.isEmpty == false) ? t : nil
    }

    private var resolvedGame: HomeGameType {
        Self.resolvedHomeGameType(gameType)
    }

    private var resolvedLessonId: String { lessonId ?? "" }

    private var isCourseReinforcement: Bool {
        guard let lessonIds, !lessonIds.isEmpty else { return false }
        return true
    }

    private var isFromLessonStep: Bool {
        !isCourseReinforcement && HomeTaskView.isLessonStepOrigin(courseId: courseId, lessonId: resolvedLessonId)
    }

    /// Страховка: навигация напрямую в `.game` без пикера не должна открывать PRO-режим бесплатным юзерам.
    private var isProGateActive: Bool {
        resolvedGame.normalizedForGameShell.requiresProSubscription && !pro.isPro
    }

    private var currentParkMode: GameModeType {
        switch resolvedGame.normalizedForGameShell {
        case .match: return .match
        case .recall, .builder: return .recall
        case .audioRecall, .conversation: return .audioRecall
        case .grandDialogue: return .grandDialogue
        }
    }

    private var nextParkMode: GameModeType? {
        let modes = GameModeType.modesLessonAndPark.filter { !$0.isPro || pro.isPro }
        guard let idx = modes.firstIndex(of: currentParkMode) else { return modes.first }
        let next = modes[(idx + 1) % modes.count]
        return next == currentParkMode ? nil : next
    }

    var body: some View {
        Group {
            if isProGateActive {
                gameProRequiredPlaceholder
            } else {
                HomeTaskView(
                    courseId: courseId,
                    lessonId: resolvedLessonId,
                    lessonIds: lessonIds,
                    cardKeys: cardKeys,
                    isCourseReinforcement: isCourseReinforcement,
                    embedBackground: false,
                    onClose: { dismiss() },
                    onNextGame: isFromLessonStep ? nil : {
                        guard let next = nextParkMode else { return }
                        // Keep error-queue filter across mode hops (don't open full-course game 2).
                        let nextKeys: [String]? = {
                            guard let lessonIds, !lessonIds.isEmpty, cardKeys != nil else { return cardKeys }
                            let remaining = Array(
                                ReinforcementStore.shared.failedCardKeys(
                                    courseId: courseId,
                                    lessonIds: lessonIds
                                )
                            ).sorted()
                            return remaining.isEmpty ? nil : remaining
                        }()
                        GameRequestedCourseScope.shared.set(
                            courseId: courseId,
                            lessonIds: lessonIds ?? [],
                            cardKeys: nextKeys
                        )
                        if !nav.path.isEmpty { nav.path.removeLast() }
                        nav.go(.game(courseId: courseId, lessonId: lessonId, gameType: next.rawValue))
                    },
                    nextGameTitle: nextParkMode?.title ?? "Следующая игра",
                    isProUser: pro.isPro,
                    displayTitle: displayTitle,
                    gameType: resolvedGame,
                    onSpeakerPractice: isFromLessonStep ? openSpeakerPractice : nil,
                    onContinueLearning: isFromLessonStep ? continueLearning : nil,
                    continueLearningTitle: HomeTaskView.continueLearningTitle(
                        courseId: courseId,
                        lessonId: resolvedLessonId
                    )
                )
            }
        }
        .onAppear {
            GameRequestedCourseScope.shared.clear()
        }
    }

    private func openSpeakerPractice() {
        let lid = resolvedLessonId
        UserSession.shared.markActive(courseId: courseId, lessonId: lid, stepIndex: 0)
        NotificationCenter.default.post(name: Notification.Name("Step.progressDidChange"), object: nil)
        SpeakerManager.shared.rebuildQueue()
        SpeakerManager.shared.setSpeakerUIMode(.training)
        SpeakerRequestedCourseId.shared.set(
            courseId,
            lessonId: lid,
            lessonIds: lessonIds,
            cardKeys: cardKeys
        )
        dismiss()
        nav.requestTab(2)
    }

    private func continueLearning() {
        let lid = resolvedLessonId
        let advance = CourseNavigator.shared.advance(from: courseId, lessonId: lid)
        while let last = nav.path.last {
            if case .game = last {
                nav.path.removeLast()
                continue
            }
            // In-place lesson advance keeps the first lesson id on the stack — pop by course.
            if case .lesson(let c, _, _) = last, c == courseId {
                nav.path.removeLast()
                continue
            }
            break
        }
        switch advance {
        case .nextLesson(let c, let nextLid):
            nav.go(.lesson(courseId: c, lessonId: nextLid, presentation: .canonical))
        case .nextCourse(let c, let firstLid):
            if case .lessons(let oldCid) = nav.path.last, oldCid == courseId {
                nav.path.removeLast()
            }
            nav.go(.lessons(courseId: c))
            nav.go(.lesson(courseId: c, lessonId: firstLid, presentation: .canonical))
        case .end:
            dismiss()
        }
    }

    private var gameProRequiredPlaceholder: some View {
        ZStack {
            PD.ColorToken.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                Text("Этот режим — Taika+")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                Text("Расширенные игры доступны с подпиской Taika+.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                Button {
                    overlay.presentPro(reason: .games, courseId: courseId)
                } label: {
                    Text("оформить Taika+")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(ThemeManager.shared.currentAccentFill)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                Button("назад") {
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
            }
            .padding(24)
        }
    }

    /// `context` / `conversation` → Audio Recall; явные rawValue — как в `HomeGameType`.
    /// `grandDialogue` → Audio Recall, пока `TaikaReleaseFlags.showGrandDialogue == false`.
    private static func resolvedHomeGameType(_ raw: String) -> HomeGameType {
        if raw == "context" || raw == "conversation" { return .audioRecall }
        let resolved = HomeGameType(rawValue: raw) ?? .match
        if !TaikaReleaseFlags.showGrandDialogue, resolved == .grandDialogue {
            return .audioRecall
        }
        return resolved
    }
}

#Preview {
    AppShell()
}
