//
//  DictionaryQuickDrawerView.swift
//  taika
//
//  Personal dictionary: full-height side panel (X-style peek), one surface — no preview/full split.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Полноширинная CTA как в Избранном / Зачётке: без розовой полоски слева.
struct DictionarySoftActionLabel: View {
    let icon: String
    let title: String
    var trailingSystemImage: String? = "arrow.up.right"
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 10 : 12) {
            Image(systemName: icon)
                .font(.system(size: compact ? 16 : 18, weight: .semibold))
            Text(title)
                .font(.system(size: compact ? 15 : 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(.system(size: compact ? 13 : 15, weight: .bold))
            }
        }
        .foregroundStyle(PD.ColorToken.text)
        .padding(.horizontal, compact ? 14 : 18)
        .frame(maxWidth: .infinity, minHeight: compact ? 52 : 58)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PD.ColorToken.card.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PD.ColorToken.stroke.opacity(0.8), lineWidth: 1)
        )
    }
}

struct DictionaryQuickDrawerView: View {
    @ObservedObject private var favorites = FavoriteManager.shared
    @EnvironmentObject private var nav: NavigationIntent
    @EnvironmentObject private var overlay: OverlayPresenter

    let onDismiss: () -> Void
    let onOpenSpeaker: () -> Void
    /// nil = all phrases; non-empty = only selected card source ids.
    var onTrainInSpeaker: ((Set<String>?) -> Void)? = nil

    @State private var drawerOffset: CGFloat = 0
    @State private var didAppear = false
    @State private var editingCard: DictionaryEditTarget?
    @State private var breakdownCard: DictionaryEditTarget?
    @State private var isSelectionMode = false
    @State private var selectedIds: Set<String> = []
    @State private var gamePickerExpanded = false
    @State private var selectedGameMode: GameModeType = .match

    private var cards: [FDCardDTO] {
        favorites.smartSpeakerDictionaryCardsDTO
    }

