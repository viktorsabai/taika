#if DEBUG

//
//  TaikaStoryLabSpeakerTrainingSession.swift
//  taika
//
//  Story Lab — Спикер · закрепление курсов (~58s).
//  Reinforce picker (цветной) → launcher + palette чик-чик →
//  coverflow → mic → score → разбор (ритм + scroll) → settle.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabSpeakerTrainClock: ObservableObject {
    @Published var t: TimeInterval = 0
    @Published var isPlaying = true
    let duration: TimeInterval = 58
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

enum StoryLabSpeakerTrainFocus: Equatable {
    case picker, launcher, cards, record, score, breakdown, settle
}

enum StoryLabSpeakerTrainPhase: Equatable {
    case idle, recording, analyzing, feedback
}

struct StoryLabToneSyl: Equatable, Identifiable {
    var id: String
    var label: String
    var score: Int
    var expected: String
    var actual: String
    var good: Bool
}

struct StoryLabSpeakerTrainScene: Equatable {
    var grid: CGFloat
    var picker: CGFloat
    var speakerHighlight: CGFloat
    var launcher: CGFloat
    var selectedCourseId: String?
    var coursesDock: CGFloat
    var training: CGFloat
    var cardsDock: CGFloat
    var cardIndex: Int
    var phase: StoryLabSpeakerTrainPhase
    var score: Int?
    var syllables: [StoryLabToneSyl]
    var breakdown: CGFloat
    var sheetScroll: CGFloat
    var waveDraw: CGFloat
    var paint: CGFloat
    var colorful: Bool
    var palette: CGFloat
    var paletteIndex: Int
    var ready: CGFloat
    var boardSnap: CGFloat
    var marquee: CGFloat
    var copyFlash: CGFloat
    var figmaChip: String?
    var editorTag: String?
    var focus: StoryLabSpeakerTrainFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var actionChip: String?

