import SwiftUI

// MARK: - Game context (match / recall — правая колонка меты; пока игры сами пушат `GameHeaderStore`)

/// Мета курса/урока для игрового UI (резерв под второй ряд; хедер приложения берётся из `GameHeaderStore`).
public struct GameContextHeader: Equatable {
    public var sourceTitle: String
    public var cardCount: Int
    public var attemptCount: Int
    public var avgScore: Int
    public var progressCurrent: Int
    public var progressTotal: Int
    public var elapsedSeconds: Int

    public init(
        sourceTitle: String,
        cardCount: Int,
        attemptCount: Int,
        avgScore: Int,
        progressCurrent: Int = 0,
        progressTotal: Int = 0,
        elapsedSeconds: Int = 0
    ) {
        self.sourceTitle = sourceTitle
        self.cardCount = cardCount
        self.attemptCount = attemptCount
        self.avgScore = avgScore
        self.progressCurrent = progressCurrent
        self.progressTotal = progressTotal
        self.elapsedSeconds = elapsedSeconds
    }
}

// MARK: - Unified full-screen wrapper for HomeTask games

/// Оболочка полноэкранных игр: разворот контента; таймер/счёт/назад — через `GameHeaderStore` в `onAppear` у конкретного экрана.
struct GameShell<Content: View>: View {
    let onClose: () -> Void
    var gameHeaderConfig: GameHeaderConfig?
    var gameContextHeader: GameContextHeader?
    @ViewBuilder let content: () -> Content

    @Environment(\.taikaRootHeaderClearance) private var headerClearance

    private var topInset: CGFloat {
        headerClearance > 0 ? headerClearance + 4 : Theme.Layout.sectionTop
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()
            content()
                .padding(.top, topInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
