//
//  TaikaVoicePlanet.swift
//  taika
//
//  Voice instrument: hollow shell of light. Brand dots while cooking; burst into the breakdown.
//

import SwiftUI

public enum TaikaVoicePlanetMode: Equatable {
    case idle
    case cooking
    case speaking
    case listening
    case result
    /// Disperse into the breakdown — not a rest pose.
    case burst
    /// Boot: atoms fly in from the edges and lock onto the shell.
    case assemble
}

public enum TaikaVoicePlanetKind: Equatable {
    case voice
    case text
}

/// Shell color for idle empty-state planets (speaker stays `.theme` / white).
public enum TaikaVoicePlanetPalette: Equatable {
    case theme
    case heart
    case lexicon
    case course
    case spark
    /// Закрепление: янтарное золото, не розовый спикера.
    case console
}

/// Shared voice control — Main, Speaker, onboarding.
public struct TaikaVoicePlanet: View {
    public let mode: TaikaVoicePlanetMode
    public var kind: TaikaVoicePlanetKind = .voice
    public var scale: CGFloat = 1
    public var centerSymbol: String? = nil
    /// Score or other caption in the hollow core (onboarding result).
    public var centerText: String? = nil
    public var lite: Bool = false
    public var inviteTap: Bool = false
    /// Live voice level 0…1 — used in `.listening` / `.speaking`.
    public var audioLevel: CGFloat = 0
    public var showsCarousel: Bool = true
    /// Shared clock with the breakdown reveal (0…1). Nil = internal timer.
    public var burstProgress: CGFloat? = nil
    /// Shared clock with boot assemble (0…1). Nil = internal timer. 0 = scattered, 1 = shell.
    public var assembleProgress: CGFloat? = nil
    public var palette: TaikaVoicePlanetPalette = .theme
    /// 0…1 share of idle dots painted with the palette (Main / Speaker default pink).
    public var idleAccent: CGFloat = 0.52

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var idlePulse = false
    @State private var sonarPhase = false
    @State private var burstT0: TimeInterval? = nil
    @State private var cookT0: TimeInterval? = nil
    @State private var assembleT0: TimeInterval? = nil

    public init(
        mode: TaikaVoicePlanetMode,
        kind: TaikaVoicePlanetKind = .voice,
        scale: CGFloat = 1,
        centerSymbol: String? = nil,
        centerText: String? = nil,
        lite: Bool = false,
        inviteTap: Bool = false,
        audioLevel: CGFloat = 0,
        showsCarousel: Bool = true,
        burstProgress: CGFloat? = nil,
        assembleProgress: CGFloat? = nil,
        palette: TaikaVoicePlanetPalette = .theme,
        idleAccent: CGFloat = 0.52
    ) {
        self.mode = mode
        self.kind = kind
        self.scale = scale
        self.centerSymbol = centerSymbol
        self.centerText = centerText
        self.lite = lite
        self.inviteTap = inviteTap
        self.audioLevel = min(max(audioLevel, 0), 1)
        self.showsCarousel = showsCarousel
        self.burstProgress = burstProgress.map { min(max($0, 0), 1) }
        self.assembleProgress = assembleProgress.map { min(max($0, 0), 1) }
        self.palette = palette
        self.idleAccent = min(max(idleAccent, 0), 1)
    }

