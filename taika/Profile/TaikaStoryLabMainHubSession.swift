#if DEBUG

//
//  TaikaStoryLabMainHubSession.swift
//  taika
//
//  Story Lab — Главная · hub carousel (~58s).
//  Behind-the-scenes: void → chrome → assemble peek-carousel →
//  swipe affordance → Speaker→Learn→Favorites (palette / copy / CTA) →
//  tap activate → settle.
//  Реальная MDMainHubSphere (physics peeks) + hubAtmosphere.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabMainHubClock: ObservableObject {
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

enum StoryLabMainHubFocus: Equatable {
    case void, chrome, assemble, affordance, swipeLearn, swipeFav, swipeHome, activate, settle
}

struct StoryLabMainHubScene: Equatable {
    var grid: CGFloat
    var shell: CGFloat
    var title: CGFloat
    var sphere: CGFloat
    var typewriter: CGFloat
    var chips: CGFloat
    var dock: CGFloat
    var mode: MDMainHubMode
    var swipeTrail: CGFloat
    var modeRail: CGFloat
    var atmosphereFlash: CGFloat
    var grab: CGFloat
    var ready: CGFloat
    var focus: StoryLabMainHubFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var actionChip: String?
    var figmaChip: String?
    var editorTag: String?

    static func at(_ t: TimeInterval) -> StoryLabMainHubScene {
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

        // VO cut (~58s):
        // 0–3.5   void + grid
        // 3.5–9   chrome (title / header / toolbar)
        // 9–17    assemble center + peek neighbors
        // 17–23   swipe affordance (peek reveal / kick)
        // 23–32   swipe → Learn (green world)
        // 32–41   swipe → Favorites (heart)
        // 41–47   swipe → Speaker home
        // 47–52   tap activate
        // 52–58   settle

        let focus: StoryLabMainHubFocus = {
            switch t {
            case ..<3.5: return .void
            case ..<9.0: return .chrome
            case ..<17.0: return .assemble
            case ..<23.0: return .affordance
            case ..<32.0: return .swipeLearn
            case ..<41.0: return .swipeFav
            case ..<47.0: return .swipeHome
            case ..<52.0: return .activate
            default: return .settle
            }
        }()

        let mode: MDMainHubMode = {
            switch t {
            case ..<26.2: return .speaker
            case ..<35.4: return .learn
            case ..<44.0: return .favorites
            default: return .speaker
            }
        }()

        let swipeTrail: CGFloat = {
            if t >= 24.0 && t < 26.4 { return pulse(24.0, 25.2, 26.4) }
            if t >= 33.2 && t < 35.6 { return pulse(33.2, 34.4, 35.6) }
            if t >= 41.8 && t < 44.2 { return pulse(41.8, 43.0, 44.2) }
            return 0
        }()

        let (cx, cy): (CGFloat, CGFloat) = {
            switch focus {
            case .void: return (0.52, 0.42)
            case .chrome:
                if t < 5.5 { return (0.22, 0.12) }
                if t < 7.2 { return (0.72, 0.10) }
                return (0.50, 0.92)
            case .assemble: return (0.50, 0.42)
            case .affordance:
                if t < 19.5 { return (0.22, 0.48) }
                return (0.78, 0.48)
            case .swipeLearn:
                return (lerp(0.62, 0.28, ramp(24.0, 26.0)), 0.44)
            case .swipeFav:
                return (lerp(0.62, 0.28, ramp(33.2, 35.2)), 0.44)
            case .swipeHome:
                return (lerp(0.38, 0.70, ramp(41.8, 43.8)), 0.44)
            case .activate: return (0.50, 0.44)
            case .settle: return (0.72, 0.22)
            }
        }()

        let grab: CGFloat = {
            if focus == .swipeLearn || focus == .swipeFav || focus == .swipeHome {
                return swipeTrail > 0.15 ? 0.85 : 0.2
            }
            if focus == .affordance { return pulse(18.0, 19.5, 22.5) * 0.55 }
            return 0
        }()

        let click = pulse(48.6, 49.0, 50.2)

        let actionChip: String? = {
            switch focus {
            case .void: return "MAIN · hub carousel"
            case .chrome: return "chrome · title + shell"
            case .assemble: return "assemble · one sphere"
            case .affordance: return "affordance · finger swipe"
            case .swipeLearn: return "swipe · Speaker → Learn"
            case .swipeFav: return "swipe · Learn → Favorites"
            case .swipeHome: return "swipe · Favorites → Speaker"
            case .activate: return "tap · open destination"
            case .settle: return "3 modes · one hero"
            }
        }()

        let figmaChip: String? = {
            switch focus {
            case .assemble: return "MDMainHubSphere"
            case .affordance: return "finger · early hint"
            case .swipeLearn: return "palette · course green"
            case .swipeFav: return "palette · heart"
            case .swipeHome: return "hubAtmosphere · pink"
            case .activate: return "onActivate(mode)"
            default: return nil
            }
        }()

        let editorTag: String? = {
            switch focus {
            case .assemble: return "LAYER · hero"
            case .affordance: return "HINT · swipe"
            case .swipeLearn, .swipeFav, .swipeHome: return "MODE · morph"
            case .activate: return "GESTURE · tap"
            case .settle: return "READY"
            default: return nil
            }
        }()

        return StoryLabMainHubScene(
            grid: ramp(0.2, 1.4) * (1 - ramp(16.5, 18.5)),
            shell: ramp(3.6, 5.0),
            title: ramp(4.0, 5.4),
            sphere: ramp(9.2, 11.5),
            typewriter: ramp(12.0, 14.0),
            chips: ramp(14.2, 16.0),
            dock: ramp(15.0, 17.0),
            mode: mode,
            swipeTrail: swipeTrail,
            modeRail: ramp(17.5, 19.0) * (1 - ramp(54.5, 57.0)),
            atmosphereFlash: pulse(26.0, 26.8, 28.5)
                + pulse(35.2, 36.0, 37.8)
                + pulse(43.8, 44.6, 46.2),
            grab: grab,
            ready: ramp(53.0, 54.5),
            focus: focus,
            cursorX: cx,
            cursorY: cy,
            click: click,
            actionChip: actionChip,
            figmaChip: figmaChip,
            editorTag: editorTag
        )
    }
}

