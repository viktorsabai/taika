#if DEBUG

//
//  TaikaStoryLabReinforceSession.swift
//  taika
//
//  Story Lab — Закрепление / memory games assembly (~68s).
//  Hub message → 3 режимы → общий game chrome →
//  Найди пару · Быстрое повторение · Аудио-реплика → stats settle.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabReinforceClock: ObservableObject {
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

enum StoryLabReinforceFocus: Equatable {
    case hub, chrome, match, recall, audio, stats, settle
}

enum StoryLabReinforceBoard: Equatable {
    case none, match, recall, audio
}

struct StoryLabReinforceScene: Equatable {
    var grid: CGFloat
    var hub: CGFloat
    var modes: CGFloat
    var selectedMode: Int // 0 match, 1 recall, 2 audio
    var chrome: CGFloat
    var board: StoryLabReinforceBoard
    var boardOpacity: CGFloat
    // Match script
    var matchLeftSel: Int?
    var matchRightSel: Int?
    var matchMatched: Set<String>
    var matchWrong: Bool
    // Recall script
    var recallSlots: [String]
    var recallWrongSlots: Set<Int>
    var recallCorrect: Bool
    // Audio script
    var audioPicked: Int?
    var audioWrong: Bool
    var audioCorrect: Bool
    var audioChoicesRevealed: Int
    /// Quick scatter→snap when switching boards (no duration stretch).
    var boardSnap: CGFloat
    var editorTag: String?
    // Live counters (shared chrome)
    var score: Int
    var mistakes: Int
    var progressText: String
    var timeText: String
    var gameTitle: String
    var statsPulse: CGFloat
    var ready: CGFloat
    var marquee: CGFloat
    var copyFlash: CGFloat
    var figmaChip: String?
    var focus: StoryLabReinforceFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var actionChip: String?