    static func at(_ t: TimeInterval) -> StoryLabSpeakerTrainScene {
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
        func cursorAt(_ e: TimeInterval) -> (CGFloat, CGFloat) {
            switch e {
            case ..<7:
                if e < 3.2 {
                    let u = CGFloat(min(1, max(0, (e - 1.0) / 2.0)))
                    return (lerp(0.12, 0.50, u), lerp(0.52, 0.34, u))
                }
                return (0.50, 0.34)
            case ..<16:
                if e < 12.0 {
                    let u = CGFloat(min(1, max(0, (e - 9.0) / 2.5)))
                    return (lerp(0.88, 0.52, u), lerp(0.58, 0.44, u))
                }
                if e < 13.0 { return (0.55, 0.48) }
                if e < 14.2 {
                    let u = CGFloat(min(1, max(0, (e - 13.0) / 1.0)))
                    return (lerp(0.72, 0.78, u), lerp(0.70, 0.68, u))
                }
                return (0.50, 0.82)
            case ..<24:
                let u = CGFloat(min(1, max(0, (e - 17.0) / 3.5)))
                return (lerp(0.18, 0.50, u), lerp(0.28, 0.40, u))
            case ..<32: return (0.50, 0.78)
            case ..<39: return (0.55, 0.42)
            case ..<53:
                if e < 44.0 { return (0.50, 0.42) }
                let u = CGFloat(min(1, max(0, (e - 44.5) / 6.0)))
                return (0.62, lerp(0.42, 0.72, u))
            default: return (0.50, 0.88)
            }
        }

        // 0–7   picker · сразу цветной
        // 7–16  launcher · раскидали курсы → палитра чик-чик (~1с)
        // 16–24 cards · уже цветные
        // 24–32 mic record
        // 32–39 score 48
        // 39–53 разбор
        // 53–58 settle

        let focus: StoryLabSpeakerTrainFocus = {
            switch t {
            case ..<7: return .picker
            case ..<16: return .launcher
            case ..<24: return .cards
            case ..<32: return .record
            case ..<39: return .score
            case ..<53: return .breakdown
            default: return .settle
            }
        }()

        let selectedCourseId: String? = t < 11.5 ? nil : "sl-cafe"

        let phase: StoryLabSpeakerTrainPhase = {
            if t >= 27.0 && t < 30.2 { return .recording }
            if t >= 30.2 && t < 32.2 { return .analyzing }
            if t >= 32.2 { return .feedback }
            return .idle
        }()

        let score: Int? = t >= 32.5 ? 48 : nil

        let syllables: [StoryLabToneSyl] = {
            guard t >= 33.2 else { return [] }
            return [
                .init(id: "s0", label: "са", score: 88, expected: "mid", actual: "mid", good: true),
                .init(id: "s1", label: "ват", score: 42, expected: "low", actual: "rising", good: false),
                .init(id: "s2", label: "ди́", score: 55, expected: "falling", actual: "mid", good: false),
            ]
        }()

        let paletteIndex: Int = {
            if t < 13.15 { return 0 }
            if t < 13.45 { return 1 }
            return 2
        }()

        let actionChip: String? = {
            if t >= 0.5 && t < 3.5 { return "Drag · ReinforceOptionRow" }
            if t >= 4.0 && t < 6.5 { return "Select · Спикер" }
            if t >= 7.5 && t < 11.0 { return "Drag · course rows" }
            if t >= 11.5 && t < 12.8 { return "Pick · «в кафе»" }
            if t >= 12.9 && t < 14.2 { return "Palette · чик-чик" }
            if t >= 14.5 && t < 16.5 { return "Start · тренировка" }
            if t >= 17.5 && t < 22.5 { return "Drag · coverflow cards" }
            if t >= 26.5 && t < 30.5 { return "Mic · запись" }
            if t >= 32.5 && t < 37.5 { return "Score · 48 · тон мимо" }
            if t >= 39.5 && t < 44.0 { return "Sheet · РАЗБОР + волна" }
            if t >= 44.5 && t < 51.0 { return "Scroll · разбор рукой" }
            return nil
        }()

        let figmaChip: String? = {
            if t >= 1.5 && t < 5.0 { return "Component · ReinforceOptionRow" }
            if t >= 8.5 && t < 12.0 { return "Component · MDCyclingTypewriter" }
            if t >= 12.0 && t < 12.9 { return "Component · SpeakerTrainingCourseOption" }
            if t >= 12.9 && t < 14.3 { return "Prop · accent palette" }
            if t >= 18.0 && t < 22.5 { return "Component · TaikaGameSpeakerStyleCard" }
            if t >= 27.0 && t < 30.5 { return "State · recording" }
            if t >= 33.0 && t < 37.5 { return "Prop · SpeakerTripleScoreHeader" }
            if t >= 40.0 && t < 47.0 { return "Overlay · РИТМ ФРАЗЫ" }
            if t >= 47.5 && t < 51.5 { return "Gesture · sheet scroll" }
            return nil
        }()

        let editorTag: String? = {
            if t >= 2.5 && t < 4.5 { return "Drag · into place" }
            if t >= 10.0 && t < 12.0 { return "Auto Layout · course list" }
            if t >= 13.0 && t < 14.1 { return "Paint · palette чик" }
            if t >= 20.0 && t < 22.0 { return "Instance · coverflow ×3" }
            if t >= 28.0 && t < 30.0 { return "Phase · recording" }
            if t >= 34.0 && t < 36.5 { return "Variant · weak tone" }
            if t >= 41.5 && t < 44.5 { return "Sheet · РАЗБОР" }
            if t >= 46.0 && t < 50.0 { return "Scroll · content up" }
            return nil
        }()

        let cxcy = cursorAt(t)
        let prev = cursorAt(max(0, t - 0.3))
        let moveStart: TimeInterval = {
            switch focus {
            case .picker: return 0
            case .launcher: return t < 12 ? 7 : (t < 13 ? 11.5 : 13.0)
            case .cards: return 16
            case .record: return 24
            case .score: return 32
            case .breakdown: return t < 44.5 ? 39 : 44.5
            case .settle: return 53
            }
        }()
        let move = min(1, max(0, (t - moveStart) / 0.32))

        let clickTimes: [TimeInterval] = [
            3.1, 5.2, 11.6, 13.15, 13.45, 13.75, 15.2, 21.0, 27.2, 33.0, 40.2, 45.0, 49.5, 54.5
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.1 { return CGFloat(1 - d / 0.1) }
            }
            return 0
        }()

