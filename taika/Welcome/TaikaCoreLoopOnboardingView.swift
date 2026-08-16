import SwiftUI

/// First-entry proof-of-value flow. The visual language follows the approved Taika mockups,
/// while recording and feedback are driven by the real SpeakerManager pipeline.
struct TaikaCoreLoopOnboardingView: View {
    let onFinished: (_ courseId: String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var speaker = SpeakerManager.shared

    @State private var phase: Phase = .hook
    @State private var hasPlayedPhrase = false
    @State private var isPressed = false
    @State private var selectedHint = 0
    @State private var introFrame: IntroFrame = .brand
    @State private var painIndex = 0
    @State private var introTask: Task<Void, Never>?
    @Namespace private var heroNamespace

    private let painPoints = ["Не понимаю тоны", "Боюсь говорить", "Забываю фразы", "Не знаю, что учить дальше"]
    private let hintChips = ["Как пройти к метро?", "Возьмите сдачу", "Я только учусь"]

    private enum IntroFrame: Int, Equatable {
        case brand
        case positioning
        case pain
        case cta
    }

    private enum Phase: Equatable {
        case hook
        case phrase
        case listen
        case speak
        case feedback
        case reinforce
    }

    private var transition: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.52, dampingFraction: 0.86)
    }

    private var phraseThai: String { speaker.conversationExpectedThai ?? MainInstantSpeakerDemo.thai }
    private var phrasePhonetic: String { speaker.conversationExpectedTranslitForFeedback ?? MainInstantSpeakerDemo.phonetic }
    private var phraseRU: String { speaker.heardRU?.isEmpty == false ? speaker.heardRU! : MainInstantSpeakerDemo.ru }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ambientGlow

            VStack(spacing: 0) {
                Spacer(minLength: phase == .hook ? 10 : 18)
                heroSlot
                Spacer(minLength: phase == .hook ? 8 : 16)
                footerSlot
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .safeAreaPadding(.top)
            .safeAreaPadding(.bottom)
        }
        .onAppear {
            speaker.setSpeakerUIMode(.conversation)
            startIntroSequence()
        }
        .onDisappear {
            introTask?.cancel()
        }
        .onChange(of: speaker.phase) { _, newPhase in
            guard phase == .speak else { return }
            if case .feedback = newPhase {
                withAnimation(transition) { phase = .feedback }
            }
        }
    }

    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(theme.currentAccentTintColor.opacity(phase == .hook ? 0.12 : 0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 92)
                .offset(y: phase == .hook ? 30 : 10)
                .animation(reduceMotion ? nil : .easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: phase)
            LinearGradient(
                colors: [.clear, theme.currentAccentTintColor.opacity(0.055), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var heroSlot: some View {
        ZStack {
            switch phase {
            case .hook:
                hookHero
            case .phrase:
                phraseHero
            case .listen:
                phraseHero
            case .speak:
                speakHero
            case .feedback:
                feedbackHero
            case .reinforce:
                reinforceHero
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: phase == .hook ? 470 : 440)
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
        .animation(transition, value: phase)
    }

    private var hookHero: some View {
        ZStack {
            switch introFrame {
            case .brand:
                brandReveal
            case .positioning:
                positioningReveal
            case .pain:
                painReveal
            case .cta:
                ctaReveal
            }
        }
        .id(introFrame)
        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.97)), removal: .opacity))
        .animation(transition, value: introFrame)
    }

    private var brandReveal: some View {
        VStack(spacing: 26) {
            Text("taikAAA")
                .font(.custom("Onmark Trial", size: 64))
                .foregroundStyle(theme.currentAccentFill)
                .shadow(color: theme.currentAccentTintColor.opacity(0.52), radius: 28)
                .scaleEffect(introFrame == .brand ? 1 : 0.96)
            Rectangle()
                .fill(theme.currentAccentFill)
                .frame(width: 68, height: 2)
                .blur(radius: 0.3)
                .shadow(color: theme.currentAccentTintColor.opacity(0.8), radius: 12)
        }
        .frame(maxWidth: .infinity)
    }

    private var positioningReveal: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("НЕ ПРОСТО ПЕРЕВОДЧИК")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.25)
                .foregroundStyle(theme.currentAccentFill)
            Text("Твоя персональная\nкун кру для тайского.")
                .font(.system(size: 35, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(-2)
            Text("Она помогает услышать, сказать\nи запомнить живую речь.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.66))
            VoiceOrb(isActive: true, tint: theme.currentAccentTintColor)
                .matchedGeometryEffect(id: "core-hero", in: heroNamespace)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
        }
    }

    private var painReveal: some View {
        VStack(spacing: 24) {
            Text("ЗНАКОМО, КОГДА УЧИШЬ ТАЙСКИЙ?")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(theme.currentAccentFill)
            Text("Ты не один с этим.")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            VStack(spacing: 8) {
                ForEach(Array(painPoints.enumerated()), id: \.offset) { index, pain in
                    painRow(pain, active: index == painIndex)
                }
            }
            .frame(maxWidth: .infinity)
            Text("Taika превращает каждую боль\nв следующий понятный шаг.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
        }
    }

    private func painRow(_ title: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(active ? theme.currentAccentFill : Color.white.opacity(0.18))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 15, weight: active ? .semibold : .medium, design: .rounded))
                .foregroundStyle(active ? .white : .white.opacity(0.4))
            Spacer(minLength: 0)
            if active {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.currentAccentFill)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 43)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(active ? theme.currentAccentTintColor.opacity(0.16) : Color.white.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(active ? theme.currentAccentTintColor.opacity(0.56) : Color.white.opacity(0.06), lineWidth: 1))
        .animation(transition, value: active)
    }

    private var ctaReveal: some View {
        VStack(spacing: 18) {
            Text("ТЕПЕРЬ ПОПРОБУЕМ ВМЕСТЕ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(theme.currentAccentFill)
            Text("Скажи одну фразу —\nTaika услышит слова и тоны.")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(-1)
            VoiceOrb(isActive: true, tint: theme.currentAccentTintColor)
                .matchedGeometryEffect(id: "core-hero", in: heroNamespace)
                .frame(height: 220)
            hintRail
        }
    }

    private var hintRail: some View {
        HStack(spacing: 8) {
            ForEach(Array(hintChips.enumerated()), id: \.offset) { index, chip in
                Button {
                    withAnimation(transition) { selectedHint = index }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: index == selectedHint ? "sparkles" : "text.quote")
                            .font(.system(size: 10, weight: .bold))
                        Text(chip)
                            .lineLimit(1)
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(index == selectedHint ? .white : .white.opacity(0.58))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Capsule().fill(index == selectedHint ? theme.currentAccentTintColor.opacity(0.26) : Color.white.opacity(0.045)))
                    .overlay(Capsule().stroke(index == selectedHint ? theme.currentAccentTintColor.opacity(0.62) : Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .scaleEffect(index == selectedHint ? 1 : 0.96)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var phraseHero: some View {
        VStack(spacing: 16) {
            Text("ОДНА ФРАЗА ДЛЯ ПРАКТИКИ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(theme.currentAccentFill)
            phraseCard
            Text(phase == .listen && hasPlayedPhrase ? "Слушаем" : "Нажми, чтобы услышать")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var phraseCard: some View {
        VStack(spacing: 14) {
            Text("ОДНА ФРАЗА")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(theme.currentAccentFill)
            Text(phraseThai)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
            Text(phrasePhonetic)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.currentAccentFill)
            Text(phraseRU)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
            Button {
                playReference()
            } label: {
                Image(systemName: hasPlayedPhrase ? "waveform" : "speaker.wave.2.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(theme.currentAccentFill))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: hasPlayedPhrase)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(maxWidth: 342)
        .matchedGeometryEffect(id: "core-hero", in: heroNamespace)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                )
        )
        .shadow(color: theme.currentAccentTintColor.opacity(0.20), radius: 34, y: 16)
    }

    private var speakHero: some View {
        VStack(spacing: 20) {
            Text("ОДНА ФРАЗА ДЛЯ ПРАКТИКИ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(theme.currentAccentFill)
            VStack(spacing: 8) {
                Text(phraseThai)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.white)
                Text(phrasePhonetic)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.currentAccentFill)
            }
            .opacity(0.82)
            VoiceMic(isRecording: speaker.phase == .recording, tint: theme.currentAccentTintColor, fill: theme.currentAccentFill)
                .frame(width: 190, height: 190)
            Text(speaker.phase == .recording ? "Говори — Taika слушает тоны" : "Нажми и повтори")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
        }
    }

    private var feedbackHero: some View {
        VStack(spacing: 18) {
            Text("Вот следующий шаг")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            VStack(spacing: 15) {
                Text(phraseThai)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(theme.currentAccentFill)
                Text(phrasePhonetic)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                feedbackRow(title: "Слова", value: speaker.heardConfidence)
                feedbackRow(title: "Тон", value: speaker.toneAverageScore ?? speaker.displayScore)
                if let hint = speaker.taikaHints.first, !hint.isEmpty {
                    Label(hint, systemImage: "lightbulb.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(22)
            .frame(maxWidth: 342)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.025)))
            )
            .shadow(color: theme.currentAccentTintColor.opacity(0.16), radius: 28, y: 12)
        }
    }

    private func feedbackRow(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(max(0, value))%")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))
            ProgressView(value: Double(max(0, min(100, value))), total: 100)
                .tint(theme.currentAccentFill)
        }
    }

    private var reinforceHero: some View {
        VStack(spacing: 22) {
            Text("Закрепим одним жестом")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            HStack(spacing: -18) {
                reinforcementCard(title: "Match", icon: "puzzlepiece.fill", opacity: 0.48, scale: 0.82, offset: 16)
                reinforcementCard(title: "Разминка", icon: "flame.fill", opacity: 1, scale: 1, offset: 0)
                reinforcementCard(title: "Audio Recall", icon: "waveform", opacity: 0.48, scale: 0.82, offset: 16)
            }
            .frame(height: 220)
            Text("Одна фраза — несколько способов остаться в памяти")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
    }

    private func reinforcementCard(title: String, icon: String, opacity: Double, scale: CGFloat, offset: CGFloat) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(width: 132, height: 168)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black.opacity(0.3)).overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(theme.currentAccentTintColor.opacity(opacity), lineWidth: 1)))
        .opacity(opacity)
        .scaleEffect(scale)
        .offset(y: offset)
    }

    @ViewBuilder
    private var footerSlot: some View {
        VStack(spacing: 12) {
            switch phase {
            case .hook:
                if introFrame == .cta {
                    primaryCTA("Попробовать фразу") { advance(.phrase) }
                }
            case .phrase:
                primaryCTA("Послушать") { advance(.listen) }
            case .listen:
                primaryCTA("Теперь сам") {
                    playReference()
                    withAnimation(transition) { phase = .speak }
                }
            case .speak:
                primaryCTA(speaker.phase == .recording ? "Остановить" : "Говорить") { toggleRecording() }
            case .feedback:
                primaryCTA("Повторить с подсказкой") { repeatWithHint() }
                Button("Дальше") { advance(.reinforce) }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .buttonStyle(.plain)
            case .reinforce:
                primaryCTA("Закрепить") { onFinished("course_b_1") }
                Button("Пропустить") { onFinished("course_b_1") }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .buttonStyle(.plain)
            }
        }
    }

    private func primaryCTA(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(transition) { action() }
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Capsule().fill(theme.currentAccentFill))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: phase)
    }

    private func startIntroSequence() {
        introTask?.cancel()
        introFrame = .brand
        painIndex = 0
        introTask = Task { @MainActor in
            if reduceMotion {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                introFrame = .cta
                return
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(transition) { introFrame = .positioning }
            try? await Task.sleep(nanoseconds: 2_100_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(transition) { introFrame = .pain }
            for index in 0..<painPoints.count {
                guard !Task.isCancelled else { return }
                withAnimation(transition) { painIndex = index }
                try? await Task.sleep(nanoseconds: 850_000_000)
            }
            guard !Task.isCancelled else { return }
            withAnimation(transition) { introFrame = .cta }
        }
    }

    private func advance(_ next: Phase) {
        withAnimation(transition) { phase = next }
        if next == .listen { hasPlayedPhrase = false }
    }

    private func playReference() {
        if speaker.conversationExpectedThai == nil {
            speaker.startConversationDemoPhrase("Спасибо")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            speaker.playReferenceConversationExpectedIfNeeded()
            hasPlayedPhrase = true
        }
    }

    private func toggleRecording() {
        if speaker.phase == .recording {
            speaker.stopConversationPronunciationCheck()
        } else {
            speaker.startConversationRecording()
        }
    }

    private func repeatWithHint() {
        speaker.startConversationRecording()
        withAnimation(transition) { phase = .speak }
    }
}

private struct VoiceOrb: View {
    let isActive: Bool
    let tint: Color
    @State private var breathing = false

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: 1).scaleEffect(breathing ? 1.08 : 0.94)
            Circle().stroke(tint.opacity(0.24), lineWidth: 1).scaleEffect(breathing ? 0.92 : 1.04)
            ForEach(0..<3, id: \.self) { index in
                WaveformLine(tint: tint, active: isActive)
                    .frame(height: 112 + CGFloat(index) * 18)
                    .opacity(0.32 + Double(index) * 0.24)
                    .scaleEffect(x: 1 + CGFloat(index) * 0.05, y: 1, anchor: .center)
            }
        }
        .frame(width: 250, height: 250)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathing = true }
        }
    }
}