    private var accentFill: LinearGradient {
        switch kind {
        case .voice:
            return LinearGradient(
                colors: brandStops,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .text:
            return LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.78, blue: 1.0),
                    Color(red: 0.72, green: 0.90, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var level: CGFloat {
        switch mode {
        case .listening, .speaking: return audioLevel
        default: return 0
        }
    }

    private var micSymbol: String {
        if let centerSymbol, !centerSymbol.isEmpty { return centerSymbol }
        switch kind {
        case .text: return "keyboard"
        case .voice:
            switch mode {
            case .listening: return "ear.fill"
            case .cooking, .burst: return "magnifyingglass"
            case .result: return "checkmark"
            case .speaking: return "speaker.wave.2.fill"
            case .idle, .assemble: return "mic.fill"
            }
        }
    }

    public var body: some View {
        ZStack {
            if kind == .text {
                textKindPlaceholder
            } else if showsCarousel {
                instrument
            } else {
                planetCoreMark
            }
        }
        .frame(width: 300, height: 300)
        .scaleEffect(scale)
        .animation(.easeInOut(duration: 0.3), value: mode)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            syncMotion()
            if mode == .cooking { cookT0 = Date().timeIntervalSinceReferenceDate }
            if mode == .burst { burstT0 = Date().timeIntervalSinceReferenceDate }
            if mode == .assemble { assembleT0 = Date().timeIntervalSinceReferenceDate }
        }
        .onChange(of: mode) { old, new in
            syncMotion()
            beginBurstIfNeeded(from: old, to: new)
            if new == .cooking, old != .cooking {
                cookT0 = Date().timeIntervalSinceReferenceDate
            } else if new != .cooking, new != .burst {
                cookT0 = nil
            }
            if new == .assemble, old != .assemble {
                assembleT0 = Date().timeIntervalSinceReferenceDate
            } else if new != .assemble {
                assembleT0 = nil
            }
        }
        .onChange(of: inviteTap) { _, _ in syncMotion() }
    }

    private var accessibilityLabel: String {
        switch mode {
        case .idle: return "Микрофон"
        case .listening: return "Слушаю"
        case .cooking: return "Распознаю"
        case .burst: return "Собираю разбор"
        case .assemble: return "Taika"
        case .speaking: return "Говорю"
        case .result: return centerText == nil ? "Готово" : "Оценка \(centerText ?? "")"
        }
    }

    private func syncMotion() {
        guard !reduceMotion else {
            idlePulse = false
            sonarPhase = false
            return
        }
        switch mode {
        case .cooking, .burst, .assemble:
            sonarPhase = false
            idlePulse = false
            if mode == .cooking {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    idlePulse = true
                }
            }
        case .idle:
            sonarPhase = false
            idlePulse = false
            withAnimation(.easeInOut(duration: inviteTap ? 1.85 : 2.6).repeatForever(autoreverses: true)) {
                idlePulse = true
            }
        case .listening, .speaking:
            idlePulse = false
            sonarPhase = true
        case .result:
            idlePulse = false
            sonarPhase = false
        }
    }

    private func beginBurstIfNeeded(from old: TaikaVoicePlanetMode, to new: TaikaVoicePlanetMode) {
        if new == .burst || (old == .cooking && new == .result) {
            burstT0 = Date().timeIntervalSinceReferenceDate
        } else if new != .burst && new != .result {
            burstT0 = nil
        }
    }

    private func burstAmount(at now: TimeInterval) -> Double {
        if let burstProgress { return Double(burstProgress) }
        if reduceMotion { return mode == .burst ? 1 : 0 }
        guard let t0 = burstT0 else { return 0 }
        return min(1, max(0, (now - t0) / 0.88))
    }

    /// 0 = atoms still scattered, 1 = hollow shell locked.
    private func assembleAmount(at now: TimeInterval) -> Double {
        if mode != .assemble { return 1 }
        if let assembleProgress { return Double(assembleProgress) }
        if reduceMotion { return 1 }
        guard let t0 = assembleT0 else { return 0 }
        return min(1, max(0, (now - t0) / 1.18))
    }

    /// Random ignition 0…1 — more brand dots means analysis is further along.
    private func cookFill(at now: TimeInterval) -> Double {
        if mode == .burst || (burstProgress ?? 0) > 0.001 { return 1 }
        if mode != .cooking { return 0 }
        if reduceMotion { return 0.55 }
        guard let t0 = cookT0 else { return 0 }
        let raw = min(1, max(0, (now - t0) / 2.15))
        return 0.94 * (1 - (1 - raw) * (1 - raw))
    }

    private var brandStops: [Color] {
        switch palette {
        case .heart:
            // Sky → soft cloud white (hub favorites / dictionary).
            return [
                Color(red: 0.10, green: 0.52, blue: 0.95),
                Color(red: 0.45, green: 0.80, blue: 1.00),
                Color(red: 0.94, green: 0.98, blue: 1.00)
            ]
        case .lexicon:
            return [
                Color(red: 0.52, green: 0.32, blue: 0.95),
                Color(red: 0.62, green: 0.58, blue: 1.00),
                Color(red: 0.90, green: 0.78, blue: 1.00)
            ]
        case .course:
            // Match Theme.Gradients.accentCourseGreen (hub learn / courses).
            return [
                Color(red: 0.06, green: 0.42, blue: 0.28),
                Color(red: 0.28, green: 0.78, blue: 0.52),
                Color(red: 0.92, green: 0.72, blue: 0.88)
            ]
        case .spark:
            return [
                Color(red: 0.98, green: 0.48, blue: 0.12),
                Color(red: 1.00, green: 0.78, blue: 0.28),
                Color(red: 1.00, green: 0.94, blue: 0.70)
            ]
        case .console:
            return [
                Color(red: 1.00, green: 0.90, blue: 0.48),
                Color(red: 0.96, green: 0.68, blue: 0.18),
                Color(red: 0.82, green: 0.42, blue: 0.08)
            ]
        case .theme:
            switch theme.accent {
            case .pink, .thai:
                // Same family as header kAAA / Theme.Gradients.accentText (pink → soft lilac).
                return [
                    Color(red: 1.00, green: 0.52, blue: 0.85),
                    Color(red: 0.98, green: 0.65, blue: 0.92),
                    Color(red: 0.90, green: 0.78, blue: 1.00)
                ]
            case .azure:
                return [
                    Color(red: 0.05, green: 0.40, blue: 0.24),
                    Color(red: 0.20, green: 0.62, blue: 0.58),
                    Color(red: 0.78, green: 0.90, blue: 1.00)
                ]
            case .sun:
                return [
                    Color(red: 0.93, green: 0.34, blue: 0.08),
                    Color(red: 1.00, green: 0.78, blue: 0.28),
                    Color(red: 1.00, green: 0.96, blue: 0.72)
                ]
            }
        }
    }

    // MARK: - Instrument

    private var cloudLive: Bool {
        if reduceMotion { return false }
        switch mode {
        case .result: return burstT0 != nil
        case .idle: return true
        default: return true
        }
    }

    private func globeClock(now: TimeInterval, burst: Double) -> TimeInterval {
        if reduceMotion { return 0 }
        if mode == .result, burst <= 0 { return now * 0.04 }
        if mode == .assemble { return now * 0.22 }
        return now
    }

    private func micScale(burst: Double, gather: Double) -> CGFloat {
        listeningCoreScale * (1 - CGFloat(burst) * 0.22) * (0.78 + 0.22 * CGFloat(gather))
    }

    private func micOpacity(burst: Double, gather: Double) -> Double {
        let core = gather * gather
        if let centerText, !centerText.isEmpty, mode == .result {
            return core
        }
        return max(0, (1 - burst * 2.8) * core)
    }

    @ViewBuilder
    private var planetCoreMark: some View {
        if let centerText, !centerText.isEmpty {
            Text(centerText)
                .font(.system(size: lite ? 40 : 52, weight: .bold, design: .rounded))
                .foregroundStyle(accentFill)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .contentTransition(.numericText())
        } else {
            Image(systemName: micSymbol)
                .font(.system(size: lite ? 28 : 32, weight: .semibold))
                .foregroundStyle(accentFill.opacity(0.94))
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(response: 0.36, dampingFraction: 0.82), value: palette)
                .animation(.spring(response: 0.36, dampingFraction: 0.82), value: micSymbol)
        }
    }

