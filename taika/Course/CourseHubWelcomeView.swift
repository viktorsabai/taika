// Course Hub Welcome — Taika identity reminder:
// Full-bleed dark surface, existing pink accent tokens, compact Main-style cards,
// restrained onboarding waveform, and a controlled product demo instead of decoration.
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
    @State private var activeDemo: CourseHubDemoAction?
    @State private var autoplayTask: Task<Void, Never>?

    private let cards: [CourseHubWelcomeCard] = [
        .init(id: "base", eyebrow: "БАЗА", title: "Разговорный старт", meta: "7 уроков · 12 минут", icon: "bubble.left.and.bubble.right.fill", courseId: "course_b_1", tintLevel: 0.98),
        .init(id: "taxi", eyebrow: "ЖИЗНЬ", title: "Такси без паники", meta: "7 уроков · 15 минут", icon: "car.fill", courseId: "course_l_2", tintLevel: 0.86),
        .init(id: "market", eyebrow: "ЖИЗНЬ", title: "Рынок и покупки", meta: "7 уроков · 14 минут", icon: "bag.fill", courseId: "course_l_3", tintLevel: 0.76),
        .init(id: "doctor", eyebrow: "ЖИЗНЬ", title: "У врача", meta: "7 уроков · 16 минут", icon: "cross.case.fill", courseId: "course_l_5", tintLevel: 0.68)
    ]

    private var visibleCards: [CourseHubWelcomeCard] {
        guard !cards.isEmpty else { return [] }
        return (-1...1).map { offset in
            cards[(activeIndex + offset + cards.count) % cards.count]
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CourseHubSignalBackdrop(
                tint: theme.currentAccentTintColor,
                active: appeared && !reduceMotion
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                logoBar
                intro
                    .padding(.top, 24)
                carousel
                    .padding(.top, 20)
                demoRail
                    .padding(.top, 12)
                libraryLine
                    .padding(.top, 14)
                Spacer(minLength: 18)
                actions
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) { appeared = true }
            startAutoplay()
        }
        .onDisappear { autoplayTask?.cancel() }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > 44 else { return }
                    moveCard(by: value.translation.width < 0 ? 1 : -1)
                    startAutoplay()
                }
        )
    }

    private var logoBar: some View {
        HStack {
            HStack(spacing: 0) {
                Text("tai")
                    .font(.custom("ONMARK Trial", size: 31))
                    .foregroundStyle(.white.opacity(0.94))
                Text("kAAA")
                    .font(.custom("ONMARK Trial", size: 31))
                    .fontWeight(.bold)
                    .foregroundStyle(theme.currentAccentFill)
            }
            .accessibilityLabel("Taika")
            Spacer()
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
        .frame(maxWidth: .infinity)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Кун Кру собрала для тебя")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text("тайский для жизни")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.currentAccentFill)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("Открой курс, сохрани фразу, закрепи её в игре или скажи в Спикере.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var carousel: some View {
        GeometryReader { proxy in
            let activeWidth = min(204, proxy.size.width * 0.57)
            let sideWidth = min(116, proxy.size.width * 0.30)
            let sideOffset = max(0, proxy.size.width * 0.36)

            ZStack {
                ForEach(Array(visibleCards.enumerated()), id: \.offset) { index, card in
                    let isActive = index == 1
                    CourseHubCardView(
                        card: card,
                        isActive: isActive,
                        tint: theme.currentAccentTintColor
                    )
                    .frame(width: isActive ? activeWidth : sideWidth, height: isActive ? 204 : 172)
                    .scaleEffect(isActive ? 1 : 0.94)
                    .opacity(isActive ? 1 : 0.5)
                    .offset(x: isActive ? 0 : (index == 0 ? -sideOffset : sideOffset))
                    .zIndex(isActive ? 2 : 1)
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onTapGesture {
                        guard !isActive else { return }
                        moveCard(by: index == 0 ? -1 : 1)
                        startAutoplay()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.48, dampingFraction: 0.86), value: activeIndex)
        }
        .frame(height: 208)
    }

    private var demoRail: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                CourseHubDemoButton(
                    title: isFavorite ? "Сохранено" : "Сохранить",
                    icon: isFavorite ? "bookmark.fill" : "bookmark",
                    isActive: isFavorite
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        isFavorite.toggle()
                        activeDemo = .favorite
                    }
                    pauseAutoplay()
                }
                CourseHubDemoButton(title: "Игры", icon: "rectangle.grid.2x2.fill", isActive: activeDemo == .games) {
                    activeDemo = .games
                    pauseAutoplay()
                }
                CourseHubDemoButton(title: "Спикер", icon: "waveform", isActive: activeDemo == .speaker) {
                    activeDemo = .speaker
                    pauseAutoplay()
                }
            }
            .frame(maxWidth: .infinity)

            if let activeDemo {
                CourseHubDemoFeedback(action: activeDemo, tint: theme.currentAccentTintColor) {
                    withAnimation(.easeOut(duration: 0.2)) { self.activeDemo = nil }
                    startAutoplay()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: activeDemo)
    }

    private var libraryLine: some View {
        Text("15 курсов  ·  100+ жизненных ситуаций  ·  короткие уроки")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.48))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.76)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onStart) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                    Text("Начать с самого нужного")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.currentAccentFill.opacity(0.92))
                        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
                )
            }
            .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.98))

            Button("Посмотреть все курсы", action: onBrowse)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .buttonStyle(.plain)
        }
    }

    private func moveCard(by offset: Int) {
        guard !cards.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        activeIndex = (activeIndex + offset + cards.count) % cards.count
    }

    private func pauseAutoplay() {
        autoplayTask?.cancel()
        autoplayTask = nil
    }

    private func startAutoplay() {
        autoplayTask?.cancel()
        guard !reduceMotion, activeDemo == nil else { return }
        autoplayTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            moveCard(by: 1)
            startAutoplay()
        }
    }
}

