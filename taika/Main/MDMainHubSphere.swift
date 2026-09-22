//
//  MDMainHubSphere.swift
//  taika
//
//  Главная: одна hero-сфера + рабочие стрелки по краям.
//  Physics swipe (инерция + center-snap). Тап по центру — вход.
//

import SwiftUI

/// Режимы hero-сферы на Главной: свайп меняет роль, тап — вход в процесс.
public enum MDMainHubMode: Int, CaseIterable, Identifiable, Equatable {
    case speaker
    case learn
    case favorites

    public var id: Int { rawValue }

    public var symbol: String {
        switch self {
        case .speaker: return "mic.fill"
        case .learn: return "graduationcap.fill"
        case .favorites: return "heart.fill"
        }
    }

    public var palette: TaikaVoicePlanetPalette {
        switch self {
        case .speaker: return .theme
        case .learn: return .course
        case .favorites: return .heart
        }
    }

    public var caption: String {
        switch self {
        case .speaker: return "Спикер"
        case .learn: return "Обучение"
        case .favorites: return "Избранное"
        }
    }

    public var accessibilityHint: String {
        switch self {
        case .speaker: return "Открыть умный спикер"
        case .learn: return "Открыть курсы"
        case .favorites: return "Открыть избранное"
        }
    }

    public var accent: Color {
        switch self {
        case .speaker: return Color(red: 1.0, green: 0.52, blue: 0.85)
        case .learn: return Color(red: 0.28, green: 0.78, blue: 0.52)
        case .favorites: return Color(red: 0.28, green: 0.72, blue: 0.98)
        }
    }

    public func advanced(by delta: Int) -> MDMainHubMode {
        let all = Self.allCases
        let count = all.count
        var idx = (rawValue + delta) % count
        if idx < 0 { idx += count }
        return all[idx]
    }
}

/// Одна сфера + рабочие крайние стрелки; physics drag → snap режима.
public struct MDMainHubSphere: View {
    @Binding var mode: MDMainHubMode
    var onActivate: (MDMainHubMode) -> Void
    var onBootFinished: (() -> Void)? = nil

    @EnvironmentObject private var assembleCoordinator: TaikaAssembleCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var assembleProgress: CGFloat = TaikaCatalogBoot.isReady ? 1 : 0
    @State private var isAssembling = !TaikaCatalogBoot.isReady
    @State private var dragX: CGFloat = 0
    @State private var isDragging = false
    @State private var bootDone = false
    @State private var assembleTask: Task<Void, Never>?
    @State private var invitePulse = false
    @State private var morphPunch: CGFloat = 1
    @State private var swipeLockUntil = Date.distantPast
    @State private var kickDone = false
    @State private var hasSwiped = false
    @State private var idleNudgeTask: Task<Void, Never>?
    @State private var ignoreModeChange = false
    @State private var arrowGlow = false
    @State private var fingerHintX: CGFloat = 0
    @State private var fingerHintVisible = false
    @State private var fingerHintTask: Task<Void, Never>?

    private let planetFrame: CGFloat = 248
    private let stride: CGFloat = 118
    private let arrowRestX: CGFloat = 156

    public init(
        mode: Binding<MDMainHubMode>,
        onActivate: @escaping (MDMainHubMode) -> Void,
        onBootFinished: (() -> Void)? = nil
    ) {
        self._mode = mode
        self.onActivate = onActivate
        self.onBootFinished = onBootFinished
    }