    private var instrument: some View {
        TimelineView(.animation(minimumInterval: cloudLive ? 1.0 / 30.0 : 120)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let burst = burstAmount(at: now)
            let gather = assembleAmount(at: now)
            let fill = cookFill(at: now)
            let clock = globeClock(now: now, burst: burst)
            ZStack {
                MDParticleGlobe(
                    time: clock,
                    mode: mode,
                    audio: Double(level),
                    accent: brandStops,
                    burst: burst,
                    cookFill: fill,
                    assemble: gather,
                    idleTint: Double(idleAccent)
                )
                .frame(width: 300, height: 300)

                planetCoreMark
                    .scaleEffect(micScale(burst: burst, gather: gather))
                    .opacity(micOpacity(burst: burst, gather: gather))
            }
        }
        .allowsHitTesting(false)
    }

    private var listeningCoreScale: CGFloat {
        switch mode {
        case .listening, .speaking:
            return 0.96 + level * 0.10
        case .cooking:
            return idlePulse ? 0.92 : 1.04
        case .burst:
            return 1.08
        case .assemble:
            return 1
        default:
            return idlePulse ? 1.03 : 1
        }
    }

    @ViewBuilder
    private var textKindPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(accentFill.opacity(0.7), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
            .frame(width: 72, height: 46)
            .overlay(
                Image(systemName: "keyboard")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentFill)
            )
    }
}

