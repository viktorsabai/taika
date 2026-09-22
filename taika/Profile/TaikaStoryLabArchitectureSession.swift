#if DEBUG

//
//  TaikaStoryLabArchitectureSession.swift
//  taika
//
//  Story Lab — Архитектура через тулбар (~54s).
//  Айдентика (хедер + сфера) → сборка живого ToolBar →
//  клик по вкладкам: заголовок typewriter + черновые сетки.
//  Без готовых экранов — только разметка / skeleton.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabArchClock: ObservableObject {
    @Published var t: TimeInterval = 0
    @Published var isPlaying = true
    let duration: TimeInterval = 54
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

enum StoryLabArchFocus: Equatable {
    case identity, toolbarBuild, home, courses, speaker, favorites, reinforce, settle
}

struct StoryLabArchScene: Equatable {
    var grid: CGFloat
    var header: CGFloat
    var sphere: CGFloat
    var toolbarBuild: CGFloat
    var toolbarStretch: CGFloat
    var toolbarRadius: CGFloat
    var toolbarIcons: CGFloat
    var iconCycle: Int
    var useRealToolbar: Bool
    var selectedTab: Int
    var titleType: CGFloat
    var pageTitle: String
    var slotsDock: CGFloat
    var iconPick: CGFloat
    var iconPickIndex: Int
    var courseUpload: CGFloat
    var courseFileIndex: Int
    var apiConnect: CGFloat
    var apiStep: Int
    var ready: CGFloat
    var marquee: CGFloat
    var boardSnap: CGFloat
    var copyFlash: CGFloat
    var figmaChip: String?
    var editorTag: String?
    var actionChip: String?
    var focus: StoryLabArchFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat

    static func at(_ t: TimeInterval) -> StoryLabArchScene {
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

        // 0–3.5 identity: header + B&W sphere + bare grid
        // 3.5–10 toolbar build (+ Notion/Figma side plaques)
        // 10–18 home (+ sphere)
        // 18–26 courses (cards only)
        // 26–34 speaker (+ sphere)
        // 34–42 favorites (cards)
        // 34–42 favorites (heart cards)
        // 42–50 reinforce (GamePark hub: sphere + chips + CTA)

        let focus: StoryLabArchFocus = {
            switch t {
            case ..<3.5: return .identity
            case ..<10: return .toolbarBuild
            case ..<18: return .home
            case ..<26: return .courses
            case ..<34: return .speaker
            case ..<42: return .favorites
            case ..<50: return .reinforce
            default: return .settle
            }
        }()

        let selectedTab: Int = {
            switch focus {
            case .identity, .toolbarBuild, .home: return 0
            case .courses: return 1
            case .speaker: return 2
            case .favorites: return 3
            case .reinforce, .settle: return 4
            }
        }()

        let pageTitle: String = {
            switch focus {
            case .home: return "Главная"
            case .courses: return "Курсы"
            case .speaker: return "Спикер"
            case .favorites: return "Избранное"
            case .reinforce: return "Закрепление"
            default: return ""
            }
        }()

        let titleType: CGFloat = {
            switch focus {
            case .home: return ramp(10.8, 12.2)
            case .courses: return ramp(18.6, 20.0)
            case .speaker: return ramp(26.6, 28.0)
            case .favorites: return ramp(34.6, 35.8)
            case .reinforce: return ramp(42.5, 43.6)
            default: return 0
            }
        }()

        let slotsDock: CGFloat = {
            switch focus {
            case .home: return ramp(12.4, 15.0)
            case .courses: return ramp(20.4, 23.2)
            case .speaker: return ramp(28.4, 31.2)
            case .favorites: return ramp(36.2, 39.0)
            case .reinforce: return ramp(44.0, 47.0)
            default: return 0
            }
        }()

        let iconPick: CGFloat = {
            switch focus {
            case .courses: return ramp(19.8, 20.6) * (1 - ramp(21.5, 22.3))
            case .speaker: return 0 // API panel instead of generic icon pick
            case .reinforce: return ramp(46.2, 47.0) * (1 - ramp(48.6, 49.2))
            default: return 0
            }
        }()

        let iconPickIndex: Int = {
            switch focus {
            case .courses:
                if t < 20.3 { return 0 }
                if t < 21.0 { return 1 }
                return 2
            case .reinforce:
                // Pick among hub modes ending on gamecontroller feel — not mic as hero
                if t < 46.8 { return 0 } // match
                if t < 47.5 { return 1 } // recall
                return 2 // speaker option (secondary)
            default: return 0
            }
        }()

        let courseUpload: CGFloat = focus == .courses ? ramp(20.6, 23.5) : 0
        let courseFileIndex: Int = {
            guard focus == .courses else { return 0 }
            if t < 21.2 { return 0 }
            if t < 21.8 { return 1 }
            if t < 22.4 { return 2 }
            if t < 23.0 { return 3 }
            return 4
        }()

        let apiConnect: CGFloat = focus == .speaker ? ramp(28.2, 31.5) : 0
        let apiStep: Int = {
            guard focus == .speaker else { return 0 }
            if t < 28.8 { return 0 } // idle
            if t < 29.5 { return 1 } // connect
            if t < 30.4 { return 2 } // /thai_phonetic
            if t < 31.2 { return 3 } // /assess tones
            return 4 // ready
        }()

        let iconCycle: Int = {
            if t < 6.2 { return 0 }
            if t < 6.9 { return 1 }
            if t < 7.6 { return 2 }
            if t < 8.3 { return 3 }
            return 4
        }()

        let actionChip: String? = {
            if t >= 0.3 && t < 3.0 { return "Identity · header + sphere" }
            if t >= 3.6 && t < 5.8 { return "Draw · toolbar capsule" }
            if t >= 6.0 && t < 8.5 { return "Icons · cycle SF Symbols" }
            if t >= 8.8 && t < 10.0 { return "Lock · real ToolBar" }
            if t >= 10.3 && t < 13.0 { return "Tab · Главная · agent hub" }
            if t >= 18.3 && t < 20.5 { return "Tab · Курсы" }
            if t >= 20.8 && t < 24.0 { return "Upload · course JSON" }
            if t >= 26.3 && t < 28.5 { return "Tab · Спикер" }
            if t >= 28.8 && t < 32.0 { return "API · connect engine" }
            if t >= 34.3 && t < 38.0 { return "Tab · Избранное · cards" }
            if t >= 42.3 && t < 45.5 { return "Tab · Закрепление · hub" }
            if t >= 46.0 && t < 49.0 { return "Add · Спикер в hub" }
            return nil
        }()

        let figmaChip: String? = {
            if t >= 0.8 && t < 3.2 { return "Component · brand header" }
            if t >= 4.0 && t < 6.5 { return "Frame · toolbar H=48" }
            if t >= 6.5 && t < 8.8 { return "Props · SF Symbols" }
            if t >= 9.0 && t < 10.2 { return "Instance · ToolBar.swift" }
            if t >= 11.0 && t < 13.5 { return "Text · Главная" }
            if t >= 19.0 && t < 21.0 { return "Text · Курсы" }
            if t >= 21.2 && t < 24.0 { return "Asset · taika_basa_course.json" }
            if t >= 27.0 && t < 29.0 { return "Text · Спикер" }
            if t >= 29.2 && t < 32.5 { return "Service · SpeakerManager API" }
            if t >= 35.0 && t < 38.0 { return "Text · Избранное" }
            if t >= 43.0 && t < 46.0 { return "Text · Закрепление" }
            if t >= 46.5 && t < 49.0 { return "Row · Reinforce · Спикер" }
            return nil
        }()

        let editorTag: String? = {
            if t >= 4.5 && t < 6.0 { return "Stretch · width" }
            if t >= 5.8 && t < 7.2 { return "Corner · radius 24" }
            if t >= 7.5 && t < 9.0 { return "Icon · swap" }
            if t >= 13.0 && t < 15.0 { return "Layout · agent center" }
            if t >= 21.5 && t < 23.5 { return "Load · JSON ×5" }
            if t >= 29.5 && t < 31.5 { return "POST · /assess" }
            if t >= 37.0 && t < 39.0 { return "Grid · favorite cards" }
            if t >= 46.5 && t < 48.5 { return "Hub · games + voice" }
            return nil
        }()

        func cursorAt(_ e: TimeInterval) -> (CGFloat, CGFloat) {
            switch e {
            case ..<3.5: return (0.50, 0.42)
            case ..<10:
                if e < 5.5 { return (0.50, 0.88) }
                if e < 8.2 {
                    let u = CGFloat(min(1, max(0, (e - 5.5) / 2.7)))
                    return (lerp(0.22, 0.78, u), 0.86)
                }
                return (0.50, 0.88)
            case ..<18:
                if e < 11.0 { return (0.18, 0.88) }
                if e < 12.5 { return (0.28, 0.16) }
                let u = CGFloat(min(1, max(0, (e - 12.5) / 3.5)))
                return (lerp(0.30, 0.70, u), lerp(0.32, 0.62, u))
            case ..<26:
                if e < 19.0 { return (0.35, 0.88) }
                if e < 20.5 { return (0.28, 0.16) }
                return (0.55, 0.50)
            case ..<34:
                if e < 27.0 { return (0.50, 0.88) }
                if e < 28.5 { return (0.28, 0.16) }
                return (0.50, 0.48)
            case ..<42:
                if e < 35.0 { return (0.68, 0.88) }
                if e < 36.5 { return (0.28, 0.16) }
                return (0.50, 0.52)
            case ..<50:
                if e < 43.0 { return (0.82, 0.88) }
                if e < 44.5 { return (0.28, 0.16) }
                if e < 46.5 { return (0.50, 0.42) }
                return (0.55, 0.58)
            default: return (0.50, 0.90)
            }
        }

        let cxcy = cursorAt(t)
        let prev = cursorAt(max(0, t - 0.28))
        let moveStart: TimeInterval = {
            switch focus {
            case .identity: return 0
            case .toolbarBuild: return t < 5.5 ? 3.5 : 5.5
            case .home: return t < 11 ? 10 : (t < 12.5 ? 11 : 12.5)
            case .courses: return t < 19 ? 18 : (t < 20.5 ? 19 : 20.5)
            case .speaker: return t < 27 ? 26 : (t < 28.5 ? 27 : 28.5)
            case .favorites: return t < 35 ? 34 : (t < 36.5 ? 35 : 36.5)
            case .reinforce: return t < 43 ? 42 : (t < 44.5 ? 43 : 45.5)
            case .settle: return 50
            }
        }()
        let move = min(1, max(0, (t - moveStart) / 0.28))

        let clickTimes: [TimeInterval] = [
            4.5, 6.0, 6.9, 7.8, 9.0,
            10.5, 12.6, 14.5,
            18.5, 20.5, 22.0,
            26.5, 28.5, 30.0,
            34.5, 36.5, 38.0,
            42.5, 45.8, 46.8, 47.8,
            51.0
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.1 { return CGFloat(1 - d / 0.1) }
            }
            return 0
        }()

