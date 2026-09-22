#if DEBUG

//
//  TaikaStoryLabBrandSession.swift
//  taika
//
//  Story Lab — Айдентика · foundation (~60s).
//  Хаос → DNA-токены → layout/glass → header+toolbar →
//  рождение сферы (характер) → слой AppDS под телефоном.
//  Editor B-roll: курсор, клики, scale handles, grab/drop.
//  Тезис: идентика сажает интерфейс на палец заранее.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabBrandClock: ObservableObject {
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

enum StoryLabBrandFocus: Equatable {
    case void, dna, layout, header, toolbar, sphere, system, settle
}

enum StoryLabBrandSphereBeat: Equatable {
    case assemble, idle, listening, cooking, settle
}

struct StoryLabBrandScene: Equatable {
    var bg: CGFloat
    var seed: CGFloat
    var grid: CGFloat
    var gridDraw: CGFloat
    var brandHero: CGFloat
    var brandHeroLetters: Int
    var foundation: CGFloat
    var foundationStep: Int
    /// 0…1 набор значения в активной ячейке (type-in).
    var tokenType: CGFloat
    var layoutGuides: CGFloat
    var glassWash: CGFloat
    var headerDock: CGFloat
    var headerIcons: CGFloat
    var accentVariant: Int
    var toolbarDock: CGFloat
    var toolbarStretch: CGFloat
    var toolbarRadius: CGFloat
    var toolbarBlur: CGFloat
    var toolbarSelected: Int
    var sphereDock: CGFloat
    var sphereAssemble: CGFloat
    var sphereScale: CGFloat
    var sphereOffsetX: CGFloat
    var sphereOffsetY: CGFloat
    var sphereBeat: StoryLabBrandSphereBeat
    var sphereAudio: CGFloat
    var sphereIconIndex: Int
    var sphereSwipe: CGFloat
    var paint: CGFloat
    var colorful: Bool
    var scaleHUD: CGFloat
    var selectBox: CGFloat
    var systemLayer: CGFloat
    var systemTokens: CGFloat
    var systemLink: CGFloat
    /// Чистая примерка иконок — без AppDS-панели и без grab-каши.
    var tryOn: CGFloat
    /// Сфера на месте → живые AppHeader / ToolBar вместо черновика.
    var chromeLive: CGFloat
    var ready: CGFloat
    var grab: CGFloat
    var focus: StoryLabBrandFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var actionChip: String?
    var figmaChip: String?
    var editorTag: String?

