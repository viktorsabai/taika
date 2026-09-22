import SwiftUI

/// First-entry proof-of-value flow.
/// Attention choreography around one TaikaVoicePlanet: craft → reveal → speak → score.
struct TaikaCoreLoopOnboardingView: View {
    let onFinished: (_ courseId: String) -> Void
    let onOpenHome: () -> Void
    let onRequestPro: () -> Void

    init(
        onFinished: @escaping (_ courseId: String) -> Void,
        onOpenHome: @escaping () -> Void = {},
        onRequestPro: @escaping () -> Void = {}
    ) {
        self.onFinished = onFinished
        self.onOpenHome = onOpenHome
        self.onRequestPro = onRequestPro
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var speaker = SpeakerManager.shared
    @ObservedObject private var pro = ProManager.shared

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
    @State private var analyzeWatchdogTask: Task<Void, Never>?
    @State private var isPreparingRecording = false
    @State private var accessCoach: String? = nil
    @State private var accessCoachTitle: String? = nil
    @State private var permissionTask: Task<Void, Never>?
    @State private var phraseRevealed = false
    @State private var isCookingResult = false
    @State private var isBurstingReveal = false
    @State private var onboardingBurstProgress: CGFloat = 0
    @State private var showBreakdownSheet = false
    @State private var brandVisible = false
    /// After reference audio plays, user can advance from listen without waiting for auto-jump.
    @State private var listenReadyToSpeak = false
    /// After a missed/empty take, ignore late ASR `.feedback` until the user starts recording again.
    @State private var suppressFeedbackUntilNextRecord = false

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

    private var orbMode: TaikaVoicePlanetMode {
        if isBurstingReveal { return .burst }
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

    private var onboardingOrbAudioLevel: CGFloat {
        if speaker.phase == .recording { return CGFloat(speaker.recordingMeter) }
        return 0
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

    /// Итог тот же, что в спикере: hybrid с сервера, иначе min(текст, тон). Пока тона нет — это текст.
    private var overallScore: Int {
        max(0, speaker.displayScore)
    }

    private var practiceEyebrow: String {
        switch phase {
        case .crafting: return "ПОДБИРАЮ ФРАЗУ"
        case .phrase: return "ТВОЯ ПЕРВАЯ ФРАЗА"
        case .listen: return "TAIKA ГОВОРИТ"
        case .speak:
            if let accessCoachTitle { return accessCoachTitle }
            if isCookingResult || speaker.phase == .analyzing { return "СЧИТАЮ РЕЗУЛЬТАТ" }
            if speaker.phase == .recording { return "СЛУШАЮ ТЕБЯ" }
            if isPreparingRecording { return "НУЖЕН ДОСТУП" }
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
            return "Слушай тоны — можно включить ещё раз"
        case .speak:
            if let accessCoach { return accessCoach }
            if isPreparingRecording { return "Одну секунду — готовлю доступ…" }
            if speaker.phase == .recording { return "Говори спокойно — я ловлю тоны" }
            if isCookingResult || speaker.phase == .analyzing { return "Собираю разбор…" }
            if !captureAccessGranted { return "Сначала микрофон и речь. Потом скажешь фразу." }
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
            PD.ColorToken.background
                .ignoresSafeArea()

            if isPracticeStage || (phase == .hook && introFrame == .brand) {
                TaikaTechnoSpaceBackdrop(
                    intensity: isPracticeStage ? 0.44 : 0.34,
                    isLive: speaker.phase == .recording,
                    audioLevel: onboardingOrbAudioLevel,
                    heroAnchor: UnitPoint(x: 0.5, y: phase == .hook ? 0.42 : 0.48)
                )
                .ignoresSafeArea()
            }

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
            SpeakerDSRoot(
                liveBreakdownFrom: speaker,
                isProUser: pro.isPro,
                hasFullToneBreakdownAccess: true,
                showBreakdownOverlay: $showBreakdownSheet
            )
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Theme.Colors.backgroundPrimary)
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
            permissionTask?.cancel()
            analyzeWatchdogTask?.cancel()
            // Shared SpeakerManager must not keep the demo phrase / recording focus after first-entry.
            speaker.endEphemeralPracticeSession()
        }
        .onChange(of: speaker.phase) { _, newPhase in
            if phase == .speak, newPhase == .recording {
                isPreparingRecording = false
                suppressFeedbackUntilNextRecord = false
                clearAccessCoach()
                scheduleRecordingAutoStop()
            }
            if newPhase == .idle {
                isPreparingRecording = false
            }
            guard phase == .speak else { return }
            if newPhase == .analyzing {
                scheduleAnalyzeWatchdog()
            }
            if newPhase == .hint {
                // Системные окна доступа не должны выглядеть как «не расслышал».
                if isPreparingRecording { return }
                let micMiss = speaker.taikaHints.first { $0.contains("микрофон") }
                recoverSpeakAfterMiss(message: micMiss ?? "Не расслышал — нажми «Говорить» и скажи фразу ещё раз")
            }
            if case .feedback = newPhase {
                recordingTask?.cancel()
                analyzeWatchdogTask?.cancel()
                if suppressFeedbackUntilNextRecord { return }
                presentFeedbackAfterCook()
            }
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
        .id(phase)
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
        TaikaBootAssembleView(
            caption: "твоя персональная кун кру",
            finishesAutomatically: false,
            onWordmarkAppeared: {
                brandVisible = true
            }
        )
        .frame(maxWidth: .infinity)
        .onAppear {
            brandVisible = reduceMotion
        }
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

    @ViewBuilder
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

            TaikaVoicePlanet(
                mode: orbMode,
                scale: orbScale * (phase == .feedback ? 0.72 : 0.87),
                centerText: nil,
                audioLevel: onboardingOrbAudioLevel,
                burstProgress: isBurstingReveal ? onboardingBurstProgress : nil
            )
            .frame(width: phase == .feedback ? 168 : 260, height: phase == .feedback ? 168 : 260)

            Spacer(minLength: 8)

            if phase == .feedback {
                VStack(spacing: 8) {
                    Text(feedbackVerdictTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(PD.ColorToken.text)
                        .multilineTextAlignment(.center)
                    SpeakerTripleScoreHeader(
                        textScore: max(0, speaker.heardConfidence),
                        toneScore: speaker.toneAverageScore,
                        overallScore: max(0, speaker.displayScore),
                        toneLoading: speaker.breakdownRequestInFlight && speaker.toneAverageScore == nil,
                        toneLocked: false,
                        usesHybridOverall: speaker.breakdownHybridScore != nil,
                        layout: .feedback,
                        centered: true
                    )
                    Text(feedbackFocusLine)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 320)
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
        case .idle, .assemble: return 0.88
        case .cooking: return 0.94
        case .burst: return 1.06
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
                .foregroundStyle(PD.ColorToken.text)
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
                    .foregroundStyle(PD.ColorToken.text.opacity(0.70))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 320)
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
                primaryCTA(listenReadyToSpeak ? "Дальше" : "Taika говорит…") {
                    guard listenReadyToSpeak else { return }
                    advanceToSpeakFromListen()
                }
                .opacity(listenReadyToSpeak ? 1 : 0.7)
                secondaryCTA("Послушать ещё раз") {
                    replayReferenceAudio()
                }
            case .speak:
                primaryCTA(speakCTATitle) {
                    guard !isPreparingRecording, !isCookingResult else { return }
                    if speaker.phase == .analyzing { return }
                    handleSpeakCTA()
                }
                .opacity(isCookingResult || speaker.phase == .analyzing ? 0.55 : 1)
                .disabled(isCookingResult || speaker.phase == .analyzing)
                if canReplayReference {
                    secondaryCTA("Послушать ещё раз") {
                        replayReferenceAudio()
                    }
                }
            case .feedback:
                primaryCTA("Что улучшить") { openBreakdownSheet() }
                Button("Далее") { advance(.reinforce) }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .buttonStyle(.plain)
            case .reinforce:
                primaryCTA(TaikaProConfig.introTrialCTAFree) { onRequestPro() }
                Button("Открыть Главную") { onOpenHome() }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .buttonStyle(.plain)
                Button {
                    OverlayPresenter.shared.presentGiftRedeem()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                        Text("У меня есть подарок")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
                Text(TaikaProConfig.introTrialLegalLine)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
            if phase != .reinforce {
                skipLink
            }
        }
        .id(phase)
    }

    private var captureAccessGranted: Bool {
        let recorder = SpeakerRecorder.shared
        return recorder.hasMicrophoneAccess && recorder.hasSpeechAccess
    }

    private var speakCTATitle: String {
        if isPreparingRecording { return "Секунду…" }
        if speaker.phase == .recording { return "Остановить" }
        if isCookingResult || speaker.phase == .analyzing { return "Разбираю фразу…" }
        if !captureAccessGranted { return "Разрешить доступ" }
        return "Говорить"
    }

    private func primaryCTA(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        phraseRevealed = false
        isCookingResult = false
        isBurstingReveal = false
        onboardingBurstProgress = 0
        showBreakdownSheet = false
        listenReadyToSpeak = false
        suppressFeedbackUntilNextRecord = false
        analyzeWatchdogTask?.cancel()
    }

    private func advance(_ next: Phase) {
        phase = next
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
        // Разбор уже запрошен до показа цифры. Повторный запрос переписывал итог с текста на тон.
        showBreakdownSheet = true
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
        listenReadyToSpeak = false
        ensurePracticePhrase()
        playReference()
        withAnimation(transition) { phase = .listen }
        scheduleListenReady()
    }

    private var canReplayReference: Bool {
        guard phase == .speak else { return false }
        if isPreparingRecording || isCookingResult { return false }
        if speaker.phase == .recording || speaker.phase == .analyzing { return false }
        return true
    }

    private func secondaryCTA(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    private var skipLink: some View {
        Button("Пропустить") { skipToOffer() }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .buttonStyle(.plain)
            .accessibilityLabel("Пропустить онбординг")
            .accessibilityHint("Перейти к семи дням бесплатно")
    }

    private func skipToOffer() {
        recordingTask?.cancel()
        listenTask?.cancel()
        craftTask?.cancel()
        resultTask?.cancel()
        permissionTask?.cancel()
        analyzeWatchdogTask?.cancel()
        showBreakdownSheet = false
        speaker.endEphemeralPracticeSession()
        if selectedGender == nil {
            selectedGender = "female"
        }
        if let g = selectedGender {
            speaker.setSmartSpeakerPoliteness(g)
        }
        withAnimation(transition) { phase = .reinforce }
    }

    private func scheduleListenReady() {
        listenTask?.cancel()
        listenTask = Task { @MainActor in
            let speakNs: UInt64 = reduceMotion ? 900_000_000 : 2_400_000_000
            try? await Task.sleep(nanoseconds: speakNs)
            guard !Task.isCancelled, phase == .listen else { return }
            withAnimation(transition) { listenReadyToSpeak = true }
            // Soft auto-advance; replay stays available before that.
            try? await Task.sleep(nanoseconds: reduceMotion ? 400_000_000 : 1_200_000_000)
            guard !Task.isCancelled, phase == .listen else { return }
            advanceToSpeakFromListen()
        }
    }

    private func advanceToSpeakFromListen() {
        listenTask?.cancel()
        listenReadyToSpeak = true
        withAnimation(transition) { phase = .speak }
    }

    private func replayReferenceAudio() {
        guard phase == .listen || phase == .speak else { return }
        guard speaker.phase != .recording, speaker.phase != .analyzing else { return }
        playReference()
        if phase == .listen {
            listenReadyToSpeak = false
            scheduleListenReady()
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

    /// Empty / failed ASR must not leave onboarding stuck on «Подсказываю…».
    private func recoverSpeakAfterMiss(
        message: String = "Не расслышал — нажми «Говорить» и скажи фразу ещё раз"
    ) {
        recordingTask?.cancel()
        resultTask?.cancel()
        analyzeWatchdogTask?.cancel()
        permissionTask?.cancel()
        isCookingResult = false
        isBurstingReveal = false
        isPreparingRecording = false
        onboardingBurstProgress = 0
        suppressFeedbackUntilNextRecord = true
        accessCoachTitle = "НЕ РАССЛЫШАЛ"
        accessCoach = message
        phase = .speak
    }

    private func scheduleAnalyzeWatchdog() {
        analyzeWatchdogTask?.cancel()
        analyzeWatchdogTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000_000)
            guard !Task.isCancelled, phase == .speak else { return }
            if case .feedback = speaker.phase { return }
            let stuckAnalyzing = speaker.phase == .analyzing || isCookingResult
            guard stuckAnalyzing else { return }
            recoverSpeakAfterMiss(message: "Разбор затянулся — давай ещё раз. Нажми «Говорить».")
        }
    }

    private func presentFeedbackAfterCook() {
        resultTask?.cancel()
        analyzeWatchdogTask?.cancel()
        isPreparingRecording = false
        isBurstingReveal = false
        isCookingResult = false
        guard !suppressFeedbackUntilNextRecord, phase == .speak else { return }
        speaker.refreshUserPhoneticFromASRIfNeeded()
        speaker.requestToneBreakdownFromAPI(
            expectedThaiForAssess: phraseThai,
            expectedPhoneticForTones: phrasePhonetic
        ) { }
        phraseRevealed = true
        phase = .feedback
    }

    private func handleSpeakCTA() {
        if speaker.phase == .recording {
            recordingTask?.cancel()
            permissionTask?.cancel()
            isPreparingRecording = false
            clearAccessCoach()
            speaker.stopConversationPronunciationCheck()
            return
        }
        if !captureAccessGranted {
            requestCaptureAccess()
            return
        }
        beginSpeakRecording()
    }

    /// Системные окна сначала. Запись не стартует, пока человек сам не нажмёт «Говорить».
    private func requestCaptureAccess() {
        permissionTask?.cancel()
        isPreparingRecording = true
        ensurePracticePhrase()
        permissionTask = Task { @MainActor in
            let ready = await ensureCaptureAccessWithCoach()
            guard !Task.isCancelled, phase == .speak else {
                isPreparingRecording = false
                return
            }
            isPreparingRecording = false
            guard ready else { return }
            SpeakerRecorder.shared.prepareRecordSession()
            withAnimation(transition) {
                accessCoachTitle = "ГОТОВО"
                accessCoach = "Теперь нажми «Говорить» и скажи фразу."
            }
        }
    }

    private func beginSpeakRecording() {
        permissionTask?.cancel()
        isPreparingRecording = false
        clearAccessCoach()
        ensurePracticePhrase()
        SpeakerRecorder.shared.prepareRecordSession()
        let started = speaker.startConversationPronunciationCheck()
        if !started, speaker.phase != .recording {
            isPreparingRecording = false
        }
    }

    /// Soft Kun Kru coach: mic → speech. Does not record.
    @MainActor
    private func ensureCaptureAccessWithCoach() async -> Bool {
        let recorder = SpeakerRecorder.shared

        if !recorder.hasMicrophoneAccess {
            withAnimation(transition) {
                accessCoachTitle = "СЕКУНДУ"
                accessCoach = "Мне нужен микрофон — иначе не услышу тебя."
            }
            let micOK = await recorder.requestMicrophoneAccess()
            guard micOK else {
                withAnimation(transition) {
                    accessCoachTitle = "БЕЗ МИКРОФОНА"
                    accessCoach = "Разреши микрофон в Настройках — и продолжим."
                }
                return false
            }
        }

        if !recorder.hasSpeechAccess {
            withAnimation(transition) {
                accessCoachTitle = "И ЕЩЁ ОДНО"
                accessCoach = "Нужен доступ к речи — так я разберу тоны."
            }
            let speechOK = await recorder.requestSpeechAccess()
            guard speechOK else {
                withAnimation(transition) {
                    accessCoachTitle = "НУЖНА РЕЧЬ"
                    accessCoach = "Без распознавания речи не соберу разбор. Разреши доступ и нажми снова."
                }
                return false
            }
        }

        return true
    }

    private func clearAccessCoach() {
        accessCoach = nil
        accessCoachTitle = nil
    }

    private func scheduleRecordingAutoStop() {
        recordingTask?.cancel()
        recordingTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled, phase == .speak, speaker.phase == .recording else { return }
            speaker.stopConversationPronunciationCheck()
        }
    }

    private func repeatWithHint() {
        resultTask?.cancel()
        isCookingResult = false
        isBurstingReveal = false
        onboardingBurstProgress = 0
        ensurePracticePhrase()
        withAnimation(transition) { phase = .speak }
        if !captureAccessGranted {
            requestCaptureAccess()
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
