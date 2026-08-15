//
//  TaikaProductDemoStages.swift
//  taika
//
//  Entry storyboard visuals + contextual phone tours.
//

import SwiftUI

enum TaikaProductDemoPresentation {
    case storyboard
    case productTour
}

struct TaikaProductDemoStageView: View {
    let stage: TaikaProductDemoStage
    let tick: Int
    var presentation: TaikaProductDemoPresentation = .storyboard

    var body: some View {
        Group {
            switch stage {
            case .phraseHero: PhraseHeroScene(tick: tick)
            case .learnPipeline: LearnPipelineScene(tick: tick)
            case .reinforceWays: ReinforceWaysScene(tick: tick)
            case .speakerAI: SpeakerAIScene(tick: tick)
            case .speakerVoiceOrText: phone { SpeakerVoiceOrTextScene(tick: tick) }
            case .speakerPreviewSave: phone { SpeakerPreviewSaveScene(tick: tick) }
            case .speakerPractice: phone { SpeakerPracticeScene(tick: tick) }
            case .courseBase: phone { CourseBaseScene(tick: tick) }
            case .courseScenarios: phone { CourseScenariosScene(tick: tick) }
            case .courseLesson: phone { CourseLessonScene(tick: tick) }
            }
        }
    }

    @ViewBuilder
    private func phone<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ProductTourPhoneChrome { content() }
    }
}

// MARK: - Phone chrome (contextual only)

private struct ProductTourPhoneChrome<Content: View>: View {
    @ViewBuilder var content: Content
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let tint = theme.currentAccentTintColor
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 78, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 10)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AnyShapeStyle(theme.currentAccentFill.opacity(0.55)), lineWidth: 1.5)
        )
        .shadow(color: tint.opacity(0.28), radius: 28, y: 12)
    }
}

// MARK: - Shared bits

private struct DemoChip: View {
    let title: String
    var active: Bool = false
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(active ? Color(white: 0.1) : Color.white.opacity(0.72))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(active ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.12)))
            )
    }
}

private struct DemoCardBlock: View {
    let title: String
    var subtitle: String? = nil
    var accentBar: Bool = false
    var emphasized: Bool = false
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            if accentBar {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(theme.currentAccentFill)
                    .frame(width: 4, height: emphasized ? 40 : 32)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: emphasized ? 17 : 15, weight: .bold))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: emphasized ? 13 : 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(emphasized ? 16 : 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(emphasized ? 0.14 : 0.08))
        )
        .overlay {
            if emphasized {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AnyShapeStyle(theme.currentAccentFill.opacity(0.85)), lineWidth: 1.5)
            }
        }
    }
}

private struct StoryGlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AnyShapeStyle(theme.currentAccentFill.opacity(0.45)), lineWidth: 1.2)
            )
            .shadow(color: theme.currentAccentTintColor.opacity(0.22), radius: 22, y: 8)
    }
}

// MARK: - Storyboard 1: phrase hero

private struct PhraseHeroScene: View {
    let tick: Int
    @State private var showCard = false
    @State private var toneBlink = false
    @State private var speakerBounce = false
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 4)

            StoryGlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("НОВАЯ ФРАЗА")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(Color(white: 0.12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(theme.currentAccentFill))

                    Text("ขอบคุณ")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Text("коп")
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                            .opacity(toneBlink ? 1 : 0.35)
                            .scaleEffect(toneBlink ? 1.2 : 1)
                        Text("кун")
                    }
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                    Text("Спасибо")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))

                    HStack {
                        Image(systemName: "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(white: 0.12))
                            .padding(12)
                            .background(Circle().fill(theme.currentAccentFill))
                            .symbolEffect(.bounce, value: speakerBounce)
                    }
                    .padding(.top, 4)
                }
            }
            .scaleEffect(showCard ? 1 : 0.92)
            .opacity(showCard ? 1 : 0)

            Text("смысл · тон · голос")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                .opacity(showCard ? 1 : 0)

            Spacer(minLength: 4)
        }
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func runMotion() {
        showCard = false
        toneBlink = false
        speakerBounce = false
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            showCard = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                toneBlink = true
            }
            speakerBounce.toggle()
        }
    }
}

// MARK: - Storyboard 2: learn pipeline

private struct LearnPipelineScene: View {
    let tick: Int
    @State private var step = 0
    @ObservedObject private var theme = ThemeManager.shared

