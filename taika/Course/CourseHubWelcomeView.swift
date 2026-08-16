// Course Hub Welcome — Taika identity reminder:
// Reuse the Main/Favorites course-card grammar: compact surface card, existing icon actions,
// dark safe-area layout, and a barely visible onboarding signal only in the background.
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
    @State private var demoMessage: CourseHubDemoAction?
    @State private var autoplayTask: Task<Void, Never>?

    private let cards: [CourseHubWelcomeCard] = [
        .init(id: "base", eyebrow: "БАЗА", title: "Разговорный старт", meta: "7 уроков · 12 минут", icon: "bubble.left.and.bubble.right.fill", courseId: "course_b_1"),
        .init(id: "taxi", eyebrow: "ЖИЗНЬ", title: "Такси без паники", meta: "7 уроков · 15 минут", icon: "car.fill", courseId: "course_l_2"),
        .init(id: "market", eyebrow: "ЖИЗНЬ", title: "Рынок и покупки", meta: "7 уроков · 14 минут", icon: "bag.fill", courseId: "course_l_3"),
        .init(id: "doctor", eyebrow: "ЖИЗНЬ", title: "У врача", meta: "7 уроков · 16 минут", icon: "cross.case.fill", courseId: "course_l_5")
    ]

    private var visibleCards: [CourseHubWelcomeCard] {
        (-1...1).map { offset in cards[(activeIndex + offset + cards.count) % cards.count] }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CourseHubSignalBackdrop(tint: theme.currentAccentTintColor, active: appeared && !reduceMotion)
                .ignoresSafeArea()
                .opacity(0.24)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                logoBar
                intro
                    .padding(.top, 18)
                carousel
                    .padding(.top, 18)
                libraryLine
                    .padding(.top, 12)
                if let demoMessage {
                    CourseHubDemoFeedback(action: demoMessage, tint: theme.currentAccentTintColor) {
                        withAnimation(.easeOut(duration: 0.18)) { self.demoMessage = nil }
                        startAutoplay()
                    }
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                Spacer(minLength: 18)
                actions
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.88)) { appeared = true }
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
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("тайский для жизни")
                .font(.system(size: 29, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.currentAccentFill)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("Открой курс, сохрани фразу, закрепи её в игре или скажи в Спикере.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var carousel: some View {
        GeometryReader { proxy in
            let sideWidth = min(118, proxy.size.width * 0.31)
            let activeWidth = min(216, proxy.size.width * 0.60)
            let sideOffset = min(126, proxy.size.width * 0.35)

            ZStack {
                ForEach(Array(visibleCards.enumerated()), id: \.offset) { index, card in
                    let isActive = index == 1
                    CourseHubCardView(
                        card: card,
                        isActive: isActive,
                        tint: theme.currentAccentTintColor,
                        isFavorite: isFavorite && isActive,
                        onOpen: { showDemo(.course) },
                        onFavorite: {
                            guard isActive else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { isFavorite.toggle() }
                            showDemo(.favorite)
                        },
                        onGames: {
                            guard isActive else { return }
                            showDemo(.games)
                        },
                        onSpeaker: {
                            guard isActive else { return }
                            showDemo(.speaker)
                        }
                    )
                    .frame(width: isActive ? activeWidth : sideWidth, height: isActive ? 222 : 174)
                    .scaleEffect(isActive ? 1 : 0.92)
                    .opacity(isActive ? 1 : 0.52)
                    .offset(x: isActive ? 0 : (index == 0 ? -sideOffset : sideOffset))
                    .zIndex(isActive ? 2 : 1)
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onTapGesture {
                        guard !isActive else { return }
                        moveCard(by: index == 0 ? -1 : 1)
                        startAutoplay()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.46, dampingFraction: 0.86), value: activeIndex)
        }
        .frame(height: 226)
    }

    private var libraryLine: some View {
        Text("15 курсов  ·  100+ жизненных ситуаций  ·  короткие уроки")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.46))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
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
                .foregroundStyle(.white)
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

    private func moveCard(by offset: Int) {
        guard !cards.isEmpty else { return }
        if offset != 0 { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        activeIndex = (activeIndex + offset + cards.count) % cards.count
    }

    private func showDemo(_ action: CourseHubDemoAction) {
        pauseAutoplay()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { demoMessage = action }
    }

    private func pauseAutoplay() {
        autoplayTask?.cancel()
        autoplayTask = nil
    }

    private func startAutoplay() {
        autoplayTask?.cancel()
        guard !reduceMotion, demoMessage == nil else { return }
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
}

private struct CourseHubCardView: View {
    let card: CourseHubWelcomeCard
    let isActive: Bool
    let tint: Color
    let isFavorite: Bool
    let onOpen: () -> Void
    let onFavorite: () -> Void
    let onGames: () -> Void
    let onSpeaker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(card.eyebrow)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.7)
                Spacer(minLength: 4)
                Image(systemName: card.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(PD.ColorToken.chip))
            }

            Spacer(minLength: 11)

            Text(card.title)
                .font(.system(size: isActive ? 21 : 15, weight: .bold, design: .rounded))
                .foregroundStyle(PD.ColorToken.text)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            Text(card.meta)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(1)

            if isActive {
                Divider()
                    .overlay(Theme.Strokes.strokeSubtle)
                    .padding(.vertical, 8)
                HStack(spacing: 7) {
                    CourseHubIconButton(systemName: "play.fill", tint: tint, label: "Открыть", action: onOpen)
                    CourseHubIconButton(systemName: isFavorite ? "heart.fill" : "heart", tint: tint, label: "Сохранить", action: onFavorite, isActive: isFavorite)
                    CourseHubIconButton(systemName: "rectangle.grid.2x2.fill", tint: tint, label: "Игры", action: onGames)
                    CourseHubIconButton(systemName: "waveform", tint: tint, label: "Спикер", action: onSpeaker)
                }
            }
        }
        .padding(isActive ? 16 : 11)
        .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: 20, style: .continuous)))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isActive ? tint.opacity(0.48) : Theme.Strokes.strokeSubtle, lineWidth: isActive ? 1.2 : Theme.Strokes.strokeLineWidth)
        )
        .shadow(color: isActive ? tint.opacity(0.16) : .clear, radius: 14, y: 6)
    }
}

