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
    /// Брендовый сплэш на каждом cold start → дальше Welcome или Main.
    @State private var showBootSplash: Bool = true
    @State private var didStartDataPreload: Bool = false

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                // Avoid extra spring-driven layout work on heavy root tabs.
                selectedTab = newValue
            }
        )
    }

    @ObservedObject private var overlay = OverlayPresenter.shared
    @ObservedObject private var gameHeaderStore = GameHeaderStore.shared
    @EnvironmentObject private var nav: NavigationIntent
    /// When switching to Speaker tab from course card, pass consumed courseId so Speaker shows full course queue (onAppear may not run in time).
    @State private var speakerPendingCourseId: String? = nil
    @State private var speakerPendingLessonId: String? = nil

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            // Вход — один экран, не два бренда подряд:
            // • первый раз → Welcome (там уже tai/kAAA + «Начать»)
            // • дальше → короткий Splash → Main
            if !welcomeSeen {
                WelcomeLandingView {
                    welcomeSeen = true
                    showBootSplash = false
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                        selectedTab = 0
                    }
                }
                .transition(.opacity)
            } else if showBootSplash {
                SplashTaikaView {
                    withAnimation(.easeOut(duration: 0.28)) {
                        showBootSplash = false
                    }
                }
                .transition(.opacity)
            } else {
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
                                    gameType: gameType
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
                .background(PD.ColorToken.background)
                .toolbar(.hidden, for: .navigationBar)
                .environment(
                    \.taikaRootHeaderClearance,
                    gameHeaderStore.config != nil
                        ? Theme.Layout.rootHeaderClearanceGame
                        : Theme.Layout.rootHeaderClearance
                )
                .overlay(alignment: .top) {
                    ShellHeaderHost(
                        selectedTab: $selectedTab,
                        speakerPendingCourseId: $speakerPendingCourseId,
                        speakerPendingLessonId: $speakerPendingLessonId
                    )
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) {
                        TaikaLiquidGlassHeaderBackdrop()
                    }
                    .zIndex(50)
                }
                .overlay(alignment: .bottom) {
                    if nav.path.isEmpty {
                        ToolBar(selectedTab: tabSelection)
                    }
                }
                // Perf hotfix: do not blur/fade the whole shell tree while scrolling/tab switching.
                .onChange(of: nav.requestedTab) { _, newValue in
                    guard let tab = newValue, (0...4).contains(tab) else { return }
                    if tab == 2 {
                        if nav.path.isEmpty {
                            // Таб → таб с корня: без back-хрома.
                            SpeakerReturnContext.shared.clear()
                        } else {
                            SpeakerReturnContext.shared.save(tab: selectedTab, path: nav.path)
                        }
                        if let ctx = SpeakerRequestedCourseId.shared.consume() {
                            speakerPendingCourseId = ctx.courseId
                            speakerPendingLessonId = ctx.lessonId
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
                case .favoritesFilters:
                    FavoritesFiltersOverlayView(onDismiss: { overlay.dismiss() })
                case .favoritesSearch:
                    FavoritesSearchOverlayView(onDismiss: { overlay.dismiss() })
                case .accentPicker:
                    AccentPickerOverlayView(onDismiss: { overlay.dismiss() })
                case .courseResetConfirm(let courseId):
                    CourseResetConfirmOverlayView(courseId: courseId) {
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
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environmentObject(ThemeManager.shared)
        .environmentObject(FavoriteManager.shared)
        .environmentObject(overlay)
        .environmentObject(ProManager.shared)
        // Failsafe: только когда сплэш реально на экране (returning users).
        .task(id: showBootSplash) {
            guard welcomeSeen, showBootSplash else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if showBootSplash {
                withAnimation(.easeOut(duration: 0.28)) {
                    showBootSplash = false
                }
            }
        }
        .task {
            // Не блокируем первый кадр: Pro sync после короткой паузы.
            try? await Task.sleep(nanoseconds: 300_000_000)
            ProManager.shared.start(session: UserSession.shared)
            await ProManager.shared.syncRevenueCatIdentity(userId: AuthService.shared.currentUserID)
            await ProManager.shared.syncCustomerInfoFromRevenueCat()
        }
        .onAppear {
            guard !didStartDataPreload else { return }
            didStartDataPreload = true
            // Тихий preload без модалки «Готовим Taika…».
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
                pendingLessonId: $speakerPendingLessonId
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

    private var gameParkActive: Bool {
        UserSession.shared.snapshot.learnedSteps.values.contains { !$0.isEmpty }
    }

    private var headerStyle: AppHeaderStyle {
        _ = headerDriver.generation
        let speakerManager = SpeakerManager.shared
        let lessonsHeaderStore = LessonsHeaderStore.shared
        let gameHeaderStore = GameHeaderStore.shared
        let stepManager = StepManager.shared

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
                gameParkActive: gameParkActive
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
                if selectedTab == 2 {
                    NotificationCenter.default.post(name: .taikaOpenSmartSpeakerDictionary, object: nil)
                } else {
                    FavoritesFilterState.shared.selectedTab = .dictionary
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        nav.popToRoot()
                        selectedTab = 3
                    }
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
    @ObservedObject private var pro = ProManager.shared
    let courseId: String
    /// nil = course-level (learned cards from entire course); non-nil = lesson-level
    let lessonId: String?
    let gameType: String

    private var displayTitle: String? {
        guard let lid = lessonId, !lid.isEmpty else { return nil }
        let t = LessonsData.shared.lessonTitle(for: lid)
        return (t?.isEmpty == false) ? t : nil
    }

    private var resolvedGame: HomeGameType {
        Self.resolvedHomeGameType(gameType)
    }

    /// Страховка: навигация напрямую в `.game` без пикера не должна открывать PRO-режим бесплатным юзерам.
    private var isProGateActive: Bool {
        resolvedGame.normalizedForGameShell.requiresProSubscription && !pro.isPro
    }

    var body: some View {
        Group {
            if isProGateActive {
                gameProRequiredPlaceholder
            } else {
                HomeTaskView(
                    courseId: courseId,
                    lessonId: lessonId ?? "",
                    embedBackground: false,
                    onClose: { dismiss() },
                    onNextGame: nil,
                    nextGameTitle: nil,
                    isProUser: pro.isPro,
                    displayTitle: displayTitle,
                    gameType: resolvedGame
                )
            }
        }
    }

    private var gameProRequiredPlaceholder: some View {
        ZStack {
            PD.ColorToken.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "crown.fill")
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
                    overlay.presentPro(reason: .lockedCourse, courseId: courseId)
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
