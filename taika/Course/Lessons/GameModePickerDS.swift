//
//  GameModePickerDS.swift
//  taika
//
//  Created by product on 15.02.2026.
//

import SwiftUI

public enum GameModeType: String, Equatable {
    case match
    case recall
    case audioRecall
    case grandDialogue

    public var title: String {
        switch self {
        case .match: return "Найди пару"
        case .recall: return "Быстрое повторение"
        case .audioRecall: return "Аудио-реплика"
        case .grandDialogue: return "Диалог курса"
        }
    }

    public var isPro: Bool {
        switch self {
        case .match: return false
        case .recall, .audioRecall, .grandDialogue: return true
        }
    }

    /// Режимы из урока / игрового парка (без финального диалога курса).
    public static let modesLessonAndPark: [GameModeType] = [.match, .recall, .audioRecall]

    public static func modesForCourseLauncher(courseCompleted: Bool) -> [GameModeType] {
        var m = modesLessonAndPark
        // Grand Dialogue: показываем только при TaikaReleaseFlags.showGrandDialogue.
        // До completion курса режим остаётся в списке, но locked (см. CourseView.lockedModes).
        if TaikaReleaseFlags.showGrandDialogue, !m.contains(.grandDialogue) {
            m.append(.grandDialogue)
        }
        _ = courseCompleted
        return m
    }
}

#Preview {
    GameModePickerDS(
        selected: .constant(.match),
        isProUser: false,
        onStart: { _ in },
        onClose: {}
    )
}

public struct GameModePickerDS: View {

    @Binding public var selected: GameModeType
    public var isProUser: Bool
    public var onStart: (GameModeType) -> Void
    public var onClose: () -> Void
    /// Callback invoked when user taps a locked mode (e.g. Grand Dialogue before completion).
    public var onLockedTap: (GameModeType) -> Void = { _ in }
    /// Optional first-class Speaker reinforcement action for course-scoped launchers.
    public var onSpeaker: (() -> Void)?
    /// Режимы, которые отображаются, но пока нельзя стартовать (например, Grand Dialogue до completion курса).
    public var lockedModes: Set<GameModeType> = []
    /// Режимы в порядке отображения (по умолчанию без Grand Dialogue).
    public var modes: [GameModeType] = GameModeType.modesLessonAndPark
    /// Когда false, рисуется только контент (список режимов + кнопка) для вставки в OverlayEtalonCard. Когда true — полный экран со своим фоном и карточкой (CourseView и т.д.).
    public var embedInEtalon: Bool = true
    /// Горизонтальные отступы у списка и кнопки «Начать» (0 — когда родитель уже даёт inset, напр. `LessonSummaryOverlay`).
    public var contentHorizontalInset: CGFloat = 20
    /// Нижний отступ под кнопкой «Начать».
    public var contentBottomInset: CGFloat = 24
    /// «Голос» / «Игры» — выключить, если родитель уже даёт одну секцию «Как закрепить».
    public var showsSectionLabels: Bool = true

    public init(
        selected: Binding<GameModeType>,
        isProUser: Bool,
        onStart: @escaping (GameModeType) -> Void,
        onClose: @escaping () -> Void,
        onLockedTap: @escaping (GameModeType) -> Void = { _ in },
        lockedModes: Set<GameModeType> = [],
        modes: [GameModeType] = GameModeType.modesLessonAndPark,
        embedInEtalon: Bool = true,
        contentHorizontalInset: CGFloat = 20,
        contentBottomInset: CGFloat = 24,
        onSpeaker: (() -> Void)? = nil,
        showsSectionLabels: Bool = true
    ) {
        self._selected = selected
        self.isProUser = isProUser
        self.onStart = onStart
        self.onClose = onClose
        self.onLockedTap = onLockedTap
        self.lockedModes = lockedModes
        self.modes = modes
        self.embedInEtalon = embedInEtalon
        self.contentHorizontalInset = contentHorizontalInset
        self.contentBottomInset = contentBottomInset
        self.onSpeaker = onSpeaker
        self.showsSectionLabels = showsSectionLabels
    }

    public var body: some View {
        if embedInEtalon {
            fullPickerView
        } else {
            pickerContentOnly
        }
    }

