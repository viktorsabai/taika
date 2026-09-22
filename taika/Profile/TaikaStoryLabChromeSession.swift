#if DEBUG

//
//  TaikaStoryLabChromeSession.swift
//  taika
//
//  Story Lab — header + toolbar chrome (~28s).
//  Black void → zones → taikAAA type/accent → toolbar icons/radius/blur → sphere settle.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabChromeClock: ObservableObject {
    @Published var t: TimeInterval = 0
    @Published var isPlaying = true
    let duration: TimeInterval = 28
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

enum StoryLabChromeFocus: Equatable {
    case none, void, zones, headerType, toolbarChrome, settle
}

struct StoryLabChromeScene: Equatable {
    var grid: CGFloat
    var zoneTop: CGFloat
    var zoneBottom: CGFloat
    var header: CGFloat
    var wordmarkSize: CGFloat
    var wordmarkWeight: Font.Weight
    var useOnmark: Bool
    var accentVariant: Int // 0 muted, 1 pink, 2 theme, 3 lilac
    var toolbar: CGFloat
    var toolbarIconSet: Int // 0 outline+labels, 1 fat filled, 2 prod outline/fill mix
    var toolbarRadius: CGFloat
    var toolbarBlur: CGFloat // 0 solid … 1 frosted
    var toolbarFill: CGFloat
    var toolbarSelected: Int
    var sphere: CGFloat
    var inspector: CGFloat
    var focus: StoryLabChromeFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var selecting: Bool

    static func at(_ t: TimeInterval) -> StoryLabChromeScene {
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

        // VO cut (~28s):
        // 0–5   black void (+ brief zones ~4–6)
        // 5–10  header · taikAAA type / accent stroke
        // 10–18 toolbar · icons / radius / blur
        // 18–28 settle · sphere center + icon cycle

        let focus: StoryLabChromeFocus = {
            switch t {
            case ..<4.2: return .void
            case ..<5.2: return .zones
            case ..<10.0: return .headerType
            case ..<18.0: return .toolbarChrome
            default: return .settle
            }
        }()

        // Header type variants
        let accentVariant: Int = {
            if t < 6.2 { return 0 }
            if t < 7.4 { return 1 }
            if t < 8.6 { return 3 }
            return 2
        }()

        let useOnmark = t >= 7.0
        let wordmarkWeight: Font.Weight = t < 6.8 ? .regular : (t < 8.2 ? .medium : .bold)
        let wordmarkSize: CGFloat = {
            if t < 6.5 { return 22 }
            if t < 7.8 { return 28 }
            if t < 9.0 { return 24 }
            return 26
        }()

        // Toolbar variants
        let toolbarIconSet: Int = {
            if t < 12.2 { return 0 }
            if t < 14.8 { return 1 }
            return 2
        }()

        let toolbarRadius: CGFloat = {
            if t < 13.0 { return 10 }
            if t < 15.0 { return 18 }
            if t < 16.5 { return 28 }
            return 22
        }()

        let toolbarBlur: CGFloat = {
            if t < 14.0 { return 0.15 }
            if t < 16.0 { return 0.85 }
            return 0.55
        }()

        let toolbarFill: CGFloat = {
            if t < 14.0 { return 0.14 }
            if t < 16.0 { return 0.08 }
            return 0.11
        }()

        let toolbarSelected: Int = {
            if t < 18.5 { return 0 }
            if t < 20.0 { return 1 }
            if t < 21.5 { return 2 }
            if t < 23.0 { return 3 }
            if t < 24.5 { return 4 }
            return 0
        }()

        let header = ramp(5.0, 5.9)
        let toolbar = ramp(10.0, 11.0)
        let sphere = ramp(18.0, 19.4)

        let (cx, cy): (CGFloat, CGFloat) = {
            switch focus {
            case .void: return (0.50, 0.48)
            case .zones: return (0.50, 0.16)
            case .headerType: return (0.32, 0.11)
            case .toolbarChrome: return (0.52, 0.88)
            case .settle, .none: return (0.50, 0.48)
            }
        }()

        let prev = cursorAnchor(before: t)
        let move = min(1, max(0, (t - focusStart(focus)) / 0.45))
        let cursorX = lerp(prev.x, cx, move)
        let cursorY = lerp(prev.y, cy, move)

        let clickTimes: [TimeInterval] = [
            4.4, 5.15,
            6.0, 7.1, 8.3, 9.2,
            10.4, 12.0, 13.5, 15.2, 16.8,
            18.6, 20.0, 21.4, 22.8, 24.2
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.14 { return CGFloat(1 - d / 0.14) }
            }
            return 0
        }()

