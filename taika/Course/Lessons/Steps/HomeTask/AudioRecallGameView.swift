import SwiftUI

private typealias AudioRecallRound = (item: StepItem, targetRU: String, choices: [String], lessonId: String?)

private enum AudioRecallModel {

    /// Одна строка перевода для сравнения и для кнопки (целиком, без дробления на слова).
    static func normalizePhrase(_ raw: String?) -> String {
        let t = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        return t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// Эталон + 4–6 вариантов: правильный полный `ru` и до 5 других целых фраз из **того же пула** (все переданные карточки).
    /// Вызыватель передаёт уже отфильтрованный список (например, только выученные в уроке — как в играх 1–2).
    static func buildRounds(from items: [(item: StepItem, lessonId: String?)], shuffleOrder: Bool) -> [AudioRecallRound] {
        let learn = items.filter { StepData.isValidForProgress($0.item) }
        var pairs: [(id: Int, item: StepItem, ru: String, lessonId: String?)] = []
        pairs.reserveCapacity(learn.count)
        var idCounter = 0
        for source in items {
            let it = source.item
            let ru = normalizePhrase(it.ru)
            guard !ru.isEmpty else { continue }
            pairs.append((id: idCounter, item: it, ru: ru, lessonId: source.lessonId))
            idCounter += 1
        }
        guard !pairs.isEmpty else { return [] }

        let ordered = shuffleOrder
        ? pairs.shuffled()
        : pairs.sorted { $0.item.order < $1.item.order }
        var out: [AudioRecallRound] = []
        for pair in ordered {
            let item = pair.item
            let target = pair.ru
            var seenWrong = Set<String>()
            var uniqueWrong: [String] = []
            for other in pairs where other.id != pair.id && other.ru != target {
                guard seenWrong.insert(other.ru).inserted else { continue }
                uniqueWrong.append(other.ru)
            }
            uniqueWrong.shuffle()
            let wrongPick = min(5, uniqueWrong.count)
            let wrong = Array(uniqueWrong.prefix(wrongPick))
            var choices = [target] + wrong
            if choices.count > 6 {
                choices = [target] + Array(wrong.prefix(5))
            }
            choices.shuffle()
            out.append((item, target, choices, pair.lessonId))
        }
        return out
    }
}

/// Игра 3: карточка как у Speaker (транслит → тайский) + выбор русской фразы внизу.
@MainActor
struct AudioRecallGameView: View {

    /// Как у «Найди пару» / recall: прогресс привязан к паре courseId + lessonId.
    let courseId: String
    let lessonId: String
    let reinforcementLessonIds: [String]?
    /// Explicit failed-card scope for targeted practice; nil keeps the normal learned pool.
    let errorCardKeys: [String]?
    let isCourseReinforcement: Bool
    let sourceTitle: String
    let sourceContextTitle: String
    let onClose: () -> Void
    let onNextGame: (() -> Void)?
    let nextGameTitle: String?
    let isProUser: Bool
    var onSpeakerPractice: (() -> Void)? = nil
    var onContinueLearning: (() -> Void)? = nil
    var continueLearningTitle: String? = nil

    @EnvironmentObject private var theme: ThemeManager

    @State private var rounds: [AudioRecallRound] = []
    @State private var roundIndex: Int = 0
    @State private var elapsedSeconds: Int = 0
    @State private var score: Int = 0
    @State private var mistakes: Int = 0
    @State private var failedTargetRUs: Set<String> = []
    @State private var finished: Bool = false
    @State private var shuffleLessonOrder: Bool = false
    @State private var didLoadSession: Bool = false
    /// Мягкое появление тайского текста (opacity + лёгкое свечение).
    @State private var heroRevealOpacity: Double = 0
    @State private var heroRevealToken: Int = 0
    @State private var choicesUnlocked: Bool = false
    @State private var revealedChoiceCount: Int = 0
    /// Инлайн-фолбэк на том же экране: выбранная фраза + верно/неверно.
    @State private var lastPickedPhrase: String? = nil
    @State private var lastPickCorrect: Bool? = nil
    @State private var advanceToken: Int = 0
    @State private var didRecordReinforcementSession: Bool = false
    /// Успех карточки — как в «Быстром повторении».
    @State private var successScale: CGFloat = 1.0
    @State private var successGlow: Double = 0

