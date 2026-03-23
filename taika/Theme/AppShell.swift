import SwiftUI

/// Единственный источник правды для игрового хедера: когда не nil, AppShell рисует в своей полоске таймер/прогресс/попытки.
final class GameHeaderStore: ObservableObject {
    static let shared = GameHeaderStore()
    @Published var config: GameHeaderConfig?
    private init() {}
}

struct AppShell: View {
    @State private var selectedTab: Int = 0
    @State private var showSplash: Bool = true
    @State private var showOnboarding: Bool = false

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    selectedTab = newValue
                }
            }
        )
    }

    @StateObject private var favorites = FavoriteManager.shared
    @StateObject private var overlay = OverlayPresenter.shared
    @StateObject private var theme = ThemeManager.shared
    @StateObject private var pro = ProManager.shared
    @StateObject private var speakerAttempts = SpeakerDailyAttemptsStore.shared
    @ObservedObject private var speakerManager = SpeakerManager.shared
    @ObservedObject private var session = UserSession.shared
    @ObservedObject private var stepManager = StepManager.shared
    @ObservedObject private var gameHeaderStore = GameHeaderStore.shared
    @EnvironmentObject private var nav: NavigationIntent
    /// When switching to Speaker tab from course card, pass consumed courseId so Speaker shows full course queue (onAppear may not run in time).
    @State private var speakerPendingCourseId: String? = nil

    private var gameParkActive: Bool {
        session.snapshot.learnedSteps.values.contains { !$0.isEmpty }
    }

    private var headerStyle: AppHeaderStyle {
        // Speaker tab with return context (from Favorites or Lessons): show back + full Speaker header (toggle, mic, crown)
        if selectedTab == 2 && SpeakerReturnContext.shared.hasContext {
            let onBack = {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    if let ctx = SpeakerReturnContext.shared.consume() {
                        selectedTab = ctx.tab
                        nav.path = ctx.path
                    }
                }
            }
            return .main(tab: 2, onBack: onBack)
        }
        // Show main header only when we are at root of navigation stack (EPIC 2: pass tab for context slots)
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
        if case .lessons = nav.path.last {
            let store = LessonsHeaderStore.shared
            return .lessons(
                onBack: onBack,
                onSpeaker: store.onSpeaker ?? {},
                onReinforce: store.onReinforce ?? {},
                onReset: { store.requestReset() }
            )
        }
        // Игра (из StepView или nav .game): один хедер сверху — таймер, прогресс, попытки
        if let gameConfig = gameHeaderStore.config {
            return .game(gameConfig)
        }
        let isOnLesson = nav.path.last.map { if case .lesson = $0 { return true }; return false } ?? false
        let stepBinding = Binding(
            get: { stepManager.stepHeaderSegment },
            set: { stepManager.stepHeaderSegment = $0 }
        )
        return .back(
            onBack: onBack,
            stepSegmentBinding: isOnLesson ? stepBinding : nil,
            stepShowsSegment: isOnLesson && stepManager.stepHeaderShowsSegment,
            stepTipCount: stepManager.stepHeaderTipCount,
            stepCardCount: stepManager.stepHeaderCardCount
        )
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            if showSplash {
                SplashTaikaView {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                        showSplash = false
                        showOnboarding = true
                    }
                }
            } else if showOnboarding {
                OnboardingCarouselView {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                        showOnboarding = false
                        selectedTab = 0
                    }
                }
            } else {
                VStack(spacing: 0) {
                    AppHeader(
                        onTapPro: { overlay.present(.proCoursePaywall(courseId: "")) },
                        onTapVoice: { overlay.present(.voiceSettings) },
                        onTapGamePark: { overlay.present(.gamePark) },
                        onTapCourseSearch: { overlay.presentSearch() },
                        onTapCourseFilters: { overlay.present(.courseFilters) },
                        onTapSpeakerFilters: { overlay.present(.speakerFilters) },
                        speakerDailyAttemptsRemaining: speakerAttempts.remainingToday,
                        gameParkActive: gameParkActive,
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
                            SpeakerReturnContext.shared.save(tab: selectedTab, path: nav.path)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                nav.popToRoot()
                                selectedTab = 2
                            }
                        },
                        onTapFavoritesGamePark: { overlay.present(.gameParkFromFavorites) }
                    )

                    NavigationStack(path: $nav.path) {
                        tabContent
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .navigationDestination(for: NavigationIntent.Route.self) { route in
                                switch route {

                                case .course:
                                    CourseView()

                                case let .lessons(courseId):
                                    LessonsView(courseId: courseId)

                                case let .lesson(courseId, lessonId):
                                    StepView(courseId: courseId, lessonId: lessonId)

                                case let .game(courseId, lessonId, gameType):
                                    GameView(
                                        courseId: courseId,
                                        lessonId: lessonId,
                                        gameType: gameType
                                    )
                                }
                            }
                    }
                    .background(PD.ColorToken.background)
                    .toolbar(.hidden, for: .navigationBar)

                    if nav.path.isEmpty {
                        ToolBar(selectedTab: tabSelection)
                            .background(PD.ColorToken.background.ignoresSafeArea(edges: .bottom))
                    }
                }
                .blur(radius: overlay.overlay != nil ? 10 : 0)
                .opacity(overlay.overlay != nil ? 0.92 : 1)
                .scaleEffect(overlay.overlay != nil ? 0.98 : 1)
                .animation(.spring(response: 0.36, dampingFraction: 0.92), value: overlay.overlay != nil)
                .onChange(of: nav.requestedTab) { _, newValue in
                    guard let tab = newValue, (0...4).contains(tab) else { return }
                    if tab == 2 {
                        SpeakerReturnContext.shared.save(tab: selectedTab, path: nav.path)
                        speakerPendingCourseId = SpeakerRequestedCourseId.shared.consume()
                    }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        nav.popToRoot()
                        selectedTab = tab
                        nav.clearRequestedTab()
                    }
                }
                .onChange(of: selectedTab) { _, newTab in
                    if newTab == 2 && speakerManager.speakerUIMode == .conversation {
                        SpeakerManager.shared.clearConversationResult()
                    }
                }
            }

            // Оверлеи на уровне шелла (EPIC 2: courseFilters, speakerFilters, voiceSettings, gamePark)
            if let o = overlay.overlay {
                switch o {
                case .search:
                    SearchOverlayView()
                case .speakerPaywall:
                    PROView(courseId: nil, initialPage: 2) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.dismiss()
                        }
                    }
                case .proCoursePaywall(let courseId):
                    PROView(courseId: courseId.isEmpty ? nil : courseId) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            overlay.dismiss()
                        }
                    }
                case .courseFilters, .courseSearchAndFilters:
                    CourseFiltersOverlayView(onDismiss: { overlay.dismiss() })
                case .speakerFilters:
                    SpeakerFiltersOverlayView(onDismiss: { overlay.dismiss() })
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
                case .favoritesFilters:
                    FavoritesFiltersOverlayView(onDismiss: { overlay.dismiss() })
                case .accentPicker:
                    AccentPickerOverlayView(onDismiss: { overlay.dismiss() })
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
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(theme.preferredScheme)
        .environmentObject(theme)
        .environmentObject(favorites)
        .environmentObject(overlay)
        .environmentObject(pro)
        .task {
            pro.start(session: UserSession.shared)
        }
        .onAppear {
            Task.detached {
                StepData.shared.preload()
                LessonsData.shared.preload()
            }
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
            SpeakerView(pendingCourseId: $speakerPendingCourseId)
        case 3:
            FavoriteView()
        case 4:
            ProfileView()
        default:
            MainView()
        }
    }
}

// MARK: - GameView router (тот же UI/UX что и игра из StepView: один сценарий, одна вёрстка)
private struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    let courseId: String
    /// nil = course-level (learned cards from entire course); non-nil = lesson-level
    let lessonId: String?
    let gameType: String

    private var displayTitle: String? {
        guard let lid = lessonId, !lid.isEmpty else { return nil }
        let t = LessonsData.shared.lessonTitle(for: lid)
        return (t?.isEmpty == false) ? t : nil
    }

    var body: some View {
        HomeTaskView(
            courseId: courseId,
            lessonId: lessonId ?? "",
            embedBackground: false,
            onClose: { dismiss() },
            onNextGame: nil,
            nextGameTitle: nil,
            isProUser: ProManager.shared.isPro,
            displayTitle: displayTitle,
            gameType: HomeGameType(rawValue: gameType) ?? .match
        )
    }
}

#Preview {
    AppShell()
}