private struct VoiceMic: View {
    let isRecording: Bool
    let tint: Color
    let fill: LinearGradient
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(tint.opacity(isRecording ? 0.26 : 0.10), lineWidth: 1)
                    .scaleEffect(isRecording ? (pulse ? 1.06 + CGFloat(index) * 0.14 : 0.92 + CGFloat(index) * 0.12) : 0.86 + CGFloat(index) * 0.12)
            }
            Circle()
                .fill(fill)
                .frame(width: isRecording ? 94 : 82, height: isRecording ? 94 : 82)
                .shadow(color: tint.opacity(0.42), radius: isRecording ? 24 : 16)
            Image(systemName: isRecording ? "waveform.path.ecg" : "mic.fill")
                .font(.system(size: isRecording ? 27 : 28, weight: .semibold))
                .foregroundStyle(.black)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

private struct WaveformLine: View {
    let tint: Color
    let active: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                var path = Path()
                let mid = size.height / 2
                let amp = active ? size.height * 0.28 : size.height * 0.16
                let time = timeline.date.timeIntervalSinceReferenceDate
                path.move(to: CGPoint(x: 0, y: mid))
                for x in stride(from: 0, through: size.width, by: 3) {
                    let t = x / size.width
                    let carrier = sin(t * .pi * 4 + time * (active ? 2.2 : 0.8))
                    let shimmer = sin(t * .pi * 9 - time * 1.35) * 0.16
                    let y = mid + (carrier + shimmer) * amp * (0.42 + 0.58 * sin(t * .pi))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(path, with: .color(tint.opacity(0.88)), lineWidth: active ? 2.2 : 1.7)
            }
        }
    }
}
