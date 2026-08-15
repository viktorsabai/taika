//
//  TaikaTabTipOverlayView.swift
//  taika
//
//  First-visit tip для Спикера / Курсов: black-glass в айдентике оверлеев,
//  не fullscreen Welcome-pager поверх таба.
//

import SwiftUI

struct TaikaTabTipOverlayView: View {
    enum Kind: Equatable {
        case speaker
        case course

        var title: String {
            switch self {
            case .speaker: return "Спикер"
            case .course: return "Курсы"
            }
        }

        var pages: [(icon: String, title: String, body: String)] {
            switch self {
            case .speaker:
                return [
                    ("mic.fill", "Голосом или текстом", "Скажи фразу по-русски — один pipeline."),
                    ("text.badge.checkmark", "Проверь, потом сохрани", "Превью → лента и словарь."),
                    ("waveform", "Сразу потренируй", "После перевода повтори вслух.")
                ]
            case .course:
                return [
                    ("graduationcap.fill", "База — фундамент", "Системный старт: привет, просьбы, цена."),
                    ("map.fill", "Сценарии — жизнь", "Переключай База / Сценарии сверху."),
                    ("arrow.triangle.2.circlepath", "Выученное → Спикер", "Отмечай фразы — вернёшься тренировать голос.")
                ]
            }
        }
    }

    let kind: Kind
    let onDismiss: () -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @State private var page = 0
    @State private var contentVisible = false

    private var pages: [(icon: String, title: String, body: String)] { kind.pages }
    private var isLast: Bool { page >= pages.count - 1 }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: finish)

            VStack(spacing: 0) {
                Spacer(minLength: Theme.Layout.rootHeaderClearance)

                VStack(alignment: .leading, spacing: 0) {
                    header

                    VStack(alignment: .leading, spacing: 14) {
                        pageBlock
                            .padding(.horizontal, CD.Spacing.screen)
                            .id(page)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))

                        HStack(spacing: 7) {
                            ForEach(0..<pages.count, id: \.self) { i in
                                Capsule(style: .continuous)
                                    .fill(
                                        i == page
                                        ? AnyShapeStyle(theme.currentAccentFill)
                                        : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.28))
                                    )
                                    .frame(width: i == page ? 16 : 7, height: 7)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)

                        VStack(spacing: 10) {
                            OverlayEtalonPrimaryButton(title: isLast ? "понял" : "дальше") {
                                advance()
                            }
                            OverlayEtalonSecondaryButton(title: "пропустить", action: finish)
                        }
                        .padding(.horizontal, CD.Spacing.screen)
                        .padding(.bottom, 18)
                        .padding(.top, 4)
                    }
                    .padding(.top, 4)
                }
                .taikaBlackGlassBackground(cornerRadius: 28)
                .frame(maxWidth: 420)
                .padding(.horizontal, 20)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 12)
                .scaleEffect(contentVisible ? 1 : 0.98)

                Spacer(minLength: ToolBar.recommendedBottomInset + 24)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                contentVisible = true
            }
        }
        .gesture(
            DragGesture(minimumDistance: 28)
                .onEnded { v in
                    if v.translation.width < -48 { advance() }
                    else if v.translation.width > 48, page > 0 {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) { page -= 1 }
                    }
                }
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(kind.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)
            Spacer(minLength: 8)
            Text("\(page + 1)/\(pages.count)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(CD.ColorToken.textSecondary)
            Button(action: finish) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(CD.ColorToken.chip.opacity(0.55)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var pageBlock: some View {
        let item = pages[page]
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.currentAccentFill)
                    .frame(width: 48, height: 48)
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(white: 0.12))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(CD.ColorToken.text)
                Text(item.body)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CD.ColorToken.chip.opacity(0.45))
        )
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if isLast {
            finish()
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                page += 1
            }
        }
    }

    private func finish() {
        switch kind {
        case .speaker: TaikaProductDemoFlags.markSpeakerSeen()
        case .course: TaikaProductDemoFlags.markCourseSeen()
        }
        onDismiss()
    }
}
