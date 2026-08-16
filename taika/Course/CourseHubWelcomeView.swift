// Course Hub Welcome — first-entry product demo:
// real CourseLessonCard grammar + sphere-style choreography (wave + icon beats),
// then a calm CTA into Course View. Not a static tip carousel.
import SwiftUI
import UIKit

struct CourseHubWelcomeView: View {
    let onStart: () -> Void
    let onBrowse: () -> Void
    let onDismiss: () -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var activeIndex = 0
    @State private var appeared = false
    @State private var isFavorite = false
    @State private var beat: CourseHubDemoBeat = .idle
    @State private var demoTask: Task<Void, Never>?
    @State private var userPausedUntil: Date?

    private let scenarios: [CourseHubScenario] = [
        .init(
            id: "base",
            category: "база",
            title: "Разговорный старт",
            subtitle: "Первые фразы, чтобы заговорить спокойно",
            lessons: 7,
            minutes: 12,
            courseId: "course_b_1"
        ),
        .init(
            id: "taxi",
            category: "жизнь",
            title: "Такси без паники",
            subtitle: "Куда, стой, сколько — и спокойный диалог",
            lessons: 7,
            minutes: 15,
            courseId: "course_l_2"
        ),
        .init(
            id: "market",
            category: "жизнь",
            title: "Рынок и покупки",
            subtitle: "Цена, торг, «беру» без стресса",
            lessons: 7,
            minutes: 14,
            courseId: "course_l_3"
        ),
        .init(
            id: "doctor",
            category: "жизнь",
            title: "У врача",
            subtitle: "Симптомы, аллергия, что болит",
            lessons: 7,
            minutes: 16,
            courseId: "course_l_5"
        )
    ]

    private var activeScenario: CourseHubScenario {
        scenarios[activeIndex % scenarios.count]
    }

    private var statusLine: String {
        switch beat {
        case .idle:
            return "Курсы на все сценарии — листай и смотри действия"
        case .play:
            return "Открыть курс — сразу в уроки"
        case .favorite:
            return "Сердце — сохранить курс в избранное"
        case .games:
            return "Игры — закрепить фразы после урока"
        case .speaker:
            return "Спикер — проговорить вслух и разобрать тоны"
        }
    }

    private var wavePace: TaikaTechWaveform.Pace {
        switch beat {
        case .idle: return .idle
        case .play, .favorite, .games: return .analyzing
        case .speaker: return .recording
        }
    }

    private var waveMeter: Double {
        switch beat {
        case .idle: return 0.32
        case .play: return 0.48
        case .favorite: return 0.55
        case .games: return 0.62
        case .speaker: return 0.88
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Sphere-energy: living brand wave behind the card.
            TaikaTechWaveform(meter: waveMeter, pace: wavePace, lineCount: 4)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .offset(y: 40)
                .opacity(appeared ? 0.55 : 0)
                .blur(radius: beat == .speaker ? 0.2 : 0.8)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.55), value: beat)

            VStack(spacing: 0) {
                logoBar
                intro
                    .padding(.top, 14)

                cardStage
                    .padding(.top, 10)

                Text(statusLine)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .frame(minHeight: 36, alignment: .top)
                    .contentTransition(.opacity)
                    .id(statusLine)
                    .padding(.top, 10)
                    .animation(.easeInOut(duration: 0.28), value: beat)

                Text("15 курсов  ·  100+ ситуаций  ·  короткие уроки")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.top, 6)

                Spacer(minLength: 12)