        let inspector = max(
            pulse(5.1, 6.0, 9.8),
            pulse(10.2, 11.2, 17.6)
        )

        return StoryLabChromeScene(
            grid: ramp(4.0, 5.0) * (1 - ramp(24.5, 27.5)),
            zoneTop: ramp(4.2, 5.0) * (1 - ramp(18.5, 21.0)),
            zoneBottom: ramp(4.6, 5.4) * (1 - ramp(18.5, 21.0)),
            header: header,
            wordmarkSize: wordmarkSize,
            wordmarkWeight: wordmarkWeight,
            useOnmark: useOnmark,
            accentVariant: accentVariant,
            toolbar: toolbar,
            toolbarIconSet: toolbarIconSet,
            toolbarRadius: toolbarRadius,
            toolbarBlur: toolbarBlur,
            toolbarFill: toolbarFill,
            toolbarSelected: toolbarSelected,
            sphere: sphere,
            inspector: inspector,
            focus: focus,
            cursorX: cursorX,
            cursorY: cursorY,
            click: click,
            selecting: ![.void, .settle, .none].contains(focus)
        )
    }

    private static func focusStart(_ f: StoryLabChromeFocus) -> TimeInterval {
        switch f {
        case .void: return 0
        case .zones: return 4.2
        case .headerType: return 5.2
        case .toolbarChrome: return 10.0
        case .settle, .none: return 18.0
        }
    }

    private static func cursorAnchor(before t: TimeInterval) -> (x: CGFloat, y: CGFloat) {
        let earlier = max(0, t - 0.5)
        let f: StoryLabChromeFocus = {
            switch earlier {
            case ..<4.2: return .void
            case ..<5.2: return .zones
            case ..<10.0: return .headerType
            case ..<18.0: return .toolbarChrome
            default: return .settle
            }
        }()
        switch f {
        case .void: return (0.50, 0.48)
        case .zones: return (0.50, 0.16)
        case .headerType: return (0.32, 0.11)
        case .toolbarChrome: return (0.52, 0.88)
        case .settle, .none: return (0.50, 0.48)
        }
    }
}

// MARK: - Session

