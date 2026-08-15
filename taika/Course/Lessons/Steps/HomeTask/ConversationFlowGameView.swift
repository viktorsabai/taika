import SwiftUI

/// Диалоговая мини-игра: реплика «как в чате» → выбор русского ответа по смыслу (закрепление живого диалога).
@MainActor
struct ConversationFlowGameView: View {

    let lessonId: String
    /// Подпись урока в хедере приложения и в контексте чата.
    let sourceTitle: String
    /// Название курса — правая колонка секции, как в «Найди пару» / recall.
    let courseTitle: String
    let onClose: () -> Void
    let onNextGame: (() -> Void)?
    let nextGameTitle: String?
    let isProUser: Bool

    @EnvironmentObject private var theme: ThemeManager

    @State private var turns: [ConversationTurnModel] = []
    @State private var turnIndex: Int = 0
    @State private var phase: Phase = .listen
    @State private var elapsedSeconds: Int = 0
    @State private var score: Int = 0
    @State private var mistakes: Int = 0
    @State private var streak: Int = 0
    @State private var finished: Bool = false
    /// «Тайка печатает…» в начале каждой реплики (listen).
    @State private var promptTypingDots: Bool = true
    @State private var dotsPhase: Int = 0
    /// В бабле реплики: тайский или транслит.
    @State private var promptShowThaiScript: Bool = true
    @State private var selectedChoiceOrder: Int? = nil

    private enum Phase: Equatable {
        case listen
        case choose
        case feedback(wasCorrect: Bool)
    }

    private var currentTurn: ConversationTurnModel? {
        guard turnIndex < turns.count else { return nil }
        return turns[turnIndex]
    }

