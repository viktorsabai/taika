#if DEBUG

//
//  TaikaStoryLabPMSession.swift
//  taika
//
//  Story Lab — работа PM в Jira (~56s), behind-the-scenes.
//  Goals Work → Board sprint → Timeline Beta → Process table.
//  Стилизованный Atlassian-chrome, контент про Taika launch.
//

import SwiftUI

// MARK: - Clock

@MainActor
final class StoryLabPMClock: ObservableObject {
    @Published var t: TimeInterval = 0
    @Published var isPlaying = true
    let duration: TimeInterval = 56
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

enum StoryLabPMFocus: Equatable {
    case boot, goals, board, timeline, process, settle
}

struct StoryLabPMScene: Equatable {
    var panel: CGFloat
    var goalsOpacity: CGFloat
    var boardOpacity: CGFloat
    var timelineOpacity: CGFloat
    var processOpacity: CGFloat
    var adoption: CGFloat
    var goalType: CGFloat
    var contributingReveal: CGFloat
    var atRiskFlash: CGFloat
    var cardDrag: CGFloat
    var cardColumn: Int
    var sprintPulse: CGFloat
    var todayLine: CGFloat
    var betaPopover: CGFloat
    var barFill: CGFloat
    var processChecks: Int
    var goalsSearch: CGFloat
    var searchTyped: CGFloat
    var opsTag: CGFloat
    var ready: CGFloat
    var marquee: CGFloat
    var chip: String?
    var tag: String?
    var action: String?
    var focus: StoryLabPMFocus
    var cursorX: CGFloat
    var cursorY: CGFloat
    var click: CGFloat
    var camScale: CGFloat
    var camX: CGFloat
    var camY: CGFloat

