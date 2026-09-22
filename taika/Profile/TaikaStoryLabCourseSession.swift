#if DEBUG

//
//  TaikaStoryLabCourseSession.swift
//  taika
//
//  Story Lab — Course View page assembly (~68s).
//  Chrome already exists. Assemble CourseView with real DS, then:
//  filter switches → different carousels → paint status waves with palette.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabCourseClock: ObservableObject {
    @Published var t: TimeInterval = 0
    @Published var isPlaying = true
    let duration: TimeInterval = 68
    private var task: Task<Void, Never>?

    func start() {
        task?.cancel()
        isPlaying = true
        task = Task { @MainActor in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                guard isPlaying else { last = Date(); continue }
                let now = Date()
                t = min(duration, t + now.timeIntervalSince(last))
                last = now
                if t >= duration { isPlaying = false }
            }
        }
    }

    func stop() { task?.cancel(); task = nil }
    func toggle() {
        isPlaying.toggle()
        if isPlaying, t >= duration { t = 0 }
    }
    func restart() { t = 0; isPlaying = true }
    func scrub(_ v: TimeInterval) { t = min(duration, max(0, v)) }
}

// MARK: - Scene

enum StoryLabCourseFocus: Equatable {
    case chrome, title, guide, wire, load, reel, tabs, paint, rhythm, settle
}

struct StoryLabCourseScene: Equatable {
    var grid: CGFloat
    var titleBlock: CGFloat
    var tabBar: CGFloat
    var guide: CGFloat
    var sectionShell: CGFloat
    var emptyReel: CGFloat
    var jsonLoad: CGFloat
    var reel: CGFloat
    var cardCount: Int
    var carouselIndex: Int
    var tab: CourseScreenTab
    var palette: CGFloat
    var waveDraw: CGFloat
    var paletteIndex: Int
    var colorful: Bool
    var rhythm: CGFloat
    var ready: CGFloat
    var marquee: CGFloat
    var figmaChip: String?
    var focus: StoryLabCourseFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var actionChip: String?

