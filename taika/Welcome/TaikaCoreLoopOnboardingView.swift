import SwiftUI

/// First-entry proof-of-value flow.
/// Attention choreography around one VoiceOrb: craft → reveal → speak → score.
private enum PracticeOrbMode: Equatable {
    case idle
    case cooking
    case speaking
    case listening
    case result
}

struct TaikaCoreLoopOnboardingView: View {
    let onFinished: (_ courseId: String) -> Void
    let onRequestPro: () -> Void

    init(
        onFinished: @escaping (_ courseId: String) -> Void,
        onRequestPro: @escaping () -> Void = {}
    ) {
        self.onFinished = onFinished
        self.onRequestPro = onRequestPro
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var speaker = SpeakerManager.shared

    @State private var phase: Phase = .hook
    @State private var hasPlayedPhrase = false
    @State private var isPressed = false
    @State private var introFrame: IntroFrame = .brand
    @State private var selectedLevel: Int?
    @State private var selectedGender: String? // "male" | "female"
    @State private var selectedPains = Set<Int>()
    @State private var recordingTask: Task<Void, Never>?
    @State private var listenTask: Task<Void, Never>?
    @State private var craftTask: Task<Void, Never>?
    @State private var resultTask: Task<Void, Never>?
    @State private var isPreparingRecording = false
    @State private var phraseRevealed = false
    @State private var isCookingResult = false
    @State private var showBreakdownSheet = false
    /// Freeze score on feedback so tone API can't jump 100→82 behind the user.
    @State private var lockedFeedbackScore: Int? = nil
    @State private var brandVisible = false
    @State private var brandLogoPulse: CGFloat = 1
    @State private var brandCursorOn = true
    @Namespace private var heroNamespace

    private let painPoints = ["Не понимаю тоны", "Боюсь говорить", "Забываю фразы", "Не знаю, что учить дальше"]
    private let levelOptions = ["Никогда не учил", "Знаю основы", "Уже говорю"]
    private let genderOptions: [(id: String, title: String, particle: String)] = [
        ("male", "Мужской", "ครับ · крап"),
        ("female", "Женский", "ค่ะ · ка")
    ]

    private enum IntroFrame: Int, Equatable {
        case brand, level, gender, pain
    }

    private enum Phase: Equatable {
        case hook
        case crafting
        case phrase
        case listen
        case speak
        case feedback
        case reinforce
    }

    private var transition: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.62, dampingFraction: 0.90)
    }

    private var isPracticeStage: Bool {
        switch phase {
        case .crafting, .phrase, .listen, .speak, .feedback: return true
        default: return false
        }
    }

    private var orbMode: PracticeOrbMode {
        if phase == .crafting { return .cooking }
        if phase == .listen { return .speaking }
        if phase == .feedback { return .result }
        if phase == .speak {
            if isCookingResult || speaker.phase == .analyzing || isPreparingRecording { return .cooking }
            if speaker.phase == .recording { return .listening }
            return .listening
        }
        return .idle
    }

    private var phraseThai: String {
        speaker.conversationExpectedThai ?? speaker.heardThai ?? practiceSeed.thai
    }
    private var phrasePhonetic: String {
        speaker.conversationExpectedTranslitForFeedback ?? speaker.heardTranslit ?? practiceSeed.phonetic
    }
    private var phraseRU: String {
        if let ru = speaker.heardRU, !ru.isEmpty { return ru }
        return practiceSeed.ru
    }

    private var practiceSeed: (thai: String, phonetic: String, ru: String) {
        OnboardingPracticePhrase.seed(level: selectedLevel ?? 0, politeness: selectedGender ?? "female")
    }

    private var overallScore: Int {
        if let lockedFeedbackScore { return lockedFeedbackScore }
        // Onboarding hero uses text confidence until tone breakdown arrives —
        // never silently rewrite the big number when syllables load.
        return max(0, speaker.heardConfidence)
    }

    private var practiceEyebrow: String {
        switch phase {
        case .crafting: return "ПОДБИРАЮ ФРАЗУ"
        case .phrase: return "ТВОЯ ПЕРВАЯ ФРАЗА"
        case .listen: return "TAIKA ГОВОРИТ"
        case .speak:
            if isCookingResult || speaker.phase == .analyzing { return "СЧИТАЮ РЕЗУЛЬТАТ" }
            if speaker.phase == .recording { return "СЛУШАЮ ТЕБЯ" }
            return "ТВОЯ ОЧЕРЕДЬ"
        case .feedback: return "TAIKA УСЛЫШАЛА"
        default: return ""
        }
    }

    private var practiceStatus: String {
        switch phase {
        case .crafting:
            return "Смотрю на твой уровень и собираю\nпонятный первый шаг…"
        case .phrase:
            return "Сначала услышь — потом повтори"
        case .listen:
            return "Слушай тоны внимательно"
        case .speak:
            if isPreparingRecording { return "Готовлю микрофон…" }
            if speaker.phase == .recording { return "Говори спокойно — я ловлю тоны" }
            if isCookingResult || speaker.phase == .analyzing { return "Собираю разбор…" }
            return "Когда готов — нажми «Говорить»"
        case .feedback:
            return feedbackFocusLine
        default:
            return ""
        }
    }

    private var feedbackVerdictTitle: String {
        if overallScore >= 75 { return "Уже звучит живо" }
        if overallScore >= 45 { return "Хороший старт" }
        return "Нормально для первого раза"
    }

    private var feedbackFocusLine: String {
        let words = speaker.heardConfidence
        let tone = speaker.toneAverageScore ?? speaker.displayScore
        if tone + 12 < words { return "Слова ок. Смотри тоны — там главный рычаг." }
        if words + 12 < tone { return "Тоны уже есть. Сделай слова чуть чётче." }
        return "Дальше — разбор по слогам: куда смотреть."
    }

    var body: some View {
        ZStack {
            Group {
                if phase == .reinforce {
                    PD.ColorToken.background
                } else {
                    Color.black
                }
            }
            .ignoresSafeArea()
            ambientGlow

            VStack(spacing: 0) {
                Spacer(minLength: phase == .hook ? 10 : (phase == .reinforce ? 4 : 8))
                heroSlot
                Spacer(minLength: phase == .reinforce ? 4 : 8)
                footerSlot
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .safeAreaPadding(.top)
            .safeAreaPadding(.bottom)
        }
        .sheet(isPresented: $showBreakdownSheet) {
            OnboardingBreakdownSheet(
                words: speaker.heardConfidence,
                tone: speaker.toneAverageScore ?? speaker.displayScore,
                syllables: speaker.syllableFeedback,
                hint: speaker.taikaHints.first ?? "",
                phraseRU: phraseRU,
                phrasePhonetic: phrasePhonetic,
                loading: speaker.breakdownRequestInFlight
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            speaker.setSpeakerUIMode(.conversation)
            startIntroSequence()
        }
        .onDisappear {
            recordingTask?.cancel()
            listenTask?.cancel()
            craftTask?.cancel()
            resultTask?.cancel()
            // Shared SpeakerManager must not keep the demo phrase / recording focus after first-entry.
            speaker.endEphemeralPracticeSession()
        }
        .onReceive(Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()) { _ in
            guard phase == .hook, introFrame == .brand else { return }
            brandCursorOn.toggle()
        }
        .onChange(of: speaker.phase) { _, newPhase in
            if phase == .speak, newPhase == .recording {
                isPreparingRecording = false
                scheduleRecordingAutoStop()
            }
            if newPhase == .idle {
                isPreparingRecording = false
            }
            guard phase == .speak else { return }
            if newPhase == .analyzing {
                withAnimation(transition) { isCookingResult = true }
            }
            if case .feedback = newPhase {
                recordingTask?.cancel()
                presentFeedbackAfterCook()
            }
        }
    }

    private var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(theme.currentAccentFill.opacity(glowOpacity))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(y: isPracticeStage ? 40 : 10)
                .scaleEffect(orbMode == .speaking || orbMode == .listening ? 1.12 : 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: orbMode)
            LinearGradient(
                colors: [.clear, theme.currentAccentTintColor.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }

    private var glowOpacity: Double {
        switch orbMode {
        case .speaking: return 0.28
        case .listening: return 0.24
        case .cooking: return 0.22
        case .result: return 0.18
        case .idle: return isPracticeStage ? 0.14 : 0.12
        }
    }

    @ViewBuilder
    private var heroSlot: some View {
        Group {
            switch phase {
            case .hook:
                hookHero
            case .crafting, .phrase, .listen, .speak, .feedback:
                practiceHero
            case .reinforce:
                reinforceHero
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: phase == .reinforce ? 460 : 520)
        .animation(transition, value: phase)
        .animation(transition, value: introFrame)
        .animation(transition, value: phraseRevealed)
        .animation(transition, value: isCookingResult)
    }

    private var hookHero: some View {
        ZStack {
            switch introFrame {
            case .brand: brandReveal
            case .level: levelReveal
            case .gender: genderReveal
            case .pain: painReveal
            }
        }
        .id(introFrame)
        .transition(.opacity)
    }

    private var brandReveal: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Text("tai")
                    .font(.custom("Onmark Trial", size: 52))
                    .foregroundStyle(.white)
                Text("kAAA")
                    .font(.custom("Onmark Trial", size: 52))
                    .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
            }
            .scaleEffect(brandLogoPulse)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("твоя персональная кун кру")
                Text("_")
                    .foregroundStyle(theme.currentAccentTintColor)
                    .opacity(brandCursorOn ? 1 : 0.18)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.72))
        }
        .multilineTextAlignment(.center)
        .opacity(brandVisible ? 1 : 0)
        .scaleEffect(brandVisible ? 1 : 0.96)
        .blur(radius: brandVisible ? 0 : 8)
        .frame(maxWidth: .infinity)
        .onAppear { runBrandReveal() }
    }

    private var levelReveal: some View {
        VStack(spacing: 26) {
            Text("С КАКОГО УРОВНЯ НАЧНЁМ?")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(theme.currentAccentFill)
            Text("Расскажи, как ты знаешь тайский.")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(Array(levelOptions.enumerated()), id: \.offset) { index, option in
                    levelRow(option, selected: selectedLevel == index) {
                        withAnimation(transition) { selectedLevel = index }
                    }
                }
            }
            Text("Это не тест. Taika просто подберёт\nправильную первую фразу.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
    }

    private func levelRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .stroke(selected ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.22)), lineWidth: 1.5)
                    .overlay(
                        Circle()
                            .fill(selected ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.clear))
                            .padding(5)
                    )
                    .frame(width: 18, height: 18)
                Text(title)
                    .font(.system(size: 16, weight: selected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(selected ? .white : .white.opacity(0.72))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(Capsule().fill(selected ? theme.currentAccentTintColor.opacity(0.18) : Color.white.opacity(0.045)))
        }
        .buttonStyle(.plain)
    }

    private var genderReveal: some View {
        VStack(spacing: 26) {
            Text("КАК ГОВОРИШЬ О СЕБЕ?")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(theme.currentAccentFill)
            Text("В тайском это сразу\nчастица вежливости.")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(genderOptions, id: \.id) { option in
                    genderRow(option.title, particle: option.particle, selected: selectedGender == option.id) {
                        withAnimation(transition) {
                            selectedGender = option.id
                            speaker.setSmartSpeakerPoliteness(option.id)
                        }
                    }
                }
            }
            Text("Сохраним в спикере — фразы сразу\nс ครับ или ค่ะ.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
    }

    private func genderRow(_ title: String, particle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .stroke(selected ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.22)), lineWidth: 1.5)
                    .overlay(
                        Circle()
                            .fill(selected ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.clear))
                            .padding(5)
                    )
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: selected ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(selected ? .white : .white.opacity(0.72))
                    Text(particle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(selected ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.42)))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(Capsule().fill(selected ? theme.currentAccentTintColor.opacity(0.18) : Color.white.opacity(0.045)))
        }
        .buttonStyle(.plain)
    }

    private var painReveal: some View {
        VStack(spacing: 24) {
            Text("ЧТО БОЛЬШЕ ВСЕГО МЕШАЕТ?")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(theme.currentAccentFill)
            Text("Выбери всё, что тебе знакомо.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(Array(painPoints.enumerated()), id: \.offset) { index, pain in
                    painRow(pain, active: selectedPains.contains(index)) {
                        withAnimation(transition) {
                            if selectedPains.contains(index) {
                                selectedPains.remove(index)
                            } else {
                                selectedPains.insert(index)
                            }
                        }
                    }
                }
            }
            Text("Taika превратит их в первые понятные шаги.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
    }

    private func painRow(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(active ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(Color.white.opacity(0.22)))
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 16, weight: active ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(active ? .white : .white.opacity(0.72))
                Spacer(minLength: 0)
                if active {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.currentAccentFill)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Capsule().fill(active ? theme.currentAccentTintColor.opacity(0.18) : Color.white.opacity(0.045)))
        }
        .buttonStyle(.plain)
        .animation(transition, value: active)
    }

    /// One orb composition for the whole practice loop — including feedback.
    private var practiceHero: some View {
        practiceLoopHero
    }

    private var practiceLoopHero: some View {
        VStack(spacing: 0) {
            Text(practiceEyebrow)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.35)
                .foregroundStyle(theme.currentAccentFill)
                .contentTransition(.opacity)
                .id(practiceEyebrow)
                .padding(.bottom, 18)

            phraseBlock
                .frame(maxHeight: phraseRevealed ? 110 : 0)
                .opacity(phraseRevealed ? 1 : 0)
                .blur(radius: phraseRevealed ? 0 : 10)
                .scaleEffect(phraseRevealed ? 1 : 0.96)
                .padding(.bottom, phraseRevealed ? 28 : 8)

            Spacer(minLength: 0)

            ZStack {
                VoiceOrb(
                    mode: orbMode,
                    tint: theme.currentAccentTintColor,
                    fill: theme.currentAccentFill
                )
                .matchedGeometryEffect(id: "core-orb", in: heroNamespace)
                .frame(width: 260, height: 260)
                .scaleEffect(orbScale)

                practiceOrbCenterMark
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
            .frame(height: 270)

            Spacer(minLength: 12)

            if phase == .feedback {
                VStack(spacing: 8) {
                    Text(feedbackVerdictTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(feedbackFocusLine)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 300)
                .frame(minHeight: 56, alignment: .top)
                .padding(.bottom, 4)
            } else {
                Text(practiceStatus)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .id(practiceStatus)
                    .frame(maxWidth: 300)
                    .frame(minHeight: 44, alignment: .top)
                    .padding(.bottom, 4)
            }
        }
    }

    private var orbScale: CGFloat {
        switch orbMode {
        case .idle: return 0.88
        case .cooking: return 0.94
        case .speaking: return 1.02
        case .listening: return speaker.phase == .recording ? 1.04 : 0.98
        case .result: return 1.0
        }
    }

    /// No card frame — text floats above the orb.
    private var phraseBlock: some View {
        VStack(spacing: 10) {
            Text(phraseRU)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text(phrasePhonetic)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(theme.currentAccentFill)
                .lineLimit(1)
            // First-entry: phonetic is the readable signal. Thai script stays for later lessons.
            if phase != .feedback {
                Text(phraseThai)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    private var practiceOrbCenterMark: some View {
        switch orbMode {
        case .result:
            Text("\(overallScore)%")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .shadow(color: theme.currentAccentTintColor.opacity(0.55), radius: 16)
        case .speaking:
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
        case .listening:
            if speaker.phase == .recording {
                Image(systemName: "waveform")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        case .cooking:
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
        case .idle:
            EmptyView()
        }
    }

    private var reinforceHero: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 6) {
                Text("tai")
                    .font(.custom("Onmark Trial", size: 40))
                    .foregroundStyle(PD.ColorToken.text)
                Text("kAAA")
                    .font(.custom("Onmark Trial", size: 40))
                    .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
            }
            .padding(.top, 12)

            Text("твоя персональная кун кру")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .padding(.top, 12)

            Spacer(minLength: 28)

            Text("Всё, чтобы тайский\nначал складываться")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(PD.ColorToken.text)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer(minLength: 36)

            VStack(spacing: 16) {
                OfferValueMarquee(
                    items: OfferValueMarquee.learningChips,
                    tint: theme.currentAccentTintColor,
                    accentFill: theme.currentAccentFill,
                    speed: 26,
                    reverse: false
                )
                OfferValueMarquee(
                    items: OfferValueMarquee.practiceChips,
                    tint: theme.currentAccentTintColor,
                    accentFill: theme.currentAccentFill,
                    speed: 22,
                    reverse: true
                )
            }
            .padding(.horizontal, -24)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var footerSlot: some View {
        VStack(spacing: 12) {
            switch phase {
            case .hook:
                switch introFrame {
                case .brand:
                    primaryCTA("Дальше") { introFrame = .level }
                        .opacity(brandVisible ? 1 : 0)
                        .offset(y: brandVisible ? 0 : 12)
                        .animation(
                            reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.55, dampingFraction: 0.86).delay(0.18),
                            value: brandVisible
                        )
                case .level:
                    primaryCTA("Продолжить") {
                        guard selectedLevel != nil else { return }
                        selectedGender = nil
                        introFrame = .gender
                    }
                case .gender:
                    primaryCTA("Продолжить") {
                        guard let g = selectedGender else { return }
                        speaker.setSmartSpeakerPoliteness(g)
                        selectedPains.removeAll()
                        introFrame = .pain
                    }
                case .pain:
                    primaryCTA(selectedPains.isEmpty ? "Выбери, что знакомо" : "Продолжить · \(selectedPains.count)") {
                        guard !selectedPains.isEmpty else { return }
                        beginCrafting()
                    }
                }
            case .crafting:
                primaryCTA("Подбираю…") { }
                    .opacity(0.55)
            case .phrase:
                primaryCTA("Послушать") {
                    beginListening()
                }
                .opacity(phraseRevealed ? 1 : 0)
            case .listen:
                primaryCTA("Taika говорит…") { }
                    .opacity(0.7)
            case .speak:
                primaryCTA(speakCTATitle) {
                    guard !isPreparingRecording, !isCookingResult else { return }
                    if speaker.phase == .analyzing { return }
                    toggleRecording()
                }
            case .feedback:
                primaryCTA("Что улучшить") { openBreakdownSheet() }
                Button("Далее") { advance(.reinforce) }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .buttonStyle(.plain)
            case .reinforce:
                primaryCTA(TaikaProConfig.introTrialCTAFree) { onRequestPro() }
                Button("Открыть первый урок") { onFinished("course_b_1") }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .buttonStyle(.plain)
                Text(TaikaProConfig.introTrialLegalLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
        }
        .animation(transition, value: phase)
    }

    private var speakCTATitle: String {
        if isPreparingRecording { return "Подготовка…" }
        if speaker.phase == .recording { return "Остановить" }
        if isCookingResult || speaker.phase == .analyzing { return "Подсказываю…" }
        return "Говорить"
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
        introFrame = .brand
        selectedLevel = nil
        selectedGender = nil
        selectedPains.removeAll()
        brandVisible = false
        brandLogoPulse = 1
        brandCursorOn = true
        phraseRevealed = false
        isCookingResult = false
        showBreakdownSheet = false
    }

    private func runBrandReveal() {
        brandVisible = false
        brandLogoPulse = 1
        if reduceMotion {
            brandVisible = true
            return
        }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.86).delay(0.05)) {
            brandVisible = true
        }
        withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
            brandLogoPulse = 1.025
        }
    }

    private func advance(_ next: Phase) {
        if next != .feedback { lockedFeedbackScore = nil }
        withAnimation(transition) { phase = next }
    }

    private func ensurePracticePhrase() {
        if let g = selectedGender {
            speaker.setSmartSpeakerPoliteness(g)
        }
        let seed = practiceSeed
        speaker.seedConversationPracticePhrase(
            thai: seed.thai,
            phonetic: seed.phonetic,
            ru: seed.ru
        )
    }

    private func openBreakdownSheet() {
        showBreakdownSheet = true
        speaker.requestToneBreakdownFromAPI(
            expectedThaiForAssess: phraseThai,
            expectedPhoneticForTones: phrasePhonetic
        ) { }
    }

    /// After questionnaire: orb cooks, then phrase floats in.
    private func beginCrafting() {
        craftTask?.cancel()
        phraseRevealed = false
        ensurePracticePhrase()
        withAnimation(transition) { phase = .crafting }

        craftTask = Task { @MainActor in
            let cookNs: UInt64 = reduceMotion ? 350_000_000 : 1_550_000_000
            try? await Task.sleep(nanoseconds: cookNs)
            guard !Task.isCancelled, phase == .crafting else { return }

            withAnimation(transition) { phraseRevealed = true }
            try? await Task.sleep(nanoseconds: reduceMotion ? 120_000_000 : 480_000_000)
            guard !Task.isCancelled, phase == .crafting else { return }
            withAnimation(transition) { phase = .phrase }
        }
    }

    private func beginListening() {
        listenTask?.cancel()
        ensurePracticePhrase()
        playReference()
        withAnimation(transition) { phase = .listen }

        listenTask = Task { @MainActor in
            // Give the orb time to "speak" the phrase — don't rush to mic.
            let speakNs: UInt64 = reduceMotion ? 900_000_000 : 2_800_000_000
            try? await Task.sleep(nanoseconds: speakNs)
            guard !Task.isCancelled, phase == .listen else { return }

            withAnimation(transition) { phase = .speak }
        }
    }

    private func playReference() {
        ensurePracticePhrase()
        hasPlayedPhrase = speaker.playReferenceConversationExpectedIfNeeded()
            || {
                speaker.playConversationTTS()
                return true
            }()
    }

    private func presentFeedbackAfterCook() {
        resultTask?.cancel()
        isPreparingRecording = false
        withAnimation(transition) { isCookingResult = true }

        resultTask = Task { @MainActor in
            let cookNs: UInt64 = reduceMotion ? 200_000_000 : 1_100_000_000
            try? await Task.sleep(nanoseconds: cookNs)
            guard !Task.isCancelled else { return }
            lockedFeedbackScore = max(0, speaker.heardConfidence)
            withAnimation(transition) {
                isCookingResult = false
                phraseRevealed = true
                phase = .feedback
            }
        }
    }

    private func toggleRecording() {
        if speaker.phase == .recording {
            recordingTask?.cancel()
            isPreparingRecording = false
            speaker.stopConversationPronunciationCheck()
            return
        }

        isPreparingRecording = true
        ensurePracticePhrase()
        let started = speaker.startConversationPronunciationCheck()
        if !started || speaker.phase != .recording {
            isPreparingRecording = false
        }
    }

    private func scheduleRecordingAutoStop() {
        recordingTask?.cancel()
        recordingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled, phase == .speak, speaker.phase == .recording else { return }
            speaker.stopConversationPronunciationCheck()
        }
    }

    private func repeatWithHint() {
        resultTask?.cancel()
        isCookingResult = false
        ensurePracticePhrase()
        withAnimation(transition) { phase = .speak }
        isPreparingRecording = true
        let started = speaker.startConversationPronunciationCheck()
        if !started || speaker.phase != .recording {
            isPreparingRecording = false
        }
    }
}