struct StoryLabEditorChromeSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabChromeClock()
    @State private var showControls = false

    private var scene: StoryLabChromeScene { .at(clock.t) }
    private var useProdChrome: Bool { clock.t >= 25.2 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        if scene.zoneTop > 0.02, !useProdChrome {
                            zoneBand(label: "HEADER ZONE", height: 96)
                                .opacity(scene.zoneTop * (scene.header > 0.55 ? 0.28 : 1))
                        }

                        Group {
                            if useProdChrome {
                                prodHeader
                            } else if scene.header > 0.05 {
                                draftHeader
                                    .opacity(scene.header)
                                    .overlay {
                                        if scene.selecting, scene.focus == .headerType {
                                            selectionFrame
                                        }
                                    }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)

                    // Center sphere (settle beat)
                    if scene.sphere > 0.02 {
                        centerSphere
                            .opacity(scene.sphere)
                            .scaleEffect(0.88 + 0.12 * scene.sphere)
                            .allowsHitTesting(false)
                    }

                    Spacer(minLength: 0)

                    ZStack(alignment: .bottom) {
                        if scene.zoneBottom > 0.02, !useProdChrome {
                            zoneBand(label: "TOOLBAR ZONE", height: 88)
                                .opacity(scene.zoneBottom * (scene.toolbar > 0.55 ? 0.28 : 1))
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }

                        Group {
                            if useProdChrome {
                                ToolBar(selectedTab: .constant(scene.toolbarSelected))
                                    .allowsHitTesting(false)
                            } else if scene.toolbar > 0.05 {
                                draftToolbar
                                    .opacity(scene.toolbar)
                                    .overlay {
                                        if scene.selecting, scene.focus == .toolbarChrome {
                                            selectionFrame.padding(.horizontal, 20)
                                        }
                                    }
                                    .padding(.bottom, 10)
                            }
                        }
                    }
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                }

                gridOverlay.opacity(scene.grid).allowsHitTesting(false)

                inspectorPanel
                    .opacity(scene.inspector)
                    .offset(x: (1 - scene.inspector) * 40)
                    .allowsHitTesting(false)

                cursorLayer(in: geo.size).allowsHitTesting(false)

                closeButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 14)
                    .padding(.top, 54)
                    .zIndex(20)

                if showControls { controlsOverlay }
            }
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

    private func zoneBand(label: String, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.cyan.opacity(0.75))
                Spacer()
            }
            .padding(.horizontal, 16)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.cyan.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.cyan.opacity(0.05))
                )
                .frame(height: height - 28)
                .padding(.horizontal, 12)
        }
        .frame(height: height)
    }

    private var selectionFrame: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color.cyan.opacity(0.65), lineWidth: 1.2)
            .overlay(alignment: .topLeading) { handle.offset(x: -2, y: -2) }
            .overlay(alignment: .topTrailing) { handle.offset(x: 2, y: -2) }
            .overlay(alignment: .bottomLeading) { handle.offset(x: -2, y: 2) }
            .overlay(alignment: .bottomTrailing) { handle.offset(x: 2, y: 2) }
            .padding(.horizontal, 8)
    }

    private var handle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 7, height: 7)
            .overlay(Circle().stroke(Color.cyan.opacity(0.9), lineWidth: 1))
    }

    // MARK: Center sphere

    private var centerSphere: some View {
        let items = toolbarItems
        let idx = min(max(0, scene.toolbarSelected), max(0, items.count - 1))
        let symbol = items.isEmpty ? "house.fill" : items[idx].icon

        return TaikaVoicePlanet(
            mode: .idle,
            kind: .voice,
            scale: 0.78,
            centerSymbol: symbol,
            lite: true,
            inviteTap: false,
            palette: .theme,
            idleAccent: 0.35
        )
        .frame(width: 210, height: 210)
        .environmentObject(theme)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: scene.toolbarSelected)
    }

    // MARK: Header

    private var prodHeader: some View {
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
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private var accentStroke: AnyShapeStyle {
        switch scene.accentVariant {
        case 0:
            return AnyShapeStyle(Color.white.opacity(0.55))
        case 1:
            return AnyShapeStyle(Color.pink)
        case 3:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.pink.opacity(0.85), Color.purple.opacity(0.75)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        default:
            return AnyShapeStyle(theme.currentAccentFill)
        }
    }

    private var draftHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                Text("tai")
                    .font(wordmarkFont)
                    .foregroundStyle(Color.white)
                Text("kAAA")
                    .font(wordmarkFont)
                    .foregroundStyle(accentStroke)
            }
            .animation(.easeOut(duration: 0.22), value: scene.wordmarkSize)
            .animation(.easeOut(duration: 0.22), value: scene.useOnmark)
            .animation(.easeOut(duration: 0.22), value: scene.accentVariant)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
    }

    private var wordmarkFont: Font {
        if scene.useOnmark {
            return .custom("Onmark Trial", size: scene.wordmarkSize)
        }
        return .system(size: scene.wordmarkSize, weight: scene.wordmarkWeight, design: .rounded)
    }

    // MARK: Toolbar

    private var draftToolbar: some View {
        HStack(spacing: 0) {
            ForEach(Array(toolbarItems.enumerated()), id: \.offset) { index, item in
                Button {} label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(
                                size: scene.toolbarIconSet == 1 ? 22 : 17,
                                weight: index == scene.toolbarSelected
                                    ? .semibold
                                    : (scene.toolbarIconSet == 0 ? .regular : .medium)
                            ))
                        if scene.toolbarIconSet == 0 {
                            Text(item.label)
                                .font(.system(size: 9, weight: .medium))
                        } else {
                            Circle()
                                .fill(Color.white.opacity(index == scene.toolbarSelected ? 0.9 : 0))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .foregroundStyle(Color.white.opacity(index == scene.toolbarSelected ? 0.95 : 0.38))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            let shape = RoundedRectangle(cornerRadius: scene.toolbarRadius, style: .continuous)
            ZStack {
                if scene.toolbarBlur > 0.35 {
                    shape.fill(.ultraThinMaterial)
                }
                shape.fill(Color.white.opacity(scene.toolbarFill))
                shape.stroke(Color.white.opacity(0.16 + 0.1 * scene.toolbarBlur), lineWidth: 1)
            }
        }
        .padding(.horizontal, 28)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: scene.toolbarRadius)
        .animation(.easeOut(duration: 0.25), value: scene.toolbarIconSet)
        .animation(.easeOut(duration: 0.2), value: scene.toolbarSelected)
        .animation(.easeOut(duration: 0.25), value: scene.toolbarBlur)
    }

    private var toolbarItems: [(icon: String, label: String)] {
        switch scene.toolbarIconSet {
        case 0:
            return [
                ("house", "Home"),
                ("book", "Learn"),
                ("mic", "Speak"),
                ("star", "Saved"),
                ("gamecontroller", "Play")
            ]
        case 1:
            return [
                ("house.fill", ""),
                ("graduationcap.fill", ""),
                ("mic.circle.fill", ""),
                ("heart.circle.fill", ""),
                ("gamecontroller.fill", "")
            ]
        default:
            return [
                ("house.fill", ""),
                ("graduationcap.fill", ""),
                ("mic.fill", ""),
                ("heart.fill", ""),
                ("gamecontroller.fill", "")
            ]
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
            ctx.stroke(path, with: .color(.white.opacity(0.045)), lineWidth: 0.6)
        }
        .ignoresSafeArea()
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(inspectorTitle)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(0.6)

            if scene.focus == .headerType {
                Text("WORDMARK")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                Text(scene.useOnmark ? "Onmark · taikAAA" : "System · taikAAA")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))

                Text("ACCENT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.top, 4)
                Text(accentLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))

                Text("SIZE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.top, 4)
                Text("\(Int(scene.wordmarkSize)) pt")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.85))
            }

            if scene.focus == .toolbarChrome {
                Text("ICONS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                Text(toolbarIconLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))

                Text("RADIUS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.top, 4)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                    let u = (scene.toolbarRadius - 10) / 18
                    Capsule()
                        .fill(Color.cyan.opacity(0.75))
                        .frame(width: 110 * min(1, max(0, u)), height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                        .offset(x: max(0, 110 * min(1, max(0, u)) - 5))
                }
                .frame(width: 110)
                Text("\(Int(scene.toolbarRadius)) pt · blur \(Int(scene.toolbarBlur * 100))%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            if scene.focus == .zones {
                Text("TOP · header")
                    .font(.system(size: 12, weight: .semibold))
                Text("BOTTOM · toolbar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
        .padding(12)
        .frame(width: 156, alignment: .leading)
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
        .padding(.top, 130)
    }

    private var inspectorTitle: String {
        switch scene.focus {
        case .zones: return "LAYOUT"
        case .headerType: return "HEADER"
        case .toolbarChrome: return "TOOLBAR"
        default: return "CHROME"
        }
    }

    private var accentLabel: String {
        switch scene.accentVariant {
        case 0: return "Muted white"
        case 1: return "Pink stroke"
        case 3: return "Pink → lilac"
        default: return "Theme accent"
        }
    }

    private var toolbarIconLabel: String {
        switch scene.toolbarIconSet {
        case 0: return "Outline + labels"
        case 1: return "Fat filled"
        default: return "Prod weight"
        }
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
        .animation(.easeOut(duration: 0.2), value: scene.cursorX)
        .animation(.easeOut(duration: 0.2), value: scene.cursorY)
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

            HStack(spacing: 14) {
                Button { clock.restart() } label: {
                    Image(systemName: "backward.end.fill")
                        .foregroundStyle(.white.opacity(0.85))
                }
                Button { clock.toggle() } label: {
                    Image(systemName: clock.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(.white.opacity(0.9))
                }
                Slider(
                    value: Binding(get: { clock.t }, set: { clock.scrub($0) }),
                    in: 0...clock.duration
                )
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.55)))
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }
}



#endif
