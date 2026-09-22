#if DEBUG

//
//  TaikaStoryLabSpeakerSession.swift
//  taika
//
//  Story Lab — Спикер · умный / «Скажи сам» (~64s).
//  Курсор хватает и ставит реальные куски UI (не fade-in).
//  Верстка/кнопки = conversation shell из SpeakerDS.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabSpeakerClock: ObservableObject {
    @Published var t: TimeInterval = 0
    @Published var isPlaying = true
    let duration: TimeInterval = 64
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

enum StoryLabSpeakerFocus: Equatable {
    case boot, voiceShell, textMode, voiceBack, assemble, states, listen, result, gloss, actions, settle
}

struct StoryLabGlossWord: Equatable, Identifiable {
    var id: String
    var phonetic: String
    var meaning: String
}

struct StoryLabSpeakerScene: Equatable {
    var grid: CGFloat
    var header: CGFloat
    var titleType: CGFloat
    var modeDock: CGFloat
    var dotsDock: CGFloat
    var sphereDock: CGFloat
    var sphere: CGFloat
    var planetMode: TaikaVoicePlanetMode
    var planetKind: TaikaVoicePlanetKind
    var palette: CGFloat
    var paletteIndex: Int
    var colorful: Bool
    var resultPaint: CGFloat
    var isTextMode: Bool
    var fieldDock: CGFloat
    var translateDock: CGFloat
    var backVoiceDock: CGFloat
    var sayCTADock: CGFloat
    var isRecording: Bool
    var resultDock: CGFloat
    var gloss: CGFloat
    var glossCount: Int
    var glossLoading: Bool
    var iconsDock: CGFloat
    var trainDock: CGFloat
    var dictDock: CGFloat
    var morePhrase: CGFloat
    var dictSaved: Bool
    var dictPulse: CGFloat
    var dictCount: Int
    var ready: CGFloat
    var marquee: CGFloat
    var grab: CGFloat
    var copyFlash: CGFloat
    var figmaChip: String?
    var editorTag: String?
    var actionChip: String?
    var focus: StoryLabSpeakerFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat

