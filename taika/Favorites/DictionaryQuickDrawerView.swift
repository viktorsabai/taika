//
//  DictionaryQuickDrawerView.swift
//  taika
//
//  Dictionary UX: personal phrases are a first-class utility layer, not a Favorites filter.
//  Visual language: Taika dark glass, restrained pink/lilac accent, readable Russian copy,
//  reversible right-side drawer that preserves the underlying screen context.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DictionaryQuickDrawerView: View {
    @ObservedObject private var favorites = FavoriteManager.shared
    @Environment(\.colorScheme) private var colorScheme

    let onDismiss: () -> Void
    let onOpenFullDictionary: () -> Void
    let onOpenSpeaker: () -> Void

    @State private var drawerOffset: CGFloat = 0
    @State private var didAppear = false

    private var cards: [FDCardDTO] {
        Array(favorites.smartSpeakerDictionaryCardsDTO.prefix(5))
    }

    private var accent: AnyShapeStyle {
        AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissAnimated() }

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                drawer
                    .frame(maxWidth: 430)
                    .frame(width: min(UIScreen.main.bounds.width * 0.86, 430))
                    .offset(x: didAppear ? drawerOffset : 48)
                    .opacity(didAppear ? 1 : 0)
                    .gesture(drawerDrag)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                didAppear = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Быстрый словарь")
    }

    private var drawer: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(CD.ColorToken.textSecondary.opacity(0.42))
                .frame(width: 38, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Мой словарь")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(CD.ColorToken.text)
                    Text("Твои фразы для жизни в Таиланде")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
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
            .padding(.horizontal, 20)
            .padding(.top, 12)

            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                Text("\(favorites.smartSpeakerDictionaryCardsDTO.count) фраз")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                Spacer(minLength: 0)
                Text("личные")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.72))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            if cards.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(cards) { card in
                            DictionaryDrawerRow(
                                card: card,
                                accent: accent,
                                onSpeak: onOpenSpeaker
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }
            }

            VStack(spacing: 12) {
                Button(action: onOpenFullDictionary) {
                    HStack(spacing: 8) {
                        Text("Открыть весь словарь")
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule(style: .continuous).fill(accent))
                }
                .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))

                Button(action: dismissAnimated) {
                    Text("Свайпни вправо, чтобы вернуться")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.82))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(CD.ColorToken.background.opacity(0.98))
                .background(.ultraThinMaterial)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accent)
                .frame(width: 1.5)
                .blur(radius: 0.2)
                .opacity(0.85)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.42)), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.36), radius: 28, x: -10, y: 0)
        .padding(.vertical, 10)
        .padding(.trailing, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(accent)
            Text("Твои фразы появятся здесь")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
            Text("Скажи фразу в Speaker и добавь её в свой словарь.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button("Открыть Speaker", action: onOpenSpeaker)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(accent)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
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
                if value.translation.width > 100 || value.predictedEndTranslation.width > 160 {
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
            drawerOffset = UIScreen.main.bounds.width
            didAppear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }
}

struct DictionaryDrawerRow: View {
    let card: FDCardDTO
    let accent: AnyShapeStyle
    var onSpeak: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onTrain: (() -> Void)? = nil
    var showsActionsMenu: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(CD.ColorToken.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.88)
                Text(card.meta)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                if !card.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(card.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)

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
                .accessibilityLabel("Открыть Speaker")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(PD.ColorToken.stroke.opacity(0.7), lineWidth: 1)
        )
        .contextMenu {
            if showsActionsMenu {
                dictionaryPhraseContextMenu(
                    card: card,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onTrain: onTrain
                )
            }
        }
    }
}

struct DictionaryPhraseActionsMenu: View {
    let card: FDCardDTO
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTrain: (() -> Void)?

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
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(CD.ColorToken.chip))
                .overlay(Circle().stroke(PD.ColorToken.stroke.opacity(0.65), lineWidth: 1))
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

struct DictionaryFullView: View {
    @ObservedObject private var favorites = FavoriteManager.shared
    @EnvironmentObject private var nav: NavigationIntent

    let onBack: () -> Void
    let onOpenSpeaker: () -> Void
    var onNavigateToSpeaker: (() -> Void)? = nil

    @State private var editingCard: DictionaryEditTarget?

    private var cards: [FDCardDTO] {
        favorites.smartSpeakerDictionaryCardsDTO
    }

    private var accent: AnyShapeStyle {
        AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            chipsRow

            if cards.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(cards) { card in
                            DictionaryDrawerRow(
                                card: card,
                                accent: accent,
                                onEdit: { editingCard = DictionaryEditTarget(card: card) },
                                onDelete: { deleteCard(card) },
                                onTrain: { trainInSpeaker() },
                                showsActionsMenu: true
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Layout.pageHorizontal)
                    .padding(.bottom, ToolBar.recommendedBottomInset + 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(CD.ColorToken.background.ignoresSafeArea())
        .sheet(item: $editingCard) { target in
            DictionaryEditSheet(card: target.card) {
                editingCard = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(CD.ColorToken.text)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(CD.ColorToken.chip))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Назад")

            VStack(alignment: .leading, spacing: 3) {
                Text("Мой словарь")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(CD.ColorToken.text)
                Text("Твои фразы для жизни в Таиланде")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
        }
        .padding(.horizontal, Theme.Layout.pageHorizontal)
        .padding(.top, Theme.Layout.rootHeaderClearance + 10)
        .padding(.bottom, 18)
    }

    private var chipsRow: some View {
        HStack(spacing: 8) {
            Text("Все фразы")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Capsule().fill(ThemeManager.shared.currentAccentFill))
            Text("\(cards.count) личных")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Layout.pageHorizontal)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
            Text("Здесь будут твои личные фразы")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
            Text("Создай первую фразу в Speaker и сохрани её в словарь.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func deleteCard(_ card: FDCardDTO) {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
        favorites.remove(id: DictionaryPhraseActions.cardId(card))
    }

    private func trainInSpeaker() {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
        SpeakerManager.shared.setSpeakerUIMode(.training)
        SpeakerManager.shared.startSpecialTraining(poolId: "__dictionary__")
        if let onNavigateToSpeaker {
            onNavigateToSpeaker()
        } else {
            nav.popToRoot()
            nav.requestTab(2)
        }
    }
}