    private var fullPickerView: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onClose)
            OverlayEtalonCard(title: "Выбери режим", onDismiss: onClose) {
                pickerBody
                    .padding(.bottom, 8)
            }
        }
    }

    /// Только контент для вставки в OverlayEtalonCard (без фона, без своей карточки, без заголовка «Выбери режим»).
    private var pickerContentOnly: some View {
        pickerBody
    }

    /// Блокировки сценария (курс не завершён и т.д.) + PRO-режимы для не‑PRO пользователя.
    private func isModeLocked(_ mode: GameModeType) -> Bool {
        if lockedModes.contains(mode) { return true }
        if mode.isPro && !isProUser { return true }
        return false
    }

    @ViewBuilder
    private var pickerBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let onSpeaker {
                if showsSectionLabels {
                    ReinforceSectionLabel("Голос")
                }
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSpeaker()
                } label: {
                    ReinforceOptionRow(
                        title: "Спикер",
                        subtitle: "произношение и тоны вслух",
                        trailing: .chevron,
                        leadingIcon: "mic.fill"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Спикер: закрепить произношение и тоны")

                if showsSectionLabels {
                    ReinforceSectionLabel("Игры")
                        .padding(.top, 4)
                }
            }

            ForEach(modes, id: \.self) { mode in
                let locked = isModeLocked(mode)
                Button {
                    guard !locked else {
                        onLockedTap(mode)
                        return
                    }
                    selected = mode
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onStart(mode)
                } label: {
                    ReinforceOptionRow(
                        title: mode.title,
                        subtitle: locked ? lockedDescription(for: mode) : description(for: mode),
                        isLocked: locked,
                        showsProCrown: mode.isPro,
                        trailing: locked ? .none : .chevron
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, contentHorizontalInset)
        .padding(.bottom, contentBottomInset)
        .onAppear {
            let firstUnlocked = modes.first(where: { !isModeLocked($0) }) ?? .match
            if !modes.contains(selected) || isModeLocked(selected) {
                selected = firstUnlocked
            }
        }
    }

    private func lockedDescription(for mode: GameModeType) -> String {
        if mode.isPro && !isProUser {
            return "нужен PRO"
        }
        switch mode {
        case .grandDialogue:
            return "откроется после завершения курса"
        default:
            return "Пока недоступно"
        }
    }

    private func description(for mode: GameModeType) -> String {
        switch mode {
        case .match:
            return "закрепление через поиск пар"
        case .recall:
            return "активное вспоминание в формате sprint"
        case .audioRecall:
            return "слушай тайскую реплику, собери русский перевод из слов"
        case .grandDialogue:
            return "полный диалог курса: ответы голосом, как в Спикере"
        }
    }
}

// MARK: - Shared reinforce choice row (pool + speaker + games)

public struct ReinforceSectionLabel: View {
    let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.78))
            .textCase(.uppercase)
            .padding(.leading, 2)
    }
}

/// Единый ряд для выбора курса / спикера / игры в оверлеях закрепления.
public struct ReinforceOptionRow: View {
    public enum Trailing {
        case chevron
        case selection
        case none
    }

    let title: String
    let subtitle: String
    var isSelected: Bool = false
    var isLocked: Bool = false
    var showsProCrown: Bool = false
    var trailing: Trailing = .chevron
    var leadingIcon: String? = nil

    @ObservedObject private var theme = ThemeManager.shared

    private var accentBar: AnyShapeStyle {
        if isLocked {
            return AnyShapeStyle(PD.ColorToken.stroke.opacity(0.42))
        }
        if trailing == .selection && !isSelected {
            return AnyShapeStyle(PD.ColorToken.stroke.opacity(0.42))
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.42, blue: 0.78),
                    Color(red: 0.68, green: 0.42, blue: 1.0).opacity(0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    public var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    if let leadingIcon {
                        Image(systemName: leadingIcon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.currentAccentFill)
                    }

                    if showsProCrown {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(theme.currentAccentFill)
                            .font(.system(size: 13))
                    }

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.white.opacity(0.7))
                            .font(.system(size: 13))
                    }
                }

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(isLocked ? 0.52 : (isSelected || trailing != .selection ? 0.6 : 0.55)))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            switch trailing {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
            case .selection:
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                        ? AnyShapeStyle(theme.currentAccentFill)
                        : AnyShapeStyle(Color.white.opacity(0.35))
                    )
            case .none:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(PD.ColorToken.card.opacity(rowFillOpacity))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentBar)
                .frame(width: 3)
                .padding(.vertical, 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PD.ColorToken.stroke.opacity(strokeOpacity), lineWidth: 1)
        )
        .opacity(isLocked ? 0.72 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var rowFillOpacity: Double {
        if isLocked { return 0.42 }
        if trailing == .selection {
            return isSelected ? 0.92 : 0.72
        }
        return 0.82
    }

    private var strokeOpacity: Double {
        if isLocked { return 0.34 }
        if trailing == .selection {
            return isSelected ? 0.72 : 0.42
        }
        return 0.72
    }
}