    static func at(_ t: TimeInterval) -> StoryLabSpeakerScene {
        func ramp(_ a: TimeInterval, _ b: TimeInterval) -> CGFloat {
            guard b > a else { return t >= b ? 1 : 0 }
            return CGFloat(min(1, max(0, (t - a) / (b - a))))
        }
        func snap(_ a: TimeInterval, _ b: TimeInterval) -> CGFloat {
            // Fast dock — feel like a drop, not a fade
            ramp(a, min(b, a + 0.45))
        }
        func pulse(_ a: TimeInterval, _ peak: TimeInterval, _ b: TimeInterval) -> CGFloat {
            if t < a || t >= b { return 0 }
            return t < peak ? ramp(a, peak) : 1 - ramp(peak, b)
        }
        func lerp(_ a: CGFloat, _ b: CGFloat, _ u: CGFloat) -> CGFloat {
            a + (b - a) * min(1, max(0, u))
        }

        // 0–2.5   boot
        // 2.5–7   voiceShell: grab mode chip + dots + soft planet
        // 7–13.5  textMode: grab field / Перевести / ‹ Голос
        // 13.5–16 voiceBack
        // 16–21.5 assemble: grab planet + palette clicks
        // 21.5–27 states: tap modes + grab «Сказать»
        // 27–34   listen → cook
        // 34–37.5 result: grab phrase (ещё чуть B&W)
        // 37.5–41  color tokens: чик-чик → settle accent → color on
        // 41–50   gloss: grab each Grid row (уже в цвете)
        // 50–58   actions: grab icons + Тренировать + В словарь
        // 58–64   settle

        let focus: StoryLabSpeakerFocus = {
            switch t {
            case ..<2.5: return .boot
            case ..<7: return .voiceShell
            case ..<13.5: return .textMode
            case ..<16: return .voiceBack
            case ..<21.5: return .assemble
            case ..<27: return .states
            case ..<34: return .listen
            case ..<37.5: return .result
            case ..<41: return .result // paint beat inside result
            case ..<50: return .gloss
            case ..<58: return .actions
            default: return .settle
            }
        }()

        let isTextMode = focus == .textMode
        let planetKind: TaikaVoicePlanetKind = isTextMode ? .text : .voice

        let planetMode: TaikaVoicePlanetMode = {
            switch focus {
            case .boot, .voiceShell, .voiceBack: return .idle
            case .textMode: return .idle
            case .assemble: return t < 18.2 ? .assemble : .idle
            case .states:
                if t < 22.8 { return .idle }
                if t < 24.2 { return .listening }
                if t < 25.6 { return .cooking }
                return .result
            case .listen:
                if t < 29.5 { return .listening }
                if t < 32.5 { return .cooking }
                return .result
            case .result, .gloss, .actions, .settle:
                return .result
            }
        }()

        let isRecording = planetMode == .listening && (focus == .listen || focus == .states)

        let paletteIndex: Int = {
            // Early sphere paint · чик-чик
            if t < 21.5 {
                if t < 19.0 { return 0 }
                if t < 19.7 { return 1 }
                if t < 20.4 { return 2 }
                return 0
            }
            // Result color tokens · чик-чик-чик → accent
            if t < 38.0 { return 0 }
            if t < 38.55 { return 1 }
            if t < 39.1 { return 2 }
            return 0
        }()

        let glossCount: Int = {
            guard t >= 41.5 else { return 0 }
            let u = min(1, max(0, (t - 41.5) / 5.5))
            return min(storyLabSmartGloss.count, max(0, Int(ceil(u * Double(storyLabSmartGloss.count)))))
        }()

        // Sphere visibility: soft in shell, gone in text, full in assemble/states/listen, shrink for outcome
        let sphere: CGFloat = {
            switch focus {
            case .boot: return 0
            case .voiceShell: return snap(3.8, 4.4) * 0.7
            case .textMode: return 0
            case .voiceBack: return snap(13.7, 14.3) * 0.75
            case .assemble: return snap(16.3, 17.0)
            case .states, .listen: return 1
            case .result: return 1 - ramp(34.0, 35.5) * 0.9
            case .gloss, .actions, .settle: return 0.08
            }
        }()

        let actionChip: String? = {
            if t >= 0.3 && t < 2.2 { return "Open · Скажи сам" }
            if t >= 2.8 && t < 6.5 { return "Grab · mode switch" }
            if t >= 7.2 && t < 13.0 { return "Grab · text composer" }
            if t >= 13.8 && t < 15.5 { return "Drop · Голос" }
            if t >= 16.3 && t < 20.8 { return "Grab · TaikaVoicePlanet" }
            if t >= 21.8 && t < 26.5 { return "Tap · states + Сказать" }
            if t >= 27.2 && t < 33.0 { return "Mic · listening → cooking" }
            if t >= 34.2 && t < 37.0 { return "Grab · result phrase" }
            if t >= 37.4 && t < 40.5 { return "Tokens · color чик-чик" }
            if t >= 41.2 && t < 49.0 { return "Grab · РАЗБОР rows" }
            if t >= 50.2 && t < 57.0 { return "Grab · Тренировать / словарь" }
            return nil
        }()

        let figmaChip: String? = {
            if t >= 3.0 && t < 6.5 { return "Control · conversationModeSwitch" }
            if t >= 7.5 && t < 12.5 { return "Panel · textComposer" }
            if t >= 16.5 && t < 20.5 { return "Component · TaikaVoicePlanet" }
            if t >= 22.0 && t < 26.0 { return "Enum · planetMode" }
            if t >= 34.5 && t < 37.2 { return "Block · resultCenter" }
            if t >= 37.5 && t < 40.5 { return "Tokens · accent / sky / done" }
            if t >= 41.5 && t < 48.5 { return "Model · SmartSpeakerPart" }
            if t >= 51.0 && t < 56.5 { return "Actions · conversationResultActions" }
            return nil
        }()

        let editorTag: String? = {
            if t >= 4.0 && t < 5.8 { return "Hand · drop switch" }
            if t >= 8.5 && t < 11.5 { return "Hand · drop field" }
            if t >= 17.0 && t < 19.0 { return "Hand · drop sphere" }
            if t >= 23.0 && t < 25.5 { return "Hand · drop CTA" }
            if t >= 35.5 && t < 37.0 { return "Hand · drop phrase" }
            if t >= 38.0 && t < 40.0 { return "Click · color tokens" }
            if t >= 42.5 && t < 48.0 { return "Hand · drop gloss row" }
            if t >= 52.0 && t < 56.0 { return "Hand · drop CTAs" }
            return nil
        }()

        // Cursor follows grab → drop path for the active piece
        func cursorAt(_ e: TimeInterval) -> (CGFloat, CGFloat) {
            switch e {
            case ..<2.5: return (0.40, 0.14)
            case ..<7:
                // Grab switch from right, drop center-top
                if e < 3.6 { return (0.88, 0.22) }
                return (0.50, 0.18)
            case ..<13.5:
                if e < 8.5 { return (0.90, 0.42) }      // grab field
                if e < 10.2 { return (0.50, 0.42) }     // drop field
                if e < 11.2 { return (0.88, 0.58) }      // grab translate
                if e < 12.2 { return (0.50, 0.58) }      // drop
                return (0.50, 0.72)                       // back-voice chip
            case ..<16: return (0.28, 0.72)
            case ..<21.5:
                if e < 17.2 { return (0.08, 0.48) }       // grab planet off-left
                if e < 18.5 { return (0.50, 0.42) }       // drop center
                return (0.82, 0.68)                       // palette
            case ..<27:
                if e < 23.5 { return (0.50, 0.44) }       // tap sphere
                if e < 24.8 { return (0.78, 0.72) }       // grab CTA
                return (0.50, 0.72)                       // drop CTA
            case ..<34: return (0.50, 0.48)
            case ..<41:
                if e < 35.2 { return (0.50, 0.08) }       // grab phrase from top
                if e < 37.2 { return (0.50, 0.32) }
                // Color tokens чик-чик: accent → sky → done → accent
                if e < 38.0 { return (0.38, 0.58) }
                if e < 38.55 { return (0.50, 0.58) }
                if e < 39.1 { return (0.62, 0.58) }
                return (0.38, 0.58)                        // settle accent
            case ..<50:
                let i = min(2, max(0, Int((e - 41.5) / 1.6)))
                let rowY = 0.48 + CGFloat(i) * 0.06
                let phase = (e - 41.5).truncatingRemainder(dividingBy: 1.6)
                if phase < 0.45 { return (0.50, 0.30) }
                return (0.40, rowY)
            case ..<58:
                if e < 51.5 { return (0.50, 0.92) }       // grab icons from bottom
                if e < 53.0 { return (0.50, 0.70) }
                if e < 54.5 { return (0.22, 0.92) }       // grab train
                if e < 55.5 { return (0.28, 0.78) }
                if e < 56.5 { return (0.78, 0.92) }       // grab dict
                return (0.72, 0.78)
            default: return (0.82, 0.12)
            }
        }

        let cxcy = cursorAt(t)
        let prev = cursorAt(max(0, t - 0.22))
        let moveStart: TimeInterval = {
            switch focus {
            case .boot: return 0
            case .voiceShell: return t < 3.6 ? 2.5 : 3.6
            case .textMode:
                if t < 8.5 { return 7.0 }
                if t < 10.2 { return 8.5 }
                if t < 11.2 { return 10.2 }
                if t < 12.2 { return 11.2 }
                return 12.2
            case .voiceBack: return 13.5
            case .assemble: return t < 17.2 ? 16.0 : (t < 18.5 ? 17.2 : 18.5)
            case .states: return t < 23.5 ? 21.5 : (t < 24.8 ? 23.5 : 24.8)
            case .listen: return 27.0
            case .result:
                if t < 35.2 { return 34.0 }
                if t < 37.5 { return 35.2 }
                if t < 38.0 { return 37.5 }
                return 38.0
            case .gloss: return 41.0 + floor((t - 41.0) / 1.6) * 1.6
            case .actions:
                if t < 51.5 { return 50.0 }
                if t < 53.0 { return 51.5 }
                if t < 54.5 { return 53.0 }
                if t < 55.5 { return 54.5 }
                if t < 56.5 { return 55.5 }
                return 56.5
            case .settle: return 58.0
            }
        }()
        let move = min(1, max(0, (t - moveStart) / 0.28))

        let clickTimes: [TimeInterval] = [
            1.6,
            3.55, 4.35,                     // grab/drop mode
            8.45, 10.1, 11.15, 12.15,       // text pieces
            14.2,
            17.15, 18.4, 19.0, 19.7, 20.4,  // planet + palette
            22.8, 24.15, 25.55,             // state taps
            24.75, 25.9,                    // CTA grab/drop
            28.8, 32.4,
            35.15, 36.2,                    // phrase
            37.95, 38.5, 39.05,             // color tokens чик-чик-чик
            42.0, 43.6, 45.2,               // gloss rows (3)
            51.4, 52.8, 54.4, 55.4, 56.4,   // actions
            60.5
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.09 { return CGFloat(1 - d / 0.09) }
            }
            return 0
        }()

