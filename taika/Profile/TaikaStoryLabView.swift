#if DEBUG

//
//  TaikaStoryLabView.swift
//  taika
//
//  Debug Story Lab — live *editor* session for blog recording.
//  Grid → draw/stretch clutter → select-all cut → clean hub assemble.
//

import SwiftUI

// MARK: - Entry

struct TaikaStoryLabView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        StoryLabEditorMainHubSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.hexagongrid.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Главная · hub carousel")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("одна сфера → cyber peeks → swipe → atmosphere · ~58с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorBrandSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Айдентика · foundation")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("хаос → DNA → glass shell → сфера-характер → AppDS · ~60с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorArchitectureSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "point.3.connected.trianglepath.dotted")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Архитектура · тулбар")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("айдентика → ToolBar → вкладки · сфера hub · ~54с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorPMSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Процесс · PM / Jira")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("Goals → Board → Timeline → Plan · behind-the-scenes · ~56с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorCourseSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Курсы · editor")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("фильтры → разные reel → paint waves · ~68с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorLessonsSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Уроки · editor")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("карточка → steps play → зачётка · ~68с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorReinforceSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Закрепление · editor")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("hub → 3 игры → chrome/stats · ~68с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorSpeakerTrainingSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.wave.2.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Спикер · закрепление")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("picker → palette чик → mic → разбор · ~58с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorChromeSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.topthird.inset.filled")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Хедер + тулбар · chrome B-roll")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text.opacity(0.7))
                                Text("деталь рамки · не ликбез")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorSpeakerSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Спикер · умный · editor")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("Голос/Текст → grab UI → РАЗБОР → тренировка · ~64с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)

                    NavigationLink {
                        StoryLabEditorFavoritesSession()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Избранное + словарь · editor")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text("карточки → grid → unlike → drawer · ~60с")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(PD.ColorToken.background)
                } footer: {
                    Text("Двойной тап — контролы записи. Голос снаружи.")
                        .font(.caption)
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(PD.ColorToken.background)
            .navigationTitle("Story Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Clock

@MainActor
final class StoryLabEditorClock: ObservableObject {
    @Published var t: TimeInterval = 0
    @Published var isPlaying = true
    /// Longer for clutter voiceover + clean assemble.
    let duration: TimeInterval = 72
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

// MARK: - Focus / CTA

enum StoryLabFocus: Equatable {
    case none, grid, title, draftCTA, clutter, selectAll, cut, sphere, typewriter, chips, dock, ghost
}

enum StoryLabCTAStyle: Equatable {
    case rectPink, roundPink, capsulePink, capsuleGlass
}

enum StoryLabClutterKind: String, CaseIterable, Identifiable {
    case stats, progress, achievements, courses, premium, toast, spinner
    var id: String { rawValue }
}

struct StoryLabClutterItem: Equatable, Identifiable {
    var id: String { kind.rawValue }
    var kind: StoryLabClutterKind
    /// 0…1 draw/resize progress for this block.
    var draw: CGFloat
    var visible: Bool
    var selected: Bool
}

struct StoryLabEditorScene: Equatable {
    var grid: CGFloat
    var shell: CGFloat
    var title: CGFloat
    var titleWeightBold: Bool
    var draftCTA: CGFloat
    var ctaStyle: StoryLabCTAStyle
    var clutter: [StoryLabClutterItem]
    var clutterLayer: CGFloat
    var marquee: CGFloat
    var cutFlash: CGFloat
    var sphere: CGFloat
    var typewriter: CGFloat
    var typeSize: CGFloat
    var chips: CGFloat
    var chipCount: Int
    var dock: CGFloat
    var ghost: CGFloat
    var inspector: CGFloat
    var focus: StoryLabFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var selecting: Bool
    var resizeDrag: CGFloat

    static func at(_ t: TimeInterval) -> StoryLabEditorScene {
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
        func drawWindow(start: TimeInterval, stretchEnd: TimeInterval) -> CGFloat {
            // Appear small then stretch to full.
            if t < start { return 0 }
            if t < stretchEnd { return ramp(start, stretchEnd) }
            return 1
        }

        // Timeline (~72s) synced to clutter voiceover:
        // 0–3    grid + shell
        // 3–7    title
        // 7–12   quick CTA shape play
        // 12–33  BUILD clutter dashboard (draw + stretch each junk block)
        // 33–37  select-all marquee
        // 37–41  cut / wipe
        // 41–72  clean hub assemble

        let ctaStyle: StoryLabCTAStyle = {
            if t < 8.5 { return .rectPink }
            if t < 9.8 { return .roundPink }
            if t < 11.2 { return .capsulePink }
            return .capsuleGlass
        }()

        let clutterCut = t >= 38.2
        let clutterSpecs: [(StoryLabClutterKind, TimeInterval, TimeInterval)] = [
            (.stats, 12.4, 14.2),
            (.progress, 14.6, 16.6),
            (.achievements, 17.0, 19.2),
            (.courses, 19.6, 22.4),
            (.premium, 22.8, 25.2),
            (.toast, 25.6, 27.6),
            (.spinner, 28.0, 30.4)
        ]

        let clutter: [StoryLabClutterItem] = clutterSpecs.map { kind, start, stretchEnd in
            let d = clutterCut ? 0 : drawWindow(start: start, stretchEnd: stretchEnd)
            let selected = t >= 33.4 && t < 38.2 && d > 0.05
            return StoryLabClutterItem(
                kind: kind,
                draw: d,
                visible: d > 0.02 && !clutterCut,
                selected: selected
            )
        }

        let clutterLayer: CGFloat = {
            if clutterCut { return 0 }
            return ramp(12.2, 13.0) * (1 - ramp(37.6, 38.6))
        }()

        let marquee = pulse(33.2, 34.0, 37.8)
        let cutFlash = pulse(37.9, 38.3, 39.4)

        let chipCount: Int = {
            if t < 56.0 { return 0 }
            if t < 57.4 { return 1 }
            if t < 58.8 { return 2 }
            return 3
        }()

        let focus: StoryLabFocus = {
            switch t {
            case ..<2.4: return .grid
            case ..<6.8: return .title
            case ..<12.0: return .draftCTA
            case ..<33.2: return .clutter
            case ..<37.8: return .selectAll
            case ..<41.0: return .cut
            case ..<48.5: return .sphere
            case ..<55.5: return .typewriter
            case ..<61.0: return .chips
            case ..<66.0: return .dock
            case ..<69.5: return .ghost
            default: return .none
            }
        }()

        let (cx, cy): (CGFloat, CGFloat) = {
            switch focus {
            case .grid: return (0.50, 0.40)
            case .title: return (0.22, 0.13)
            case .draftCTA: return (0.52, 0.80)
            case .clutter:
                // Walk across blocks as they are drawn.
                if t < 14.5 { return (0.48, 0.28) }
                if t < 17.0 { return (0.55, 0.34) }
                if t < 19.5 { return (0.42, 0.42) }
                if t < 22.5 { return (0.50, 0.52) }
                if t < 25.5 { return (0.50, 0.62) }
                if t < 28.0 { return (0.62, 0.30) }
                return (0.72, 0.48)
            case .selectAll: return (0.18, 0.22)
            case .cut: return (0.78, 0.18)
            case .sphere: return (0.50, 0.42)
            case .typewriter: return (0.50, 0.20)
            case .chips: return (0.58, 0.54)
            case .dock: return (0.50, 0.80)
            case .ghost: return (0.50, 0.88)
            case .none: return (0.70, 0.28)
            }
        }()

        let prev = atCursorAnchor(before: t)
        let move = min(1, max(0, (t - focusStart(focus)) / 0.55))
        let cursorX = lerp(prev.x, cx, move)
        let cursorY = lerp(prev.y, cy, move)

        // Resize drag pulse while stretching a newly placed block.
        let resizeDrag: CGFloat = {
            for (_, start, stretchEnd) in clutterSpecs {
                if t >= start + 0.25, t <= stretchEnd {
                    return ramp(start + 0.25, stretchEnd)
                }
            }
            return 0
        }()

        let clickTimes: [TimeInterval] = [
            3.2, 7.3, 8.6, 9.7, 11.0,
            12.5, 14.8, 17.2, 19.8, 23.0, 25.8, 28.2,
            33.5, 34.2, 38.0,
            42.5, 49.0, 56.2, 57.6, 62.0, 66.5
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.16 { return CGFloat(1 - d / 0.16) }
            }
            return 0
        }()

        let inspector = max(
            pulse(7.2, 8.0, 11.8),
            pulse(13.0, 14.0, 31.5),
            pulse(48.5, 49.5, 54.5),
            pulse(61.5, 62.5, 67.0)
        )

        let draftCTA: CGFloat = {
            if t >= 12.0 { return 0 }
            return ramp(7.4, 8.3)
        }()

        return StoryLabEditorScene(
            grid: ramp(0.25, 1.6) * (1 - ramp(68.5, 71.5)),
            shell: ramp(1.0, 2.4),
            title: ramp(3.3, 4.5),
            titleWeightBold: t >= 5.0,
            draftCTA: draftCTA,
            ctaStyle: ctaStyle,
            clutter: clutter,
            clutterLayer: clutterLayer,
            marquee: marquee,
            cutFlash: cutFlash,
            sphere: ramp(41.8, 45.5),
            typewriter: ramp(48.8, 51.2),
            typeSize: t < 52.5 ? 18 : (t < 54.0 ? 22 : 20),
            chips: ramp(55.8, 56.6),
            chipCount: chipCount,
            dock: ramp(61.8, 63.8),
            ghost: ramp(65.5, 67.4),
            inspector: inspector,
            focus: focus,
            cursorX: cursorX,
            cursorY: cursorY,
            click: click,
            selecting: ![.none, .grid, .cut].contains(focus) && t < 69,
            resizeDrag: resizeDrag
        )
    }

    private static func focusStart(_ f: StoryLabFocus) -> TimeInterval {
        switch f {
        case .grid: return 0
        case .title: return 2.4
        case .draftCTA: return 6.8
        case .clutter: return 12.0
        case .selectAll: return 33.2
        case .cut: return 37.8
        case .sphere: return 41.0
        case .typewriter: return 48.5
        case .chips: return 55.5
        case .dock: return 61.0
        case .ghost: return 66.0
        case .none: return 69.5
        }
    }

    private static func atCursorAnchor(before t: TimeInterval) -> (x: CGFloat, y: CGFloat) {
        let earlier = max(0, t - 0.65)
        let f: StoryLabFocus = {
            switch earlier {
            case ..<2.4: return .grid
            case ..<6.8: return .title
            case ..<12.0: return .draftCTA
            case ..<33.2: return .clutter
            case ..<37.8: return .selectAll
            case ..<41.0: return .cut
            case ..<48.5: return .sphere
            case ..<55.5: return .typewriter
            case ..<61.0: return .chips
            case ..<66.0: return .dock
            case ..<69.5: return .ghost
            default: return .none
            }
        }()
        switch f {
        case .grid: return (0.50, 0.40)
        case .title: return (0.22, 0.13)
        case .draftCTA: return (0.52, 0.80)
        case .clutter: return (0.50, 0.45)
        case .selectAll: return (0.18, 0.22)
        case .cut: return (0.78, 0.18)
        case .sphere: return (0.50, 0.42)
        case .typewriter: return (0.50, 0.20)
        case .chips: return (0.58, 0.54)
        case .dock: return (0.50, 0.80)
        case .ghost: return (0.50, 0.88)
        case .none: return (0.70, 0.28)
        }
    }
}

// MARK: - Session

struct StoryLabEditorMainSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabEditorClock()
    @StateObject private var assemble = TaikaAssembleCoordinator()
    @State private var showControls = false
    @State private var tab = 0
    @State private var sphereKey = UUID()
    @State private var kickedSphere = false

    private var scene: StoryLabEditorScene { .at(clock.t) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PD.ColorToken.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .opacity(scene.shell)
                        .offset(y: (1 - scene.shell) * -10)

                    canvas
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ToolBar(selectedTab: $tab)
                        .opacity(scene.shell)
                        .offset(y: (1 - scene.shell) * 14)
                        .allowsHitTesting(false)
                }

                gridOverlay.opacity(scene.grid).allowsHitTesting(false)

                // Select-all marquee over content
                if scene.marquee > 0.02 {
                    selectAllMarquee
                        .opacity(scene.marquee)
                        .allowsHitTesting(false)
                }

                if scene.cutFlash > 0.02 {
                    Color.white.opacity(0.12 * scene.cutFlash)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                inspectorPanel
                    .opacity(scene.inspector)
                    .offset(x: (1 - scene.inspector) * 40)
                    .allowsHitTesting(false)

                cursorLayer(in: geo.size)
                    .allowsHitTesting(false)

                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 14)
                    .padding(.top, 54)
                    .zIndex(20)

                if showControls { controlsOverlay }
            }
        }
        .environmentObject(assemble)
        .statusBarHidden(false)
        .navigationBarHidden(true)
        .onAppear { clock.start() }
        .onDisappear { clock.stop() }
        .onChange(of: scene.sphere) { _, v in
            if v > 0.08, !kickedSphere {
                kickedSphere = true
                sphereKey = UUID()
            }
            if v < 0.02 { kickedSphere = false }
        }
        .onTapGesture(count: 2) {
            withAnimation(.easeOut(duration: 0.2)) { showControls.toggle() }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.height > 100 { closeSession() }
                }
        )
    }

    private func closeSession() {
        clock.stop()
        dismiss()
    }

    private var closeButton: some View {
        Button(action: closeSession) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.55))
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Закрыть Story Lab")
    }

    private var header: some View {
        AppHeader(
            showSearch: false,
            showHeart: false,
            showProfile: false,
            showPro: true,
            speakerDailyAttemptsRemaining: 0,
            gameParkActive: false,
            favoritesTotalCount: 0,
            favoritesHasCards: false,
            isPro: false,
            style: .main(tab: 0, onBack: nil)
        )
        .environmentObject(theme)
        .padding(.top, 4)
        .allowsHitTesting(false)
    }

    private var canvas: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Главная")
                    .font(CD.FontToken.title(28, weight: scene.titleWeightBold ? .bold : .regular))
                    .foregroundStyle(CD.ColorToken.text)
                    .opacity(scene.title)
                    .scaleEffect(x: 0.92 + 0.08 * scene.title, y: 1, anchor: .leading)
                    .overlay(alignment: .bottomLeading) {
                        if scene.focus == .title, scene.selecting { selectionRect }
                    }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.top, 6)

            ZStack {
                // Junk dashboard — drawn/stretched in editor time
                clutterBoard
                    .opacity(scene.clutterLayer)
                    .allowsHitTesting(false)

                // Clean hub after cut
                hubStack
                    .opacity(scene.clutterLayer > 0.55 ? 0.15 : 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: Clutter board

    private var clutterBoard: some View {
        VStack(spacing: 10) {
            ForEach(scene.clutter) { item in
                if item.visible {
                    clutterBlock(item)
                        .scaleEffect(
                            x: 0.55 + 0.45 * item.draw,
                            y: 0.72 + 0.28 * item.draw,
                            anchor: .topLeading
                        )
                        .opacity(Double(min(1, item.draw * 1.35)))
                        .overlay {
                            if item.selected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.cyan.opacity(0.7), lineWidth: 1.4)
                                    .overlay(alignment: .topLeading) { handle.offset(x: -3, y: -3) }
                                    .overlay(alignment: .topTrailing) { handle.offset(x: 3, y: -3) }
                                    .overlay(alignment: .bottomLeading) { handle.offset(x: -3, y: 3) }
                                    .overlay(alignment: .bottomTrailing) { handle.offset(x: 3, y: 3) }
                            } else if scene.focus == .clutter, item.draw > 0.2, item.draw < 0.98 {
                                // Active resize while drawing
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.cyan.opacity(0.45), lineWidth: 1)
                                    .overlay(alignment: .bottomTrailing) {
                                        handle.offset(x: 4, y: 4)
                                            .scaleEffect(1 + 0.15 * scene.resizeDrag)
                                    }
                            }
                        }
                        .padding(.horizontal, Theme.Layout.pageHorizontal)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.2), value: scene.clutter)
    }

    @ViewBuilder
    private func clutterBlock(_ item: StoryLabClutterItem) -> some View {
        switch item.kind {
        case .stats:
            HStack(spacing: 8) {
                clutterStat("12", "дней")
                clutterStat("48%", "курс")
                clutterStat("🔥 7", "стрик")
                clutterStat("120", "XP")
            }
        case .progress:
            VStack(alignment: .leading, spacing: 8) {
                Text("Прогресс недели")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 10)
                    Capsule()
                        .fill(theme.currentAccentFill)
                        .frame(width: 160 * item.draw, height: 10)
                }
                HStack {
                    Text("Ачивка: Ночной совёнок")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("3/5")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                }
                .foregroundStyle(Color.white.opacity(0.45))
            }
            .padding(12)
            .background(cardChrome)
        case .achievements:
            HStack(spacing: 8) {
                ForEach(["🏆", "⚡️", "🎯", "👑"], id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                        )
                }
            }
        case .courses:
            VStack(spacing: 8) {
                clutterCourse("База", "урок 4 · продолжить")
                clutterCourse("Кафе", "новый · 12 фраз")
                clutterCourse("Такси", "78% · повторить")
            }
        case .premium:
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(theme.currentAccentFill)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Открой Taika Pro")
                        .font(.system(size: 14, weight: .bold))
                    Text("Безлимит спикера и игр")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                Spacer()
                Text("7 дней")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(theme.currentAccentFill))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.currentAccentFill.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.currentAccentFill.opacity(0.45), lineWidth: 1)
                    )
            )
        case .toast:
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                Text("Ежедневная цель почти закрыта!")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.black.opacity(0.65))
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            )
        case .spinner:
            HStack(spacing: 12) {
                ProgressView()
                    .tint(theme.currentAccentFill)
                Text("Синхронизируем ачивки…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer()
                Text("отмена")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .padding(12)
            .background(cardChrome)
        }
    }

    private var cardChrome: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    private func clutterStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold).monospacedDigit())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func clutterCourse(_ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.1))
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.28))
        }
        .padding(10)
        .background(cardChrome)
    }

    private var selectAllMarquee: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.cyan.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.cyan.opacity(0.06))
            )
            .padding(.horizontal, 14)
            .padding(.top, 100)
            .padding(.bottom, 110)
            .overlay(alignment: .topTrailing) {
                Text("Select all · \(scene.clutter.filter(\.visible).count) layers")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.cyan.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.65)))
                    .padding(.trailing, 22)
                    .padding(.top, 108)
            }
            .overlay(alignment: .topTrailing) {
                if scene.focus == .cut || scene.cutFlash > 0.2 {
                    Text("⌘X  Cut")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.red.opacity(0.75)))
                        .padding(.trailing, 22)
                        .padding(.top, 140)
                }
            }
    }

    // MARK: Clean hub

    private var hubStack: some View {
        VStack(spacing: 14) {
            ZStack {
                Color.clear.frame(minHeight: 58)
                if scene.typewriter > 0.05 {
                    MDCyclingTypewriter(
                        lines: [
                            "Привет 👋",
                            "Нажми на сферу — скажи по-русски",
                            "Или продолжи курс"
                        ],
                        font: .system(size: scene.typeSize, weight: .bold),
                        holdSeconds: 2.4,
                        minHeight: 58,
                        isCentered: true
                    )
                    .opacity(scene.typewriter)
                    .overlay {
                        if scene.focus == .typewriter, scene.selecting {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.cyan.opacity(0.55), lineWidth: 1.2)
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }

            ZStack {
                if scene.sphere > 0.05 {
                    TaikaAssemblingPlanet(
                        gateKey: "storylab.editor.\(sphereKey.uuidString)",
                        tier: .soft,
                        kind: .voice,
                        scale: 0.62,
                        inviteTap: true,
                        frameSize: 176
                    )
                    .id(sphereKey)
                    .opacity(scene.sphere)
                    .scaleEffect(0.75 + 0.25 * scene.sphere)
                    .overlay {
                        if scene.focus == .sphere, scene.selecting {
                            Circle()
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 1.2)
                                .frame(width: 188, height: 188)
                        }
                    }
                } else {
                    Color.clear.frame(height: 176)
                }
            }

            if scene.chips > 0.05 {
                HStack(spacing: 8) {
                    ForEach(Array(["Можно счёт", "Где туалет?", "Без острого"].prefix(scene.chipCount)), id: \.self) { title in
                        TaikaNeutralChip(title: title, action: {})
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.36, dampingFraction: 0.82), value: scene.chipCount)
                .opacity(scene.chips)
            }

            Spacer(minLength: 6)

            VStack(spacing: 10) {
                if scene.draftCTA > 0.05 {
                    draftCTAButton
                        .opacity(scene.draftCTA)
                        .overlay {
                            if scene.focus == .draftCTA, scene.selecting {
                                selectionRect.padding(.horizontal, -4)
                            }
                        }
                }

                if scene.dock > 0.05 {
                    MDMainFilledPillCTA(title: "Продолжить · База", action: {})
                        .opacity(scene.dock)
                }

                if scene.ghost > 0.05 {
                    TaikaHubGhostCTA(icon: "bolt.fill", title: "Разминка", action: {})
                        .opacity(scene.ghost)
                }
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.bottom, ToolBar.recommendedBottomInset + 6)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var draftCTAButton: some View {
        let label = Text("Начать обучение")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(scene.ctaStyle == .capsuleGlass ? Color.white.opacity(0.92) : Color.black.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)

        switch scene.ctaStyle {
        case .rectPink:
            label.background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.currentAccentFill)
            )
        case .roundPink:
            label.background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.currentAccentFill)
            )
        case .capsulePink:
            label.background(Capsule().fill(theme.currentAccentFill))
        case .capsuleGlass:
            label.background(TaikaNeutralPrimaryPillChrome())
        }
    }

    private var selectionRect: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color.cyan.opacity(0.65), lineWidth: 1.2)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.cyan.opacity(0.04)))
            .overlay(alignment: .topLeading) { handle }
            .overlay(alignment: .topTrailing) { handle }
            .overlay(alignment: .bottomLeading) { handle }
            .overlay(alignment: .bottomTrailing) { handle }
    }

    private var handle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(Color.cyan.opacity(0.9), lineWidth: 1))
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
            ctx.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 0.6)
            let inset = size.width * 0.06
            var guides = Path()
            guides.move(to: .init(x: inset, y: 0))
            guides.addLine(to: .init(x: inset, y: size.height))
            guides.move(to: .init(x: size.width - inset, y: 0))
            guides.addLine(to: .init(x: size.width - inset, y: size.height))
            ctx.stroke(guides, with: .color(.cyan.opacity(0.18)), lineWidth: 1)
        }
        .ignoresSafeArea()
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(inspectorTitle)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(0.6)

            HStack(spacing: 8) {
                swatch(theme.currentAccentFill, selected: scene.focus == .clutter || scene.ctaStyle != .capsuleGlass)
                swatch(Color.white.opacity(0.18), selected: scene.ctaStyle == .capsuleGlass)
                swatch(Color.white.opacity(0.85), selected: false)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(scene.focus == .clutter ? "DRAW / RESIZE" : "RADIUS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                    Capsule()
                        .fill(Color.cyan.opacity(0.75))
                        .frame(width: max(12, 110 * (scene.focus == .clutter ? max(scene.resizeDrag, 0.2) : radiusNorm)), height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                        .offset(x: max(0, 110 * (scene.focus == .clutter ? max(scene.resizeDrag, 0.2) : radiusNorm) - 5))
                }
                .frame(width: 110)
            }

            if scene.focus == .selectAll || scene.focus == .cut {
                Text(scene.focus == .cut ? "CUT  ·  7 layers" : "SELECT ALL")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
            } else {
                Text(scene.titleWeightBold ? "Bold · 28" : "Regular · 28")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(12)
        .frame(width: 148, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 10)
        .padding(.top, 120)
    }

    private var inspectorTitle: String {
        switch scene.focus {
        case .title: return "TEXT"
        case .draftCTA, .dock: return "BUTTON"
        case .clutter: return "LAYER"
        case .selectAll: return "MULTI"
        case .cut: return "EDIT"
        case .sphere: return "HERO"
        case .typewriter: return "COPY"
        case .chips: return "CHIPS"
        case .ghost: return "GHOST"
        default: return "LAYER"
        }
    }

    private var radiusNorm: CGFloat {
        switch scene.ctaStyle {
        case .rectPink: return 0.25
        case .roundPink: return 0.55
        case .capsulePink, .capsuleGlass: return 1
        }
    }

    private func swatch(_ style: some ShapeStyle, selected: Bool) -> some View {
        Circle()
            .fill(style)
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(Color.white.opacity(selected ? 0.95 : 0.2), lineWidth: selected ? 2 : 1))
            .scaleEffect(selected ? 1.08 : 1)
    }

    private func cursorLayer(in size: CGSize) -> some View {
        let x = scene.cursorX * size.width
        let y = scene.cursorY * size.height
        return ZStack {
            if scene.click > 0.05 {
                Circle()
                    .stroke(Color.white.opacity(0.55 * scene.click), lineWidth: 2)
                    .frame(width: 28 + (1 - scene.click) * 22, height: 28 + (1 - scene.click) * 22)
                    .position(x: x, y: y)
            }
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                .position(x: x + 6, y: y + 8)
        }
        .animation(.easeOut(duration: 0.22), value: scene.cursorX)
        .animation(.easeOut(duration: 0.22), value: scene.cursorY)
    }

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button { closeSession() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(String(format: "%.0f / %.0fs", clock.t, clock.duration))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            HStack(spacing: 16) {
                Button {
                    clock.restart()
                    kickedSphere = false
                    sphereKey = UUID()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                Button { clock.toggle() } label: {
                    Image(systemName: clock.isPlaying ? "pause.fill" : "play.fill")
                }
                Slider(
                    value: Binding(get: { clock.t }, set: { clock.scrub($0) }),
                    in: 0...clock.duration
                )
                .tint(.white.opacity(0.7))
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.55)))
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
    }
}

#endif
