//
//  HomeTaskView.swift
//  taika
//
//  Minimal game screen: "Подобрать пару" — phonetic (left) ↔ ru (right)
//  Uses MPMatchPairsGrid from HomeTaskDS.swift and HomeTaskManager as data source.
//

import SwiftUI
import AudioToolbox

@MainActor
public struct HomeTaskView: View {
    public let courseId: String
    public let lessonId: String
    /// Optional multi-lesson scope for course reinforcement training.
    public let lessonIds: [String]?
    public let embedBackground: Bool
    public let onClose: (() -> Void)?
    public let onNextGame: (() -> Void)?
    /// Название следующей игры (для не‑Pro: подпись на заблокированной кнопке).
    public let nextGameTitle: String?
    public let isProUser: Bool
    public let displayTitle: String?
    public let gameType: HomeGameType
    /// Из урока/степа: предложить спикер и следующий урок/курс.
    public let onSpeakerPractice: (() -> Void)?
    public let onContinueLearning: (() -> Void)?
    public let continueLearningTitle: String?
    @StateObject private var store: HomeTaskManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager

    // Matching state
    @State private var leftItems: [MPItem] = []
    @State private var rightItems: [MPItem] = []
    @State private var selectedLeft: Int? = nil
    @State private var selectedRight: Int? = nil
    @State private var matchedPairIds: Set<String> = []
    @State private var tries: Int = 0
    // Summary overlay visibility (separate from computed isFinished)
    @State private var showSummary: Bool = false
    @State private var didRecordReinforcementSession: Bool = false
    /// Секунды с начала текущего раунда (для хедера). Останавливается при showSummary.
    @State private var gameElapsedSeconds: Int = 0
    /// Секунды с начала Recall-игры (для хедера).
    @State private var recallElapsedSeconds: Int = 0
    /// Время последней завершённой игры (для экрана итогов).
    @State private var lastGameTimeSeconds: Int? = nil

    // Intro animation state
    @State private var didRunIntro: Bool = false
    @State private var gridFlipDeg: Double = 0
    @State private var gridOpacity: Double = 0
    @State private var flipTimer: Timer? = nil
    @State private var flipCycle: Int = 0
    @State private var flipStates: [String: Bool] = [:]

    // Staged pool logic
    @State private var allTriples: [HomeTaskManager.LearnedTriple] = []
    @State private var remainingTriples: [HomeTaskManager.LearnedTriple] = []
    @State private var totalPairsCount: Int = 0
    private let visiblePairsTarget: Int = 6

