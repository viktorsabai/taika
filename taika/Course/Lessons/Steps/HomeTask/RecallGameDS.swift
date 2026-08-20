import SwiftUI

// MARK: - Recall Game DS (Tap-to-build phonetic)
// Pure rendering; no business logic. Syllable selectability precomputed by View.
// EPIC 2 Discovery: segments define mask (slot + toneAfter); pool has clean syllables only.

public struct RecallSyllableItem: Identifiable {
    public let id: Int
    public let text: String
    public let isSelectable: Bool
    /// Этот экземпляр чипа уже стоит в сборке (визуально «выбран», повторный тап снимает).
    public let isInUse: Bool

    public init(id: Int, text: String, isSelectable: Bool, isInUse: Bool = false) {
        self.id = id
        self.text = text
        self.isSelectable = isSelectable
        self.isInUse = isInUse
    }
}

/// Один раунд для карусели (карточки урока / выученные).
public struct RecallRoundDisplay: Identifiable {
    public let id: Int
    public let question: String
    public let target: String
    public let thai: String
}

public struct RecallGameView: View {

    @State private var assembleSuccessScale: CGFloat = 1.0
    @State private var assembleSuccessGlow: Double = 0
    @State private var revealedSyllableCount: Int = 0
    @State private var syllableRevealToken: Int = 0

    public let question: String
    public let phoneticDisplay: String?
    public let progressText: String?
    public let segments: [HomeTaskManager.PhoneticSegment]
    public let syllableItems: [RecallSyllableItem]
    public let slotCount: Int
    public let assembled: [String]
    public let isCorrect: Bool?
    public let correctAnswerDisplay: String?
    public let wrongSlotIndices: Set<Int>
    /// Индекс слота, выбранного для замены (тап по красному слоту → выбрать; тап по слогу в пуле → заменить).
    public let selectedSlotForReplacement: Int?
    public let onTapSlot: ((Int) -> Void)?
    public let audioText: String?
    /// (текст слога, уже в сборке?) — повторный тап по in-use снимает выбор.
    public let onTapSyllable: (String, Bool) -> Void
    public let onPlayAudio: (() -> Void)?
    public let onRemoveLast: () -> Void
    public let onReset: () -> Void
    public let onCheck: () -> Void
    public let onNextRound: (() -> Void)?
    public let roundText: String?
    public let scoreText: String?
    public let isLocked: Bool
    public let roundDisplays: [RecallRoundDisplay]?
    public let currentRoundIndex: Int
    public let onSelectRound: ((Int) -> Void)?
    /// Чип на карточке (название урока или курса), как в FDMiniCardV.
    public let lessonTitle: String?
    /// Статус в теле экрана (не в хедере).
    public let statusTimeText: String?
    public let statusProgressText: String?
    public let statusMistakes: Int
    public let statusScore: Int