    private var accent: AnyShapeStyle {
        AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

    private var effectiveSelection: Set<String>? {
        if isSelectionMode, !selectedIds.isEmpty { return selectedIds }
        return nil
    }

    private var peekWidth: CGFloat { 52 }

    private var panelWidth: CGFloat {
        max(280, UIScreen.main.bounds.width - peekWidth)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                Color.black.opacity(didAppear ? 0.52 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissAnimated() }

                panel
                    .frame(width: panelWidth)
                    .frame(maxHeight: .infinity)
                    .offset(x: (didAppear ? drawerOffset : panelWidth))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                didAppear = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Мой словарь")
        .sheet(item: $editingCard) { target in
            DictionaryEditSheet(card: target.card) {
                editingCard = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(item: $breakdownCard) { target in
            DictionaryPhraseBreakdownSheet(card: target.card) {
                breakdownCard = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            header

            if cards.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        LazyVStack(spacing: 12) {
                            ForEach(cards) { card in
                                DictionaryDrawerRow(
                                    card: card,
                                    accent: accent,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedIds.contains(card.sourceId),
                                    onToggleSelect: { toggleSelection(card) },
                                    onTap: {
                                        if isSelectionMode {
                                            toggleSelection(card)
                                        } else {
                                            DictionaryPhraseActions.play(card)
                                        }
                                    },
                                    onLongPress: {
                                        guard !isSelectionMode else { return }
                                        breakdownCard = DictionaryEditTarget(card: card)
                                    },
                                    onEdit: { editingCard = DictionaryEditTarget(card: card) },
                                    onDelete: {
                                        favorites.remove(id: DictionaryPhraseActions.cardId(card))
                                        selectedIds.remove(card.sourceId)
                                    },
                                    onTrain: { trainInSpeaker(selected: [card.sourceId]) },
                                    showsActionsMenu: !isSelectionMode
                                )
                            }
                        }
                        .padding(.horizontal, Theme.Layout.pageHorizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 18)

                        footerBar
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CD.ColorToken.background.ignoresSafeArea())
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: 24,
                    bottomLeading: 24,
                    bottomTrailing: 0,
                    topTrailing: 0
                ),
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.28), radius: 24, x: -8, y: 0)
        .gesture(drawerDrag)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Мой словарь")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(CD.ColorToken.text)
                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)

            if !cards.isEmpty {
                Button(action: toggleSelectionMode) {
                    Text(isSelectionMode ? "Готово" : "Выбрать")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }

            Button(action: dismissAnimated) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(CD.ColorToken.chip))
                    .overlay(Circle().stroke(Theme.Strokes.strokeSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть словарь")
        }
        .padding(.horizontal, Theme.Layout.pageHorizontal)
        .padding(.top, Theme.Layout.rootHeaderClearance + 8)
        .padding(.bottom, 10)
    }

    private var headerSubtitle: String {
        if cards.isEmpty {
            return "Твои фразы для жизни в Таиланде"
        }
        if isSelectionMode, !selectedIds.isEmpty {
            return "Выбрано \(selectedIds.count) · \(dictionaryPhraseCountLabel(cards.count))"
        }
        return "\(dictionaryPhraseCountLabel(cards.count)) · для жизни в Таиланде"
    }

    private var footerBar: some View {
        VStack(spacing: 0) {
            if gamePickerExpanded {
                gamePickerSection
            } else {
                actionButtonsRow
            }
        }
        .padding(.bottom, ToolBar.recommendedBottomInset + 12)
        .animation(.easeInOut(duration: 0.22), value: gamePickerExpanded)
    }

    private var actionButtonsRow: some View {
        VStack(spacing: 10) {
            Button { trainInSpeaker(selected: effectiveSelection) } label: {
                footerActionLabel(icon: "mic.fill", title: trainButtonTitle)
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
            .disabled(isSelectionMode && selectedIds.isEmpty)
            .opacity(isSelectionMode && selectedIds.isEmpty ? 0.45 : 1)

            Button {
                withAnimation { gamePickerExpanded = true }
            } label: {
                footerActionLabel(icon: "gamecontroller.fill", title: reinforceButtonTitle)
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
            .disabled(isSelectionMode && selectedIds.isEmpty)
            .opacity(isSelectionMode && selectedIds.isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, Theme.Layout.pageHorizontal)
        .padding(.vertical, 10)
    }

    private var gamePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(reinforceButtonTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CD.ColorToken.text)
                Spacer(minLength: 0)
                Button("Назад") {
                    withAnimation { gamePickerExpanded = false }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CD.ColorToken.textSecondary)
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.top, 14)

            GameModePickerDS(
                selected: $selectedGameMode,
                isProUser: ProManager.shared.isPro,
                onStart: { mode in startGame(mode: mode) },
                onClose: { withAnimation { gamePickerExpanded = false } },
                onLockedTap: { mode in
                    if mode.isPro && !ProManager.shared.isPro {
                        overlay.presentPro(reason: .games)
                    }
                },
                modes: GameModeType.modesLessonAndPark,
                embedInEtalon: false,
                contentHorizontalInset: Theme.Layout.pageHorizontal,
                contentBottomInset: 12
            )
        }
    }

    @ViewBuilder
    private func footerActionLabel(icon: String, title: String) -> some View {
        DictionarySoftActionLabel(icon: icon, title: title)
    }

    private var trainButtonTitle: String {
        if isSelectionMode, !selectedIds.isEmpty {
            return "Тренировать (\(selectedIds.count))"
        }
        return "Тренировать все"
    }

    private var reinforceButtonTitle: String {
        if isSelectionMode, !selectedIds.isEmpty {
            return "Закрепить (\(selectedIds.count))"
        }
        return "Закрепить все"
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 24)
            Image(systemName: "bookmark")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(accent)
            Text("Твои фразы появятся здесь")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
            Text("Скажи фразу в Speaker и сохрани её в словарь.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Открыть Speaker", action: onOpenSpeaker)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent)
                .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleSelectionMode() {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedIds.removeAll()
                gamePickerExpanded = false
            }
        }
    }

    private func toggleSelection(_ card: FDCardDTO) {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        if selectedIds.contains(card.sourceId) {
            selectedIds.remove(card.sourceId)
        } else {
            selectedIds.insert(card.sourceId)
        }
    }

    private func trainInSpeaker(selected: Set<String>?) {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
        DictionarySessionSelection.shared.activate(selected)
        if let onTrainInSpeaker {
            onTrainInSpeaker(selected)
        } else {
            onOpenSpeaker()
        }
    }

    private func startGame(mode: GameModeType) {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
        DictionarySessionSelection.shared.activate(effectiveSelection)
        dismissAnimated()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            nav.go(.game(
                courseId: DictionaryGameSource.courseId,
                lessonId: nil,
                gameType: mode.rawValue
            ))
        }
    }

    private var drawerDrag: some Gesture {
        DragGesture(minimumDistance: 14, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width > 0 {
                    drawerOffset = value.translation.width
                }
            }
            .onEnded { value in
                if value.translation.width > 90 || value.predictedEndTranslation.width > 140 {
                    dismissAnimated()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        drawerOffset = 0
                    }
                }
            }
    }

    private func dismissAnimated() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            drawerOffset = panelWidth
            didAppear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }
}

// MARK: - Helpers

private func dictionaryPhraseCountLabel(_ count: Int) -> String {
    let mod10 = count % 10
    let mod100 = count % 100
    if mod100 >= 11 && mod100 <= 14 { return "\(count) фраз" }
    switch mod10 {
    case 1: return "\(count) фраза"
    case 2, 3, 4: return "\(count) фразы"
    default: return "\(count) фраз"
    }
}