    public var body: some View {
        GeometryReader { geo in
            let midX = geo.size.width * 0.5
            ZStack {
                // Drag/tap only on planet band — arrows remain real buttons outside it.
                ZStack {
                    if fingerHintVisible {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
                            .offset(x: fingerHintX, y: 36)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                            .zIndex(3)
                    }

                    TaikaVoicePlanet(
                        mode: isAssembling ? .assemble : .idle,
                        kind: .voice,
                        scale: 0.86,
                        centerSymbol: mode.symbol,
                        lite: true,
                        inviteTap: !isAssembling && invitePulse,
                        assembleProgress: isAssembling ? assembleProgress : nil,
                        palette: mode.palette,
                        idleAccent: 0.78
                    )
                    .frame(width: planetFrame, height: planetFrame)
                    .offset(x: dragX * 0.42)
                    .rotationEffect(.degrees(Double(dragX) * 0.028))
                    .scaleEffect(morphPunch * (1 - min(0.04, abs(dragX) / 1400)))
                    .opacity(Double(1 - min(0.12, abs(dragX) / 900)))
                    .zIndex(2)
                    .allowsHitTesting(false)
                }
                .frame(width: planetFrame + 48, height: 268)
                .contentShape(Rectangle())
                .highPriorityGesture(hubDrag(midX: midX))
                .zIndex(2)

                swipeArrowButton(side: -1)
                swipeArrowButton(side: 1)
            }
            .frame(width: geo.size.width, height: 268)
        }
        .frame(height: 268)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .onAppear {
            bootAssembleIfNeeded()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                arrowGlow = true
            }
        }
        .onDisappear {
            assembleTask?.cancel()
            assembleTask = nil
            idleNudgeTask?.cancel()
            idleNudgeTask = nil
            fingerHintTask?.cancel()
            fingerHintTask = nil
        }
        .onChange(of: mode) { _, _ in
            guard !ignoreModeChange else { return }
            flickAssemble()
        }
    }

    // MARK: Working edge arrows

    private func swipeArrowButton(side: CGFloat) -> some View {
        let pull = side < 0 ? max(0, dragX) : max(0, -dragX)
        let approach = min(1, pull / stride)
        let x = side * arrowRestX + dragX * 0.18
        let baseOpac = arrowGlow ? 0.58 : 0.30
        let opac = (baseOpac + 0.32 * approach) * (isAssembling ? Double(assembleProgress) : 1)

        return Button {
            guard !isAssembling else { return }
            hideFingerHint()
            hasSwiped = true
            idleNudgeTask?.cancel()
            commitSwipe(pages: side < 0 ? -1 : 1, fromDrag: 0)
        } label: {
            Image(systemName: side < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55 + 0.35 * approach))
                .frame(width: 44, height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(opac)
        .offset(x: x)
        .zIndex(4)
        .disabled(isAssembling)
        .accessibilityLabel(side < 0 ? "Предыдущий режим" : "Следующий режим")
    }

    // MARK: Gesture

    private func hubDrag(midX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 6, abs(dx) > abs(dy) * 0.85 else {
                    if abs(dx) < 6, !isDragging { dragX = 0 }
                    return
                }
                isDragging = true
                hideFingerHint()
                let raw = dx
                let limit = stride * 1.2
                if abs(raw) <= limit {
                    dragX = raw
                } else {
                    let sign: CGFloat = raw > 0 ? 1 : -1
                    let extra = abs(raw) - limit
                    dragX = sign * (limit + extra * 0.28)
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let distance = hypot(dx, dy)
                let predicted = value.predictedEndTranslation.width
                let velocity = predicted - dx

                defer { isDragging = false }

                if !isDragging || (distance < 12 && abs(dx) < 10 && abs(dy) < 10) {
                    if distance < 14, abs(dx) < 12, abs(dy) < 12, !isAssembling {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { dragX = 0 }
                        activateCenter()
                    } else {
                        snapDragToZero()
                    }
                    return
                }

                let projected = dx + velocity * 0.55
                var pages = Int((-projected / stride).rounded())
                if pages == 0 {
                    let horizontalSwipe = abs(dx) > 36 && abs(dx) > abs(dy) * 1.15
                    let flick = abs(predicted) > 100 && abs(predicted) > abs(value.predictedEndTranslation.height) * 1.05
                    if horizontalSwipe || flick {
                        pages = (dx + predicted * 0.35) < 0 ? 1 : -1
                    }
                }
                pages = max(-1, min(1, pages))

                if pages != 0 {
                    hasSwiped = true
                    idleNudgeTask?.cancel()
                    idleNudgeTask = nil
                    hideFingerHint()
                    commitSwipe(pages: pages, fromDrag: dx)
                } else {
                    snapDragToZero()
                }
            }
    }

    private func snapDragToZero() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            dragX = 0
        }
    }

    private func commitSwipe(pages: Int, fromDrag: CGFloat) {
        guard Date() >= swipeLockUntil else {
            snapDragToZero()
            return
        }
        let next = mode.advanced(by: pages)
        guard next != mode else {
            snapDragToZero()
            return
        }
        swipeLockUntil = Date().addingTimeInterval(0.36)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

        let residual = fromDrag + CGFloat(pages) * stride
        ignoreModeChange = true
        mode = next
        dragX = residual
        ignoreModeChange = false

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            dragX = 0
        }
        flickAssemble()
    }

    private func activateCenter() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            morphPunch = 0.94
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                morphPunch = 1
            }
            onActivate(mode)
        }
    }

    // MARK: Assemble / nudge

    private func bootAssembleIfNeeded() {
        guard !bootDone else { return }
        bootDone = true
        if reduceMotion || TaikaCatalogBoot.isReady {
            assembleProgress = 1
            isAssembling = false
            morphPunch = 1
            invitePulse = true
            assembleCoordinator.skipToComplete()
            TaikaAssembleGate.shared.markVisited(key: "tab.main.hero")
            onBootFinished?()
            return
        }
        runAssemble(duration: 0.92, notifyCoordinator: true, playKick: true)
    }

    private func flickAssemble() {
        guard bootDone else { return }
        if reduceMotion {
            assembleProgress = 1
            isAssembling = false
            morphPunch = 1
            invitePulse = true
            return
        }
        runAssemble(duration: 0.48, notifyCoordinator: false, playKick: false)
    }

    private func runAssemble(duration: TimeInterval, notifyCoordinator: Bool, playKick: Bool) {
        assembleTask?.cancel()
        isAssembling = true
        assembleProgress = 0
        invitePulse = false
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            morphPunch = 0.88
        }
        if notifyCoordinator {
            assembleCoordinator.begin()
        }

        let steps = max(12, Int(duration * 28))
        assembleTask = Task { @MainActor in
            for step in 0...steps {
                guard !Task.isCancelled else { return }
                let t = Double(step) / Double(steps)
                let eased = t * t * (3 - 2 * t)
                assembleProgress = CGFloat(eased)
                morphPunch = CGFloat(0.88 + 0.12 * eased)
                if notifyCoordinator {
                    assembleCoordinator.update(progress: assembleProgress)
                }
                if step < steps {
                    try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                }
            }
            guard !Task.isCancelled else { return }
            isAssembling = false
            assembleProgress = 1
            withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                morphPunch = 1.06
            }
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                morphPunch = 1
            }
            invitePulse = true
            if notifyCoordinator {
                assembleCoordinator.complete()
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if notifyCoordinator {
                TaikaAssembleGate.shared.markVisited(key: "tab.main.hero")
                onBootFinished?()
            }
            if playKick {
                await playSwipeKickHint()
            }
        }
    }

    /// Early finger, then short sphere nudge.
    private func playSwipeKickHint() async {
        guard !kickDone, !reduceMotion else { return }
        kickDone = true

        await playFingerSwipeOnce()
        guard !Task.isCancelled, !hasSwiped else {
            startIdleNudgeLoop()
            return
        }

        try? await Task.sleep(nanoseconds: 90_000_000)
        guard !Task.isCancelled, !hasSwiped else {
            startIdleNudgeLoop()
            return
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeOut(duration: 0.24)) { dragX = stride * 0.22 }
        try? await Task.sleep(nanoseconds: 220_000_000)
        guard !Task.isCancelled, !hasSwiped else {
            startIdleNudgeLoop()
            return
        }
        withAnimation(.spring(response: 0.46, dampingFraction: 0.80)) { dragX = 0 }
        startIdleNudgeLoop()
    }

    private func playFingerSwipeOnce() async {
        guard !hasSwiped, !reduceMotion else { return }
        fingerHintTask?.cancel()
        fingerHintX = 40
        withAnimation(.easeOut(duration: 0.14)) { fingerHintVisible = true }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        try? await Task.sleep(nanoseconds: 70_000_000)
        guard !Task.isCancelled, !hasSwiped else { return }
        withAnimation(.easeInOut(duration: 0.48)) { fingerHintX = -44 }
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.18)) { fingerHintVisible = false }
    }

    private func hideFingerHint() {
        fingerHintTask?.cancel()
        fingerHintTask = nil
        if fingerHintVisible {
            withAnimation(.easeOut(duration: 0.15)) { fingerHintVisible = false }
        }
    }

    private func startIdleNudgeLoop() {
        idleNudgeTask?.cancel()
        guard !reduceMotion, !hasSwiped else { return }
        idleNudgeTask = Task { @MainActor in
            for _ in 0..<2 {
                try? await Task.sleep(nanoseconds: 5_200_000_000)
                guard !Task.isCancelled, !hasSwiped, !isAssembling, !isDragging else { return }
                withAnimation(.easeOut(duration: 0.28)) { dragX = stride * 0.14 }
                try? await Task.sleep(nanoseconds: 260_000_000)
                guard !Task.isCancelled, !hasSwiped, !isDragging else { return }
                withAnimation(.easeInOut(duration: 0.28)) { dragX = -stride * 0.10 }
                try? await Task.sleep(nanoseconds: 240_000_000)
                guard !Task.isCancelled, !hasSwiped, !isDragging else { return }
                withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) { dragX = 0 }
            }
        }
    }
}

