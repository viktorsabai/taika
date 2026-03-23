import SwiftUI

// MARK: - Game context header (unified with Speaker second header: icons + source title)

public struct GameContextHeader: Equatable {
    public var sourceTitle: String
    public var cardCount: Int
    public var attemptCount: Int
    public var avgScore: Int
    /// Game progress mode: show "X из Y пар" + timer instead of card/attempt icons.
    public var progressCurrent: Int?
    public var progressTotal: Int?
    public var progressLabel: String?
    public var elapsedSeconds: Int?

    public init(sourceTitle: String, cardCount: Int, attemptCount: Int, avgScore: Int = 0,
                progressCurrent: Int? = nil, progressTotal: Int? = nil, progressLabel: String? = nil, elapsedSeconds: Int? = nil) {
        self.sourceTitle = sourceTitle
        self.cardCount = cardCount
        self.attemptCount = attemptCount
        self.avgScore = avgScore
        self.progressCurrent = progressCurrent
        self.progressTotal = progressTotal
        self.progressLabel = progressLabel
        self.elapsedSeconds = elapsedSeconds
    }
}

/// Хедер игры: при progressCurrent/progressTotal и elapsedSeconds — прогресс «X из Y пар» + таймер + полоска; иначе заголовок курса/урока.
public struct GameContextHeaderView: View {
    public let header: GameContextHeader
    private let theme = ThemeManager.shared

    public init(header: GameContextHeader) {
        self.header = header
    }

    private var useProgressMode: Bool {
        header.progressTotal != nil && header.progressTotal! > 0
    }

    private var timerText: String {
        let s = header.elapsedSeconds ?? 0
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if useProgressMode, let cur = header.progressCurrent, let total = header.progressTotal {
                    Text("\(cur) из \(total) пар")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                    Text(timerText)
                        .font(.system(size: 14, weight: .medium).monospacedDigit())
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                }
                Spacer(minLength: 8)
                Text(header.sourceTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if useProgressMode, let cur = header.progressCurrent, let total = header.progressTotal, total > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(PD.ColorToken.textSecondary.opacity(0.2))
                            .frame(height: 4)
                        Capsule()
                            .fill(theme.currentAccentFill)
                            .frame(width: max(0, geo.size.width * CGFloat(cur) / CGFloat(total)), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .background(PD.ColorToken.background.ignoresSafeArea())
    }
}

// MARK: - Game Shell (shared layout for all home games)

public struct GameShell<Content: View>: View {

    // MARK: State

    public let content: Content
    public let onClose: () -> Void
    /// Унифицированный хедер приложения (логотип + прогресс + таймер в одном стиле с остальными экранами).
    public let gameHeaderConfig: GameHeaderConfig?
    /// Когда gameHeaderConfig == nil: второй хедер (название урока + иконки) для recall/builder.
    public let gameContextHeader: GameContextHeader?

    // MARK: Init

    public init(
        onClose: @escaping () -> Void,
        gameHeaderConfig: GameHeaderConfig? = nil,
        gameContextHeader: GameContextHeader? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onClose = onClose
        self.gameHeaderConfig = gameHeaderConfig
        self.gameContextHeader = gameContextHeader
        self.content = content()
    }

    // MARK: Body

    public var body: some View {
        ZStack {
            PD.ColorToken.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if let config = gameHeaderConfig {
                    AppHeader(style: .game(config))
                        .environmentObject(ThemeManager.shared)
                } else if let header = gameContextHeader {
                    GameContextHeaderView(header: header)
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