struct DictionaryDrawerRow: View {
    let card: FDCardDTO
    let accent: AnyShapeStyle
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelect: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil
    var onLongPress: (() -> Void)? = nil
    var onSpeak: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onTrain: (() -> Void)? = nil
    var showsActionsMenu: Bool = false

    private var phonetic: String { dictionaryCardPhonetic(card) }

    private var thai: String {
        card.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 12)

            HStack(alignment: .center, spacing: 12) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? accent : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.5)))
                }

                VStack(alignment: .leading, spacing: 6) {
                    if !phonetic.isEmpty {
                        TaikaPhoneticText.styled(
                            phonetic,
                            font: .system(size: 17, weight: .semibold),
                            baseColor: CD.ColorToken.text
                        )
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(isSelectionMode ? 2 : 3)
                        .minimumScaleFactor(0.85)
                    }
                    if !card.title.isEmpty {
                        Text(card.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)
                    }
                    if !thai.isEmpty, !isSelectionMode {
                        Text(thai)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.72))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let onTap { onTap() }
                }

                if !isSelectionMode {
                    Button {
                        DictionaryPhraseActions.play(card)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(CD.ColorToken.chip))
                            .overlay(Circle().stroke(PD.ColorToken.stroke.opacity(0.65), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Послушать")

                    if showsActionsMenu {
                        DictionaryPhraseActionsMenu(
                            card: card,
                            onEdit: onEdit,
                            onDelete: onDelete,
                            onTrain: onTrain
                        )
                    } else if let onSpeak {
                        Button(action: onSpeak) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(accent)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(CD.ColorToken.chip))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Послушать")
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? CD.ColorToken.card.opacity(0.95) : CD.ColorToken.card.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected
                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                    : AnyShapeStyle(PD.ColorToken.stroke.opacity(0.72)),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            if isSelectionMode {
                onToggleSelect?()
            } else {
                onTap?()
            }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard !isSelectionMode else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onLongPress?()
        }
        .accessibilityHint(showsActionsMenu ? "Долгое нажатие — разбор фразы" : "")
    }
}

private func dictionaryCardPhonetic(_ card: FDCardDTO) -> String {
    var meta = card.meta
    if meta.hasPrefix("card:") { meta = String(meta.dropFirst("card:".count)) }
    return meta.trimmingCharacters(in: .whitespacesAndNewlines)
}

struct DictionaryPhraseActionsMenu: View {
    let card: FDCardDTO
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTrain: (() -> Void)?
    var compact: Bool = false

    var body: some View {
        Menu {
            dictionaryPhraseContextMenu(
                card: card,
                onEdit: onEdit,
                onDelete: onDelete,
                onTrain: onTrain
            )
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: compact ? 15 : 15, weight: .bold))
                .foregroundStyle(compact ? PD.ColorToken.textSecondary : CD.ColorToken.textSecondary)
                .frame(width: compact ? 28 : 34, height: compact ? 36 : 34)
                .background {
                    if !compact {
                        Circle().fill(CD.ColorToken.chip)
                    }
                }
                .overlay {
                    if !compact {
                        Circle().stroke(PD.ColorToken.stroke.opacity(0.65), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Действия с фразой")
    }
}

@ViewBuilder
func dictionaryPhraseContextMenu(
    card: FDCardDTO,
    onEdit: (() -> Void)?,
    onDelete: (() -> Void)?,
    onTrain: (() -> Void)?
) -> some View {
    Button {
        DictionaryPhraseActions.play(card)
    } label: {
        Label("Послушать", systemImage: "speaker.wave.2.fill")
    }

    if !card.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Button {
            DictionaryPhraseActions.copyThai(card)
        } label: {
            Label("Скопировать тайский", systemImage: "doc.on.doc")
        }
    }

    if let onTrain {
        Button(action: onTrain) {
            Label("Тренировка", systemImage: "person.wave.2.fill")
        }
    }

    if let onEdit {
        Button(action: onEdit) {
            Label("Изменить", systemImage: "pencil")
        }
    }

    if let onDelete {
        Divider()
        Button(role: .destructive, action: onDelete) {
            Label("Удалить", systemImage: "trash")
        }
    }
}

enum DictionaryPhraseActions {
    static func play(_ card: FDCardDTO) {
        let thai = card.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thai.isEmpty else { return }
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        StepAudio.shared.speakThai(thai)
    }

    static func copyThai(_ card: FDCardDTO) {
        let thai = card.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thai.isEmpty else { return }
#if canImport(UIKit)
        UIPasteboard.general.string = thai
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
    }