/// Чипы под сферой в режиме обучения.
public struct MDMainLearnChipMarquee: View {
    public var courseTitles: [String]
    public var onOpenCourses: () -> Void

    public init(courseTitles: [String], onOpenCourses: @escaping () -> Void) {
        self.courseTitles = courseTitles
        self.onOpenCourses = onOpenCourses
    }

    public var body: some View {
        let titles = Array(courseTitles.prefix(5))
        let items: [TaikaMarqueeChipItem] = {
            if titles.isEmpty {
                return [TaikaMarqueeChipItem(id: "courses", title: "Смотреть курсы")]
            }
            return titles.map { TaikaMarqueeChipItem(id: $0, title: $0) }
        }()
        return TaikaNeutralChipMarquee(
            items: items,
            accessibilityLabel: "Курсы",
            onSelect: { _ in onOpenCourses() }
        )
    }
}

/// Чипы под сферой в режиме избранного.
public struct MDMainFavoritesChipMarquee: View {
    public var onOpenFavorites: () -> Void

    public init(onOpenFavorites: @escaping () -> Void) {
        self.onOpenFavorites = onOpenFavorites
    }

    public var body: some View {
        TaikaNeutralChipMarquee(
            items: [
                TaikaMarqueeChipItem(id: "fav", title: "Мои фразы"),
                TaikaMarqueeChipItem(id: "open", title: "Открыть избранное")
            ],
            accessibilityLabel: "Избранное",
            onSelect: { _ in onOpenFavorites() }
        )
    }
}