    private var isAnswerLocked: Bool {
        lastPickCorrect == true
    }

    private var currentTargetRU: String {
        guard roundIndex < rounds.count else { return "" }
        return rounds[roundIndex].targetRU
    }

    private var currentChoices: [String] {
        guard roundIndex < rounds.count else { return [] }
        return rounds[roundIndex].choices
    }

    private var currentItem: StepItem? {
        guard roundIndex < rounds.count else { return nil }
        return rounds[roundIndex].item
    }

    private var formattedElapsedTime: String {
        let mm = elapsedSeconds / 60
        let ss = elapsedSeconds % 60
        return String(format: "%d:%02d", mm, ss)
    }

    /// Тот же псевдо-курс, что у матча/викторины из игрового парка вкладки «Избранное».
    private var isFavoritesContext: Bool {
        let c = courseId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return c == "__favorites__" || c == "--favorites--"
    }

    private var isLearnedParkContext: Bool {
        LearnedGameSource.isPseudoCourseId(courseId)
    }

    private var isGlobalParkContext: Bool {
        isFavoritesContext || isLearnedParkContext
    }

    var body: some View {
        GameShell(
            onClose: {
                StepAudio.shared.stop()
                onClose()
            },
            gameHeaderConfig: nil,
            gameContextHeader: nil
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if finished {
                        Color.clear.frame(height: 1)
                    } else if !didLoadSession {
                        TaikaLoadingView(label: "подготовка…", compact: true)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    } else {
                        if rounds.isEmpty {
                            if lessonId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Group {
                                    if isFavoritesContext {
                                        emptyFavoritesState
                                    } else if isLearnedParkContext {
                                        emptyLearnedParkState
                                    } else {
                                        emptyCourseState
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                            } else {
                                emptyContentState
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                            }
                        } else {
                            activePlayLayout
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .overlay {
                if finished {
                    completionOverlay
                        .zIndex(100)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            didLoadSession = false
            StepData.shared.preload()
            reloadSession()
            didLoadSession = true
            GameHeaderStore.shared.config = headerConfig()
        }
        .onDisappear {
            StepAudio.shared.stop()
            GameHeaderStore.shared.config = nil
        }
        .onChange(of: roundIndex) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: lastPickCorrect) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: choicesUnlocked) { _, unlocked in
            if unlocked {
                staggerRevealChoices()
            } else {
                revealedChoiceCount = 0
            }
        }
        .onChange(of: elapsedSeconds) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: score) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: mistakes) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: finished) { _, isDone in
            if isDone { StepAudio.shared.stop() }
            if isDone, !didRecordReinforcementSession, !isGlobalParkContext {
                didRecordReinforcementSession = true
                let total = max(1, rounds.count)
                let percent = max(0, min(100, Int((Double(score) / Double(total) * 100).rounded())))
                let sourceCardKeys = rounds.compactMap { round -> String? in
                    guard let lid = round.lessonId?.trimmingCharacters(in: .whitespacesAndNewlines), !lid.isEmpty else { return nil }
                    return "\(lid)|\(round.targetRU)"
                }
                let failedKeys = sourceCardKeys.filter { key in
                    guard let phrase = key.split(separator: "|", maxSplits: 1).last else { return false }
                    return failedTargetRUs.contains(String(phrase).lowercased())
                }
                let clearedKeys = sourceCardKeys.filter { key in !failedKeys.contains(key) }
                ReinforcementStore.shared.recordSession(
                    courseId: courseId,
                    gameType: "audioRecall",
                    score: percent,
                    sourceCardKeys: sourceCardKeys,
                    failedCardKeys: failedKeys,
                    clearedCardKeys: clearedKeys,
                    lessonIds: reinforcementLessonIds ?? (lessonId.isEmpty ? [] : [lessonId])
                )
            }
            GameHeaderStore.shared.config = headerConfig()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard !finished, currentItem != nil else { return }
            elapsedSeconds += 1
        }
    }

    /// Единый brand accent (Fill), без отдельного Tint-розового.
    private var brandAccent: AnyShapeStyle {
        AnyShapeStyle(theme.currentAccentFill)
    }