    static func at(_ t: TimeInterval) -> StoryLabCourseScene {
        func ramp(_ a: TimeInterval, _ b: TimeInterval) -> CGFloat {
            guard b > a else { return t >= b ? 1 : 0 }
            return CGFloat(min(1, max(0, (t - a) / (b - a))))
        }
        func pulse(_ a: TimeInterval, _ peak: TimeInterval, _ b: TimeInterval) -> CGFloat {
            if t < a || t >= b { return 0 }
            return t < peak ? ramp(a, peak) : 1 - ramp(peak, b)
        }
        func lerp(_ a: CGFloat, _ b: CGFloat, _ u: CGFloat) -> CGFloat {
            a + (b - a) * min(1, max(0, u))
        }

        // Chrome already live.
        // 0–4   empty page under chrome
        // 4–10  title + CDCourseTabBar
        // 10–18 MDCyclingTypewriter
        // 18–26 empty reel
        // 26–33 courses.json
        // 33–42 CDBaseSection flood
        // 42–54 filter switches → different carousels
        // 54–62 paint waves + palette
        // 62–66 rhythm
        // 66–68 settle

        let focus: StoryLabCourseFocus = {
            switch t {
            case ..<4: return .chrome
            case ..<10: return .title
            case ..<18: return .guide
            case ..<26: return .wire
            case ..<33: return .load
            case ..<42: return .reel
            case ..<54: return .tabs
            case ..<62: return .paint
            case ..<66: return .rhythm
            default: return .settle
            }
        }()

        let total = storyLabBaseCatalog.count
        let cardCount: Int = {
            if t < 33.5 { return 0 }
            let u = ramp(33.5, 41.0)
            return max(1, Int(round(CGFloat(total) * u * u)))
        }()

        let tab: CourseScreenTab = {
            if t < 43.0 { return .base }
            if t < 47.0 { return .scenarios }
            if t < 50.5 { return .favorites }
            if t < 54.0 { return .base }
            return .base
        }()

        let paletteIndex: Int = {
            if t < 55.5 { return 0 } // pink
            if t < 58.0 { return 1 } // sky / in progress
            return 2 // green / done
        }()

        let actionChip: String? = {
            if t >= 0.6 && t < 3.5 { return "Chrome ready · header + ToolBar" }
            if t >= 4.5 && t < 9.5 { return "Wire · TaikaScreenPageTitle + CDCourseTabBar" }
            if t >= 10.5 && t < 17.0 { return "Drop · MDCyclingTypewriter (nav guide)" }
            if t >= 18.5 && t < 25.0 { return "Frame · БАЗА section + empty reel" }
            if t >= 26.5 && t < 32.5 { return "Load · courses.json" }
            if t >= 33.5 && t < 41.0 { return "Hydrate · CDBaseSection \(min(cardCount, total))/\(total)" }
            if t >= 42.5 && t < 46.5 { return "Filter · Сценарии → new reel" }
            if t >= 47.0 && t < 50.0 { return "Filter · Избранное → liked reel" }
            if t >= 50.5 && t < 53.5 { return "Filter · back to База" }
            if t >= 54.5 && t < 61.0 { return "Paint · status waves + palette" }
            if t >= 62.5 && t < 65.5 { return "Mount · CDWeeklyRhythmSection" }
            return nil
        }()

        let figmaChip: String? = {
            if t >= 5.5 && t < 8.5 { return "Component · CDCourseTabBar" }
            if t >= 12.0 && t < 16.0 { return "Component · MDCyclingTypewriter" }
            if t >= 20.0 && t < 24.0 { return "Frame · CDLessonCarousel" }
            if t >= 28.0 && t < 32.0 { return "Data · courses.json" }
            if t >= 36.0 && t < 40.0 { return "Instance · CourseLessonCard ×\(total)" }
            if t >= 44.0 && t < 52.5 { return "Variant · filter scope" }
            if t >= 55.0 && t < 60.5 { return "Draw · accent waves" }
            if t >= 63.0 && t < 65.5 { return "Component · CDWeeklyRhythmSection" }
            return nil
        }()

        let (cx, cy): (CGFloat, CGFloat) = {
            switch focus {
            case .chrome: return (0.50, 0.88)
            case .title: return (0.78, 0.16)
            case .guide: return (0.40, 0.24)
            case .wire: return (0.50, 0.42)
            case .load: return (0.50, 0.38)
            case .reel: return (0.55, 0.42)
            case .tabs: return (0.80, 0.16)
            case .paint: return (0.58, 0.46)
            case .rhythm: return (0.40, 0.72)
            case .settle: return (0.50, 0.90)
            }
        }()
        let prev: (CGFloat, CGFloat) = {
            let e = max(0, t - 0.4)
            switch e {
            case ..<4: return (0.50, 0.88)
            case ..<10: return (0.78, 0.16)
            case ..<18: return (0.40, 0.24)
            case ..<26: return (0.50, 0.42)
            case ..<33: return (0.50, 0.38)
            case ..<42: return (0.55, 0.42)
            case ..<54: return (0.80, 0.16)
            case ..<62: return (0.58, 0.46)
            case ..<66: return (0.40, 0.72)
            default: return (0.50, 0.90)
            }
        }()
        let moveStart: TimeInterval = {
            switch focus {
            case .chrome: return 0
            case .title: return 4
            case .guide: return 10
            case .wire: return 18
            case .load: return 26
            case .reel: return 33
            case .tabs: return 42
            case .paint: return 54
            case .rhythm: return 62
            case .settle: return 66
            }
        }()
        let move = min(1, max(0, (t - moveStart) / 0.35))

        let clickTimes: [TimeInterval] = [
            2.0, 6.0, 8.5, 12.0, 16.0, 20.5, 24.0, 29.0, 32.0,
            36.0, 40.0, 43.5, 47.2, 50.8, 55.5, 57.8, 60.0, 63.5
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.12 { return CGFloat(1 - d / 0.12) }
            }
            return 0
        }()