// MARK: - Hollow sphere. Accent ignites at random; burst stays spherical.

private struct MDParticleGlobe: View {
    let time: TimeInterval
    let mode: TaikaVoicePlanetMode
    let audio: Double
    let accent: [Color]
    let burst: Double
    let cookFill: Double
    let assemble: Double
    let idleTint: Double

    var body: some View {
        Canvas { context, size in
            MDParticleGlobe.draw(
                in: &context,
                size: size,
                time: time,
                mode: mode,
                audio: audio,
                accent: accent,
                burst: burst,
                cookFill: cookFill,
                assemble: assemble,
                idleTint: idleTint
            )
        }
    }

    private static func unit(_ index: Int, salt: UInt32) -> Double {
        var h = UInt32(truncatingIfNeeded: index) &* 374761393 &+ salt
        h ^= h >> 16
        h &*= 2246822519
        return Double(h & 0x7fffffff) / Double(0x7fffffff)
    }

    private static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        mode: TaikaVoicePlanetMode,
        audio: Double,
        accent: [Color],
        burst: Double,
        cookFill: Double,
        assemble: Double,
        idleTint: Double
    ) {
        let cx = size.width * 0.5
        let cy = size.height * 0.5
        let count = 180
        let golden = Double.pi * (3 - sqrt(5))
        let cooking = mode == .cooking
        let gathering = mode == .assemble && assemble < 0.999
        let fill = max((mode == .burst || burst > 0.001) ? 1.0 : cookFill, idleTint)

        let speed: Double = {
            if burst > 0.2 { return 0.42 }
            switch mode {
            case .cooking: return 2.05
            case .burst: return 0.85
            case .assemble: return 0.38
            case .listening, .speaking: return 1.55
            case .result: return 0.10
            case .idle: return 0.26
            }
        }()
        let t = time * speed
        let baseR: Double = {
            switch mode {
            case .cooking, .burst: return 58
            case .listening, .speaking: return 62 * (1.0 + audio * 0.32)
            case .result, .assemble, .idle: return 60
            }
        }()
        let voidR = baseR * 0.48
        let jitter = (mode == .listening || mode == .speaking) ? audio * 6.0 : 0
        let trail: Int = cooking && burst < 0.08 ? 2 : 0
        let expand = 1 + burst * burst * 1.55

        struct Particle {
            var x: CGFloat
            var y: CGFloat
            var z: Double
            var trail: Double
            var index: Int
            var gather: Double
        }
        var pts: [Particle] = []
        pts.reserveCapacity(count * (1 + trail))

        let tilt = 0.38
        let cosT = cos(tilt)
        let sinT = sin(tilt)
        let gatherEase = assemble * assemble * (3 - 2 * assemble)

        for i in 0..<count {
            let y0 = 1 - (Double(i) / Double(count - 1)) * 2
            let ring = sqrt(max(0, 1 - y0 * y0))
            let theta = golden * Double(i) + t
            let jx = jitter * sin(theta * 2.4 + t * 3)
            let jy = jitter * cos(theta * 1.7 + t * 2.2)

            let delay = unit(i, salt: 0xA11CE) * 0.46
            let local = gathering
                ? min(1, max(0, (gatherEase - delay) / max(0.18, 1 - delay)))
                : 1
            let landed = local * local * (3 - 2 * local)
            let scatterR = 92 + unit(i, salt: 0x51ED) * 148
            let scatterA = unit(i, salt: 0xC0DE) * .pi * 2
            let scatterX = cos(scatterA) * scatterR
            let scatterY = sin(scatterA) * scatterR * (0.72 + unit(i, salt: 0xBEEF) * 0.55)

            func project(_ th: Double, trailAmt: Double) -> Particle {
                let x0 = cos(th) * ring
                let z0 = sin(th) * ring
                let y1 = y0 * cosT - z0 * sinT
                let z1 = y0 * sinT + z0 * cosT
                let sx = (x0 * baseR + jx) * expand
                let sy = (y1 * baseR + jy) * expand
                return Particle(
                    x: CGFloat(sx * landed + scatterX * (1 - landed)),
                    y: CGFloat(sy * landed + scatterY * (1 - landed)),
                    z: z1,
                    trail: trailAmt,
                    index: i,
                    gather: landed
                )
            }

            pts.append(project(theta, trailAmt: 0))
            if trail > 0 {
                pts.append(project(theta - 0.10, trailAmt: 0.4))
                pts.append(project(theta - 0.20, trailAmt: 0.18))
            }
        }

        pts.sort { $0.z < $1.z }

        for p in pts {
            let dist = Double(hypot(p.x, p.y))
            let hideVoid = burst < 0.04 && (!gathering || p.gather > 0.88)
            if hideVoid, dist < voidR { continue }
            let edge = hideVoid && dist < voidR + 10 ? (dist - voidR) / 10 : 1

            let spark = Double((p.index &* 2654435761) & 0x7fffffff) / Double(0x7fffffff)
            let isAccent = fill > 0.001 && spark < fill
            let depth = min(max((p.z + 1) * 0.5, 0), 1)
            let dot = (1.15 + depth * 1.85) * (isAccent ? 1.18 : 1) * (0.72 + 0.28 * p.gather)
            let fade = 1 - burst * 0.92
            let approach = 0.22 + 0.78 * p.gather
            let alpha = (0.10 + depth * 0.55) * (p.trail == 0 ? 1 : p.trail) * edge * fade * approach
            guard alpha > 0.02 else { continue }

            let fillColor: Color = {
                if isAccent, !accent.isEmpty {
                    return accent[p.index % accent.count].opacity(alpha)
                }
                return Color.white.opacity(alpha)
            }()
            let rect = CGRect(
                x: cx + p.x - dot,
                y: cy + p.y - dot,
                width: dot * 2,
                height: dot * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(fillColor))
        }
    }
}