// MARK: - Session

struct StoryLabEditorMainHubSession: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var clock = StoryLabMainHubClock()
    @StateObject private var assemble = TaikaAssembleCoordinator()
    @State private var showControls = false
    @State private var hubMode: MDMainHubMode = .speaker
    @State private var tab = 0
    @State private var sphereKey = UUID()
    @State private var kicked = false

    private var scene: StoryLabMainHubScene { .at(clock.t) }

    var body: some View {
        GeometryReader { geo in
            rootStack(in: geo.size)
                .animation(.easeOut(duration: 0.22), value: hubMode)
                .animation(.easeOut(duration: 0.18), value: scene.focus)
        }
        .environmentObject(assemble)
        .statusBarHidden(false)
        .navigationBarHidden(true)
        .onAppear {
            clock.start()
            syncAtmosphere(hubMode)
        }
        .onDisappear {
            clock.stop()
            ThemeManager.shared.hubAtmosphere = nil
        }
        .onChange(of: scene.mode) { _, newMode in
            guard hubMode != newMode else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                hubMode = newMode
            }
            syncAtmosphere(newMode)
        }
        .onChange(of: scene.sphere) { _, v in
            if v > 0.12, !kicked {
                kicked = true
                sphereKey = UUID()
            }
            if v < 0.02 { kicked = false }
        }
        .onTapGesture(count: 2) {
            withAnimation(.easeOut(duration: 0.2)) { showControls.toggle() }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 50)
                .onEnded { v in if v.translation.height > 100 { closeSession() } }
        )
    }

    private func rootStack(in size: CGSize) -> some View {
        ZStack {
            backdrop
            shellColumn
            gridOverlay
                .opacity(scene.grid)
                .allowsHitTesting(false)
            editorOverlays(in: size)
            closeButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 14)
                .padding(.top, 54)
                .zIndex(20)
            if showControls { controlsOverlay }
        }
    }

    private var backdrop: some View {
        TaikaTechnoSpaceBackdrop(intensity: 0.48, heroAnchor: UnitPoint(x: 0.5, y: 0.38))
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.34), value: hubMode)
    }

    private var shellColumn: some View {
        VStack(spacing: 0) {
            header
                .opacity(scene.shell)
                .offset(y: (1 - scene.shell) * -12)

            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ToolBar(selectedTab: $tab)
                .opacity(scene.shell)
                .offset(y: (1 - scene.shell) * 16)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func editorOverlays(in size: CGSize) -> some View {
        if scene.swipeTrail > 0.05 {
            swipeTrailLayer(in: size)
                .opacity(Double(scene.swipeTrail))
                .allowsHitTesting(false)
        }
        if scene.modeRail > 0.05 {
            modeRailHUD
                .opacity(scene.modeRail)
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
        cursorLayer(in: size).allowsHitTesting(false)
    }

    private func closeSession() {
        clock.stop()
        ThemeManager.shared.hubAtmosphere = nil
        dismiss()
    }

    private func syncAtmosphere(_ mode: MDMainHubMode) {
        let atmosphere: ThemeManager.HubAtmosphere
        switch mode {
        case .speaker: atmosphere = .speaker
        case .learn: atmosphere = .learn
        case .favorites: atmosphere = .favorites
        }
        withAnimation(.easeInOut(duration: 0.34)) {
            ThemeManager.shared.hubAtmosphere = atmosphere
        }
    }

    // MARK: Chrome

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
                    .font(CD.FontToken.title(28, weight: .bold))
                    .foregroundStyle(CD.ColorToken.text)
                    .opacity(scene.title)
                    .scaleEffect(x: 0.94 + 0.06 * scene.title, y: 1, anchor: .leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.top, 6)

            hubStage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 8)
    }

    // MARK: Hub (real pieces)

    private var hubStage: some View {
        VStack(spacing: 12) {
            typewriterSlot
            sphereSlot
            if scene.chips > 0.05 {
                chipZone
                    .id("chips-\(hubMode.rawValue)")
                    .opacity(scene.chips)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            Spacer(minLength: 4)
            if scene.dock > 0.05 {
                dockSlot
            }
        }
        .padding(.top, 2)
    }

    private var typewriterSlot: some View {
        ZStack {
            Color.clear.frame(minHeight: 56)
            if scene.typewriter > 0.05 {
                MDCyclingTypewriter(
                    lines: heroLines(for: hubMode),
                    font: .system(size: 22, weight: .bold),
                    holdSeconds: 2.2,
                    minHeight: 56,
                    isCentered: true
                )
                .id(hubMode)
                .opacity(scene.typewriter)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var sphereSlot: some View {
        ZStack {
            if scene.sphere > 0.05 {
                MDMainHubSphere(mode: $hubMode) { _ in }
                    .id(sphereKey)
                    .opacity(scene.sphere)
                    .scaleEffect(0.82 + 0.18 * scene.sphere)
                    .allowsHitTesting(false)
            } else {
                Color.clear.frame(height: 268)
            }

            if scene.focus == .affordance, scene.grab > 0.1 {
                Text("peek · swipe")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .offset(y: 128)
                    .opacity(Double(scene.grab))
            }
        }
        .frame(height: 268)
    }

    private var dockSlot: some View {
        VStack(spacing: 2) {
            TaikaHubAgentSwitchCTA(
                title: primaryTitle(for: hubMode),
                icon: primaryIcon(for: hubMode),
                action: {}
            )
            TaikaHubGhostCTA(
                icon: ghostIcon(for: hubMode),
                title: ghostTitle(for: hubMode),
                action: {}
            )
        }
        .id("dock-\(hubMode.rawValue)")
        .opacity(scene.dock)
        .padding(.horizontal, Theme.Layout.pageHorizontal)
        .padding(.bottom, ToolBar.recommendedBottomInset + 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    @ViewBuilder
    private var chipZone: some View {
        switch hubMode {
        case .speaker:
            HStack(spacing: 8) {
                ForEach(["Можно счёт", "Где туалет?", "Без острого"], id: \.self) { title in
                    TaikaNeutralChip(title: title, action: {})
                }
            }
        case .learn:
            HStack(spacing: 8) {
                ForEach(["База", "Еда", "Улица"], id: \.self) { title in
                    TaikaNeutralChip(title: title, action: {})
                }
            }
        case .favorites:
            HStack(spacing: 8) {
                ForEach(["Мои фразы", "Недавние", "Словарь"], id: \.self) { title in
                    TaikaNeutralChip(title: title, action: {})
                }
            }
        }
    }

    private func heroLines(for mode: MDMainHubMode) -> [String] {
        switch mode {
        case .speaker:
            return [
                "Добрый день 👋",
                "Свайпни сферу — или скажи фразу",
                "Тап по сфере — умный спикер"
            ]
        case .learn:
            return [
                "Добрый день 👋",
                "Тап по сфере — к курсам",
                "Или продолжи «База»"
            ]
        case .favorites:
            return [
                "Добрый день 👋",
                "Твои фразы — всегда под рукой",
                "Тап по сфере — открыть избранное"
            ]
        }
    }

    private func primaryTitle(for mode: MDMainHubMode) -> String {
        switch mode {
        case .speaker, .learn: return "Продолжить · База"
        case .favorites: return "Открыть избранное"
        }
    }

    private func primaryIcon(for mode: MDMainHubMode) -> String {
        switch mode {
        case .speaker, .learn: return "graduationcap.fill"
        case .favorites: return "heart.fill"
        }
    }

    private func ghostTitle(for mode: MDMainHubMode) -> String {
        switch mode {
        case .speaker, .learn: return "Разминка"
        case .favorites: return "Словарь"
        }
    }

    private func ghostIcon(for mode: MDMainHubMode) -> String {
        switch mode {
        case .speaker, .learn: return "bolt.fill"
        case .favorites: return "bookmark.fill"
        }
    }

    // MARK: Editor overlays

    private var modeRailHUD: some View {
        HStack(spacing: 6) {
            ForEach(MDMainHubMode.allCases) { m in
                modeRailPill(m)
            }
        }
        .padding(8)
        .background(modeRailChrome)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 108)
    }

    private func modeRailPill(_ m: MDMainHubMode) -> some View {
        let on = m == hubMode
        let fg = on ? Color.white : Color.white.opacity(0.45)
        let fill = on ? m.accent.opacity(0.55) : Color.white.opacity(0.06)
        let stroke = m.accent.opacity(on ? 0.9 : 0.25)
        return HStack(spacing: 4) {
            Image(systemName: m.symbol)
                .font(.system(size: 10, weight: .bold))
            Text(m.caption.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(fill)
                .overlay(Capsule().stroke(stroke, lineWidth: 1))
        )
    }

    private var modeRailChrome: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.black.opacity(0.62))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    private func swipeTrailLayer(in size: CGSize) -> some View {
        let home = scene.focus == .swipeHome
        let y = size.height * 0.44
        let fromX = size.width * (home ? 0.34 : 0.64)
        let toX = size.width * (home ? 0.66 : 0.30)
        let u = min(1, max(0, (Double(scene.swipeTrail) - 0.15) / 0.7))
        let x = fromX + (toX - fromX) * CGFloat(u)
        let accent = hubMode.accent
        return ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.0),
                            accent.opacity(0.45),
                            accent.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: abs(toX - fromX) * 0.85, height: 3)
                .position(x: (fromX + toX) / 2, y: y)
                .blur(radius: 0.5)

            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 10, height: 10)
                .shadow(color: accent.opacity(0.8), radius: 8)
                .position(x: x, y: y)
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
        Text("готово · hub carousel")
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
        .accessibilityLabel("Закрыть Story Lab")
    }

    private var controlsOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                Slider(value: Binding(get: { clock.t }, set: { clock.scrub($0) }), in: 0...clock.duration)
                HStack {
                    Button(clock.isPlaying ? "Pause" : "Play") { clock.toggle() }
                    Button("Restart") {
                        kicked = false
                        hubMode = .speaker
                        sphereKey = UUID()
                        clock.restart()
                    }
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