    static func at(_ t: TimeInterval) -> StoryLabBrandScene {
        func ramp(_ a: TimeInterval, _ b: TimeInterval) -> CGFloat {
            guard b > a else { return t >= b ? 1 : 0 }
            return CGFloat(min(1, max(0, (t - a) / (b - a))))
        }
        func snap(_ a: TimeInterval, _ b: TimeInterval) -> CGFloat {
            ramp(a, min(b, a + 0.38))
        }
        func pulse(_ a: TimeInterval, _ peak: TimeInterval, _ b: TimeInterval) -> CGFloat {
            if t < a || t >= b { return 0 }
            return t < peak ? ramp(a, peak) : 1 - ramp(peak, b)
        }
        func lerp(_ a: CGFloat, _ b: CGFloat, _ u: CGFloat) -> CGFloat {
            a + (b - a) * min(1, max(0, u))
        }

        // 0–3     void → grid → Ч/Б taikAAA (wow)
        // 3–9     foundation tokens type-in
        // 9–14    layout + glass
        // 14–20   header
        // 20–27   toolbar
        // 27–44   sphere character
        // 44–48.5 AppDS only (тихо)
        // 48.5–54 try-on icons only (chic-chic)
        // 54–60   settle

        let focus: StoryLabBrandFocus = {
            switch t {
            case ..<3.0: return .void
            case ..<9: return .dna
            case ..<14: return .layout
            case ..<20: return .header
            case ..<27: return .toolbar
            case ..<44: return .sphere
            case ..<54: return .system
            default: return .settle
            }
        }()

        let accentVariant: Int = {
            if t < 16.2 { return 0 }
            if t < 17.4 { return 1 }
            return 2
        }()

        let toolbarRadius: CGFloat = {
            if t < 21.5 { return 12 }
            if t < 23.2 { return 28 }
            if t < 24.8 { return 18 }
            return 22
        }()

        let sphereScale: CGFloat = {
            if t < 30.0 { return 0.72 }
            if t < 32.5 { return 1.14 }
            if t < 35.0 { return 0.86 }
            if t < 38.0 { return 1.02 }
            return 0.96
        }()
        let sphereOffsetX: CGFloat = {
            if t < 30.5 { return -0.14 }
            if t < 33.0 { return 0.16 }
            if t < 36.0 { return -0.05 }
            return 0
        }()
        let sphereOffsetY: CGFloat = {
            if t < 31.0 { return 0.10 }
            if t < 33.5 { return -0.08 }
            if t < 36.5 { return 0.04 }
            return 0
        }()

        let sphereBeat: StoryLabBrandSphereBeat = {
            if t < 30.2 { return .assemble }
            if t < 34.5 { return .idle }
            if t < 37.5 { return .listening }
            if t < 40.0 { return .cooking }
            return .settle
        }()

        // Letters of "taikAAA" appear 0.7→2.6s
        let brandHeroLetters: Int = {
            if t < 0.75 { return 0 }
            if t < 1.0 { return 1 }
            if t < 1.25 { return 2 }
            if t < 1.5 { return 3 }
            if t < 1.8 { return 4 }
            if t < 2.05 { return 5 }
            if t < 2.3 { return 6 }
            return 7
        }()

        // Token cells: step + type-in within step
        let foundationStep: Int = {
            if t < 3.4 { return -1 }
            if t < 4.6 { return 0 }
            if t < 5.7 { return 1 }
            if t < 6.8 { return 2 }
            return 3
        }()
        let tokenType: CGFloat = {
            let windows: [(TimeInterval, TimeInterval)] = [
                (3.45, 4.35), (4.65, 5.45), (5.75, 6.55), (6.85, 7.75)
            ]
            guard foundationStep >= 0, foundationStep < windows.count else {
                return foundationStep >= 3 ? 1 : 0
            }
            let w = windows[foundationStep]
            return ramp(w.0, w.1)
        }()

        let tryOn = ramp(48.5, 49.0) * (1 - ramp(53.6, 54.2))

        // Icon try-on ONLY in dedicated window
        let sphereIconIndex: Int = {
            guard t >= 48.6 else { return 2 }
            if t < 49.5 { return 0 }
            if t < 50.4 { return 1 }
            if t < 51.3 { return 2 }
            if t < 52.2 { return 3 }
            if t < 53.2 { return 4 }
            return 2
        }()

        let sphereSwipe: CGFloat = {
            guard tryOn > 0.5 else { return 0 }
            let cuts: [TimeInterval] = [48.6, 49.5, 50.4, 51.3, 52.2]
            for c in cuts {
                let d = t - c
                if d >= 0, d < 0.26 {
                    let u = CGFloat(d / 0.26)
                    return (1 - u) * (u < 0.4 ? 0.85 : -0.25)
                }
            }
            return 0
        }()

        let toolbarSelected: Int = {
            if tryOn > 0.4 { return min(4, max(0, sphereIconIndex)) }
            if t < 25.5 { return 0 }
            if t < 26.2 { return 2 }
            return 0
        }()

        let actionChip: String? = {
            if t >= 0.6 && t < 2.8 { return "name · from scratch" }
            if t >= 3.4 && t < 8.2 { return "tokens · type-in" }
            if t >= 9.2 && t < 13.5 { return "layout · glass" }
            if t >= 14.2 && t < 19.5 { return "header · finger top" }
            if t >= 20.2 && t < 26.5 { return "toolbar · finger base" }
            if t >= 27.2 && t < 31.0 { return "character · assemble" }
            if t >= 31.2 && t < 36.0 { return "edit · move / scale" }
            if t >= 36.2 && t < 41.5 { return "states · invite action" }
            if t >= 41.8 && t < 43.5 { return "paint · brand" }
            if t >= 44.5 && t < 48.2 { return "system · AppDS" }
            if t >= 48.7 && t < 53.2 { return "try-on · pages" }
            return nil
        }()

        let figmaChip: String? = {
            if t >= 1.0 && t < 2.8 { return "wordmark · Onmark · B&W" }
            if t >= 3.5 && t < 8.0 { return "grid · radius · stroke · gradient" }
            if t >= 9.5 && t < 13.0 { return "guides · safe · zones" }
            if t >= 14.5 && t < 19.0 { return "Header · taikAAA" }
            if t >= 20.5 && t < 26.0 { return "ToolBar · liquid glass" }
            if t >= 28.0 && t < 42.0 { return "TaikaVoicePlanet" }
            if t >= 44.8 && t < 48.2 { return "AppDS.swift" }
            if t >= 49.0 && t < 53.0 { return "sphere · page icons" }
            return nil
        }()

        let editorTag: String? = {
            if t >= 0.9 && t < 2.6 { return "Draw · name" }
            if t >= 3.6 && t < 7.6 { return "Type · tokens" }
            if t >= 10.0 && t < 12.8 { return "Guides · align" }
            if t >= 15.0 && t < 18.5 { return "Drop · wordmark" }
            if t >= 21.0 && t < 25.0 { return "Stretch · radius" }
            if t >= 29.0 && t < 32.5 { return "Scale · handles" }
            if t >= 33.0 && t < 36.0 { return "Drag · center" }
            if t >= 49.0 && t < 53.0 { return "Swipe · icons" }
            return nil
        }()

        func cursorAt(_ e: TimeInterval) -> (CGFloat, CGFloat) {
            switch e {
            case ..<3.0: return (0.50, 0.38)
            case ..<9:
                if e < 3.5 { return (0.50, 0.58) }
                if e < 4.6 { return (0.36, 0.62) }
                if e < 5.7 { return (0.64, 0.62) }
                if e < 6.8 { return (0.36, 0.74) }
                return (0.64, 0.74)
            case ..<14: return (0.50, e < 11.2 ? 0.18 : 0.82)
            case ..<20:
                if e < 15.5 { return (0.86, 0.10) }
                if e < 17.0 { return (0.30, 0.11) }
                return (0.78, 0.12)
            case ..<27:
                if e < 21.5 { return (0.50, 0.94) }
                if e < 24.0 { return (0.72, 0.86) }
                return (0.50, 0.88)
            case ..<44:
                if e < 29.2 { return (0.10, 0.46) }
                if e < 32.5 { return (0.50 + sphereOffsetX * 0.45, 0.40 + sphereOffsetY * 0.45) }
                if e < 36.0 { return (0.50 + sphereOffsetX * 0.55, 0.40 + sphereOffsetY * 0.55) }
                if e < 40.0 { return (0.50, 0.42) }
                return (0.70, 0.58)
            case ..<48.5:
                // AppDS panel — спокойный курсор справа
                return (0.82, 0.55)
            case ..<54:
                // Try-on — только горизонтальный свайп по сфере
                let local = CGFloat((e - 48.5).truncatingRemainder(dividingBy: 0.9))
                return (0.40 + local * 0.22, 0.44)
            default: return (0.50, 0.48)
            }
        }

        let cxcy = cursorAt(t)
        let prev = cursorAt(max(0, t - 0.22))
        let moveStart: TimeInterval = {
            switch focus {
            case .void: return 0
            case .dna:
                if t < 3.4 { return 2.5 }
                return 3.4 + floor((t - 3.4) / 1.1) * 1.1
            case .layout: return t < 11.2 ? 9.0 : 11.2
            case .header:
                if t < 15.5 { return 14.0 }
                if t < 17.0 { return 15.5 }
                return 17.0
            case .toolbar:
                if t < 21.5 { return 20.0 }
                if t < 24.0 { return 21.5 }
                return 24.0
            case .sphere:
                if t < 29.2 { return 27.0 }
                if t < 32.5 { return 29.2 }
                if t < 36.0 { return 32.5 }
                if t < 40.0 { return 36.0 }
                return 40.0
            case .system:
                if t < 48.5 { return 44.0 }
                return 48.5 + floor((t - 48.5) / 0.9) * 0.9
            case .settle: return 54.0
            }
        }()
        let move = min(1, max(0, (t - moveStart) / 0.26))

        let clickTimes: [TimeInterval] = [
            1.2, 1.8, 2.4,
            3.6, 4.7, 5.8, 6.9, 7.9,
            10.2, 11.8, 13.0,
            15.3, 16.5, 17.8, 18.8,
            21.2, 22.6, 24.2, 25.6,
            29.0, 30.5, 32.0, 33.5, 35.0, 36.8, 38.5, 40.5, 42.2,
            45.5, 47.0,
            49.0, 49.9, 50.8, 51.7, 52.6,
            56.0
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.09 { return CGFloat(1 - d / 0.09) }
            }
            return 0
        }()