// MARK: - Soft assemble (in-app screens)

public enum TaikaAssembleTier {
    /// Cold boot / onboarding — full ritual (~1.18s).
    case boot
    /// Tab enter, empty states (~0.88s).
    case soft
    /// Quick revisit (~0.38s).
    case micro

    var duration: TimeInterval {
        switch self {
        case .boot: return 1.35
        case .soft: return 1.52
        case .micro: return 0.68
        }
    }
}

@MainActor
public final class TaikaAssembleGate {
    public static let shared = TaikaAssembleGate()

    public static let tabActivatedNotification = Notification.Name("TaikaAssembleTabActivated")

    private var lastVisit: [String: Date] = [:]
    private let cooldown: TimeInterval = 28

    private let tabGateKeys: [Int: String] = [
        0: "tab.main.hero",
        2: "tab.speaker",
        3: "tab.favorites",
        4: "tab.gamepark"
    ]

    private init() {}

    public func postTabActivated(_ tab: Int) {
        guard let key = tabGateKeys[tab] else { return }
        NotificationCenter.default.post(name: Self.tabActivatedNotification, object: key)
    }

    public func tier(for key: String) -> TaikaAssembleTier {
        guard let last = lastVisit[key] else { return .soft }
        return Date().timeIntervalSince(last) > cooldown ? .soft : .micro
    }