    static func at(_ t: TimeInterval) -> StoryLabPMScene {
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

        // 0–2 boot
        // 2–14 goals
        // 14–30 board
        // 30–42 timeline
        // 42–52 process
        // 52–56 settle

        let focus: StoryLabPMFocus = {
            switch t {
            case ..<2: return .boot
            case ..<14: return .goals
            case ..<30: return .board
            case ..<42: return .timeline
            case ..<52: return .process
            default: return .settle
            }
        }()

        let cardColumn: Int = {
            if t < 18.5 { return 0 } // To Do
            if t < 22.5 { return 1 } // In Progress
            if t < 26.5 { return 2 } // In Review
            return 3 // Done
        }()

        let processChecks: Int = {
            if t < 44.0 { return 2 }
            if t < 46.0 { return 3 }
            if t < 48.0 { return 5 }
            if t < 50.0 { return 6 }
            return 7
        }()

        let chip: String? = {
            if t >= 3.5 && t < 6.0 { return "Goal · Objective" }
            if t >= 8.0 && t < 11.0 { return "Adoption · 75%" }
            if t >= 16.0 && t < 19.0 { return "Board · Sprint" }
            if t >= 22.0 && t < 25.5 { return "Card · drag" }
            if t >= 32.0 && t < 35.0 { return "Timeline · Beta" }
            if t >= 44.0 && t < 47.0 { return "Process · audit" }
            if t >= 48.5 && t < 51.0 { return "@ Operations" }
            return nil
        }()

        let tag: String? = {
            switch focus {
            case .goals: return "Jira · Goals"
            case .board: return "Jira · Board"
            case .timeline: return "Jira · Timeline"
            case .process: return "Jira · Plan"
            case .settle: return "PM · ready"
            default: return "Jira"
            }
        }()

        let action: String? = {
            if t >= 5.5 && t < 8.0 { return "Open · Work tab" }
            if t >= 19.5 && t < 22.0 { return "Move · In Progress" }
            if t >= 25.0 && t < 27.5 { return "Move · Done" }
            if t >= 36.0 && t < 39.0 { return "Release · Beta 1.0" }
            if t >= 47.5 && t < 50.5 { return "Link · Launch goal" }
            return nil
        }()

        func cursorAt(_ e: TimeInterval) -> (CGFloat, CGFloat) {
            switch e {
            case ..<2: return (0.50, 0.55)
            case ..<14:
                if e < 4.0 { return (0.28, 0.18) }
                if e < 7.0 { return (0.82, 0.28) }
                if e < 10.0 { return (0.40, 0.48) }
                return (0.55, 0.62)
            case ..<30:
                if e < 16.0 { return (0.22, 0.20) }
                if e < 19.0 { return (0.18, 0.42) }
                if e < 23.0 { return (0.42, 0.45) }
                if e < 27.0 { return (0.78, 0.48) }
                return (0.55, 0.18)
            case ..<42:
                if e < 32.0 { return (0.55, 0.22) }
                if e < 36.0 { return (0.62, 0.38) }
                return (0.58, 0.48)
            case ..<52:
                if e < 44.0 { return (0.20, 0.35) }
                if e < 47.0 { return (0.55, 0.52) }
                return (0.62, 0.68)
            default: return (0.50, 0.90)
            }
        }

        let cxcy = cursorAt(t)
        let prev = cursorAt(max(0, t - 0.28))
        let moveStart: TimeInterval = {
            switch focus {
            case .boot: return 0
            case .goals: return t < 4 ? 2 : (t < 7 ? 4 : (t < 10 ? 7 : 10))
            case .board: return t < 16 ? 14 : (t < 19 ? 16 : (t < 23 ? 19 : 23))
            case .timeline: return t < 32 ? 30 : (t < 36 ? 32 : 36)
            case .process: return t < 44 ? 42 : (t < 47 ? 44 : 47)
            case .settle: return 52
            }
        }()
        let move = min(1, max(0, (t - moveStart) / 0.28))

        let clickTimes: [TimeInterval] = [
            3.2, 5.8, 8.4, 11.2,
            15.5, 18.8, 22.2, 26.0, 28.2,
            33.5, 37.0, 39.5,
            43.5, 46.5, 49.0,
            53.0
        ]
        let click: CGFloat = {
            for c in clickTimes {
                let d = abs(t - c)
                if d < 0.1 { return CGFloat(1 - d / 0.1) }
            }
            return 0
        }()

        let (camScale, camX, camY): (CGFloat, CGFloat, CGFloat) = {
            switch focus {
            case .boot: return (0.92, 0, 0)
            case .goals: return (lerp(0.92, 1.05, ramp(2, 4)), lerp(0, -8, ramp(7, 10)), lerp(0, -12, ramp(3, 6)))
            case .board: return (1.0, 0, 0)
            case .timeline: return (lerp(1.0, 1.08, ramp(30, 33)), lerp(0, 10, ramp(34, 38)), -6)
            case .process: return (1.02, 0, 4)
            case .settle: return (0.98, 0, 0)
            }
        }()

        return StoryLabPMScene(
            panel: ramp(0.4, 1.6),
            goalsOpacity: ramp(2.0, 3.2) * (1 - ramp(13.2, 14.2)),
            boardOpacity: ramp(14.0, 15.2) * (1 - ramp(29.2, 30.2)),
            timelineOpacity: ramp(30.0, 31.2) * (1 - ramp(41.2, 42.2)),
            processOpacity: ramp(42.0, 43.2) * (1 - ramp(51.4, 52.6)),
            adoption: ramp(6.5, 9.5),
            goalType: ramp(2.8, 4.6),
            contributingReveal: ramp(4.8, 8.5),
            atRiskFlash: pulse(9.5, 10.5, 12.5),
            cardDrag: max(ramp(18.5, 22.0), ramp(22.5, 26.0)),
            cardColumn: cardColumn,
            sprintPulse: pulse(15.8, 16.8, 18.5),
            todayLine: ramp(31.5, 34.0),
            betaPopover: ramp(35.5, 37.5) * (1 - ramp(40.0, 41.2)),
            barFill: ramp(32.0, 38.5),
            processChecks: processChecks,
            goalsSearch: ramp(46.8, 48.2) * (1 - ramp(50.8, 51.8)),
            searchTyped: ramp(48.0, 50.0),
            opsTag: ramp(49.0, 50.2) * (1 - ramp(51.5, 52.4)),
            ready: ramp(52.5, 54.5),
            marquee: max(
                pulse(3.0, 4.2, 6.0),
                pulse(16.0, 17.2, 19.0),
                pulse(32.0, 33.2, 35.0),
                pulse(44.0, 45.2, 47.0)
            ),
            chip: chip,
            tag: tag,
            action: action,
            focus: focus,
            cursorX: lerp(prev.0, cxcy.0, move),
            cursorY: lerp(prev.1, cxcy.1, move),
            click: click,
            camScale: camScale,
            camX: camX,
            camY: camY
        )
    }
}

// MARK: - Session

struct StoryLabEditorPMSession: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var clock = StoryLabPMClock()
    @State private var showControls = false

