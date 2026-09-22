#if DEBUG

//
//  TaikaStoryLabFavoritesSession.swift
//  taika
//
//  Story Lab — Избранное + Словарь (~60s).
//  Один mockup: сборка страницы → list/grid → unlike →
//  переключение на Словарь → боковой drawer → Тренировать / Закрепить.
//  Behind-the-scenes: grab / drop / click-clack.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabFavoritesClock: ObservableObject {
    @Published var t: TimeInterval = 0
    @Published var isPlaying = true
    let duration: TimeInterval = 60
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

enum StoryLabFavFocus: Equatable {
    case void, shell, cards, viewFlip, unlike, tabDict, dictCards, drawer, actions, settle
}

enum StoryLabFavViewMode: Equatable {
    case list, grid
}

struct StoryLabFavPhrase: Equatable, Identifiable {
    var id: String
    var phonetic: String
    var meaning: String
    var path: String
}

struct StoryLabFavoritesScene: Equatable {
    var bg: CGFloat
    var grid: CGFloat
    var headerDock: CGFloat
    var tabsDock: CGFloat
    var modeDock: CGFloat
    var summaryDock: CGFloat
    var cardsDock: CGFloat
    var cardCount: Int
    var viewMode: StoryLabFavViewMode
    var unlikeProgress: CGFloat
    var removedCard: Bool
    var isDictionary: Bool
    var titleType: CGFloat
    var drawer: CGFloat
    var drawerScrim: CGFloat
    var drawerActions: CGFloat
    var selectMode: Bool
    var trainCTA: CGFloat
    var grab: CGFloat
    var ready: CGFloat
    var focus: StoryLabFavFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var actionChip: String?
    var figmaChip: String?
    var editorTag: String?