private struct CourseHubIconButton: View {
    let systemName: String
    let tint: Color
    let label: String
    let action: () -> Void
    var isActive: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? tint : PD.ColorToken.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(isActive ? tint.opacity(0.16) : PD.ColorToken.chip))
                .overlay(Circle().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
        }
        .buttonStyle(PressDownStyle(scale: 0.9, fade: 0.92))
        .accessibilityLabel(label)
    }
}

private enum CourseHubDemoAction: Equatable {
    case course
    case favorite
    case games
    case speaker
}

private struct CourseHubDemoFeedback: View {
    let action: CourseHubDemoAction
    let tint: Color
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.06)))
        .overlay(Capsule().stroke(tint.opacity(0.20), lineWidth: 1))
    }

    private var icon: String {
        switch action {
        case .course: return "play.fill"
        case .favorite: return "heart.fill"
        case .games: return "rectangle.grid.2x2.fill"
        case .speaker: return "waveform"
        }
    }

    private var message: String {
        switch action {
        case .course: return "Открой курс и начни с первой полезной ситуации."
        case .favorite: return "Сохранила — вернёшься к курсу позже."
        case .games: return "Фразы можно закрепить в играх."
        case .speaker: return "Скажи фразу — Спикер разберёт её."
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
                let mid = size.height * 0.72
                let amp = min(size.height * 0.018, 12)
                path.move(to: CGPoint(x: 0, y: mid))
                for x in stride(from: CGFloat(0), through: size.width, by: 5) {
                    let t = x / max(size.width, 1)
                    let y = mid + sin(t * .pi * 3.2 + time * 0.8) * amp * sin(t * .pi)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(path, with: .color(tint.opacity(0.16)), lineWidth: 1.1)
            }
        }
    }
}