    @ViewBuilder
    private var activePlayLayout: some View {
        VStack(spacing: 10) {
            TaikaGameStatusStrip(
                timeText: formattedElapsedTime,
                progressText: {
                    let total = rounds.count
                    guard total > 0 else { return nil }
                    let progress = finished ? total : min(roundIndex + 1, total)
                    return "\(progress)/\(total)"
                }(),
                mistakes: mistakes,
                score: score
            )
            .padding(.horizontal, CD.Spacing.screen)

            // Два Spacer — воздух сверху/снизу, карточка склеена с вариантами.
            Spacer(minLength: 6)

            VStack(spacing: 8) {
                audioRoundCoverflow
                audioUnderCardControl
                audioPlayfield
            }
            .padding(.horizontal, CD.Spacing.screen)

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            audioBottomChrome
        }
        .onChange(of: lastPickCorrect) { _, new in
            guard new == true else {
                successGlow = 0
                successScale = 1.0
                return
            }
            withAnimation(.easeOut(duration: 0.22)) { successGlow = 1 }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) { successScale = 1.04 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) { successScale = 1.0 }
            }
        }
    }

    /// Карусель 1:1 как Speaker: 268×196, 3D yaw.
    private var audioRoundCoverflow: some View {
        let itemH = TaikaGameCoverflowMetrics.cardH
        let stepX = TaikaGameCoverflowMetrics.cardW * TaikaGameCoverflowMetrics.peekStepFactor
        let current = min(max(0, roundIndex), max(0, rounds.count - 1))
        let locked = lastPickCorrect == true

        return ZStack {
            ForEach(Array(rounds.enumerated()), id: \.offset) { index, round in
                let rel = index - current
                audioRoundCard(
                    item: round.item,
                    isActive: rel == 0,
                    succeeded: rel == 0 && lastPickCorrect == true
                )
                .scaleEffect((rel == 0 ? 1.0 : 0.82) * (rel == 0 ? successScale : 1))
                .rotation3DEffect(
                    .degrees(Double(rel) * -18),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.7
                )
                .opacity(abs(rel) > 2 ? 0 : (rel == 0 ? 1.0 : 0.45))
                .offset(x: CGFloat(rel) * stepX)
                .zIndex(rel == 0 ? 10 : Double(10 - abs(rel)))
                .allowsHitTesting(abs(rel) <= 1 && !locked)
                .onTapGesture {
                    guard index != current, !locked else { return }
                    selectRound(at: index)
                }
            }
        }
        .frame(height: itemH + 12)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.35), value: current)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: successScale)
        .opacity(0.55 + 0.45 * heroRevealOpacity)
    }

    private var audioUnderCardControl: some View {
        let thai = (currentItem?.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 10) {
            TaikaGameBareSpeakerButton(
                disabled: thai.isEmpty || lastPickCorrect == true,
                action: {
                    if let item = currentItem { speakPrompt(item) }
                }
            )
            if !choicesUnlocked {
                Image(systemName: "ear")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill.opacity(0.85))
                    .accessibilityLabel("Слушай")
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: choicesUnlocked)
    }

    private func audioRoundCard(item: StepItem, isActive: Bool, succeeded: Bool) -> some View {
        let thai = (item.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phonetic = (item.phonetic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let revealedRU: String? = {
            guard succeeded,
                  let picked = lastPickedPhrase?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !picked.isEmpty else { return nil }
            return picked
        }()

        // 1:1 иерархия спикера: транслит (hero) → RU (после успеха) → тайский (footnote).
        let heroLine = phonetic.isEmpty ? thai : phonetic
        let heroPhonetic = !phonetic.isEmpty

        return TaikaGameSpeakerStyleCard(
            lessonTitle: (isActive && !sourceTitle.isEmpty) ? sourceTitle : nil,
            hero: heroLine,
            heroIsPhonetic: heroPhonetic,
            secondary: revealedRU,
            tertiary: thai.isEmpty || (!phonetic.isEmpty && thai == heroLine) ? nil : thai,
            secondaryIsAccent: revealedRU != nil,
            succeeded: succeeded,
            successGlow: successGlow,
            showsPlayControl: false
        )
    }

    private var audioPlayfield: some View {
        VStack(spacing: 10) {
            translationChoicesColumn
        }
        .frame(maxWidth: .infinity)
        .opacity(choicesUnlocked ? 1 : 0.35)
        .allowsHitTesting(choicesUnlocked)
    }

    private var audioBottomChrome: some View {
        HStack(alignment: .center, spacing: 14) {
            if lastPickCorrect == false {
                audioIconButton(icon: "arrow.counterclockwise", accessibility: "Сброс") {
                    retryAfterWrong()
                }
            }

            Spacer(minLength: 8)

            if lastPickCorrect == true {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(brandAccent)
                    .accessibilityLabel("Верно")
            } else if lastPickCorrect == false {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .accessibilityLabel("Исправь ответ")
            } else {
                Text("\(min(roundIndex + 1, max(rounds.count, 1)))/\(max(rounds.count, 1))")
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 14)
        .padding(.bottom, 22)
    }

    private func audioIconButton(icon: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }

    private func speakPrompt(_ item: StepItem) {
        let text = (item.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        StepAudio.shared.speakThai(text)
    }

    private func selectRound(at index: Int) {
        guard index >= 0, index < rounds.count, index != roundIndex else { return }
        guard lastPickCorrect != true else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            roundIndex = index
        }
        loadRound(at: index)
    }

    /// Варианты — chip-стиль как у слогов в Recall.
    private var translationChoicesColumn: some View {
        let choices = currentChoices
        return VStack(spacing: 10) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, phrase in
                translationChoiceTile(phrase: phrase, index: index)
            }
        }
    }

    private enum ChoiceVisualState {
        case idle
        case correct
        case wrongPick
        case dimmed
    }

    private func choiceVisualState(phrase: String) -> ChoiceVisualState {
        guard let ok = lastPickCorrect, let picked = lastPickedPhrase else { return .idle }
        let norm = AudioRecallModel.normalizePhrase(phrase)
        let pickedNorm = AudioRecallModel.normalizePhrase(picked)
        let targetNorm = AudioRecallModel.normalizePhrase(currentTargetRU)
        if ok {
            if norm == targetNorm { return .correct }
            return .dimmed
        } else {
            // Неверная — красная; остальные остаются доступными (как слоты в Recall).
            if norm == pickedNorm { return .wrongPick }
            return .idle
        }
    }

    private func translationChoiceTile(phrase: String, index: Int) -> some View {
        let canTap = !isAnswerLocked && choicesUnlocked
        let isRevealed = index < revealedChoiceCount
        let visual = choiceVisualState(phrase: phrase)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectTranslation(phrase)
        } label: {
            Text(phrase)
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .foregroundStyle(choiceTextStyle(visual: visual, canTap: canTap))
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(choiceRowBackground(visual: visual, shape: shape))
                .overlay(choiceRowStroke(visual: visual, shape: shape))
                .shadow(
                    color: visual == .correct
                        ? theme.currentAccentTintColor.opacity(0.18)
                        : Color.black.opacity(visual == .idle ? 0.12 : 0.04),
                    radius: visual == .correct ? 8 : 4,
                    y: visual == .correct ? 2 : 1
                )
                .contentShape(shape)
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
        .disabled(!canTap)
        // Motion: вылет снизу + scale + лёгкий tilt, каскадом.
        .opacity(isRevealed ? (visual == .dimmed ? 0.42 : 1) : 0)
        .offset(y: isRevealed ? 0 : 36)
        .scaleEffect(isRevealed ? 1 : 0.86, anchor: .bottom)
        .rotation3DEffect(
            .degrees(isRevealed ? 0 : 12),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.65
        )
        .blur(radius: isRevealed ? 0 : 2.5)
        .animation(
            .spring(response: 0.52, dampingFraction: 0.76).delay(Double(index) * 0.055),
            value: isRevealed
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: visual == .correct)
        .modifier(WrongPickShakeIfNeeded(active: visual == .wrongPick))
        .accessibilityLabel(phrase)
    }

    private func choiceTextStyle(visual: ChoiceVisualState, canTap: Bool) -> AnyShapeStyle {
        switch visual {
        case .correct:
            return brandAccent
        case .wrongPick:
            return AnyShapeStyle(Color.red.opacity(0.92))
        case .dimmed:
            return AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.42))
        case .idle:
            return AnyShapeStyle(CD.ColorToken.text.opacity(canTap ? 1 : 0.55))
        }
    }

    @ViewBuilder
    private func choiceRowBackground(visual: ChoiceVisualState, shape: RoundedRectangle) -> some View {
        switch visual {
        case .correct:
            shape.fill(AnyShapeStyle(theme.currentAccentFill.opacity(0.18)))
        case .wrongPick:
            shape.fill(Color.red.opacity(0.14))
        case .dimmed:
            shape.fill(CD.ColorToken.card.opacity(0.35))
        case .idle:
            shape.fill(CD.ColorToken.card.opacity(0.96))
        }
    }

    @ViewBuilder
    private func choiceRowStroke(visual: ChoiceVisualState, shape: RoundedRectangle) -> some View {
        switch visual {
        case .correct:
            shape.stroke(brandAccent, lineWidth: 1.4)
        case .wrongPick:
            shape.stroke(Color.red.opacity(0.45), lineWidth: 1.2)
        case .idle:
            shape.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        case .dimmed:
            shape.stroke(Theme.Strokes.strokeSubtle.opacity(0.5), lineWidth: 0.8)
        }
    }

    private func staggerRevealChoices() {
        revealedChoiceCount = 0
        let total = currentChoices.count
        guard total > 0 else { return }
        // Каскад: каждый следующий чуть позже — ощущение «motion stagger».
        for i in 0..<total {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04 + Double(i) * 0.075) {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.76)) {
                    revealedChoiceCount = i + 1
                }
            }
        }
    }

    private func reshuffleCurrentChoices() {
        guard roundIndex < rounds.count else { return }
        let r = rounds[roundIndex]
        var ch = r.choices
        ch.shuffle()
        var next = rounds
        next[roundIndex] = (item: r.item, targetRU: r.targetRU, choices: ch, lessonId: r.lessonId)
        rounds = next
    }

    private func selectTranslation(_ picked: String) {
        guard lastPickCorrect != true, choicesUnlocked, roundIndex < rounds.count else { return }
        let pickedNorm = AudioRecallModel.normalizePhrase(picked)
        if lastPickCorrect == false,
           pickedNorm == AudioRecallModel.normalizePhrase(lastPickedPhrase) {
            return
        }
        let target = rounds[roundIndex].targetRU
        let ok = pickedNorm == AudioRecallModel.normalizePhrase(target)
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            lastPickedPhrase = picked
            lastPickCorrect = ok
        }
        if ok {
            score += 1
            TaikaGameFeedbackHaptics.answerCorrect()
            TaikaVoice.shared.play(.success)
            scheduleAutoAdvance()
        } else {
            failedTargetRUs.insert(currentTargetRU.lowercased())
            mistakes += 1
            TaikaGameFeedbackHaptics.mismatch()
            TaikaVoice.shared.playMatchFail()
        }
    }

    /// Как в Recall: короткая «красота» карточки → дальше.
    private func scheduleAutoAdvance() {
        advanceToken += 1
        let token = advanceToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            guard token == advanceToken, lastPickCorrect == true, !finished else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                advanceRound()
            }
        }
    }

    private func retryAfterWrong() {
        withAnimation(.easeInOut(duration: 0.18)) {
            lastPickedPhrase = nil
            lastPickCorrect = nil
            reshuffleCurrentChoices()
            staggerRevealChoices()
        }
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    private func advanceRound() {
        if roundIndex + 1 >= rounds.count {
            withAnimation(.easeOut(duration: 0.2)) { finished = true }
            return
        }
        roundIndex += 1
        loadRound(at: roundIndex)
    }

    private func loadRound(at index: Int) {
        guard index < rounds.count else { return }
        lastPickedPhrase = nil
        lastPickCorrect = nil
        successScale = 1.0
        successGlow = 0
        advanceToken += 1
        scheduleHeroReveal(for: rounds[index].item)
    }

    private func scheduleHeroReveal(for item: StepItem) {
        choicesUnlocked = false
        revealedChoiceCount = 0
        heroRevealToken += 1
        let token = heroRevealToken
        heroRevealOpacity = 0
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.95)) {
                heroRevealOpacity = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            guard token == heroRevealToken else { return }
            choicesUnlocked = true
            speakPrompt(item)
        }
    }

    private func reloadSession() {
        lastPickedPhrase = nil
        lastPickCorrect = nil
        choicesUnlocked = false
        revealedChoiceCount = 0
        heroRevealOpacity = 0
        heroRevealToken += 1
        advanceToken += 1
        didRecordReinforcementSession = false

        let trimmedLessonId = lessonId.trimmingCharacters(in: .whitespacesAndNewlines)
        var raw: [(item: StepItem, lessonId: String?)] = []

        if trimmedLessonId.isEmpty, isFavoritesContext {
            // Игровой парк из «Избранного»: тот же пул, что у матча и викторины (`HomeTaskView.buildRound` / `recallTriples`).
            let triples = FavoritesGameSource.triples().filter {
                !$0.ru.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.ph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            raw = triples.enumerated().map { idx, t in
                let ru = t.ru.trimmingCharacters(in: .whitespacesAndNewlines)
                let ph = t.ph.trimmingCharacters(in: .whitespacesAndNewlines)
                let th = t.th.trimmingCharacters(in: .whitespacesAndNewlines)
                return (item: StepItem(
                    favoritesAudioRecallOrder: idx,
                    ru: ru,
                    thai: th.isEmpty ? nil : th,
                    phonetic: ph
                ), lessonId: nil)
            }
        } else if trimmedLessonId.isEmpty, isLearnedParkContext {
            let triples = LearnedGameSource.triples().filter {
                !$0.ru.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.ph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            raw = triples.enumerated().map { idx, t in
                let ru = t.ru.trimmingCharacters(in: .whitespacesAndNewlines)
                let ph = t.ph.trimmingCharacters(in: .whitespacesAndNewlines)
                let th = t.th.trimmingCharacters(in: .whitespacesAndNewlines)
                return (item: StepItem(
                    favoritesAudioRecallOrder: idx,
                    ru: ru,
                    thai: th.isEmpty ? nil : th,
                    phonetic: ph
                ), lessonId: nil)
            }
        } else if trimmedLessonId.isEmpty {
            // Course-mode: собираем learned-steps по всем урокам курса.
            var bundles = LessonsData.shared.lessons(for: courseId)
            if bundles.isEmpty {
                bundles = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "_", with: "-"))
            }
            if bundles.isEmpty {
                bundles = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "-", with: "_"))
            }

            let orderedLessonIds = bundles.sorted { $0.order < $1.order }.map { $0.lessonID }
            let lessonIds = shuffleLessonOrder ? orderedLessonIds.shuffled() : orderedLessonIds

            for lid in lessonIds {
                let steps = StepData.shared.items(for: lid)
                let learnedIdx = ProgressManager.shared.learnedSet(courseId: courseId, lessonId: lid)
                raw.append(contentsOf: steps.filter {
                    guard learnedIdx.contains($0.order) else { return false }
                    guard let errorCardKeys else { return true }
                    let key = Self.normalizedCardKey("\(lid)|\($0.ru ?? "")")
                    return errorCardKeys.map(Self.normalizedCardKey).contains(key)
                }.map { (item: $0, lessonId: lid) })
            }
        } else {
            // Lesson-mode: собираем learned-steps только из заданного урока.
            let steps = StepData.shared.items(for: trimmedLessonId)
            let learnedIdx = ProgressManager.shared.learnedSet(courseId: courseId, lessonId: trimmedLessonId)
            raw = steps.filter {
                guard learnedIdx.contains($0.order) else { return false }
                guard let errorCardKeys else { return true }
                let key = Self.normalizedCardKey("\(trimmedLessonId)|\($0.ru ?? "")")
                return errorCardKeys.map(Self.normalizedCardKey).contains(key)
            }.map { (item: $0, lessonId: trimmedLessonId) }
        }

        // Unify reinforcement pool with match/recall: dedupe by RU (case-insensitive).
        // HomeTaskManager.userTriples(...) already dedupes by ru.lowercased().
        var seenRU = Set<String>()
        raw = raw.filter { source in
            let ru = AudioRecallModel.normalizePhrase(source.item.ru).lowercased()
            guard !ru.isEmpty else { return false }
            guard seenRU.insert(ru).inserted else { return false }
            return true
        }

        rounds = AudioRecallModel.buildRounds(from: raw, shuffleOrder: shuffleLessonOrder)
        roundIndex = 0
        elapsedSeconds = 0
        score = 0
        mistakes = 0
        finished = false
        if !rounds.isEmpty {
            loadRound(at: 0)
        }
    }

    private static func normalizedCardKey(_ raw: String) -> String {
        let parts = raw.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return raw.lowercased() }
        return "\(parts[0].lowercased().replacingOccurrences(of: "_", with: "-"))|\(parts[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private var emptyLessonState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Нужен урок с карточками.")
                .font(CD.FontToken.body(15, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button("Закрыть") {
                onClose()
            }
            .font(CD.FontToken.body(15, weight: .semibold))
            .foregroundStyle(theme.currentAccentFill)
        }
        .padding(.vertical, 12)
    }

    private var emptyCourseState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("В этом курсе пока нет выученных карточек для Audio Recall.")
                .font(CD.FontToken.body(15, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button("Закрыть") {
                onClose()
            }
            .font(CD.FontToken.body(15, weight: .semibold))
            .foregroundStyle(theme.currentAccentFill)
        }
        .padding(.vertical, 12)
    }

    private var emptyFavoritesState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("В избранном нет карточек с тайским текстом и транскрипцией — без них Audio Recall не собрать варианты ответов.")
                .font(CD.FontToken.body(15, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button("Закрыть") {
                onClose()
            }
            .font(CD.FontToken.body(15, weight: .semibold))
            .foregroundStyle(theme.currentAccentFill)
        }
        .padding(.vertical, 12)
    }

    private var emptyLearnedParkState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Пока нет выученных карточек с фонетикой для Audio Recall.")
                .font(CD.FontToken.body(15, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button("Закрыть") {
                onClose()
            }
            .font(CD.FontToken.body(15, weight: .semibold))
            .foregroundStyle(theme.currentAccentFill)
        }
        .padding(.vertical, 12)
    }

    private var emptyContentState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("В этом уроке нет карточек с русским переводом для игры.")
                .font(CD.FontToken.body(15, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button("Закрыть") {
                onClose()
            }
            .font(CD.FontToken.body(15, weight: .semibold))
            .foregroundStyle(theme.currentAccentFill)
        }
        .padding(.vertical, 12)
    }

    private func headerConfig() -> GameHeaderConfig {
        let total = rounds.count
        let progressText: String? = {
            guard total > 0 else { return nil }
            let progress = finished ? total : min(roundIndex + 1, total)
            return "раунд \(progress) из \(total)"
        }()
        // Время в status-чипах; в хедере не дублируем розовым.
        return GameHeaderConfig(
            timeText: "",
            score: score,
            mistakes: mistakes,
            streak: 0,
            progressText: progressText,
            gameTitle: "Аудио-реплика",
            sourceTitle: sourceContextTitle,
            minimalGameChrome: false,
            onBack: {
                StepAudio.shared.stop()
                onClose()
            }
        )
    }

    private var completionOverlay: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onClose)
            OverlayEtalonCard(title: "Урок закреплён", onDismiss: onClose) {
                VStack(spacing: 16) {
                    completionOverlayStats
                    completionOverlayActionButtons
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 20)
            }
        }
    }

    private var completionOverlayStats: some View {
        VStack(spacing: 10) {
            Text("верных: \(score) из \(rounds.count)")
                .font(CD.FontToken.body(15, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Text(formattedElapsedTime)
                .font(CD.FontToken.body(16, weight: .semibold))
                .foregroundStyle(CD.ColorToken.text)
        }
    }

    private var completionOverlayActionButtons: some View {
        GameCompletionActions(
            isFromLessonStep: !isCourseReinforcement && HomeTaskView.isLessonStepOrigin(courseId: courseId, lessonId: lessonId),
            isCourseReinforcement: isCourseReinforcement,
            isProUser: isProUser,
            continueLearningTitle: continueLearningTitle
                ?? HomeTaskView.continueLearningTitle(courseId: courseId, lessonId: lessonId),
            nextGameTitle: nextGameTitle,
            onRepeat: {
                shuffleLessonOrder.toggle()
                reloadSession()
                GameHeaderStore.shared.config = headerConfig()
            },
            errorCount: failedTargetRUs.count,
            onNextGame: onNextGame.map { next in
                {
                    StepAudio.shared.stop()
                    next()
                }
            },
            onSpeakerPractice: onSpeakerPractice,
            onContinueLearning: onContinueLearning,
            onClose: onClose
        )
    }
}

/// Одноразовая встряска только на ошибочной плитке (после ответа).
private struct WrongPickShakeIfNeeded: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.taikaGameShakeOnceOnAppear()
        } else {
            content
        }
    }
}
