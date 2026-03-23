//
//  GameModePickerDS.swift
//  taika
//
//  Created by product on 15.02.2026.
//

//
//  GameModePickerDS.swift
//  taika
//

import SwiftUI

enum GameModeType: String, CaseIterable {
    case match
    case recall
    case context
    
    var title: String {
        switch self {
        case .match: return "Найди пару"
        case .recall: return "Быстрое повторение"
        case .context: return "Фразы в контексте"
        }
    }
    
    var isPro: Bool {
        switch self {
        case .match: return false
        case .recall, .context: return true
        }
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

struct GameModePickerDS: View {
    
    @Binding var selected: GameModeType
    var isProUser: Bool
    var onStart: (GameModeType) -> Void
    var onClose: () -> Void
    /// Когда false, рисуется только контент (список режимов + кнопка) для вставки в OverlayEtalonCard. Когда true — полный экран со своим фоном и карточкой (CourseView и т.д.).
    var embedInEtalon: Bool = true
    
    var body: some View {
        if embedInEtalon {
            fullPickerView
        } else {
            pickerContentOnly
        }
    }
    
    private var fullPickerView: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack {
                Spacer()

                VStack(spacing: 20) {

                    Text("Выбери режим")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    pickerBody
                }
                .padding(.top, 28)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
                .padding(.horizontal, 16)

                Spacer(minLength: 24)
            }
        }
    }
    
    /// Только контент для вставки в OverlayEtalonCard (без фона, без своей карточки, без заголовка «Выбери режим»).
    private var pickerContentOnly: some View {
        pickerBody
    }
    
    @ViewBuilder
    private var pickerBody: some View {
        VStack(spacing: 12) {
            ForEach(GameModeType.allCases, id: \.self) { mode in
                modeRow(mode)
                    .onTapGesture {
                        selected = mode
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
        }
        .padding(.horizontal, 20)

        Button {
            onStart(selected)
        } label: {
            Text("Начать")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(ThemeManager.shared.currentAccentFill)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private func modeRow(_ mode: GameModeType) -> some View {
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
                }

                Text(description(for: mode))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            if selected == mode {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(selected == mode ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    selected == mode
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        : AnyShapeStyle(Color.clear),
                    lineWidth: 2
                )
        )
    }

    private func description(for mode: GameModeType) -> String {
        switch mode {
        case .match:
            return "закрепление через поиск пар"
        case .recall:
            return "активное вспоминание в формате sprint"
        case .context:
            return "сборка фраз и живых диалогов"
        }
    }
}