        let grab: CGFloat = max(
            pulse(3.4, 3.7, 4.5),
            pulse(8.3, 8.7, 10.3),
            pulse(11.0, 11.3, 12.3),
            pulse(16.9, 17.3, 18.5),
            pulse(24.5, 24.9, 26.0),
            pulse(34.9, 35.3, 36.5),
            pulse(37.6, 38.2, 39.8),
            pulse(41.7, 42.2, 43.0),
            pulse(43.3, 43.8, 44.6),
            pulse(44.9, 45.4, 46.2),
            pulse(51.1, 51.5, 53.0),
            pulse(54.1, 54.5, 55.6),
            pulse(56.1, 56.5, 57.4)
        )

        // Sphere early color; result/gloss B&W until token clicks settle on accent
        let sphereColorful = t >= 20.5 && t < 34.0
        // Color locks only after the last чик (accent) — not a wash/scan
        let resultPaint = ramp(39.2, 39.9)
        let colorful = sphereColorful || resultPaint > 0.55

        return StoryLabSpeakerScene(
            grid: ramp(0.15, 1.0) * (1 - ramp(61.5, 63.5)),
            header: ramp(0.2, 1.4),
            titleType: ramp(0.8, 2.4),
            modeDock: snap(3.6, 4.3),
            dotsDock: snap(4.4, 5.0),
            sphereDock: {
                switch focus {
                case .voiceShell: return snap(3.9, 4.5)
                case .voiceBack: return snap(13.8, 14.4)
                case .assemble: return snap(17.0, 17.8)
                case .states, .listen: return 1
                default: return sphere > 0.2 ? 1 : 0
                }
            }(),
            sphere: sphere,
            planetMode: planetMode,
            planetKind: planetKind,
            palette: max(
                ramp(18.6, 19.2) * (1 - ramp(20.8, 21.5)),
                ramp(37.3, 38.0) * (1 - ramp(40.2, 41.0))
            ),
            paletteIndex: paletteIndex,
            colorful: colorful,
            resultPaint: resultPaint,
            isTextMode: isTextMode,
            fieldDock: focus == .textMode ? snap(8.5, 9.3) : 0,
            translateDock: focus == .textMode ? snap(11.0, 11.7) : 0,
            backVoiceDock: focus == .textMode ? snap(12.2, 12.9) : (focus == .voiceBack ? 1 : 0),
            sayCTADock: {
                if focus == .states { return snap(24.8, 25.6) }
                if focus == .listen { return 1 }
                return 0
            }(),
            isRecording: isRecording,
            resultDock: snap(35.2, 36.2) * (t >= 34 ? 1 : 0),
            gloss: ramp(41.0, 42.2),
            glossCount: glossCount,
            glossLoading: t >= 39.8 && t < 41.4,
            iconsDock: snap(51.5, 52.4),
            trainDock: snap(54.5, 55.3),
            dictDock: snap(56.5, 57.2),
            morePhrase: ramp(57.3, 58.2),
            dictSaved: t >= 57.0,
            dictPulse: pulse(57.0, 57.4, 58.5),
            dictCount: t >= 57.0 ? 12 : 11,
            ready: ramp(59.5, 61.5),
            marquee: grab,
            grab: grab,
            copyFlash: max(
                pulse(12.5, 13.0, 13.8),
                pulse(20.5, 21.0, 21.8),
                pulse(39.0, 39.4, 40.2),
                pulse(48.5, 49.0, 50.0),
                pulse(57.0, 57.5, 58.5)
            ),
            figmaChip: figmaChip,
            editorTag: editorTag,
            actionChip: actionChip,
            focus: focus,
            cursorX: lerp(prev.0, cxcy.0, move),
            cursorY: lerp(prev.1, cxcy.1, move),
            click: click
        )
    }
}

