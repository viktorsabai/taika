import SwiftUI

// Типы и движок — `GrandDialogueModels.swift` (меньше нагрузка на type checker в одном файле с View).

/// Курсовая: финальный диалог с Тайкой — сценарий из пройденных уроков, ответ голосом.
@MainActor
struct GrandDialogueGameView: View {

    let courseId: String
    let courseTitle: String
    let onClose: () -> Void
    let onNextGame: (() -> Void)?
    let nextGameTitle: String?
    let isProUser: Bool
    var onSpeakerPractice: (() -> Void)? = nil
    var onContinueLearning: (() -> Void)? = nil
    var continueLearningTitle: String? = nil

    @EnvironmentObject private var theme: ThemeManager
    @ObservedObject private var recorder = SpeakerRecorder.shared

    @State private var sessionPhase: SessionPhase = .intro
    @State private var turns: [GrandDialogueTurn] = []
    @State private var turnIndex: Int = 0
    @State private var phase: TurnPhase = .listen
    @State private var elapsedSeconds: Int = 0
    @State private var score: Int = 0
    @State private var finished: Bool = false
    @State private var statusLine: String = ""
    @State private var isEvaluating: Bool = false
    @State private var lastScore: Int = 0
    @State private var didRecordReinforcementSession: Bool = false
    @State private var messages: [DialogueMessage] = []
    @State private var isTaikaTyping: Bool = false
    @State private var promptShownTurnIndex: Int = -1

    private enum SessionPhase {
        case intro
        case dialogue
    }

    private enum TurnPhase: Equatable {
        case listen
        case record
        case feedback(pass: Bool)
    }

    private struct DialogueMessage: Identifiable {
        enum Role { case taika, user }
        let id: UUID = UUID()
        let role: Role
        let text: String
        let subtitle: String?
    }

    private var canonicalCourseIds: [String] {
        let raw = courseId.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        var out: [String] = []
        func add(_ s: String) {
            guard !s.isEmpty, seen.insert(s).inserted else { return }
            out.append(s)
        }
        add(raw)
        add(raw.replacingOccurrences(of: "_", with: "-"))
        add(raw.replacingOccurrences(of: "-", with: "_"))
        return out
    }

    private var courseCompleted: Bool {
        for cid in canonicalCourseIds {
            let lessonsTotal = LessonsData.shared.lessons(for: cid).count
            let (done, total) = LessonsManager.shared.headerCounts(for: cid, lessonsTotal: lessonsTotal)
            if total > 0 && done >= total {
                return true
            }
        }
        return canonicalCourseIds.contains { LessonsManager.shared.courseStatus(for: $0) == .completed }
    }

    private var currentTurn: GrandDialogueTurn? {
        guard turnIndex < turns.count else { return nil }
        return turns[turnIndex]
    }

    private let passThreshold: Int = 75
    private let maxSessionTurns: Int = 12
    private let uiCorner: CGFloat = Theme.Radii.card