    private let rows: [(icon: String, title: String, detail: String)] = [
        ("ear.fill", "Учишь", "Слушаешь фразу и тоны"),
        ("gamecontroller.fill", "Закрепляешь", "Игра / разминка / карточка"),
        ("mic.fill", "Говоришь", "Повторяешь вслух в Спикере"),
        ("checkmark.seal.fill", "Остаётся", "В словаре и разминке")
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                let active = idx <= step
                let current = idx == step
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(active ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.12)))
                            .frame(width: 44, height: 44)
                        Image(systemName: row.icon)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(active ? Color(white: 0.12) : Color.white.opacity(0.4))
                    }
                    .scaleEffect(current ? 1.08 : 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(active ? Color.white : Color.white.opacity(0.4))
                        Text(row.detail)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(active ? Color.white.opacity(0.6) : Color.white.opacity(0.28))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(current ? 0.14 : 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            current
                            ? AnyShapeStyle(theme.currentAccentFill.opacity(0.75))
                            : AnyShapeStyle(Color.clear),
                            lineWidth: 1.3
                        )
                )
                .opacity(idx <= step + 1 || step >= rows.count - 1 ? 1 : 0.55)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.85), value: step)
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func runMotion() {
        step = 0
        Task { @MainActor in
            for i in 1..<rows.count {
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation { step = i }
            }
        }
    }
}

// MARK: - Storyboard 3: reinforce ways

private struct ReinforceWaysScene: View {
    let tick: Int
    @State private var focus = 0
    @ObservedObject private var theme = ThemeManager.shared

    private let ways: [(icon: String, title: String, detail: String)] = [
        ("flame.fill", "Разминка", "Умный повтор карточек"),
        ("gamecontroller.fill", "Игры", "Матч, слоги, аудио"),
        ("waveform.circle.fill", "Спикер", "Произношение и тоны"),
        ("bookmark.fill", "Словарь", "Твоя полка фраз")
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(ways.enumerated()), id: \.offset) { idx, way in
                let on = idx == focus
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(on ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.1)))
                            .frame(width: 48, height: 48)
                        Image(systemName: way.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(on ? Color(white: 0.12) : Color.white.opacity(0.55))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(way.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text(way.detail)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 0)

                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(on ? 0.14 : 0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            on
                            ? AnyShapeStyle(theme.currentAccentFill.opacity(0.8))
                            : AnyShapeStyle(Color.white.opacity(0.08)),
                            lineWidth: on ? 1.4 : 1
                        )
                )
                .scaleEffect(on ? 1.02 : 1)
            }

            Text("Ты выбираешь, как закрепить результат")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 4)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.84), value: focus)
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func runMotion() {
        focus = 0
        Task { @MainActor in
            for i in 1..<ways.count {
                try? await Task.sleep(nanoseconds: 700_000_000)
                withAnimation { focus = i }
            }
        }
    }
}

// MARK: - Storyboard 4: speaker AI flow

private struct SpeakerAIScene: View {
    let tick: Int
    @State private var phase = 0
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 12) {
            bubble(align: .trailing, delayVisible: phase >= 0) {
                Text("Мне нужна вода")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            bubble(align: .leading, delayVisible: phase >= 1) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ขอน้ำหน่อย")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text("ко↑ нам нои")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("Повтори за Taika")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                }
            }

            bubble(align: .trailing, delayVisible: phase >= 2) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                    Text("ขอน้ำหน่อย")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            if phase >= 3 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                    Text("Taika услышала — можно в словарь")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.currentAccentFill.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AnyShapeStyle(theme.currentAccentFill.opacity(0.55)), lineWidth: 1)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: phase)
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func bubble<Content: View>(
        align: HorizontalAlignment,
        delayVisible: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            if align == .trailing { Spacer(minLength: 36) }
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(align == .trailing ? Color.white.opacity(0.14) : Color.white.opacity(0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            align == .leading
                            ? AnyShapeStyle(theme.currentAccentFill.opacity(0.4))
                            : AnyShapeStyle(Color.white.opacity(0.1)),
                            lineWidth: 1
                        )
                )
            if align == .leading { Spacer(minLength: 36) }
        }
        .opacity(delayVisible ? 1 : 0)
        .offset(y: delayVisible ? 0 : 12)
    }

    private func runMotion() {
        phase = 0
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation { phase = 1 }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation { phase = 2 }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation { phase = 3 }
        }
    }
}

// MARK: - Contextual: speaker