        return StoryLabSpeakerTrainScene(
            grid: ramp(0.2, 1.2) * (1 - ramp(55.5, 57.5)),
            picker: ramp(0.3, 1.6) * (1 - ramp(6.4, 8.0)),
            speakerHighlight: ramp(3.5, 5.0) * (1 - ramp(6.4, 8.0)),
            launcher: ramp(7.0, 9.2) * (1 - ramp(15.5, 17.5)),
            selectedCourseId: selectedCourseId,
            coursesDock: ramp(9.0, 12.5),
            training: ramp(16.5, 19.0),
            cardsDock: ramp(17.5, 21.5),
            cardIndex: t < 20.0 ? 0 : (t < 21.5 ? 1 : 0),
            phase: phase,
            score: score,
            syllables: syllables,
            breakdown: ramp(39.2, 41.5),
            sheetScroll: ramp(44.5, 50.5),
            waveDraw: ramp(41.5, 45.5),
            paint: ramp(13.0, 13.9),
            colorful: t >= 13.55,
            palette: ramp(12.85, 13.15) * (1 - ramp(14.15, 14.6)),
            paletteIndex: paletteIndex,
            ready: ramp(53.5, 55.5),
            boardSnap: max(
                ramp(1.0, 2.4) * (1 - ramp(3.2, 4.2)),
                ramp(8.2, 10.0) * (1 - ramp(11.0, 12.2)),
                ramp(17.5, 19.5) * (1 - ramp(21.0, 22.2)),
                ramp(32.4, 33.8) * (1 - ramp(35.0, 36.2)),
                ramp(39.2, 41.0) * (1 - ramp(42.2, 43.5))
            ),
            marquee: max(
                pulse(2.0, 3.5, 5.5),
                pulse(9.0, 10.5, 12.5),
                pulse(13.0, 13.5, 14.3),
                pulse(18.5, 20.0, 22.0),
                pulse(27.0, 28.5, 30.5),
                pulse(33.5, 35.0, 37.5),
                pulse(40.5, 42.0, 45.0),
                pulse(46.0, 48.0, 51.0)
            ),
            copyFlash: max(
                pulse(9.5, 10.5, 12.0),
                pulse(17.5, 18.5, 20.0),
                pulse(39.8, 40.8, 42.2)
            ),
            figmaChip: figmaChip,
            editorTag: editorTag,
            focus: focus,
            cursorX: lerp(prev.0, cxcy.0, move),
            cursorY: lerp(prev.1, cxcy.1, move),
            click: click,
            actionChip: actionChip
        )
    }
}

// MARK: - Demo data

private let storyLabTrainCourses: [SpeakerTrainingCourseOption] = [
    .init(id: "sl-cafe", title: "в кафе", count: 12),
    .init(id: "sl-market", title: "на рынке", count: 9),
    .init(id: "sl-taxi", title: "такси и дорога", count: 7),
]

private let storyLabTrainLessons: [SpeakerTrainingLessonOption] = [
    .init(id: "sl-l1", title: "приветствия", count: 4),
    .init(id: "sl-l2", title: "заказ и меню", count: 5),
    .init(id: "sl-l3", title: "счёт", count: 3),
]

private let storyLabTrainCards: [(ru: String, ph: String, th: String)] = [
    ("Привет", "са-ват-ди́", "สวัสดี"),
    ("Счёт, пожалуйста", "чек-бин", "เช็คบิล"),
    ("Спасибо", "коп-ку́н", "ขอบคุณ"),
]

private let storyLabTrainGameModes: [(GameModeType, String)] = [
    (.match, "закрепление через поиск пар"),
    (.recall, "активное вспоминание в формате sprint"),
    (.audioRecall, "слушай тайскую реплику"),
]

/// Fake F0 contours for story-lab «РИТМ ФРАЗЫ» (эталон mid-low-fall · юзер mid-rise-mid).
private let storyLabRefContour: [Double] = [
    0.50, 0.52, 0.51, 0.42, 0.34, 0.30, 0.32, 0.76, 0.68, 0.58, 0.48, 0.39, 0.32
]
private let storyLabUserContour: [Double] = [
    0.50, 0.51, 0.52, 0.39, 0.46, 0.55, 0.72, 0.58, 0.54, 0.52, 0.50, 0.49, 0.48
]

// MARK: - Session

struct StoryLabEditorSpeakerTrainingSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabSpeakerTrainClock()
    @State private var showControls = false

    private var scene: StoryLabSpeakerTrainScene { .at(clock.t) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PD.ColorToken.background.ignoresSafeArea()

                gridOverlay
                    .opacity(scene.grid)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    brandHeader
                        .opacity(max(scene.picker, scene.launcher, scene.training * 0.85))
                        .allowsHitTesting(false)

                    ZStack {
                        if scene.picker > 0.05 {
                            pickerPage
                                .opacity(scene.picker)
                                .allowsHitTesting(false)
                        }
                        if scene.launcher > 0.05 {
                            launcherPage
                                .opacity(scene.launcher)
                                .saturation(scene.colorful ? 1 : 0)
                                .allowsHitTesting(false)
                        }
                        if scene.training > 0.05 {
                            trainingPage
                                .opacity(scene.training)
                                .allowsHitTesting(false)
                        }
                        if scene.breakdown > 0.05 {
                            breakdownOverlay
                                .opacity(scene.breakdown)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ToolBar(selectedTab: .constant(2))
                        .allowsHitTesting(false)
                        .padding(.bottom, 2)
                        .opacity(max(scene.picker * 0.7, scene.launcher * 0.5, scene.ready))
                }

                if scene.palette > 0.05 {
                    paintPlaque
                        .opacity(scene.palette)
                        .allowsHitTesting(false)
                }

                if scene.boardSnap > 0.05 {
                    boardScatter(in: geo.size)
                        .opacity(scene.boardSnap)
                        .allowsHitTesting(false)
                }
                if scene.training > 0.3, scene.breakdown < 0.4 {
                    contextPlaques
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
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: scene.selectedCourseId)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: scene.cardIndex)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: scene.coursesDock)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: scene.cardsDock)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: scene.picker)
            .animation(.easeOut(duration: 0.18), value: scene.colorful)
            .animation(.easeOut(duration: 0.12), value: scene.paletteIndex)
            .animation(.easeOut(duration: 0.2), value: scene.score)
            .animation(.easeOut(duration: 0.22), value: scene.phase)
            .animation(.easeOut(duration: 0.22), value: scene.sheetScroll)
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

    // MARK: Chrome

    private var brandHeader: some View {
        HStack {
            HStack(spacing: 2) {
                Text("tai").font(.custom("Onmark Trial", size: 22)).foregroundStyle(.white)
                Text("kAAA").font(.custom("Onmark Trial", size: 22)).foregroundStyle(theme.currentAccentFill)
            }
            Spacer()
            HStack(spacing: 8) {
                if let score = scene.score, scene.training > 0.5 {
                    Text("\(score)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: 1) Reinforce picker — drag into place (no tilt)

    private var pickerPage: some View {
        let scatter = 1 - scene.picker
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Как закрепить")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PD.ColorToken.text)
                    .padding(.top, 8)
                    .offset(y: -24 * scatter)
                    .opacity(Double(scene.picker))

                MDCyclingTypewriter(
                    lines: [
                        "Игры уже есть — теперь голос",
                        "Спикер закрепит тоны вслух"
                    ],
                    font: .system(size: 18, weight: .bold),
                    holdSeconds: 2.2,
                    minHeight: 44
                )
                .offset(y: -18 * scatter)
                .opacity(Double(scene.picker))

                ReinforceSectionLabel("Голос")
                    .padding(.top, 6)
                    .opacity(Double(scene.picker))

                ReinforceOptionRow(
                    title: "Спикер",
                    subtitle: "произношение и тоны вслух",
                    isSelected: scene.speakerHighlight > 0.4,
                    trailing: .chevron,
                    leadingIcon: "mic.fill"
                )
                .scaleEffect(1 + 0.03 * scene.speakerHighlight)
                .offset(x: -110 * scatter, y: 0)
                .opacity(Double(scene.picker))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.cyan.opacity(0.55 * scene.speakerHighlight), lineWidth: 1.2)
                )

                ReinforceSectionLabel("Игры")
                    .padding(.top, 8)
                    .opacity(0.75 * Double(scene.picker))
                    .offset(y: 28 * scatter)

                ForEach(Array(storyLabTrainGameModes.enumerated()), id: \.offset) { idx, row in
                    ReinforceOptionRow(
                        title: row.0.title,
                        subtitle: row.1,
                        isSelected: false,
                        showsProCrown: row.0.isPro,
                        trailing: .chevron
                    )
                    .opacity(0.55 * Double(scene.picker))
                    .offset(
                        x: scatter * CGFloat(90 + idx * 24),
                        y: scatter * CGFloat(18 + idx * 10)
                    )
                }

                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, CD.Spacing.screen)
        }
    }

    // MARK: 2) Launcher

    private var launcherPage: some View {
        let scatter = 1 - scene.coursesDock
        return VStack(spacing: 0) {
            TaikaScreenPageTitle(title: "Закрепление курсов")
                .padding(.top, 2)
                .offset(y: -20 * scatter)
                .opacity(Double(scene.coursesDock))

            MDCyclingTypewriter(
                lines: [
                    "Жми «Начать тренировку» — и говори",
                    "Выбери курсы и уроки ниже"
                ],
                font: .system(size: 19, weight: .bold),
                holdSeconds: 2.4,
                minHeight: 48
            )
            .padding(.top, 6)
            .padding(.bottom, 8)
            .padding(.horizontal, CD.Spacing.screen)
            .offset(y: -14 * scatter)
            .opacity(Double(max(scene.launcher, scene.coursesDock)))

            HStack {
                Text("Выбери курсы и уроки")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.bottom, 8)
            .opacity(Double(scene.coursesDock))
            .offset(y: 16 * scatter)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(storyLabTrainCourses.enumerated()), id: \.element.id) { idx, option in
                        let selected = scene.selectedCourseId == option.id
                        let expanded = selected && scene.coursesDock > 0.85
                        courseBlock(option: option, selected: selected, expanded: expanded)
                            .opacity(min(1, Double(scene.coursesDock) * (1.2 - Double(idx) * 0.15)))
                            .offset(
                                x: scatter * CGFloat(idx % 2 == 0 ? -72 : 68),
                                y: scatter * CGFloat(20 + idx * 12)
                            )
                    }
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 12)
            }

            Text(scene.selectedCourseId == nil
                 ? "Начать тренировку"
                 : "Начать тренировку · 12")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    Capsule(style: .continuous)
                        .fill(scene.selectedCourseId == nil
                              ? AnyShapeStyle(Color.white.opacity(0.35))
                              : AnyShapeStyle(theme.currentAccentFill))
                )
                .offset(y: 48 * scatter)
                .opacity(Double(scene.coursesDock))
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 12)
                .scaleEffect(scene.selectedCourseId != nil && clock.t >= 14.8 && clock.t < 16.2 ? 0.97 : 1)
        }
    }

    private func courseBlock(option: SpeakerTrainingCourseOption, selected: Bool, expanded: Bool) -> some View {
        let checkColor: Color = selected ? theme.currentAccentTintColor : PD.ColorToken.textSecondary.opacity(0.4)
        let strokeColor: Color = selected ? theme.currentAccentTintColor.opacity(0.55) : Color.white.opacity(0.08)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(checkColor)
                    .frame(width: 28, height: 28)

                Text(option.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Spacer(minLength: 8)
                Text("\(option.count) фраз")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if expanded {
                courseLessonsList
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(selected ? 0.10 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        )
    }

    private var courseLessonsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(storyLabTrainLessons) { lesson in
                HStack {
                    Text(lesson.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PD.ColorToken.text.opacity(0.9))
                    Spacer()
                    Text("\(lesson.count)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .padding(.bottom, 6)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: 3) Training play

    private var trainingPage: some View {
        let showFeedback = scene.score != nil && scene.breakdown < 0.55
        return ZStack {
            if showFeedback {
                trainingFeedbackFullScreen
                    .transition(.opacity)
            } else {
                trainingPracticeCanvas
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: showFeedback)
    }

    private var trainingPracticeCanvas: some View {
        let current = min(max(0, scene.cardIndex), storyLabTrainCards.count - 1)
        let itemW = TaikaGameCoverflowMetrics.cardW
        let itemH = TaikaGameCoverflowMetrics.cardH
        let stepX = itemW * TaikaGameCoverflowMetrics.peekStepFactor
        let dock = scene.cardsDock
        let scatter = 1 - dock

        return VStack(spacing: 0) {
            Spacer(minLength: 8)

            ZStack {
                ForEach(Array(storyLabTrainCards.enumerated()), id: \.offset) { index, card in
                    let rel = index - current
                    TaikaGameSpeakerStyleCard(
                        lessonTitle: rel == 0 ? "в кафе" : nil,
                        hero: card.ph,
                        heroIsPhonetic: true,
                        secondary: nil,
                        tertiary: card.th,
                        secondaryIsAccent: false,
                        succeeded: false,
                        successGlow: 0,
                        showsPlayControl: true,
                        playDisabled: false,
                        onPlay: {}
                    )
                    .frame(width: itemW, height: itemH)
                    .scaleEffect((rel == 0 ? 1.0 : 0.82) * max(0.9, dock))
                    .rotation3DEffect(
                        .degrees(Double(rel) * -18),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.7
                    )
                    .opacity(abs(rel) > 2 ? 0 : (rel == 0 ? Double(dock) : 0.45 * Double(dock)))
                    .offset(
                        x: CGFloat(rel) * stepX + (rel == 0 ? -90 : 70) * scatter,
                        y: 0
                    )
                    .zIndex(rel == 0 ? 10 : Double(10 - abs(rel)))
                }
            }
            .frame(height: itemH + 12)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 16)

            HStack(spacing: 22) {
                VStack(spacing: 4) {
                    TaikaGameBareSpeakerButton(disabled: false, action: {})
                    Text("эталон")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                }
                .offset(x: -64 * scatter)
                .opacity(Double(dock))

                micButton
                    .offset(y: 48 * scatter)
                    .opacity(Double(dock))

                VStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.currentAccentFill)
                        .frame(width: 32, height: 32)
                    Text("разбор")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                }
                .offset(x: 64 * scatter)
                .opacity(Double(dock))
            }

            phaseLabel
                .padding(.top, 10)
                .opacity(Double(dock))

            Spacer(minLength: 24)
        }
        .padding(.horizontal, CD.Spacing.screen)
    }

    private var trainingFeedbackFullScreen: some View {
        let overall = scene.score ?? 0
        let textScore = 72
        let toneScore = 41
        let userSaid = "са-ват-ди"
        let expected = "са-ват-ди́"
        let dock = min(1, max(0, CGFloat((clock.t - 32.5) / 0.55)))
        let scatter = 1 - dock

        return ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 22) {
                    SpeakerTripleScoreHeader(
                        textScore: textScore,
                        toneScore: toneScore,
                        overallScore: overall,
                        toneLoading: scene.phase == .analyzing,
                        toneLocked: false,
                        usesHybridOverall: false,
                        layout: .feedback,
                        centered: true
                    )
                    .offset(y: 36 * scatter)
                    .opacity(Double(dock))

                    HStack(alignment: .top, spacing: 18) {
                        VStack(spacing: 6) {
                            Text("нужно было")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
                            Text(expected)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(PD.ColorToken.text)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .offset(x: -56 * scatter)
                        .opacity(Double(dock))

                        VStack(spacing: 6) {
                            Text("ты сказал")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
                            Text(userSaid)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.orange.opacity(0.95))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .offset(x: 56 * scatter)
                        .opacity(Double(dock))
                    }

                    Text("Тон на «ват» пошёл вверх — нужен спад")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .offset(y: 20 * scatter)
                        .opacity(Double(dock))
                }
                .padding(.horizontal, CD.Spacing.screen)

                Spacer(minLength: 0)
                Color.clear.frame(height: 72)
            }

            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .semibold))
                Text("что улучшить")
            }
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule(style: .continuous).fill(theme.currentAccentFill))
            .foregroundColor(.black)
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.bottom, 8)
            .offset(y: 64 * scatter)
            .opacity(Double(dock))
            .scaleEffect(clock.t >= 37.5 && clock.t < 39.5 ? 0.97 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var micButton: some View {
        let recording = scene.phase == .recording
        let analyzing = scene.phase == .analyzing
        return ZStack {
            Circle()
                .fill(recording ? AnyShapeStyle(theme.currentAccentFill.opacity(0.25)) : AnyShapeStyle(Color.white.opacity(0.08)))
                .frame(width: 72, height: 72)
                .scaleEffect(recording ? 1.08 : 1.0)
            Circle()
                .strokeBorder(theme.currentAccentFill.opacity(recording ? 0.9 : 0.35), lineWidth: 2)
                .frame(width: 72, height: 72)
            Image(systemName: recording ? "stop.fill" : (analyzing ? "ellipsis" : "mic.fill"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(recording ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.9)))
        }
    }

    private var phaseLabel: some View {
        let text: String = {
            switch scene.phase {
            case .idle: return "готов к записи"
            case .recording: return "запись…"
            case .analyzing: return "анализ…"
            case .feedback:
                if let s = scene.score { return "оценка: \(s) · тон мимо" }
                return "оценка"
            }
        }()
        return Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(PD.ColorToken.textSecondary)
    }

    // MARK: 4) Bottom sheet «РАЗБОР» + rhythm wave + hand scroll

    private var breakdownOverlay: some View {
        let overall = scene.score ?? 48
        let textScore = 72
        let toneScore = 41
        let userSaid = "са-ват-ди"

        return ZStack(alignment: .bottom) {
            Color.black.opacity(0.35 * Double(scene.breakdown))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("РАЗБОР")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 10) {
                            Text("Привет")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(PD.ColorToken.text)
                                .frame(maxWidth: .infinity)
                            Text("са-ват-ди́")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(PD.ColorToken.text)
                                .frame(maxWidth: .infinity)
                            Text("สวัสดี")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .frame(maxWidth: .infinity)
                        }

                        HStack(alignment: .top, spacing: 0) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ЭТАЛОН")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(0.7)
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.62))
                                Text("са-ват-ди́")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
                                    .padding(.top, 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 12)

                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 1)
                                .padding(.vertical, 2)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("ТЫ СКАЗАЛА")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(0.7)
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.62))
                                Text(userSaid)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.orange.opacity(0.95))
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
                                    .padding(.top, 2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 12)
                        }
                        .padding(.vertical, 4)

                        // РИТМ ФРАЗЫ — как в детальном разборе
                        rhythmPhraseBlock

                        VStack(alignment: .leading, spacing: 6) {
                            Text("ЧТО ПОПРАВИТЬ")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.65))
                            Text("На «ват» голос пошёл вверх — нужен спад в конце слога.")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PD.ColorToken.text)
                        }

                        SpeakerTripleScoreHeader(
                            textScore: textScore,
                            toneScore: toneScore,
                            overallScore: overall,
                            toneLoading: false,
                            toneLocked: false,
                            usesHybridOverall: false,
                            layout: .sheet,
                            centered: true
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            Text("По слогам")
                                .font(.system(size: 12, weight: .semibold))
                                .tracking(0.5)
                                .foregroundStyle(PD.ColorToken.textSecondary)

                            VStack(spacing: 0) {
                                ForEach(Array(scene.syllables.enumerated()), id: \.element.id) { idx, syl in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(syl.good ? TaikaMasteryTokens.greenGlow : Color.orange)
                                            .frame(width: 8, height: 8)
                                        Text(syl.label)
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(PD.ColorToken.text)
                                            .frame(width: 40, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(syl.expected) → \(syl.actual)")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(PD.ColorToken.textSecondary)
                                            if !syl.good {
                                                Text("Голос пошёл вверх — нужен спад")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(Color.orange)
                                            }
                                        }
                                        Spacer()
                                        Text("\(syl.score)")
                                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                                            .foregroundStyle(syl.good ? TaikaMasteryTokens.greenGlow : Color.orange)
                                    }
                                    .padding(.vertical, 12)
                                    if idx < scene.syllables.count - 1 {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.11))
                                            .frame(height: 1)
                                            .padding(.leading, 17)
                                    }
                                }
                            }
                        }

                        // Extra coaching so scroll has somewhere to go
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Кхун Кру шепчет")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(theme.currentAccentFill)
                            Text("Послушай эталон на «ват» отдельно — потом собери всю фразу. Не тяни вверх в конце слога.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PD.ColorToken.text.opacity(0.88))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )

                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .offset(y: -scene.sheetScroll * 210)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.72)
            .background(PD.ColorToken.background.ignoresSafeArea(edges: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
            )
            .offset(y: (1 - scene.breakdown) * 420)
            .shadow(color: .black.opacity(0.35), radius: 24, y: -4)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var rhythmPhraseBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Text("РИТМ ФРАЗЫ")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Spacer(minLength: 8)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("эталон")
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                        Text("как ты")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
            }

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 14, height: 3)
                    Text("эталон")
                }
                HStack(spacing: 6) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.82))
                        .frame(width: 14, height: 3)
                    Text("ты")
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(PD.ColorToken.textSecondary)

            ZStack {
                StoryLabSparklineShape(values: storyLabRefContour)
                    .trim(from: 0, to: max(0.02, Double(scene.waveDraw)))
                    .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                StoryLabSparklineShape(values: storyLabUserContour)
                    .trim(from: 0, to: max(0.02, Double(scene.waveDraw)))
                    .stroke(Color.white.opacity(0.86), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 72)
            .padding(.vertical, 4)

            HStack(spacing: 0) {
                ForEach(["са", "ват", "ди́"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: Paint

    private var paintPlaque: some View {
        let colors: [Color] = [
            theme.currentAccentTintColor,
            TaikaMasteryTokens.continueSky,
            TaikaMasteryTokens.green
        ]
        let labels = ["accent", "sky", "done"]
        return VStack(alignment: .leading, spacing: 10) {
            Text("PALETTE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .tracking(0.8)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    let on = i == scene.paletteIndex
                    VStack(spacing: 6) {
                        Circle()
                            .fill(colors[i])
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(on ? 0.95 : 0.15), lineWidth: on ? 2.5 : 1)
                            )
                            .shadow(color: colors[i].opacity(on ? 0.55 : 0), radius: 8)
                            .scaleEffect(on ? 1.08 : 1)
                        Text(labels[i])
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(on ? 0.85 : 0.4))
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

    // MARK: Context plaques

    private var contextPlaques: some View {
        let items: [(String, Alignment, CGFloat)] = {
            switch scene.focus {
            case .cards:
                return [
                    ("coverflow · 3 cards", .topLeading, 0.7),
                    ("peek neighbor", .topTrailing, 0.55),
                ]
            case .record:
                return [
                    ("phase · recording", .leading, 0.85),
                    ("meter · live", .trailing, 0.7),
                ]
            case .score:
                return [
                    ("score · center", .topTrailing, 0.9),
                    ("diff · columns", .leading, 0.8),
                    ("CTA · toolbar", .bottomTrailing, 0.85),
                ]
            case .breakdown:
                return [
                    ("sheet · .large", .topLeading, 0.9),
                    ("ритм фразы", .trailing, 0.85),
                    ("scroll · hand", .bottomLeading, 0.8),
                ]
            default:
                return []
            }
        }()

        return ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                contextPlaque(item.0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: item.1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, CGFloat(90 + i * 36))
                    .opacity(Double(item.2))
            }
        }
        .animation(.easeOut(duration: 0.25), value: scene.focus)
    }

    private func contextPlaque(_ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.cyan)
                .frame(width: 3, height: 12)
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.88))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.72))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
        )
    }

    private func boardScatter(in size: CGSize) -> some View {
        let frames: [(String, CGFloat, CGFloat, CGFloat, CGFloat)] = {
            switch scene.focus {
            case .launcher:
                return [
                    ("TYPEWRITER", 0.08, 0.16, 0.84, 0.10),
                    ("COURSE", 0.08, 0.32, 0.84, 0.12),
                    ("CTA", 0.12, 0.78, 0.76, 0.07),
                ]
            case .cards, .record:
                return [
                    ("CARD", 0.14, 0.14, 0.72, 0.26),
                    ("MIC", 0.38, 0.52, 0.24, 0.10),
                ]
            case .score:
                return [
                    ("SCORE %", 0.18, 0.22, 0.64, 0.22),
                    ("DIFF L/R", 0.10, 0.48, 0.80, 0.12),
                    ("CTA", 0.12, 0.78, 0.76, 0.08),
                ]
            case .breakdown:
                return [
                    ("SHEET", 0.0, 0.28, 1.0, 0.72),
                ]
            default:
                return [("ROW", 0.1, 0.3, 0.8, 0.12)]
            }
        }()
        let u = 1 - scene.boardSnap
        return ZStack {
            ForEach(Array(frames.enumerated()), id: \.offset) { i, f in
                let drift = CGFloat(i % 2 == 0 ? -1 : 1) * 16 * u
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.cyan.opacity(0.05)))
                    .overlay(
                        Text(f.0)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.cyan.opacity(0.9))
                    )
                    .frame(width: size.width * f.3, height: size.height * f.4)
                    .position(
                        x: size.width * (f.1 + f.3 / 2) + drift,
                        y: size.height * (f.2 + f.4 / 2) - drift * 0.35
                    )
            }
        }
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
            case .picker: return (0.06, 0.18, 0.88, 0.42)
            case .launcher: return (0.06, 0.20, 0.88, 0.55)
            case .cards, .record: return (0.10, 0.16, 0.80, 0.45)
            case .score: return (0.10, 0.28, 0.80, 0.52)
            case .breakdown: return (0.0, 0.28, 1.0, 0.70)
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
        let label: String = {
            switch scene.focus {
            case .picker: return "Paste · ReinforceOptionRow · Спикер"
            case .launcher: return "Paste · training launcher"
            case .breakdown: return "Paste · tone breakdown"
            default: return "Paste · SpeakerStyleCard"
            }
        }()
        return HStack(spacing: 8) {
            Image(systemName: "doc.on.doc.fill")
            Text(label).font(.system(size: 12, weight: .semibold))
        }
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
        .padding(.bottom, 130)
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
        Text("готово · голос закрепляет")
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

// MARK: - Sparkline (story-lab mirror of breakdownPhraseSparkline)

private struct StoryLabSparklineShape: Shape {
    var values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count >= 2 else { return Path() }
        var path = Path()
        let last = CGFloat(values.count - 1)
        for (i, raw) in values.enumerated() {
            let x = rect.minX + rect.width * (CGFloat(i) / last)
            let y = rect.maxY - rect.height * CGFloat(min(1, max(0, raw)))
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

#endif
