//
//  TaikaLearnOnboardingView.swift
//  taika
//
//  Первый вход = мини-урок + демо разбора.
//  Один stage: title / hero / footer — слоты не двигаются между шагами.
//  Splash → дверь → фраза → разбор → курсы → закрепление → Taika+ → LessonsView.
//

import SwiftUI
import Speech

enum TaikaStartDoor: String, Equatable {
    case beginner
    case speaking
    case living

    static let storageKey = "taika.onboarding.startDoor.v1"

    var persist: Void {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }
}

struct TaikaLearnOnboardingView: View {
    let onFinished: (_ courseId: String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var overlay = OverlayPresenter.shared
    @ObservedObject private var pro = ProManager.shared

    @State private var step: Step = .door
    @State private var appeared = false
    @State private var phraseHeard = false
    @State private var listenAnimating = false
    @State private var didAutoplay = false
    @State private var speakPhase: SpeakPhase = .idle
    @State private var heardThai: String = ""
    @State private var pulseMic = false
    @State private var doorIndex = 0
    @State private var catalogIndex = 0
    @State private var reinforceIndex = 0
    @State private var catalogPausedUntil: Date = .distantPast
    @State private var pickedCourseId: String = "course_b_1"
    @State private var offeredPlus = false
    @State private var didFinish = false
    @State private var breakdownIsDemo = true

    /// Единая геометрия сцены — не менять между шагами.
    private enum Stage {
        static let titleH: CGFloat = 86
        static let heroH: CGFloat = 320
        static let footerH: CGFloat = 128
        static let card = CGSize(width: 268, height: 300)
    }

    private enum Canon {
        static let thai = MainInstantSpeakerDemo.thai
        static let phonetic = MainInstantSpeakerDemo.phonetic
        static let ru = MainInstantSpeakerDemo.ru
    }

    private enum Step: Equatable {
        case door
        case phrase
        case breakdown
        case catalog
        case reinforce
        case plus
    }

    private enum SpeakPhase: Equatable {
        case idle
        case recording
        case checking
        case understood
        case mismatch
        case unheard
        case denied
    }

    var body: some View {
        ZStack {
            WelcomeSpaceBackdropView()
            Circle()
                .fill(theme.currentAccentTintColor.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 72)
                .offset(y: 40)
                .allowsHitTesting(false)

            // Один каркас на весь онбординг — слоты фиксированы.
            VStack(spacing: 0) {
                titleSlot
                    .frame(height: Stage.titleH)
                    .padding(.horizontal, 20)

                Spacer(minLength: 0)

                heroSlot
                    .frame(height: Stage.heroH)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                footerSlot
                    .frame(height: Stage.footerH, alignment: .top)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(appeared ? 1 : 0)
            .safeAreaPadding(.top)
            .safeAreaPadding(.bottom)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.35)) {
                appeared = true
            }
            _ = CourseData.shared.load()
        }
        .onChange(of: overlay.overlay) { _, newValue in
            if offeredPlus, newValue == nil {
                finish()
            }
        }
        .onChange(of: step) { _, newStep in
            if newStep == .catalog {
                let count = showcaseCourses.count
                if count > 1, catalogIndex < count {
                    catalogIndex = count
                }
            }
        }
        .task(id: step) {
            guard step == .catalog, !reduceMotion else { return }
            let count = showcaseCourses.count
            guard count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_700_000_000)
                guard step == .catalog, Date() >= catalogPausedUntil else { continue }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        catalogIndex += 1
                    }
                    if catalogIndex >= count * 2 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
                            catalogIndex = count + (catalogIndex % max(1, count))
                        }
                    }
                }
            }
        }
    }

    private var contentMotion: Animation? {
        reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: 0.28)
    }

    // MARK: - Fixed slots

    private var titleSlot: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(stageTitle)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Text(stageSubtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(stageSubtitle.isEmpty ? 0 : 0.58))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(contentMotion, value: step)
        .animation(nil, value: speakPhase)
    }

    private var stageTitle: String {
        switch step {
        case .door: return "Какой у тебя тайский?"
        case .phrase: return "Начнём с одной фразы"
        case .breakdown:
            return breakdownIsDemo ? "Так выглядит разбор" : "Вот как Taika разбирает"
        case .catalog: return "Сценарии на все случаи"
        case .reinforce: return "Как закреплять"
        case .plus: return "Хочешь больше Taika?"
        }
    }

    private var stageSubtitle: String {
        switch step {
        case .door:
            return "Фразы для жизни. По 3–5 минут в день."
        case .phrase:
            // Высота title-слота фиксирована — меняем только текст, не layout.
            switch speakPhase {
            case .recording: return "Слушаю тебя…"
            case .checking: return "Разбираю…"
            case .unheard: return "Не поймала — давай ещё раз"
            case .mismatch: return "Почти! Повтори «Без острого»"
            case .denied: return "Можно пройти без микрофона"
            default:
                return phraseHeard ? "Скажи: «Без острого»" : "Послушай, потом скажи сам"
            }
        case .breakdown:
            return breakdownIsDemo
                ? "Пример на этой фразе — слова, тон, что поправить."
                : "Слова, тон по слогам и что поправить — сразу."
        case .catalog:
            return "Рынок, такси, храм, кафе — живые курсы."
        case .reinforce:
            return "Тот же язык карточек — разные способы."
        case .plus:
            return "Попробуй Taika+"
        }
    }

    @ViewBuilder
    private var heroSlot: some View {
        ZStack {
            switch step {
            case .door:
                doorHero
            case .phrase:
                phraseHero
            case .breakdown:
                breakdownHero
            case .catalog:
                catalogHero
            case .reinforce:
                reinforceHero
            case .plus:
                plusHero
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .id(step)
        .transition(.opacity)
        .animation(contentMotion, value: step)
    }

    @ViewBuilder
    private var footerSlot: some View {
        Group {
            switch step {
            case .door:
                primaryCTA("это я") {
                    let door = DoorCard.all.indices.contains(doorIndex)
                        ? DoorCard.all[doorIndex].door
                        : TaikaStartDoor.beginner
                    chooseDoor(door)
                }
            case .phrase:
                phraseFooter
            case .breakdown:
                primaryCTA("Дальше") { go(.catalog) }
            case .catalog:
                primaryCTA("Дальше") { go(.reinforce) }
            case .reinforce:
                primaryCTA("Дальше") { go(.plus) }
            case .plus:
                plusFooter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .id(step)
        .transition(.opacity)
        .animation(contentMotion, value: step)
        .animation(nil, value: speakPhase)
    }

    // MARK: - Heroes (все в одном Stage.heroH / Stage.card)

    private var doorHero: some View {
        LearnCoverflow(
            items: DoorCard.all,
            index: $doorIndex,
            cardSize: Stage.card
        ) { item, _ in
            LearnDoorCard(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                chipTitle: item.chip,
                size: Stage.card
            )
        }
    }

    private var phraseHero: some View {
        ZStack(alignment: .bottom) {
            LearnPhraseCard(
                thai: Canon.thai,
                russian: Canon.ru,
                phonetic: Canon.phonetic,
                listening: listenAnimating,
                checking: speakPhase == .checking,
                recording: speakPhase == .recording,
                size: Stage.card,
                onPlay: playPhrase
            )
            .onAppear(perform: autoplayIfNeeded)

            phraseStatusBand
                .frame(height: 28)
                .padding(.bottom, 52)
        }
        .frame(width: Stage.card.width, height: Stage.card.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var phraseStatusBand: some View {
        Group {
            if speakPhase == .mismatch, !heardThai.isEmpty {
                Text("Услышала: \(heardThai)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            } else if speakPhase == .recording {
                Text("Говори уверенно")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var breakdownHero: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LearnBreakdownDemo(
                thai: Canon.thai,
                russian: Canon.ru,
                phonetic: Canon.phonetic,
                onPlay: playPhrase,
                compact: true
            )
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var catalogHero: some View {
        let scale = min(
            Stage.card.width / CardDS.Metrics.courseWidth,
            Stage.card.height / CardDS.Metrics.courseHeight
        )
        let cardSize = CGSize(
            width: CardDS.Metrics.courseWidth * scale,
            height: CardDS.Metrics.courseHeight * scale
        )
        return LearnInfiniteCourseReel(
            courses: showcaseCourses,
            index: $catalogIndex,
            cardSize: cardSize,
            onSelect: { course in
                pickedCourseId = course.courseID
            },
            onUserInteracted: {
                catalogPausedUntil = Date().addingTimeInterval(4)
            }
        )
    }

    private var reinforceHero: some View {
        LearnCoverflow(
            items: ReinforceCard.all,
            index: $reinforceIndex,
            cardSize: Stage.card
        ) { item, _ in
            LearnDoorCard(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                chipTitle: item.chip,
                size: Stage.card
            )
        }
    }

    private var plusHero: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(PlusPerk.all) { perk in
                        plusPerkRow(perk)
                        if perk.id != PlusPerk.all.last?.id {
                            Divider().overlay(Color.white.opacity(0.08))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            .taikaBlackGlassBackground(cornerRadius: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AnyShapeStyle(theme.currentAccentFill.opacity(0.28)), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func plusPerkRow(_ perk: PlusPerk) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(theme.currentAccentTintColor.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: perk.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(perk.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text(perk.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }

    // MARK: - Footers

    @ViewBuilder
    private var phraseFooter: some View {
        VStack(spacing: 6) {
            switch speakPhase {
            case .checking:
                ProgressView()
                    .tint(theme.currentAccentTintColor)
                    .frame(height: 72)
                secondaryLink(" ", action: {})
                    .opacity(0)
                    .disabled(true)
            case .unheard, .mismatch:
                primaryCTA("Ещё раз") { startSpeak() }
                secondaryLink("Показать, как выглядит разбор") {
                    openBreakdown(isDemo: true)
                }
            case .denied:
                Text("Нет доступа к микрофону")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(height: 52)
                secondaryLink("Показать пример разбора") {
                    openBreakdown(isDemo: true)
                }
            default:
                if phraseHeard {
                    micButton
                    Text(speakPhase == .recording ? "Слушаю…" : "Говори")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            speakPhase == .recording
                            ? AnyShapeStyle(theme.currentAccentFill)
                            : AnyShapeStyle(.white.opacity(0.55))
                        )
                    if speakPhase == .idle {
                        secondaryLink("Пропустить — показать пример") {
                            openBreakdown(isDemo: true)
                        }
                    } else {
                        secondaryLink(" ", action: {}).opacity(0).disabled(true)
                    }
                } else {
                    Color.clear.frame(height: 88)
                    secondaryLink(" ", action: {}).opacity(0).disabled(true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            guard !reduceMotion else { return }
            pulseMic = false
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulseMic = true
            }
        }
    }

    private func secondaryLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(height: 22)
        }
        .buttonStyle(.plain)
    }

    private var micButton: some View {
        Button(action: speakPhase == .recording ? stopSpeak : startSpeak) {
            ZStack {
                Circle()
                    .stroke(AnyShapeStyle(theme.currentAccentFill.opacity(0.35)), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .scaleEffect(pulseMic && speakPhase != .recording ? 1.08 : 1)
                    .opacity(pulseMic ? 0.35 : 0.7)
                Circle()
                    .fill(theme.currentAccentFill)
                    .frame(width: 56, height: 56)
                Image(systemName: speakPhase == .recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(white: 0.1))
            }
            .frame(width: 76, height: 76)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(speakPhase == .recording ? "Остановить запись" : "Говорить")
    }

    private var plusFooter: some View {
        VStack(spacing: 8) {
            if pro.isPro {
                primaryCTA("Открыть курс") { finish(courseId: pickedCourseId) }
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    offeredPlus = true
                    overlay.presentProDirect(reason: .general)
                } label: {
                    VStack(spacing: 2) {
                        Text("\(TaikaProConfig.introTrialDaysPhrase) бесплатно")
                            .font(.system(size: 16, weight: .bold))
                        Text("Далее — \(TaikaProConfig.MarketingPrice.monthlyTHB) ฿ / месяц · отмена в любой момент")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(0.65)
                    }
                    .foregroundStyle(Color(white: 0.1))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(theme.currentAccentFill))
                }
                .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))

                secondaryLink("Начать бесплатно") {
                    finish(courseId: pickedCourseId)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func primaryCTA(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(white: 0.1))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(theme.currentAccentFill))
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
    }

    // MARK: - Actions

    private var showcaseCourses: [Course] {
        let all = CourseData.shared.courses
        let scenarios = all.filter { $0.category != "База от Тайки" }
        let base = all.filter { $0.category == "База от Тайки" }
        let ordered = scenarios + base
        return ordered.isEmpty ? all : ordered
    }

    private func go(_ next: Step) {
        withAnimation(contentMotion) {
            step = next
        }
    }

    private func openBreakdown(isDemo: Bool) {
        breakdownIsDemo = isDemo
        go(.breakdown)
    }

    private func chooseDoor(_ door: TaikaStartDoor) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        door.persist
        go(.phrase)
    }

    private func autoplayIfNeeded() {
        guard !didAutoplay else { return }
        didAutoplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            playPhrase()
        }
    }

    private func playPhrase() {
        phraseHeard = true
        listenAnimating = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        StepAudio.shared.speakThai(Canon.thai)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            listenAnimating = false
        }
    }

    private func startSpeak() {
        heardThai = ""
        SpeakerRecorder.shared.requestPermission { ok in
            guard ok else {
                speakPhase = .denied
                return
            }
            Self.requestSpeechAuth { speechOk in
                guard speechOk else {
                    speakPhase = .denied
                    return
                }
                SpeakerRecorder.shared.start { url in
                    guard url != nil else {
                        speakPhase = .denied
                        return
                    }
                    speakPhase = .recording
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                        if speakPhase == .recording {
                            stopSpeak()
                        }
                    }
                }
            }
        }
    }

    private func stopSpeak() {
        let url = SpeakerRecorder.shared.stop()
        speakPhase = .checking
        Task { @MainActor in
            let heard = await Self.recognizeThai(url: url)
            let trimmed = heard.trimmingCharacters(in: .whitespacesAndNewlines)
            heardThai = trimmed
            if trimmed.isEmpty {
                speakPhase = .unheard
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else if Self.matchesCanon(trimmed) {
                speakPhase = .understood
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                openBreakdown(isDemo: false)
            } else {
                speakPhase = .mismatch
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
    }

    private static func matchesCanon(_ raw: String) -> Bool {
        let compact = raw.replacingOccurrences(of: " ", with: "")
        if compact.contains("ไม่เผ็ด") { return true }
        if compact.contains("เผ็ด") { return true }
        if compact.contains("ไม่") && (compact.contains("เผ") || compact.contains("แปล") || compact.contains("เพ")) {
            return true
        }
        let folded = compact.lowercased()
        if folded.contains("maiphet") || folded.contains("maipet") { return true }
        if folded.contains("mai") && (folded.contains("phet") || folded.contains("pet") || folded.contains("plaek")) {
            return true
        }
        return false
    }

    private static func requestSpeechAuth(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized {
            completion(true)
            return
        }
        if status == .denied || status == .restricted {
            completion(false)
            return
        }
        SFSpeechRecognizer.requestAuthorization { newStatus in
            DispatchQueue.main.async {
                completion(newStatus == .authorized)
            }
        }
    }

    private func finish(courseId: String? = nil) {
        guard !didFinish else { return }
        didFinish = true
        TaikaProductDemoFlags.markCourseSeen()
        onFinished(courseId ?? pickedCourseId)
    }

    private static func recognizeThai(url: URL?) async -> String {
        guard let url else { return "" }
        let auth = SFSpeechRecognizer.authorizationStatus()
        if auth != .authorized {
            let granted: Bool = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
            if !granted { return "" }
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH")) else { return "" }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        return await withCheckedContinuation { cont in
            var done = false
            var lastText = ""
            recognizer.recognitionTask(with: request) { result, error in
                if let text = result?.bestTranscription.formattedString, !text.isEmpty {
                    lastText = text
                }
                guard !done else { return }
                if result?.isFinal == true || error != nil {
                    done = true
                    cont.resume(returning: lastText)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                guard !done else { return }
                done = true
                cont.resume(returning: lastText)
            }
        }
    }
}

// MARK: - Models

private struct DoorCard: Identifiable {
    let id: String
    let door: TaikaStartDoor
    let icon: String
    let chip: String
    let title: String
    let subtitle: String

    static let all: [DoorCard] = [
        .init(id: "beginner", door: .beginner, icon: "leaf.fill", chip: "начало", title: "Начинаю с нуля", subtitle: "Хочу базовые фразы"),
        .init(id: "speaking", door: .speaking, icon: "waveform", chip: "речь", title: "Немного говорю", subtitle: "Хочу говорить увереннее"),
        .init(id: "living", door: .living, icon: "sun.max.fill", chip: "жизнь", title: "Уже живу в Таиланде", subtitle: "Хочу больше живых ситуаций")
    ]
}

private struct ReinforceCard: Identifiable {
    let id: String
    let icon: String
    let chip: String
    let title: String
    let subtitle: String

    static let all: [ReinforceCard] = [
        .init(id: "warmup", icon: "flame.fill", chip: "каждый день", title: "Разминка", subtitle: "Умный повтор карточек по утрам"),
        .init(id: "games", icon: "gamecontroller.fill", chip: "игры", title: "Практика", subtitle: "Матч, слоги, аудио — разные памяти"),
        .init(id: "speaker", icon: "waveform.circle.fill", chip: "речь", title: "Спикер", subtitle: "Произношение и тоны вслух"),
        .init(id: "translate", icon: "bubble.left.and.bubble.right.fill", chip: "рядом", title: "Перевод", subtitle: "Скажи по-русски — получишь фразу")
    ]
}

private struct PlusPerk: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String

    static let all: [PlusPerk] = [
        .init(id: "courses", icon: "infinity", title: "Все курсы", subtitle: "40+ курсов для любых ситуаций"),
        .init(id: "speaker", icon: "mic.fill", title: "Спикер без лимитов", subtitle: "Неограниченная практика произношения"),
        .init(id: "tone", icon: "waveform", title: "Тональное караоке", subtitle: "Больше фраз для тренировки тонов"),
        .init(id: "reinforce", icon: "brain.head.profile", title: "Расширенное закрепление", subtitle: "Умные повторения и статистика"),
        .init(id: "ai", icon: "bubble.left.and.text.bubble.right.fill", title: "Практика речи с AI", subtitle: "Перевод в обе стороны и разбор твоей речи")
    ]
}

// MARK: - Demo разбора

private struct LearnBreakdownDemo: View {
    let thai: String
    let russian: String
    let phonetic: String
    let onPlay: () -> Void
    var compact: Bool = false

    @ObservedObject private var theme = ThemeManager.shared
    @State private var showText = false
    @State private var showTone = false
    @State private var showRows = false
    @State private var showHint = false

    private let textScore = 92
    private let toneScore = 68

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("разбор")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button(action: onPlay) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(white: 0.12))
                        .padding(10)
                        .background(Circle().fill(theme.currentAccentFill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Слушать эталон")
            }

            Text(thai)
                .font(.system(size: compact ? 26 : 32, weight: .bold))
                .foregroundStyle(.white)
            Text(russian)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            TaikaPhoneticText.styled(
                phonetic,
                font: .system(size: 16, weight: .semibold),
                baseColor: .white.opacity(0.88)
            )

            HStack(spacing: 10) {
                scoreMetric(title: "Текст", subtitle: "слова", value: textScore, visible: showText)
                scoreMetric(title: "Тон", subtitle: "мелодия", value: toneScore, visible: showTone)
            }

            if showRows {
                VStack(spacing: 6) {
                    syllableRow(
                        label: "май",
                        score: 96,
                        expected: "→",
                        actual: "→",
                        match: true,
                        comment: "Идеальный тон!"
                    )
                    syllableRow(
                        label: "пхет",
                        score: 64,
                        expected: "↘",
                        actual: "→",
                        match: false,
                        comment: "Нужен спад в конце."
                    )
                }
                .transition(.opacity)
            }

            if showHint {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                    Text("На «пхет» тон падает. Послушай эталон и повтори спад.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .transition(.opacity)
            }
        }
        .padding(compact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .taikaBlackGlassBackground(cornerRadius: 22)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AnyShapeStyle(theme.currentAccentFill.opacity(0.45)), lineWidth: 1.2)
        )
        .onAppear { reveal() }
    }

    private func scoreMetric(title: String, subtitle: String, value: Int, visible: Bool) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            if visible {
                TaikaCountingScore(
                    value: value,
                    font: .taikaStat(compact ? 36 : 48),
                    color: AnyShapeStyle(theme.currentAccentFill),
                    suffix: "%"
                )
            } else {
                Text("—")
                    .font(.taikaStat(compact ? 36 : 48))
                    .foregroundStyle(.white.opacity(0.2))
            }
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func syllableRow(
        label: String,
        score: Int,
        expected: String,
        actual: String,
        match: Bool,
        comment: String
    ) -> some View {
        let isGreen = score >= 90
        let fill = isGreen ? Color.green.opacity(0.28) : Color.orange.opacity(0.28)
        let stroke = isGreen ? Color.green.opacity(0.45) : Color.orange.opacity(0.45)
        return HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text("нужно: \(expected)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PD.ColorToken.toneExpected)
                Text("ты: \(actual)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(match ? PD.ColorToken.toneCorrect : PD.ColorToken.toneWrong)
            }
            .frame(width: 58, alignment: .leading)
            Text("\(score)%")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isGreen ? PD.ColorToken.toneCorrect : Color.orange)
                .frame(width: 28, alignment: .trailing)
            Text(comment)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
        )
    }

    private func reveal() {
        withAnimation(.easeOut(duration: 0.35).delay(0.15)) { showText = true }
        withAnimation(.easeOut(duration: 0.35).delay(0.55)) { showTone = true }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86).delay(0.9)) { showRows = true }
        withAnimation(.easeOut(duration: 0.35).delay(1.25)) { showHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}

// MARK: - Phrase card

private struct LearnPhraseCard: View {
    let thai: String
    let russian: String
    let phonetic: String
    let listening: Bool
    var checking: Bool = false
    var recording: Bool = false
    let size: CGSize
    let onPlay: () -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CardDS.Metrics.stepCardContentRadius, style: .continuous)
        let borderOpacity: Double = {
            if checking || recording { return 0.7 }
            if listening { return 0.55 }
            return 0.22
        }()

        ZStack {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    TaikaWordmarkLockup(fontSize: 16)
                    Spacer(minLength: 4)
                    AppMiniChip(title: "фраза", style: .accent)
                }
                .padding(.horizontal, CardDS.Metrics.contentX + CardDS.Metrics.stepCardHeaderEdgeInset)
                .frame(height: CardDS.Metrics.stepCardTopBandHeight)

                VStack(spacing: 10) {
                    Text(thai)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
                    Text(russian)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .minimumScaleFactor(0.8)
                    TaikaPhoneticText.styled(
                        phonetic,
                        font: .system(size: 18, weight: .semibold),
                        baseColor: CD.ColorToken.text.opacity(0.88)
                    )
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Button(action: onPlay) {
                    HStack(spacing: 8) {
                        Image(systemName: listening ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .bold))
                            .symbolEffect(
                                .variableColor.iterative.reversing,
                                options: .repeating,
                                isActive: listening
                            )
                        Text("слушать")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(white: 0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(theme.currentAccentFill))
                }
                .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
                .disabled(checking || recording)
                .opacity(checking || recording ? 0.45 : 1)
            }

            if checking {
                RoundedRectangle(cornerRadius: CardDS.Metrics.stepCardContentRadius, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(theme.currentAccentTintColor)
                        .scaleEffect(1.15)
                    Text("Разбираю…")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Theme.Surfaces.card(shape))
        .overlay(
            shape.stroke(
                AnyShapeStyle(theme.currentAccentFill.opacity(borderOpacity)),
                lineWidth: recording || checking ? 1.6 : 1.2
            )
        )
    }
}

// MARK: - Door / reinforce card

private struct LearnDoorCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let chipTitle: String
    let size: CGSize

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CardDS.Metrics.stepCardContentRadius, style: .continuous)
        let accent = theme.currentAccentFill
        let tint = theme.currentAccentTintColor

        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                TaikaWordmarkLockup(fontSize: 16)
                Spacer(minLength: 4)
                Text(chipTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(accent, lineWidth: 1.2)
                    )
            }
            .padding(.horizontal, CardDS.Metrics.contentX + CardDS.Metrics.stepCardHeaderEdgeInset)
            .frame(height: CardDS.Metrics.stepCardTopBandHeight)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
            }
            .padding(.horizontal, 18)

            Spacer(minLength: 16)
        }
        .frame(width: size.width, height: size.height)
        .background(Theme.Surfaces.card(shape))
        .overlay(
            shape.stroke(accent.opacity(0.45), lineWidth: Theme.Strokes.strokeCardLineWidth + 0.4)
        )
        .shadow(color: tint.opacity(0.18), radius: 12, y: 5)
    }
}

// MARK: - Coverflow

private struct LearnCoverflow<Item: Identifiable, Card: View>: View {
    let items: [Item]
    @Binding var index: Int
    var cardSize: CGSize
    var onTap: ((Item) -> Void)?
    var onUserInteracted: (() -> Void)?
    let card: (Item, Bool) -> Card

    init(
        items: [Item],
        index: Binding<Int>,
        cardSize: CGSize,
        onTap: ((Item) -> Void)? = nil,
        onUserInteracted: (() -> Void)? = nil,
        @ViewBuilder card: @escaping (Item, Bool) -> Card
    ) {
        self.items = items
        self._index = index
        self.cardSize = cardSize
        self.onTap = onTap
        self.onUserInteracted = onUserInteracted
        self.card = card
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = min(max(0, index), max(0, items.count - 1))
        let stepX = cardSize.width * 0.72
        let sideScale = Theme.Layout.carouselDepthScaleSide
        let sideOpacity = Theme.Layout.carouselDepthOpacitySide

        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                let rel = i - current
                card(item, rel == 0)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .scaleEffect(rel == 0 ? 1 : (reduceMotion ? 0.94 : sideScale))
                    .rotation3DEffect(
                        reduceMotion ? .zero : .degrees(Double(rel) * -8),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.65
                    )
                    .opacity(abs(rel) > 2 ? 0 : (rel == 0 ? 1 : sideOpacity))
                    .offset(x: CGFloat(rel) * stepX)
                    .zIndex(rel == 0 ? 10 : Double(10 - abs(rel)))
                    .allowsHitTesting(abs(rel) <= 1)
                    .onTapGesture {
                        if i != current {
                            onUserInteracted?()
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(snap) { index = i }
                        } else if let onTap {
                            onTap(item)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 48, abs(dx) > abs(dy) * 1.15 else { return }
                    onUserInteracted?()
                    UISelectionFeedbackGenerator().selectionChanged()
                    if dx < 0, current + 1 < items.count {
                        withAnimation(snap) { index = current + 1 }
                    } else if dx > 0, current > 0 {
                        withAnimation(snap) { index = current - 1 }
                    }
                }
        )
        .animation(snap, value: current)
    }

    private var snap: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.35)
    }
}