private enum OnboardingPracticePhrase {
    static func seed(level: Int, politeness: String) -> (thai: String, phonetic: String, ru: String) {
        let male = politeness == "male"
        let pThai = male ? "ครับ" : "ค่ะ"
        let pPh = male ? "кра́п" : "ка̂"

        switch level {
        case 0:
            return ("ไม่เผ็ด", "май→ пхет↘", "Без острого")
        case 1:
            return ("ขอบคุณ\(pThai)", "коп-ку́н \(pPh)", "Спасибо")
        default:
            return ("ขอโทษ\(pThai)", "хо̂-то̂т \(pPh)", "Извините")
        }
    }
}

private struct OnboardingToneSparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let scale = max(maxV - minV, 1)
        let r = rect.insetBy(dx: 2, dy: 1)
        for (i, y) in values.enumerated() {
            let x = r.minX + CGFloat(i) / CGFloat(max(1, values.count - 1)) * r.width
            let yNorm = 1 - CGFloat((y - minV) / scale)
            let point = CGPoint(x: x, y: yNorm * r.height + r.minY)
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        return path
    }
}

private struct OnboardingToneSparkline: View {
    let values: [Double]
    var muted: Bool = false
    var lineWidth: CGFloat = 2.4
    @ObservedObject private var theme = ThemeManager.shared
    @State private var progress: CGFloat = 0

