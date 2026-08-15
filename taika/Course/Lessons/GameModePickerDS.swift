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
        contentBottomInset: CGFloat = 24
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
        VStack(spacing: 10) {
            ForEach(modes, id: \.self) { mode in
                modeRow(mode)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isModeLocked(mode) else {
                            onLockedTap(mode)
                            return
                        }
                        selected = mode
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onStart(mode)
                    }
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

    @ViewBuilder
    private func modeRow(_ mode: GameModeType) -> some View {
        let isLocked = isModeLocked(mode)
        HStack(spacing: 14) {

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(mode.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    if mode.isPro {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            .font(.system(size: 13))
                    }

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.white.opacity(0.7))
                            .font(.system(size: 13))
                    }
                }

                Text(isLocked ? lockedDescription(for: mode) : description(for: mode))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(isLocked ? 0.52 : 0.6))
            }

            Spacer()

            if !isLocked {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
        .opacity(isLocked ? 0.72 : 1)
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