private struct SpeakerVoiceOrTextScene: View {
    let tick: Int
    @State private var showKeyboard = false
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Скажи сам")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 20) {
                buttonGlyph(system: "keyboard", lit: showKeyboard)
                buttonGlyph(system: "mic.fill", lit: !showKeyboard)
                    .scaleEffect(!showKeyboard ? 1.1 : 1)
            }

            Text(showKeyboard ? "Текст" : "Голос")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))

            Spacer(minLength: 0)
        }
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func buttonGlyph(system: String, lit: Bool) -> some View {
        ZStack {
            Circle()
                .fill(lit ? AnyShapeStyle(theme.currentAccentFill.opacity(0.28)) : AnyShapeStyle(Color.white.opacity(0.08)))
                .frame(width: 78, height: 78)
            if lit {
                Circle()
                    .stroke(AnyShapeStyle(theme.currentAccentFill), lineWidth: 2)
                    .frame(width: 78, height: 78)
            }
            Image(systemName: system)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(lit ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.4)))
        }
    }

    private func runMotion() {
        showKeyboard = false
        withAnimation(.easeInOut(duration: 0.95).delay(0.35).repeatForever(autoreverses: true)) {
            showKeyboard = true
        }
    }
}

private struct SpeakerPreviewSaveScene: View {
    let tick: Int
    @State private var confirmed = false
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Превью")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))

            VStack(alignment: .leading, spacing: 8) {
                Text("Где туалет?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("хонг↑нам юу тии най")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text("ห้องน้ำอยู่ที่ไหน")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )

            Text(confirmed ? "В ленте и словаре ✓" : "В ленту и словарь")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(confirmed ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color(white: 0.1)))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(confirmed ? AnyShapeStyle(Color.white.opacity(0.12)) : AnyShapeStyle(theme.currentAccentFill))
                )
                .scaleEffect(confirmed ? 1.03 : 1)

            Spacer(minLength: 0)
        }
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func runMotion() {
        confirmed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                confirmed = true
            }
        }
    }
}

private struct SpeakerPracticeScene: View {
    let tick: Int
    @State private var pulsing = false
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Тренировать произношение")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            DemoCardBlock(title: "สวัสดี · Привет", subtitle: "Повтори за образцом", accentBar: true, emphasized: true)

            ZStack {
                Circle()
                    .stroke(AnyShapeStyle(theme.currentAccentFill.opacity(0.4)), lineWidth: 2.5)
                    .frame(width: 110, height: 110)
                    .scaleEffect(pulsing ? 1.22 : 1)
                    .opacity(pulsing ? 0.2 : 0.75)
                Circle()
                    .fill(theme.currentAccentFill)
                    .frame(width: 82, height: 82)
                Image(systemName: "mic.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(white: 0.1))
            }
            .padding(.top, 16)

            Text("Скажи вслух")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Spacer(minLength: 0)
        }
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func runMotion() {
        pulsing = false
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }
}

// MARK: - Contextual: course

private struct CourseBaseScene: View {
    let tick: Int
    @State private var focus = 0
    @ObservedObject private var theme = ThemeManager.shared

    private let cards = ["Разговорный старт", "Числа и цена", "Вежливость"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                DemoChip(title: "База", active: true)
                DemoChip(title: "Сценарии", active: false)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { idx, title in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(theme.currentAccentFill.opacity(idx == focus ? 0.55 : 0.2))
                                .frame(width: 140, height: 88)
                            Text(title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(idx == focus ? 1 : 0.5))
                                .frame(width: 140, alignment: .leading)
                                .lineLimit(2)
                        }
                        .scaleEffect(idx == focus ? 1.05 : 0.94)
                    }
                }
                .padding(.vertical, 6)
            }

            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: focus)
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func runMotion() {
        focus = 0
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation { focus = 1 }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation { focus = 0 }
        }
    }
}

private struct CourseScenariosScene: View {
    let tick: Int
    @State private var scenarios = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                DemoChip(title: "База", active: !scenarios)
                DemoChip(title: "Сценарии", active: scenarios)
            }

            if scenarios {
                VStack(spacing: 10) {
                    DemoCardBlock(title: "7-Eleven", subtitle: "Купить воду · спросить цену", accentBar: true, emphasized: true)
                    DemoCardBlock(title: "Такси", subtitle: "Куда едем · остановите", accentBar: true)
                    DemoCardBlock(title: "Рынок", subtitle: "Сколько · торг", accentBar: true)
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                DemoCardBlock(title: "Разговорный старт", subtitle: "База · 7 уроков", accentBar: true, emphasized: true)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: scenarios)
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func runMotion() {
        scenarios = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation { scenarios = true }
        }
    }
}

private struct CourseLessonScene: View {
    let tick: Int
    @State private var checked = false
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Урок · Приветствие")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            ForEach(["สวัสดี — Привет", "สบายดีไหม — Как дела?", "ขอบคุณ — Спасибо"], id: \.self) { row in
                HStack(spacing: 12) {
                    Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(checked ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.35)))
                    Text(row)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Text("Выученное → очередь в Спикере")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .onAppear { runMotion() }
        .onChange(of: tick) { _, _ in runMotion() }
    }

    private func runMotion() {
        checked = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                checked = true
            }
        }
    }
}