    var body: some View {
        OnboardingToneSparklineShape(values: values)
            .trim(from: 0, to: progress)
            .stroke(
                muted
                    ? AnyShapeStyle(Color.white.opacity(0.35))
                    : AnyShapeStyle(theme.currentAccentFill),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .onAppear {
                progress = 0
                withAnimation(.easeInOut(duration: muted ? 0.75 : 1.05)) {
                    progress = 1
                }
            }
    }
}

private struct OnboardingBreakdownSheet: View {
    let words: Int
    let tone: Int
    let syllables: [SpeakerManager.SyllableFeedback]
    let hint: String
    let phraseRU: String
    let phrasePhonetic: String
    let loading: Bool

    @ObservedObject private var theme = ThemeManager.shared

    private var phoneticChunks: [String] {
        Self.chunks(from: phrasePhonetic)
    }

    private var focusTitle: String {
        if tone + 12 < words { return "Смотри тоны" }
        if words + 12 < tone { return "Смотри слова" }
        return "Смотри слоги"
    }

    private var focusBody: String {
        if tone + 12 < words {
            return "Слова уже читаются. Главный рычаг сейчас — тоны на каждом слоге."
        }
        if words + 12 < tone {
            return "Тоны живые. Сделай слоги чуть чётче — и фраза соберётся."
        }
        return "Посмотри график и слоги: где линия совпала — держи, где нет — повтори."
    }

