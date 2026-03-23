import SwiftUI

// MARK: - Recall Game DS (Tap-to-build phonetic)
// Pure rendering; no business logic. Syllable selectability precomputed by View.
// EPIC 2 Discovery: segments define mask (slot + toneAfter); pool has clean syllables only.

public struct RecallSyllableItem: Identifiable {
    public let id: Int
    public let text: String
    public let isSelectable: Bool
}

/// Один раунд для карусели (карточки урока / выученные).
public struct RecallRoundDisplay: Identifiable {
    public let id: Int
    public let question: String
    public let target: String
    public let thai: String
}

public struct RecallGameView: View {

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
    public let onTapSyllable: (String) -> Void
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
        onTapSyllable: @escaping (String) -> Void,
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
        lessonTitle: String? = nil
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
    }

    public var body: some View {
        VStack(spacing: 0) {
            roundCarouselOrCard
                .padding(.bottom, 12)

            Spacer(minLength: 8)

            assembleZone

            Spacer(minLength: 12)

            syllableCarousel

            Spacer(minLength: 12)

            feedbackRow

            Spacer(minLength: 0)

            recallGameBar
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 12)
        .padding(.bottom, 0)
    }

    // MARK: - Round carousel (как SpeakerDS) или одна карточка

    @ViewBuilder
    private var roundCarouselOrCard: some View {
        if let rounds = roundDisplays, !rounds.isEmpty {
            recallRoundCarousel(rounds: rounds)
        } else {
            questionCard
        }
    }

    private var questionCard: some View {
        RecallMiniCard(
            title: question,
            translit: phoneticDisplay ?? "",
            thai: audioText ?? "",
            translitRevealed: isCorrect == true,
            onPlay: (audioText?.isEmpty == false) ? onPlayAudio : nil,
            lessonTitle: lessonTitle
        )
        .frame(maxWidth: .infinity)
        .disabled(isLocked)
    }

    /// Карусель раундов — 1:1 как в FavoriteDS (FDFavReels): ScrollView, 268×196, scale/opacity/yOffset по расстоянию от центра.
    private func recallRoundCarousel(rounds: [RecallRoundDisplay]) -> some View {
        let cardWidth: CGFloat = 268
        let cardHeight: CGFloat = 196
        let spacing: CGFloat = 14
        let sideInset: CGFloat = CD.Spacing.screen
        let currentIndex = min(max(0, currentRoundIndex), rounds.count - 1)
        let reelRounds: [RecallRoundDisplay] = rounds.isEmpty ? [] : (rounds + rounds + rounds)
        let centerIndex = rounds.count

        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(Array(reelRounds.enumerated()), id: \.offset) { idx, display in
                            let realIndex = idx % rounds.count
                            let isCurrent = (realIndex == currentIndex)
                            GeometryReader { itemGeo in
                                let midX = itemGeo.frame(in: .global).midX
                                let containerMidX = geo.frame(in: .global).midX
                                let distance = abs(midX - containerMidX)
                                let maxDistance = cardWidth + spacing
                                let t = min(distance / maxDistance, 1)
                                let scale: CGFloat = 0.9 + (1 - t) * 0.12
                                let opacity: Double = 0.45 + (1 - t) * 0.55
                                let yOffset: CGFloat = t * 18

                                RecallRoundCard(
                                    question: display.question,
                                    target: display.target,
                                    thai: display.thai,
                                    isCurrent: isCurrent,
                                    translitRevealed: isCurrent && (isCorrect == true),
                                    onPlay: (isCurrent && (audioText?.isEmpty == false)) ? onPlayAudio : nil,
                                    lessonTitle: lessonTitle
                                )
                                .scaleEffect(scale)
                                .opacity(opacity)
                                .offset(y: yOffset)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard realIndex != currentIndex, let onSelect = onSelectRound else { return }
                                    onSelect(realIndex)
                                }
                            }
                            .frame(width: cardWidth, height: cardHeight)
                            .id(idx)
                        }
                    }
                    .padding(.horizontal, sideInset)
                    .padding(.vertical, 4)
                    .frame(height: cardHeight + 36)
                }
                .onAppear {
                    if !reelRounds.isEmpty {
                        proxy.scrollTo(centerIndex + currentIndex, anchor: .center)
                    }
                }
                .onChange(of: currentRoundIndex) { _, newIdx in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(centerIndex + newIdx, anchor: .center)
                    }
                }
            }
        }
        .frame(height: cardHeight + 36)
        .frame(maxWidth: .infinity)
        .disabled(isLocked)
    }

    // MARK: - Assemble Zone (как в Speaker: только слоги по центру, без рамок)

    private var assembleZone: some View {
        assemblyMaskRow
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
    }

    private let assemblySpacing: CGFloat = 4
    /// Минимальная ширина на один слог (слот + тон/точка) для расчёта переноса — только перенос, без масштаба.
    private let minSegmentWidth: CGFloat = 56

    /// Число сегментов в строке по доступной ширине (умный перенос целыми слогами).
    private func segmentsPerLine(containerWidth: CGFloat) -> Int {
        max(1, Int(containerWidth / minSegmentWidth))
    }

    private func assemblySegmentRows(containerWidth: CGFloat) -> [[(offset: Int, segment: HomeTaskManager.PhoneticSegment)]] {
        let enumerated = Array(effectiveSegments.enumerated())
        guard !enumerated.isEmpty else { return [] }
        let perLine = segmentsPerLine(containerWidth: containerWidth)
        return stride(from: 0, to: enumerated.count, by: perLine).map {
            Array(enumerated[$0..<min($0 + perLine, enumerated.count)].map { (offset: $0.offset, segment: $0.element) })
        }
    }

    /// Assembly: только умный перенос по строкам (целыми слогами). Без масштабирования — остальная вёрстка не смещается.
    private var assemblyMaskRow: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width - (CD.Spacing.tiny * 2))
            let rows = assemblySegmentRows(containerWidth: width)
            VStack(alignment: .center, spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: assemblySpacing) {
                        ForEach(Array(row.enumerated()), id: \.element.offset) { _, item in
                            let index = item.offset
                            let seg = item.segment
                            let isFilled = index < assembled.count
                            let isWrong = wrongSlotIndices.contains(index)
                            let isSelected = (selectedSlotForReplacement == index)
                            HStack(spacing: assemblySpacing) {
                                minimalSlot(index: index, isFilled: isFilled, isWrong: isWrong, isSelected: isSelected)
                                if let tone = seg.toneAfter {
                                    Text(tone)
                                        .font(CD.FontToken.body(20, weight: .semibold))
                                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                        .lineLimit(1)
                                } else if index < effectiveSegments.count - 1 && !segments.isEmpty {
                                    Text("·")
                                        .font(CD.FontToken.body(14, weight: .medium))
                                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.5))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, CD.Spacing.tiny)
        .padding(.vertical, 10)
    }

    private var effectiveSegments: [HomeTaskManager.PhoneticSegment] {
        if !segments.isEmpty { return segments }
        return (0..<slotCount).map { _ in HomeTaskManager.PhoneticSegment(syllable: "", toneAfter: nil) }
    }

    @ViewBuilder
    private func minimalSlot(index: Int, isFilled: Bool, isWrong: Bool = false, isSelected: Bool = false) -> some View {
        let content: some View = Group {
            if isFilled, index < assembled.count {
                Text(assembled[index])
                    .font(CD.FontToken.body(22, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(isWrong ? AnyShapeStyle(Color.red) : AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .underline(isWrong, color: Color.red)
            } else {
                Text("–")
                    .font(CD.FontToken.body(22, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)

        if isWrong, let onTap = onTapSlot {
            Button { onTap(index) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    // MARK: - Feedback Row (заметный баннер: верно! / исправь слоги)

    @ViewBuilder
    private var feedbackRow: some View {
        if isCorrect == true {
            feedbackBanner(isCorrect: true)
        } else if isCorrect == false {
            feedbackBanner(isCorrect: false)
        }
    }

    /// Реакция на сборку: не кнопка, а компактное сообщение (как в игре).
    private func feedbackBanner(isCorrect: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(isCorrect ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(Color.red))
            Text(isCorrect ? "Верно!" : "Исправь")
                .font(CD.FontToken.body(15, weight: .semibold))
                .foregroundStyle(CD.ColorToken.text)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            Capsule(style: .continuous)
                .fill(isCorrect ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.15)) : AnyShapeStyle(Color.red.opacity(0.12)))
        )
    }

    // MARK: - Syllable Pool (умная адаптация: по ширине экрана, без переносов текста в чипах)
    private let syllableGridMaxHeight: CGFloat = 260
    private let syllableSpacing: CGFloat = 12
    private let minChipWidth: CGFloat = 64

    private var syllableCarousel: some View {
        VStack(alignment: .center, spacing: CD.Spacing.inner) {
            GeometryReader { geo in
                let availableWidth = geo.size.width - (CD.Spacing.screen * 2)
                let cols = max(3, min(5, Int(availableWidth / (minChipWidth + syllableSpacing))))
                let columns = Array(repeating: GridItem(.flexible(), spacing: syllableSpacing), count: cols)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, alignment: .center, spacing: syllableSpacing) {
                        ForEach(syllableItems) { item in
                            recallSyllableChip(item: item)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: syllableGridMaxHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private func recallSyllableChip(item: RecallSyllableItem) -> some View {
        Button {
            onTapSyllable(item.text)
        } label: {
            Text(item.text)
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(item.isSelectable ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.7)))
                .frame(minWidth: minChipWidth, minHeight: 48)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CD.ColorToken.card.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            item.isSelectable ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.6)) : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                            lineWidth: 1.5
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(isLocked || !item.isSelectable)
        .opacity((isLocked || !item.isSelectable) ? 0.65 : 1)
    }

    // MARK: - Recall Game Bar (внизу экрана, как Speaker — обводка/заливка в айдентике)

    private var recallGameBar: some View {
        VStack(spacing: 14) {
            // Назад = выйти из игры; Сброс = очистить и начать раунд заново
            HStack(spacing: 12) {
                Button(action: onRemoveLast) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Назад")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule(style: .continuous).fill(Color.clear))
                    .overlay(Capsule(style: .continuous).stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .opacity(isLocked ? 0.5 : 1)
                .disabled(isLocked)

                Button(action: onReset) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Сброс")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule(style: .continuous).fill(Color.clear))
                    .overlay(Capsule(style: .continuous).stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .opacity(isLocked ? 0.5 : 1)
                .disabled(isLocked)
            }

            if assembled.count == slotCount && slotCount > 0 {
                if isCorrect == true {
                    Button(action: { onNextRound?() }) {
                        HStack(spacing: 8) {
                            Text("Дальше")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color(white: 0.14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                    }
                    .buttonStyle(.plain)
                } else if isCorrect == nil || isCorrect == false {
                    Button(action: onCheck) {
                        HStack(spacing: 8) {
                            Text("Проверить")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color(white: 0.14))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                }
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(
            PD.ColorToken.background
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(PD.ColorToken.stroke.opacity(0.5)),
                    alignment: .top
                )
        )
    }

}

// MARK: - RecallRoundCard (1:1 как FDMiniCardV: taikA, центр, bottomBar = AppCardIconButton listen + чип урока)

private struct RecallRoundCard: View {
    let question: String
    let target: String
    let thai: String
    let isCurrent: Bool
    let translitRevealed: Bool
    let onPlay: (() -> Void)?
    let lessonTitle: String?

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        VStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text("taikA")
                    .font(Font.custom("ONMARK Trial", size: 14))
                    .foregroundStyle(PD.ColorToken.text)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: 8) {
                if isCurrent && translitRevealed && !target.isEmpty {
                    Text(target)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .lineLimit(2)
                        .minimumScaleFactor(0.80)
                        .multilineTextAlignment(.center)
                }
                Text(question.isEmpty ? "—" : question)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.80)
                    .multilineTextAlignment(.center)
                if !thai.isEmpty {
                    Text(thai)
                        .font(.footnote)
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .opacity(0.86)
                        .lineLimit(1)
                        .minimumScaleFactor(0.90)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            HStack {
                if onPlay != nil {
                    AppCardIconButton(kind: .listen, forceAccent: true, onTap: { onPlay?() })
                }
                Spacer(minLength: 10)
                if let title = lessonTitle, !title.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill)))
                    .overlay(Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: 268, height: 196, alignment: .top)
        .background(Theme.Surfaces.card(round))
        .overlay(round.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
        .contentShape(round)
    }
}

// MARK: - RecallMiniCard (как FDMiniCardV: listen-кнопка + чип урока)

private struct RecallMiniCard: View {
    let title: String
    let translit: String
    let thai: String
    let translitRevealed: Bool
    let onPlay: (() -> Void)?
    let lessonTitle: String?

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        VStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center) {
                Text("taikA")
                    .font(Font.custom("ONMARK Trial", size: 14))
                    .foregroundStyle(PD.ColorToken.text)
                Spacer(minLength: 8)
            }

            VStack(alignment: .center, spacing: 4) {
                Text(title)
                    .font(CD.FontToken.body(16, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .lineLimit(Theme.TextBlock.cardTitleLines)
                    .minimumScaleFactor(Theme.TextBlock.titleMinimumScale)
                    .multilineTextAlignment(.center)

                if !translit.isEmpty && translitRevealed {
                    Text(translit)
                        .font(CD.FontToken.caption(14, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                if !thai.isEmpty {
                    Text(thai)
                        .font(CD.FontToken.caption(12, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                if onPlay != nil {
                    AppCardIconButton(kind: .listen, forceAccent: true, onTap: { onPlay?() })
                }
                Spacer(minLength: 10)
                if let t = lessonTitle, !t.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(t)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill)))
                    .overlay(Capsule().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.Surfaces.card(round))
        .overlay(round.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
    }
}