        return StoryLabCourseScene(
            grid: ramp(0.4, 2.0) * (1 - ramp(64.0, 67.0)),
            titleBlock: ramp(4.2, 6.5),
            tabBar: ramp(6.5, 8.5),
            guide: ramp(10.5, 13.0),
            sectionShell: ramp(18.5, 21.0),
            emptyReel: ramp(20.0, 23.0) * (1 - ramp(33.0, 36.0)),
            jsonLoad: ramp(26.5, 32.5) * (1 - ramp(33.0, 35.5)),
            reel: ramp(33.0, 36.0),
            cardCount: cardCount,
            carouselIndex: 0,
            tab: tab,
            palette: ramp(54.0, 55.5) * (1 - ramp(61.5, 63.0)),
            waveDraw: ramp(55.0, 60.5),
            paletteIndex: paletteIndex,
            colorful: t >= 56.5,
            rhythm: ramp(62.0, 64.0),
            ready: ramp(66.0, 67.5),
            marquee: max(
                pulse(5.0, 6.5, 9.0),
                pulse(19.5, 21.0, 24.0),
                pulse(36.5, 38.0, 41.0),
                pulse(43.5, 44.5, 46.5),
                pulse(55.5, 57.0, 60.0)
            ),
            figmaChip: figmaChip,
            focus: focus,
            cursorX: lerp(prev.0, cx, move),
            cursorY: lerp(prev.1, cy, move),
            click: click,
            actionChip: actionChip
        )
    }
}

// MARK: - Catalogs (different reels per filter)

private func storyLabMakeItem(
    index: Int,
    title: String,
    subtitle: String,
    category: String,
    status: CDCourseStatus?,
    progress: Double,
    isPro: Bool,
    favorite: Bool
) -> CDCourseItem {
    CDCourseItem(
        title: title,
        subtitle: subtitle,
        applicationLine: subtitle,
        category: category,
        lessons: 4 + (index % 9),
        durationMin: 18 + (index % 40),
        cta: status == .inProgress ? "Продолжить" : "Начать",
        isPro: isPro,
        status: status,
        progress: progress,
        homeworkTotal: 3,
        homeworkDone: status == .inProgress || status == .done ? 1 : 0,
        isFavorite: favorite,
        key: "storylab-\(category)-\(index)-\(title)"
    )
}

private let storyLabBaseCatalog: [CDCourseItem] = [
    storyLabMakeItem(index: 0, title: "разговорный старт", subtitle: "звуки · тоны · первые фразы", category: "База от тайки", status: .inProgress, progress: 0.05, isPro: false, favorite: false),
    storyLabMakeItem(index: 1, title: "магия интонации", subtitle: "тон · ритм · слух", category: "База от тайки", status: .new, progress: 0, isPro: false, favorite: true),
    storyLabMakeItem(index: 2, title: "первые диалоги", subtitle: "привет · спасибо · извини", category: "База от тайки", status: .new, progress: 0, isPro: false, favorite: false),
    storyLabMakeItem(index: 3, title: "тон и слух", subtitle: "высокий · низкий · падающий", category: "База от тайки", status: .done, progress: 1, isPro: false, favorite: false),
    storyLabMakeItem(index: 4, title: "связка слов", subtitle: "частицы · порядок · смысл", category: "База от тайки", status: .new, progress: 0, isPro: false, favorite: false),
    storyLabMakeItem(index: 5, title: "вежливые формы", subtitle: "кхап · кха · кру", category: "База от тайки", status: .inProgress, progress: 0.28, isPro: false, favorite: true),
    storyLabMakeItem(index: 6, title: "числа и цены", subtitle: "байт · скидка · сдача", category: "База от тайки", status: .new, progress: 0, isPro: false, favorite: false),
    storyLabMakeItem(index: 7, title: "время и день", subtitle: "сегодня · завтра · сейчас", category: "База от тайки", status: .new, progress: 0, isPro: false, favorite: false),
    storyLabMakeItem(index: 8, title: "вопросы", subtitle: "где · как · сколько", category: "База от тайки", status: .new, progress: 0, isPro: true, favorite: false),
    storyLabMakeItem(index: 9, title: "разговорный финиш", subtitle: "связный мини-диалог", category: "База от тайки", status: .new, progress: 0, isPro: false, favorite: false),
    storyLabMakeItem(index: 10, title: "слуховая разминка", subtitle: "повтор · ритм · акцент", category: "База от тайки", status: .new, progress: 0, isPro: false, favorite: false),
    storyLabMakeItem(index: 11, title: "база · волна 2", subtitle: "закрепление стартовых фраз", category: "База от тайки", status: .new, progress: 0, isPro: false, favorite: false),
]