    private var referenceContour: [Double] {
        phoneticChunks.flatMap { Self.referenceSegment(for: Self.toneFromChunk($0)) }
    }

    private var userContour: [Double] {
        syllables.flatMap { $0.f0Contour ?? [] }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(focusTitle)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(PD.ColorToken.text)
                        Text(focusBody)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(phraseRU)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(PD.ColorToken.text)
                        Text(phrasePhonetic)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.currentAccentFill)
                    }

                    if referenceContour.count >= 2 || userContour.count >= 2 {
                        toneGraphBlock
                    }

                    if loading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Смотрю слоги…")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary)
                        }
                        .padding(.top, 4)
                    } else if syllables.isEmpty {
                        Text("Пока без послогового разбора — опирайся на общий результат и попробуй ещё в уроке.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    } else {
                        Text("По слогам")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(PD.ColorToken.textSecondary)

                        VStack(spacing: 10) {
                            ForEach(Array(syllables.enumerated()), id: \.element.id) { index, item in
                                syllableRow(item, label: labelForSyllable(at: index, fallback: item.syllable))
                            }
                        }
                    }

                    if !hint.isEmpty, !hint.lowercased().hasPrefix("оценка") {
                        Text(hint)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                }
                .padding(22)
            }
            .background(PD.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Разбор")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var toneGraphBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("График тона")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(PD.ColorToken.textSecondary)

            if referenceContour.count >= 2 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Эталон")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                    OnboardingToneSparkline(values: referenceContour, muted: true)
                        .frame(height: 30)
                }
            }

            if userContour.count >= 2 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ты сказал")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                    OnboardingToneSparkline(values: userContour)
                        .frame(height: 30)
                }
            }

            if !phoneticChunks.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(phoneticChunks.enumerated()), id: \.offset) { _, chunk in
                        Text(Self.stripToneMarks(chunk))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PD.ColorToken.chip)
        )
    }

    private func syllableRow(_ item: SpeakerManager.SyllableFeedback, label: String) -> some View {
        let status = syllableStatus(item.score)
        return HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(status.color.opacity(0.9))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(PD.ColorToken.text)
                Text(status.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                if let tip = toneTip(expected: item.toneExpected, actual: item.toneActual) {
                    Text(tip)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.currentAccentFill)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PD.ColorToken.chip)
        )
    }

    private func labelForSyllable(at index: Int, fallback: String) -> String {
        if index < phoneticChunks.count {
            return Self.stripToneMarks(phoneticChunks[index])
        }
        // Never show Thai script in onboarding breakdown — phonetic only.
        if fallback.unicodeScalars.contains(where: { $0.value >= 0x0E00 && $0.value <= 0x0E7F }) {
            return "слог \(index + 1)"
        }
        return Self.stripToneMarks(fallback)
    }

    private func syllableStatus(_ score: Int) -> (label: String, color: Color) {
        if score >= 80 { return ("Держи так", Color.green.opacity(0.85)) }
        if score >= 55 { return ("Почти — ещё раз", theme.currentAccentTintColor) }
        return ("Вот сюда внимание", Color.orange.opacity(0.9))
    }

    private func toneTip(expected: String?, actual: String?) -> String? {
        let exp = toneRU(expected)
        let act = toneRU(actual)
        guard !exp.isEmpty, !act.isEmpty else { return nil }
        if exp == act { return "Тон \(exp) — верно" }
        return "Нужен \(exp), сейчас \(act)"
    }

    private func toneRU(_ raw: String?) -> String {
        switch (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "mid", "middle", "m": return "средний"
        case "low", "l": return "низкий"
        case "falling", "fall", "f": return "падающий"
        case "high", "h": return "высокий"
        case "rising", "rise", "r": return "восходящий"
        case "": return ""
        default: return (raw ?? "").lowercased()
        }
    }

    private static func chunks(from phonetic: String) -> [String] {
        phonetic
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
            .flatMap { word in
                word.split(omittingEmptySubsequences: true) { "-·".contains($0) }
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
    }

    private static func stripToneMarks(_ label: String) -> String {
        let arrows = CharacterSet(charactersIn: "↘↗→−↓↑↔—")
        return label.unicodeScalars.filter { !arrows.contains($0) }.map(String.init).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func toneFromChunk(_ chunk: String) -> String {
        if chunk.contains("↘") { return "Falling" }
        if chunk.contains("↗") { return "Rising" }
        if chunk.contains("→") { return "Mid" }
        if chunk.contains("↓") { return "Low" }
        if chunk.contains("↑") { return "High" }
        return "Mid"
    }

    private static func referenceSegment(for tone: String) -> [Double] {
        let n = 8
        switch tone {
        case "Low": return (0..<n).map { _ in -2.0 }
        case "High": return (0..<n).map { _ in 2.0 }
        case "Falling": return (0..<n).map { 2.0 - 4.0 * Double($0) / Double(n - 1) }
        case "Rising": return (0..<n).map { -2.0 + 4.0 * Double($0) / Double(n - 1) }
        default: return (0..<n).map { _ in 0.0 }
        }
    }
}

private struct OfferValueMarquee: View {
    let items: [String]
    let tint: Color
    let accentFill: LinearGradient
    let speed: CGFloat
    let reverse: Bool

    @State private var rowWidth: CGFloat = 0

    static let learningChips: [String] = [
        "курсы",
        "тоны",
        "спикер",
        "самоучитель",
        "кун кру",
        "живой тайский",
        "под твой уровень",
        "слова",
        "фразы",
        "диалоги",
        "прогресс",
        "персональный путь"
    ]

    static let practiceChips: [String] = [
        "audio recall",
        "разминка",
        "match",
        "закрепление",
        "практика голосом",
        "избранное",
        "проверка тонов",
        "повтор фраз",
        "игры",
        "слушаю → говорю",
        "ежедневная практика",
        "память на фразы"
    ]

    var body: some View {
        Color.clear
            .frame(height: 38)
            .overlay(alignment: .leading) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let shift: CGFloat = {
                        guard rowWidth > 1 else { return 0 }
                        let t = context.date.timeIntervalSinceReferenceDate
                        let raw = CGFloat(t * Double(speed)).truncatingRemainder(dividingBy: rowWidth)
                        return reverse ? (rowWidth - raw) : raw
                    }()

                    HStack(spacing: 0) {
                        chipRow
                            .background(
                                GeometryReader { g in
                                    Color.clear.preference(key: OfferMarqueeWidthKey.self, value: g.size.width)
                                }
                            )
                        chipRow
                            .accessibilityHidden(true)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: -shift)
                }
            }
            .clipped()
            .mask(
                LinearGradient(
                    colors: [.clear, .white, .white, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onPreferenceChange(OfferMarqueeWidthKey.self) { rowWidth = $0 }
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, title in
                offerChip(title, accent: index.isMultiple(of: 2))
            }
        }
        .padding(.trailing, 8)
    }

    private func offerChip(_ title: String, accent: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(accent ? AnyShapeStyle(accentFill) : AnyShapeStyle(PD.ColorToken.text.opacity(0.92)))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                Capsule(style: .continuous)
                    .fill(accent ? AnyShapeStyle(accentFill.opacity(0.16)) : AnyShapeStyle(PD.ColorToken.chip))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        accent ? AnyShapeStyle(accentFill) : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                        lineWidth: accent ? 1.35 : 1.1
                    )
            )
    }
}

