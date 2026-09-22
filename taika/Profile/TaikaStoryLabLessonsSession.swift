#if DEBUG

//
//  TaikaStoryLabLessonsSession.swift
//  taika
//
//  Story Lab — Lessons / Steps / Gradebook assembly (~68s).
//  Working process only: enter from course card → scatter on grid →
//  snap real Lessons chrome → paint → materials chip → assemble StepView →
//  play «запомнил» / избранное → unlock → morph to ЗАЧЁТКА.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabLessonsClock: ObservableObject {
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

enum StoryLabLessonsFocus: Equatable {
    case entry, scatter, snap, paint, materials, steps, unlock, gradebook, settle
}

struct StoryLabLessonsScene: Equatable {
    var grid: CGFloat
    var entryCard: CGFloat
    var entryZoom: CGFloat
    var scatter: CGFloat
    var dock: CGFloat
    var lessonsChrome: CGFloat
    var reel: CGFloat
    var paint: CGFloat
    var materialsPicker: CGFloat
    var materialsIndex: Int // 0 Уроки, 1 Лайфхаки
    var stepsPage: CGFloat
    var stepsDock: CGFloat
    /// Active card in StepView coverflow (0-based learnable cards).
    var stepIndex: Int
    var stepLearned: Set<Int>
    var stepFavorites: Set<Int>
    var unlock: CGFloat
    var gradebook: CGFloat
    var gradeScore: Int
    var ready: CGFloat
    var marquee: CGFloat
    var copyFlash: CGFloat
    var figmaChip: String?
    var focus: StoryLabLessonsFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var actionChip: String?