    static func at(_ t: TimeInterval) -> StoryLabReinforceScene {
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

        // 0–9   hub: typewriter + 3 mode rows
        // 9–15  chrome scatter → snap (header + status strip)
        // 15–28 Найди пару — one/two matches, score ticks
        // 28–42 Быстрое повторение — syllable assemble
        // 42–54 Аудио-реплика — listen + pick RU
        // 54–62 stats / covered cards pulse
        // 62–68 settle

        let focus: StoryLabReinforceFocus = {
            switch t {
            case ..<9: return .hub
            case ..<15: return .chrome
            case ..<28: return .match
            case ..<42: return .recall
            case ..<54: return .audio
            case ..<62: return .stats
            default: return .settle
            }
        }()

        let selectedMode: Int = {
            if t < 11.5 { return 0 }
            if t < 29.5 { return 0 }
            if t < 43.5 { return 1 }
            return 2
        }()

        let board: StoryLabReinforceBoard = {
            switch t {
            case ..<15: return .none
            case ..<28: return .match
            case ..<42: return .recall
            case ..<54: return .audio
            default: return .audio
            }
        }()

        // Match script — shuffled columns; all face-up; wrong then correct
        // Left order:  p1, p0, p2  | Right order: p2, p0, p1
        let matchLeftSel: Int? = {
            if t >= 17.2 && t < 20.2 { return 0 } // чек-бин
            if t >= 20.6 && t < 22.8 { return 0 } // retry чек-бин
            if t >= 23.5 && t < 25.8 { return 1 } // са-ват-ди́
            return nil
        }()
        let matchRightSel: Int? = {
            if t >= 18.4 && t < 20.2 { return 0 } // Спасибо — WRONG vs чек-бин
            if t >= 21.4 && t < 22.8 { return 2 } // Счёт — correct for p1
            if t >= 24.6 && t < 25.8 { return 1 } // Привет — correct for p0
            return nil
        }()
        let matchWrong = t >= 18.6 && t < 20.2
        var matchMatched: Set<String> = []
        if t >= 22.4 { matchMatched.insert("p1") }
        if t >= 25.5 { matchMatched.insert("p0") }

        // Recall: wrong syllable → fix → correct
        let recallSlots: [String] = {
            if t < 31.5 { return [] }
            if t < 33.0 { return ["чек"] }
            if t < 35.2 { return ["чек", "нам"] } // wrong 2nd
            if t < 36.2 { return ["чек"] }        // cleared wrong
            if t < 38.5 { return ["чек", "бин"] }
            return ["чек", "бин"]
        }()
        let recallWrongSlots: Set<Int> = (t >= 33.2 && t < 35.2) ? [1] : []
        let recallCorrect = t >= 38.0

        // Audio: wrong pick → then correct
        let audioPicked: Int? = {
            if t >= 46.8 && t < 49.0 { return 1 } // Спасибо — wrong
            if t >= 50.0 { return 0 }             // Привет — correct
            return nil
        }()
        let audioWrong = t >= 47.0 && t < 49.0
        let audioCorrect = t >= 50.2
        let audioChoicesRevealed: Int = {
            if t < 44.0 { return 0 }
            if t < 44.6 { return 1 }
            if t < 45.2 { return 2 }
            if t < 45.8 { return 3 }
            return 4
        }()

        let boardSnap: CGFloat = max(
            ramp(15.2, 16.8) * (1 - ramp(17.2, 18.0)),
            ramp(28.2, 29.6) * (1 - ramp(30.2, 31.0)),
            ramp(42.2, 43.6) * (1 - ramp(44.2, 45.0))
        )

        let editorTag: String? = {
            if t >= 16.2 && t < 17.8 { return "Auto Layout · columns" }
            if t >= 18.8 && t < 20.4 { return "Variant · wrong" }
            if t >= 21.5 && t < 23.0 { return "State · matched" }
            if t >= 29.0 && t < 30.8 { return "Instance · RecallGameView" }
            if t >= 33.4 && t < 35.0 { return "Prop · wrongSlotIndices" }
            if t >= 37.5 && t < 39.0 { return "Prop · isCorrect=true" }
            if t >= 43.0 && t < 44.8 { return "Instance · AudioRecall chrome" }
            if t >= 47.2 && t < 48.8 { return "Variant · wrongPick" }
            if t >= 50.2 && t < 51.8 { return "Variant · correct" }
            return nil
        }()

        // Shared counters
        let score: Int = {
            var s = 0
            if t >= 22.4 { s += 1 }
            if t >= 25.5 { s += 1 }
            if t >= 38.0 { s += 1 }
            if t >= 50.2 { s += 1 }
            return s
        }()
        let mistakes: Int = {
            var m = 0
            if t >= 18.6 { m += 1 } // match wrong
            if t >= 33.2 { m += 1 } // recall wrong
            if t >= 47.0 { m += 1 } // audio wrong
            return m
        }()
        let progressText: String = {
            switch board {
            case .match:
                return "\(matchMatched.count) из 3 пар"
            case .recall:
                if recallCorrect { return "1 из 4" }
                if !recallWrongSlots.isEmpty { return "ошибка · слог" }
                return "сборка · \(recallSlots.count)/2"
            case .audio:
                if audioCorrect { return "1 из 6" }
                if audioWrong { return "ошибка · перевод" }
                return "слушай → выбери"
            case .none:
                return "—"
            }
        }()
        let timeText: String = {
            let sec = Int(max(0, t - 15))
            return String(format: "0:%02d", min(59, sec))
        }()
        let gameTitle: String = {
            switch selectedMode {
            case 1: return "Быстрое повторение"
            case 2: return "Аудио-реплика"
            default: return "Найди пару"
            }
        }()

        let actionChip: String? = {
            if t >= 0.6 && t < 4.0 { return "Open · Закрепление hub" }
            if t >= 4.5 && t < 8.5 { return "Assemble · 3 memory modes" }
            if t >= 9.5 && t < 14.0 { return "Snap · GameHeader + status" }
            if t >= 16.0 && t < 18.5 { return "Play · face-up shuffle" }
            if t >= 18.5 && t < 20.5 { return "Miss · wrong pair" }
            if t >= 21.0 && t < 26.5 { return "Match · recover → score" }
            if t >= 29.0 && t < 33.0 { return "Mode · Быстрое повторение" }
            if t >= 33.0 && t < 35.5 { return "Miss · wrong syllable" }
            if t >= 36.0 && t < 39.5 { return "Fix · assemble correct" }
            if t >= 43.0 && t < 46.5 { return "Mode · Аудио-реплика" }
            if t >= 46.8 && t < 49.2 { return "Miss · wrong RU" }
            if t >= 50.0 && t < 53.0 { return "Pick · correct RU" }
            if t >= 55.0 && t < 60.5 { return "Stats · score / mistakes" }
            return nil
        }()

        let figmaChip: String? = {
            if t >= 2.0 && t < 5.5 { return "Component · MDCyclingTypewriter" }
            if t >= 5.5 && t < 8.5 { return "Component · ReinforceOptionRow ×3" }
            if t >= 10.0 && t < 14.0 { return "Component · TaikaGameTopChrome" }
            if t >= 17.0 && t < 26.0 { return "Component · MPMatchPairsGrid" }
            if t >= 29.0 && t < 39.0 { return "Component · RecallGameView" }
            if t >= 43.0 && t < 52.0 { return "Component · AudioRecall chrome" }
            if t >= 56.0 && t < 60.0 { return "Store · ReinforcementStore" }
            return nil
        }()

        let (cx, cy): (CGFloat, CGFloat) = {
            switch focus {
            case .hub: return (0.55, 0.42)
            case .chrome: return (0.35, 0.16)
            case .match:
                if matchWrong { return (0.72, 0.42) }
                return t < 23 ? (0.28, 0.48) : (0.72, 0.55)
            case .recall: return (0.50, 0.55)
            case .audio: return (0.50, 0.62)
            case .stats: return (0.40, 0.22)
            case .settle: return (0.50, 0.88)
            }
        }()
        let prev: (CGFloat, CGFloat) = {
            let e = max(0, t - 0.35)
            switch e {
            case ..<9: return (0.55, 0.42)
            case ..<15: return (0.35, 0.16)
            case ..<20.2: return (0.72, 0.42)
            case ..<23: return (0.28, 0.48)
            case ..<28: return (0.72, 0.55)
            case ..<42: return (0.50, 0.55)
            case ..<54: return (0.50, 0.62)
            case ..<62: return (0.40, 0.22)
            default: return (0.50, 0.88)
            }
        }()
        let moveStart: TimeInterval = {
            switch focus {
            case .hub: return 0
            case .chrome: return 9
            case .match:
                if matchWrong { return 18.4 }
                return t < 23 ? 15 : 23
            case .recall: return 28
            case .audio: return 42
            case .stats: return 54
            case .settle: return 62
            }
        }()
        let move = min(1, max(0, (t - moveStart) / 0.28))

        let clickTimes: [TimeInterval] = [
            3.0, 6.0, 8.0, 11.0, 13.5,
            17.4, 18.6, 21.0, 21.6, 23.7, 24.8,
            31.8, 33.4, 35.5, 36.8, 38.2,
            46.0, 47.2, 50.2,
            56.5, 64.0
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.1 { return CGFloat(1 - d / 0.1) }
            }
            return 0
        }()