                actions
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) { appeared = true }
            restartDemoLoop()
        }
        .onDisappear { demoTask?.cancel() }
        .gesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    guard abs(value.translation.width) > 48 else { return }
                    advanceCard(by: value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private var logoBar: some View {
        HStack {
            HStack(spacing: 0) {
                Text("tai")
                    .font(.custom("ONMARK Trial", size: 30))
                    .foregroundStyle(.white.opacity(0.94))
                Text("kAAA")
                    .font(.custom("ONMARK Trial", size: 30))
                    .fontWeight(.bold)
                    .foregroundStyle(theme.currentAccentFill)
            }
            .accessibilityLabel("Taika")
            Spacer(minLength: 12)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Кун Кру собрала для тебя")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text("тайский для жизни")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.currentAccentFill)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("Это те же карточки курсов: открой, сохрани, закрепи в играх или скажи в Спикере.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardStage: some View {
        let cardW = CardDS.Metrics.courseWidth * 0.78
        let cardH = CardDS.Metrics.courseHeight * 0.78

        return ZStack {
            // Side peeks — proof of many scenarios.
            ForEach([-1, 1], id: \.self) { side in
                let idx = (activeIndex + side + scenarios.count) % scenarios.count
                courseCard(for: scenarios[idx], interactive: false)
                    .frame(width: cardW * 0.86, height: cardH * 0.86)
                    .scaleEffect(0.9)
                    .opacity(0.38)
                    .offset(x: CGFloat(side) * (cardW * 0.58))
                    .blur(radius: reduceMotion ? 0 : 0.6)
                    .allowsHitTesting(false)
            }

            courseCard(for: activeScenario, interactive: true)
                .frame(width: cardW, height: cardH)
                .scaleEffect(beat == .idle ? 1 : 1.015)
                .shadow(
                    color: theme.currentAccentTintColor.opacity(beat == .idle ? 0.12 : 0.28),
                    radius: beat == .speaker ? 28 : 18,
                    y: 10
                )
                .overlay(alignment: .bottom) {
                    if !reduceMotion {
                        beatGlow
                            .padding(.bottom, 22)
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.84), value: beat)
                .animation(.spring(response: 0.48, dampingFraction: 0.86), value: activeIndex)
                .zIndex(2)
                .id(activeScenario.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal: .opacity
                ))
        }
        .frame(height: cardH + 8)
        .frame(maxWidth: .infinity)
    }

    private var beatGlow: some View {
        // Soft accent halo under the real icon rail (play / heart / games / mic).
        HStack(spacing: 20) {
            glowDot(active: beat == .play)
            glowDot(active: beat == .favorite)
            glowDot(active: beat == .games)
            glowDot(active: beat == .speaker)
        }
        .allowsHitTesting(false)
    }

    private func glowDot(active: Bool) -> some View {
        Circle()
            .fill(theme.currentAccentTintColor.opacity(active ? 0.55 : 0))
            .frame(width: active ? 36 : 28, height: active ? 36 : 28)
            .blur(radius: active ? 8 : 0)
            .scaleEffect(active ? 1.15 : 0.7)
            .animation(.easeInOut(duration: 0.45), value: active)
    }

    @ViewBuilder
    private func courseCard(for scenario: CourseHubScenario, interactive: Bool) -> some View {
        CourseLessonCard(
            title: scenario.title,
            subtitle: scenario.subtitle,
            lessonsCount: scenario.lessons,
            durationText: "≈ \(scenario.minutes) мин",
            statusKind: .new,
            courseCategory: scenario.category,
            isPro: false,
            tags: [],
            size: CGSize(
                width: CardDS.Metrics.courseWidth * 0.78,
                height: CardDS.Metrics.courseHeight * 0.78
            ),
            sectionChrome: .none,
            primaryCTA: .start,
            scale: .xs,
            showFavorite: true,
            showConsole: true,
            onPrimaryTap: interactive ? { runUserBeat(.play) } : nil,
            isFavoriteActive: interactive ? isFavorite : false,
            isConsoleEnabled: true,
            completionFraction: 1,
            onFavoriteTap: interactive ? {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    isFavorite.toggle()
                }
                runUserBeat(.favorite)
            } : nil,
            onConsoleTap: interactive ? { runUserBeat(.games) } : nil,
            onSpeakerTap: interactive ? { runUserBeat(.speaker) } : nil,
            showsInlineProgress: false
        )
    }

    private var actions: some View {
        VStack(spacing: 9) {
            Button(action: onStart) {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                    Text("Начать с самого нужного")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule(style: .continuous).fill(theme.currentAccentFill))
            }
            .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.98))

            Button("Посмотреть все курсы", action: onBrowse)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .buttonStyle(.plain)
        }
    }

    // MARK: - Demo choreography (sphere DNA)

    private func advanceCard(by offset: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isFavorite = false
        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
            activeIndex = (activeIndex + offset + scenarios.count) % scenarios.count
            beat = .idle
        }
        restartDemoLoop(delay: 0.35)
    }

    private func runUserBeat(_ next: CourseHubDemoBeat) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        userPausedUntil = Date().addingTimeInterval(2.4)
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            beat = next
        }
        restartDemoLoop(delay: 2.5)
    }

    private func restartDemoLoop(delay: Double = 0.2) {
        demoTask?.cancel()
        guard !reduceMotion else {
            beat = .idle
            return
        }
        demoTask = Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            while !Task.isCancelled {
                if let until = userPausedUntil, Date() < until {
                    try? await Task.sleep(for: .milliseconds(200))
                    continue
                }
                await playBeatSequence()
                guard !Task.isCancelled else { return }
                // Next scenario — proof of breadth.
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    activeIndex = (activeIndex + 1) % scenarios.count
                    isFavorite = false
                    beat = .idle
                }
                try? await Task.sleep(for: .seconds(0.85))
            }
        }
    }

    @MainActor
    private func playBeatSequence() async {
        let steps: [(CourseHubDemoBeat, Double)] = [
            (.idle, 1.1),
            (.play, 1.05),
            (.favorite, 1.05),
            (.games, 1.05),
            (.speaker, 1.45)
        ]
        for (step, seconds) in steps {
            guard !Task.isCancelled else { return }
            if let until = userPausedUntil, Date() < until { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                beat = step
                if step == .favorite {
                    isFavorite = true
                }
            }
            if step == .play || step == .speaker {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
            try? await Task.sleep(for: .seconds(seconds))
        }
    }
}

private struct CourseHubScenario: Identifiable, Equatable {
    let id: String
    let category: String
    let title: String
    let subtitle: String
    let lessons: Int
    let minutes: Int
    let courseId: String
}

private enum CourseHubDemoBeat: Equatable {
    case idle
    case play
    case favorite
    case games
    case speaker
}
