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
    public let embedBackground: Bool
    public let onClose: (() -> Void)?
    public let onNextGame: (() -> Void)?
    /// Название следующей игры (для не‑Pro: подпись на заблокированной кнопке с короной).
    public let nextGameTitle: String?
    public let isProUser: Bool
    public let displayTitle: String?
    public let gameType: HomeGameType
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
                embedBackground: Bool = false,
                store: HomeTaskManager? = nil,
                onClose: (() -> Void)? = nil,
                onNextGame: (() -> Void)? = nil,
                nextGameTitle: String? = nil,
                isProUser: Bool = true,
                displayTitle: String? = nil,
                gameType: HomeGameType = .match) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.embedBackground = embedBackground
        self.onClose = onClose
        self.onNextGame = onNextGame
        self.nextGameTitle = nextGameTitle
        self.isProUser = isProUser
        self.displayTitle = displayTitle
        self.gameType = gameType
        _store = StateObject(wrappedValue: store ?? HomeTaskManager())
    }

    public var body: some View {
        Group {
            switch currentGameType {
            case .match:
                matchBody
            case .recall:
                recallBody
            case .builder:
                matchBody
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Game Type Routing

    private var currentGameType: HomeGameType {
        return gameType
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
        switch gameType {
        case .match: return "Найди пару"
        case .recall: return "Быстрое повторение"
        case .builder: return "Фразы в контексте"
        }
    }

    /// Название курса для правой части секции (без дублирования с чипом урока в карточке).
    private func courseTitleForSection() -> String {
        let (ccid, _) = canonicalIds()
        if ccid == "__favorites__" { return "Избранное" }
        return CourseData.shared.title(for: ccid) ?? CourseData.shared.title(for: courseId) ?? ccid
    }

    /// Стандартная секция: слева название игры, справа название курса (в карточке — чип с названием урока).
    private var gameSectionHeader: some View {
        HStack {
            Text(currentGameDisplayName().uppercased())
                .font(CD.FontToken.caption(12, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(CD.ColorToken.textSecondary)
            Spacer(minLength: 8)
            Text(courseTitleForSection().uppercased())
                .font(CD.FontToken.caption(12, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(CD.ColorToken.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var contentBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            gameSectionHeader
                .padding(.bottom, 10)

            if leftItems.isEmpty || rightItems.isEmpty {
                emptyState
                    .onAppear {
                        buildRound()
                        if !didRunIntro {
                            didRunIntro = true
                            startTabloidIntro()
                        }
                    }
            } else {
                if !isFinished {
                    Text("найди пары. не спеши. слушай, чувствуй, сопоставляй.")
                        .font(CD.FontToken.caption(13, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                        .padding(.bottom, 10)
                } else {
                    Text("ну что, закрепили? хочешь ещё раунд?")
                        .font(CD.FontToken.caption(13, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                        .padding(.bottom, 10)
                }
                activeGameBlock
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 32)
        .overlay {
            if showSummary {
                completionOverlay
                    .zIndex(100)
                    .transition(.opacity)
                    .allowsHitTesting(true)
            }
        }
    }

    /// Оверлей итогов в том же UI/UX, что и PRO (корона): фон 0.35, карточка material+чёрный, хедер taikA + крестик.
    @ViewBuilder
    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { showSummary = false }
                }

            VStack(spacing: 20) {
                // Хедер как в PRO: слева логотип, справа крестик
                HStack {
                    Text("taikA")
                        .font(.taikaLogo(16))
                        .foregroundStyle(CD.ColorToken.text)
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { showSummary = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Text("закрепление завершено")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .frame(maxWidth: .infinity)

                finishedBlockContent
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 24, y: 14)
            .frame(maxWidth: 420)
            .padding(.horizontal, 20)
        }
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

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.2)) { showSummary = false }
                    buildRound(force: true)
                } label: {
                    Text("Повторить")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(white: 0.14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.currentAccentFill))
                }
                .buttonStyle(.plain)

                if isProUser, onNextGame != nil {
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.easeOut(duration: 0.2)) { showSummary = false }
                        onNextGame?()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Следующая игра")
                                .font(CD.FontToken.body(15, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(theme.currentAccentFill)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.currentAccentFill, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                        Text(nextGameTitle ?? "Следующая игра")
                            .font(CD.FontToken.body(15, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PD.ColorToken.card.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.6), lineWidth: 1))
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var activeGameBlock: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

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
            .padding(.horizontal, 16)

            Spacer(minLength: 12)
        }
    }

    // MARK: - Recall Body (PRO recall game)

    private func recallSyllableItems(round: HomeTaskManager.BuilderRound) -> [RecallSyllableItem] {
        let assembled = store.assembledBuilder
        let syllables = round.syllables
        let replaceMode = store.builderSelectedSlotForReplacement != nil
        return syllables.enumerated().map { index, text in
            let usedCount = assembled.filter { $0 == text }.count
            let availableCount = syllables.filter { $0 == text }.count
            let isSelectable = (usedCount < availableCount && assembled.count < round.slotCount) || replaceMode
            return RecallSyllableItem(id: index, text: text, isSelectable: isSelectable)
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
                VStack(alignment: .leading, spacing: Theme.Layout.sectionContentV) {
                    gameSectionHeader
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
                            if store.builderSelectedSlotForReplacement == idx {
                                store.clearSlotForReplacement()
                            } else {
                                store.selectSlotForReplacement(idx)
                            }
                        },
                        audioText: round.audioText,
                        onTapSyllable: { store.appendBuilderPiece($0) },
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
                        lessonTitle: displayTitle ?? gameContextSourceTitle()
                    )
                } else {
                    TaikaLoadingView(label: "подготовка…", compact: true)
                        .onAppear { startRecallGame() }
                }
                    }
                    .padding(.top, Theme.Layout.sectionTitleToContent)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
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
        .onChange(of: store.builderAttemptCount) { _, _ in
            GameHeaderStore.shared.config = recallHeaderConfig()
        }
        .onChange(of: recallElapsedSeconds) { _, _ in
            GameHeaderStore.shared.config = recallHeaderConfig()
        }
        .onChange(of: store.builderState) { _, newState in
            if newState == .correct {
                if let round = store.currentBuilderRound, let text = round.audioText, !text.isEmpty {
                    StepAudio.shared.speakThai(text)
                }
            } else if newState == .wrong {
                TaikaVoice.shared.playMatchFail()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if store.currentBuilderRound != nil {
                recallElapsedSeconds += 1
            }
        }
    }

    private func recallHeaderConfig() -> GameHeaderConfig {
        let m = recallElapsedSeconds / 60
        let s = recallElapsedSeconds % 60
        let timeText = String(format: "%d:%02d", m, s)
        let total = max(1, store.builderTotalRounds)
        return GameHeaderConfig(
            timeText: timeText,
            score: store.builderScore,
            mistakes: store.builderAttemptCount,
            streak: 0,
            progressText: "\(store.builderIndex + 1)/\(total)",
            sourceTitle: gameContextSourceTitle(),
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
            if ccid == "__favorites__" {
                triples = store.userTriplesForCourse(courseId: "__favorites__", lessonIds: [])
            } else {
                let lessonIds = LessonsData.shared.lessons(for: courseId).map { $0.lessonID }
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
        store.startBuilderRound(from: triples)
    }

    /// Оверлей завершения Recall: счёт, время, Повторить / Следующая игра (не кружить по кругу).
    @ViewBuilder
    private var recallCompletionOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Text("taikA")
                        .font(.taikaLogo(16))
                        .foregroundStyle(CD.ColorToken.text)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Text("быстрое повторение завершено")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .frame(maxWidth: .infinity)

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

                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        startRecallGame()
                    } label: {
                        Text("Повторить")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(white: 0.14))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.currentAccentFill))
                    }
                    .buttonStyle(.plain)

                    if isProUser, let onNext = onNextGame {
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            onNext()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Следующая игра")
                                    .font(CD.FontToken.body(15, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(theme.currentAccentFill)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.currentAccentFill, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16))
                            Text(nextGameTitle ?? "Следующая игра")
                                .font(CD.FontToken.body(15, weight: .medium))
                        }
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(PD.ColorToken.card.opacity(0.6)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.6), lineWidth: 1))
                        .allowsHitTesting(false)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 24, y: 14)
            .frame(maxWidth: 420)
            .padding(.horizontal, 20)
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
        if courseId == "__favorites__" { return "Избранное" }
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
        let total = max(1, totalPairsCount)
        let m = gameElapsedSeconds / 60
        let s = gameElapsedSeconds % 60
        let timeText = String(format: "%d:%02d", m, s)
        return GameHeaderConfig(
            timeText: timeText,
            score: matchedPairIds.count,
            mistakes: tries,
            streak: 0,
            progressText: "\(matchedPairIds.count) из \(total)",
            sourceTitle: gameContextSourceTitle(),
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
        let total = max(1, totalPairsCount)
        return GameContextHeader(
            sourceTitle: gameContextSourceTitle(),
            cardCount: total,
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
            // COURSE MODE or FAVORITES: all learned cards from course, or from favorites when courseId == "__favorites__"
            if ccid == "__favorites__" {
                triples = store.userTriplesForCourse(courseId: "__favorites__", lessonIds: [])
            } else {
                let lessonIds = LessonsData.shared.lessons(for: courseId).map { $0.lessonID }
                if !lessonIds.isEmpty {
                    triples = store.userTriplesForCourse(courseId: ccid, lessonIds: lessonIds)
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
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
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
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
            .preferredColorScheme(.dark)
            .environmentObject(ThemeManager.shared)
    }
}
#endif