        return StoryLabReinforceScene(
            grid: ramp(0.2, 1.5) * (1 - ramp(64.5, 67.5)),
            hub: ramp(0.4, 2.0) * (1 - ramp(13.5, 15.5)),
            modes: ramp(3.5, 6.5) * (1 - ramp(13.5, 15.5)),
            selectedMode: selectedMode,
            chrome: ramp(9.5, 13.0),
            board: board,
            boardOpacity: ramp(15.5, 17.5) * (1 - ramp(61.5, 64.0)),
            matchLeftSel: matchLeftSel,
            matchRightSel: matchRightSel,
            matchMatched: matchMatched,
            matchWrong: matchWrong,
            recallSlots: recallSlots,
            recallWrongSlots: recallWrongSlots,
            recallCorrect: recallCorrect,
            audioPicked: audioPicked,
            audioWrong: audioWrong,
            audioCorrect: audioCorrect,
            audioChoicesRevealed: audioChoicesRevealed,
            boardSnap: boardSnap,
            editorTag: editorTag,
            score: score,
            mistakes: mistakes,
            progressText: progressText,
            timeText: timeText,
            gameTitle: gameTitle,
            statsPulse: pulse(54.5, 57.0, 61.0),
            ready: ramp(64.0, 66.5),
            marquee: max(
                pulse(4.0, 5.5, 8.0),
                pulse(10.5, 12.0, 14.0),
                pulse(15.8, 16.6, 17.8),
                pulse(18.8, 19.4, 20.4),
                pulse(22.0, 22.8, 24.0),
                pulse(28.5, 29.4, 30.8),
                pulse(33.2, 34.0, 35.4),
                pulse(37.6, 38.4, 39.6),
                pulse(42.6, 43.5, 45.0),
                pulse(47.0, 47.8, 49.0),
                pulse(50.2, 51.0, 52.2),
                pulse(55.5, 57.0, 59.5)
            ),
            copyFlash: max(
                pulse(11.0, 12.0, 13.5),
                pulse(16.0, 16.8, 17.8),
                pulse(29.0, 29.8, 31.0),
                pulse(43.0, 43.8, 45.0)
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

// MARK: - Demo data
// Shuffled so pairs are NOT opposite each other (deterministic “random”).

private let storyLabMatchLeft: [MPItem] = [
    .init(pairId: "p1", text: "чек-бин", side: .left),
    .init(pairId: "p0", text: "са-ват-ди́", side: .left),
    .init(pairId: "p2", text: "коп-ку́н", side: .left),
]

private let storyLabMatchRight: [MPItem] = [
    .init(pairId: "p2", text: "Спасибо", side: .right),
    .init(pairId: "p0", text: "Привет", side: .right),
    .init(pairId: "p1", text: "Счёт", side: .right),
]

private let storyLabMatchAllIds: Set<String> = ["p0", "p1", "p2"]

private let storyLabRecallSyllables = ["чек", "бин", "кун", "нам", "ди"]
private let storyLabRecallSegments: [HomeTaskManager.PhoneticSegment] = [
    .init(syllable: "чек", toneAfter: nil),
    .init(syllable: "бин", toneAfter: nil),
]
private let storyLabRecallRounds: [RecallRoundDisplay] = [
    .init(id: 0, question: "Счёт, пожалуйста", target: "чек-бин", thai: "เช็คบิล"),
    .init(id: 1, question: "Привет", target: "са-ват-ди́", thai: "สวัสดี"),
    .init(id: 2, question: "Спасибо", target: "коп-ку́н", thai: "ขอบคุณ"),
]
private let storyLabAudioChoices = ["Привет", "Спасибо", "Вода", "Счёт"]
private let storyLabAudioRounds: [(phonetic: String, thai: String, lesson: String)] = [
    ("са-ват-ди́", "สวัสดี", "в кафе"),
    ("чек-бин", "เช็คบิล", "в кафе"),
    ("коп-ку́н", "ขอบคุณ", "в кафе"),
]

private let storyLabReinforceModes: [(GameModeType, String)] = [
    (.match, "закрепление через поиск пар"),
    (.recall, "активное вспоминание в формате sprint"),
    (.audioRecall, "слушай тайскую реплику, собери русский перевод"),
]

// MARK: - Session

struct StoryLabEditorReinforceSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabReinforceClock()
    @State private var showControls = false
    @State private var selectedModeBinding: GameModeType = .match

    private var scene: StoryLabReinforceScene { .at(clock.t) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PD.ColorToken.background.ignoresSafeArea()

                gridOverlay
                    .opacity(scene.grid)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    gameOrBrandHeader
                        .opacity(max(scene.hub, scene.chrome))
                        .allowsHitTesting(false)

                    ZStack {
                        if scene.hub > 0.05 {
                            hubPage
                                .opacity(scene.hub)
                                .allowsHitTesting(false)
                        }

                        if scene.chrome > 0.05, scene.boardOpacity > 0.02 || scene.focus == .chrome {
                            gamePage
                                .opacity(max(scene.boardOpacity, scene.chrome * (scene.hub < 0.2 ? 1 : 0.15)))
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ToolBar(selectedTab: .constant(4))
                        .allowsHitTesting(false)
                        .padding(.bottom, 2)
                        .opacity(max(scene.hub * 0.85, scene.ready))
                }

                if scene.focus == .chrome, scene.chrome < 0.95 {
                    chromeScatter(in: geo.size)
                        .opacity(1 - scene.chrome)
                        .allowsHitTesting(false)
                }

                if scene.boardSnap > 0.05 {
                    boardScatter(in: geo.size)
                        .opacity(scene.boardSnap)
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
                if let tag = scene.editorTag {
                    editorTagChip(tag).allowsHitTesting(false)
                }
                if let chip = scene.actionChip {
                    workChip(chip).allowsHitTesting(false)
                }
                if scene.statsPulse > 0.05 {
                    statsCallout.opacity(scene.statsPulse).allowsHitTesting(false)
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
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: scene.selectedMode)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: scene.matchMatched)
            .animation(.easeOut(duration: 0.18), value: scene.matchWrong)
            .animation(.easeOut(duration: 0.2), value: scene.score)
            .animation(.easeOut(duration: 0.2), value: scene.mistakes)
            .animation(.easeOut(duration: 0.22), value: scene.recallSlots)
            .animation(.easeOut(duration: 0.18), value: scene.recallWrongSlots)
            .animation(.easeOut(duration: 0.22), value: scene.audioPicked)
            .animation(.easeOut(duration: 0.18), value: scene.audioWrong)
        }
        .statusBarHidden(false)
        .navigationBarHidden(true)
        .onAppear { clock.start() }
        .onDisappear { clock.stop() }
        .onChange(of: scene.selectedMode) { _, idx in
            selectedModeBinding = [.match, .recall, .audioRecall][min(2, max(0, idx))]
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

    // MARK: Headers

    @ViewBuilder
    private var gameOrBrandHeader: some View {
        if scene.chrome > 0.35, scene.hub < 0.4 {
            AppHeader(
                showSearch: false,
                showHeart: false,
                showProfile: false,
                showPro: false,
                speakerDailyAttemptsRemaining: 0,
                gameParkActive: true,
                favoritesTotalCount: 0,
                favoritesHasCards: false,
                isPro: true,
                style: .game(GameHeaderConfig(
                    timeText: scene.timeText,
                    score: scene.score,
                    mistakes: scene.mistakes,
                    streak: max(0, scene.score - scene.mistakes),
                    progressText: scene.progressText,
                    gameTitle: scene.gameTitle,
                    sourceTitle: "в кафе · заказ",
                    onBack: {}
                ))
            )
            .environmentObject(theme)
            .id("sl-game-header-\(scene.gameTitle)")
        } else {
            HStack {
                HStack(spacing: 2) {
                    Text("tai").font(.custom("Onmark Trial", size: 22)).foregroundStyle(.white)
                    Text("kAAA").font(.custom("Onmark Trial", size: 22)).foregroundStyle(theme.currentAccentFill)
                }
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    // MARK: Hub

    private var hubPage: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                TaikaScreenPageTitle(title: "Закрепление")
                    .padding(.top, 4)

                MDCyclingTypewriter(
                    lines: [
                        "Выбери режим игры",
                        "три режима · одна колода · счёт ведётся"
                    ],
                    holdSeconds: 2.4
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 10) {
                    ReinforceSectionLabel("Игры")
                    ForEach(Array(storyLabReinforceModes.enumerated()), id: \.offset) { idx, row in
                        let locked = row.0.isPro
                        ReinforceOptionRow(
                            title: row.0.title,
                            subtitle: row.1,
                            isSelected: scene.selectedMode == idx,
                            isLocked: false,
                            showsProCrown: locked,
                            trailing: .selection,
                            leadingIcon: idx == 0 ? "square.on.square" : (idx == 1 ? "bolt.fill" : "ear")
                        )
                        .opacity(min(1, scene.modes * (1.15 - CGFloat(idx) * 0.12)))
                        .offset(y: (1 - scene.modes) * CGFloat(8 + idx * 6))
                    }
                }
                .padding(.top, 4)

                Text("Начать")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.currentAccentFill)
                    )
                    .opacity(scene.modes)
                    .padding(.top, 8)

                Color.clear.frame(height: ToolBar.recommendedBottomInset + 24)
            }
            .padding(.horizontal, CD.Spacing.screen)
        }
    }

    // MARK: Game page

    private var gamePage: some View {
        VStack(spacing: 0) {
            TaikaGameTopChrome(
                timeText: scene.timeText,
                progressText: scene.progressText,
                mistakes: scene.mistakes,
                score: scene.score,
                showsSessionScore: true,
                showsStarWallet: true,
                hints: [
                    TaikaGameHintAction(id: "reveal", title: "Подсказать пару", cost: 1, isEnabled: scene.board == .match, action: {}),
                    TaikaGameHintAction(id: "skip", title: "Пропустить", cost: 2, isEnabled: scene.board != .none, action: {})
                ]
            )
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.top, 8)
            .opacity(scene.chrome)

            Group {
                switch scene.board {
                case .match:
                    matchBoard
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .recall:
                    recallBoard
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .audio:
                    audioBoard
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .none:
                    Color.clear
                }
            }
            .opacity(scene.boardOpacity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id("sl-board-\(String(describing: scene.board))")
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: scene.board)
    }

    private var matchBoard: some View {
        let leftItems: [MPItem] = storyLabMatchLeft.enumerated().map { idx, item in
            let state: MPItemState = {
                if scene.matchMatched.contains(item.pairId) { return .matched }
                if scene.matchWrong, scene.matchLeftSel == idx { return .wrong }
                if scene.matchLeftSel == idx { return .selected }
                return .idle
            }()
            return MPItem(pairId: item.pairId, text: item.text, side: .left, state: state, hasAudio: true)
        }
        let rightItems: [MPItem] = storyLabMatchRight.enumerated().map { idx, item in
            let state: MPItemState = {
                if scene.matchMatched.contains(item.pairId) { return .matched }
                if scene.matchWrong, scene.matchRightSel == idx { return .wrong }
                if scene.matchRightSel == idx { return .selected }
                return .idle
            }()
            return MPItem(pairId: item.pairId, text: item.text, side: .right, state: state)
        }

        return MPMatchPairsGrid(
            left: leftItems,
            right: rightItems,
            selectedLeft: scene.matchWrong ? nil : scene.matchLeftSel,
            selectedRight: scene.matchWrong ? nil : scene.matchRightSel,
            leftTitle: "транслит",
            rightTitle: "русский",
            onTapLeft: { _ in },
            onTapRight: { _ in },
            // Always face-up — show the whole board at once
            revealedIds: storyLabMatchAllIds
        )
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .environmentObject(theme)
    }

    private var recallBoard: some View {
        let slots = scene.recallSlots
        var assembled = Array(repeating: "", count: 2)
        for (i, s) in slots.enumerated() where i < 2 {
            assembled[i] = s
        }
        let pool: [RecallSyllableItem] = storyLabRecallSyllables.enumerated().map { i, s in
            let inUse = slots.contains(s)
            let wrong = scene.recallWrongSlots.contains(where: { idx in
                idx < slots.count && slots[idx] == s
            })
            return RecallSyllableItem(
                id: i,
                text: s,
                isSelectable: !inUse,
                isInUse: inUse,
                isWrong: wrong
            )
        }
        let isCorrect: Bool? = {
            if scene.recallCorrect { return true }
            if !scene.recallWrongSlots.isEmpty { return false }
            return nil
        }()

        return RecallGameView(
            question: "Счёт, пожалуйста",
            phoneticDisplay: "чек-бин",
            segments: storyLabRecallSegments,
            syllableItems: pool,
            slotCount: 2,
            assembled: assembled,
            isCorrect: isCorrect,
            wrongSlotIndices: scene.recallWrongSlots,
            audioText: "เช็คบิล",
            onTapSyllable: { _, _ in },
            onPlayAudio: {},
            onRemoveLast: {},
            onReset: {},
            onCheck: {},
            roundDisplays: storyLabRecallRounds,
            currentRoundIndex: 0,
            lessonTitle: "в кафе",
            // Top chrome already drawn by gamePage — avoid double strip.
            statusTimeText: nil
        )
        .environmentObject(theme)
        .allowsHitTesting(false)
    }

    private var audioBoard: some View {
        let current = 0
        let itemW = TaikaGameCoverflowMetrics.cardW
        let itemH = TaikaGameCoverflowMetrics.cardH
        let stepX = itemW * TaikaGameCoverflowMetrics.peekStepFactor
        let succeeded = scene.audioCorrect

        return VStack(spacing: 10) {
            // Real speaker-style coverflow (same metrics as AudioRecallGameView)
            ZStack {
                ForEach(Array(storyLabAudioRounds.enumerated()), id: \.offset) { index, round in
                    let rel = index - current
                    TaikaGameSpeakerStyleCard(
                        lessonTitle: rel == 0 ? round.lesson : nil,
                        hero: round.phonetic,
                        heroIsPhonetic: true,
                        secondary: (rel == 0 && succeeded) ? "Привет" : nil,
                        tertiary: round.thai,
                        secondaryIsAccent: succeeded && rel == 0,
                        succeeded: succeeded && rel == 0,
                        successGlow: succeeded && rel == 0 ? 1 : 0,
                        showsPlayControl: false
                    )
                    .frame(width: itemW, height: itemH)
                    .scaleEffect(rel == 0 ? 1.0 : 0.82)
                    .rotation3DEffect(
                        .degrees(Double(rel) * -18),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.7
                    )
                    .opacity(abs(rel) > 2 ? 0 : (rel == 0 ? 1.0 : 0.45))
                    .offset(x: CGFloat(rel) * stepX)
                    .zIndex(rel == 0 ? 10 : Double(10 - abs(rel)))
                }
            }
            .frame(height: itemH + 12)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            HStack(spacing: 10) {
                TaikaGameBareSpeakerButton(disabled: false, action: {})
                if scene.audioChoicesRevealed < 2 {
                    Image(systemName: "ear")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.currentAccentFill.opacity(0.85))
                } else {
                    Text("слушай")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.72))
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(storyLabAudioChoices.enumerated()), id: \.offset) { idx, phrase in
                    audioChoiceTile(phrase: phrase, index: idx)
                }
            }
            .padding(.horizontal, 4)

            HStack {
                if scene.audioWrong {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                        .frame(width: 40, height: 40)
                }
                Spacer(minLength: 8)
                if scene.audioCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.currentAccentFill)
                } else if scene.audioWrong {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                } else {
                    Text("1/6")
                        .font(.system(size: 14, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, CD.Spacing.screen)
        .allowsHitTesting(false)
    }

    private func audioChoiceTile(phrase: String, index: Int) -> some View {
        let revealed = index < scene.audioChoicesRevealed
        let picked = scene.audioPicked == index
        let isWrong = scene.audioWrong && picked
        let isCorrect = scene.audioCorrect && index == 0
        let dimmed = scene.audioCorrect && index != 0
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        let fill: AnyShapeStyle = {
            if isCorrect { return AnyShapeStyle(theme.currentAccentFill.opacity(0.18)) }
            if isWrong { return AnyShapeStyle(Color.red.opacity(0.14)) }
            if dimmed { return AnyShapeStyle(CD.ColorToken.card.opacity(0.35)) }
            return AnyShapeStyle(CD.ColorToken.card.opacity(0.96))
        }()
        let stroke: AnyShapeStyle = {
            if isCorrect { return AnyShapeStyle(theme.currentAccentFill) }
            if isWrong { return AnyShapeStyle(Color.red.opacity(0.85)) }
            return AnyShapeStyle(CD.ColorToken.stroke.opacity(0.55))
        }()
        let textStyle: AnyShapeStyle = {
            if isCorrect { return AnyShapeStyle(theme.currentAccentFill) }
            if isWrong { return AnyShapeStyle(Color.red.opacity(0.92)) }
            if dimmed { return AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.42)) }
            return AnyShapeStyle(CD.ColorToken.text)
        }()