    static func at(_ t: TimeInterval) -> StoryLabLessonsScene {
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

        // 0–5   enter from CourseLessonCard
        // 5–12  scatter empty pieces on grid
        // 12–20 snap → real Lessons chrome + full reel
        // 20–25 paint colors chik-chik
        // 25–32 materials chip · Уроки ↔ Лайфхаки
        // 32–39 Steps: scatter → snap real layout
        // 39–48 Steps play: Запомнил → next · ♥ на 2-й · Запомнил
        // 48–54 unlock reinforcement
        // 54–64 morph ЗАЧЁТКА
        // 64–68 settle

        let focus: StoryLabLessonsFocus = {
            switch t {
            case ..<5: return .entry
            case ..<12: return .scatter
            case ..<20: return .snap
            case ..<25: return .paint
            case ..<32: return .materials
            case ..<48: return .steps
            case ..<54: return .unlock
            case ..<64: return .gradebook
            default: return .settle
            }
        }()

        let materialsIndex: Int = {
            if t < 26.5 { return 0 }
            if t < 30.5 { return 1 }
            return 0
        }()

        // Step play script (cardItems = non-tip only → 4 cards)
        // t<40.5: card 0 · tap Запомнил → learn 0, advance 1
        // t<43.2: card 1 · tap ♥ → fav 1
        // t<46.0: card 1 · tap Запомнил → learn 0+1, advance 2
        let stepIndex: Int = {
            if t < 40.5 { return 0 }
            if t < 46.0 { return 1 }
            return 2
        }()
        let stepLearned: Set<Int> = {
            if t < 40.5 { return [] }
            if t < 46.0 { return [0] }
            return [0, 1]
        }()
        let stepFavorites: Set<Int> = {
            if t < 43.2 { return [] }
            return [1]
        }()

        let actionChip: String? = {
            if t >= 0.4 && t < 4.5 { return "Open · CourseLessonCard → Lessons" }
            if t >= 5.5 && t < 11.0 { return "Scatter · layout pieces" }
            if t >= 12.0 && t < 18.5 { return "Snap · LessonsView chrome" }
            if t >= 20.0 && t < 24.5 { return "Paint · status / slots" }
            if t >= 25.5 && t < 28.0 { return "Chip · Материалы курса" }
            if t >= 28.0 && t < 31.5 { return "Switch · Уроки ↔ Лайфхаки" }
            if t >= 32.5 && t < 36.5 { return "Scatter · StepView pieces" }
            if t >= 37.0 && t < 39.5 { return "Snap · StepView layout" }
            if t >= 40.0 && t < 42.2 { return "Tap · Запомнил → next" }
            if t >= 42.5 && t < 45.0 { return "Favorite · card #2" }
            if t >= 45.5 && t < 47.5 { return "Tap · Запомнил → next" }
            if t >= 48.5 && t < 53.0 { return "Unlock · reinforcement" }
            if t >= 54.5 && t < 62.5 { return "Transform · ЗАЧЁТКА" }
            return nil
        }()

        let figmaChip: String? = {
            if t >= 1.5 && t < 4.0 { return "Instance · CourseLessonCard" }
            if t >= 7.0 && t < 11.0 { return "Frames · scatter ×6" }
            if t >= 13.0 && t < 17.0 { return "Component · LSLessonReels" }
            if t >= 21.0 && t < 24.0 { return "Fill · accent waves" }
            if t >= 26.0 && t < 29.0 { return "Component · AppInlineFilterPicker" }
            if t >= 29.0 && t < 31.5 { return "Variant · Лайфхаки reel" }
            if t >= 34.0 && t < 37.5 { return "Component · SDStepCard" }
            if t >= 38.0 && t < 40.0 { return "Component · SDStepProgress" }
            if t >= 40.5 && t < 42.5 { return "Action · Запомнил" }
            if t >= 43.0 && t < 45.0 { return "Action · Favorite" }
            if t >= 45.5 && t < 47.5 { return "Action · Запомнил" }
            if t >= 56.0 && t < 61.0 { return "Component · LSCompletedTrainingHero" }
            return nil
        }()

        let (cx, cy): (CGFloat, CGFloat) = {
            switch focus {
            case .entry: return (0.50, 0.48)
            case .scatter: return (0.35, 0.55)
            case .snap: return (0.55, 0.42)
            case .paint: return (0.60, 0.45)
            case .materials: return (0.78, 0.34)
            case .steps:
                if t < 39.0 { return (0.50, 0.50) }
                if t < 42.5 { return (0.70, 0.58) } // Запомнил
                if t < 45.0 { return (0.64, 0.38) } // ♥ on card #2
                return (0.70, 0.58)                 // Запомнил again
            case .unlock: return (0.72, 0.22)
            case .gradebook: return (0.45, 0.40)
            case .settle: return (0.50, 0.90)
            }
        }()
        let prev: (CGFloat, CGFloat) = {
            let e = max(0, t - 0.35)
            switch e {
            case ..<5: return (0.50, 0.48)
            case ..<12: return (0.35, 0.55)
            case ..<20: return (0.55, 0.42)
            case ..<25: return (0.60, 0.45)
            case ..<32: return (0.78, 0.34)
            case ..<39: return (0.50, 0.50)
            case ..<42.5: return (0.70, 0.58)
            case ..<45: return (0.64, 0.38)
            case ..<48: return (0.70, 0.58)
            case ..<54: return (0.72, 0.22)
            case ..<64: return (0.45, 0.40)
            default: return (0.50, 0.90)
            }
        }()
        let moveStart: TimeInterval = {
            switch focus {
            case .entry: return 0
            case .scatter: return 5
            case .snap: return 12
            case .paint: return 20
            case .materials: return 25
            case .steps:
                if t < 39 { return 32 }
                if t < 42.5 { return 39 }
                if t < 45 { return 42.5 }
                return 45
            case .unlock: return 48
            case .gradebook: return 54
            case .settle: return 64
            }
        }()
        let move = min(1, max(0, (t - moveStart) / 0.28))

        let clickTimes: [TimeInterval] = [
            2.2, 6.5, 9.0, 13.0, 16.0, 21.5, 24.0,
            26.8, 28.5, 30.8, 34.0, 38.0,
            40.5, 43.2, 46.0,
            50.0, 56.0, 61.0, 65.5
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.1 { return CGFloat(1 - d / 0.1) }
            }
            return 0
        }()