    public init(
        question: String,
        phoneticDisplay: String? = nil,
        progressText: String? = nil,
        segments: [HomeTaskManager.PhoneticSegment] = [],
        syllableItems: [RecallSyllableItem],
        slotCount: Int,
        assembled: [String],
        isCorrect: Bool?,
        correctAnswerDisplay: String? = nil,
        wrongSlotIndices: Set<Int> = [],
        selectedSlotForReplacement: Int? = nil,
        onTapSlot: ((Int) -> Void)? = nil,
        audioText: String? = nil,
        onTapSyllable: @escaping (String, Bool) -> Void,
        onPlayAudio: (() -> Void)? = nil,
        onRemoveLast: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onCheck: @escaping () -> Void,
        onNextRound: (() -> Void)? = nil,
        roundText: String? = nil,
        scoreText: String? = nil,
        isLocked: Bool = false,
        roundDisplays: [RecallRoundDisplay]? = nil,
        currentRoundIndex: Int = 0,
        onSelectRound: ((Int) -> Void)? = nil,
        lessonTitle: String? = nil,
        statusTimeText: String? = nil,
        statusProgressText: String? = nil,
        statusMistakes: Int = 0,
        statusScore: Int = 0
    ) {
        self.question = question
        self.phoneticDisplay = phoneticDisplay
        self.progressText = progressText
        self.segments = segments
        self.syllableItems = syllableItems
        self.slotCount = slotCount
        self.assembled = assembled
        self.isCorrect = isCorrect
        self.correctAnswerDisplay = correctAnswerDisplay
        self.wrongSlotIndices = wrongSlotIndices
        self.selectedSlotForReplacement = selectedSlotForReplacement
        self.onTapSlot = onTapSlot
        self.audioText = audioText
        self.onTapSyllable = onTapSyllable
        self.onPlayAudio = onPlayAudio
        self.onRemoveLast = onRemoveLast
        self.onReset = onReset
        self.onCheck = onCheck
        self.onNextRound = onNextRound
        self.roundText = roundText
        self.scoreText = scoreText
        self.isLocked = isLocked
        self.roundDisplays = roundDisplays
        self.currentRoundIndex = currentRoundIndex
        self.onSelectRound = onSelectRound
        self.lessonTitle = lessonTitle
        self.statusTimeText = statusTimeText
        self.statusProgressText = statusProgressText
        self.statusMistakes = statusMistakes
        self.statusScore = statusScore
    }