    static func at(_ t: TimeInterval) -> StoryLabFavoritesScene {
        func ramp(_ a: TimeInterval, _ b: TimeInterval) -> CGFloat {
            guard b > a else { return t >= b ? 1 : 0 }
            return CGFloat(min(1, max(0, (t - a) / (b - a))))
        }
        func snap(_ a: TimeInterval, _ b: TimeInterval) -> CGFloat {
            ramp(a, min(b, a + 0.4))
        }
        func pulse(_ a: TimeInterval, _ peak: TimeInterval, _ b: TimeInterval) -> CGFloat {
            if t < a || t >= b { return 0 }
            return t < peak ? ramp(a, peak) : 1 - ramp(peak, b)
        }
        func lerp(_ a: CGFloat, _ b: CGFloat, _ u: CGFloat) -> CGFloat {
            a + (b - a) * min(1, max(0, u))
        }

        // 0–2.5  void → fill
        // 2.5–8  shell: header + tabs + view toggle
        // 8–15   grab heart cards (list)
        // 15–19  flip list → grid
        // 19–24  swipe unlike one card
        // 24–28  tab → Словарь
        // 28–34  dictionary cards
        // 34–42  side drawer «Мой словарь»
        // 42–50  Выбрать + Тренировать / Закрепить
        // 50–55  training CTA on page
        // 55–60  settle

        let focus: StoryLabFavFocus = {
            switch t {
            case ..<2.5: return .void
            case ..<8: return .shell
            case ..<15: return .cards
            case ..<19: return .viewFlip
            case ..<24: return .unlike
            case ..<28: return .tabDict
            case ..<34: return .dictCards
            case ..<42: return .drawer
            case ..<50: return .actions
            case ..<55: return .settle
            default: return .settle
            }
        }()

        let isDictionary = t >= 25.5
        let viewMode: StoryLabFavViewMode = t >= 16.5 ? .grid : .list
        let removedCard = t >= 22.5

        let cardCount: Int = {
            if t < 8.5 { return 0 }
            if focus == .unlike || (t >= 19 && t < 28) {
                let base = min(6, max(0, Int(ceil((t - 8.5) / 1.0))))
                return removedCard ? max(base - 1, 5) : base
            }
            if isDictionary {
                return min(5, max(0, Int(ceil((t - 28.2) / 0.9))))
            }
            return min(6, max(0, Int(ceil((t - 8.5) / 1.0))))
        }()

        let unlikeProgress: CGFloat = {
            if t < 19.5 { return 0 }
            if t < 21.5 { return ramp(19.5, 21.2) } // swipe open
            if t < 22.5 { return 1 }
            return 1 - ramp(22.5, 23.5) // card flies away
        }()

        let actionChip: String? = {
            if t >= 0.4 && t < 2.2 { return "Void · favorites canvas" }
            if t >= 3.0 && t < 7.5 { return "Grab · header + tabs" }
            if t >= 8.5 && t < 14.5 { return "Grab · ♥ cards" }
            if t >= 15.5 && t < 18.5 { return "Toggle · list / grid" }
            if t >= 19.5 && t < 23.5 { return "Swipe · Убрать лайк" }
            if t >= 24.5 && t < 27.5 { return "Tab · Словарь" }
            if t >= 28.5 && t < 33.5 { return "Grab · dictionary rows" }
            if t >= 34.5 && t < 41.0 { return "Drawer · Мой словарь" }
            if t >= 42.5 && t < 49.0 { return "CTA · Тренировать / Закрепить" }
            if t >= 50.0 && t < 54.0 { return "Page · Начать тренировку" }
            return nil
        }()

        let figmaChip: String? = {
            if t >= 3.5 && t < 7.0 { return "Screen · FavoriteView" }
            if t >= 9.0 && t < 14.0 { return "Component · FDFavCards" }
            if t >= 15.8 && t < 18.5 { return "Control · FavCardsViewMode" }
            if t >= 20.0 && t < 23.0 { return "Gesture · FavSwipeToRemove" }
            if t >= 25.0 && t < 27.5 { return "Tab · FavoriteScreenTab" }
            if t >= 35.0 && t < 41.0 { return "Panel · DictionaryQuickDrawer" }
            if t >= 43.0 && t < 48.5 { return "Actions · train + reinforce" }
            return nil
        }()

        let editorTag: String? = {
            if t >= 4.5 && t < 6.5 { return "Hand · drop tabs" }
            if t >= 9.5 && t < 13.0 { return "Hand · drop cards" }
            if t >= 16.2 && t < 18.0 { return "Click · grid mode" }
            if t >= 20.2 && t < 22.0 { return "Hand · swipe unlike" }
            if t >= 35.5 && t < 39.0 { return "Hand · slide drawer" }
            if t >= 44.0 && t < 48.0 { return "Hand · drop CTAs" }
            return nil
        }()

        func cursorAt(_ e: TimeInterval) -> (CGFloat, CGFloat) {
            switch e {
            case ..<2.5: return (0.50, 0.50)
            case ..<8:
                if e < 4.0 { return (0.88, 0.12) }
                if e < 5.5 { return (0.28, 0.12) }
                return (0.55, 0.18)
            case ..<15:
                let i = min(5, max(0, Int((e - 8.5) / 1.0)))
                return (0.50, 0.32 + CGFloat(i) * 0.08)
            case ..<19: return (0.82, 0.12)
            case ..<24:
                if e < 21.0 { return (0.72, 0.42) }
                return (0.88, 0.42)
            case ..<28: return (0.42, 0.18)
            case ..<34:
                let i = min(4, max(0, Int((e - 28.2) / 0.9)))
                return (0.48, 0.34 + CGFloat(i) * 0.08)
            case ..<42:
                if e < 36.0 { return (0.95, 0.50) }
                return (0.72, 0.45)
            case ..<50:
                if e < 44.0 { return (0.72, 0.22) }
                if e < 46.5 { return (0.55, 0.78) }
                return (0.55, 0.88)
            default: return (0.50, 0.78)
            }
        }

        let cxcy = cursorAt(t)
        let prev = cursorAt(max(0, t - 0.22))
        let moveStart: TimeInterval = {
            switch focus {
            case .void: return 0
            case .shell: return t < 4 ? 2.5 : (t < 5.5 ? 4.0 : 5.5)
            case .cards: return 8.0 + floor((t - 8.0) / 1.0) * 1.0
            case .viewFlip: return 15.0
            case .unlike: return t < 21 ? 19.0 : 21.0
            case .tabDict: return 24.0
            case .dictCards: return 28.0 + floor((t - 28.0) / 0.9) * 0.9
            case .drawer: return t < 36 ? 34.0 : 36.0
            case .actions: return t < 44 ? 42.0 : (t < 46.5 ? 44.0 : 46.5)
            case .settle: return 50.0
            }
        }()
        let move = min(1, max(0, (t - moveStart) / 0.26))

        let clickTimes: [TimeInterval] = [
            1.6, 3.5, 5.2, 6.5,
            9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
            16.4, 17.2,
            20.5, 22.2,
            25.8,
            29.0, 30.0, 31.0, 32.0, 33.0,
            35.5, 38.0,
            43.0, 45.0, 47.0,
            51.0, 56.5
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.09 { return CGFloat(1 - d / 0.09) }
            }
            return 0
        }()