    public func markVisited(key: String) {
        lastVisit[key] = Date()
    }

    /// Scroll bounce / rapid re-appear — skip assemble entirely.
    public func shouldSkipInstantly(key: String) -> Bool {
        guard let last = lastVisit[key] else { return false }
        return Date().timeIntervalSince(last) < 2.0
    }

    public func reset(key: String) {
        lastVisit.removeValue(forKey: key)
    }
}

@MainActor
public final class TaikaAssembleCoordinator: ObservableObject {
    @Published public private(set) var progress: CGFloat = 1
    @Published public private(set) var isComplete: Bool = true
    /// После анимированной сборки сферы — каскад UI. После skip — сразу всё.
    @Published public private(set) var shouldCascadeUI: Bool = false
    /// Инкремент при каждом complete/skip — чтобы UI синхронизировался даже при skip без begin.
    @Published public private(set) var revealGeneration: Int = 0

    public init() {}

    public func begin() {
        progress = 0
        isComplete = false
        shouldCascadeUI = true
    }

    public func update(progress: CGFloat) {
        self.progress = min(1, max(0, progress))
    }

    public func complete() {
        progress = 1
        isComplete = true
        revealGeneration &+= 1
    }

    public func skipToComplete() {
        progress = 1
        isComplete = true
        shouldCascadeUI = false
        revealGeneration &+= 1
    }
}

/// Planet that assembles on appear — shared ritual for Main, Game Park, empty states.
public struct TaikaAssemblingPlanet: View {
    public var gateKey: String?
    public var tier: TaikaAssembleTier?
    public var kind: TaikaVoicePlanetKind = .voice
    public var scale: CGFloat = 0.62
    public var centerSymbol: String? = nil
    public var inviteTap: Bool = false
    public var palette: TaikaVoicePlanetPalette = .theme
    public var idleAccent: CGFloat = 0.52
    public var frameSize: CGFloat = 188
    public var allowsHitTesting: Bool = true
    /// Режим планеты после сборки (динамический для Speaker).
    public var settledMode: TaikaVoicePlanetMode = .idle
    public var audioLevel: CGFloat = 0

    @EnvironmentObject private var assembleCoordinator: TaikaAssembleCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isAssembling = true
    @State private var drivenProgress: CGFloat = 0
    @State private var effectiveInviteTap = false
    @State private var assembleTask: Task<Void, Never>?

    public init(
        gateKey: String? = nil,
        tier: TaikaAssembleTier? = nil,
        kind: TaikaVoicePlanetKind = .voice,
        scale: CGFloat = 0.62,
        centerSymbol: String? = nil,
        inviteTap: Bool = false,
        palette: TaikaVoicePlanetPalette = .theme,
        idleAccent: CGFloat = 0.52,
        frameSize: CGFloat = 188,
        allowsHitTesting: Bool = true,
        settledMode: TaikaVoicePlanetMode = .idle,
        audioLevel: CGFloat = 0
    ) {
        self.gateKey = gateKey
        self.tier = tier
        self.kind = kind
        self.scale = scale
        self.centerSymbol = centerSymbol
        self.inviteTap = inviteTap
        self.palette = palette
        self.idleAccent = idleAccent
        self.frameSize = frameSize
        self.allowsHitTesting = allowsHitTesting
        self.settledMode = settledMode
        self.audioLevel = audioLevel
    }

    private var displayMode: TaikaVoicePlanetMode {
        isAssembling ? .assemble : settledMode
    }