        return StoryLabLessonsScene(
            grid: ramp(0.3, 1.8) * (1 - ramp(64.5, 67.5)),
            entryCard: ramp(0.2, 1.2) * (1 - ramp(4.2, 5.5)),
            entryZoom: ramp(3.2, 5.0),
            scatter: ramp(5.2, 7.5) * (1 - ramp(18.5, 20.5)),
            dock: ramp(12.0, 17.5),
            lessonsChrome: ramp(13.0, 16.0) * (1 - ramp(32.0, 34.0)),
            reel: ramp(14.5, 17.5) * (1 - ramp(32.0, 34.5)),
            paint: ramp(20.0, 23.0),
            materialsPicker: ramp(24.5, 26.5),
            materialsIndex: materialsIndex,
            stepsPage: ramp(32.5, 34.5) * (1 - ramp(53.0, 55.0)),
            stepsDock: ramp(35.5, 39.0),
            stepIndex: stepIndex,
            stepLearned: stepLearned,
            stepFavorites: stepFavorites,
            unlock: ramp(48.5, 51.5),
            gradebook: ramp(54.0, 57.5),
            gradeScore: Int(round(72 * Double(ramp(55.5, 62.0)))),
            ready: ramp(65.0, 67.0),
            marquee: max(
                pulse(6.0, 7.5, 10.5),
                pulse(13.5, 15.0, 17.5),
                pulse(21.0, 22.5, 24.0),
                pulse(26.5, 28.0, 30.5),
                pulse(35.0, 37.0, 39.5),
                pulse(40.5, 41.2, 42.2),
                pulse(43.2, 43.9, 45.0),
                pulse(46.0, 46.7, 47.8),
                pulse(56.0, 57.5, 61.0)
            ),
            copyFlash: max(pulse(14.0, 15.2, 17.0), pulse(36.0, 37.2, 39.0)),
            figmaChip: figmaChip,
            focus: focus,
            cursorX: lerp(prev.0, cx, move),
            cursorY: lerp(prev.1, cy, move),
            click: click,
            actionChip: actionChip
        )
    }
}

// MARK: - Data

private let storyLabLessonItems: [LS.Item] = [
    .init(id: "sl-l0", index: 1, title: "приветствия", subtitle: "саватди · вежливость", durationMinutes: 12, isPro: false, status: .completed, progress: 1, cardCount: 8, favoriteCount: 0, learnedCardCount: 8, errorCardCount: 0, reinforcementScore: 60, reinforcementSessionCount: 1, speakerScore: 60),
    .init(id: "sl-l1", index: 2, title: "в кафе · заказ", subtitle: "меню · счёт · острота", durationMinutes: 14, isPro: false, status: .inProgress, progress: 0.42, cardCount: 10, favoriteCount: 3, learnedCardCount: 4, errorCardCount: 2, reinforcementScore: 63, reinforcementSessionCount: 1, speakerScore: 63),
    .init(id: "sl-l2", index: 3, title: "на рынке", subtitle: "торг · веса · вкус", durationMinutes: 13, isPro: false, status: .completed, progress: 1, cardCount: 9, favoriteCount: 0, learnedCardCount: 9, errorCardCount: 0, reinforcementScore: 70, reinforcementSessionCount: 2, speakerScore: 68),
    .init(id: "sl-l3", index: 4, title: "такси и дорога", subtitle: "куда · сколько · стоп", durationMinutes: 11, isPro: false, status: .locked, progress: nil, cardCount: 7, favoriteCount: 0),
    .init(id: "sl-l4", index: 5, title: "в храме", subtitle: "этикет · дарение", durationMinutes: 10, isPro: false, status: .locked, progress: nil, cardCount: 6, favoriteCount: 2),
    .init(id: "sl-l5", index: 6, title: "у врача", subtitle: "боль · аптека", durationMinutes: 12, isPro: true, status: .locked, progress: nil, cardCount: 8),
    .init(id: "sl-l6", index: 7, title: "семья и дом", subtitle: "родные · визит", durationMinutes: 13, isPro: false, status: .locked, progress: nil, cardCount: 9),
    .init(id: "sl-l7", index: 8, title: "финальный диалог", subtitle: "связный разговор", durationMinutes: 15, isPro: false, status: .inProgress, progress: 0.42, cardCount: 11, favoriteCount: 0, learnedCardCount: 3, errorCardCount: 2, reinforcementScore: 55, reinforcementSessionCount: 1, speakerScore: 58),
]