private struct OfferMarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct VoiceOrb: View {
    let mode: PracticeOrbMode
    let tint: Color
    let fill: LinearGradient

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var rotation: Double = 0

    private var isWaveActive: Bool {
        switch mode {
        case .speaking, .listening, .cooking: return true
        case .idle, .result: return false
        }
    }

    private var rotationDuration: Double {
        switch mode {
        case .cooking: return 7
        case .speaking: return 11
        case .listening: return 14
        default: return 18
        }
    }

    private var waveAmpBoost: Bool {
        mode == .speaking || mode == .listening
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fill.opacity(mode == .speaking ? 0.34 : 0.22))
                .blur(radius: 28)
                .scaleEffect(breathing ? 1.18 : 0.92)
            Circle()
                .fill(fill.opacity(0.12))
                .frame(width: 230, height: 230)
                .blur(radius: 2)
                .overlay(Circle().stroke(AnyShapeStyle(fill.opacity(0.35)), lineWidth: 1))
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.14), tint.opacity(0.10), .black.opacity(0.78)], center: UnitPoint(x: 0.35, y: 0.28), startRadius: 4, endRadius: 118))
                .frame(width: 192, height: 192)
                .overlay(Circle().stroke(AnyShapeStyle(fill), lineWidth: mode == .speaking ? 2.0 : 1.4).opacity(0.85))
                .shadow(color: tint.opacity(mode == .cooking ? 0.5 : (mode == .result ? 0.48 : 0.34)), radius: mode == .cooking || mode == .result ? 34 : 26)
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.16), .clear], center: .center, startRadius: 2, endRadius: 66))
                .frame(width: 132, height: 132)
                .blur(radius: 8)
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .trim(from: 0.06 + CGFloat(index) * 0.17, to: 0.27 + CGFloat(index) * 0.17)
                    .stroke(AnyShapeStyle(fill.opacity(0.55 - Double(index) * 0.08)), style: StrokeStyle(lineWidth: index == 0 ? 2.2 : 1.1, lineCap: .round))
                    .frame(width: 208 + CGFloat(index) * 18, height: 208 + CGFloat(index) * 18)
                    .rotationEffect(.degrees(rotation + Double(index) * 92))
            }
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(fill)
                    .frame(width: index == 0 ? 5 : 2.5, height: index == 0 ? 5 : 2.5)
                    .shadow(color: tint.opacity(0.9), radius: 7)
                    .offset(y: -122)
                    .rotationEffect(.degrees(Double(index) * 51.4 + rotation * 0.35))
                    .opacity(index.isMultiple(of: 2) ? 0.82 : 0.38)
            }
            ForEach(0..<5, id: \.self) { index in
                WaveformLine(tint: tint, active: isWaveActive, intense: waveAmpBoost)
                    .frame(height: 92 + CGFloat(index) * 15)
                    .opacity(0.20 + Double(index) * 0.14)
                    .scaleEffect(x: 0.92 + CGFloat(index) * 0.06, y: mode == .speaking ? 1.12 : 1, anchor: .center)
            }
            Circle()
                .fill(fill)
                .frame(width: 8, height: 8)
                .shadow(color: tint.opacity(0.95), radius: 14)
        }
        .frame(width: 300, height: 300)
        .onAppear { startMotion() }
        .onChange(of: mode) { _, _ in startMotion() }
    }

    private func startMotion() {
        guard !reduceMotion else { return }
        breathing = false
        rotation = 0
        withAnimation(.easeInOut(duration: mode == .speaking ? 1.4 : 2.4).repeatForever(autoreverses: true)) {
            breathing = true
        }
        withAnimation(.linear(duration: rotationDuration).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}

private struct WaveformLine: View {
    let tint: Color
    let active: Bool
    var intense: Bool = false

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                var path = Path()
                let mid = size.height / 2
                let amp = active ? size.height * (intense ? 0.36 : 0.26) : size.height * 0.14
                let time = CGFloat(timeline.date.timeIntervalSinceReferenceDate)
                let speed: CGFloat = intense ? 3.1 : (active ? 2.0 : 0.75)
                path.move(to: CGPoint(x: 0, y: mid))
                for x in stride(from: CGFloat(0), through: size.width, by: 3) {
                    let t = x / size.width
                    let carrier = sin(t * .pi * 4 + time * speed)
                    let shimmer = sin(t * .pi * 9 - time * 1.35) * 0.16
                    let y = mid + (carrier + shimmer) * amp * (0.42 + 0.58 * sin(t * .pi))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(path, with: .color(tint.opacity(0.9)), lineWidth: active ? (intense ? 2.6 : 2.1) : 1.5)
            }
        }
    }
}
