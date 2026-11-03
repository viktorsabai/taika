//
//  MDMainHubSphere.swift
//  taika
//
//  Главная: одна hero-сфера. Тап — умный спикер.
//

import SwiftUI

/// Режимы hero-сферы на Главной. Свайп убран: сфера всегда спикер.
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
}

/// Одна сфера. Тап по центру — вход в спикер.
public struct MDMainHubSphere: View {
    @Binding var mode: MDMainHubMode
    var onActivate: (MDMainHubMode) -> Void
    var onBootFinished: (() -> Void)? = nil

    @EnvironmentObject private var assembleCoordinator: TaikaAssembleCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var assembleProgress: CGFloat = TaikaCatalogBoot.isReady ? 1 : 0
    @State private var isAssembling = !TaikaCatalogBoot.isReady
    @State private var bootDone = false
    @State private var assembleTask: Task<Void, Never>?
    @State private var invitePulse = false
    @State private var morphPunch: CGFloat = 1

    private let planetFrame: CGFloat = TaikaHeroColumn.planetFrame

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
        Button {
            guard !isAssembling else { return }
            activateCenter()
        } label: {
            TaikaVoicePlanet(
                mode: isAssembling ? .assemble : .idle,
                kind: .voice,
                scale: TaikaHeroColumn.planetScale,
                centerSymbol: "mic.fill",
                lite: true,
                inviteTap: !isAssembling && invitePulse,
                assembleProgress: isAssembling ? assembleProgress : nil,
                palette: .theme,
                idleAccent: 0.78
            )
            .frame(width: planetFrame, height: planetFrame)
            .scaleEffect(morphPunch)
        }
        .buttonStyle(.plain)
        .frame(width: planetFrame + 48, height: TaikaHeroColumn.sphereBand)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Спикер")
        .accessibilityHint("Открыть умный спикер")
        .accessibilityAddTraits(.isButton)
        .onAppear { bootAssembleIfNeeded() }
        .onDisappear {
            assembleTask?.cancel()
            assembleTask = nil
        }
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
            onActivate(.speaker)
        }
    }

    private func bootAssembleIfNeeded() {
        guard !bootDone else { return }
        bootDone = true
        mode = .speaker
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
        runAssemble()
    }

    private func runAssemble() {
        assembleTask?.cancel()
        isAssembling = true
        assembleProgress = 0
        invitePulse = false
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            morphPunch = 0.88
        }
        assembleCoordinator.begin()

        let duration: TimeInterval = 0.92
        let steps = max(12, Int(duration * 28))
        assembleTask = Task { @MainActor in
            for step in 0...steps {
                guard !Task.isCancelled else { return }
                let t = Double(step) / Double(steps)
                let eased = t * t * (3 - 2 * t)
                assembleProgress = CGFloat(eased)
                morphPunch = CGFloat(0.88 + 0.12 * eased)
                assembleCoordinator.update(progress: assembleProgress)
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
            assembleCoordinator.complete()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            TaikaAssembleGate.shared.markVisited(key: "tab.main.hero")
            onBootFinished?()
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