private let storyLabPaintedLessons: [LS.Item] = storyLabLessonItems.enumerated().map { i, item in
    let status: LS.Status = {
        switch i % 3 {
        case 0: return .completed
        case 1: return .inProgress
        default: return item.status
        }
    }()
    return LS.Item(
        id: item.id,
        index: item.index,
        title: item.title,
        subtitle: item.subtitle,
        durationMinutes: item.durationMinutes,
        isPro: item.isPro,
        status: status,
        progress: status == .completed ? 1 : (status == .inProgress ? 0.42 : nil),
        cardCount: item.cardCount,
        favoriteCount: item.favoriteCount,
        learnedCardCount: status == .completed ? (item.cardCount ?? 8) : item.learnedCardCount,
        errorCardCount: status == .completed && (i == 1 || i == 7) ? 2 : item.errorCardCount,
        reinforcementScore: status == .completed ? (55 + i * 3) : item.reinforcementScore,
        reinforcementSessionCount: item.reinforcementSessionCount,
        speakerScore: status == .completed ? (58 + i * 2) : item.speakerScore
    )
}

private let storyLabStepItems: [SDStepItem] = [
    .init(kind: .word, titleRU: "Привет", subtitleTH: "สวัสดี", phonetic: "са-ват-ди́"),
    .init(kind: .phrase, titleRU: "Счёт, пожалуйста", subtitleTH: "เช็คบิล", phonetic: "чек-бин"),
    .init(kind: .word, titleRU: "Спасибо", subtitleTH: "ขอบคุณ", phonetic: "коп-ку́н"),
    .init(kind: .word, titleRU: "Вода", subtitleTH: "น้ำ", phonetic: "на́м"),
    .init(kind: .tip, titleRU: "Тон", subtitleTH: "Улыбка + мягкий тон важнее идеального произношения.", phonetic: ""),
]

private let storyLabLifehackItems: [SDStepItem] = [
    .init(kind: .tip, titleRU: "Острота", subtitleTH: "Скажи «не остро» заранее — в Тае острота часто сюрприз.", phonetic: ""),
    .init(kind: .tip, titleRU: "Счёт", subtitleTH: "«Чек бин» + улыбка работает лучше, чем жесты.", phonetic: ""),
    .init(kind: .tip, titleRU: "Вежливость", subtitleTH: "Кхап/кха в конце фразы — мгновенный плюс к тону.", phonetic: ""),
]

private let storyLabMaterialsTitles = ["Уроки", "Лайфхаки"]

private let storyLabLessonSubtitle = "меню · заказ · счёт — живой сценарий в кафе"

// MARK: - Session

struct StoryLabEditorLessonsSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabLessonsClock()
    @State private var showControls = false
    @State private var listFocus: LSReinforcementListFocus = .lessons
    @State private var stepActiveIndex: Int = 0

    private var scene: StoryLabLessonsScene { .at(clock.t) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PD.ColorToken.background.ignoresSafeArea()

                gridOverlay
                    .opacity(scene.grid)
                    .allowsHitTesting(false)

                // Global chrome always on (Identity/Architecture already shipped)
                VStack(spacing: 0) {
                    brandHeader
                    ZStack {
                        if scene.entryCard > 0.05 {
                            entryFromCourseCard
                                .opacity(scene.entryCard)
                                .scaleEffect(1 + 0.18 * scene.entryZoom)
                                .allowsHitTesting(false)
                        }

                        if scene.lessonsChrome > 0.05 || scene.reel > 0.05 {
                            lessonsAssembledPage
                                .opacity(max(scene.lessonsChrome, scene.reel) * (1 - scene.stepsPage * 0.95) * (1 - scene.gradebook * 0.15))
                                .allowsHitTesting(false)
                        }

                        if scene.stepsPage > 0.05 {
                            stepsAssembledPage
                                .opacity(scene.stepsPage)
                                .allowsHitTesting(false)
                        }

                        if scene.gradebook > 0.05 {
                            gradebookPage
                                .opacity(scene.gradebook)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ToolBar(selectedTab: .constant(1))
                        .allowsHitTesting(false)
                        .padding(.bottom, 2)
                }

                if scene.scatter > 0.05, scene.dock < 0.98 {
                    scatterPieces(in: geo.size, mode: .lessons)
                        .opacity(max(scene.scatter, 1 - scene.dock))
                        .allowsHitTesting(false)
                }

                if scene.stepsPage > 0.05, scene.stepsDock < 0.95 {
                    scatterPieces(in: geo.size, mode: .steps)
                        .opacity((1 - scene.stepsDock) * scene.stepsPage)
                        .allowsHitTesting(false)
                }

                if scene.marquee > 0.05 {
                    figmaMarquee(in: geo.size).opacity(scene.marquee).allowsHitTesting(false)
                }
                if scene.copyFlash > 0.05 {
                    copyToast.opacity(scene.copyFlash).allowsHitTesting(false)
                }
                if let fig = scene.figmaChip {
                    figmaPropertyChip(fig).allowsHitTesting(false)
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
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: scene.dock)
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: scene.stepsDock)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: scene.stepIndex)
            .animation(.easeOut(duration: 0.22), value: scene.paint)
            .animation(.easeOut(duration: 0.22), value: scene.stepLearned)
            .animation(.easeOut(duration: 0.22), value: scene.stepFavorites)
            .animation(.easeOut(duration: 0.28), value: scene.gradebook)
        }
        .statusBarHidden(false)
        .navigationBarHidden(true)
        .onAppear {
            clock.start()
            stepActiveIndex = scene.stepIndex
        }
        .onDisappear { clock.stop() }
        .onChange(of: scene.stepIndex) { _, next in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                stepActiveIndex = next
            }
        }
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

    // MARK: Chrome

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

    // MARK: 1) Entry from course card

    private var entryFromCourseCard: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)
            CourseLessonCard(
                title: "в кафе",
                subtitle: "меню · заказ · счёт",
                lessonsCount: 8,
                durationText: "≈ 42 мин",
                statusKind: .inProgress,
                courseCategory: "Тайский для жизни",
                brandText: "taikAAA",
                sectionChrome: .none,
                accentTreatment: .taikaValues(
                    fill: AnyShapeStyle(TaikaMasteryTokens.continueSkyGradient),
                    glow: TaikaMasteryTokens.continueSkyGlow
                ),
                primaryCTA: .resume,
                scale: .xs,
                showFavorite: true,
                showConsole: true,
                completionFraction: 0.42,
                showsInlineProgress: true
            )
            .frame(width: 300, height: 384)
            .environmentObject(theme)
            .overlay(alignment: .bottom) {
                if scene.entryZoom > 0.2 {
                    Text("tap → LessonsView")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                        .offset(y: 18)
                        .opacity(scene.entryZoom)
                }
            }
            Spacer()
        }
    }

    // MARK: 2) Lessons assembled (real chrome)

    private var lessonsAssembledPage: some View {
        let items = scene.paint > 0.55 ? storyLabPaintedLessons : storyLabLessonItems
        let slots: [Double] = {
            if scene.paint > 0.55 {
                return [1, 0.42, 1, 0, 0, 0, 0, 0.42]
            }
            return Array(repeating: 0, count: 8)
        }()

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Real Lessons back + hero (as in LessonsView)
                Button(action: {}) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("в курсы")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, CD.Spacing.screen)
                .opacity(scene.lessonsChrome)

                LSCourseHeroCopy(title: "в кафе", subtitle: storyLabLessonSubtitle)
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.top, 2)
                    .opacity(scene.lessonsChrome)

                LSProgressSlotsStrip(
                    slots: slots,
                    selectedIndex: 1,
                    isCompletedCourse: false
                )
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.top, 16)
                .opacity(scene.lessonsChrome)

                // Real materials chip: Уроки ↔ Лайфхаки
                if scene.materialsPicker > 0.05 || scene.lessonsChrome > 0.7 {
                    HStack(spacing: 10) {
                        Text("Материалы курса")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .textCase(.uppercase)
                            .kerning(0.5)
                        Spacer(minLength: 8)
                        AppInlineFilterPicker(
                            titles: storyLabMaterialsTitles,
                            selectedIndex: scene.materialsIndex,
                            selectionAccent: AnyShapeStyle(PD.ColorToken.textSecondary)
                        ) { _ in }
                    }
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.top, 12)
                    .opacity(max(scene.materialsPicker, scene.lessonsChrome * 0.85))
                }

                // Unlock affordances on chrome
                if scene.unlock > 0.05 {
                    HStack(spacing: 14) {
                        Label("игра", systemImage: "gamecontroller.fill")
                        Label("спикер", systemImage: "mic.fill")
                        Spacer()
                        Text("unlocked")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(TaikaMasteryTokens.greenGlow)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.top, 10)
                    .opacity(scene.unlock)
                }

                if scene.reel > 0.05 {
                    if scene.materialsIndex == 1 {
                        lifehacksReel
                            .id("sl-lifehacks")
                            .padding(.top, 14)
                            .opacity(scene.reel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        LSLessonReels(
                            "УРОКИ",
                            items: items,
                            collapsible: false,
                            startExpanded: true,
                            onTap: { _ in },
                            onTapAccessory: scene.unlock > 0.35 ? { _ in } : nil,
                            onFavorite: { _ in },
                            onSpeaker: scene.unlock > 0.35 ? { _ in } : nil,
                            selectedIndex: 1
                        )
                        .id("sl-lessons-\(scene.paint > 0.55)-\(Int(scene.unlock * 10))")
                        .padding(.top, 14)
                        .opacity(scene.reel)
                        .environmentObject(theme)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }

                Color.clear.frame(height: ToolBar.recommendedBottomInset + 20)
            }
            .padding(.top, 4)
            .animation(.spring(response: 0.32, dampingFraction: 0.88), value: scene.materialsIndex)
        }
    }

    private var lifehacksReel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LSSectionTitle("ЛАЙФХАКИ")
                Spacer(minLength: 8)
                Text("\(storyLabLifehackItems.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            .padding(.horizontal, CD.Spacing.screen)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CDLessonCarouselCanonical.spacing) {
                    ForEach(storyLabLifehackItems) { item in
                        StepLifehackCardVisual(
                            item: item,
                            label: "лайфхак",
                            size: CGSize(
                                width: CDLessonCarouselCanonical.cardWidth,
                                height: CDLessonCarouselCanonical.courseLessonCardHeight
                            ),
                            sectionChrome: .seps,
                            chromeStyle: .cards,
                            isFavorite: false
                        )
                        .environmentObject(theme)
                    }
                }
                .padding(.horizontal, Theme.Layout.pageHorizontal)
            }
            .frame(height: CDLessonCarouselCanonical.courseLessonCardHeight + 8)
        }
    }

    // MARK: 3) Real StepView layout

    private var stepsAssembledPage: some View {
        let cardItems = storyLabStepItems.filter { $0.kind != .tip }
        let learned = scene.stepLearned
        let favorites = scene.stepFavorites

        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("приветствия")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(PD.ColorToken.text)
                    Text("карточки урока")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, PD.Spacing.screen)
            .padding(.top, 8)
            .opacity(scene.stepsDock)

            Spacer(minLength: 6)

            if scene.stepsDock > 0.12 {
                SDStepCarousel(
                    title: "",
                    items: cardItems,
                    activeIndex: $stepActiveIndex,
                    learned: learned,
                    favorites: favorites,
                    isOverlay: false,
                    loop: false,
                    compactSection: true
                )
                .environmentObject(theme)
                .environment(\.taikaStepActionCaptions, true)
                .opacity(scene.stepsDock)
                .id("sl-step-carousel")
            } else {
                Color.clear.frame(height: CardDS.Metrics.stepCarouselSquareSide + 28)
            }

            Spacer(minLength: 6)

            SDStepProgress(
                total: cardItems.count,
                activeIndex: min(stepActiveIndex, max(0, cardItems.count - 1)),
                learned: learned,
                favorites: favorites,
                tipIndices: []
            )
            .opacity(scene.stepsDock)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 4) Gradebook

    private var gradebookPage: some View {
        let items = storyLabPaintedLessons.map {
            LS.Item(
                id: $0.id, index: $0.index, title: $0.title, subtitle: $0.subtitle,
                durationMinutes: $0.durationMinutes, isPro: $0.isPro, status: .completed,
                progress: 1, cardCount: $0.cardCount, favoriteCount: $0.favoriteCount,
                learnedCardCount: $0.cardCount ?? 8,
                errorCardCount: ($0.id == "sl-l1" || $0.id == "sl-l7") ? 2 : 0,
                reinforcementScore: $0.reinforcementScore ?? 60,
                reinforcementSessionCount: 2,
                speakerScore: $0.speakerScore ?? 60
            )
        }
        let weakIds: Set<String> = ["sl-l1", "sl-l7"]
        let selected: Set<String> = scene.gradeScore >= 48 ? weakIds : []
        let stableScore = 72
        let stats = LSCourseStats(
            completedLessons: 8, totalLessons: 8, learnedWords: 64, favorites: 7,
            streakDays: 3, timeMinutes: 48, gameCoveredCards: 28, gameSessions: 5,
            reinforcementScore: stableScore,
            reinforcementSkills: [
                LSReinforcementSkill(id: "speaker", title: "Спикер", subtitle: "Произношение и тоны", icon: "mic.fill", score: 62, sessions: 3, isSpeaker: true),
                LSReinforcementSkill(id: "game", title: "Игра", subtitle: "Закрепление карточек", icon: "gamecontroller.fill", score: 57, sessions: 2)
            ]
        )

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                    Text("в курсы")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .padding(.horizontal, CD.Spacing.screen)

                Text("в кафе")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, CD.Spacing.screen)

                LSCompletedTrainingHero(
                    stats: stats,
                    focusCaption: selected.isEmpty ? "8 уроков · курс закрыт" : "2 к закреплению",
                    focusCardCount: selected.isEmpty ? 42 : 8,
                    totalLessons: 8,
                    weakCount: weakIds.count,
                    onSpeaker: {},
                    onGamePark: {},
                    selectedWeakCount: selected.count
                )
                .id("sl-grade-hero-stable")
                .padding(.horizontal, CD.Spacing.screen)

                LSCompletedLessonList(
                    items: items,
                    selectedIds: selected,
                    weakIds: weakIds,
                    listFocus: $listFocus,
                    selectedCardCount: selected.count * 4,
                    selectedErrorCardCount: selected.count * 2,
                    scores: Dictionary(uniqueKeysWithValues: items.compactMap { i in
                        guard let s = i.reinforcementScore else { return nil }
                        return (i.id, s)
                    }),
                    courseSessionCount: 5,
                    onToggle: { _ in },
                    sectionTitle: "УРОКИ КУРСА"
                )

                Color.clear.frame(height: ToolBar.recommendedBottomInset + 16)
            }
            .padding(.top, 6)
        }
        .overlay(alignment: .bottom) {
            if scene.ready > 0.05 {
                Text("Lessons · Steps · Gradebook · locked")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(.bottom, 88)
                    .opacity(scene.ready)
            }
        }
    }

    // MARK: Scatter pieces

    private enum ScatterMode { case lessons, steps }

    private func scatterPieces(in size: CGSize, mode: ScatterMode) -> some View {
        let dock = mode == .lessons ? scene.dock : scene.stepsDock
        let frames: [(String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = {
            switch mode {
            case .lessons:
                return [
                    ("BACK", 0.70, 0.78, 0.06, 0.14, 0.28, 0.04),
                    ("TITLE", 0.08, 0.72, 0.06, 0.20, 0.50, 0.06),
                    ("SLOTS", 0.55, 0.82, 0.06, 0.30, 0.88, 0.08),
                    ("CARD A", 0.05, 0.55, 0.05, 0.42, 0.42, 0.28),
                    ("CARD B", 0.60, 0.58, 0.48, 0.42, 0.42, 0.28),
                    ("ICONS", 0.78, 0.35, 0.72, 0.22, 0.20, 0.05),
                ]
            case .steps:
                return [
                    ("TITLE", 0.10, 0.70, 0.06, 0.12, 0.45, 0.05),
                    ("CARD", 0.55, 0.55, 0.12, 0.28, 0.76, 0.36),
                    ("PROGRESS", 0.20, 0.85, 0.06, 0.78, 0.88, 0.10),
                    ("NEXT", 0.75, 0.75, 0.70, 0.55, 0.18, 0.05),
                ]
            }
        }()

        return ZStack {
            ForEach(Array(frames.enumerated()), id: \.offset) { i, f in
                let u = min(1, max(0, (dock - CGFloat(i) * 0.06) / 0.5))
                let x = f.1 + (f.3 - f.1) * u
                let y = f.2 + (f.4 - f.2) * u
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.cyan.opacity(0.06))
                    )
                    .overlay(
                        Text(f.0)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.cyan.opacity(0.9))
                            .padding(6),
                        alignment: .topLeading
                    )
                    .frame(width: size.width * f.5, height: size.height * f.6)
                    .position(
                        x: size.width * x + size.width * f.5 / 2,
                        y: size.height * y + size.height * f.6 / 2
                    )
            }
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
    }

    private func figmaMarquee(in size: CGSize) -> some View {
        let rect: (CGFloat, CGFloat, CGFloat, CGFloat) = {
            switch scene.focus {
            case .entry: return (0.12, 0.28, 0.76, 0.42)
            case .scatter, .snap: return (0.04, 0.18, 0.92, 0.55)
            case .paint: return (0.04, 0.38, 0.92, 0.38)
            case .materials: return (0.08, 0.28, 0.84, 0.42)
            case .steps: return (0.06, 0.20, 0.88, 0.58)
            case .unlock: return (0.55, 0.18, 0.40, 0.08)
            case .gradebook: return (0.04, 0.16, 0.92, 0.62)
            default: return (0.1, 0.15, 0.8, 0.1)
            }
        }()
        let w = size.width * rect.2
        let h = size.height * rect.3
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
            .position(x: size.width * rect.0 + w / 2, y: size.height * rect.1 + h / 2)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white)
            .frame(width: 7, height: 7)
            .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.cyan, lineWidth: 1))
    }

    private var copyToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.doc.fill")
            Text(scene.focus == .steps ? "Paste · SDStepCard" : "Paste · Lesson reel ×8")
                .font(.system(size: 12, weight: .semibold))
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.black.opacity(0.78)).overlay(Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 1)))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 120)
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
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
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
            .background(Capsule().fill(Color.black.opacity(0.65)).overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)))
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
                Slider(value: Binding(get: { clock.t }, set: { clock.scrub($0) }), in: 0...clock.duration)
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