    /// Единый brand accent (как стрелки слогов) — не смешиваем tint и fill.
    private var brandAccent: AnyShapeStyle {
        AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

    public var body: some View {
        VStack(spacing: 10) {
            if let time = statusTimeText {
                TaikaGameStatusStrip(
                    timeText: time,
                    progressText: statusProgressText,
                    mistakes: statusMistakes,
                    score: statusScore
                )
                .padding(.horizontal, CD.Spacing.screen)
            }

            // Два Spacer делят воздух сверху/снизу — без дыры между карточкой и сборкой.
            Spacer(minLength: 6)

            VStack(spacing: 8) {
                roundCardCoverflow
                recallAudioControl
                playfield
            }
            .padding(.horizontal, CD.Spacing.screen)

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            recallBottomChrome
        }
        .onAppear {
            staggerRevealSyllables()
        }
        .onChange(of: currentRoundIndex) { _, _ in
            staggerRevealSyllables()
        }
        .onChange(of: syllableItems.count) { _, _ in
            staggerRevealSyllables()
        }
        .onChange(of: assembled) { _, _ in
            // Авто-проверка, когда слоты заполнены — без лишней кнопки.
            guard !isLocked, isCorrect == nil, assembled.count == slotCount,
                  assembled.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  slotCount > 0 else { return }
            onCheck()
        }
        .onChange(of: isCorrect) { _, new in
            guard new == true else {
                assembleSuccessGlow = 0
                assembleSuccessScale = 1.0
                return
            }
            withAnimation(.easeOut(duration: 0.22)) {
                assembleSuccessGlow = 1
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                assembleSuccessScale = 1.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                    assembleSuccessScale = 1.0
                }
            }
            // Красивая карточка → озвучка (снаружи) → сама листает дальше.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                onNextRound?()
            }
        }
    }

    // MARK: - Layout zones

    /// Карусель 1:1 как Speaker training: 268×196, 3D yaw, peek соседа.
    private var roundCardCoverflow: some View {
        let rounds = roundDisplays ?? [
            RecallRoundDisplay(id: 0, question: question, target: phoneticDisplay ?? "", thai: audioText ?? "")
        ]
        let current = min(max(0, currentRoundIndex), max(0, rounds.count - 1))
        let itemW = TaikaGameCoverflowMetrics.cardW
        let itemH = TaikaGameCoverflowMetrics.cardH
        let stepX = itemW * TaikaGameCoverflowMetrics.peekStepFactor

        return ZStack {
            ForEach(Array(rounds.enumerated()), id: \.element.id) { index, display in
                let rel = index - current
                recallRoundCard(
                    display: display,
                    isActive: rel == 0,
                    succeeded: rel == 0 && isCorrect == true
                )
                .scaleEffect((rel == 0 ? 1.0 : 0.82) * (rel == 0 ? assembleSuccessScale : 1))
                .rotation3DEffect(
                    .degrees(Double(rel) * -18),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.7
                )
                .opacity(abs(rel) > 2 ? 0 : (rel == 0 ? 1.0 : 0.45))
                .offset(x: CGFloat(rel) * stepX)
                .zIndex(rel == 0 ? 10 : Double(10 - abs(rel)))
                .allowsHitTesting(abs(rel) <= 1 && !isLocked)
                .onTapGesture {
                    guard index != current, !isLocked else { return }
                    onSelectRound?(index)
                }
            }
        }
        .frame(height: itemH + 12)
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.35), value: currentRoundIndex)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: assembleSuccessScale)
    }

    /// Аудио под карточкой — как панель спикера, не внутри chrome карточки.
    private var recallAudioControl: some View {
        TaikaGameBareSpeakerButton(
            disabled: audioText?.isEmpty ?? true,
            action: { onPlayAudio?() }
        )
        .opacity(isLocked ? 0.35 : 1)
        .accessibilityHint("Прослушать фразу")
    }

    private func recallRoundCard(display: RecallRoundDisplay, isActive: Bool, succeeded: Bool) -> some View {
        // Адаптация спикера под сборку: RU на месте транслита (не спойлерим слоги), тайский — footnote.
        // На успехе тайский подсвечиваем accent через secondary.
        TaikaGameSpeakerStyleCard(
            lessonTitle: (isActive && !(lessonTitle ?? "").isEmpty) ? lessonTitle : nil,
            hero: display.question,
            secondary: (succeeded && !display.thai.isEmpty) ? display.thai : nil,
            tertiary: (!succeeded && !display.thai.isEmpty) ? display.thai : nil,
            secondaryIsAccent: succeeded,
            succeeded: succeeded,
            successGlow: assembleSuccessGlow,
            showsPlayControl: false
        )
    }

    private var playfield: some View {
        VStack(spacing: 12) {
            assemblyBoard
            syllablePool
        }
        .frame(maxWidth: .infinity)
    }

    private var assemblyBoard: some View {
        VStack(spacing: 8) {
            TaikaSectionLabel(title: "собери по слогам")
                .frame(maxWidth: .infinity, alignment: .leading)
            assembleZone
        }
        .frame(maxWidth: .infinity)
    }

    private var syllablePool: some View {
        VStack(alignment: .leading, spacing: 8) {
            TaikaSectionLabel(title: "слоги")
            syllableCarousel
        }
    }

    // MARK: - Assemble Zone (как в Speaker: только слоги по центру, без рамок)

    private var assembleZone: some View {
        assemblyMaskRow
            .scaleEffect(assembleSuccessScale)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: assembleSuccessScale)
            .frame(maxWidth: .infinity)
    }

    private let assemblySpacing: CGFloat = 8
    /// Минимальная ширина на один слог (слот + тон/точка) для расчёта переноса.
    private let minSegmentWidth: CGFloat = 68

    /// Число сегментов в строке по доступной ширине (умный перенос целыми слогами).
    private func segmentsPerLine(containerWidth: CGFloat) -> Int {
        let fitted = max(1, Int(containerWidth / minSegmentWidth))
        return min(4, fitted)
    }

    private func assemblySegmentRows(containerWidth: CGFloat) -> [[(offset: Int, segment: HomeTaskManager.PhoneticSegment)]] {
        let enumerated = Array(effectiveSegments.enumerated())
        guard !enumerated.isEmpty else { return [] }
        let perLine = segmentsPerLine(containerWidth: containerWidth)
        return stride(from: 0, to: enumerated.count, by: perLine).map {
            Array(enumerated[$0..<min($0 + perLine, enumerated.count)].map { (offset: $0.offset, segment: $0.element) })
        }
    }

    /// Assembly: перенос по строкам без GeometryReader (иначе съедает всю высоту экрана в VStack).
    private var assemblyMaskRow: some View {
        let width = min(360, max(1, UIScreen.main.bounds.width - CD.Spacing.screen * 2 - 24))
        let rows = assemblySegmentRows(containerWidth: width)

        return VStack(alignment: .center, spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .bottom, spacing: assemblySpacing) {
                    ForEach(Array(row.enumerated()), id: \.element.offset) { _, item in
                        let index = item.offset
                        let seg = item.segment
                        let isFilled = index < assembled.count && !assembled[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        let isWrong = wrongSlotIndices.contains(index)
                        let isSelected = (selectedSlotForReplacement == index)

                        // Стрелка тона в одной строке со слогом; подчёркивание только под слогом.
                        minimalSlot(
                            index: index,
                            isFilled: isFilled,
                            isWrong: isWrong,
                            isSelected: isSelected,
                            assemblySucceeded: isCorrect == true,
                            toneAfter: seg.toneAfter
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var effectiveSegments: [HomeTaskManager.PhoneticSegment] {
        if !segments.isEmpty { return segments }
        return (0..<slotCount).map { _ in HomeTaskManager.PhoneticSegment(syllable: "", toneAfter: nil) }
    }

    @ViewBuilder
    private func minimalSlot(
        index: Int,
        isFilled: Bool,
        isWrong: Bool = false,
        isSelected: Bool = false,
        assemblySucceeded: Bool = false,
        toneAfter: String? = nil
    ) -> some View {
        let textColor: AnyShapeStyle = {
            if isWrong { return AnyShapeStyle(Color.red.opacity(0.92)) }
            if isFilled { return AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.96)) }
            return AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.30))
        }()

        let underlineColor: AnyShapeStyle = {
            if isWrong { return AnyShapeStyle(Color.red.opacity(0.72)) }
            if isSelected { return AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.62)) }
            if assemblySucceeded, isFilled { return AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.58 + 0.16 * assembleSuccessGlow)) }
            if isFilled { return AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.34)) }
            return AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.18))
        }()

        let toneColor: AnyShapeStyle = {
            if isWrong { return AnyShapeStyle(Color.red.opacity(0.72)) }
            return AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.62))
        }()

        let syllableText: String = {
            if isFilled, index < assembled.count { return assembled[index] }
            return "\(index + 1)"
        }()

        let content = VStack(alignment: .center, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Text(syllableText)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(textColor)
                        .opacity(isFilled ? 1 : 0.62)
                        .frame(minWidth: 32, minHeight: 28)

                    if isFilled, !isLocked, isCorrect == nil, !isWrong {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.55))
                            .offset(x: 8, y: -6)
                            .accessibilityHidden(true)
                    }
                }

                if let tone = toneAfter {
                    Text(tone)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(toneColor)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            Rectangle()
                .fill(underlineColor)
                .frame(
                    width: max(32, isFilled && index < assembled.count ? CGFloat(assembled[index].count) * 12 : 36),
                    height: isWrong ? 2.5 : (isSelected || isFilled ? 2 : 1.75)
                )
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isSelected)
        .shadow(color: isSelected ? ThemeManager.shared.currentAccentTintColor.opacity(0.22) : Color.clear, radius: 10, x: 0, y: 0)

        // Любой слот можно выбрать: заполнение не обязано идти слева направо.
        if !isLocked, let onTap = onTapSlot {
            Button { onTap(index) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel(isFilled ? "Выбрать слот \(index + 1)" : "Заполнить слот \(index + 1)")
                .accessibilityHint("Выбери слог из пула")
        } else {
            content
        }
    }

    // MARK: - Syllable Pool (тактильные chips, адаптивная сетка без вложенного скролла)

    private let syllableSpacing: CGFloat = 10
    private let syllableChipHeight: CGFloat = 52

    private var syllableColumnCount: Int {
        min(4, max(2, syllableItems.count <= 4 ? syllableItems.count : 4))
    }

    private var syllableCarousel: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: syllableSpacing),
                count: syllableColumnCount
            ),
            spacing: syllableSpacing
        ) {
            ForEach(Array(syllableItems.enumerated()), id: \.element.id) { index, item in
                recallSyllableChip(item: item, index: index)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private func recallSyllableChip(item: RecallSyllableItem, index: Int) -> some View {
        let selectable = item.isSelectable && !isLocked
        let isRevealed = index < revealedSyllableCount

        return Button {
            onTapSyllable(item.text, item.isInUse)
        } label: {
            recallSyllableChipLabel(text: item.text, inUse: item.isInUse, selectable: selectable)
        }
        .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
        .disabled(!selectable)
        .opacity(isRevealed ? (selectable ? 1 : 0.42) : 0)
        .offset(y: isRevealed ? 0 : 28)
        .scaleEffect(isRevealed ? 1 : 0.88, anchor: .bottom)
        .rotation3DEffect(
            .degrees(isRevealed ? 0 : 10),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.65
        )
        .blur(radius: isRevealed ? 0 : 2)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.76).delay(Double(index) * 0.05),
            value: isRevealed
        )
        .animation(.easeOut(duration: 0.2), value: item.isInUse)
        .animation(.easeOut(duration: 0.2), value: selectable)
    }

    private func staggerRevealSyllables() {
        revealedSyllableCount = 0
        syllableRevealToken += 1
        let token = syllableRevealToken
        let total = syllableItems.count
        guard total > 0 else { return }
        for i in 0..<total {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04 + Double(i) * 0.065) {
                guard token == syllableRevealToken else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.76)) {
                    revealedSyllableCount = i + 1
                }
            }
        }
    }

    private func recallSyllableChipLabel(text: String, inUse: Bool, selectable: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Text(text)
            .font(.system(size: 17, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(
                inUse
                ? brandAccent
                : AnyShapeStyle(selectable ? CD.ColorToken.text : CD.ColorToken.textSecondary.opacity(0.7))
            )
            .frame(maxWidth: .infinity)
            .frame(height: syllableChipHeight)
            .background(
                shape.fill(
                    inUse
                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.18))
                    : AnyShapeStyle(CD.ColorToken.card.opacity(0.96))
                )
            )
            .overlay(
                shape.stroke(
                    inUse ? brandAccent : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                    lineWidth: inUse ? 1.4 : Theme.Strokes.strokeLineWidth
                )
            )
            .shadow(
                color: Color.black.opacity(inUse ? 0.16 : 0.12),
                radius: inUse ? 8 : 4,
                y: inUse ? 2 : 1
            )
            .contentShape(shape)
    }

    // MARK: - Bottom chrome: только undo/reset + воздух (статус выше, стрелка «дальше» не нужна)

    private var recallBottomChrome: some View {
        VStack(spacing: 0) {
            recallGameBar
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.top, 14)
                .padding(.bottom, 22)
        }
        .background(Color.clear)
    }

    private var recallGameBar: some View {
        HStack(alignment: .center, spacing: 14) {
            if !isLocked {
                recallIconButton(
                    icon: "arrow.uturn.backward",
                    accessibility: "Назад",
                    action: onRemoveLast
                )
                recallIconButton(
                    icon: "arrow.counterclockwise",
                    accessibility: "Сброс",
                    action: onReset
                )
            }

            Spacer(minLength: 8)

            if isCorrect == true {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(brandAccent)
                    .accessibilityLabel("Верно")
            } else if isCorrect == false {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .accessibilityLabel("Исправь красные слоги")
            } else {
                Text("\(assembled.count)/\(max(slotCount, 1))")
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
            }
        }
    }

    private func recallIconButton(icon: String, accessibility: String, action: @escaping () -> Void) -> some View {
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

}