    public var body: some View {
        TaikaVoicePlanet(
            mode: displayMode,
            kind: kind,
            scale: scale,
            centerSymbol: centerSymbol,
            lite: true,
            inviteTap: effectiveInviteTap,
            audioLevel: isAssembling ? 0 : audioLevel,
            assembleProgress: isAssembling ? drivenProgress : nil,
            palette: palette,
            idleAccent: idleAccent
        )
        .frame(width: frameSize, height: frameSize)
        .allowsHitTesting(allowsHitTesting)
        .onAppear { runAssemble() }
        .onDisappear {
            assembleTask?.cancel()
            assembleTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: TaikaAssembleGate.tabActivatedNotification)) { note in
            guard let activated = note.object as? String, let gateKey else { return }
            let matches = activated == gateKey
                || (activated == "tab.favorites" && gateKey.hasPrefix("tab.favorites"))
            guard matches else { return }
            runAssemble()
        }
        .onChange(of: inviteTap) { _, newValue in
            guard assembleCoordinator.isComplete else { return }
            effectiveInviteTap = newValue
        }
    }

    private func runAssemble() {
        assembleTask?.cancel()

        let resolvedTier: TaikaAssembleTier = {
            if let tier { return tier }
            if let gateKey { return TaikaAssembleGate.shared.tier(for: gateKey) }
            return .soft
        }()

        if reduceMotion {
            finishImmediately(markGate: gateKey != nil)
            return
        }

        if let gateKey, TaikaAssembleGate.shared.shouldSkipInstantly(key: gateKey) {
            finishImmediately(markGate: false)
            return
        }

        runAnimatedAssemble(duration: resolvedTier.duration, markGate: gateKey != nil)
    }

    private func finishImmediately(markGate: Bool) {
        isAssembling = false
        drivenProgress = 1
        effectiveInviteTap = inviteTap
        assembleCoordinator.skipToComplete()
        if markGate, let gateKey { TaikaAssembleGate.shared.markVisited(key: gateKey) }
    }

    private func runAnimatedAssemble(duration: TimeInterval, markGate: Bool) {
        assembleCoordinator.begin()
        isAssembling = true
        drivenProgress = 0
        effectiveInviteTap = false

        let steps = max(16, Int(duration * 24))
        assembleTask = Task { @MainActor in
            for step in 0...steps {
                guard !Task.isCancelled else { return }
                let t = Double(step) / Double(steps)
                let eased = t * t * (3 - 2 * t)
                drivenProgress = CGFloat(eased)
                assembleCoordinator.update(progress: drivenProgress)
                if step < steps {
                    try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                }
            }
            guard !Task.isCancelled else { return }
            isAssembling = false
            drivenProgress = 1
            effectiveInviteTap = inviteTap
            assembleCoordinator.complete()
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            if markGate, let gateKey { TaikaAssembleGate.shared.markVisited(key: gateKey) }
        }
    }
}

/// Empty-screen planet: same hollow shell, section palette + glyph in the void.
struct TaikaEmptyPlanet: View {
    var systemImage: String
    var gateKey: String?

    private var resolved: (symbol: String, palette: TaikaVoicePlanetPalette) {
        switch systemImage {
        case "heart", "heart.fill":
            return ("heart.fill", .heart)
        case "bookmark", "bookmark.fill":
            // Словарь живёт во вкладке Избранного: та же небесная сфера, не отдельный фиолетовый lexicon.
            return ("bookmark.fill", .heart)
        case "graduationcap", "graduationcap.fill":
            return ("graduationcap.fill", .course)
        case "lightbulb", "lightbulb.fill", "lightbulb.slash":
            return ("lightbulb.fill", .spark)
        case "mic", "mic.fill":
            return ("mic.fill", .theme)
        default:
            return (systemImage, .theme)
        }
    }

    var body: some View {
        let spec = resolved
        TaikaAssemblingPlanet(
            gateKey: gateKey ?? "empty.\(systemImage)",
            scale: 0.72,
            centerSymbol: spec.symbol,
            inviteTap: true,
            palette: spec.palette,
            idleAccent: 0.58,
            frameSize: 220,
            allowsHitTesting: false
        )
        .accessibilityHidden(true)
    }
}