    public init(courseId: String,
                lessonId: String,
                lessonIds: [String]? = nil,
                embedBackground: Bool = false,
                store: HomeTaskManager? = nil,
                onClose: (() -> Void)? = nil,
                onNextGame: (() -> Void)? = nil,
                nextGameTitle: String? = nil,
                isProUser: Bool = true,
                displayTitle: String? = nil,
                gameType: HomeGameType = .match,
                onSpeakerPractice: (() -> Void)? = nil,
                onContinueLearning: (() -> Void)? = nil,
                continueLearningTitle: String? = nil) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.lessonIds = lessonIds
        self.embedBackground = embedBackground
        self.onClose = onClose
        self.onNextGame = onNextGame
        self.nextGameTitle = nextGameTitle
        self.isProUser = isProUser
        self.displayTitle = displayTitle
        self.gameType = gameType
        self.onSpeakerPractice = onSpeakerPractice
        self.onContinueLearning = onContinueLearning
        self.continueLearningTitle = continueLearningTitle
        _store = StateObject(wrappedValue: store ?? HomeTaskManager())
    }

    private var isFromLessonStep: Bool {
        Self.isLessonStepOrigin(courseId: courseId, lessonId: lessonId)
    }

    private var resolvedContinueTitle: String? {
        continueLearningTitle ?? Self.continueLearningTitle(courseId: courseId, lessonId: lessonId)
    }

    public var body: some View {
        Group {
            switch effectiveGameType {
            case .match:
                matchBody
            case .recall, .builder:
                // Один движок (сборка из слогов); builder = «фразы в контексте», другие тексты в UI.
                recallBody
            case .audioRecall:
                audioRecallFlowBody
            case .grandDialogue:
                grandDialogueFlowBody
            case .conversation:
                audioRecallFlowBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Game Type Routing

    private var effectiveGameType: HomeGameType {
        gameType.normalizedForGameShell
    }

    // MARK: - Match Body (existing implementation extracted)

    @ViewBuilder
    private var matchBody: some View {
        GameShell(
            onClose: {
                if let onClose = onClose {
                    onClose()
                } else {
                    dismiss()
                }
            },
            gameHeaderConfig: nil,
            gameContextHeader: nil
        ) {
            contentBody
        }
        .onAppear {
            GameHeaderStore.shared.config = gameHeaderConfigForMatch()
        }
        .onDisappear {
            GameHeaderStore.shared.config = nil
            if isDictionaryContext {
                DictionarySessionSelection.shared.clear()
            }
        }
        .onChange(of: gameElapsedSeconds) { _, _ in
            GameHeaderStore.shared.config = gameHeaderConfigForMatch()
        }
        .onChange(of: tries) { _, _ in
            GameHeaderStore.shared.config = gameHeaderConfigForMatch()
        }
        .onChange(of: matchedPairIds.count) { _, _ in
            GameHeaderStore.shared.config = gameHeaderConfigForMatch()
        }
        .onChange(of: showSummary) { _, isShowing in
            if isShowing {
                if !didRecordReinforcementSession {
                    didRecordReinforcementSession = true
                    recordMatchedGameMastery()
                }
                lastGameTimeSeconds = gameElapsedSeconds
                let key = Self.matchBestTimeKey(courseId: courseId, lessonId: lessonId)
                let current = UserDefaults.standard.object(forKey: key) as? Int ?? .max
                if gameElapsedSeconds < current {
                    UserDefaults.standard.set(gameElapsedSeconds, forKey: key)
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if totalPairsCount > 0 && matchedPairIds.count < totalPairsCount {
                gameElapsedSeconds += 1
            }
        }
    }

    /// Название текущей игры для секции (слева).
    private func currentGameDisplayName() -> String {
        switch effectiveGameType {
        case .match: return "Найди пару"
        case .recall: return "Быстрое повторение"
        case .builder: return "Фразы в контексте"
        case .audioRecall: return "Audio Recall"
        case .grandDialogue: return "Курсовая"
        case .conversation: return "Audio Recall"
        }
    }

    /// Правая колонка секции игры: курс / избранное (как подсекция в Main/Course), без дубля в app-header.
    private func courseTitleForSection() -> String {
        let (ccid, _) = canonicalIds()
        if isFavoritesContext { return "Избранное" }
        if isDictionaryContext { return "Мой словарь" }
        if isLearnedParkContext { return "Все выученные" }
        return CourseData.shared.title(for: ccid) ?? CourseData.shared.title(for: courseId) ?? ccid
    }

    /// Название урока для чипа на карточке recall (текущий раунд → урок-источник в пуле курса).
    private func recallLessonChipTitle() -> String? {
        if let lid = store.currentBuilderRound?.lessonId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lid.isEmpty,
           let t = LessonsData.shared.lessonTitle(for: lid), !t.isEmpty {
            return t
        }
        if !lessonId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return resolvedLessonTitle()
        }
        if let t = displayTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        return nil
    }

    @ViewBuilder
    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            TaikaGameStatusStrip(
                timeText: formatGameTime(gameElapsedSeconds),
                progressText: {
                    let total = max(1, totalPairsCount)
                    return "\(matchedPairIds.count)/\(total)"
                }(),
                mistakes: max(0, tries - matchedPairIds.count),
                score: matchedPairIds.count
            )

            if leftItems.isEmpty || rightItems.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        buildRound()
                        if !didRunIntro {
                            didRunIntro = true
                            startTabloidIntro()
                        }
                    }
            } else {
                Spacer(minLength: 6)
                activeGameBlock
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 6)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay {
            if showSummary {
                completionOverlay
                    .zIndex(100)
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }
        }
    }

    /// Оверлей итогов: blur-scrim + эталонная карточка с хедером (заголовок + закрытие).
    @ViewBuilder
    private var completionOverlay: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: {
                withAnimation(.easeOut(duration: 0.2)) { showSummary = false }
            })

            OverlayEtalonCard(title: completionOverlayTitle, onDismiss: {
                withAnimation(.easeOut(duration: 0.2)) { showSummary = false }
            }) {
                finishedBlockContent
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.bottom, 20)
            }
        }
    }

    private var completionOverlayTitle: String {
        if lessonId.isEmpty && !(lessonIds ?? []).isEmpty { return "закрепление курса" }
        if isFromLessonStep { return "урок закреплён" }
        return "закрепление завершено"
    }

    private var courseCompletionHint: String {
        let mistakes = max(0, tries - matchedPairIds.count)
        if mistakes > 0 {
            return "Карточки закреплены. \(mistakes) ошибок сохранены в уроках — начни следующую практику с них."
        }
        return "Карточки закреплены. Следующий шаг — коротко повторить их в Спикере или пройти следующую игру."
    }

    private var finishedBlockContent: some View {
        let timeStr = formatGameTime(lastGameTimeSeconds ?? 0)
        let bestKey = Self.matchBestTimeKey(courseId: courseId, lessonId: lessonId)
        let bestSeconds = UserDefaults.standard.object(forKey: bestKey) as? Int
        let bestStr = bestSeconds.map { formatGameTime($0) }

        return VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text("пары: \(matchedPairIds.count) из \(totalPairsCount) · попытки: \(tries)")
                    .font(CD.FontToken.body(15, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    Label(timeStr, systemImage: "timer")
                        .font(CD.FontToken.body(16, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                    if let best = bestStr, !best.isEmpty, best != timeStr {
                        Label("рекорд \(best)", systemImage: "star.fill")
                            .font(CD.FontToken.caption(13, weight: .medium))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    }
                }
            }

            if lessonId.isEmpty && !(lessonIds ?? []).isEmpty {
                Text(courseCompletionHint)
                    .font(CD.FontToken.body(13, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                    GameCompletionActions(
                        isFromLessonStep: isFromLessonStep,
                        isCourseReinforcement: lessonId.isEmpty && !(lessonIds ?? []).isEmpty,
                        isProUser: isProUser,
                    continueLearningTitle: resolvedContinueTitle,
                    nextGameTitle: nextGameTitle,
                    onRepeat: {
                        withAnimation(.easeOut(duration: 0.2)) { showSummary = false }
                        buildRound(force: true)
                    },
                    onNextGame: onNextGame,
                    onSpeakerPractice: onSpeakerPractice,
                    onContinueLearning: onContinueLearning,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.2)) { showSummary = false }
                        if let onClose { onClose() }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var activeGameBlock: some View {
        MPMatchPairsGrid(
            left: leftItems,
            right: rightItems,
            selectedLeft: selectedLeft,
            selectedRight: selectedRight,
            leftTitle: "",
            rightTitle: "",
            onTapLeft: { tapLeft($0) },
            onTapRight: { tapRight($0) },
            revealedIds: Set(flipStates.compactMap { $0.value ? $0.key : nil })
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Conversation flow (PRO)

    /// `AnyView` + явные `let`: на некоторых тулчейнах Swift иначе падает на `some View` (opaque) без вывода типа / краш компилятора.
    private var audioRecallFlowBody: AnyView {
        // Course-mode (lessonId == ""): берём learned-steps по всему курсу.
        // Lesson-mode: резолвим «какой урок использовать» для диалогового сценария.
        let lid: String = lessonId.isEmpty
        ? ""
        : GameLessonContextResolver.resolveConversationLessonId(courseId: courseId, explicitLessonId: lessonId)
        let title = audioRecallSourceTitle(resolvedLessonId: lid)
        let optionalClose = onClose
        return AnyView(
            AudioRecallGameView(
                courseId: courseId,
                lessonId: lid,
                sourceTitle: title,
                sourceContextTitle: courseTitleForSection(),
                onClose: {
                    if let performClose = optionalClose {
                        performClose()
                    } else {
                        dismiss()
                    }
                },
                onNextGame: onNextGame,
                nextGameTitle: nextGameTitle,
                isProUser: isProUser,
                onSpeakerPractice: onSpeakerPractice,
                onContinueLearning: onContinueLearning,
                continueLearningTitle: resolvedContinueTitle
            )
            .environmentObject(theme)
        )
    }

    private var grandDialogueFlowBody: AnyView {
        let optionalClose = onClose
        return AnyView(
            GrandDialogueGameView(
                courseId: courseId,
                courseTitle: courseTitleForSection(),
                onClose: {
                    if let performClose = optionalClose {
                        performClose()
                    } else {
                        dismiss()
                    }
                },
                onNextGame: onNextGame,
                nextGameTitle: nextGameTitle,
                isProUser: isProUser,
                onSpeakerPractice: onSpeakerPractice,
                onContinueLearning: onContinueLearning,
                continueLearningTitle: resolvedContinueTitle
            )
            .environmentObject(theme)
        )
    }

    /// Заголовок в шапке: если урок подставлен резолвером (курс без `lessonId`, избранное), показываем название урока.
    private func audioRecallSourceTitle(resolvedLessonId: String) -> String {
        let raw = lessonId.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty, !resolvedLessonId.isEmpty,
           let t = LessonsData.shared.lessonTitle(for: resolvedLessonId), !t.isEmpty {
            return t
        }
        return gameContextSourceTitle()
    }

    // MARK: - Recall Body (PRO recall game)

    private var recallCompletionTitle: String {
        switch gameType {
        case .builder: return "фразы в контексте — раунд завершён"
        case .recall: return "быстрое повторение завершено"
        case .match: return "тренировка завершена"
        case .conversation, .audioRecall: return "аудио-реплика завершена"
        case .grandDialogue: return "курсовая завершена"
        }
    }

    private func recallSyllableItems(round: HomeTaskManager.BuilderRound) -> [RecallSyllableItem] {
        let assembled = store.assembledBuilder
        let syllables = round.syllables
        let replaceMode = store.builderSelectedSlotForReplacement != nil
        let usedByText = Dictionary(grouping: assembled, by: { $0 }).mapValues(\.count)
        var consumedRank: [String: Int] = [:]
        return syllables.enumerated().map { index, text in
            let rank = consumedRank[text, default: 0]
            consumedRank[text] = rank + 1
            let isInUse = rank < (usedByText[text] ?? 0)
            let usedCount = usedByText[text] ?? 0
            let availableCount = syllables.filter { $0 == text }.count
            let canAdd = !isInUse && usedCount < availableCount && assembled.count < round.slotCount
            // Повторный тап по уже поставленному чипу — снять; в replace — любой свободный/пул.
            let isSelectable = replaceMode || isInUse || canAdd
            return RecallSyllableItem(id: index, text: text, isSelectable: isSelectable, isInUse: isInUse)
        }
    }

    @ViewBuilder
    private var recallBody: some View {
        GameShell(
            onClose: {
                if let onClose = onClose {
                    onClose()
                } else {
                    dismiss()
                }
            },
            gameHeaderConfig: nil,
            gameContextHeader: nil
        ) {
            Group {
                if let round = store.currentBuilderRound {
                    let roundDisplays: [RecallRoundDisplay] = store.builderRoundDisplays.map { d in
                        RecallRoundDisplay(id: d.id, question: d.question, target: d.target, thai: d.thai)
                    }
                    RecallGameView(
                        question: round.question,
                        phoneticDisplay: round.target,
                        progressText: "раунд \(store.builderIndex + 1)",
                        segments: round.segments,
                        syllableItems: recallSyllableItems(round: round),
                        slotCount: round.slotCount,
                        assembled: store.assembledBuilder,
                        isCorrect: {
                            switch store.builderState {
                            case .correct: return true
                            case .wrong: return false
                            default: return nil
                            }
                        }(),
                        wrongSlotIndices: store.builderWrongSlotIndices,
                        selectedSlotForReplacement: store.builderSelectedSlotForReplacement,
                        onTapSlot: { idx in
                            if store.builderState == .wrong {
                                if store.builderSelectedSlotForReplacement == idx {
                                    store.clearSlotForReplacement()
                                } else {
                                    store.selectSlotForReplacement(idx)
                                }
                            } else if store.builderState != .correct {
                                store.removeBuilderPiece(at: idx)
                            }
                        },
                        audioText: round.audioText,
                        onTapSyllable: { text, isInUse in
                            if isInUse, store.builderSelectedSlotForReplacement == nil {
                                store.removeLastBuilderPiece(matching: text)
                            } else {
                                store.appendBuilderPiece(text)
                            }
                        },
                        onPlayAudio: round.audioText.map { text in
                            { StepAudio.shared.speakThai(text) }
                        },
                        onRemoveLast: { store.removeLastBuilderPiece() },
                        onReset: { store.resetBuilder() },
                        onCheck: { store.checkBuilderAnswer() },
                        onNextRound: { store.advanceBuilderRound() },
                        roundText: "раунд \(store.builderIndex + 1)",
                        scoreText: "\(store.builderScore)",
                        isLocked: store.builderState == .correct,
                        roundDisplays: roundDisplays.isEmpty ? nil : roundDisplays,
                        currentRoundIndex: store.builderIndex,
                        onSelectRound: { store.selectBuilderRound(at: $0) },
                        lessonTitle: displayTitle ?? gameContextSourceTitle(),
                        statusTimeText: {
                            let m = recallElapsedSeconds / 60
                            let s = recallElapsedSeconds % 60
                            return String(format: "%d:%02d", m, s)
                        }(),
                        statusProgressText: "\(store.builderIndex + 1)/\(max(1, store.builderTotalRounds))",
                        statusMistakes: store.builderMistakeCount,
                        statusScore: store.builderScore
                    )
                } else {
                    TaikaLoadingView(label: "подготовка…", compact: true)
                        .onAppear { startRecallGame() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                    if store.builderState == .finished {
                        recallCompletionOverlay
                            .zIndex(100)
                            .transition(.opacity)
                    }
                }
        }
        .onAppear {
            recallElapsedSeconds = 0
            didRecordReinforcementSession = false
            GameHeaderStore.shared.config = recallHeaderConfig()
        }
        .onDisappear {
            GameHeaderStore.shared.config = nil
        }
        .onChange(of: store.builderIndex) { _, _ in
            GameHeaderStore.shared.config = recallHeaderConfig()
        }
        .onChange(of: store.builderScore) { _, _ in
            GameHeaderStore.shared.config = recallHeaderConfig()
        }
        .onChange(of: store.builderMistakeCount) { _, _ in
            GameHeaderStore.shared.config = recallHeaderConfig()
        }
        .onChange(of: store.builderAttemptCount) { _, _ in
            GameHeaderStore.shared.config = recallHeaderConfig()
        }
        .onChange(of: recallElapsedSeconds) { _, _ in
            GameHeaderStore.shared.config = recallHeaderConfig()
        }
        .onChange(of: store.builderState) { _, newState in
            if newState == .correct {
                TaikaGameFeedbackHaptics.answerCorrect()
                if let round = store.currentBuilderRound, let text = round.audioText, !text.isEmpty {
                    StepAudio.shared.speakThai(text)
                }
            } else if newState == .wrong {
                TaikaGameFeedbackHaptics.mismatch()
                TaikaVoice.shared.playMatchFail()
            } else if newState == .finished {
                if !didRecordReinforcementSession, !isGlobalParkContext {
                    didRecordReinforcementSession = true
                    let total = max(1, store.builderTotalRounds)
                    let percent = max(0, min(100, Int((Double(store.builderScore) / Double(total) * 100).rounded())))
                    ReinforcementStore.shared.recordSession(
                        courseId: courseId,
                        gameType: "recall",
                        score: percent,
                        lessonIds: reinforcementLessonScope
                    )
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if store.currentBuilderRound != nil {
                recallElapsedSeconds += 1
            }
        }
    }

    private func recallHeaderConfig() -> GameHeaderConfig {
        let total = max(1, store.builderTotalRounds)
        // Время уже в status-чипах — в хедере не дублируем (и не красим в accent).
        return GameHeaderConfig(
            timeText: "",
            score: store.builderScore,
            mistakes: store.builderMistakeCount,
            streak: 0,
            progressText: "раунд \(store.builderIndex + 1) из \(total)",
            gameTitle: "Быстрое повторение",
            sourceTitle: recallLessonChipTitle(),
            minimalGameChrome: false,
            onBack: {
                if let onClose = onClose {
                    onClose()
                } else {
                    dismiss()
                }
            }
        )
    }

    /// Тройки для Recall: курс/урок/избранное (используется при старте и при «Повторить»).
    private func recallTriples() -> [HomeTaskManager.LearnedTriple] {
        let (ccid, clid) = canonicalIds()
        var triples: [HomeTaskManager.LearnedTriple]
        if lessonId.isEmpty {
            if isFavoritesContext {
                triples = store.userTriplesForCourse(courseId: "__favorites__", lessonIds: [])
            } else if isDictionaryContext {
                triples = store.userTriplesForCourse(courseId: DictionaryGameSource.courseId, lessonIds: [])
            } else if isLearnedParkContext {
                triples = store.userTriplesForCourse(courseId: LearnedGameSource.pseudoCourseId, lessonIds: [])
            } else {
                let lessonIds = catalogLessonsSortedForCourse(courseId).map { $0.lessonID }
                triples = lessonIds.isEmpty ? [] : store.userTriplesForCourse(courseId: ccid, lessonIds: lessonIds)
            }
        } else {
            triples = store.userTriples(for: ccid, lessonId: clid)
            if triples.isEmpty { triples = store.userTriples(for: courseId, lessonId: lessonId) }
        }
        triples = triples.filter { !$0.ru.isEmpty && !$0.ph.isEmpty }
        if triples.isEmpty && isPreview { triples = demoTriples() }
        return triples
    }

    private func startRecallGame() {
        let triples = recallTriples()
        guard !triples.isEmpty else { return }
        didRecordReinforcementSession = false
        store.startBuilderRound(from: triples)
    }

    /// Оверлей завершения Recall: счёт, время, Повторить / Следующая игра (не кружить по кругу).
    @ViewBuilder
    private var recallCompletionOverlay: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: {})

            OverlayEtalonCard(title: recallCompletionTitle, onDismiss: {
                if let onClose { onClose() }
            }) {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        let total = max(1, store.builderTotalRounds)
                        Text("фраз: \(store.builderScore) из \(total)")
                            .font(CD.FontToken.body(15, weight: .regular))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                        let m = recallElapsedSeconds / 60
                        let s = recallElapsedSeconds % 60
                        Text(String(format: "%d:%02d", m, s))
                            .font(CD.FontToken.body(16, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text)
                    }

                    GameCompletionActions(
                        isFromLessonStep: isFromLessonStep,
                        isCourseReinforcement: lessonId.isEmpty && !(lessonIds ?? []).isEmpty,
                        isProUser: isProUser,
                        continueLearningTitle: resolvedContinueTitle,
                        nextGameTitle: nextGameTitle,
                        onRepeat: { startRecallGame() },
                        onNextGame: onNextGame,
                        onSpeakerPractice: onSpeakerPractice,
                        onContinueLearning: onContinueLearning,
                        onClose: {
                            if let onClose { onClose() }
                        }
                    )
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 20)
            }
        }
    }

    // DS header: title + tiny hint (matches HomeTaskDS look)
    private var dsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("подобрать пару")
                .font(CD.FontToken.title(26, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
            HStack(spacing: 8) {
                Circle()
                    .foregroundStyle(theme.currentAccentFill)
                    .frame(width: 6, height: 6)
                Text("найди совпадения слева и справа")
                    .font(CD.FontToken.body(13, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("нет пар для матча")
                .font(CD.FontToken.body(16, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button("обновить") { buildRound(force: true) }
                .font(CD.FontToken.body(15, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().stroke(theme.currentAccentFill, lineWidth: 1))
        }
        .padding(20)
    }

    // MARK: - Logic
    private var isFinished: Bool { totalPairsCount > 0 && matchedPairIds.count >= totalPairsCount }

    private func titleForLesson() -> String {
        if let t = displayTitle, !t.isEmpty { return t }
        let title = resolvedLessonTitle()
        return "\(title) — подобрать пару"
    }

    private func resolvedLessonTitle() -> String {
        // Try LessonsData with dashed IDs first
        let (_, clid) = canonicalIds()
        if let t = LessonsData.shared.lessonTitle(for: clid), !t.isEmpty { return t }
        // Fallback to original lessonId
        if let t = LessonsData.shared.lessonTitle(for: lessonId), !t.isEmpty { return t }
        // Graceful fallback: derive "Урок N" from id like "lesson_1" or "..._l8"
        if let n = lessonNumber(from: lessonId) { return "Урок \(n)" }
        return "Урок"
    }

    /// Course or lesson name for second header (unified with Speaker).
    private func gameContextSourceTitle() -> String {
        if isFavoritesContext { return "Избранное" }
        if isDictionaryContext { return "Мой словарь" }
        if isLearnedParkContext { return "Все выученные" }
        let (ccid, _) = canonicalIds()
        if !lessonId.isEmpty {
            return resolvedLessonTitle()
        }
        return CourseData.shared.title(for: ccid) ?? CourseData.shared.title(for: courseId) ?? courseId
    }

    private static func matchBestTimeKey(courseId: String, lessonId: String) -> String {
        let safe = "\(courseId)_\(lessonId)".replacingOccurrences(of: " ", with: "_")
        return "taika_match_best_\(safe)"
    }

    private func formatGameTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func gameHeaderConfigForMatch() -> GameHeaderConfig {
        let total = totalPairsCount
        let progressText = total <= 0
            ? "нет пар"
            : "\(matchedPairIds.count) из \(total) пар"
        return GameHeaderConfig(
            timeText: "",
            score: matchedPairIds.count,
            mistakes: tries,
            streak: 0,
            progressText: progressText,
            gameTitle: "Найди пару",
            sourceTitle: courseTitleForSection(),
            onBack: {
                if let onClose = onClose {
                    onClose()
                } else {
                    dismiss()
                }
            }
        )
    }

    private func gameContextHeaderForMatch() -> GameContextHeader {
        let total = totalPairsCount
        return GameContextHeader(
            sourceTitle: gameContextSourceTitle(),
            cardCount: max(0, total),
            attemptCount: tries,
            avgScore: 0,
            progressCurrent: matchedPairIds.count,
            progressTotal: total,
            elapsedSeconds: gameElapsedSeconds
        )
    }

    private func gameContextHeaderForRecall() -> GameContextHeader {
        let cardCount = store.builderRoundDisplays.count
        return GameContextHeader(
            sourceTitle: gameContextSourceTitle(),
            cardCount: max(1, cardCount),
            attemptCount: store.builderScore,
            avgScore: 0
        )
    }

    private func lessonNumber(from raw: String) -> Int? {
        // Extract trailing digits after "lesson_" or "_l"
        let patterns = ["lesson_([0-9]+)$", "_l([0-9]+)$"]
        for p in patterns {
            if let r = raw.range(of: p, options: .regularExpression) {
                let sub = String(raw[r])
                let digits = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let num = Int(digits) {
                    return num
                }
            }
        }
        return nil
    }

    private func canonicalIds() -> (String, String) {
        // Progress stores ids with dashes; lessons may come with underscores
        let cid = courseId.replacingOccurrences(of: "_", with: "-")
        let lid = lessonId.replacingOccurrences(of: "_", with: "-")
        return (cid, lid)
    }

    private var isFavoritesContext: Bool {
        let raw = courseId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return raw == "__favorites__" || raw == "--favorites--"
    }

    private var isDictionaryContext: Bool {
        DictionaryGameSource.isDictionaryCourseId(courseId)
    }

    private var isLearnedParkContext: Bool {
        LearnedGameSource.isPseudoCourseId(courseId)
    }

    private var isGlobalParkContext: Bool {
        isFavoritesContext || isDictionaryContext || isLearnedParkContext
    }

    /// The course reinforcement scope is the fallback when legacy learned cards lack lesson metadata.
    private var reinforcementLessonScope: [String] {
        let scoped = (lessonIds ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !scoped.isEmpty { return scoped }
        let single = lessonId.trimmingCharacters(in: .whitespacesAndNewlines)
        return single.isEmpty ? [] : [single]
    }

    /// Persist the exact source cards encountered in this completed match session.
    /// Global Game Park is grouped back into real courses instead of writing to the pseudo-course.
    private func recordMatchedGameMastery() {
        guard !isFavoritesContext, !isDictionaryContext else { return }
        let total = max(1, totalPairsCount)
        let attempts = max(1, tries)
        let accuracy = Double(total) / Double(attempts)
        let percent = max(0, min(100, Int((accuracy * 100).rounded())))
        let matched = allTriples.filter { matchedPairIds.contains("\($0.ru)|\($0.ph)") }
        if matched.isEmpty {
            let scope = reinforcementLessonScope
            guard !scope.isEmpty else { return }
            ReinforcementStore.shared.recordSession(
                courseId: courseId,
                gameType: "match",
                score: percent,
                lessonIds: scope
            )
            return
        }
        let grouped = Dictionary(grouping: matched) { triple in
            let sourceCourse = triple.courseId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return sourceCourse.isEmpty ? courseId : sourceCourse
        }
        for (sourceCourseId, triples) in grouped {
            guard !LearnedGameSource.isPseudoCourseId(sourceCourseId) else { continue }
            let sourceKeys = triples.compactMap { triple -> String? in
                guard let lesson = triple.lessonId?.trimmingCharacters(in: .whitespacesAndNewlines), !lesson.isEmpty else { return nil }
                let phrase = triple.ru.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !phrase.isEmpty else { return nil }
                return "\(lesson)|\(phrase)"
            }
            ReinforcementStore.shared.recordSession(
                courseId: sourceCourseId,
                gameType: "match",
                score: percent,
                sourceCardKeys: sourceKeys,
                lessonIds: reinforcementLessonScope
            )
        }
    }

    /// Lessons catalog for course-level mode (lessonId == "").
    /// Course ids can be referenced with dash/underscore variants; all games must see the same lesson set.
    private func catalogLessonsSortedForCourse(_ rawCourseId: String) -> [LessonBundle] {
        var list = LessonsData.shared.lessons(for: rawCourseId)
        if list.isEmpty {
            list = LessonsData.shared.lessons(for: rawCourseId.replacingOccurrences(of: "_", with: "-"))
        }
        if list.isEmpty {
            list = LessonsData.shared.lessons(for: rawCourseId.replacingOccurrences(of: "-", with: "_"))
        }
        return list.sorted { $0.order < $1.order }
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private func demoTriples() -> [HomeTaskManager.LearnedTriple] {
        return [
            .init(ru: "привет", th: "", ph: "са-ват-ди"),
            .init(ru: "здравствуйте", th: "", ph: "са-ват-ди кхрап"),
            .init(ru: "приветик (мягко)", th: "", ph: "са-ват-ди ик-кхранг"),
            .init(ru: "всем привет!", th: "", ph: "ват-ди на"),
            .init(ru: "добро пожаловать!", th: "", ph: "йин-ди тон-рап"),
            .init(ru: "привет ещё раз", th: "", ph: "са-ват-ди тук-кхон")
        ]
    }

    private func buildRound(force: Bool = false) {
        // pull learned pairs directly from progress (try canonical dashed ids first)
        let (ccid, clid) = canonicalIds()
        var triples: [HomeTaskManager.LearnedTriple] = []

        if lessonId.isEmpty {
            // COURSE MODE / FAVORITES / ALL LEARNED (парк с Main)
            if isFavoritesContext {
                triples = store.userTriplesForCourse(courseId: "__favorites__", lessonIds: [])
            } else if isDictionaryContext {
                triples = store.userTriplesForCourse(courseId: DictionaryGameSource.courseId, lessonIds: [])
            } else if isLearnedParkContext {
                triples = store.userTriplesForCourse(courseId: LearnedGameSource.pseudoCourseId, lessonIds: [])
            } else {
                let scopedLessonIds = lessonIds?.filter { !$0.isEmpty } ?? []
                let lessonIdsToUse = scopedLessonIds.isEmpty
                    ? catalogLessonsSortedForCourse(courseId).map { $0.lessonID }
                    : scopedLessonIds
                if !lessonIdsToUse.isEmpty {
                    triples = store.userTriplesForCourse(courseId: ccid, lessonIds: lessonIdsToUse)
                }
            }
        } else {
            // LESSON MODE
            triples = store.userTriples(for: ccid, lessonId: clid)
            if triples.isEmpty {
                triples = store.userTriples(for: courseId, lessonId: lessonId)
            }
        }
        if triples.isEmpty && isPreview { triples = demoTriples() }
        triples = triples.filter { !$0.ru.isEmpty && !$0.ph.isEmpty }
        guard !triples.isEmpty else { leftItems = []; rightItems = []; totalPairsCount = 0; return }

        // Reset all state
        allTriples = triples.shuffled()
        totalPairsCount = allTriples.count
        matchedPairIds = []
        tries = 0
        gameElapsedSeconds = 0
        didRecordReinforcementSession = false
        selectedLeft = nil; selectedRight = nil

        // Seed visible with up to 5 pairs
        let seedCount = min(visiblePairsTarget, allTriples.count)
        let seed = Array(allTriples.prefix(seedCount))
        remainingTriples = Array(allTriples.dropFirst(seedCount))

        var L: [MPItem] = []
        var R: [MPItem] = []
        for t in seed {
            let pid = "\(t.ru)|\(t.ph)"
            L.append(.init(pairId: pid, text: t.ph, side: .left, hasAudio: true))
            R.append(.init(pairId: pid, text: t.ru, side: .right))
        }
        leftItems = L.shuffled()
        rightItems = R.shuffled()
        // reset states
        for i in leftItems.indices { leftItems[i].state = .idle }
        for j in rightItems.indices { rightItems[j].state = .idle }

        // Prepare reveal states: if intro already ran, default all to revealed
        let ids = Set(leftItems.map { $0.pairId } + rightItems.map { $0.pairId })
        if didRunIntro {
            var dict: [String: Bool] = [:]
            ids.forEach { dict[$0] = true }
            flipStates = dict
            gridOpacity = 1
        } else {
            // intro will manage flipStates itself
            flipStates = [:]
            gridOpacity = 0
        }
    }

    private func introduceNextPairIfNeeded() {
        // Keep up to visiblePairsTarget pairs visible until we exhaust remainingTriples
        guard !remainingTriples.isEmpty else { return }
        let need = max(0, visiblePairsTarget - currentVisiblePairsCount())
        guard need > 0 else { return }
        let take = min(need, remainingTriples.count)
        let newcomers = Array(remainingTriples.prefix(take))
        remainingTriples.removeFirst(take)
        for t in newcomers {
            let pid = "\(t.ru)|\(t.ph)"
            leftItems.append(.init(pairId: pid, text: t.ph, side: .left, hasAudio: true))
            rightItems.append(.init(pairId: pid, text: t.ru, side: .right))
        }
        // Shuffle all cards after adding newcomers
        leftItems.shuffle()
        rightItems.shuffle()
        // seed backs for newcomers, then flip to face shortly
        for t in newcomers {
            let pid = "\(t.ru)|\(t.ph)"
            flipStates[pid] = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                for t in newcomers {
                    let pid = "\(t.ru)|\(t.ph)"
                    flipStates[pid] = true
                }
                // Shuffle again after reveal animation to randomize grid
                leftItems.shuffle()
                rightItems.shuffle()
            }
        }
    }

    private func currentVisiblePairsCount() -> Int {
        // left/right arrays include matched items; count unique pairIds minus those already matched
        let ids = Set(leftItems.map { $0.pairId })
        return ids.subtracting(matchedPairIds).count
    }

    private func tapLeft(_ idx: Int) {
        guard leftItems.indices.contains(idx) else { return }
        if leftItems[idx].state == .matched { return }
        // Озвучка только при выборе карточки (не при снятии выбора)
        let isSelecting = (selectedLeft != idx)
        if isSelecting, let thai = thaiForPairId(leftItems[idx].pairId), !thai.isEmpty {
            StepAudio.shared.speakThai(thai)
        }
        // clear previous selection state
        if let p = selectedLeft, leftItems.indices.contains(p) {
            leftItems[p].state = .idle
        }
        withAnimation(TaikaGameFeedbackMotion.pairSelectSpring) {
            selectedLeft = (selectedLeft == idx) ? nil : idx
        }
        // apply selected state
        if let s = selectedLeft {
            leftItems[s].state = .selected
        }
        tryResolve()
    }

    private func tapRight(_ idx: Int) {
        guard rightItems.indices.contains(idx) else { return }
        if rightItems[idx].state == .matched { return }
        if let p = selectedRight, rightItems.indices.contains(p) {
            rightItems[p].state = .idle
        }
        withAnimation(TaikaGameFeedbackMotion.pairSelectSpring) {
            selectedRight = (selectedRight == idx) ? nil : idx
        }
        if let s = selectedRight {
            rightItems[s].state = .selected
        }
        tryResolve()
    }

    private func tryResolve() {
        guard let li = selectedLeft, let ri = selectedRight,
              leftItems.indices.contains(li), rightItems.indices.contains(ri) else { return }
        tries += 1
        let L = leftItems[li]; let R = rightItems[ri]
        if L.pairId == R.pairId {
            matchedPairIds.insert(L.pairId)
            // mark matched visually
            leftItems[li].state = .matched
            rightItems[ri].state = .matched
            TaikaGameFeedbackHaptics.matchSuccess()
            TaikaVoice.shared.playMatchSuccess()

            // If we still have newcomers in the pool, remove matched and introduce next pair
            let canIntroduceMore = !remainingTriples.isEmpty
            if canIntroduceMore {
                // remove matched items from the visible lists
                leftItems.removeAll { $0.pairId == L.pairId }
                rightItems.removeAll { $0.pairId == R.pairId }
                flipStates[L.pairId] = nil
                introduceNextPairIfNeeded()
            } else {
                // pool exhausted — keep matched cards on screen to preserve visiblePairsTarget
            }
            selectedLeft = nil; selectedRight = nil
            // Последняя пара → сыграть «табло»-аутро (всё на рубашку), затем показать summary
            if matchedPairIds.count >= totalPairsCount {
                showSummary = true
            }
        } else {
            TaikaGameFeedbackHaptics.mismatch()
            // brief wrong pulse + случайно: оой или match_fail.mp3
            if Bool.random() {
                TaikaVoice.shared.playMatchFail()
            } else {
                StepAudio.shared.speakThai("โอ้ย")
            }
            leftItems[li].state = .wrong
            rightItems[ri].state = .wrong
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                if leftItems.indices.contains(li) { leftItems[li].state = .idle }
                if rightItems.indices.contains(ri) { rightItems[ri].state = .idle }
                selectedLeft = nil; selectedRight = nil
            }
        }
    }

    // Tabloid-style intro flipping animation
    private func startTabloidIntro() {
        flipCycle = 0
        let ids = Set(leftItems.map { $0.pairId } + rightItems.map { $0.pairId })
        flipStates = Dictionary<String, Bool>(uniqueKeysWithValues: ids.map { (key: String) in (key, false) })
        gridOpacity = 1
        flipTimer?.invalidate()
        flipTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { timer in
            Task { @MainActor in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                    for key in flipStates.keys {
                        if Bool.random() { flipStates[key]?.toggle() }
                    }
                }
                flipCycle += 1
                if flipCycle > 8 {
                    timer.invalidate()
                    flipTimer = nil
                    withAnimation(.easeOut(duration: 0.4)) {
                        for key in flipStates.keys { flipStates[key] = true }
                    }
                }
            }
        }
    }

    // Tabloid-style outro: random flips ending with all backs, then show summary
    private func startTabloidOutroAndShowSummary() {
        // flipTimer?.invalidate()
        // let ids = Set(leftItems.map { $0.pairId } + rightItems.map { $0.pairId })
        // var cycles = 0
        // flipTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { timer in
        //     Task { @MainActor in
        //         withAnimation(.easeInOut(duration: 0.16)) {
        //             for id in ids where Bool.random() { flipStates[id]?.toggle() }
        //         }
        //         cycles += 1
        //         if cycles > 6 {
        //             timer.invalidate()
        //             flipTimer = nil
        //             withAnimation(.easeOut(duration: 0.28)) {
        //                 for id in ids { flipStates[id] = false }
        //             }
        //             DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        //                 Task { @MainActor in showSummary = true }
        //             }
        //         }
        //     }
        // }
        showSummary = true
    }

    /// Thai текст сматченной карточки для озвучки (из allTriples по pairId).
    private func thaiForPairId(_ pairId: String) -> String? {
        guard let first = pairId.split(separator: "|", maxSplits: 1).first,
              let last = pairId.split(separator: "|", maxSplits: 1).last else { return nil }
        let ru = String(first)
        let ph = String(last)
        return allTriples.first { "\($0.ru)|\($0.ph)" == pairId }?.th
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#if DEBUG
struct HomeTaskView_Previews: PreviewProvider {
    static var previews: some View {
        let s = HomeTaskManager()
        s.setTasks([
            HTask(courseId: "course_demo",
                  lessonIndex: 0,
                  gameType: .match,
                  title: "урок #1",
                  details: "",
                  status: .available)
        ], for: "course_demo")
        return HomeTaskView(courseId: "course_demo",
                            lessonId: "lesson_1",
                            embedBackground: true,
                            store: s,
                            displayTitle: "Урок 1 — подобрать пару",
                            gameType: .match)
            .environmentObject(ThemeManager.shared)
    }
}
#endif