    private var correctItem: StepItem? {
        guard let t = currentTurn else { return nil }
        return t.choices.first { $0.order == t.correctOrder }
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
                conversationGameSectionHeader
                Group {
                    if lessonId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        emptyLessonState
                    } else if turns.isEmpty {
                        emptyContentState
                    } else if finished {
                        finishedPlaceholder
                    } else {
                        activeTurnContent
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 16)
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
            StepData.shared.preload()
            reloadSession()
            GameHeaderStore.shared.config = headerConfig()
        }
        .onDisappear {
            StepAudio.shared.stop()
            GameHeaderStore.shared.config = nil
        }
        .onChange(of: turnIndex) { _, _ in
            schedulePromptTypingReveal()
            GameHeaderStore.shared.config = headerConfig()
        }
        .onChange(of: phase) { _, _ in
            GameHeaderStore.shared.config = headerConfig()
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
            if isDone {
                StepAudio.shared.stop()
            }
            GameHeaderStore.shared.config = headerConfig()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard !finished, currentTurn != nil else { return }
            elapsedSeconds += 1
        }
    }

    /// Как в match/recall: слева игра, справа курс; урок — в верхнем хедере приложения.
    private var conversationGameSectionHeader: some View {
        HStack {
            Text("ПОТОК ДИАЛОГА")
                .taikaSectionTitleStyle()
            Spacer(minLength: 8)
            Text(courseTitle.uppercased())
                .taikaSubsectionStyle(accent: false)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 6)
    }

    private func schedulePromptTypingReveal() {
        promptTypingDots = true
        dotsPhase = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) {
            withAnimation(.easeOut(duration: 0.2)) {
                promptTypingDots = false
            }
        }
    }

    private var taikaAvatar: some View {
        ZStack {
            Circle().fill(CD.ColorToken.chip)
            Image("mascot.course")
                .resizable()
                .scaledToFit()
                .padding(4)
                .taikaMascotChrome()
        }
        .frame(width: 40, height: 40)
        .overlay(Circle().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
    }

    private var typingDotsMessenger: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 7, height: 7)
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(i == dotsPhase % 3 ? 0.95 : 0.4))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .onReceive(Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()) { _ in
            guard promptTypingDots else { return }
            dotsPhase += 1
        }
    }

    private var emptyLessonState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Нужен конкретный урок с карточками — здесь не из чего собрать диалог.")
                .font(CD.FontToken.body(15, weight: .regular))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button("Закрыть") {
                StepAudio.shared.stop()
                onClose()
            }
            .font(CD.FontToken.body(15, weight: .semibold))
            .foregroundStyle(theme.currentAccentFill)
        }
        .padding(.vertical, 12)
    }

    private var emptyContentState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("В этом уроке мало связных фраз для сценария «ответ на реплику». Добавьте вопросы с «?» или поле conversation_next_order в шагах.")
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

    private var finishedPlaceholder: some View {
        Color.clear.frame(height: 1)
    }

    @ViewBuilder
    private var activeTurnContent: some View {
        if let turn = currentTurn {
            TaikaRootVerticalScroll {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .bottom, spacing: 10) {
                        Spacer(minLength: 8)
                        taikaPromptStack(prompt: turn.prompt)
                        taikaAvatar
                    }

                    switch phase {
                    case .listen:
                        listenMessengerActions(for: turn)
                    case .choose:
                        chooseMessengerBlock(for: turn)
                    case .feedback(let ok):
                        feedbackBlock(wasCorrect: ok, turn: turn)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private func taikaPromptStack(prompt: StepItem) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            if promptTypingDots {
                typingDotsMessenger
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(PD.ColorToken.card.opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                            )
                    )
            } else {
                taikaPromptBubble(for: prompt)
            }
        }
        .frame(maxWidth: 320, alignment: .trailing)
    }

    private func displayPromptMainText(thai: String, ph: String) -> String {
        let useThai = promptShowThaiScript || ph.isEmpty
        if useThai, !thai.isEmpty { return thai }
        if !ph.isEmpty { return ph }
        return thai
    }

    private func taikaPromptBubble(for prompt: StepItem) -> some View {
        let thai = (prompt.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ph = (prompt.phonetic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasBoth = !thai.isEmpty && !ph.isEmpty
        let shownText = displayPromptMainText(thai: thai, ph: ph)

        return VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: 0) {
                if hasBoth {
                    HStack(spacing: 0) {
                        promptScriptChip(title: "ไทย", selected: promptShowThaiScript) {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            promptShowThaiScript = true
                        }
                        promptScriptChip(title: "трансл.", selected: !promptShowThaiScript) {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            promptShowThaiScript = false
                        }
                    }
                }
                Spacer(minLength: 8)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    speakPrompt(prompt)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(white: 0.14))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(theme.currentAccentFill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Прослушать реплику")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if promptShowThaiScript && !thai.isEmpty {
                ThaiDigitalRevealText(text: shownText, trigger: turnIndex)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                Text(shownText)
                    .font(CD.FontToken.body(17, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PD.ColorToken.card.opacity(0.95))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.currentAccentFill.opacity(0.2))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
        )
    }

    private func promptScriptChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Color(white: 0.14) : CD.ColorToken.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if selected {
                            Capsule(style: .continuous).fill(theme.currentAccentFill)
                        } else {
                            Capsule(style: .continuous).fill(CD.ColorToken.card.opacity(0.5))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 4)
    }

    private func listenMessengerActions(for turn: ConversationTurnModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.easeInOut(duration: 0.22)) {
                    phase = .choose
                }
            } label: {
                Text("Выбрать ответ")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(white: 0.14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.currentAccentFill))
            }
            .buttonStyle(.plain)
            .disabled(promptTypingDots)
            .opacity(promptTypingDots ? 0.45 : 1)
        }
        .onAppear {
            speakPrompt(turn.prompt)
        }
    }

    private func chooseMessengerBlock(for turn: ConversationTurnModel) -> some View {
        let gridRows: [GridItem] = [
            GridItem(.fixed(74), spacing: 10),
            GridItem(.fixed(74), spacing: 10)
        ]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(theme.currentAccentFill.opacity(0.65))
                    .frame(width: 4, height: 14)
                Text("Твой ответ")
                    .font(CD.FontToken.caption(12, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
            }

            TaikaCarouselScroll {
                LazyHGrid(rows: gridRows, alignment: .top, spacing: 10) {
                    ForEach(turn.choices, id: \.order) { item in
                        choiceTile(item: item)
                    }
                }
                .padding(.vertical, 2)
            }

            Button {
                guard let selected = selectedChoiceOrder,
                      let selectedItem = turn.choices.first(where: { $0.order == selected }) else { return }
                selectChoice(selectedItem, in: turn)
            } label: {
                HStack(spacing: 8) {
                    Text("Подтвердить выбор")
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color(white: 0.14))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.currentAccentFill))
            }
            .buttonStyle(.plain)
            .disabled(selectedChoiceOrder == nil)
            .opacity(selectedChoiceOrder == nil ? 0.45 : 1.0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { selectedChoiceOrder = nil }
    }

    private func choiceTile(item: StepItem) -> some View {
        let isSelected = selectedChoiceOrder == item.order
        let ru = (item.ru ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ph = (item.phonetic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedChoiceOrder = item.order
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(ru)
                    .font(CD.FontToken.body(15, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(CD.ColorToken.text))
                    .lineLimit(1)
                if !ph.isEmpty {
                    Text(ph)
                        .font(CD.FontToken.caption(12, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .frame(width: 210, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PD.ColorToken.card.opacity(isSelected ? 0.85 : 0.60))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Color.pink.opacity(0.9) : Color.white.opacity(0.06),
                        lineWidth: isSelected ? 1.4 : 1.0
                    )
            )
            .shadow(color: isSelected ? Color.pink.opacity(0.18) : .clear, radius: 10, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func feedbackBlock(wasCorrect: Bool, turn: ConversationTurnModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(wasCorrect ? "Так и есть — отлично." : "Почти — зафиксируем эталон.")
                .font(CD.FontToken.body(17, weight: .semibold))
                .foregroundStyle(CD.ColorToken.text)
            if wasCorrect && streak >= 2 {
                Text("серия: \(streak)")
                    .font(CD.FontToken.caption(13, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
            }

            if !wasCorrect, let ref = correctItem {
                let ru = (ref.ru ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let th = (ref.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let ph = (ref.phonetic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                VStack(alignment: .leading, spacing: 6) {
                    if !ru.isEmpty {
                        Text(ru)
                            .font(CD.FontToken.body(16, weight: .medium))
                    }
                    if !ph.isEmpty {
                        Text(ph)
                            .font(CD.FontToken.caption(14, weight: .medium))
                            .foregroundStyle(theme.currentAccentFill)
                    }
                    if !th.isEmpty {
                        Text(th)
                            .font(CD.FontToken.caption(14, weight: .regular))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                    }
                }
            }

            Button {
                advanceAfterFeedback()
            } label: {
                Text(turnIndex + 1 >= turns.count ? "Итоги" : "Дальше")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(white: 0.14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.currentAccentFill))
            }
            .buttonStyle(.plain)
        }
    }

    private func speakPrompt(_ item: StepItem) {
        let text = (item.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        StepAudio.shared.speakThai(text)
    }

    private func selectChoice(_ item: StepItem, in turn: ConversationTurnModel) {
        let ok = item.order == turn.correctOrder
        if ok {
            score += 1
            streak += 1
            TaikaGameFeedbackHaptics.matchSuccess()
            TaikaVoice.shared.playMatchSuccess()
        } else {
            mistakes += 1
            streak = 0
            TaikaGameFeedbackHaptics.mismatch()
            TaikaVoice.shared.playMatchFail()
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .feedback(wasCorrect: ok)
        }
        selectedChoiceOrder = nil
    }

    private func advanceAfterFeedback() {
        if turnIndex + 1 >= turns.count {
            withAnimation(.easeOut(duration: 0.2)) {
                finished = true
            }
            return
        }
        turnIndex += 1
        phase = .listen
        selectedChoiceOrder = nil
    }

    private func reloadSession() {
        let raw = StepData.shared.items(for: lessonId)
        turns = ConversationFlowEngine.buildTurns(from: raw)
        turnIndex = 0
        phase = .listen
        elapsedSeconds = 0
        score = 0
        mistakes = 0
        streak = 0
        finished = false
        promptShowThaiScript = true
        selectedChoiceOrder = nil
        schedulePromptTypingReveal()
    }

    private func headerConfig() -> GameHeaderConfig {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        let timeText = String(format: "%d:%02d", m, s)
        let total = turns.count
        let progressText: String? = {
            guard total > 0 else { return nil }
            let progress = finished ? total : min(turnIndex + 1, total)
            return "ход \(progress) из \(total)"
        }()
        return GameHeaderConfig(
            timeText: timeText,
            score: score,
            mistakes: mistakes,
            streak: streak,
            progressText: progressText,
            gameTitle: "Разговор",
            sourceTitle: nil,
            onBack: {
                StepAudio.shared.stop()
                onClose()
            }
        )
    }

    @ViewBuilder
    private var completionOverlay: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onClose)

            OverlayEtalonCard(title: "поток диалога — готово", onDismiss: onClose) {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Text("верных: \(score) из \(turns.count)")
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
                        nextGameTitle: nextGameTitle,
                        onRepeat: { reloadSession() },
                        onNextGame: onNextGame.map { next in
                            {
                                StepAudio.shared.stop()
                                next()
                            }
                        },
                        onClose: onClose
                    )
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 20)
            }
        }
    }
}

private struct ThaiDigitalRevealText: View {
    let text: String
    let trigger: Int

    @State private var rendered: String = ""
    @State private var revealProgress: CGFloat = 0
    @State private var timer: Timer?

    private let thaiGlyphs = Array("กขคงจฉชซญฎฏฐฑฒณดตถทธนบปผพภมยรลวศษสหอฮ")

    var body: some View {
        Text(rendered.isEmpty ? text : rendered)
            .font(CD.FontToken.body(17, weight: .semibold))
            .foregroundStyle(CD.ColorToken.text)
            .multilineTextAlignment(.trailing)
            .blur(radius: (1 - revealProgress) * 2.2)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.pink.opacity(0.0),
                        Color.pink.opacity(0.22 * revealProgress),
                        Color.pink.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blendMode(.screen)
            )
            .onAppear { startAnimation() }
            .onChange(of: trigger) { _, _ in startAnimation() }
            .onDisappear { timer?.invalidate(); timer = nil }
    }

    private func startAnimation() {
        timer?.invalidate()
        revealProgress = 0
        rendered = scramble(from: text, keepPrefix: 0)
        let total = max(1, text.count)
        var step = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.045, repeats: true) { t in
            step += 1
            let prefix = min(total, step)
            rendered = scramble(from: text, keepPrefix: prefix)
            revealProgress = CGFloat(prefix) / CGFloat(total)
            if prefix >= total {
                t.invalidate()
                rendered = text
            }
        }
    }

    private func scramble(from source: String, keepPrefix: Int) -> String {
        guard !source.isEmpty else { return source }
        let chars = Array(source)
        var out: [Character] = []
        out.reserveCapacity(chars.count)
        for i in chars.indices {
            if i < keepPrefix || chars[i].isWhitespace {
                out.append(chars[i])
            } else {
                out.append(thaiGlyphs.randomElement() ?? chars[i])
            }
        }
        return String(out)
    }
}