    private var scene: StoryLabPMScene { .at(clock.t) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.08).ignoresSafeArea()
                gridOverlay.opacity(0.55)

                jiraWorld(in: geo.size)
                    .scaleEffect(scene.camScale)
                    .offset(x: scene.camX, y: scene.camY)
                    .opacity(scene.panel)
                    .allowsHitTesting(false)

                if scene.marquee > 0.02 {
                    marqueeFrame(in: geo.size).opacity(scene.marquee)
                }

                if let chip = scene.chip {
                    propertyChip(chip)
                }
                if let tag = scene.tag {
                    editorTag(tag)
                }
                if let action = scene.action {
                    actionChip(action)
                }

                if scene.ready > 0.05 {
                    readyBanner.opacity(scene.ready)
                }

                cursorLayer(in: geo.size)

                VStack {
                    HStack {
                        closeButton
                        Spacer()
                        Text(String(format: "%.0fs", clock.t))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                        Button {
                            showControls.toggle()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    Spacer()
                }

                if showControls {
                    controlsOverlay
                }
            }
        }
        .statusBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { clock.start() }
        .onDisappear { clock.stop() }
        .onTapGesture(count: 2) { clock.toggle() }
    }

    // MARK: World

    private func jiraWorld(in size: CGSize) -> some View {
        let cardW = min(size.width - 28, 520)
        let cardH = min(size.height * 0.78, 640)
        return ZStack {
            if scene.goalsOpacity > 0.02 {
                goalsPanel
                    .frame(width: cardW, height: cardH)
                    .opacity(scene.goalsOpacity)
                    .scaleEffect(0.96 + 0.04 * scene.goalsOpacity)
            }
            if scene.boardOpacity > 0.02 {
                boardPanel
                    .frame(width: cardW, height: cardH)
                    .opacity(scene.boardOpacity)
                    .scaleEffect(0.96 + 0.04 * scene.boardOpacity)
            }
            if scene.timelineOpacity > 0.02 {
                timelinePanel
                    .frame(width: cardW, height: cardH * 0.72)
                    .opacity(scene.timelineOpacity)
                    .scaleEffect(0.96 + 0.04 * scene.timelineOpacity)
            }
            if scene.processOpacity > 0.02 {
                processPanel
                    .frame(width: cardW, height: cardH * 0.78)
                    .opacity(scene.processOpacity)
                    .scaleEffect(0.96 + 0.04 * scene.processOpacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: Color(red: 0.1, green: 0.25, blue: 0.75).opacity(0.35), radius: 18, y: 10)
    }

    // MARK: Goals

    private var goalsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            jiraTopBar(title: "Ship Taika TestFlight", badge: "On track 0.8")
            HStack(spacing: 14) {
                Text("About").foregroundStyle(Color(white: 0.45))
                Text("Updates").foregroundStyle(Color(white: 0.45))
                Text("Work")
                    .foregroundStyle(Color(red: 0.05, green: 0.40, blue: 0.85))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color(red: 0.05, green: 0.40, blue: 0.85)).frame(height: 2).offset(y: 6)
                    }
                Text("Risks").foregroundStyle(Color(white: 0.45))
                Spacer()
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Contributing work")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(white: 0.12))
                        .opacity(Double(scene.contributingReveal))

                    statusSummaryBar
                        .opacity(Double(scene.contributingReveal))

                    contributingRow(
                        "Sphere hub carousel · Main",
                        status: .onTrack,
                        owner: "VS"
                    )
                    .opacity(Double(min(1, scene.contributingReveal * 1.4)))

                    contributingRow(
                        "Launch curriculum traffic light",
                        status: scene.atRiskFlash > 0.2 ? .atRisk : .onTrack,
                        owner: "VS"
                    )
                    .opacity(Double(min(1, scene.contributingReveal * 1.1)))
                    .scaleEffect(1 + 0.02 * scene.atRiskFlash)

                    contributingRow(
                        "Speaker word-level contract",
                        status: .onTrack,
                        owner: "AI"
                    )
                    .opacity(Double(min(1, scene.contributingReveal * 0.9)))

                    nestedWorkItems
                        .opacity(Double(max(0, scene.contributingReveal - 0.35) / 0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                goalsSidebar
                    .frame(width: 148)
                    .opacity(Double(scene.adoption))
            }
            .padding(14)

            Spacer(minLength: 0)
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var statusSummaryBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("3 Projects").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(white: 0.35))
                Spacer()
                Text("2 On track · 1 At risk")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.4))
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.9))
                    HStack(spacing: 0) {
                        Capsule().fill(Color(red: 0.12, green: 0.62, blue: 0.38)).frame(width: g.size.width * 0.62)
                        Capsule().fill(Color(red: 0.95, green: 0.62, blue: 0.12)).frame(width: g.size.width * 0.28)
                    }
                }
            }
            .frame(height: 6)
        }
    }

    private enum PMStatus { case onTrack, atRisk, inProgress, done, planning, audit }

    private func contributingRow(_ title: String, status: PMStatus, owner: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.9))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(white: 0.15))
                .lineLimit(1)
            Spacer(minLength: 4)
            statusPill(status)
            avatar(owner)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.97)))
    }

    private var nestedWorkItems: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Work items without a project")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(white: 0.4))
            contributingRow("Story Lab · PM behind-the-scenes", status: .inProgress, owner: "VS")
            contributingRow("Dictionary page deep-link from Main", status: .inProgress, owner: "AI")
        }
        .padding(.leading, 8)
    }

    private var goalsSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Customer adoption")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(white: 0.4))
            Text("\(Int(round(75 * scene.adoption)))%")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(white: 0.1))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.88))
                    Capsule()
                        .fill(Color(white: 0.12))
                        .frame(width: g.size.width * 0.75 * scene.adoption)
                }
            }
            .frame(height: 8)

            Divider().padding(.vertical, 4)

            labeledMeta("Owner", "Viktor S.")
            labeledMeta("Type", "Objective")
            labeledMeta("Focus", "Taika launch")

            Text("Sub-goals (2)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(white: 0.35))
                .padding(.top, 4)
            subGoal("First-entry onboarding complete")
            subGoal("Speaker hub wow on Main")
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.97)))
    }

    private func labeledMeta(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(white: 0.45))
            Text(v).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(white: 0.15))
        }
    }

    private func subGoal(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "target")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.62, blue: 0.38))
            Text(t)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(white: 0.2))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Board

    private var boardPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Board")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(white: 0.1))
                Spacer()
                HStack(spacing: -6) {
                    avatar("VS"); avatar("AI"); avatar("PM")
                    Text("+2")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(white: 0.4))
                        .padding(5)
                        .background(Circle().fill(Color(white: 0.9)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            HStack {
                Image(systemName: "bolt.fill").foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.12))
                Text("4 days remaining")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
                Spacer()
                Text("Complete sprint")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(red: 0.05, green: 0.40, blue: 0.85)))
                    .scaleEffect(1 + 0.04 * scene.sprintPulse)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            HStack(alignment: .top, spacing: 8) {
                boardColumn("TO DO", count: scene.cardColumn == 0 ? 3 : 2, index: 0)
                boardColumn("IN PROGRESS", count: scene.cardColumn == 1 ? 3 : 2, index: 1)
                boardColumn("IN REVIEW", count: scene.cardColumn == 2 ? 2 : 1, index: 2)
                boardColumn("DONE", count: scene.cardColumn == 3 ? 3 : 2, index: 3)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)

            Spacer(minLength: 0)
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(white: 0.94)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func boardColumn(_ title: String, count: Int, index: Int) -> some View {
        let heroHere = scene.cardColumn == index
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(white: 0.4))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(white: 0.55))
            }
            if heroHere {
                heroCard
                    .offset(y: -4 * scene.cardDrag)
                    .scaleEffect(1 + 0.03 * scene.cardDrag)
                    .shadow(color: .black.opacity(0.12 * scene.cardDrag), radius: 8, y: 4)
            }
            boardCard("Hub atmosphere recolor", key: "TKA-118", points: "3")
                .opacity(heroHere ? 0.55 : 1)
            if index != 2 {
                boardCard(index == 3 ? "Dictionary deep-link" : "Onboarding v2 gate", key: "TKA-\(120 + index)", points: "5")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCard: some View {
        boardCard("Sphere hub carousel", key: "TKA-104", points: "8", highlight: true)
    }

    private func boardCard(_ title: String, key: String, points: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(white: 0.12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(highlight ? Color(red: 0.12, green: 0.62, blue: 0.38) : Color(red: 0.25, green: 0.55, blue: 0.95))
                    .frame(width: 10, height: 10)
                Text(key)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.4))
                Spacer()
                Text(points)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(white: 0.45))
                avatar("VS")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(highlight ? Color(red: 0.05, green: 0.40, blue: 0.85).opacity(0.45) : Color.clear, lineWidth: 1.2)
                )
        )
    }

    // MARK: Timeline

    private var timelinePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                Text("JUL").foregroundStyle(Color(white: 0.45))
                Text("AUG")
                    .foregroundStyle(Color(white: 0.1))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.88)))
                Text("SEP").foregroundStyle(Color(white: 0.45))
                Spacer()
            }
            .font(.system(size: 11, weight: .bold))
            .padding(12)

            HStack(spacing: 8) {
                sprintChip("Sprint 1", active: false)
                sprintChip("Sprint 2", active: true)
                sprintChip("Sprint 3", active: false)
                Spacer()
            }
            .padding(.horizontal, 12)

            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    timelineRow("TKA-1", "App chrome · Main hub", Color(red: 0.12, green: 0.62, blue: 0.38), fill: 0.85 * scene.barFill)
                    timelineRow("TKA-2", "Speaker word contract", Color(red: 0.55, green: 0.35, blue: 0.9), fill: 0.7 * scene.barFill)
                    timelineRow("TKA-3", "Launch curriculum", Color(red: 0.05, green: 0.40, blue: 0.85), fill: 0.55 * scene.barFill)
                    timelineRow("TKA-4", "Story Lab Reels pack", Color(red: 0.95, green: 0.45, blue: 0.2), fill: 0.4 * scene.barFill)
                }
                .padding(12)

                // Today line
                Rectangle()
                    .fill(Color(red: 0.95, green: 0.45, blue: 0.12))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .offset(x: 210 * scene.todayLine)
                    .opacity(Double(scene.todayLine))

                if scene.betaPopover > 0.05 {
                    betaPopoverView
                        .opacity(Double(scene.betaPopover))
                        .scaleEffect(0.9 + 0.1 * scene.betaPopover)
                        .offset(x: 150, y: 36)
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                releaseDot("Beta 1.0")
                Spacer()
                releaseDot("Beta 2.0")
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 12)
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sprintChip(_ t: String, active: Bool) -> some View {
        Text(t)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(active ? Color(red: 0.05, green: 0.40, blue: 0.85) : Color(white: 0.45))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(active ? Color(red: 0.05, green: 0.40, blue: 0.85).opacity(0.12) : Color(white: 0.92))
            )
    }

    private func timelineRow(_ key: String, _ title: String, _ color: Color, fill: CGFloat) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.9))
            VStack(alignment: .leading, spacing: 2) {
                Text(key).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color(white: 0.4))
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.15)).lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.92))
                    Capsule()
                        .fill(color)
                        .frame(width: max(12, g.size.width * min(1, max(0.12, fill))))
                }
            }
            .frame(height: 14)
        }
    }

    private var betaPopoverView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shippingbox.fill")
                Text("Beta 1.0").font(.system(size: 13, weight: .bold))
                Spacer()
                Text("UNRELEASED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 0.05, green: 0.40, blue: 0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.05, green: 0.40, blue: 0.85), lineWidth: 1))
            }
            .foregroundStyle(Color(white: 0.12))
            GeometryReader { g in
                HStack(spacing: 0) {
                    Rectangle().fill(Color(red: 0.05, green: 0.40, blue: 0.85)).frame(width: g.size.width * 0.4)
                    Rectangle().fill(Color(red: 0.12, green: 0.62, blue: 0.38)).frame(width: g.size.width * 0.25)
                    Rectangle().fill(Color(white: 0.85))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            Text("Core loop · Main hub · Speaker")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(white: 0.35))
            Text("2026/09/16")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.4))
        }
        .padding(12)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        )
    }

    private func releaseDot(_ t: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color(red: 0.05, green: 0.40, blue: 0.85)).frame(width: 10, height: 10)
            Text(t).font(.system(size: 10, weight: .bold)).foregroundStyle(Color(white: 0.3))
        }
    }

    // MARK: Process

    private var processPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Process improvement plan")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(white: 0.1))
                Spacer()
                HStack(spacing: -6) {
                    avatar("VS"); avatar("AI"); avatar("PM"); avatar("UX")
                    Text("+3")
                        .font(.system(size: 9, weight: .bold))
                        .padding(5)
                        .background(Circle().fill(Color(white: 0.9)))
                        .foregroundStyle(Color(white: 0.4))
                }
            }
            .padding(14)

            processHeaderRow
            ForEach(Array(processRows.enumerated()), id: \.offset) { idx, row in
                processRow(
                    title: row.0,
                    status: idx < scene.processChecks ? (idx == 3 ? .audit : .planning) : .planning,
                    checked: idx < scene.processChecks,
                    assignee: row.1
                )
                .opacity(idx < scene.processChecks ? 1 : 0.45)
            }

            Spacer(minLength: 0)

            if scene.goalsSearch > 0.05 {
                goalsSearchPopover
                    .opacity(Double(scene.goalsSearch))
                    .offset(y: (1 - scene.goalsSearch) * 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if scene.opsTag > 0.05 {
                Text("@ Operations")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.55, green: 0.35, blue: 0.9)))
                    .opacity(Double(scene.opsTag))
                    .padding(18)
            }
        }
    }

    private var processRows: [(String, String)] {
        [
            ("Curriculum traffic-light audit", "VS"),
            ("Main hub sphere coverflow", "AI"),
            ("Atmosphere recolor by mode", "AI"),
            ("Process mapping · funnel", "PM"),
            ("Value stream · retention", "PM"),
            ("Solutions plan · TestFlight", "VS"),
            ("Risk assessment · API deploy", "AI")
        ]
    }

    private var processHeaderRow: some View {
        HStack {
            Text("Summary").frame(maxWidth: .infinity, alignment: .leading)
            Text("Status").frame(width: 88, alignment: .leading)
            Text("Goal").frame(width: 64, alignment: .leading)
            Text("Assignee").frame(width: 72, alignment: .leading)
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(Color(white: 0.4))
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func processRow(title: String, status: PMStatus, checked: Bool, assignee: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .foregroundStyle(checked ? Color(red: 0.05, green: 0.40, blue: 0.85) : Color(white: 0.55))
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(white: 0.15))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            statusPill(status)
                .frame(width: 88, alignment: .leading)
            HStack(spacing: 4) {
                Image(systemName: "target").font(.system(size: 9)).foregroundStyle(Color(red: 0.12, green: 0.62, blue: 0.38))
                Text("Launch").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.3))
            }
            .frame(width: 64, alignment: .leading)
            HStack(spacing: 4) {
                avatar(assignee)
                Text(assignee).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(white: 0.3))
            }
            .frame(width: 72, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private var goalsSearchPopover: some View {
        let typed = "Launch"
        let shown = String(typed.prefix(max(0, Int(ceil(Double(typed.count) * Double(scene.searchTyped))))))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Color(white: 0.45))
                Text(shown.isEmpty ? "Find goals" : shown)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(shown.isEmpty ? Color(white: 0.55) : Color(white: 0.12))
                Spacer()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.05, green: 0.40, blue: 0.85), lineWidth: 1.5))

            Text("RECENTLY VIEWED")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(white: 0.45))
            goalSearchItem("Ship Taika TestFlight", Color(red: 0.12, green: 0.62, blue: 0.38))
            goalSearchItem("First-entry onboarding complete", Color(red: 0.12, green: 0.62, blue: 0.38))
            goalSearchItem("Increase retention 10×", Color(red: 0.95, green: 0.55, blue: 0.15))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
        )
    }

    private func goalSearchItem(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "target").foregroundStyle(c).font(.system(size: 11, weight: .bold))
            Text(t).font(.system(size: 11, weight: .medium)).foregroundStyle(Color(white: 0.15))
        }
    }

    // MARK: Shared chrome

    private func jiraTopBar(title: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Goals /")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
                Spacer()
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.08, green: 0.45, blue: 0.28))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(red: 0.12, green: 0.62, blue: 0.38).opacity(0.18)))
            }
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(red: 0.12, green: 0.62, blue: 0.38)))
                Text(String(title.prefix(max(1, Int(ceil(Double(title.count) * Double(max(0.15, scene.goalType))))))))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(white: 0.1))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private func statusPill(_ s: PMStatus) -> some View {
        let (text, fg, bg): (String, Color, Color) = {
            switch s {
            case .onTrack: return ("ON TRACK", Color(red: 0.08, green: 0.45, blue: 0.28), Color(red: 0.12, green: 0.62, blue: 0.38).opacity(0.18))
            case .atRisk: return ("AT RISK", Color(red: 0.55, green: 0.35, blue: 0.05), Color(red: 0.95, green: 0.62, blue: 0.12).opacity(0.22))
            case .inProgress: return ("IN PROGRESS", Color(red: 0.05, green: 0.30, blue: 0.65), Color(red: 0.05, green: 0.40, blue: 0.85).opacity(0.16))
            case .done: return ("DONE", Color(red: 0.08, green: 0.45, blue: 0.28), Color(red: 0.12, green: 0.62, blue: 0.38).opacity(0.18))
            case .planning: return ("PLANNING", Color(red: 0.05, green: 0.30, blue: 0.65), Color(red: 0.05, green: 0.40, blue: 0.85).opacity(0.14))
            case .audit: return ("AUDIT", Color(white: 0.35), Color(white: 0.9))
            }
        }()
        return Text(text)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(bg))
    }

    private func avatar(_ initials: String) -> some View {
        let colors: [Color] = [
            Color(red: 0.90, green: 0.35, blue: 0.25),
            Color(red: 0.10, green: 0.55, blue: 0.95),
            Color(red: 0.10, green: 0.72, blue: 0.45),
            Color(red: 0.75, green: 0.35, blue: 0.85)
        ]
        let idx = abs(initials.hashValue) % colors.count
        return Text(initials)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(colors[idx]))
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
            ctx.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.6)
        }
        .ignoresSafeArea()
    }

    private func marqueeFrame(in size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(Color.cyan.opacity(0.75), style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
            .frame(width: size.width * 0.88, height: size.height * 0.72)
            .position(x: size.width * 0.5, y: size.height * 0.48)
    }

    private func propertyChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.15, green: 0.35, blue: 0.55).opacity(0.92))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 56)
            .padding(.trailing, 14)
    }

    private func editorTag(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color.cyan).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 56)
        .padding(.leading, 14)
    }

    private func actionChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.72)).overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 110)
    }

    private var readyBanner: some View {
        Text("READY FOR REELS · PM")
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color(red: 0.12, green: 0.62, blue: 0.38).opacity(0.92)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 130)
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
        .allowsHitTesting(false)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private var controlsOverlay: some View {
        VStack(spacing: 12) {
            HStack {
                Button { clock.toggle() } label: {
                    Image(systemName: clock.isPlaying ? "pause.fill" : "play.fill")
                }
                Button { clock.restart() } label: {
                    Image(systemName: "backward.end.fill")
                }
                Slider(value: Binding(get: { clock.t }, set: { clock.scrub($0) }), in: 0...clock.duration)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.78)))
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 36)
    }
}

#endif
