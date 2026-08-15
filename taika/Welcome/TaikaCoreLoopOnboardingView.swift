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
    @Namespace private var heroNamespace

    private let hintChips = ["Как пройти к метро?", "Возьмите сдачу", "Я только учусь"]

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
            WelcomeSpaceBackdropView()
            Color.black.opacity(0.48).ignoresSafeArea()
            ambientGlow

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: phase == .hook ? 10 : 18)
                if phase != .hook {
                    promptSlot
                }
                Spacer(minLength: phase == .hook ? 0 : 16)
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
                .fill(theme.currentAccentTintColor.opacity(0.42))
                .frame(width: 330, height: 330)
                .blur(radius: 78)
                .offset(y: phase == .hook ? 70 : 20)
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: phase)
            LinearGradient(
                colors: [.clear, theme.currentAccentTintColor.opacity(0.16), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("taikAAA")
                .font(.custom("Onmark Trial", size: 30))
                .foregroundStyle(theme.currentAccentFill)
            Spacer()
            onboardingIcon("gamecontroller.fill")
            onboardingIcon("bookmark.fill", value: "6")
            onboardingIcon("crown.fill")
        }
        .opacity(phase == .hook ? 1 : 0.72)
    }

    private func onboardingIcon(_ systemName: String, value: String? = nil) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill.opacity(0.9))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.035)))
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            if let value {
                Text(value)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(3)
                    .background(Circle().fill(theme.currentAccentFill))
                    .offset(x: 2, y: -2)
            }
        }
    }

    private var promptSlot: some View {
        Text(phase == .feedback ? "РАЗБОР ПРОИЗНОШЕНИЯ" : "ОДНА ФРАЗА ДЛЯ ПРАКТИКИ")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.25)
            .foregroundStyle(theme.currentAccentFill.opacity(0.82))
            .frame(height: 22)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ТВОЙ ПЕРСОНАЛЬНЫЙ КУН КРУ")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(theme.currentAccentFill)
                Text("Говори. Учись.\nЖиви по-тайски.")
                    .font(.system(size: 33, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(-2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VoiceOrb(isActive: true, tint: theme.currentAccentTintColor)
                .matchedGeometryEffect(id: "core-hero", in: heroNamespace)
                .frame(height: 235)

            Text("Сразу попробуй настоящую фразу —\nTaika услышит слова и тоны.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

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
        VStack(spacing: 18) {
            phraseCard
            if phase == .listen {
                Text(hasPlayedPhrase ? "Слушаем" : "Нажми, чтобы услышать")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Text("Сначала услышь")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
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
                .fill(Color.black.opacity(0.56))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(theme.currentAccentTintColor.opacity(0.68), lineWidth: 1))
        )
        .shadow(color: theme.currentAccentTintColor.opacity(0.34), radius: 30, y: 12)
    }

    private var speakHero: some View {
        VStack(spacing: 22) {
            phraseCard
                .scaleEffect(0.82)
                .opacity(0.72)
            VoiceMic(isRecording: speaker.phase == .recording, tint: theme.currentAccentTintColor)
                .frame(height: 150)
            Text(speaker.phase == .recording ? "Говори" : "Нажми и повтори")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
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
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.38)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(theme.currentAccentTintColor.opacity(0.6), lineWidth: 1)))
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
                primaryCTA("Попробовать фразу") { advance(.phrase) }
                warmupStrip
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

    private var warmupStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.currentAccentFill)
            Text("Разминка")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(theme.currentAccentFill)
            Text("· 3ч 25м")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(Capsule().fill(Color.white.opacity(0.035)))
        .overlay(Capsule().stroke(theme.currentAccentTintColor.opacity(0.58), lineWidth: 1))
        .contentShape(Capsule())
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
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(tint.opacity(isRecording ? 0.26 : 0.10), lineWidth: 1)
                    .scaleEffect(isRecording ? (pulse ? 1.06 + CGFloat(index) * 0.14 : 0.92 + CGFloat(index) * 0.12) : 0.86 + CGFloat(index) * 0.12)
            }
            Circle().fill(tint).frame(width: 82, height: 82)
            Image(systemName: isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 28, weight: .semibold))
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