/// Одна фраза везде: composer → result → РАЗБОР (1:1 с Thai).
/// «Можно скидку?» = ลดได้ไหม
private enum StoryLabSpeakerCopy {
    static let ru = "Можно скидку?"
    static let ruSoft = "можно скидку?"
    static let phonetic = "ло́т да́й ма́й"
    static let thai = "ลดได้ไหม"
}

private let storyLabSmartGloss: [StoryLabGlossWord] = [
    .init(id: "w0", phonetic: "ло́т", meaning: "скидка"),
    .init(id: "w1", phonetic: "да́й", meaning: "можно"),
    .init(id: "w2", phonetic: "ма́й", meaning: "ли?")
]

// MARK: - Session

struct StoryLabEditorSpeakerSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabSpeakerClock()
    @State private var showControls = false

    private var scene: StoryLabSpeakerScene { .at(clock.t) }

    private var stageSaturation: Double {
        if scene.isTextMode { return 1 }
        switch scene.focus {
        case .result, .gloss, .actions, .settle:
            return 0.18 + 0.82 * Double(scene.resultPaint)
        default:
            return scene.colorful ? 1 : 0.25
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PD.ColorToken.background.ignoresSafeArea()

                if scene.isTextMode {
                    TaikaTechnoSpaceBackdrop(intensity: 0.72)
                        .ignoresSafeArea()
                        .opacity(Double(max(scene.fieldDock, 0.35)))
                        .allowsHitTesting(false)
                }

                gridOverlay
                    .opacity(scene.grid * (scene.isTextMode ? 0.25 : 1))
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    speakerHeader
                        .opacity(scene.header)
                        .allowsHitTesting(false)

                        mainStage
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .saturation(stageSaturation)

                    ToolBar(selectedTab: .constant(2))
                        .allowsHitTesting(false)
                        .padding(.bottom, 2)
                        .opacity(Double(scene.header))
                }

                if scene.palette > 0.05 {
                    accentPalette
                        .opacity(scene.palette)
                        .allowsHitTesting(false)
                }
                if scene.marquee > 0.08 {
                    grabMarquee(in: geo.size)
                        .opacity(scene.marquee)
                        .allowsHitTesting(false)
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
            .animation(.easeOut(duration: 0.18), value: scene.planetMode)
            .animation(.easeOut(duration: 0.16), value: scene.isTextMode)
            .animation(.easeOut(duration: 0.12), value: scene.paletteIndex)
            .animation(.easeOut(duration: 0.28), value: scene.resultPaint)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: scene.glossCount)
            .animation(.easeOut(duration: 0.15), value: scene.dictSaved)
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

    // MARK: Drag helper — piece follows grab, then docks

    private func placed<V: View>(
        _ view: V,
        dock: CGFloat,
        from dx: CGFloat,
        dy: CGFloat,
        grabLift: Bool = true
    ) -> some View {
        let scatter = 1 - dock
        let lifting = grabLift && scene.grab > 0.2 && scatter > 0.15 && scatter < 0.95
        return view
            .offset(x: dx * scatter, y: dy * scatter)
            .scaleEffect(lifting ? 1.06 : (0.94 + 0.06 * dock))
            .opacity(Double(min(1, dock * 1.35 + (lifting ? 0.35 : 0))))
            .overlay {
                if lifting {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.cyan.opacity(0.7), style: StrokeStyle(lineWidth: 1.4, dash: [5, 3]))
                        .padding(-6)
                }
            }
            .zIndex(lifting ? 8 : 0)
    }

    // MARK: Header

    private var speakerHeader: some View {
        HStack(spacing: 12) {
            brandMark
            Spacer(minLength: 8)
            Text(typedTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text.opacity(0.9))
            Spacer(minLength: 8)
            dictionaryHeaderChip
            crownChip
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var brandMark: some View {
        HStack(spacing: 2) {
            Text("tai").font(.custom("Onmark Trial", size: 20)).foregroundStyle(.white)
            Text("kAAA").font(.custom("Onmark Trial", size: 20)).foregroundStyle(theme.currentAccentFill)
        }
    }

    private var dictionaryHeaderChip: some View {
        let pulsing = scene.dictPulse > 0.2
        let accent = theme.currentAccentTintColor
        return HStack(spacing: 5) {
            Image(systemName: scene.dictSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pulsing ? accent : Color.white.opacity(0.85))
                .scaleEffect(1 + 0.18 * scene.dictPulse)
            Text("\(scene.dictCount)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(pulsing ? accent : Color.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
            Capsule()
                .fill(Color.white.opacity(scene.dictPulse > 0.15 ? 0.16 : 0.08))
                .overlay(Capsule().stroke(accent.opacity(0.65 * scene.dictPulse), lineWidth: 1.2))
        )
    }

    private var crownChip: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.white.opacity(0.08)))
    }

    private var typedTitle: String {
        let full = "Скажи сам"
        let n = max(0, Int(ceil(Double(full.count) * Double(scene.titleType))))
        return String(full.prefix(n))
    }

    // MARK: Main

    private var mainStage: some View {
        let showVoicePlanet = !scene.isTextMode
            && scene.sphere > 0.05
            && scene.focus != .gloss
            && scene.focus != .actions
            && scene.focus != .settle
            && !(scene.focus == .result && scene.resultDock > 0.7)

        return VStack(spacing: 0) {
            if !scene.isTextMode, scene.modeDock > 0.02 {
                placed(
                    modeSwitch(toText: true),
                    dock: scene.modeDock,
                    from: 120, dy: -36
                )
                .padding(.top, 8)
            }

            if !scene.isTextMode, scene.dotsDock > 0.02 {
                placed(pageDots, dock: scene.dotsDock, from: 0, dy: -20)
                    .padding(.top, 10)
            }

            Spacer(minLength: 4)

            if scene.isTextMode {
                textComposerStage
            } else if showVoicePlanet {
                voicePlanetStage
            }

            if scene.resultDock > 0.02 || scene.gloss > 0.02 {
                resultAndGloss
                    .padding(.horizontal, CD.Spacing.screen)
            }

            if scene.focus == .actions || scene.focus == .settle || (scene.iconsDock + scene.trainDock) > 0.02 {
                resultActions
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.top, 10)
            }

            Spacer(minLength: 8)
        }
    }

    private var voicePlanetStage: some View {
        VStack(spacing: 12) {
            placed(
                TaikaVoicePlanet(
                    mode: scene.planetMode,
                    kind: .voice,
                    scale: 1.0,
                    centerSymbol: "mic.fill",
                    lite: false,
                    inviteTap: scene.planetMode == .idle,
                    audioLevel: scene.isRecording ? 0.55 : 0.12,
                    palette: .theme,
                    idleAccent: scene.colorful ? 0.55 : 0.28
                )
                .frame(width: 240, height: 240)
                .environmentObject(theme),
                dock: max(scene.sphereDock, scene.sphere),
                from: -160, dy: 40
            )
            .opacity(Double(scene.sphere))
            .frame(height: 250)

            if scene.sayCTADock > 0.02 {
                placed(sayCTA, dock: scene.sayCTADock, from: 90, dy: 50)
            }
        }
    }

    /// Exact conversation listen chrome: speaker circle + Сказать/Стоп capsule
    private var sayCTA: some View {
        HStack(spacing: 16) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.white.opacity(0.08)))

            HStack(spacing: 10) {
                Image(systemName: scene.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(scene.isRecording ? "Стоп" : (scene.planetMode == .cooking ? "Секунду…" : "Сказать"))
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(scene.isRecording ? .white : .black)
            .padding(.horizontal, 28)
            .frame(height: 56)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        scene.isRecording
                        ? AnyShapeStyle(Color.white.opacity(0.18))
                        : AnyShapeStyle(theme.currentAccentFill)
                    )
            )
        }
    }

    /// Exact mode switch from SpeakerDS
    private func modeSwitch(toText: Bool) -> some View {
        HStack(spacing: 8) {
            if toText {
                Text("Текст")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "keyboard")
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            } else {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                Image(systemName: "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Голос")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .foregroundStyle(PD.ColorToken.text.opacity(0.9))
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: 1)
                )
        )
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(!scene.isTextMode ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.22)))
                .frame(width: !scene.isTextMode ? 18 : 7, height: 7)
            Capsule()
                .fill(scene.isTextMode ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.22)))
                .frame(width: scene.isTextMode ? 18 : 7, height: 7)
        }
    }

    /// Exact text composer panel
    private var textComposerStage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .center, spacing: 18) {
                placed(
                    Text("Любая фраза…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity),
                    dock: scene.fieldDock,
                    from: 80, dy: -30
                )

                placed(
                    Text(StoryLabSpeakerCopy.ruSoft)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(PD.ColorToken.text)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 88)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .center) {
                            HStack {
                                Spacer().frame(width: 148)
                                Rectangle()
                                    .fill(theme.currentAccentTintColor)
                                    .frame(width: 2, height: 24)
                                    .opacity(Int(clock.t * 2) % 2 == 0 ? 1 : 0.12)
                                Spacer()
                            }
                        },
                    dock: scene.fieldDock,
                    from: 110, dy: 20
                )

                placed(
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                        Text("Перевести")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: TaikaOverlayTokens.Layout.primaryButtonHeight)
                    .background(Capsule(style: .continuous).fill(theme.currentAccentFill)),
                    dock: scene.translateDock,
                    from: -100, dy: 40
                )

                placed(
                    modeSwitch(toText: false),
                    dock: scene.backVoiceDock,
                    from: 0, dy: 50
                )
                .padding(.top, 4)
            }
            .padding(.horizontal, CD.Spacing.screen)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }

    // MARK: Result + gloss (exact layout)

    private var resultAndGloss: some View {
        let painted = scene.resultPaint
        return VStack(alignment: .center, spacing: 18) {
            if scene.resultDock > 0.02 {
                placed(resultCenter, dock: scene.resultDock, from: 0, dy: -90)
                    .saturation(0.2 + 0.8 * Double(painted))
            }

            if scene.glossLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(theme.currentAccentTintColor)
                    Text("собираю разбор…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if scene.gloss > 0.05 {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text("РАЗБОР")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.78))
                        Text("·")
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.35))
                        Text("\(max(scene.glossCount, 1))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.55))
                        Spacer(minLength: 0)
                    }

                    Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 14) {
                        ForEach(Array(storyLabSmartGloss.prefix(max(scene.glossCount, 0)).enumerated()), id: \.element.id) { i, word in
                            let dock = glossRowDock(i)
                            let scatter = 1 - dock
                            let lifting = scene.grab > 0.2 && scatter > 0.15 && scatter < 0.95
                            GridRow {
                                Text(word.phonetic)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(
                                        painted > 0.55
                                        ? AnyShapeStyle(theme.currentAccentFill)
                                        : AnyShapeStyle(PD.ColorToken.text)
                                    )
                                    .fixedSize(horizontal: true, vertical: false)
                                Text("—")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.42))
                                Text(word.meaning)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.text.opacity(0.82))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .opacity(Double(min(1, dock * 1.35 + (lifting ? 0.35 : 0))))
                            .offset(y: -48 * scatter)
                            .scaleEffect(lifting ? 1.05 : (0.94 + 0.06 * dock), anchor: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .opacity(Double(scene.gloss))
                .saturation(0.25 + 0.75 * Double(painted))
            }
        }
    }

    private func glossRowDock(_ index: Int) -> CGFloat {
        let start = 41.5 + Double(index) * 1.6
        let t = clock.t
        guard t >= start else { return 0 }
        return min(1, max(0, CGFloat((t - start) / 0.4)))
    }

    /// Exact result center: ПО-РУССКИ / КАК СКАЗАТЬ
    private var resultCenter: some View {
        VStack(alignment: .center, spacing: 18) {
            VStack(alignment: .center, spacing: 10) {
                Text("ПО-РУССКИ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
                Text(StoryLabSpeakerCopy.ru)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 48)

            VStack(alignment: .center, spacing: 14) {
                Text("КАК СКАЗАТЬ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))

                Text(StoryLabSpeakerCopy.phonetic)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        scene.resultPaint > 0.55
                        ? AnyShapeStyle(theme.currentAccentFill)
                        : AnyShapeStyle(PD.ColorToken.text)
                    )
                    .multilineTextAlignment(.center)

                HStack(alignment: .top, spacing: 8) {
                    Text(StoryLabSpeakerCopy.thai)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(PD.ColorToken.text.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Exact conversationResultActions
    private var resultActions: some View {
        VStack(spacing: 18) {
            placed(
                HStack(spacing: 28) {
                    Spacer(minLength: 0)
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.currentAccentFill)
                        .frame(width: 44, height: 44)
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.currentAccentFill)
                        .frame(width: 44, height: 44)
                    Spacer(minLength: 0)
                },
                dock: scene.iconsDock,
                from: 0, dy: 70
            )

            HStack(spacing: 10) {
                placed(
                    Label("Тренировать", systemImage: "mic.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Capsule(style: .continuous).fill(theme.currentAccentFill)),
                    dock: scene.trainDock,
                    from: -80, dy: 60
                )

                placed(
                    Label(
                        scene.dictSaved ? "В словаре" : "В словарь",
                        systemImage: scene.dictSaved ? "checkmark" : "bookmark.fill"
                    )
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(scene.dictSaved ? PD.ColorToken.textSecondary : PD.ColorToken.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Capsule(style: .continuous)
                            .fill(scene.dictSaved ? PD.ColorToken.chip.opacity(0.72) : PD.ColorToken.chip.opacity(0.94))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                            )
                    ),
                    dock: scene.dictDock,
                    from: 80, dy: 60
                )
            }

            Label("Сказать ещё одну фразу", systemImage: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .opacity(Double(scene.morePhrase))
                .offset(y: (1 - scene.morePhrase) * 16)
        }
    }

    // MARK: Palette / overlays

    // MARK: Palette / color tokens (чик-чик — как везде)

    private var accentPalette: some View {
        let isResultTokens = clock.t >= 37.0 && clock.t < 41.0
        let colors: [Color] = [
            theme.currentAccentTintColor,
            TaikaMasteryTokens.continueSky,
            TaikaMasteryTokens.green
        ]
        let labels = ["accent", "sky", "done"]
        return VStack(alignment: .leading, spacing: 10) {
            Text(isResultTokens ? "COLOR TOKENS" : "SPHERE TOKENS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .tracking(0.7)
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    let on = i == scene.paletteIndex
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(colors[i])
                            .frame(width: 28, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(on ? 0.95 : 0.15), lineWidth: on ? 2.4 : 1)
                            )
                            .shadow(color: colors[i].opacity(on ? 0.55 : 0), radius: 8)
                            .scaleEffect(on ? 1.1 : 1)
                        Text(labels[i])
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(on ? 0.9 : 0.4))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isResultTokens ? .center : .bottomTrailing)
        .padding(.trailing, isResultTokens ? 0 : 16)
        .padding(.bottom, isResultTokens ? 0 : 120)
        .offset(y: isResultTokens ? 40 : 0)
    }

    private func grabMarquee(in size: CGSize) -> some View {
        let x = size.width * scene.cursorX
        let y = size.height * scene.cursorY
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.cyan.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, dash: [5, 3]))
            .frame(width: 120 + 40 * scene.grab, height: 44 + 20 * scene.grab)
            .position(x: x, y: y - 10)
            .allowsHitTesting(false)
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

    private var copyToast: some View {
        let label: String = {
            switch scene.focus {
            case .textMode: return "Drop · text composer"
            case .assemble: return "Drop · TaikaVoicePlanet"
            case .result: return "Drop · resultCenter"
            case .gloss: return "Drop · SmartSpeakerPart"
            case .actions: return "Drop · result actions"
            default: return "Drop · conversation shell"
            }
        }()
        return HStack(spacing: 8) {
            Image(systemName: "hand.draw.fill")
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
        Text("готово · умный спикер")
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