        return Text(phrase)
            .font(.system(size: 17, weight: .semibold))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .foregroundStyle(textStyle)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(shape.fill(fill))
            .overlay(shape.stroke(stroke, lineWidth: 1))
            .opacity(revealed ? (dimmed ? 0.42 : 1) : 0)
            .offset(y: revealed ? 0 : 36)
            .scaleEffect(revealed ? 1 : 0.86, anchor: .bottom)
            .animation(
                .spring(response: 0.52, dampingFraction: 0.76).delay(Double(index) * 0.04),
                value: revealed
            )
    }

    // MARK: Scatter / overlays

    private func chromeScatter(in size: CGSize) -> some View {
        let frames: [(String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            ("BACK", 0.72, 0.70, 0.04, 0.10, 0.12, 0.04),
            ("TITLE", 0.10, 0.78, 0.18, 0.10, 0.42, 0.05),
            ("TIMER", 0.80, 0.35, 0.78, 0.10, 0.16, 0.04),
            ("SCORE", 0.05, 0.55, 0.06, 0.18, 0.28, 0.06),
            ("★ HINT", 0.55, 0.62, 0.40, 0.18, 0.28, 0.06),
        ]
        return ZStack {
            ForEach(0..<frames.count, id: \.self) { i in
                chromeScatterPiece(frames[i], index: i, size: size)
            }
        }
    }

    private func chromeScatterPiece(
        _ f: (String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat),
        index: Int,
        size: CGSize
    ) -> some View {
        let u = min(1, max(0, (scene.chrome - CGFloat(index) * 0.08) / 0.45))
        let x = f.1 + (f.3 - f.1) * u
        let y = f.2 + (f.4 - f.2) * u
        let opacity = Double(0.35 + 0.65 * (1 - u * 0.3))
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.cyan.opacity(0.06))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
            Text(f.0)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.cyan.opacity(0.85))
        }
        .frame(width: size.width * f.5, height: size.height * f.6)
        .position(
            x: size.width * x + size.width * f.5 / 2,
            y: size.height * y + size.height * f.6 / 2
        )
            .opacity(opacity)
    }

    private func boardScatter(in size: CGSize) -> some View {
        let frames: [(String, CGFloat, CGFloat, CGFloat, CGFloat)] = {
            switch scene.board {
            case .match:
                return [
                    ("CARD L", 0.08, 0.32, 0.38, 0.22),
                    ("CARD R", 0.54, 0.36, 0.38, 0.22),
                    ("HUD", 0.10, 0.18, 0.80, 0.08),
                ]
            case .recall:
                return [
                    ("COVERFLOW", 0.12, 0.22, 0.76, 0.26),
                    ("SLOTS", 0.18, 0.52, 0.64, 0.08),
                    ("POOL", 0.14, 0.64, 0.72, 0.12),
                ]
            case .audio:
                return [
                    ("SPEAKER CARD", 0.12, 0.20, 0.76, 0.26),
                    ("CHOICE", 0.14, 0.52, 0.72, 0.28),
                ]
            case .none:
                return [("FRAME", 0.1, 0.25, 0.8, 0.4)]
            }
        }()
        let u = 1 - scene.boardSnap
        return ZStack {
            ForEach(Array(frames.enumerated()), id: \.offset) { i, f in
                let drift = CGFloat(i % 2 == 0 ? -1 : 1) * 18 * u
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.cyan.opacity(0.05))
                    )
                    .overlay(
                        Text(f.0)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.cyan.opacity(0.9))
                    )
                    .frame(width: size.width * f.3, height: size.height * f.4)
                    .position(
                        x: size.width * (f.1 + f.3 / 2) + drift,
                        y: size.height * (f.2 + f.4 / 2) - drift * 0.4
                    )
            }
        }
    }

    private func editorTagChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.orange)
                .frame(width: 7, height: 7)
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
        .padding(.bottom, 130)
    }

    private var statsCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ReinforcementStore")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.cyan)
            Text("score \(scene.score) · mistakes \(scene.mistakes) · covered 4 cards")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Text("miss → recover · ★ hints · progress в хедере")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 18)
        .padding(.bottom, 120)
    }

    private var readyBadge: some View {
        Text("готово · можно играть")
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.72)).overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 110)
    }

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

    private func figmaMarquee(in size: CGSize) -> some View {
        let rect: (CGFloat, CGFloat, CGFloat, CGFloat) = {
            switch scene.focus {
            case .hub: return (0.06, 0.22, 0.88, 0.48)
            case .chrome: return (0.04, 0.08, 0.92, 0.18)
            case .match: return (0.04, 0.22, 0.92, 0.55)
            case .recall: return (0.08, 0.28, 0.84, 0.42)
            case .audio: return (0.10, 0.24, 0.80, 0.52)
            case .stats: return (0.06, 0.12, 0.70, 0.16)
            case .settle: return (0.2, 0.78, 0.6, 0.08)
            }
        }()
        let w = size.width * rect.2
        let h = size.height * rect.3
        return RoundedRectangle(cornerRadius: 8)
            .stroke(Color.cyan.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
            .frame(width: w, height: h)
            .position(x: size.width * rect.0 + w / 2, y: size.height * rect.1 + h / 2)
    }

    private var copyToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.doc.fill")
            Text(copyToastLabel)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.black.opacity(0.78)).overlay(Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 1)))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 120)
    }

    private var copyToastLabel: String {
        switch scene.board {
        case .match: return "Paste · MPMatchPairsGrid"
        case .recall: return "Paste · RecallGameView"
        case .audio: return "Paste · TaikaGameSpeakerStyleCard"
        case .none: return "Paste · GameHeaderConfig"
        }
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
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
        }
    }
}

#endif