private struct CourseHubWelcomeCard: Identifiable {
    let id: String
    let eyebrow: String
    let title: String
    let meta: String
    let icon: String
    let courseId: String
    let tintLevel: Double
}

private struct CourseHubCardView: View {
    let card: CourseHubWelcomeCard
    let isActive: Bool
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(card.eyebrow)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.7)
                Spacer(minLength: 4)
                Image(systemName: card.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.black.opacity(0.2)))
            }
            .foregroundStyle(.white.opacity(0.82))

            Spacer(minLength: 12)

            Text(card.title)
                .font(.system(size: isActive ? 21 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)

            Spacer(minLength: 10)

            Text(card.meta)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
                .lineLimit(1)
        }
        .padding(isActive ? 16 : 12)
        .background(
            LinearGradient(
                colors: [
                    tint.opacity(card.tintLevel),
                    tint.opacity(max(0.22, card.tintLevel - 0.34))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(isActive ? 0.28 : 0.14), lineWidth: 1)
        )
        .shadow(color: tint.opacity(isActive ? 0.22 : 0.08), radius: isActive ? 16 : 8, y: 6)
    }
}

private enum CourseHubDemoAction: Equatable {
    case favorite
    case games
    case speaker
}

private struct CourseHubDemoButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isActive ? .white : .white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? .white.opacity(0.16) : .white.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CourseHubDemoFeedback: View {
    let action: CourseHubDemoAction
    let tint: Color
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Group {
                switch action {
                case .favorite:
                    Image(systemName: "bookmark.fill")
                case .games:
                    Image(systemName: "sparkles.rectangle.stack.fill")
                case .speaker:
                    Image(systemName: "waveform")
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(2)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 1))
        )
    }

    private var message: String {
        switch action {
        case .favorite: return "Сохранила курс — вернёшься к нему позже."
        case .games: return "Закрепи фразы в играх и оставь их в памяти."
        case .speaker: return "Скажи фразу — Спикер разберёт произношение."
        }
    }
}

private struct CourseHubSignalBackdrop: View {
    let tint: Color
    let active: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                var path = Path()
                let time = active ? CGFloat(timeline.date.timeIntervalSinceReferenceDate) : 0
                let mid = size.height * 0.63
                let amp = min(size.height * 0.025, 18)
                path.move(to: CGPoint(x: 0, y: mid))
                for x in stride(from: CGFloat(0), through: size.width, by: 4) {
                    let t = x / max(size.width, 1)
                    let carrier = sin(t * .pi * 4 + time * 1.1)
                    let shimmer = sin(t * .pi * 9 - time * 0.8) * 0.12
                    path.addLine(to: CGPoint(x: x, y: mid + (carrier + shimmer) * amp * (0.42 + 0.58 * sin(t * .pi))))
                }
                context.stroke(path, with: .color(tint.opacity(0.5)), lineWidth: 1.3)
                context.stroke(path, with: .color(tint.opacity(0.10)), lineWidth: 5)
            }
        }
    }
}