        return StoryLabArchScene(
            grid: ramp(0.2, 1.2) * (1 - ramp(51.5, 53.5)),
            header: ramp(0.3, 1.5),
            sphere: ramp(1.0, 2.4),
            toolbarBuild: ramp(3.5, 4.8) * (1 - ramp(9.4, 10.2)),
            toolbarStretch: ramp(4.0, 5.5),
            toolbarRadius: ramp(5.2, 6.4),
            toolbarIcons: ramp(6.0, 8.2),
            iconCycle: iconCycle,
            useRealToolbar: t >= 8.8,
            selectedTab: selectedTab,
            titleType: titleType,
            pageTitle: pageTitle,
            slotsDock: slotsDock,
            iconPick: iconPick,
            iconPickIndex: iconPickIndex,
            courseUpload: courseUpload,
            courseFileIndex: courseFileIndex,
            apiConnect: apiConnect,
            apiStep: apiStep,
            ready: ramp(50.5, 52.5),
            marquee: max(
                pulse(4.2, 5.2, 7.0),
                pulse(11.0, 12.2, 14.0),
                pulse(19.0, 20.2, 22.0),
                pulse(27.0, 28.2, 30.0),
                pulse(35.0, 36.2, 38.0),
                pulse(43.0, 44.2, 46.0)
            ),
            boardSnap: max(
                ramp(3.6, 4.8) * (1 - ramp(5.6, 6.5)),
                ramp(12.6, 14.0) * (1 - ramp(15.2, 16.2)),
                ramp(20.6, 22.0) * (1 - ramp(23.2, 24.0)),
                ramp(28.6, 30.0) * (1 - ramp(31.2, 32.0)),
                ramp(36.4, 37.8) * (1 - ramp(39.0, 39.8)),
                ramp(44.2, 45.6) * (1 - ramp(46.8, 47.6))
            ),
            copyFlash: max(
                pulse(9.0, 9.6, 10.4),
                pulse(12.2, 12.8, 14.0),
                pulse(21.5, 22.2, 23.5),
                pulse(29.8, 30.5, 31.8),
                pulse(46.2, 47.0, 48.2)
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

// MARK: - Session

struct StoryLabEditorArchitectureSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabArchClock()
    @State private var showControls = false

    private var scene: StoryLabArchScene { .at(clock.t) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PD.ColorToken.background.ignoresSafeArea()

                gridOverlay
                    .opacity(scene.grid)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    brandHeader
                        .opacity(scene.header)
                        .allowsHitTesting(false)

                    ZStack {
                        // Sphere on identity / home / speaker; reinforce embeds its own hub planet
                        if showsSphere {
                            sphereLayer
                                .opacity(Double(scene.sphere) * sphereOpacity)
                                .allowsHitTesting(false)
                        }

                        pageDraft
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    toolbarZone
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
                if scene.iconPick > 0.05 {
                    iconPickerPlaque
                        .opacity(scene.iconPick)
                        .allowsHitTesting(false)
                }
                if scene.focus == .toolbarBuild || scene.focus == .identity {
                    architectureSourcePlaques
                        .opacity(Double(max(scene.toolbarBuild, scene.header * 0.5)))
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
            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: scene.selectedTab)
            .animation(.spring(response: 0.4, dampingFraction: 0.86), value: scene.slotsDock)
            .animation(.easeOut(duration: 0.15), value: scene.iconCycle)
            .animation(.easeOut(duration: 0.12), value: scene.iconPickIndex)
            .animation(.easeOut(duration: 0.22), value: scene.useRealToolbar)
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

    private var showsSphere: Bool {
        switch scene.focus {
        case .identity, .toolbarBuild, .home, .speaker:
            return true
        case .reinforce:
            // Sphere lives inside reinforce hub draft (GamePark), not as global backdrop
            return false
        default:
            return false
        }
    }

    private var sphereOpacity: Double {
        switch scene.focus {
        case .speaker: return 0.38
        case .home, .identity, .toolbarBuild: return 0.55
        default: return 0
        }
    }

    private func closeSession() {
        clock.stop()
        dismiss()
    }

    // MARK: Identity

    private var brandHeader: some View {
        HStack {
            HStack(spacing: 2) {
                Text("tai").font(.custom("Onmark Trial", size: 22)).foregroundStyle(.white)
                Text("kAAA").font(.custom("Onmark Trial", size: 22)).foregroundStyle(theme.currentAccentFill)
            }
            Spacer()
            Image(systemName: "crown.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var sphereLayer: some View {
        TaikaVoicePlanet(
            mode: .idle,
            kind: .voice,
            scale: 0.9,
            centerSymbol: "mic.fill",
            lite: true,
            inviteTap: false,
            audioLevel: 0.12,
            palette: .theme,
            idleAccent: 0.3
        )
        .frame(width: 210, height: 210)
        .saturation(0)
        .opacity(0.85)
        .environmentObject(theme)
        .allowsHitTesting(false)
    }

    // MARK: Page drafts (wire grids only)

    @ViewBuilder
    private var pageDraft: some View {
        switch scene.focus {
        case .identity, .toolbarBuild:
            emptyCanvasHint
        case .home:
            draftPage(title: "Главная", layout: .home)
        case .courses:
            draftPage(title: "Курсы", layout: .courses)
        case .speaker:
            draftPage(title: "Спикер", layout: .speaker)
        case .favorites:
            draftPage(title: "Избранное", layout: .favorites)
        case .reinforce:
            draftPage(title: "Закрепление", layout: .reinforce)
        case .settle:
            draftPage(title: "Закрепление", layout: .reinforce)
        }
    }

    private var emptyCanvasHint: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("canvas · empty")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.28))
            Text("только айдентика")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.35))
            Spacer()
        }
        .opacity(Double(1 - scene.toolbarBuild * 0.4))
    }