    static func cardId(_ card: FDCardDTO) -> String {
        DictionaryEditTarget(card: card).id
    }
}

/// Лонгтап по фразе словаря: РАЗБОР (не дубль меню ⋯).
struct DictionaryPhraseBreakdownSheet: View {
    let card: FDCardDTO
    var onDismiss: () -> Void

    @ObservedObject private var favorites = FavoriteManager.shared
    @State private var repairInFlight = false
    @State private var repairAttempted = false

    private var phonetic: String {
        var meta = card.meta
        if meta.hasPrefix("card:") { meta = String(meta.dropFirst("card:".count)) }
        return meta.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parts: [FavoritePhrasePart] {
        let stored = FavoriteManager.shared.dictionaryPhraseParts(for: card)
        if !stored.isEmpty { return stored }
        return card.phraseParts ?? []
    }

    /// Карточки, сохранённые до пословного контракта, могут хранить обрезанный разбор.
    /// Он выглядит как полноценный, поэтому проверяем его тем же инвариантом, что и живой.
    private var storedPartsAreUsable: Bool {
        let saved = parts
        guard !saved.isEmpty, !phonetic.isEmpty else { return false }
        let mapped = saved.map { SpeakerManager.SmartSpeakerPart(p: $0.p, m: $0.m) }
        return SpeakerManager.partsMatchPhonetic(phonetic: phonetic, parts: mapped)
    }

    /// Чиним молча: пользователь не должен узнать, что в его словаре лежал мусор.
    private func repairPartsIfNeeded() {
        guard !repairAttempted, !repairInFlight else { return }
        guard !storedPartsAreUsable else { return }
        let thai = card.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thai.isEmpty, !phonetic.isEmpty else { return }

        repairAttempted = true
        repairInFlight = true
        let sourceId = card.sourceId
        let ru = card.title
        let ph = phonetic
        Task {
            let fresh = await SpeakerManager.shared.alignedPhraseParts(ru: ru, thai: thai, phonetic: ph)
            await MainActor.run {
                repairInFlight = false
                guard !fresh.isEmpty else { return }
                FavoriteManager.shared.replaceDictionaryPhraseParts(
                    sourceId: sourceId,
                    parts: fresh.map { FavoritePhrasePart(p: $0.p, m: $0.m) }
                )
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !phonetic.isEmpty {
                            TaikaPhoneticText.styled(
                                phonetic,
                                font: .system(size: 22, weight: .semibold),
                                baseColor: CD.ColorToken.text
                            )
                        }
                        if !card.title.isEmpty {
                            Text(card.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(CD.ColorToken.textSecondary)
                        }
                        let thai = card.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !thai.isEmpty {
                            Text(thai)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.75))
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("РАЗБОР")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))

                        if repairInFlight {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("собираю разбор…")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                            }
                        } else if !storedPartsAreUsable {
                            Text("У этой фразы разбора нет.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(part.p)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(PD.ColorToken.text.opacity(0.92))
                                        Text("—")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.45))
                                        Text(SpeakerManager.withoutThaiScript(part.m))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.88))
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                        }
                    }

                }
                .padding(.horizontal, Theme.Layout.pageHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .onAppear { repairPartsIfNeeded() }
            .background(CD.ColorToken.background.ignoresSafeArea())
            .navigationTitle("Разбор")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { onDismiss() }
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
}

/// Push-route fallback when dictionary opens from deep link (not the side panel).
struct DictionaryFullView: View {
    @ObservedObject private var favorites = FavoriteManager.shared
    @EnvironmentObject private var nav: NavigationIntent
    @EnvironmentObject private var overlay: OverlayPresenter

    let onBack: () -> Void
    let onOpenSpeaker: () -> Void
    var onNavigateToSpeaker: (() -> Void)? = nil

    var body: some View {
        DictionaryQuickDrawerView(
            onDismiss: onBack,
            onOpenSpeaker: onOpenSpeaker,
            onTrainInSpeaker: { selected in
                DictionarySessionSelection.shared.activate(selected)
                trainInSpeaker()
            }
        )
        .environmentObject(nav)
        .environmentObject(overlay)
    }

    private func trainInSpeaker() {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
        SpeakerManager.shared.setSpeakerUIMode(.training)
        SpeakerRequestedCourseId.shared.set("__dictionary__")
        SpeakerManager.shared.startSpecialTraining(poolId: "__dictionary__")
        if nav.path.contains(where: { if case .dictionary = $0 { return true }; return false }) {
            SpeakerReturnContext.shared.save(tab: 0, path: nav.path)
        } else {
            SpeakerReturnContext.shared.saveFromDictionary(tab: 3)
        }
        if let onNavigateToSpeaker {
            onNavigateToSpeaker()
        } else {
            nav.popToRoot()
            nav.requestTab(2)
        }
    }
}