    var body: some View {
        GameShell(
            onClose: {
                stopRecordingIfNeeded()
                onClose()
            },
            gameHeaderConfig: nil,
            gameContextHeader: nil
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if !courseCompleted {
                    lockedState
                } else if turns.isEmpty {
                    emptyPairsState
                } else if sessionPhase == .intro {
                    introState
                } else if finished {
                    Color.clear.frame(height: 1)
                } else {
                    activeTurn
                }
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.top, 4)
            .overlay {
                if finished {
                    completionOverlay
                        .zIndex(100)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            reloadSession()
            GameHeaderStore.shared.config = headerConfig()
        }
        .onDisappear {
            stopRecordingIfNeeded()
            GameHeaderStore.shared.config = nil
        }
        .onChange(of: turnIndex) { _, _ in
            enqueuePromptIfNeeded()
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: phase) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: sessionPhase) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: elapsedSeconds) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: score) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: finished) { _, _ in
            if finished, !didRecordReinforcementSession, courseId != "__favorites__", !LearnedGameSource.isPseudoCourseId(courseId) {
                didRecordReinforcementSession = true
                let total = max(1, turns.count)
                let percent = max(0, min(100, Int((Double(score) / Double(total) * 100).rounded())))
                ReinforcementStore.shared.recordSession(
                    courseId: courseId,
                    gameType: "grandDialogue",
                    score: percent
                )
            }
            GameHeaderStore.shared.config = headerConfig()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard sessionPhase == .dialogue, !finished, currentTurn != nil else { return }
            elapsedSeconds += 1
        }
    }

    // MARK: - Intro

    private var introMessages: [String] {
        let title = courseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let named = title.isEmpty ? "курс" : "«\(title)»"
        return [
            "Ты прошёл \(named) — [[молодец]].",
            "Сейчас короткая [[курсовая]]: я говорю по-тайски, ты отвечаешь голосом.",
            "Можно ошибаться — главное попробовать. [[Готов?]]"
        ]
    }

    private var introState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Курсовая")
                    .taikaSectionTitleStyle()
                Spacer(minLength: 8)
                Text(courseTitle.uppercased())
                    .taikaSubsectionStyle(accent: false)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, 6)

            Spacer(minLength: 12)

            HStack(alignment: .top, spacing: 12) {
                taikaAvatarLarge
                Text("Это финальный разговор по курсу. Отвечай вслух — как в жизни.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CD.ColorToken.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    introFactChip(icon: "bubble.left.and.bubble.right", text: "\(turns.count) реплик")
                    introFactChip(icon: "mic.fill", text: "ответ голосом")
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    startDialogue()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Начать диалог")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Color(white: 0.14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: uiCorner, style: .continuous)
                            .fill(theme.currentAccentFill)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
        }
    }

    private func introFactChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(CD.FontToken.caption(12, weight: .semibold))
        }
        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
    }

    private func startDialogue() {
        withAnimation(.easeInOut(duration: 0.25)) {
            sessionPhase = .dialogue
            elapsedSeconds = 0
        }
        enqueuePromptIfNeeded()
        GameHeaderStore.shared.config = headerConfig()
    }

    // MARK: - Locked / empty

    private var lockedState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                taikaAvatarLarge
                Text("Диалог откроется, когда пройдёшь все уроки курса.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CD.ColorToken.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("Закрыть") { onClose() }
                .font(CD.FontToken.body(15, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
        }
        .padding(.vertical, 12)
    }

    private var emptyPairsState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Пока мало выученных карточек для диалога. Пройди ещё несколько уроков и вернись.")
                .font(CD.FontToken.body(15, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button("Закрыть") { onClose() }
                .font(CD.FontToken.body(15, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Avatar

    private var taikaAvatar: some View {
        Image("mascot.course")
            .resizable()
            .scaledToFit()
            .frame(width: 34, height: 34)
            .padding(2)
            .background(Circle().fill(CD.ColorToken.chip))
            .taikaMascotChrome()
    }

    private var taikaAvatarLarge: some View {
        Image("mascot.course")
            .resizable()
            .scaledToFit()
            .frame(width: 52, height: 52)
            .padding(3)
            .background(Circle().fill(CD.ColorToken.chip))
            .taikaMascotChrome()
    }

    // MARK: - Active dialogue

    @ViewBuilder
    private var activeTurn: some View {
        if currentTurn != nil {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { msg in
                                dialogueBubble(msg)
                                    .id(msg.id)
                            }
                            if isTaikaTyping {
                                taikaTypingRow
                                    .id("typing")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: messages.count) { _, _ in
                        scrollChatToBottom(proxy: proxy)
                    }
                    .onChange(of: isTaikaTyping) { _, _ in
                        scrollChatToBottom(proxy: proxy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composerBar
            }
        }
    }

    private func scrollChatToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isTaikaTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(composerStatusText)
                .font(CD.FontToken.caption(12, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.88))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if usesWideComposerButton {
                wideComposerButton
            } else {
                HStack {
                    Spacer(minLength: 0)
                    compactMicButton
                }
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, Theme.Layout.pageHorizontal)
        .padding(.bottom, 12)
        .background(
            Theme.Surfaces.blackGlassScrim
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var usesWideComposerButton: Bool {
        if isEvaluating || recorder.isRecording { return true }
        if case .feedback = phase { return true }
        return false
    }

    private var wideComposerButton: some View {
        Button {
            handleComposerPrimaryTap()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: composerPrimaryIcon)
                    .font(.system(size: 15, weight: .semibold))
                Text(composerPrimaryTitle)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(composerPrimaryForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: uiCorner, style: .continuous)
                    .fill(composerPrimaryBackground)
            )
        }
        .buttonStyle(.plain)
        .disabled(isEvaluating)
    }

    private var compactMicButton: some View {
        Button(action: handleComposerPrimaryTap) {
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(white: 0.14))
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(theme.currentAccentFill)
                )
                .overlay(
                    Circle()
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
        }
        .buttonStyle(.plain)
        .disabled(isEvaluating)
        .accessibilityLabel("Ответить голосом")
    }

    private var composerPrimaryTitle: String {
        if isEvaluating { return "Проверяем..." }
        if recorder.isRecording { return "Остановить и проверить" }
        if case .feedback(let pass) = phase {
            if pass { return turnIndex + 1 >= turns.count ? "Показать итоги" : "Дальше" }
            return "Записать ещё раз"
        }
        return "Ответить голосом"
    }

    private var composerPrimaryIcon: String {
        if isEvaluating { return "waveform" }
        if recorder.isRecording { return "stop.fill" }
        if case .feedback(let pass) = phase { return pass ? "arrow.right" : "arrow.clockwise" }
        return "mic.fill"
    }

    private var composerPrimaryBackground: AnyShapeStyle {
        if recorder.isRecording { return AnyShapeStyle(Color.red.opacity(0.9)) }
        if isEvaluating { return AnyShapeStyle(Color.white.opacity(0.18)) }
        return AnyShapeStyle(theme.currentAccentFill)
    }

    private var composerPrimaryForeground: Color {
        if recorder.isRecording { return .white }
        if isEvaluating { return CD.ColorToken.textSecondary }
        return Color(white: 0.14)
    }

    private func handleComposerPrimaryTap() {
        guard !isEvaluating else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if recorder.isRecording {
            Task { await finishRecordingAndScore() }
            return
        }
        if case .feedback(let pass) = phase {
            if pass {
                advanceTurn()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .record
                    statusLine = ""
                }
                startRecording()
            }
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .record
            statusLine = ""
        }
        startRecording()
    }

    private var composerStatusText: String {
        if isEvaluating { return "Проверяем ответ..." }
        if recorder.isRecording { return "Идёт запись..." }
        if phase == .record {
            return statusLine.isEmpty ? "Нажми и ответь по смыслу." : statusLine
        }
        if case .feedback(let pass) = phase {
            return pass ? "Хорошо, можно идти дальше." : "Не совсем. Попробуй ещё раз."
        }
        return "Слушай реплику Тайки и ответь голосом."
    }

    private func dialogueBubble(_ message: DialogueMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .taika {
                taikaAvatar
            } else {
                Spacer(minLength: 40)
            }

            if message.role == .taika {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(message.text)
                            .font(CD.FontToken.body(16, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text)
                            .multilineTextAlignment(.leading)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            StepAudio.shared.speakThai(message.text)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(white: 0.14))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(theme.currentAccentFill))
                        }
                        .buttonStyle(.plain)
                    }
                    if let subtitle = message.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(CD.FontToken.caption(13, weight: .medium))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.86))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: 280, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: uiCorner, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                        .overlay(
                            RoundedRectangle(cornerRadius: uiCorner, style: .continuous)
                                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                        )
                )
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(CD.FontToken.body(16, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                    if let subtitle = message.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(CD.FontToken.caption(13, weight: .medium))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: 280, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: uiCorner, style: .continuous)
                        .fill(theme.currentAccentFill.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: uiCorner, style: .continuous)
                                .stroke(theme.currentAccentFill.opacity(0.45), lineWidth: Theme.Strokes.strokeLineWidth)
                        )
                )
            }

            if message.role == .taika {
                Spacer(minLength: 40)
            }
        }
    }

    private var taikaTypingRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            taikaAvatar
            HStack(spacing: 5) {
                Circle().frame(width: 6, height: 6).opacity(0.35)
                Circle().frame(width: 6, height: 6).opacity(0.65)
                Circle().frame(width: 6, height: 6).opacity(0.9)
            }
            .foregroundStyle(CD.ColorToken.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: uiCorner, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: uiCorner, style: .continuous)
                            .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                    )
            )
            Spacer(minLength: 40)
        }
    }

    private func enqueuePromptIfNeeded() {
        guard sessionPhase == .dialogue else { return }
        guard phase == .listen else { return }
        guard let turn = currentTurn else { return }
        guard promptShownTurnIndex != turnIndex else { return }
        promptShownTurnIndex = turnIndex

        let thai = (turn.prompt.item.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ru = (turn.prompt.item.ru ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        isTaikaTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isTaikaTyping = false
            if !thai.isEmpty {
                messages.append(DialogueMessage(role: .taika, text: thai, subtitle: ru.isEmpty ? nil : ru))
                StepAudio.shared.speakThai(thai)
            }
        }
    }

    private func startRecording() {
        if recorder.isRecording { return }
        statusLine = "идёт запись…"
        recorder.start { url in
            if url == nil {
                Task { @MainActor in
                    statusLine = "не удалось начать запись"
                }
            }
        }
    }

    private func stopRecordingIfNeeded() {
        guard recorder.isRecording else { return }
        _ = recorder.stop()
    }

    private func finishRecordingAndScore() async {
        guard let turn = currentTurn else {
            await MainActor.run {
                statusLine = "нет активного шага"
                phase = .feedback(pass: false)
            }
            return
        }
        await MainActor.run { isEvaluating = true }
        let url = await MainActor.run { recorder.stop() }
        guard let url else {
            await MainActor.run {
                isEvaluating = false
                statusLine = "нет файла записи"
                phase = .feedback(pass: false)
            }
            return
        }
        let candidates = turn.expectedReplies.map {
            SpeakerManager.GrandDialogueExpectedCandidate(
                thai: $0.item.thai ?? "",
                phonetic: $0.item.phonetic
            )
        }
        let eval = await SpeakerManager.shared.evaluateGrandDialogueUtterance(
            at: url,
            candidates: candidates,
            isProUser: isProUser
        )
        let spokenThai = eval.spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let spokenPhonetic = await SpeakerManager.shared.transliterateThaiForDialogue(thai: spokenThai)
        let matchedExpectedPhonetic: String? = {
            let matchedThai = eval.matchedThai.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !matchedThai.isEmpty else { return nil }
            let m = turn.expectedReplies.first(where: {
                ($0.item.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == matchedThai
            })?.item.phonetic?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (m?.isEmpty == false) ? m : nil
        }()
        await MainActor.run {
            isEvaluating = false
            lastScore = eval.finalScore
            let finalScore = eval.finalScore
            let userText = (spokenPhonetic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? (spokenPhonetic ?? "")
                : (matchedExpectedPhonetic ?? "...")
            messages.append(
                DialogueMessage(
                    role: .user,
                    text: userText,
                    subtitle: nil
                )
            )
            let pass = finalScore >= passThreshold
            if pass {
                score += 1
                TaikaVoice.shared.playMatchSuccess()
            } else {
                TaikaVoice.shared.playMatchFail()
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                phase = .feedback(pass: pass)
            }
        }
    }

    private func advanceTurn() {
        if turnIndex + 1 >= turns.count {
            withAnimation(.easeOut(duration: 0.2)) { finished = true }
            return
        }
        turnIndex += 1
        phase = .listen
        statusLine = ""
        lastScore = 0
    }

    private func reloadSession() {
        let cid = canonicalCourseIds.first { !LessonsData.shared.lessons(for: $0).isEmpty }
            ?? canonicalCourseIds.first
            ?? courseId
        turns = GrandDialogueEngine.buildSessionTurns(courseId: cid, maxTurns: maxSessionTurns)
        sessionPhase = .intro
        turnIndex = 0
        phase = .listen
        elapsedSeconds = 0
        score = 0
        finished = false
        didRecordReinforcementSession = false
        statusLine = ""
        lastScore = 0
        isEvaluating = false
        messages = []
        isTaikaTyping = false
        promptShownTurnIndex = -1
    }

    private func headerConfig() -> GameHeaderConfig {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        let timeText = String(format: "%d:%02d", m, s)
        let total = turns.count
        let progressText: String? = {
            guard sessionPhase == .dialogue, total > 0 else { return nil }
            let progress = finished ? total : min(turnIndex + 1, total)
            return "реплика \(progress) из \(total)"
        }()
        return GameHeaderConfig(
            timeText: timeText,
            score: score,
            mistakes: 0,
            streak: 0,
            progressText: progressText,
            gameTitle: "Диалог курса",
            sourceTitle: nil,
            onBack: {
                stopRecordingIfNeeded()
                onClose()
            }
        )
    }

    private var completionOverlay: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onClose)
            OverlayEtalonCard(title: "Курсовая — готово", onDismiss: onClose) {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Text("успешных реплик: \(score) из \(turns.count)")
                            .font(CD.FontToken.body(15, weight: .regular))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                        let mm = elapsedSeconds / 60
                        let ss = elapsedSeconds % 60
                        Text(String(format: "%d:%02d", mm, ss))
                            .font(CD.FontToken.body(16, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text)
                    }

                    GameCompletionActions(
                        isFromLessonStep: false,
                        isProUser: isProUser,
                        continueLearningTitle: continueLearningTitle,
                        nextGameTitle: nextGameTitle,
                        onRepeat: {
                            reloadSession()
                            GameHeaderStore.shared.config = headerConfig()
                        },
                        onNextGame: onNextGame,
                        onSpeakerPractice: onSpeakerPractice,
                        onContinueLearning: onContinueLearning,
                        onClose: onClose
                    )
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 20)
            }
        }
    }
}
