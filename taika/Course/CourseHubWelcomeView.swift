// Course Hub Welcome — Taika identity reminder:
// Dark near-black surface, compact Main-style course cards, restrained pink/lilac signal wave,
// one clear CTA. This screen is a first-entry state, not a multi-step tutorial.
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
    @State private var autoplayTask: Task<Void, Never>?

    private let cards: [CourseHubWelcomeCard] = [
        .init(id: "base", eyebrow: "БАЗА", title: "Разговорный старт", meta: "7 уроков · 12 минут", icon: "bubble.left.and.bubble.right.fill", colors: [Color(red: 0.95, green: 0.34, blue: 0.68), Color(red: 0.67, green: 0.38, blue: 0.92)]), courseId: "course_b_1"),
        .init(id: "taxi", eyebrow: "ЖИЗНЬ", title: "Такси без паники", meta: "7 уроков · 15 минут", icon: "car.fill", colors: [Color(red: 0.94, green: 0.33, blue: 0.43), Color(red: 0.74, green: 0.28, blue: 0.48)], courseId: "course_l_2"),
        .init(id: "market", eyebrow: "ЖИЗНЬ", title: "Рынок и покупки", meta: "7 уроков · 14 минут", icon: "bag.fill", colors: [Color(red: 0.98, green: 0.47, blue: 0.27), Color(red: 0.75, green: 0.31, blue: 0.24)], courseId: "course_l_3"),
        .init(id: "doctor", eyebrow: "ЖИЗНЬ", title: "У врача", meta: "7 уроков · 16 минут", icon: "cross.case.fill", colors: [Color(red: 0.35, green: 0.62, blue: 0.94), Color(red: 0.37, green: 0.38, blue: 0.76)], courseId: "course_l_5")
    ]

    private var visibleCards: [CourseHubWelcomeCard] {
        guard !cards.isEmpty else { return [] }
        return (-1...1).map { offset in
            cards[(activeIndex + offset + cards.count) % cards.count]
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.985).ignoresSafeArea()
            CourseHubSignalBackdrop(active: appeared && !reduceMotion)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 22)
                intro
                Spacer(minLength: 24)
                carousel
                Spacer(minLength: 18)
                libraryLine
                Spacer(minLength: 24)
                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) { appeared = true }
            startAutoplay()
        }
        .onDisappear { autoplayTask?.cancel() }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > 44 else { return }
                    let direction = value.translation.width < 0 ? 1 : -1
                    moveCard(by: direction)
                    startAutoplay()
                }
        )
    }

    private var topBar: some View {
        HStack {
            Text("Taika")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.58))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Кун Кру собрала")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("тайский для твоей жизни")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.currentAccentFill)
            Text("Такси, рынок, кафе, врач, кондо и разговоры — выбирай ситуацию, которая нужна сегодня.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var carousel: some View {
        HStack(spacing: 12) {
            ForEach(Array(visibleCards.enumerated()), id: \.offset) { index, card in
                CourseHubCardView(card: card, isActive: index == 1)
                    .frame(width: index == 1 ? 210 : 150, height: index == 1 ? 238 : 194)
                    .scaleEffect(index == 1 ? 1 : 0.92)
                    .opacity(index == 1 ? 1 : 0.55)
                    .blur(radius: index == 1 || reduceMotion ? 0 : 0.4)
                    .zIndex(index == 1 ? 2 : 1)
                    .onTapGesture {
                        if index != 1 { moveCard(by: index == 0 ? -1 : 1) }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: activeIndex)
    }

    private var libraryLine: some View {
        Text("15 курсов  ·  100+ жизненных ситуаций  ·  короткие уроки")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.52))
            .multilineTextAlignment(.center)
    }

    private var actions: some View {
        VStack(spacing: 13) {
            Button(action: onStart) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                    Text("Начать с самого нужного")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.currentAccentFill.opacity(0.92))
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                )
            }
            .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.98))

            Button("Посмотреть все курсы", action: onBrowse)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .buttonStyle(.plain)
        }
    }

    private func moveCard(by offset: Int) {
        guard !cards.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        activeIndex = (activeIndex + offset + cards.count) % cards.count
    }

    private func startAutoplay() {
        autoplayTask?.cancel()
        guard !reduceMotion else { return }
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
    let colors: [Color]
    let courseId: String
}

private struct CourseHubCardView: View {
    let card: CourseHubWelcomeCard
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(card.eyebrow)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.7)
                Spacer()
                Image(systemName: card.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.black.opacity(0.22)))
            }
            .foregroundStyle(.white.opacity(0.83))

            Spacer(minLength: 14)

            Text(card.title)
                .font(.system(size: isActive ? 23 : 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Text(card.meta)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(isActive ? 18 : 15)
        .background(
            LinearGradient(colors: card.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(isActive ? 0.32 : 0.16), lineWidth: 1)
        )
        .shadow(color: card.colors[0].opacity(isActive ? 0.26 : 0.12), radius: isActive ? 20 : 10, y: 8)
    }
}

private struct CourseHubSignalBackdrop: View {
    let active: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                var path = Path()
                let time = active ? CGFloat(timeline.date.timeIntervalSinceReferenceDate) : phase
                let mid = size.height * 0.64
                let amp = min(size.height * 0.035, 24)
                path.move(to: CGPoint(x: 0, y: mid))
                for x in stride(from: CGFloat(0), through: size.width, by: 4) {
                    let t = x / max(size.width, 1)
                    let carrier = sin(t * .pi * 4 + time * 1.1)
                    let shimmer = sin(t * .pi * 9 - time * 0.8) * 0.16
                    path.addLine(to: CGPoint(x: x, y: mid + (carrier + shimmer) * amp * (0.42 + 0.58 * sin(t * .pi))))
                }
                context.stroke(path, with: .color(Color.pink.opacity(0.72)), lineWidth: 1.6)
                context.stroke(path, with: .color(Color.purple.opacity(0.24)), lineWidth: 6)
            }
        }
    }
}