        // Grab только там, где реально тащим UI — не на try-on и не на AppDS-чипах
        let grab: CGFloat = {
            if tryOn > 0.3 { return 0 }
            if t >= 44 && t < 48.5 { return 0 }
            return max(
                pulse(3.8, 4.2, 4.8),
                pulse(4.9, 5.3, 5.9),
                pulse(6.0, 6.4, 7.0),
                pulse(7.1, 7.5, 8.1),
                pulse(14.8, 15.4, 16.8),
                pulse(20.8, 21.4, 23.0),
                pulse(22.4, 23.0, 24.6),
                pulse(28.6, 29.2, 31.0),
                pulse(31.2, 32.0, 34.0),
                pulse(34.2, 35.0, 36.8)
            )
        }()

        return StoryLabBrandScene(
            bg: ramp(2.4, 4.2),
            seed: ramp(0.35, 0.9) * (1 - ramp(1.8, 2.6)),
            grid: ramp(0.8, 2.2) * (1 - ramp(55.0, 59.0)),
            gridDraw: ramp(0.7, 2.4),
            brandHero: ramp(0.55, 1.4) * (1 - ramp(7.8, 9.0)),
            brandHeroLetters: brandHeroLetters,
            foundation: ramp(3.2, 4.0) * (1 - ramp(8.3, 9.2)),
            foundationStep: foundationStep,
            tokenType: tokenType,
            layoutGuides: ramp(9.0, 10.5) * (1 - ramp(26.5, 28.5)),
            glassWash: ramp(10.5, 12.5),
            headerDock: snap(15.2, 16.2),
            headerIcons: ramp(17.6, 18.8),
            accentVariant: accentVariant,
            toolbarDock: snap(21.0, 22.0),
            toolbarStretch: pulse(21.8, 23.0, 25.0),
            toolbarRadius: toolbarRadius,
            toolbarBlur: ramp(22.5, 25.0),
            toolbarSelected: toolbarSelected,
            sphereDock: snap(29.0, 30.0),
            sphereAssemble: ramp(27.4, 30.0),
            sphereScale: sphereScale,
            sphereOffsetX: sphereOffsetX,
            sphereOffsetY: sphereOffsetY,
            sphereBeat: sphereBeat,
            sphereAudio: sphereBeat == .listening ? ramp(34.5, 35.5) * (1 - ramp(37.0, 37.5)) : 0,
            sphereIconIndex: sphereIconIndex,
            sphereSwipe: sphereSwipe,
            paint: ramp(40.5, 42.2),
            colorful: t >= 42.0,
            scaleHUD: (focus == .sphere && t >= 30.0 && t < 36.5) ? 1 : 0,
            selectBox: max(
                pulse(15.0, 15.6, 17.0),
                pulse(21.0, 21.8, 24.5),
                pulse(29.5, 30.5, 34.5)
            ),
            systemLayer: ramp(44.2, 45.5) * (1 - ramp(48.2, 48.8)),
            systemTokens: ramp(45.0, 46.2),
            systemLink: ramp(46.4, 47.6),
            tryOn: tryOn,
            chromeLive: ramp(29.2, 30.4),
            ready: ramp(55.5, 58.0),
            grab: grab,
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

// MARK: - Session

struct StoryLabEditorBrandSession: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Brand session")
                    .font(.system(size: 20, weight: .semibold))
                Text("Stubbed for compile · full cut returns after ship")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("Close") { dismiss() }
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(24)
        }
        .statusBarHidden(false)
        .navigationBarHidden(true)
    }
}

#endif