    private enum DraftLayout {
        case home, courses, speaker, favorites, reinforce
    }

    private func draftPage(title: String, layout: DraftLayout) -> some View {
        let typed = String(title.prefix(max(0, Int(ceil(Double(title.count) * Double(scene.titleType))))))
        let scatter = 1 - scene.slotsDock

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(typed.isEmpty ? " " : typed)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PD.ColorToken.text)
                    .frame(minHeight: 34, alignment: .leading)
                if scene.titleType > 0.05, scene.titleType < 0.98 {
                    Rectangle()
                        .fill(theme.currentAccentFill)
                        .frame(width: 2, height: 22)
                        .opacity(Int(clock.t * 4) % 2 == 0 ? 1 : 0.2)
                }
                Spacer()
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.top, 4)
            .opacity(Double(max(scene.titleType, 0.001)))

            Group {
                switch layout {
                case .home: homeWireSlots(scatter: scatter)
                case .courses: coursesWireSlots(scatter: scatter)
                case .speaker: speakerWireSlots(scatter: scatter)
                case .favorites: favoritesWireSlots(scatter: scatter)
                case .reinforce: reinforceWireSlots(scatter: scatter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(Double(max(scene.slotsDock, scene.titleType * 0.25)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func homeWireSlots(scatter: CGFloat) -> some View {
        VStack(spacing: 12) {
            wireSlot("TYPEWRITER · кун кру", h: 56)
                .offset(x: -70 * scatter)
            Spacer(minLength: 8)
            // Sphere lives in background — mark its zone
            wireSlot("SPHERE ZONE", h: 200)
                .offset(y: 28 * scatter)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                wireSlot("CTA", h: 48)
                wireSlot("CTA", h: 48)
                wireSlot("CTA", h: 48)
            }
            .offset(y: 36 * scatter)
            Spacer(minLength: 4)
            wireSlot("CHIPS · phrases", h: 44)
                .offset(x: 40 * scatter)
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity)
    }

    private func coursesWireSlots(scatter: CGFloat) -> some View {
        let files = [
            "taika_basa_course.json",
            "scenarios_cafe.json",
            "scenarios_market.json",
            "lifehacks.json",
            "progress_map.json"
        ]

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                wireChip("база")
                wireChip("сценарии")
                wireChip("избранное")
                Spacer()
                Text("catalog")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.cyan.opacity(0.7))
            }
            .padding(.horizontal, CD.Spacing.screen)
            .offset(x: -28 * scatter)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.up.doc.fill")
                        .foregroundStyle(theme.currentAccentFill)
                    Text("UPLOAD · course pack")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Spacer()
                    Text("\(min(scene.courseFileIndex + 1, files.count))/\(files.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.cyan.opacity(0.85))
                }
                ForEach(Array(files.enumerated()), id: \.offset) { i, name in
                    let loaded = i < scene.courseFileIndex || (i == scene.courseFileIndex && scene.courseUpload > 0.85)
                    let active = i == scene.courseFileIndex && scene.courseUpload > 0.1 && !loaded
                    HStack(spacing: 8) {
                        Image(systemName: loaded ? "checkmark.circle.fill" : "doc.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(loaded ? TaikaMasteryTokens.greenGlow : Color.white.opacity(0.35))
                        Text(name)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(loaded ? 0.9 : 0.4))
                        Spacer()
                        if active {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(theme.currentAccentTintColor)
                        }
                    }
                    .opacity(Double(max(scene.courseUpload, 0.2)))
                    .offset(x: (1 - scene.courseUpload) * CGFloat(40 + i * 8))
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(theme.currentAccentFill)
                            .frame(width: g.size.width * CGFloat(scene.courseUpload))
                    }
                }
                .frame(height: 4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.cyan.opacity(0.4), style: StrokeStyle(lineWidth: 1.1, dash: [5, 3]))
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.35)))
            )
            .padding(.horizontal, CD.Spacing.screen)
            .opacity(Double(max(scene.courseUpload, scene.slotsDock * 0.5)))

            GeometryReader { geo in
                let visible = min(3, max(1, scene.courseFileIndex))
                let cardH = max(180, geo.size.height - 4)
                HStack(spacing: 12) {
                    ForEach(0..<visible, id: \.self) { i in
                        wireCard(
                            title: ["в кафе", "на рынке", "база"][min(i, 2)],
                            subtitle: "from JSON · cover"
                        )
                        .frame(width: geo.size.width * 0.7)
                        .frame(height: cardH)
                        .offset(
                            x: scatter * CGFloat(i == 0 ? -50 : 30),
                            y: scatter * CGFloat(12 + i * 8)
                        )
                        .opacity(i == 0 ? 1 : 0.55)
                    }
                }
                .padding(.leading, CD.Spacing.screen)
            }
            .frame(maxHeight: .infinity)
            .opacity(Double(scene.slotsDock))
        }
        .frame(maxHeight: .infinity)
    }

    private func speakerWireSlots(scatter: CGFloat) -> some View {
        let sylOpacity = Double(scene.slotsDock) * (scene.apiStep >= 3 ? 1.0 : 0.35)
        let ctaOpacity = Double(scene.slotsDock) * (scene.apiStep >= 4 ? 1.0 : 0.3)

        return VStack(spacing: 10) {
            wireSlot("PROMPT · скажи по-русски", h: 48)
                .offset(x: -40 * scatter)

            apiEnginePanel
                .opacity(Double(max(scene.apiConnect, 0.25)))
                .offset(y: (1 - scene.apiConnect) * 24)

            Spacer(minLength: 4)

            ZStack {
                wireSlot("MIC / PLANET", h: 160)
                Circle()
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .frame(width: 110, height: 110)
            }
            .offset(y: 16 * scatter)
            .opacity(Double(scene.slotsDock))

            HStack(spacing: 10) {
                wireSlot("слог", h: 44)
                wireSlot("слог", h: 44)
                wireSlot("слог", h: 44)
            }
            .opacity(sylOpacity)

            wireSlot("CTA · разобрать тоны", h: 46)
                .opacity(ctaOpacity)
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity)
    }

    private var apiEnginePanel: some View {
        let steps: [(String, String)] = [
            ("idle", "engine idle"),
            ("connect", "ws · voice uplink"),
            ("/thai_phonetic", "POST phonetic"),
            ("/assess", "tones · syllables"),
            ("ready", "API live")
        ]
        let status = scene.apiStep >= 4 ? "CONNECTED" : "HANDSHAKE"
        let statusColor: Color = scene.apiStep >= 4 ? TaikaMasteryTokens.greenGlow : Color.orange

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(theme.currentAccentFill)
                Text("API ENGINE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))
                Spacer()
                Text(status)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusColor)
            }
            ForEach(0..<steps.count, id: \.self) { i in
                apiStepRow(index: i, title: steps[i].0, detail: steps[i].1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.cyan.opacity(0.45), style: StrokeStyle(lineWidth: 1.1, dash: [5, 3]))
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.4)))
        )
    }

    private func apiStepRow(index: Int, title: String, detail: String) -> some View {
        let on = index <= scene.apiStep && scene.apiConnect > 0.1
        let dot: Color = {
            guard on else { return Color.white.opacity(0.15) }
            return index == scene.apiStep ? theme.currentAccentTintColor : TaikaMasteryTokens.greenGlow
        }()
        return HStack(spacing: 8) {
            Circle()
                .fill(dot)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(on ? 0.95 : 0.35))
                .frame(width: 110, alignment: .leading)
            Text(detail)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(on ? 0.55 : 0.22))
            Spacer()
        }
    }

    private func favoritesWireSlots(scatter: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                wireChip("карточки")
                wireChip("список")
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill.opacity(0.9))
            }

            Text("♥ favorites · saved phrases")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(0..<6, id: \.self) { i in
                    heartWireCard(
                        title: ["са-ват-ди́", "коп-ку́н", "чек-бин", "май пен рай", "а-рой", "са-бай ди́"][i],
                        subtitle: ["привет", "спасибо", "счёт", "ничего", "вкусно", "как дела"][i]
                    )
                    .frame(minHeight: 118)
                    .frame(maxHeight: .infinity)
                    .offset(
                        x: scatter * CGFloat(i % 2 == 0 ? -40 : 40),
                        y: scatter * CGFloat(14 + (i / 2) * 8)
                    )
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.bottom, 8)
        .frame(maxHeight: .infinity)
    }

    private func heartWireCard(title: String, subtitle: String) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.pink.opacity(0.45), style: StrokeStyle(lineWidth: 1.1, dash: [6, 4]))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.pink.opacity(0.06))
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
                    .padding(12)
                    .scaleEffect(0.9 + 0.1 * scene.slotsDock)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.pink.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(height: 36)
                        .overlay(
                            Text("♥ card")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.pink.opacity(0.55))
                        )
                }
                .padding(12)
                .padding(.trailing, 28)
            }
            .overlay(alignment: .topLeading) { wireHandle.offset(x: -3, y: -3) }
            .overlay(alignment: .bottomLeading) { wireHandle.offset(x: -3, y: 3) }
            .overlay(alignment: .bottomTrailing) { wireHandle.offset(x: 3, y: 3) }
    }

    private func reinforceWireSlots(scatter: CGFloat) -> some View {
        // Real GamePark shape: guide + planet + chips + CTA
        // (page title already typed by draftPage)
        let dock = scene.slotsDock
        return VStack(spacing: 0) {
            Text(dock > 0.5 ? "Выбери режим игры" : "Сначала выучи фразы")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CD.Spacing.screen)
                .opacity(Double(max(scene.titleType, dock * 0.5)))
                .offset(y: -10 * scatter)

            Spacer(minLength: 12)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.cyan.opacity(0.35), style: StrokeStyle(lineWidth: 1.1, dash: [6, 4]))
                    .frame(width: 230, height: 230)
                    .opacity(0.5)

                TaikaVoicePlanet(
                    mode: .idle,
                    kind: .voice,
                    scale: 0.85,
                    centerSymbol: "gamecontroller.fill",
                    lite: true,
                    inviteTap: true,
                    audioLevel: 0.15,
                    palette: .spark,
                    idleAccent: 0.5
                )
                .frame(width: 210, height: 210)
                .environmentObject(theme)
                .scaleEffect(0.75 + 0.25 * dock)
                .opacity(Double(dock))
            }
            .offset(y: (1 - dock) * 36)

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                ForEach(["Найди пару", "Вспомни", "На слух"], id: \.self) { title in
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .background(Capsule().fill(Color.white.opacity(0.05)))
                        )
                }
            }
            .opacity(Double(dock))
            .offset(y: (1 - dock) * 20)

            Spacer(minLength: 14)

            Text("Начать закрепление")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule(style: .continuous).fill(theme.currentAccentFill))
                .padding(.horizontal, CD.Spacing.screen)
                .opacity(Double(dock))
                .offset(y: (1 - dock) * 28)

            Text("голос · отдельный вход из hub")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
                .padding(.top, 10)
                .opacity(Double(dock) * (clock.t >= 46 ? 1 : 0))

            Spacer(minLength: 8)
        }
        .frame(maxHeight: .infinity)
    }

    /// Side plaques — architecture sources (Notion / Figma) while toolbar is born.
    private var architectureSourcePlaques: some View {
        let items: [(String, String, Alignment, CGFloat)] = [
            ("Import · Notion", "IA · tabs map", .topLeading, 0.9),
            ("Sync · Figma", "chrome · ToolBar", .topTrailing, 0.85),
            ("Spec · userflow", "5 tabs · skeleton", .leading, 0.75),
        ]
        return ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.purple.opacity(0.9))
                        .frame(width: 3, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.92))
                        Text(item.1)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.purple.opacity(0.45), lineWidth: 1)
                        )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: item.2)
                .padding(.horizontal, 12)
                .padding(.vertical, CGFloat(100 + i * 52))
                .opacity(Double(item.3) * Double(min(1, scene.toolbarBuild + 0.35)))
                .offset(
                    x: item.2 == .topTrailing ? (1 - scene.toolbarBuild) * 40 : (1 - scene.toolbarBuild) * -40,
                    y: 0
                )
            }
        }
    }

    private func wireCard(title: String, subtitle: String) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.cyan.opacity(0.45), style: StrokeStyle(lineWidth: 1.1, dash: [6, 4]))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.cyan.opacity(0.8))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                    Spacer(minLength: 0)
                    // Fake image zone
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .overlay(
                            Text("img")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.25))
                        )
                }
                .padding(12)
            }
            .overlay(alignment: .topLeading) { wireHandle.offset(x: -3, y: -3) }
            .overlay(alignment: .topTrailing) { wireHandle.offset(x: 3, y: -3) }
            .overlay(alignment: .bottomLeading) { wireHandle.offset(x: -3, y: 3) }
            .overlay(alignment: .bottomTrailing) { wireHandle.offset(x: 3, y: 3) }
    }

    private func wireSlot(_ label: String, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.cyan.opacity(0.45), style: StrokeStyle(lineWidth: 1.1, dash: [6, 4]))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.cyan.opacity(0.75))
                    .padding(10),
                alignment: .topLeading
            )
            .overlay(alignment: .topLeading) { wireHandle.offset(x: -3, y: -3) }
            .overlay(alignment: .topTrailing) { wireHandle.offset(x: 3, y: -3) }
            .overlay(alignment: .bottomLeading) { wireHandle.offset(x: -3, y: 3) }
            .overlay(alignment: .bottomTrailing) { wireHandle.offset(x: 3, y: 3) }
            .frame(maxWidth: .infinity)
            .frame(height: h)
    }

    private func wireChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
    }

    private var wireHandle: some View {
        Circle()
            .fill(Color.cyan)
            .frame(width: 6, height: 6)
    }

    // MARK: Toolbar build → real ToolBar

    private var toolbarZone: some View {
        ZStack {
            if !scene.useRealToolbar {
                draftToolbar
                    .opacity(Double(scene.toolbarBuild))
            } else {
                ToolBar(selectedTab: .constant(scene.selectedTab))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .padding(.bottom, 2)
        .frame(minHeight: 56)
    }

    private var draftToolbar: some View {
        let wFactor = 0.42 + 0.58 * scene.toolbarStretch
        let radius = 8 + 16 * scene.toolbarRadius
        let icons = draftIconSet(scene.iconCycle)

        return HStack(spacing: 0) {
            ForEach(Array(icons.enumerated()), id: \.offset) { idx, name in
                Image(systemName: name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(idx == 2 ? 0.95 : 0.7))
                    .frame(maxWidth: .infinity)
                    .opacity(Double(scene.toolbarIcons))
                    .scaleEffect(0.85 + 0.15 * scene.toolbarIcons)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .scaleEffect(x: wFactor, y: 1, anchor: .center)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                )
        )
        .overlay(alignment: .topLeading) { wireHandle.offset(x: -2, y: -2) }
        .overlay(alignment: .topTrailing) { wireHandle.offset(x: 2, y: -2) }
        .overlay(alignment: .bottomLeading) { wireHandle.offset(x: -2, y: 2) }
        .overlay(alignment: .bottomTrailing) { wireHandle.offset(x: 2, y: 2) }
        .padding(.horizontal, ToolBar.contentHorizontalInset)
        .padding(.bottom, 8)
    }

    private func draftIconSet(_ cycle: Int) -> [String] {
        switch cycle {
        case 0: return ["square", "square", "circle", "square", "square"]
        case 1: return ["house", "book", "mic", "star", "flag"]
        case 2: return ["house", "graduationcap", "waveform", "bookmark", "dice"]
        case 3: return ["house.fill", "graduationcap", "mic", "heart", "gamecontroller"]
        default: return ["house.fill", "graduationcap.fill", "mic.fill", "heart.fill", "gamecontroller.fill"]
        }
    }

    // MARK: Icon picker plaque (чик-чик)

    private var iconPickerPlaque: some View {
        let options: [String] = {
            switch scene.focus {
            case .courses: return ["book.fill", "graduationcap.fill", "rectangle.stack.fill"]
            case .reinforce: return ["gamecontroller.fill", "dice.fill", "flag.checkered"]
            default: return ["circle"]
            }
        }()
        return VStack(alignment: .leading, spacing: 10) {
            Text("ICON PICK")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .tracking(0.8)
            HStack(spacing: 12) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, name in
                    let on = i == scene.iconPickIndex
                    Image(systemName: name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(on ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.45)))
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(on ? 0.12 : 0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.white.opacity(on ? 0.55 : 0.12), lineWidth: on ? 1.5 : 1)
                                )
                        )
                        .scaleEffect(on ? 1.08 : 1)
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

    // MARK: Overlays

    private func boardScatter(in size: CGSize) -> some View {
        let frames: [(String, CGFloat, CGFloat, CGFloat, CGFloat)] = {
            switch scene.focus {
            case .toolbarBuild:
                return [("TOOLBAR", 0.12, 0.82, 0.76, 0.08)]
            case .home:
                return [
                    ("TITLE", 0.08, 0.14, 0.5, 0.06),
                    ("SLOT", 0.08, 0.28, 0.84, 0.12),
                    ("SLOT", 0.08, 0.48, 0.84, 0.22),
                ]
            case .courses:
                return [
                    ("FILTERS", 0.08, 0.16, 0.7, 0.05),
                    ("CARD", 0.08, 0.28, 0.4, 0.32),
                    ("CARD", 0.52, 0.28, 0.4, 0.32),
                ]
            case .speaker:
                return [
                    ("PROMPT", 0.1, 0.18, 0.8, 0.08),
                    ("MIC", 0.28, 0.35, 0.44, 0.28),
                ]
            case .favorites:
                return [
                    ("♥", 0.08, 0.24, 0.4, 0.22),
                    ("♥", 0.52, 0.24, 0.4, 0.22),
                    ("♥", 0.08, 0.50, 0.4, 0.22),
                    ("♥", 0.52, 0.50, 0.4, 0.22),
                ]
            case .reinforce:
                return [
                    ("SPHERE", 0.22, 0.28, 0.56, 0.28),
                    ("CHIPS", 0.10, 0.62, 0.80, 0.06),
                    ("CTA", 0.12, 0.72, 0.76, 0.07),
                ]
            default:
                return [("CANVAS", 0.15, 0.3, 0.7, 0.3)]
            }
        }()
        let u = 1 - scene.boardSnap
        return ZStack {
            ForEach(Array(frames.enumerated()), id: \.offset) { i, f in
                let drift = CGFloat(i % 2 == 0 ? -1 : 1) * 14 * u
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.cyan.opacity(0.04)))
                    .overlay(
                        Text(f.0)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.cyan.opacity(0.9))
                    )
                    .frame(width: size.width * f.3, height: size.height * f.4)
                    .position(
                        x: size.width * (f.1 + f.3 / 2) + drift,
                        y: size.height * (f.2 + f.4 / 2) - drift * 0.3
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
            case .toolbarBuild: return (0.08, 0.80, 0.84, 0.10)
            case .home: return (0.06, 0.14, 0.88, 0.55)
            case .courses: return (0.06, 0.14, 0.88, 0.55)
            case .speaker: return (0.08, 0.16, 0.84, 0.52)
            case .favorites: return (0.06, 0.16, 0.88, 0.52)
            case .reinforce: return (0.06, 0.18, 0.88, 0.50)
            default: return (0.2, 0.3, 0.6, 0.3)
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
            case .toolbarBuild: return "Paste · ToolBar.swift"
            case .home: return "Paste · Main agent grid"
            case .courses: return "Upload · course JSON pack"
            case .speaker: return "Connect · SpeakerManager API"
            case .reinforce: return "Paste · GamePark hub"
            case .favorites: return "Paste · ♥ favorite cards"
            default: return "Paste · page skeleton"
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
        Text("готово · архитектура через тулбар")
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

#endif