private let storyLabScenarioCatalog: [CDCourseItem] = [
    storyLabMakeItem(index: 0, title: "у аэропорта", subtitle: "встреча · такси · check-in", category: "Тайский для жизни", status: .done, progress: 1, isPro: false, favorite: false),
    storyLabMakeItem(index: 1, title: "в кафе", subtitle: "меню · заказ · счёт", category: "Тайский для жизни", status: .new, progress: 0.05, isPro: false, favorite: true),
    storyLabMakeItem(index: 2, title: "на посту с полицией", subtitle: "документы · спокойствие", category: "Тайский для жизни", status: .inProgress, progress: 0.42, isPro: true, favorite: false),
    storyLabMakeItem(index: 3, title: "рынок Чатучак", subtitle: "торг · веса · вкус", category: "Еда и улица", status: .new, progress: 0, isPro: false, favorite: false),
    storyLabMakeItem(index: 4, title: "в храме", subtitle: "этикет · дарение · фото", category: "Культура", status: .new, progress: 0, isPro: false, favorite: true),
    storyLabMakeItem(index: 5, title: "в такси", subtitle: "куда · сколько · стоп", category: "Город", status: .new, progress: 0, isPro: false, favorite: false),
    storyLabMakeItem(index: 6, title: "отель check-in", subtitle: "номер · ключ · завтрак", category: "Travel", status: .done, progress: 1, isPro: false, favorite: false),
    storyLabMakeItem(index: 7, title: "у врача", subtitle: "боль · аптека · рецепт", category: "Жизнь", status: .new, progress: 0, isPro: true, favorite: false),
    storyLabMakeItem(index: 8, title: "ночь в Бангкоке", subtitle: "бары · такси · безопасно", category: "Город", status: .inProgress, progress: 0.18, isPro: true, favorite: false),
    storyLabMakeItem(index: 9, title: "утро в Чиангмае", subtitle: "кофе · храмы · рынок", category: "Travel", status: .new, progress: 0, isPro: false, favorite: false),
]

private let storyLabFavoriteCatalog: [CDCourseItem] = [
    storyLabMakeItem(index: 0, title: "магия интонации", subtitle: "тон · ритм · слух", category: "База от тайки", status: .new, progress: 0, isPro: false, favorite: true),
    storyLabMakeItem(index: 1, title: "в кафе", subtitle: "меню · заказ · счёт", category: "Тайский для жизни", status: .new, progress: 0.05, isPro: false, favorite: true),
    storyLabMakeItem(index: 2, title: "в храме", subtitle: "этикет · дарение · фото", category: "Культура", status: .new, progress: 0, isPro: false, favorite: true),
    storyLabMakeItem(index: 3, title: "вежливые формы", subtitle: "кхап · кха · кру", category: "База от тайки", status: .inProgress, progress: 0.28, isPro: false, favorite: true),
]

/// Colorful paint pass — same titles, stronger status colors / waves.
private func storyLabColorized(_ items: [CDCourseItem]) -> [CDCourseItem] {
    items.enumerated().map { i, item in
        let status: CDCourseStatus = {
            switch i % 3 {
            case 0: return .inProgress
            case 1: return .done
            default: return item.status ?? .new
            }
        }()
        let progress: Double = {
            switch status {
            case .done: return 1
            case .inProgress: return max(0.35, item.progress)
            default: return item.progress
            }
        }()
        return storyLabMakeItem(
            index: i,
            title: item.title,
            subtitle: item.subtitle,
            category: item.category,
            status: status,
            progress: progress,
            isPro: item.isPro,
            favorite: item.isFavorite
        )
    }
}

private let storyLabGuideLines: [String] = [
    "Листай курсы — свайп влево и вправо",
    "Сверху переключай База и Сценарии",
    "Начать — открыть курс одним тапом",
    "На карточке: избранное, игра и спикер"
]

private let storyLabTabs: [CourseScreenTab] = [.base, .scenarios, .favorites]

private func storyLabSectionTitle(for tab: CourseScreenTab) -> String {
    switch tab {
    case .scenarios: return "ТАЙСКИЙ ДЛЯ ЖИЗНИ"
    case .favorites: return "ИЗБРАННОЕ"
    default: return "БАЗА"
    }
}

private func storyLabCatalog(for tab: CourseScreenTab) -> [CDCourseItem] {
    switch tab {
    case .scenarios: return storyLabScenarioCatalog
    case .favorites: return storyLabFavoriteCatalog
    default: return storyLabBaseCatalog
    }
}

// MARK: - Session