        let grab: CGFloat = max(
            pulse(3.3, 3.7, 5.0),
            pulse(5.8, 6.3, 7.5),
            pulse(8.8, 9.3, 10.2),
            pulse(10.8, 11.3, 12.2),
            pulse(12.8, 13.3, 14.2),
            pulse(19.8, 20.5, 22.0),
            pulse(28.6, 29.2, 30.5),
            pulse(34.8, 35.6, 38.0),
            pulse(44.2, 44.8, 46.5),
            pulse(46.6, 47.2, 48.8)
        )

        return StoryLabFavoritesScene(
            bg: ramp(2.4, 4.0),
            grid: ramp(3.0, 4.8) * (1 - ramp(56.5, 59.5)),
            headerDock: snap(3.6, 4.4),
            tabsDock: snap(5.0, 5.9),
            modeDock: snap(6.2, 7.0),
            summaryDock: snap(7.2, 8.0),
            cardsDock: snap(8.8, 9.6),
            cardCount: cardCount,
            viewMode: viewMode,
            unlikeProgress: unlikeProgress,
            removedCard: removedCard,
            isDictionary: isDictionary,
            titleType: isDictionary ? ramp(25.5, 26.8) : ramp(3.8, 5.2),
            drawer: snap(35.2, 36.4) * (t >= 34 && t < 50 ? 1 : (t >= 50 ? 1 - ramp(49.5, 51.0) : 0)),
            drawerScrim: ramp(34.8, 36.0) * (1 - ramp(49.5, 51.0)),
            drawerActions: snap(44.0, 45.0),
            selectMode: t >= 42.8 && t < 49.5,
            trainCTA: snap(50.5, 51.5) * (t >= 50 ? 1 : 0),
            grab: grab,
            ready: ramp(55.5, 58.0),
            focus: focus,
            cursorX: lerp(prev.0, cxcy.0, move),
            cursorY: lerp(prev.1, cxcy.1, move),
            click: click,
            actionChip: actionChip,
            figmaChip: figmaChip,
            editorTag: editorTag
        )
    }
}

private let storyLabFavCards: [StoryLabFavPhrase] = [
    .init(id: "c0", phonetic: "са-ват-ди́", meaning: "привет", path: "База · Урок 1"),
    .init(id: "c1", phonetic: "коп-ку́н кхра́п", meaning: "спасибо", path: "База · Урок 1"),
    .init(id: "c2", phonetic: "май пен рай", meaning: "ничего", path: "База · Урок 2"),
    .init(id: "c3", phonetic: "а-рой ма̂к", meaning: "очень вкусно", path: "Еда · Урок 1"),
    .init(id: "c4", phonetic: "тао рай", meaning: "сколько стоит?", path: "Рынок · Урок 2"),
    .init(id: "c5", phonetic: "пай най", meaning: "куда идёшь?", path: "Город · Урок 1"),
]

private let storyLabDictCards: [StoryLabFavPhrase] = [
    .init(id: "d0", phonetic: "чек-бин", meaning: "счёт, пожалуйста", path: "Скажи сам"),
    .init(id: "d1", phonetic: "са-бай ди́ май", meaning: "как дела?", path: "Скажи сам"),
    .init(id: "d2", phonetic: "янг-гай", meaning: "как?", path: "Скажи сам"),
    .init(id: "d3", phonetic: "май ка̂о джай", meaning: "не понимаю", path: "Скажи сам"),
    .init(id: "d4", phonetic: "чу̂ай ду̂ай", meaning: "помоги, пожалуйста", path: "Скажи сам"),
]

// MARK: - Session

struct StoryLabEditorFavoritesSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabFavoritesClock()
    @State private var showControls = false

    private var scene: StoryLabFavoritesScene { .at(clock.t) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                PD.ColorToken.background
                    .ignoresSafeArea()
                    .opacity(scene.bg)

                gridOverlay
                    .opacity(scene.grid)
                    .allowsHitTesting(false)

                favoritesMockup(in: geo.size)
                    .opacity(Double(max(scene.bg, 0.001)))
                    .allowsHitTesting(false)

                if scene.drawerScrim > 0.05 {
                    Color.black.opacity(0.52 * Double(scene.drawerScrim))
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if scene.drawer > 0.02 {
                    dictionaryDrawer(in: geo.size)
                        .allowsHitTesting(false)
                }

                ToolBar(selectedTab: .constant(3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 2)
                    .opacity(Double(scene.bg))
                    .allowsHitTesting(false)

                if scene.grab > 0.08 {
                    grabMarquee(in: geo.size)
                        .opacity(scene.grab)
                        .allowsHitTesting(false)
                }
                if let fig = scene.figmaChip {
                    figmaPropertyChip(fig).allowsHitTesting(false)
                }
                if let tag = scene.editorTag {
                    editorTagChip(tag).allowsHitTesting(false)
                }
                if let chip = scene.actionChip {
                    workChip(chip).allowsHitTesting(false)
                }
                if scene.ready > 0.05 {
                    readyBadge.opacity(scene.ready).allowsHitTesting(false)
                }

                cursorLayer(in: geo.size).allowsHitTesting(false)

                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 14)
                    .padding(.top, 54)
                    .zIndex(20)

                if showControls { controlsOverlay }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: scene.viewMode)
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: scene.isDictionary)
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: scene.drawer)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: scene.cardCount)
            .animation(.easeOut(duration: 0.15), value: scene.selectMode)
        }
        .statusBarHidden(false)
        .navigationBarHidden(true)
        .onAppear { clock.start() }
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

    // MARK: placed

    private func placed<V: View>(
        _ view: V,
        dock: CGFloat,
        from dx: CGFloat,
        dy: CGFloat
    ) -> some View {
        let scatter = 1 - dock
        let lifting = scene.grab > 0.2 && scatter > 0.12 && scatter < 0.92
        return view
            .offset(x: dx * scatter, y: dy * scatter)
            .scaleEffect(lifting ? 1.04 : (0.94 + 0.06 * dock))
            .opacity(Double(min(1, dock * 1.4 + (lifting ? 0.3 : 0))))
            .overlay {
                if lifting {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.cyan.opacity(0.7), style: StrokeStyle(lineWidth: 1.3, dash: [5, 3]))
                        .padding(-5)
                }
            }
            .zIndex(lifting ? 8 : 0)
    }

    // MARK: Mockup

    private func favoritesMockup(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Theme.Layout.rootHeaderClearance * 0.35)

            // Header: title + view mode
            HStack(alignment: .center, spacing: 12) {
                placed(
                    Text(typedTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(PD.ColorToken.text)
                        .frame(maxWidth: .infinity, alignment: .leading),
                    dock: scene.headerDock,
                    from: -90, dy: -30
                )
                if scene.modeDock > 0.02 {
                    placed(viewModeToggle, dock: scene.modeDock, from: 70, dy: -24)
                }
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.top, 4)

            if scene.tabsDock > 0.02 {
                placed(tabBar, dock: scene.tabsDock, from: 0, dy: -36)
                    .padding(.top, 10)
                    .padding(.horizontal, CD.Spacing.screen)
            }

            if scene.summaryDock > 0.02 {
                placed(summaryRow, dock: scene.summaryDock, from: -40, dy: 20)
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.top, 10)
            }

            // Cards area
            Group {
                if scene.isDictionary {
                    dictCardsArea
                } else {
                    favCardsArea
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)

            if scene.trainCTA > 0.02 {
                placed(
                    DictionarySoftActionLabel(
                        icon: "mic.fill",
                        title: "Начать тренировку · \(max(scene.cardCount, 1))"
                    ),
                    dock: scene.trainCTA,
                    from: 0, dy: 70
                )
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, ToolBar.recommendedBottomInset + 18)
            } else {
                Spacer().frame(height: ToolBar.recommendedBottomInset + 8)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private var typedTitle: String {
        let full = scene.isDictionary ? "Словарь" : "Избранное"
        let n = max(0, Int(ceil(Double(full.count) * Double(max(scene.titleType, 0.15)))))
        return String(full.prefix(n))
    }

    private var tabBar: some View {
        // Matches FDFavoriteTabBar / AppInlineFilterPicker feel
        HStack(spacing: 0) {
            tabChip("Избранное", on: !scene.isDictionary)
            tabChip("Словарь", on: scene.isDictionary)
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(PD.ColorToken.chip)
                .overlay(Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
        )
    }

    private func tabChip(_ title: String, on: Bool) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(on ? Color.white.opacity(0.95) : PD.ColorToken.textSecondary)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(on ? AnyShapeStyle(Color.white.opacity(0.12)) : AnyShapeStyle(Color.clear))
                    .overlay(
                        Capsule()
                            .stroke(on ? Color.white.opacity(0.22) : Color.clear, lineWidth: 1)
                    )
            )
    }

    private var viewModeToggle: some View {
        HStack(spacing: 2) {
            modeIcon("list.bullet", on: scene.viewMode == .list)
            modeIcon("square.grid.2x2", on: scene.viewMode == .grid)
        }
        .padding(2)
        .frame(height: 36)
        .background(
            Capsule(style: .continuous)
                .fill(PD.ColorToken.chip)
                .overlay(Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
        )
    }

    private func modeIcon(_ name: String, on: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(on ? Color.white.opacity(0.95) : PD.ColorToken.textSecondary)
            .frame(width: 40, height: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(on ? AnyShapeStyle(Color.white.opacity(0.12)) : AnyShapeStyle(Color.clear))
            )
    }

    private var summaryRow: some View {
        HStack(spacing: 8) {
            Text(scene.isDictionary ? "Сохранено в словаре" : "Сохранённые карточки")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
            Text("·").foregroundStyle(PD.ColorToken.textSecondary.opacity(0.5))
            Text("\(max(scene.cardCount, scene.removedCard && !scene.isDictionary ? 5 : scene.cardCount))")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(PD.ColorToken.text)
            Spacer()
        }
    }

    // MARK: Favorites cards

    private var favCardsArea: some View {
        let cards = Array(storyLabFavCards.prefix(max(scene.cardCount, 0)))
        return Group {
            if scene.viewMode == .grid {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                        let isUnlikeTarget = i == 1 && scene.unlikeProgress > 0.05
                        placed(
                            gridHeartCard(card, dimmed: isUnlikeTarget && scene.removedCard),
                            dock: cardDock(i),
                            from: CGFloat(i % 2 == 0 ? -70 : 70),
                            dy: 40 + CGFloat(i) * 6
                        )
                        .opacity(isUnlikeTarget && scene.removedCard ? 0 : 1)
                        .offset(x: isUnlikeTarget ? scene.unlikeProgress * -90 : 0)
                    }
                }
                .padding(.horizontal, CD.Spacing.screen)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                        let isUnlikeTarget = i == 1 && scene.unlikeProgress > 0.05
                        ZStack(alignment: .trailing) {
                            if isUnlikeTarget {
                                Text("Убрать")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 78)
                                    .frame(maxHeight: .infinity)
                                    .background(Color.red.opacity(0.92))
                                    .opacity(Double(min(1, scene.unlikeProgress * 1.4)))
                            }
                            placed(
                                listHeartRow(card),
                                dock: cardDock(i),
                                from: -80, dy: 24 + CGFloat(i) * 4
                            )
                            .offset(x: isUnlikeTarget ? -78 * scene.unlikeProgress : 0)
                            .opacity(isUnlikeTarget && scene.removedCard ? 0 : 1)
                        }
                        .clipped()
                    }
                }
                .padding(.horizontal, CD.Spacing.screen)
            }
        }
    }

    private func cardDock(_ index: Int) -> CGFloat {
        let start = 8.5 + Double(index) * 1.0
        let t = clock.t
        guard t >= start else { return 0 }
        return min(1, max(0, CGFloat((t - start) / 0.4)))
    }

    private func listHeartRow(_ card: StoryLabFavPhrase) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.phonetic)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Text(card.meaning)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Text(card.path)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
            }
            Spacer(minLength: 0)
            Image(systemName: "heart.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.06)))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PD.ColorToken.card.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
        )
    }

    private func gridHeartCard(_ card: StoryLabFavPhrase, dimmed: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(card.meaning)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Text(card.phonetic)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                Text(card.path)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)

            Image(systemName: "heart.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
                .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PD.ColorToken.card.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.pink.opacity(0.22), lineWidth: 1)
                )
        )
        .opacity(dimmed ? 0.35 : 1)
    }

    // MARK: Dictionary tab cards

    private var dictCardsArea: some View {
        let cards = Array(storyLabDictCards.prefix(max(scene.cardCount, 0)))
        return VStack(spacing: 10) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                placed(
                    dictRow(card),
                    dock: dictCardDock(i),
                    from: 90, dy: 20 + CGFloat(i) * 5
                )
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
    }

    private func dictCardDock(_ index: Int) -> CGFloat {
        let start = 28.2 + Double(index) * 0.9
        let t = clock.t
        guard t >= start else { return 0 }
        return min(1, max(0, CGFloat((t - start) / 0.38)))
    }

    private func dictRow(_ card: StoryLabFavPhrase) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.07)))
            VStack(alignment: .leading, spacing: 3) {
                Text(card.phonetic)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Text(card.meaning)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            Spacer()
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PD.ColorToken.card.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
        )
    }

    // MARK: Side drawer

    private func dictionaryDrawer(in size: CGSize) -> some View {
        let panelW = max(280, size.width - 52)
        let dock = scene.drawer
        return HStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Мой словарь")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(PD.ColorToken.text)
                        Text(scene.selectMode ? "Выбрано 2 · для жизни в Таиланде" : "5 фраз · для жизни в Таиланде")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    Spacer()
                    Text(scene.selectMode ? "Готово" : "Выбрать")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.currentAccentFill)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(PD.ColorToken.chip))
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.top, 54)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(storyLabDictCards) { card in
                            HStack(spacing: 10) {
                                if scene.selectMode {
                                    Image(systemName: card.id == "d0" || card.id == "d2" ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(
                                            card.id == "d0" || card.id == "d2"
                                            ? AnyShapeStyle(theme.currentAccentFill)
                                            : AnyShapeStyle(PD.ColorToken.textSecondary)
                                        )
                                }
                                dictRow(card)
                            }
                        }
                    }
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.bottom, 12)
                }

                if scene.drawerActions > 0.02 {
                    VStack(spacing: 10) {
                        placed(
                            DictionarySoftActionLabel(
                                icon: "mic.fill",
                                title: scene.selectMode ? "Тренировать (2)" : "Тренировать все"
                            ),
                            dock: scene.drawerActions,
                            from: 0, dy: 50
                        )
                        placed(
                            DictionarySoftActionLabel(
                                icon: "gamecontroller.fill",
                                title: scene.selectMode ? "Закрепить (2)" : "Закрепить все"
                            ),
                            dock: min(1, scene.drawerActions + 0.15),
                            from: 0, dy: 60
                        )
                    }
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.bottom, ToolBar.recommendedBottomInset + 16)
                    .padding(.top, 8)
                }
            }
            .frame(width: panelW)
            .frame(maxHeight: .infinity)
            .background(PD.ColorToken.background.ignoresSafeArea())
            .clipShape(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 24, bottomLeading: 24, bottomTrailing: 0, topTrailing: 0),
                    style: .continuous
                )
            )
            .shadow(color: .black.opacity(0.28), radius: 24, x: -8, y: 0)
            .offset(x: (1 - dock) * panelW)
        }
        .frame(width: size.width, height: size.height)
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
        }
        .ignoresSafeArea()
    }

    private func grabMarquee(in size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.cyan.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, dash: [5, 3]))
            .frame(width: 100 + 55 * scene.grab, height: 38 + 22 * scene.grab)
            .position(x: size.width * scene.cursorX, y: size.height * scene.cursorY - 10)
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

    private func editorTagChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color.orange).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.22, green: 0.18, blue: 0.12).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.45), lineWidth: 1))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 16)
        .padding(.bottom, 120)
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

    private var readyBadge: some View {
        Text("готово · избранное + словарь")
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.72)).overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 110)
    }

    private func cursorLayer(in size: CGSize) -> some View {
        let x = size.width * scene.cursorX
        let y = size.height * scene.cursorY
        let grabbing = scene.grab > 0.25
        return ZStack {
            if scene.click > 0.05 {
                Circle()
                    .stroke(Color.white.opacity(0.4 * scene.click), lineWidth: 1.5)
                    .frame(width: 28 + 18 * scene.click, height: 28 + 18 * scene.click)
                    .position(x: x, y: y)
            }
            Image(systemName: grabbing ? "hand.raised.fill" : "cursorarrow.click")
                .font(.system(size: grabbing ? 20 : 18, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .scaleEffect(1 - 0.08 * scene.click + 0.06 * scene.grab)
                .position(x: x + 6, y: y + 8)
        }
        .animation(.easeOut(duration: 0.12), value: scene.cursorX)
        .animation(.easeOut(duration: 0.12), value: scene.cursorY)
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
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
        }
    }
}

#endif