private struct LearnCourseSlide: Identifiable {
    let id: String
    let course: Course
}

private struct LearnInfiniteCourseReel: View {
    let courses: [Course]
    @Binding var index: Int
    var cardSize: CGSize
    var onSelect: (Course) -> Void
    var onUserInteracted: () -> Void

    private var slides: [LearnCourseSlide] {
        guard courses.count > 1 else {
            return courses.map { LearnCourseSlide(id: $0.courseID, course: $0) }
        }
        return (0..<3).flatMap { block in
            courses.map { LearnCourseSlide(id: "\(block)-\($0.courseID)", course: $0) }
        }
    }

    var body: some View {
        LearnCoverflow(
            items: slides,
            index: $index,
            cardSize: cardSize,
            onUserInteracted: onUserInteracted
        ) { item, _ in
            courseCard(item.course)
        }
    }

    private func courseCard(_ course: Course) -> some View {
        let subtitle = course.description
            .replacingOccurrences(of: "[[", with: "")
            .replacingOccurrences(of: "]]", with: "")
        return CourseLessonCard(
            title: course.title,
            subtitle: subtitle,
            lessonsCount: course.lessonCount,
            durationText: "≈ \(course.durationMinutes) мин",
            statusKind: nil,
            courseCategory: course.category,
            isPro: course.isPro,
            showProCrown: course.isPro && !ProManager.shared.isPro,
            size: cardSize,
            sectionChrome: .none,
            primaryCTA: .start,
            scale: .xs,
            showFavorite: false,
            showConsole: false,
            onPrimaryTap: { onSelect(course) },
            flipEnabled: false
        )
    }
}

#Preview {
    TaikaLearnOnboardingView(onFinished: { _ in })
        .environmentObject(ThemeManager.shared)
}