struct StoryLabEditorCourseSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabCourseClock()
    @State private var showControls = false
    @State private var selectedTab: CourseScreenTab = .base

    private var scene: StoryLabCourseScene { .at(clock.t) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PD.ColorToken.background.ignoresSafeArea()

                gridOverlay
                    .opacity(scene.grid)
                    .allowsHitTesting(false)

                // Full product chrome from the start (Identity + Architecture already shipped).
                VStack(spacing: 0) {
                    brandHeader
                    coursePage
                    ToolBar(selectedTab: .constant(1))
                        .allowsHitTesting(false)
                        .padding(.bottom, 2)
                }

                if scene.marquee > 0.05 {
                    figmaMarquee(in: geo.size)
                        .opacity(scene.marquee)
                        .allowsHitTesting(false)
                }

                if let fig = scene.figmaChip {
                    figmaPropertyChip(fig).allowsHitTesting(false)
                }

                if scene.palette > 0.05 {
                    wavePaletteHUD
                        .opacity(scene.palette)
                        .allowsHitTesting(false)
                }

                if scene.waveDraw > 0.05 {
                    wavePaintOverlay(in: geo.size)
                        .opacity(min(1, scene.waveDraw * 1.2))
                        .allowsHitTesting(false)
                }

                if let chip = scene.actionChip {
                    workChip(chip).allowsHitTesting(false)
                }

                cursorLayer(in: geo.size).allowsHitTesting(false)

                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 14)
                    .padding(.top, 54)
                    .zIndex(20)

                if showControls { controlsOverlay }
            }
            .onChange(of: scene.tab) { _, tab in
                selectedTab = tab
            }
            .animation(.easeOut(duration: 0.28), value: scene.cardCount)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedTab)
            .animation(.easeOut(duration: 0.25), value: scene.paletteIndex)
            .animation(.easeOut(duration: 0.3), value: scene.colorful)
        }
        .statusBarHidden(false)
        .navigationBarHidden(true)
        .onAppear {
            selectedTab = .base
            clock.start()
        }
        .onDisappear { clock.stop() }
        .onTapGesture(count: 2) {
            withAnimation(.easeOut(duration: 0.2)) { showControls.toggle() }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 50)
                .onEnded { v in if v.translation.height > 100 { closeSession() } }
        )
    }

    private func closeSession() {
        clock.stop()
        dismiss()
    }

    // MARK: Chrome (already built)

    private var brandHeader: some View {
        HStack {
            HStack(spacing: 2) {
                Text("tai").font(.custom("Onmark Trial", size: 22)).foregroundStyle(.white)
                Text("kAAA").font(.custom("Onmark Trial", size: 22)).foregroundStyle(theme.currentAccentFill)
            }
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                Image(systemName: "crown.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 54)
        .padding(.bottom, 6)
    }

    // MARK: CourseView page (what we assemble)

    private var coursePage: some View {
        VStack(spacing: 0) {
            // Real header row: title + CDCourseTabBar
            ZStack {
                if scene.titleBlock < 0.55 {
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                            .frame(width: 120, height: 28)
                        Spacer()
                        Capsule()
                            .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                            .frame(width: 88, height: 32)
                    }
                    .padding(.horizontal, CD.Spacing.screen)
                    .opacity(0.35 + 0.4 * scene.titleBlock)
                }

                TaikaScreenPageTitle(title: "Курсы") {
                    CDCourseTabBar(selection: $selectedTab, tabs: storyLabTabs)
                        .opacity(scene.tabBar)
                }
                .opacity(scene.titleBlock)
            }
            .padding(.top, 4)

            if scene.guide > 0.05 {
                MDCyclingTypewriter(
                    lines: storyLabGuideLines,
                    font: .system(size: 19, weight: .bold),
                    holdSeconds: 2.4,
                    charInterval: 0.032,
                    minHeight: 48
                )
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.top, 2)
                .padding(.bottom, 4)
                .opacity(scene.guide)
                .id("storylab-course-guide")
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: max(14, Theme.Layout.sectionGap - 6)) {
                    if scene.jsonLoad > 0.05 {
                        jsonLoadBar
                            .padding(.horizontal, CD.Spacing.screen)
                            .opacity(scene.jsonLoad)
                    }

                    if scene.sectionShell > 0.05 || scene.reel > 0.05 {
                        sectionAndReel
                    }

                    if scene.rhythm > 0.05 {
                        CDWeeklyRhythmSection(
                            model: CDWeeklyRhythmModel(lessons: 1, steps: 3, days: 1)
                        )
                        .opacity(scene.rhythm)
                        .id("storylab-rhythm")
                    }

                    Color.clear.frame(height: ToolBar.recommendedBottomInset + 24)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if scene.ready > 0.05 {
                Text("CourseView · locked")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(.bottom, 8)
                    .opacity(scene.ready)
            }
        }
    }

    @ViewBuilder
    private var sectionAndReel: some View {
        let itemsBase: [CDCourseItem] = {
            if selectedTab == .base, scene.focus == .reel || scene.focus == .load || scene.cardCount < storyLabBaseCatalog.count {
                // Growing flood only on База while hydrating.
                if scene.focus == .tabs || scene.focus == .paint || scene.focus == .rhythm || scene.focus == .settle {
                    return storyLabBaseCatalog
                }
                return Array(storyLabBaseCatalog.prefix(max(0, scene.cardCount)))
            }
            return storyLabCatalog(for: selectedTab)
        }()
        let items = scene.colorful ? storyLabColorized(itemsBase) : itemsBase
        let sectionTitle = storyLabSectionTitle(for: selectedTab)

        ZStack(alignment: .top) {
            if scene.emptyReel > 0.05 {
                emptyReelPlaceholder(title: sectionTitle)
                    .opacity(scene.emptyReel)
            }

            if scene.reel > 0.05, !items.isEmpty {
                CDBaseSection(
                    title: sectionTitle,
                    items: items,
                    initialCarouselIndex: 0,
                    onTapItem: { _ in },
                    onTapStart: {}
                )
                .id("storylab-reel-\(selectedTab.rawValue)-\(scene.colorful)-\(items.count)")
                .opacity(scene.reel)
                .environmentObject(theme)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: selectedTab)
    }

    private func emptyReelPlaceholder(title: String) -> some View {
        VStack(alignment: .leading, spacing: CDLayout.sectionContentV) {
            TaikaSectionHeaderRow(title) {
                HStack(spacing: 6) {
                    Text("Начать")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(PD.ColorToken.text.opacity(0.45))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            }
            .padding(.horizontal, CD.Spacing.screen)

            HStack(spacing: 16) {
                ForEach(0..<2, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.2, dash: [7, 4]))
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "rectangle.stack")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.28))
                                Text(i == 0 ? "card slot" : "peek")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.32))
                            }
                        )
                        .frame(width: 280, height: 360)
                        .opacity(0.7)
                }
            }
            .padding(.leading, Theme.Layout.pageHorizontal)
        }
        .padding(.top, CDLayout.sectionTop)
    }

    private var jsonLoadBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("courses.json")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text("\(Int(scene.jsonLoad * 100))% · \(storyLabBaseCatalog.count)+")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.cyan.opacity(0.9))
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.75), theme.currentAccentTintColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, g.size.width * scene.jsonLoad))
                }
            }
            .frame(height: 7)
        }
    }

    // MARK: Overlays

    private var gridOverlay: some View {
        Canvas { ctx, size in
            let step: CGFloat = 24
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: .init(x: x, y: 0))
                path.addLine(to: .init(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: .init(x: 0, y: y))
                path.addLine(to: .init(x: size.width, y: y))
                y += step
            }
            ctx.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.6)
            let inset = size.width * 0.06
            var guides = Path()
            guides.move(to: .init(x: inset, y: 0))
            guides.addLine(to: .init(x: inset, y: size.height))
            guides.move(to: .init(x: size.width - inset, y: 0))
            guides.addLine(to: .init(x: size.width - inset, y: size.height))
            ctx.stroke(guides, with: .color(.cyan.opacity(0.14)), lineWidth: 1)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func figmaMarquee(in size: CGSize) -> some View {
        let focus = scene.focus
        let rect: (CGFloat, CGFloat, CGFloat, CGFloat) = {
            switch focus {
            case .title, .tabs: return (0.55, 0.12, 0.40, 0.06)
            case .guide: return (0.05, 0.20, 0.90, 0.08)
            case .wire, .load, .reel: return (0.04, 0.30, 0.92, 0.42)
            case .paint: return (0.06, 0.30, 0.78, 0.40)
            case .rhythm: return (0.05, 0.68, 0.90, 0.14)
            default: return (0.08, 0.14, 0.84, 0.08)
            }
        }()
        let w = size.width * rect.2
        let h = size.height * rect.3
        let x = size.width * rect.0
        let y = size.height * rect.1
        return RoundedRectangle(cornerRadius: 8)
            .stroke(Color.cyan.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
            .frame(width: w, height: h)
            .overlay {
                ZStack {
                    handle.position(x: 0, y: 0)
                    handle.position(x: w, y: 0)
                    handle.position(x: 0, y: h)
                    handle.position(x: w, y: h)
                }
            }
            .position(x: x + w / 2, y: y + h / 2)
    }

    private var wavePaletteHUD: some View {
        let colors: [Color] = [
            theme.currentAccentTintColor,
            TaikaMasteryTokens.continueSky,
            TaikaMasteryTokens.green
        ]
        let labels = ["accent", "in progress", "done"]
        return VStack(alignment: .leading, spacing: 10) {
            Text("WAVE PALETTE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .tracking(0.8)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(colors[i])
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(i == scene.paletteIndex ? 0.95 : 0.15), lineWidth: i == scene.paletteIndex ? 2.5 : 1)
                            )
                            .shadow(color: colors[i].opacity(i == scene.paletteIndex ? 0.55 : 0), radius: 8)
                        Text(labels[i])
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(i == scene.paletteIndex ? 0.85 : 0.4))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 16)
        .padding(.bottom, 120)
    }

    private func wavePaintOverlay(in size: CGSize) -> some View {
        let tint: Color = {
            switch scene.paletteIndex {
            case 1: return TaikaMasteryTokens.continueSky
            case 2: return TaikaMasteryTokens.green
            default: return theme.currentAccentTintColor
            }
        }()
        let cardW = min(300.0, size.width - 48)
        let cardH: CGFloat = 360
        let x = Theme.Layout.pageHorizontal
        let y = size.height * 0.30
        return ZStack(alignment: .topLeading) {
            // Progressive wave draw on top of the focus card area
            Canvas { context, canvasSize in
                let progress = Double(scene.waveDraw)
                let waves = 4
                for i in 0..<waves {
                    let reveal = min(1, max(0, (progress - Double(i) * 0.12) / 0.55))
                    guard reveal > 0.02 else { continue }
                    let t = Double(i) / 3.0
                    var path = Path()
                    let y0 = canvasSize.height * (0.35 + t * 0.45)
                    let amp = 8.0 + t * 10.0
                    let maxX = canvasSize.width * reveal
                    var xPos: CGFloat = 0
                    while xPos <= maxX {
                        let xn = Double(xPos / max(canvasSize.width, 1))
                        let yPos = y0 + sin((xn * 2.2 + t + progress) * .pi * 2) * amp
                        let pt = CGPoint(x: xPos, y: yPos)
                        if xPos == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                        xPos += 5
                    }
                    context.stroke(
                        path,
                        with: .color(tint.opacity(0.35 + (1 - t) * 0.35)),
                        lineWidth: 1.6
                    )
                }
            }
            .frame(width: cardW, height: cardH)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
            .padding(.leading, x)
            .padding(.top, y)

            Text("draw waves")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .padding(.leading, x + 12)
                .padding(.top, y - 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white)
            .frame(width: 7, height: 7)
            .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.cyan, lineWidth: 1))
    }

    private func figmaPropertyChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.15, green: 0.35, blue: 0.55).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 108)
            .padding(.trailing, 14)
    }

    private func workChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.65))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 56)
    }

    private func cursorLayer(in size: CGSize) -> some View {
        let x = size.width * scene.cursorX
        let y = size.height * scene.cursorY
        return ZStack {
            if scene.click > 0.05 {
                Circle()
                    .stroke(Color.white.opacity(0.35 * scene.click), lineWidth: 1.5)
                    .frame(width: 28 + 18 * scene.click, height: 28 + 18 * scene.click)
                    .position(x: x, y: y)
            }
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .scaleEffect(1 - 0.08 * scene.click)
                .position(x: x + 6, y: y + 8)
        }
    }

    private var closeButton: some View {
        Button(action: closeSession) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private var controlsOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                Slider(value: Binding(
                    get: { clock.t },
                    set: { clock.scrub($0) }
                ), in: 0...clock.duration)
                HStack {
                    Button(clock.isPlaying ? "Pause" : "Play") { clock.toggle() }
                    Button("Restart") { clock.restart() }
                    Spacer()
                    Text(String(format: "%.1fs", clock.t))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .font(.system(size: 14, weight: .semibold))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.82)))
            .padding(16)
        }
    }
}

#endif
