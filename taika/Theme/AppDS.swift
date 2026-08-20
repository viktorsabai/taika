//  AppDS.swift
//  taika
//
//  Created by product on 17.09.2025.
//


import SwiftUI
import UIKit

/// Shared semantic color for completed/mastery surfaces; accessible across design-system files.
public enum TaikaMasteryTokens {
    /// Solid companion for places that cannot render a gradient; use the darker gradient stop.
    public static let green = Color(red: 0x19 / 255.0, green: 0xCF / 255.0, blue: 0xA0 / 255.0)

    /// Exact completed/mastery accent: #36F5B0 → #19CFA0, left to right.
    /// Use only for completed/learned states; neutral and in-progress cards keep their own accent.
    public static let greenGradient = LinearGradient(
        colors: [
            Color(red: 0x36 / 255.0, green: 0xF5 / 255.0, blue: 0xB0 / 255.0),
            Color(red: 0x19 / 255.0, green: 0xCF / 255.0, blue: 0xA0 / 255.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    public static let greenGlow = Color(red: 0x36 / 255.0, green: 0xF5 / 255.0, blue: 0xB0 / 255.0)

    /// Same exact mastery accent for compact status badges.
    public static let greenBadgeGradient = LinearGradient(
        colors: [
            Color(red: 0x36 / 255.0, green: 0xF5 / 255.0, blue: 0xB0 / 255.0),
            Color(red: 0x19 / 255.0, green: 0xCF / 255.0, blue: 0xA0 / 255.0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Unified App Header Style
public enum AppHeaderStyle {
    /// Root header; tab 0=Main, 1=Course, 2=Speaker, 3=Favorites, 4=Profile. onBack: when set (e.g. Speaker from Favorites), show back button left of logo.
    case main(tab: Int, onBack: (() -> Void)?)
    /// Back + опционально название урока/таймер (Step) или wordmark. Segment-чипы живут в теле Step рядом с «Урок».
    case back(
        onBack: () -> Void,
        lessonTitle: String?,
        timerText: String?,
        showsWordmark: Bool
    )
    /// Экран списка уроков курса: иконки Спикер/Игры опциональны (теория-only курс).
    case lessons(onBack: () -> Void, onSpeaker: (() -> Void)?, onReinforce: (() -> Void)?, onReset: () -> Void, gameParkActive: Bool)
    case game(GameHeaderConfig)
}

public struct GameHeaderConfig {
    public var timeText: String
    public var score: Int
    public var mistakes: Int
    public var streak: Int
    /// Прогресс в человеческом виде: «3 из 8 пар».
    public var progressText: String?
    /// Короткое имя игры для blank brain: «Найди пару».
    public var gameTitle: String?
    /// Название урока/источника — вторая строка (опционально).
    public var sourceTitle: String?
    /// Ультра-минимальный ряд: назад + название (без счётчиков).
    public var minimalGameChrome: Bool
    public var onBack: () -> Void

    public init(
        timeText: String = "00:00",
        score: Int = 0,
        mistakes: Int = 0,
        streak: Int = 0,
        progressText: String? = nil,
        gameTitle: String? = nil,
        sourceTitle: String? = nil,
        minimalGameChrome: Bool = false,
        onBack: @escaping () -> Void = {}
    ) {
        self.timeText = timeText
        self.score = score
        self.mistakes = mistakes
        self.streak = streak
        self.progressText = progressText
        self.gameTitle = gameTitle
        self.sourceTitle = sourceTitle
        self.minimalGameChrome = minimalGameChrome
        self.onBack = onBack
    }
}

// UIKit-backed full-screen system blur with no extra tint and hardened against accessibility/system tints
struct SystemBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterial
    func makeUIView(context: Context) -> UIVisualEffectView {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: style))
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.isOpaque = false
        v.backgroundColor = .clear
        v.contentView.backgroundColor = .clear
        v.layer.allowsGroupOpacity = false
        v.isUserInteractionEnabled = false
        return v
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
        uiView.isOpaque = false
        uiView.backgroundColor = .clear
        uiView.contentView.backgroundColor = .clear
        uiView.layer.allowsGroupOpacity = false
    }
}

// MARK: - Unified Loading View (единый UI загрузок по всему приложению)
public struct TaikaLoadingView: View {
    public var label: String
    public var hint: String?
    public var compact: Bool

    @EnvironmentObject private var theme: ThemeManager

    public init(label: String, hint: String? = nil, compact: Bool = false) {
        self.label = label
        self.hint = hint
        self.compact = compact
    }

    public var body: some View {
        VStack(spacing: compact ? 8 : 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.currentAccentFill)
                .scaleEffect(compact ? 1.0 : 1.15)

            if !label.isEmpty {
                Text(label)
                    .font(.system(size: compact ? 14 : 16, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }

            if let h = hint, !h.isEmpty {
                Text(h)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity)
        .padding(compact ? 12 : 24)
    }
}

// MARK: - Global App Header (reusable across views)
public struct AppHeader: View {
    // Visibility toggles
    public var showSearch: Bool
    public var showHeart: Bool
    public var showProfile: Bool
    public var showPro: Bool

    // Actions
    public var onTapAccent: () -> Void
    public var onTapTheme: () -> Void
    public var onTapPro: () -> Void

    // State
    public var isPro: Bool

    // Legacy actions retained for call-site compatibility
    public var onTapSearch: () -> Void
    public var onTapHeart: () -> Void
    public var onTapProfile: () -> Void

    // Unified header style (EPIC 2: .main(tab:) for context slots)
    public var style: AppHeaderStyle = .main(tab: 0, onBack: nil)

    /// EPIC 2: optional actions for context slots (used when style is .main(tab:))
    public var onTapVoice: () -> Void
    public var onTapGamePark: () -> Void
    public var onTapCourseSearch: () -> Void
    public var onTapCourseFilters: () -> Void
    public var onTapPersonalCourseCreate: () -> Void
    public var onTapSpeakerFilters: () -> Void
    /// Спикер: режим + выбор курсов для сборки карточек (иконка в хедере).
    public var onTapSpeakerCourses: (() -> Void)? = nil
    public var speakerDailyAttemptsRemaining: Int
    /// When true, Game Park button looks active (accent); only false when user has no completed lessons.
    public var gameParkActive: Bool
    public var onTapFavoritesFilters: () -> Void
    public var favoritesTotalCount: Int
    /// Когда true, иконки спикера и геймпада во вкладке Избранное показываются активными (акцент).
    public var favoritesHasCards: Bool
    /// При тапе на радугу (Profile): открыть оверлей выбора акцента. Если nil — используется onTapAccent.
    public var onTapAccentPicker: (() -> Void)?

    /// Speaker tab (tab 2): mode toggle. «Закрепление курсов» | «Скажи сам».
    public var speakerUIMode: SpeakerManager.SpeakerUIMode? = nil
    public var onSpeakerUIModeChange: ((SpeakerManager.SpeakerUIMode) -> Void)? = nil
    /// Speaker tab: shuffle queue on/off. When non-nil, show По порядку | Вразброс switch.
    public var speakerShuffleOn: Bool? = nil
    public var onSpeakerShuffleChange: ((Bool) -> Void)? = nil
    /// Favorites tab (tab 3): open Speaker with favorites queue.
    public var onTapFavoritesSpeaker: (() -> Void)? = nil
    /// Favorites tab: open game park with favorites as card source.
    public var onTapFavoritesGamePark: (() -> Void)? = nil
    /// Favorites tab: search saved phrases (header magnifying glass).
    public var onTapFavoritesSearch: (() -> Void)? = nil
    /// Main / Speaker: открыть словарь (Избранное → Словарь или sheet умного спикера).
    public var onTapDictionary: (() -> Void)? = nil
    public var dictionaryCount: Int = 0

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject private var favoritesFilter = FavoritesFilterState.shared
    @ObservedObject private var favoriteManager = FavoriteManager.shared
    @ObservedObject private var lessonsHeaderStore = LessonsHeaderStore.shared

    public init(
        showSearch: Bool = true,
        showHeart: Bool = true,
        showProfile: Bool = true,
        showPro: Bool = true,
        onTapSearch: @escaping () -> Void = {},
        onTapHeart: @escaping () -> Void = {},
        onTapProfile: @escaping () -> Void = {},
        onTapPro: @escaping () -> Void = {},
        onTapVoice: @escaping () -> Void = {},
        onTapGamePark: @escaping () -> Void = {},
        onTapCourseSearch: @escaping () -> Void = {},
        onTapCourseFilters: @escaping () -> Void = {},
        onTapPersonalCourseCreate: @escaping () -> Void = {},
        onTapSpeakerFilters: @escaping () -> Void = {},
        onTapSpeakerCourses: (() -> Void)? = nil,
        speakerDailyAttemptsRemaining: Int = 0,
        gameParkActive: Bool = false,
        onTapFavoritesFilters: @escaping () -> Void = {},
        favoritesTotalCount: Int = 0,
        favoritesHasCards: Bool = false,
        onTapAccentPicker: (() -> Void)? = nil,
        isPro: Bool = false,
        style: AppHeaderStyle = .main(tab: 0, onBack: nil),
        speakerUIMode: SpeakerManager.SpeakerUIMode? = nil,
        onSpeakerUIModeChange: ((SpeakerManager.SpeakerUIMode) -> Void)? = nil,
        speakerShuffleOn: Bool? = nil,
        onSpeakerShuffleChange: ((Bool) -> Void)? = nil,
        onTapFavoritesSpeaker: (() -> Void)? = nil,
        onTapFavoritesGamePark: (() -> Void)? = nil,
        onTapFavoritesSearch: (() -> Void)? = nil,
        onTapDictionary: (() -> Void)? = nil,
        dictionaryCount: Int = 0
    ) {
        // legacy flags kept for call-site compatibility
        self.showSearch = showSearch
        self.showHeart = showHeart
        self.showProfile = showProfile

        // new contract
        self.showPro = showPro
        self.onTapAccent = onTapHeart
        self.onTapTheme = onTapProfile
        self.onTapPro = onTapPro
        self.isPro = isPro
        self.onTapVoice = onTapVoice
        self.onTapGamePark = onTapGamePark
        self.onTapCourseSearch = onTapCourseSearch
        self.onTapCourseFilters = onTapCourseFilters
        self.onTapPersonalCourseCreate = onTapPersonalCourseCreate
        self.onTapSpeakerFilters = onTapSpeakerFilters
        self.onTapSpeakerCourses = onTapSpeakerCourses
        self.speakerDailyAttemptsRemaining = speakerDailyAttemptsRemaining
        self.gameParkActive = gameParkActive
        self.onTapFavoritesFilters = onTapFavoritesFilters
        self.favoritesTotalCount = favoritesTotalCount
        self.favoritesHasCards = favoritesHasCards
        self.onTapAccentPicker = onTapAccentPicker
        self.style = style
        self.speakerUIMode = speakerUIMode
        self.onSpeakerUIModeChange = onSpeakerUIModeChange
        self.speakerShuffleOn = speakerShuffleOn
        self.onSpeakerShuffleChange = onSpeakerShuffleChange
        self.onTapFavoritesSpeaker = onTapFavoritesSpeaker
        self.onTapFavoritesGamePark = onTapFavoritesGamePark
        self.onTapFavoritesSearch = onTapFavoritesSearch
        self.onTapDictionary = onTapDictionary
        self.dictionaryCount = dictionaryCount

        // legacy actions retained but unused
        self.onTapSearch = onTapSearch
        self.onTapHeart = onTapHeart
        self.onTapProfile = onTapProfile
    }

    // MARK: Logo (taik + A with gradient)
    private var logo: some View {
        rootHeaderLogo(size: 36)
    }

    private func rootHeaderLogo(size: CGFloat) -> some View {
        HStack(spacing: size > 32 ? 6 : 4) {
            Text("tai")
                .font(.custom("Onmark Trial", size: size))
                .foregroundColor(CD.ColorToken.text)
            Text("kAAA")
                .font(.custom("Onmark Trial", size: size))
                .foregroundStyle(lessonsHeaderStore.isCompletedCourse ? AnyShapeStyle(TaikaMasteryTokens.greenGlow) : AnyShapeStyle(theme.currentAccentFill))
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("taikAAA")
    }

    /// Компактный логотип для минимального игрового хедера (не конкурирует с контентом).
    private var gameHeaderMinimalLogo: some View {
        HStack(spacing: 3) {
            Text("tai")
                .font(.custom("Onmark Trial", size: 22))
                .foregroundColor(CD.ColorToken.text.opacity(0.42))
            Text("kAAA")
                .font(.custom("Onmark Trial", size: 22))
                .foregroundStyle(theme.currentAccentFill.opacity(0.5))
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("taikAAA")
    }

    private var headerMinHeight: CGFloat {
        if case .game(let c) = style, c.minimalGameChrome { return 44 }
        return 56
    }

    private enum HeaderControlMetrics {
        static let clusterSpacing: CGFloat = 8
        static let rowSpacing: CGFloat = 12
        static let glassSize: CGFloat = 38
        static let hitSize: CGFloat = 44
    }

    private var headerIconForeground: AnyShapeStyle {
        AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.92))
    }

    private func headerIconForeground(accent: Bool) -> AnyShapeStyle {
        if lessonsHeaderStore.isCompletedCourse {
            return AnyShapeStyle(TaikaMasteryTokens.greenGlow.opacity(accent ? 1.0 : 0.86))
        }
        return accent ? AnyShapeStyle(theme.currentAccentFill) : headerIconForeground
    }

    // MARK: Header controls — glass orbs + единый hit target (все вкладки / push)

    @ViewBuilder
    private func headerIcon(_ system: String, isAccent: Bool = false) -> some View {
        TaikaHeaderGlassButton(size: HeaderControlMetrics.glassSize) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(headerIconForeground(accent: isAccent))
        }
        .frame(width: HeaderControlMetrics.hitSize, height: HeaderControlMetrics.hitSize)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func headerCounterBadge(icon: String, text: String, active: Bool) -> some View {
        TaikaHeaderGlassPill(height: HeaderControlMetrics.glassSize) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(headerIconForeground(accent: active))
        }
        .frame(minWidth: HeaderControlMetrics.hitSize, minHeight: HeaderControlMetrics.hitSize)
        .contentShape(Rectangle())
    }

    private func headerBackButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TaikaHeaderGlassButton(size: HeaderControlMetrics.glassSize) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
            }
            .frame(width: HeaderControlMetrics.hitSize, height: HeaderControlMetrics.hitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(TaikaHeaderButtonStyle())
    }

    private func headerIconButton(
        _ system: String,
        isAccent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            headerIcon(system, isAccent: isAccent)
        }
        .buttonStyle(TaikaHeaderButtonStyle())
    }

    @ViewBuilder
    private func headerTrailingCluster<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: HeaderControlMetrics.clusterSpacing) {
            content()
        }
    }

    /// Иконка умного спикера: профиль + волны (как voice в main).
    @ViewBuilder
    private func speakerSmartIconButton(onTap: @escaping () -> Void) -> some View {
        headerIconButton("person.wave.2.fill", action: onTap)
    }

    @ViewBuilder
    private func speakerMicIconButton(onTap: @escaping () -> Void) -> some View {
        headerIconButton("mic.fill", action: onTap)
    }

    /// Режим микрофон: иконка микрофона + счётчик (стандартный спикер).
    private var speakerAttemptsBadge: some View {
        let active = isPro || speakerDailyAttemptsRemaining > 0
        return headerCounterBadge(
            icon: "mic.fill",
            text: isPro ? "∞" : "\(speakerDailyAttemptsRemaining)",
            active: active
        )
    }

    /// Режим умный спикер: счётчик вместо микрофона.
    private var speakerSmartCounterBadge: some View {
        let active = isPro || speakerDailyAttemptsRemaining > 0
        return headerCounterBadge(
            icon: "person.wave.2.fill",
            text: isPro ? "∞" : "\(speakerDailyAttemptsRemaining)",
            active: active
        )
    }

    /// Favorites tab: heart + total likes count
    private var favoritesCountBadge: some View {
        headerCounterBadge(
            icon: "heart.fill",
            text: "\(favoritesTotalCount)",
            active: favoritesTotalCount > 0
        )
    }

    /// Личный словарь: bookmark glyph (+ счётчик).
    @ViewBuilder
    private func dictionaryHeaderButton(
        count: Int,
        isAccent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if count > 0 {
                headerCounterBadge(
                    icon: "bookmark.fill",
                    text: "\(count)",
                    active: isAccent || count > 0
                )
            } else {
                headerIcon("bookmark", isAccent: isAccent)
            }
        }
        .buttonStyle(TaikaHeaderButtonStyle())
        .accessibilityLabel(count > 0 ? "Словарь, \(count) фраз" : "Словарь")
    }

    /// Step header: иконка + счётчик в стиле хедера.
    private func stepSegmentIconBadge(icon: String, count: Int, isSelected: Bool) -> some View {
        TaikaHeaderGlassPill(height: HeaderControlMetrics.glassSize) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(headerIconForeground(accent: isSelected))
        }
        .frame(minWidth: HeaderControlMetrics.hitSize, minHeight: HeaderControlMetrics.hitSize)
        .contentShape(Rectangle())
    }

    // MARK: Game HUD Pill
    private func hudPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.currentAccentFill)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(CD.ColorToken.text)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.82))
        )
    }

    /// Компактные чипы HUD: без fixedSize, чтобы ряд не вылезал за экран.
    private func gameHeaderBadge(icon: String, text: String) -> some View {
        TaikaHeaderGlassPill(height: HeaderControlMetrics.glassSize) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(CD.ColorToken.text)
            }
        }
        .frame(minHeight: HeaderControlMetrics.hitSize)
        .contentShape(Rectangle())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: HeaderControlMetrics.rowSpacing) {

            switch style {

            case .main(let tab, let onBack):
                // Back (если пришли со стороны) + логотип всегда — иначе хедер «пустой».
                if let onBack = onBack {
                    headerBackButton(action: onBack)
                }
                logo

                Spacer(minLength: 0)

                headerTrailingCluster {
                    switch tab {
                    case 0:
                        // TF: «Голос Таики» скрыт (stub «Скоро»).
                        headerIconButton("gamecontroller.fill", isAccent: gameParkActive, action: onTapGamePark)
                        if let onDict = onTapDictionary {
                            dictionaryHeaderButton(count: dictionaryCount, action: onDict)
                        }
                    case 1:
                        // MVP: создание курса скрыто (как «Голос Таики» — позже).
                        headerIconButton("magnifyingglass", action: onTapCourseSearch)
                    case 2:
                        if let onDict = onTapDictionary {
                            dictionaryHeaderButton(count: dictionaryCount, action: onDict)
                        }
                        // Mic + N: счётчик попыток; тап → выбор курсов (сборка очереди).
                        if speakerUIMode == .conversation {
                            Button(action: onTapSpeakerFilters) {
                                speakerSmartCounterBadge
                            }
                            .buttonStyle(TaikaHeaderButtonStyle())
                            .accessibilityLabel("Попытки сегодня")
                        } else {
                            Button(action: onTapSpeakerFilters) {
                                speakerAttemptsBadge
                            }
                            .buttonStyle(TaikaHeaderButtonStyle())
                            .accessibilityLabel("Выбрать курсы, попыток \(speakerDailyAttemptsRemaining)")
                        }
                    case 3:
                        // Favorites: личный словарь — отдельная utility entry point, не фильтр.
                        if let onDict = onTapDictionary {
                            dictionaryHeaderButton(count: dictionaryCount, action: onDict)
                        }
                        if let onSearch = onTapFavoritesSearch {
                            headerIconButton("magnifyingglass", action: onSearch)
                        }
                    case 4:
                        // MVP: тема и цвет акцента скрыты до пост-MVP.
                        EmptyView()
                    default:
                        EmptyView()
                    }
                    if showPro {
                        let proGlyph = isPro ? "crown.fill" : "crown"
                        headerIconButton(proGlyph, isAccent: isPro, action: onTapPro)
                    }
                }

            case .back(let onBack, let lessonTitle, let timerText, let showsWordmark):
                headerBackButton(action: onBack)

                if let title = lessonTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 2)

                    if let timerText, !timerText.isEmpty {
                        Text(timerText)
                            .font(.system(size: 16, weight: .semibold).monospacedDigit())
                            .foregroundStyle(CD.ColorToken.text)
                            .lineLimit(1)
                            .accessibilityLabel("Время \(timerText)")
                    }
                } else {
                    Spacer(minLength: 0)
                    if showsWordmark {
                        logo
                    }
                }

            case .lessons(_, let onSpeaker, let onReinforce, _, let gameParkActive):
                logo

                Spacer(minLength: 0)

                headerTrailingCluster {
                    if let onSpeaker {
                        headerIconButton("mic.fill", action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSpeaker()
                        })
                        .accessibilityLabel("Спикер")
                    }
                    if let onReinforce {
                        headerIconButton("gamecontroller.fill", isAccent: gameParkActive, action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onReinforce()
                        })
                        .accessibilityLabel("Игры")
                    }
                    if showPro {
                        let proGlyph = isPro ? "crown.fill" : "crown"
                        headerIconButton(proGlyph, isAccent: isPro, action: onTapPro)
                    }
                }

            case .game(let config):
                // Blank-brain: назад + название + читаемые цифры. Без стеклянных чипов (обрезались).
                headerBackButton(action: config.onBack)

                VStack(alignment: .leading, spacing: 2) {
                    Text(gameHeaderPrimaryTitle(config))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .truncationMode(.tail)

                    if !config.minimalGameChrome {
                        Text(gameHeaderStatusLine(config))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .monospacedDigit()
                    } else if let st = config.sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !st.isEmpty {
                        Text(st)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 2)

                // Таймер в хедере — тот же нейтральный цвет, что чип timer (не отдельный «розовый»).
                if !config.minimalGameChrome, !config.timeText.isEmpty {
                    Text(config.timeText)
                        .font(.system(size: 16, weight: .semibold).monospacedDigit())
                        .foregroundStyle(CD.ColorToken.text)
                        .lineLimit(1)
                        .accessibilityLabel("Время \(config.timeText)")
                }
            }
            }
            .frame(maxWidth: .infinity)

            // Вторая строка source больше не нужна — всё в блоке слева.
        }
        .padding(.horizontal, CD.Spacing.screen)
        .frame(maxWidth: .infinity, minHeight: headerMinHeight, alignment: .leading)
        // Continuous canvas: the header is a translucent field that fades into the body,
        // never a separate opaque strip with a visible horizontal seam.
        .background {
            TaikaLiquidGlassHeaderBackdrop()
        }
    }

    private func gameHeaderPrimaryTitle(_ config: GameHeaderConfig) -> String {
        if let t = config.gameTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        if config.minimalGameChrome,
           let st = config.sourceTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !st.isEmpty {
            return st
        }
        if let p = config.progressText?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            return p
        }
        return "Игра"
    }

    private func gameHeaderStatusLine(_ config: GameHeaderConfig) -> String {
        // Без названия курса/урока в статусе — длинные chip'ы обрезались и были нечитаемы.
        var parts: [String] = []
        if let p = config.progressText?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            parts.append(p)
        }
        if config.mistakes > 0 {
            let n = config.mistakes
            let word: String = {
                let m10 = n % 10
                let m100 = n % 100
                if m10 == 1, m100 != 11 { return "ошибка" }
                if (2...4).contains(m10), !(12...14).contains(m100) { return "ошибки" }
                return "ошибок"
            }()
            parts.append("\(n) \(word)")
        } else if config.score > 0, config.progressText == nil {
            parts.append("счёт \(config.score)")
        }
        return parts.isEmpty ? " " : parts.joined(separator: " · ")
    }

}

// Visual variants for AppBackHeader
public enum AppBackHeaderVariant { case solid, transparent }

// MARK: - Back Header (logo right, back button left)
public struct AppBackHeader: View {
    public var onTapBack: () -> Void
    public var variant: AppBackHeaderVariant

    public init(onTapBack: @escaping () -> Void = {}, variant: AppBackHeaderVariant = .solid) {
        self.onTapBack = onTapBack
        self.variant = variant
    }

    private var logo: some View {
        HStack(spacing: 6) {
            Text("tai")
                .font(.custom("Onmark Trial", size: 36))
                .foregroundColor(CD.ColorToken.text)
            Text("kAAA")
                .font(.custom("Onmark Trial", size: 36))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
        }
        .accessibilityLabel("taikAAA")
        .fixedSize(horizontal: true, vertical: false)
    }

    public var body: some View {
        ZStack {
            logo
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onTapBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CD.Spacing.screen)
        .frame(height: 56)
        .background(
            Theme.Colors.backgroundPrimary
                .ignoresSafeArea(edges: .top)
        )
    }
}
// MARK: - Game Header (console mode, aligned with App identity)

public struct AppGameHeader: View {

    public var timeText: String
    public var score: Int
    public var mistakes: Int
    public var streak: Int
    public var onBack: () -> Void

    public init(
        timeText: String = "00:00",
        score: Int = 0,
        mistakes: Int = 0,
        streak: Int = 0,
        onBack: @escaping () -> Void = {}
    ) {
        self.timeText = timeText
        self.score = score
        self.mistakes = mistakes
        self.streak = streak
        self.onBack = onBack
    }

    private var logo: some View {
        HStack(spacing: 6) {
            Text("tai")
                .font(.custom("Onmark Trial", size: 36))
                .foregroundColor(CD.ColorToken.text)
            Text("kAAA")
                .font(.custom("Onmark Trial", size: 36))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
        }
        .accessibilityLabel("taikAAA")
        .fixedSize(horizontal: true, vertical: false)
    }

    private func hudPill(icon: String, text: String, tint: some ShapeStyle) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(CD.ColorToken.text)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            Capsule(style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.82))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
    }

    public var body: some View {
        HStack(spacing: 14) {

            // Back button (same visual language as AppBackHeader)
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            logo

            Spacer(minLength: 0)

            HStack(spacing: 8) {

                hudPill(
                    icon: "timer",
                    text: timeText,
                    tint: ThemeManager.shared.currentAccentFill
                )

                hudPill(
                    icon: "checkmark",
                    text: "\(score)",
                    tint: Color.green.opacity(0.9)
                )

                hudPill(
                    icon: "xmark",
                    text: "\(mistakes)",
                    tint: Color.red.opacity(0.9)
                )

                if streak > 1 {
                    hudPill(
                        icon: "flame.fill",
                        text: "x\(streak)",
                        tint: ThemeManager.shared.currentAccentFill
                    )
                }
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
        .frame(height: 56)
        .background(
            ZStack {
                SystemBlur(style: .systemChromeMaterial)
                Theme.Colors.backgroundPrimary
                    .opacity(0.72)
            }
            .saturation(1.15)
            .contrast(1.02)
        )
        .ignoresSafeArea(edges: .top)
    }
}
// MARK: - Summary CTA style enum

public enum SummaryCTAStyle { case brandChips }

/// Уровень итогового оверлея: урок / весь курс / конец каталога.
public enum LessonSummaryKind {
    case lesson
    case course
    case catalogEnd
}

// MARK: - Shared CTA buttons (reusable across screens)
// Preset semantic types for CTA labels
public enum AppCTAType { case start, resume, reinforce, next }

public enum AppCTAScale { case xs, s }

public enum AppCTAVisual { case brandStatus, brandDark, brandOutline, brandSolid }

// MARK: - Status Chip enum
public enum AppStatusKind { case new, inProgress, completed }
public enum AppStatusScale { case xs, s }

// Unified chip metrics for status + PRO chips (single visual baseline)
private enum AppChipMetrics {
    static let xsHeight: CGFloat = 34       // baseline height used by PRO chip (matches XS CTA height)
    static let sHeight: CGFloat = 28
    static let corner: CGFloat = 13         // visual corner thickness for capsule silhouette
    static let hPadXS: CGFloat = 12
    static let hPadS: CGFloat = 14
}

// MARK: - Status Chip Component
public struct AppStatusChip: View {
    public var kind: AppStatusKind
    public var scale: AppStatusScale = .xs
    public var title: String? = nil

    public init(kind: AppStatusKind, scale: AppStatusScale = .xs, title: String? = nil) {
        self.kind = kind
        self.scale = scale
        self.title = title
    }

    // compact jira-like palette per status
    private struct StatusColors {
        let fill: AnyShapeStyle
        let stroke: AnyShapeStyle
        let text: AnyShapeStyle
    }

    private func colors(for kind: AppStatusKind) -> StatusColors {
        // MVP: statuses must be distinguishable, but still in Taika identity (accent-driven).
        switch kind {
        case .new:
            return StatusColors(
                fill: AnyShapeStyle(Color.white.opacity(0.04)),
                stroke: AnyShapeStyle(Theme.Strokes.strokeSubtle.opacity(2.0)),
                text: AnyShapeStyle(Theme.Colors.textPrimary.opacity(0.90))
            )
        case .inProgress:
            return StatusColors(
                fill: AnyShapeStyle(Color.clear),
                stroke: AnyShapeStyle(ThemeManager.shared.currentAccentFill),
                text: AnyShapeStyle(ThemeManager.shared.currentAccentFill)
            )
        case .completed:
            let learnedGreen = Color(red: 0.25, green: 0.78, blue: 0.48)
            return StatusColors(
                fill: AnyShapeStyle(Color.black.opacity(0.34)),
                stroke: AnyShapeStyle(learnedGreen.opacity(0.72)),
                text: AnyShapeStyle(learnedGreen.opacity(0.96))
            )
        }
    }

    private var height: CGFloat {
        switch scale {
        case .xs: return 18
        case .s:  return 20
        }
    }

    private var hPad: CGFloat {
        switch scale {
        case .xs: return 8
        case .s:  return 10
        }
    }

    private var labelText: String {
        if let t = title, !t.isEmpty {
            return t
        }
        switch kind {
        case .new:        return "новый"
        case .inProgress: return "в процессе"
        case .completed:  return "пройден"
        }
    }

    public var body: some View {
        let c = colors(for: kind)
        HStack(spacing: kind == .completed ? 4 : 0) {
            if kind == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: scale == .xs ? 9 : 10, weight: .bold))
            }
            Text(labelText)
        }
        .font(.system(size: scale == .xs ? 11 : 12, weight: .semibold))
        .foregroundStyle(c.text)
        .padding(.horizontal, hPad)
        .frame(height: height)
            .background(Capsule(style: .continuous).fill(c.fill))
            .overlay(Capsule(style: .continuous).strokeBorder(c.stroke, lineWidth: 1))
    }
}


// MARK: - Mini Chip Component (for actions like "Запомнил" / "Слово")
public enum AppMiniChipStyle { case accent, neutral }

public struct AppMiniChip: View {
    public var title: String
    public var style: AppMiniChipStyle = .neutral
    public var onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    public init(title: String, style: AppMiniChipStyle = .neutral, onTap: @escaping () -> Void = {}) {
        self.title = title
        self.style = style
        self.onTap = onTap
    }

    private var displayTitle: String {
        let s = title
        guard let f = s.first else { return s }
        return String(f).uppercased() + s.dropFirst()
    }

    public var body: some View {
        let height: CGFloat = 28
        let isLight = colorScheme == .light

        Button(action: onTap) {
            Text(displayTitle)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(
                    style == .accent ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                     : AnyShapeStyle(CD.ColorToken.text.opacity(0.95))
                )
                .padding(.horizontal, 10)
                .frame(height: height)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            style == .accent
                            ? AnyShapeStyle(TaikaDynamicColors.accent.opacity(isLight ? 0.16 : 0.20))
                            : AnyShapeStyle(TaikaDynamicColors.chip)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            style == .accent
                            ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                            : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                            lineWidth: style == .accent ? 1.35 : 1.2
                        )
                )
                .shadow(
                    color: style == .accent && isLight ? Color.black.opacity(0.07) : .clear,
                    radius: 3,
                    x: 0,
                    y: 1
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
    }
}

// MARK: - PRO Chip (brand identity) — как на Main «подборка дня»
public struct AppProChip: View {
    public var title: String = "Taika+"
    public var scale: CGFloat = 1.0
    public var showCrown: Bool = true
    /// Locked gate (free user): замок вместо короны.
    public var locked: Bool = false

    public init(
        title: String = "Taika+",
        scale: CGFloat = 1.0,
        showCrown: Bool = true,
        locked: Bool = false
    ) {
        self.title = title
        self.scale = scale
        self.showCrown = showCrown
        self.locked = locked
    }

    public var body: some View {
        let accent = ThemeManager.shared.currentAccentFill
        let iconSize: CGFloat = 9.5 * scale
        let fontSize: CGFloat = 11 * scale
        let vPad: CGFloat = 4.5 * scale
        let hPad: CGFloat = 8 * scale

        HStack(spacing: 4 * scale) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: iconSize, weight: .semibold))
            } else if showCrown {
                Image(systemName: "crown.fill")
                    .font(.system(size: iconSize, weight: .semibold))
            }
            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(accent)
        .padding(.vertical, vPad)
        .padding(.horizontal, hPad)
        .background(
            Capsule(style: .continuous)
                .fill(Color.clear)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(accent, lineWidth: 1.15)
        )
        .accessibilityLabel(locked ? "\(title), закрыто" : title)
    }
}

// MARK: - Console Buttons (nav + actions) — same family as AppCardIconButton
public enum AppConsoleNavKind { case prev, next, minus, plus }
public enum AppConsoleActKind { case play, modes, chat, info }

public enum AppConsoleState { case idle, pressed, active, disabled }

public struct AppConsoleIconButton: View {
    public var nav: AppConsoleNavKind? = nil
    public var act: AppConsoleActKind? = nil
    public var isEnabled: Bool = true
    public var isActive: Bool = false
    public var state: AppConsoleState = .idle
    public var onTap: () -> Void

    public init(nav: AppConsoleNavKind,
                state: AppConsoleState = .idle,
                isEnabled: Bool = true,
                onTap: @escaping () -> Void = {}) {
        self.nav = nav
        self.state = state
        self.isEnabled = isEnabled
        self.onTap = onTap
    }
    public init(act: AppConsoleActKind,
                state: AppConsoleState = .idle,
                isEnabled: Bool = true,
                isActive: Bool = false,
                onTap: @escaping () -> Void = {}) {
        self.act = act
        self.state = state
        self.isEnabled = isEnabled
        self.isActive = isActive
        self.onTap = onTap
    }

    @EnvironmentObject var theme: ThemeManager
    private let size: CGFloat = 34
    private let iconSize: CGFloat = 13

    private var iconName: String {
        if let n = nav {
            switch n {
            case .prev:  return "chevron.left"
            case .next:  return "chevron.right"
            case .minus: return "minus"
            case .plus:  return "plus"
            }
        }
        if let a = act {
            switch a {
            case .play:  return "play.fill"
            case .modes: return "square.grid.2x2"
            case .chat:  return "bubble.left.and.bubble.right.fill"
            case .info:  return "questionmark"
            }
        }
        return "circle"
    }

    public var body: some View {
        let isAction = act != nil
        let isDisabled = (state == .disabled) || !isEnabled
        let isPressedStatic = (state == .pressed) // static preview of pressed
        let isActiveStatic = (state == .active) || isActive
        let isSubtleInfo = (act == .info)
        let showGradient = isAction && !isDisabled && !isSubtleInfo
        let iconOpacity: Double = isDisabled ? 0.45 : (isPressedStatic ? 1.0 : 0.90)
        let iconInk: some ShapeStyle = showGradient
            ? AnyShapeStyle(Color.black.opacity(0.90))
            : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(iconOpacity))

        let accentInk: some ShapeStyle = AnyShapeStyle(theme.currentAccentFill)
        let idleInk: some ShapeStyle = AnyShapeStyle(CD.ColorToken.textSecondary.opacity(isDisabled ? 0.5 : 0.92))
        Button(action: onTap) {
            Image(systemName: iconName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(showGradient ? accentInk : idleInk)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle(scale: 0.94, fade: 0.96))
        .disabled(isDisabled)
    }
}
// MARK: - Card Icon Buttons (like / console) — compact, unified
public enum AppIconActionKind { case favorite, console, play, info, speaker, listen }

private struct FavoriteSymbolBounceModifier: ViewModifier {
    let kind: AppIconActionKind
    let isOn: Bool

    func body(content: Content) -> some View {
        Group {
            if kind == .favorite {
                content.symbolEffect(.bounce, value: isOn)
            } else {
                content
            }
        }
    }
}

public struct AppCardIconButton: View {
    public var kind: AppIconActionKind
    public var isActive: Bool = false   // for .favorite (filled heart). Ignored for .console
    public var isEnabled: Bool = true   // when false, shows locked/disabled visual
    /// Для .play — всегда показывать акцентом (главная CTA «запустить урок»).
    public var forceAccent: Bool = false
    /// Нейтральная glossy-black action surface для Speaker/Game actions.
    public var glossyBlackSurface: Bool = false
    /// Completed course actions use mastery green without the global pink accent.
    public var forceMasteryGreen: Bool = false
    /// Если задан — тап по заблокированной иконке не молчит (shake + callback).
    public var onLockedTap: (() -> Void)? = nil
    public var onTap: () -> Void
    @State private var tapPulse: CGFloat = 1
    @State private var lockShake: CGFloat = 0

    public init(kind: AppIconActionKind,
                isActive: Bool = false,
                isEnabled: Bool = true,
                forceAccent: Bool = false,
                glossyBlackSurface: Bool = false,
                forceMasteryGreen: Bool = false,
                onLockedTap: (() -> Void)? = nil,
                onTap: @escaping () -> Void = {}) {
        self.kind = kind
        self.isActive = isActive
        self.isEnabled = isEnabled
        self.forceAccent = forceAccent
        self.glossyBlackSurface = glossyBlackSurface
        self.forceMasteryGreen = forceMasteryGreen
        self.onLockedTap = onLockedTap
        self.onTap = onTap
    }

    // Только иконка: активное = акцент; крупнее + отскок при нажатии (EPIC 5 UI приколы)
    private let iconSize: CGFloat = Theme.IconButton.iconSizeCard
    private let minTapSize: CGFloat = Theme.IconButton.tapMinCard

    private var isOn: Bool { kind == .favorite && isActive }
    private var isAccent: Bool {
        forceAccent
            || isOn
            || (kind == .console && isEnabled)
            || (kind == .speaker && isEnabled)
            || (kind == .listen && isEnabled)
    }
    private var allowsLockedTap: Bool { !isEnabled && onLockedTap != nil }

    private var iconName: String {
        switch kind {
        case .favorite: return isOn ? "heart.fill" : "heart"
        case .console:  return isAccent ? "gamecontroller.fill" : "gamecontroller"
        case .play:     return "play.fill"
        case .info:     return "info.circle"
        case .speaker:  return "mic.fill"
        case .listen:   return "speaker.wave.2.fill"
        }
    }

    public var body: some View {
        Button(action: handleTap) {
            iconLabel
        }
        .buttonStyle(PressDownStyle(scale: 0.90, fade: 0.94, useBouncySpring: true, flashOpacity: 0.12))
        .disabled(!isEnabled && !allowsLockedTap)
        .opacity(isEnabled || allowsLockedTap ? 1 : 0.55)
        .accessibilityLabel(accessibilityLabelForKind)
        .accessibilityHint(allowsLockedTap ? "Доступно после первого урока" : "")
    }

    private var iconLabel: some View {
        let scale: CGFloat = (kind == .favorite && isOn ? 1.06 : 1.0) * tapPulse
        let shakeX: CGFloat = lockShake == 0 ? 0 : (lockShake > 0.5 ? 5 : -5)

        return Image(systemName: iconName)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(iconInkStyle)
            .modifier(FavoriteSymbolBounceModifier(kind: kind, isOn: isOn))
            .scaleEffect(scale)
            .offset(x: shakeX)
            .animation(
                lockShake == 0
                ? .spring(response: 0.28, dampingFraction: 0.7)
                : .easeInOut(duration: 0.06).repeatCount(4, autoreverses: true),
                value: lockShake
            )
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isOn)
            .frame(
                width: glossyBlackSurface ? 34 : minTapSize,
                height: glossyBlackSurface ? 34 : minTapSize
            )
            .background {
                if glossyBlackSurface {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.black.opacity(0.72))
                        .overlay(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear, Color.black.opacity(0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                        )
                }
            }
            .frame(minWidth: minTapSize, minHeight: minTapSize)
            .contentShape(Rectangle())
    }

    private var iconInkStyle: AnyShapeStyle {
        if forceMasteryGreen, isEnabled {
            return AnyShapeStyle(TaikaMasteryTokens.green)
        }
        if glossyBlackSurface, isEnabled {
            return AnyShapeStyle(TaikaMasteryTokens.green)
        }
        if isAccent {
            return AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        }
        return AnyShapeStyle(CD.ColorToken.textSecondary.opacity(isEnabled ? 0.92 : 0.55))
    }

    private func handleTap() {
        if !isEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.12, dampingFraction: 0.28)) {
                lockShake = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    lockShake = 0
                }
            }
            onLockedTap?()
            return
        }
        if kind == .favorite || kind == .listen {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.58)) {
                tapPulse = 1.08
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    tapPulse = 1.0
                }
            }
        }
        onTap()
    }

    private var accessibilityLabelForKind: String {
        switch kind {
        case .favorite: return isActive ? "В избранном" : "Добавить в избранное"
        case .console:  return isEnabled ? "Домашка" : "Домашка недоступна"
        case .play:     return "Запустить урок"
        case .info:     return "Подробнее"
        case .speaker:  return "Потренировать произношение"
        case .listen:   return "Прослушать"
        }
    }
}

// MARK: - AppCardIconButton (end)

// MARK: - Lesson Favorite Counter — минимальный вариант (только сердечко + число, без капсулы)
public struct AppFavCounterMinimal: View {
    public var count: Int
    public var isEnabled: Bool = true
    public var onTap: () -> Void

    public init(count: Int, isEnabled: Bool = true, onTap: @escaping () -> Void = {}) {
        self.count = count
        self.isEnabled = isEnabled
        self.onTap = onTap
    }

    private let iconSize: CGFloat = Theme.IconButton.iconSizeCard
    private let minTapSize: CGFloat = Theme.IconButton.tapMinCard

    public var body: some View {
        let hasAny = count > 0
        let accent = AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: hasAny ? "heart.fill" : "heart")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(hasAny ? accent : accent)
                    .opacity(hasAny ? 1 : 0.85)
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hasAny ? accent : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.92)))
                    .monospacedDigit()
            }
            .frame(minWidth: minTapSize, minHeight: minTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle(scale: 0.88, fade: 0.92, useBouncySpring: true, flashOpacity: 0.16))
        .disabled(!isEnabled)
        .accessibilityLabel("В избранном: \(count)")
    }
}

// MARK: - Lesson Favorite Counter (capsule with heart + count)
public struct AppFavCounterButton: View {
    public var count: Int
    public var isEnabled: Bool = true
    public var onTap: () -> Void

    public init(count: Int, isEnabled: Bool = true, onTap: @escaping () -> Void = {}) {
        self.count = count
        self.isEnabled = isEnabled
        self.onTap = onTap
    }

    // Unified metrics to match card icon height
    private let height: CGFloat = 34

    public var body: some View {
        let hasAny = count > 0
        let idleFill = CD.ColorToken.card.opacity(0.82)

        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: hasAny ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hasAny ? AnyShapeStyle(Color.black.opacity(0.90))
                                             : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.92)))
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hasAny ? AnyShapeStyle(Color.black.opacity(0.92))
                                             : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.92)))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(
                ZStack {
                    if hasAny {
                        ThemeManager.shared.currentAccentFill
                            .blur(radius: 2.5)
                            .opacity(0.5)
                            .mask(Capsule(style: .continuous))
                        Capsule(style: .continuous)
                            .fill(ThemeManager.shared.currentAccentFill)
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.plusLighter)
                    } else {
                        ZStack {
                            Capsule(style: .continuous)
                                .fill(idleFill)
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.06), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blendMode(.plusLighter)
                        }
                    }
                }
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
        .disabled(!isEnabled)
        .accessibilityLabel("В избранном: \(count)")
    }
}

// Reusable press feedback for icon buttons (лёгкий «отскок» — не плоский отклик)
public struct PressDownStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var fade: CGFloat = 0.98
    /// Более выраженный отскок для карточных иконок (dampingFraction ниже = заметнее).
    var useBouncySpring: Bool = false
    /// Короткая accent-вспышка при нажатии (например 0.16–0.2).
    var flashOpacity: CGFloat? = nil
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? fade : 1)
            .overlay(
                Group {
                    if let flash = flashOpacity, configuration.isPressed {
                        Color.white.opacity(flash)
                    }
                }
                .allowsHitTesting(false)
            )
            .animation(
                .spring(
                    response: 0.28,
                    dampingFraction: useBouncySpring ? 0.72 : 0.88
                ),
                value: configuration.isPressed
            )
    }
}

// CTA XS style that mirrors card icon visuals (idle outline ↔ active gradient)
private struct CTAXSStyle: ButtonStyle {
    var height: CGFloat
    var minWidth: CGFloat
    var fixedWidth: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let outline = Color.white.opacity(isPressed ? 0.22 : 0.18)
        let fill = CD.ColorToken.card.opacity(0.82)

        return configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(CD.ColorToken.text.opacity(0.92))
            .padding(.horizontal, AppChipMetrics.hPadXS)
            .frame(minHeight: height, maxHeight: height)
            .frame(minWidth: minWidth, idealWidth: minWidth)
            .frame(width: fixedWidth)
            .background(
                ZStack {
                    Capsule(style: .continuous)
                        .fill(fill)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.plusLighter)
                        .opacity(isPressed ? 0.85 : 1.0)
                }
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(outline, lineWidth: 1.2)
            )
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(isPressed ? 0.96 : 1)
            .opacity(isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isPressed)
    }
}

@inline(__always)
private func appCTATitle(_ t: AppCTAType) -> String {
    switch t {
    case .start:     return "начать"
    case .resume:    return "продолжить"
    case .reinforce: return "закрепить"
    case .next:      return "следующий урок"
    }
}

@inline(__always)
private func appCTAIcon(_ t: AppCTAType) -> String {
    switch t {
    case .reinforce: return "gamecontroller.fill"
    case .start:     return "play.fill"
    case .resume:    return "arrow.clockwise"
    case .next:      return "chevron.right"
    }
}


public struct AppCTAButtons: View {
    public var primaryTitle: String
    public var secondaryTitle: String
    public var onPrimary: () -> Void
    public var onSecondary: () -> Void
    // Semantic CTA types (optional, used for dynamic label/icon)
    private var primaryKind: AppCTAType? = nil
    private var secondaryKind: AppCTAType? = nil
    public var scale: AppCTAScale = .s
    public var unifiedWidth: Bool = true
    public var visual: AppCTAVisual = .brandDark

    // Semantic init (compact only)
    public init(
        primary: AppCTAType,
        secondary: AppCTAType? = nil,
        onPrimary: @escaping () -> Void = {},
        onSecondary: @escaping () -> Void = {},
        scale: AppCTAScale = .s,
        unifiedWidth: Bool = true,
        visual: AppCTAVisual = .brandStatus
    ) {
        self.primaryKind = primary
        self.secondaryKind = secondary
        self.primaryTitle = appCTATitle(primary)
        self.secondaryTitle = secondary.map { appCTATitle($0) } ?? ""
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.scale = scale
        self.unifiedWidth = unifiedWidth
        self.visual = .brandDark
    }

    // Title init (back-compat)
    public init(
        primaryTitle: String,
        secondaryTitle: String = "",
        onPrimary: @escaping () -> Void = {},
        onSecondary: @escaping () -> Void = {},
        scale: AppCTAScale = .s,
        unifiedWidth: Bool = true,
        visual: AppCTAVisual = .brandStatus
    ) {
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.scale = scale
        self.unifiedWidth = unifiedWidth
        self.visual = .brandDark
    }

    // MARK: -- LOCKED TO DESIGN SYSTEM SPEC --
    // The following sizing constants are LOCKED to the DS spec.
    // ⚠️ Do NOT change these values unless you have explicit DS/PM request.
    // They are used throughout the app for CTA sizing and must remain in sync with design.
    // -- END LOCKED --
    //
    // LOCKED: Compact CTA button height, per scale
    private var buttonHeight: CGFloat { scale == .xs ? 34 : 36 } // S is now 36, XS remains 34
    // LOCKED: Rounded corner radius, per scale
    private var corner: CGFloat { scale == .xs ? 12 : 14 } // LOCKED
    // LOCKED: Horizontal padding, per scale
    private var hPad: CGFloat { scale == .xs ? 8 : 10 } // LOCKED

    // XS helpers
    private var isXS: Bool { scale == .xs }
    private var xsStandardWidth: CGFloat { 136 } // unified width for single XS pill
    private var xsUnifiedWidth: CGFloat { 160 } // unified pill width for XS when unifiedWidth=true

    @ViewBuilder
    private func primaryButton() -> some View {
        if scale == .xs {
            Button(action: onPrimary) {
                Text(primaryTitle.capitalized)
                    .kerning(0.15)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(CD.ColorToken.text.opacity(0.92))
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(CTAXSStyle(height: buttonHeight,
                                    minWidth: xsStandardWidth,
                                    fixedWidth: unifiedWidth ? xsUnifiedWidth : nil))
        } else {
            Button(action: onPrimary) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(primaryTitle.capitalized)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, hPad)
                .frame(maxWidth: 190, minHeight: buttonHeight, maxHeight: buttonHeight)
                .foregroundStyle(CD.ColorToken.text.opacity(0.92))
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(CD.ColorToken.card.opacity(0.82))

                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.plusLighter)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
                .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func secondaryButton() -> some View {
        if secondaryKind != nil || !secondaryTitle.isEmpty {
            if scale == .xs {
                Button(action: onSecondary) {
                    let secTitle = secondaryTitle.isEmpty ? appCTATitle(secondaryKind ?? .next) : secondaryTitle
                    Text(secTitle.capitalized)
                        .kerning(0.15)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxHeight: .infinity)
                }
                .buttonStyle(CTAXSStyle(height: buttonHeight,
                                        minWidth: xsStandardWidth,
                                        fixedWidth: unifiedWidth ? xsUnifiedWidth : nil))
            } else {
                Button(action: onSecondary) {
                    let secTitle = secondaryTitle.isEmpty ? appCTATitle(secondaryKind ?? .next) : secondaryTitle
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Text(secTitle.capitalized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, hPad)
                    .frame(maxWidth: .infinity, minHeight: buttonHeight, maxHeight: buttonHeight)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .fill(CD.ColorToken.card.opacity(0.82))

                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.06), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .blendMode(.plusLighter)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    public var body: some View {
        Group {
            if isXS {
                // XS: unified sizes
                if (secondaryKind != nil || !secondaryTitle.isEmpty) {
                    HStack(spacing: 8) {
                        primaryButton()
                        secondaryButton()
                    }
                } else {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        primaryButton()
                        Spacer(minLength: 0)
                    }
                }
            } else {
                // S: legacy wide layout
                HStack(spacing: 10) {
                    primaryButton()
                    secondaryButton()
                }
            }
        }
    }

}


// MARK: - App Progress
public enum AppProgressStyle { case rail }

public struct AppProgressBar: View {
    public var value: CGFloat      // 0…1
    public var height: CGFloat

    public init(value: CGFloat, height: CGFloat = 8) {
        self.value = max(0, min(1, value))
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(1, value))
            let totalWidth = geo.size.width
            let filledWidth = totalWidth * clamped
            let corner = height / 2
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

            ZStack(alignment: .leading) {
                // base rail
                shape
                    .fill(CD.ColorToken.card.opacity(0.75))
                shape
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)

                if filledWidth > 0 {
                    shape
                        .fill(ThemeManager.shared.currentAccentFill)
                        .frame(width: filledWidth)
                        .animation(.easeInOut(duration: 0.28), value: value)
                }
            }
        }
        .frame(height: height)
    }
}


// MARK: - Segmented Progress (empty rails)
/// Пустая сегментированная шкала прогресса (без заливки). Визуал — как у card‑icons: тонкий контур + карточный фон.
public struct AppSegmentedRail: View {
    public var segments: Int = 6
    public var height: CGFloat = 10
    public var gap: CGFloat = 6
    public var cornerScale: CGFloat = 0.35

    public init(segments: Int = 6, height: CGFloat = 10, gap: CGFloat = 6, cornerScale: CGFloat = 0.35) {
        self.segments = max(1, segments)
        self.height = height
        self.gap = max(0, gap)
        self.cornerScale = cornerScale
    }

    private var corner: CGFloat { max(6, height * cornerScale) }

    public var body: some View {
        GeometryReader { geo in
            let count = max(1, segments)
            let totalGap = gap * CGFloat(max(0, count - 1))
            let segW = (geo.size.width - totalGap) / CGFloat(count)
            let shape = RoundedRectangle(cornerRadius: max(4, height * cornerScale), style: .continuous)

            HStack(spacing: gap) {
                ForEach(0..<count, id: \.self) { _ in
                    ZStack {
                        // base fill как у иконок/кнопок в idle
                        shape
                            .fill(CD.ColorToken.card.opacity(0.72))
                        // лёгкий внутренний глосс
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.06), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .blendMode(.plusLighter)
                        // волосковый штрих
                        shape
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .frame(width: segW, height: height)
                    .contentShape(shape)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Pro / Paywall Frame Chrome (accent outline + integrated chips)

private struct AppOverlayChipFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let n = nextValue()
        if n != .zero { value = n }
    }
}

private struct AppOverlayChipFrameReader: View {
    let key: AppOverlayChipFrameKey.Type
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: key, value: geo.frame(in: .named("app_pro_frame_chrome")))
        }
    }
}

/// close button that visually matches the pro chip outline (accent stroke + soft glass fill)
public struct AppProCloseButton: View {
    public var size: CGFloat = 40
    public var onTap: () -> Void

    public init(size: CGFloat = 40, onTap: @escaping () -> Void = {}) {
        self.size = size
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.55))
                        .background(Circle().fill(.ultraThinMaterial))
                )
                .overlay(
                    Circle()
                        .stroke(AnyShapeStyle(ThemeManager.shared.currentAccentFill), lineWidth: 1.2)
                )
                .contentShape(Circle())
        }
        .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
        .accessibilityLabel("Закрыть")
    }
}

/// a reusable glass frame with an accent outline; pro/close chips sit on the outline (outline is erased behind them)
public struct AppProFrameChrome<Content: View>: View {
    public var cornerRadius: CGFloat = 28
    public var strokeWidth: CGFloat = 1.3
    public var inset: CGFloat = 18

    public var topLeft: AnyView
    public var topRight: AnyView
    public var content: () -> Content

    public init(
        cornerRadius: CGFloat = 28,
        strokeWidth: CGFloat = 1.3,
        inset: CGFloat = 18,
        topLeft: AnyView,
        topRight: AnyView,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.strokeWidth = strokeWidth
        self.inset = inset
        self.topLeft = topLeft
        self.topRight = topRight
        self.content = content
    }

    @State private var tlFrame: CGRect = .zero
    @State private var trFrame: CGRect = .zero

    private var outlineStyle: AnyShapeStyle {
        AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

    @ViewBuilder
    private func panelFill() -> some View {
        Theme.Surfaces.blackGlass(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    private func eraseUnderChip(frame: CGRect) -> some View {
        if frame != .zero {
            // cover the outline under the chip with the same panel fill; visually reads as a "cut-out"
            panelFill()
                .frame(width: frame.width + 10, height: frame.height + 10)
                .clipShape(RoundedRectangle(cornerRadius: min((frame.height + 10) / 2, 20), style: .continuous))
                .position(x: frame.midX, y: frame.midY)
                .allowsHitTesting(false)
        }
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            panelFill()

            // accent outline
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(outlineStyle, lineWidth: strokeWidth)
                .opacity(0.85)

            // "cut-outs" under chips so the outline doesn’t run under them
            eraseUnderChip(frame: tlFrame)
            eraseUnderChip(frame: trFrame)

            // top chips (sit on the frame)
            HStack(alignment: .top) {
                topLeft
                    .background(AppOverlayChipFrameReader(key: AppOverlayChipFrameKey.self))
                Spacer(minLength: 0)
                topRight
                    .background(AppOverlayChipFrameReader(key: AppOverlayChipFrameKey.self))
            }
            .padding(.horizontal, inset)
            .padding(.top, inset)

            // inner content area
            VStack(spacing: 0) {
                // leave breathing room under the top chips
                Spacer().frame(height: inset + 10)
                content()
            }
            .padding(.horizontal, inset)
            .padding(.bottom, inset)
        }
        .coordinateSpace(name: "app_pro_frame_chrome")
        .onPreferenceChange(AppOverlayChipFrameKey.self) { _ in }
        // capture both frames (top-left and top-right) by reading them sequentially
        .background(
            GeometryReader { _ in
                Color.clear
                    .onPreferenceChange(AppOverlayChipFrameKey.self) { frame in
                        // this key is reused by both readers; we disambiguate by assigning the first non-zero to TL,
                        // then the next distinct non-zero to TR.
                        if tlFrame == .zero {
                            tlFrame = frame
                        } else if trFrame == .zero, frame != tlFrame {
                            trFrame = frame
                        }
                    }
            }
        )
    }
}

// MARK: - PRO-style modal panel (same shell as PROView / CourseResetConfirm)
public struct ProStyleModalPanel<Content: View>: View {
    public var maxWidth: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(maxWidth: CGFloat = 420, @ViewBuilder content: @escaping () -> Content) {
        self.maxWidth = maxWidth
        self.content = content
    }

    public var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: maxWidth)
            .taikaBlackGlassBackground(cornerRadius: 28)
    }
}

// MARK: - Lesson Summary Overlay (PRO shell)
public struct LessonSummaryOverlay: View {
    public var title: String
    public var subtitle: String
    public var primaryTitle: String
    public var secondaryTitle: String
    public var onPrimary: () -> Void
    public var onSecondary: () -> Void
    public var onClose: () -> Void = {}
    public var ctaStyle: SummaryCTAStyle
    /// Уровень завершения — меняет тон и иерархию CTA.
    public var kind: LessonSummaryKind
    /// Мини‑бейдж над заголовком («курс», «трек»).
    public var eyebrow: String?
    /// Мини‑лайфхаки урока (те же атомы, что в FavoriteDS); `nil` — не показывать блок.
    public var hacksAccessory: AnyView?
    /// Вторая строка: Спикер (урок) или «следующий курс» / каталог.
    public var onSpeakerPractice: (() -> Void)? = nil
    public var speakerPracticeTitle: String
    public var speakerPracticeSystemImage: String
    public var selectedGameMode: GameModeType? = nil
    public var onSelectGameMode: ((GameModeType) -> Void)? = nil
    /// На completion screen показываем компактные game chips, если true.
    public var showGameReinforce: Bool
    /// Доступность PRO-режимов для free/PRO state rendering.
    public var isProUser: Bool
    /// Штатный callback для locked game; overlay должен остаться в исходном context.
    public var onLockedGame: ((GameModeType) -> Void)?
    public var onOpenGame: ((GameModeType) -> Void)?
    public var primaryCaption: String?
    public var lessonDurationText: String? = nil
    public var overallProgressText: String? = nil
    @State private var isGameModeExpanded: Bool = false
    @State private var animateIntro: Bool = false
    @State private var animateReward: Bool = false
    @State private var animateCTA: Bool = false
    @State private var animateHint: Bool = false
    @State private var checkBurst: Bool = false
    @State private var approvedActionInFlight: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        subtitle: String,
        primaryTitle: String,
        secondaryTitle: String,
        onPrimary: @escaping () -> Void = {},
        onSecondary: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        ctaStyle: SummaryCTAStyle = .brandChips,
        kind: LessonSummaryKind = .lesson,
        eyebrow: String? = nil,
        hacksAccessory: AnyView? = nil,
        onSpeakerPractice: (() -> Void)? = nil,
        speakerPracticeTitle: String = "Практика в Спикере",
        speakerPracticeSystemImage: String = "mic.fill",
        selectedGameMode: GameModeType? = nil,
        onSelectGameMode: ((GameModeType) -> Void)? = nil,
        showGameReinforce: Bool = true,
        isProUser: Bool = true,
        onLockedGame: ((GameModeType) -> Void)? = nil,
        onOpenGame: ((GameModeType) -> Void)? = nil,
        primaryCaption: String? = nil,
        lessonDurationText: String? = nil,
        overallProgressText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.onClose = onClose
        self.ctaStyle = ctaStyle
        self.kind = kind
        self.eyebrow = eyebrow
        self.hacksAccessory = hacksAccessory
        self.onSpeakerPractice = onSpeakerPractice
        self.speakerPracticeTitle = speakerPracticeTitle
        self.speakerPracticeSystemImage = speakerPracticeSystemImage
        self.selectedGameMode = selectedGameMode
        self.onSelectGameMode = onSelectGameMode
        self.showGameReinforce = showGameReinforce
        self.isProUser = isProUser
        self.onLockedGame = onLockedGame
        self.onOpenGame = onOpenGame
        self.primaryCaption = primaryCaption
        self.lessonDurationText = lessonDurationText
        self.overallProgressText = overallProgressText
    }

    private func runApprovedAction(_ action: @escaping () -> Void) {
        guard !approvedActionInFlight else { return }
        approvedActionInFlight = true
        action()
    }

    private var fmAccentLine: [TaikaFMChunk] {
        let all: [[TaikaFMChunk]] = {
            switch kind {
            case .course, .catalogEnd:
                return TaikaFMData.shared.courseCompletionAccentMessages()
            case .lesson:
                return TaikaFMData.shared.lessonCompletionAccentMessages()
            }
        }()
        guard !all.isEmpty else { return [] }
        let idx = abs((title + subtitle).hashValue) % all.count
        return all[idx]
    }

    // Helper to compact long secondary titles (e.g. Russian)
    // Helper to parse progress from subtitle string
    private func parseProgress(_ s: String) -> (section: String, learned: Int, total: Int)? {
        // Expected examples: "ПРИВЕТСТВИЯ — выучено 1 из 6", "Приветствие — выучено 6 из 6"
        let parts = s.components(separatedBy: "—").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count >= 2 else { return nil }
        let section = parts[0]
        let tail = parts[1].lowercased()
        // find two numbers in tail
        let nums = tail.split(whereSeparator: { !$0.isNumber }).map { Int(String($0)) }.compactMap { $0 }
        if nums.count >= 2 { return (section, nums[0], nums[1]) }
        return nil
    }
    @ViewBuilder
    private func metaProgressLine() -> some View {
        let duration = lessonDurationText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let overall = overallProgressText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !duration.isEmpty || !overall.isEmpty {
            HStack(spacing: 8) {
                if !duration.isEmpty {
                    Label(duration, systemImage: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.82))
                        .labelStyle(.titleAndIcon)
                }

                if !duration.isEmpty && !overall.isEmpty {
                    Text("•")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.45))
                }

                if !overall.isEmpty {
                    Text(overall)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func startIntroAnimationIfNeeded() {
        guard !animateIntro else { return }

        if reduceMotion {
            animateIntro = true
            animateReward = true
            animateCTA = true
            animateHint = true
            checkBurst = true
            return
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.72)) {
            animateIntro = true
            checkBurst = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                animateReward = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                animateCTA = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.easeInOut(duration: 0.9).repeatCount(3, autoreverses: true)) {
                animateHint = true
            }
        }
    }
    private func compactSecondary(_ t: String) -> String {
        var s = t.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count > 14 {
            s = s.replacingOccurrences(of: "следующий", with: "след.")
            s = s.replacingOccurrences(of: "Следующий", with: "След.")
            s = s.replacingOccurrences(of: "урок", with: "ур.")
            s = s.replacingOccurrences(of: "Урок", with: "Ур.")
        }
        return s
    }

    @ViewBuilder
    private func buttonsBrandChips() -> some View {
        let h: CGFloat = 44
        VStack(spacing: 12) {
            // PRIMARY — visually neutral, on-brand capsule
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPrimary()
            }) {
                Text(primaryTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: h, maxHeight: h)
                    .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
                            .blendMode(.plusLighter)
                    )
                    .clipShape(Capsule(style: .continuous))
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))

            // SECONDARY — quiet dark capsule + game modes always visible
            if showGameReinforce, selectedGameMode != nil, onSelectGameMode != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Закрепить в игре")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                    inlineGameModeSelector()
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSecondary()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: gameModeIcon(selectedGameMode!))
                                .font(.system(size: 14, weight: .semibold))
                            Text("Играть · \(gameModeLabel(selectedGameMode!))")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1.4)
                        )
                    }
                    .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
                }
            } else if !secondaryTitle.isEmpty {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    onSecondary()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        Text(compactSecondary(secondaryTitle))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .allowsTightening(true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: h, maxHeight: h)
                    .background(Capsule(style: .continuous).fill(CD.ColorToken.card.opacity(0.82)))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func secondaryNextCapsule() -> some View {
        let h: CGFloat = 44
        return Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onSecondary()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                Text(compactSecondary(secondaryTitle))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: h, maxHeight: h)
            .background(Capsule(style: .continuous).fill(CD.ColorToken.card.opacity(0.82)))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
    }

    private func gameModeLabel(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "матч"
        case .recall: return "слоги"
        case .audioRecall: return "аудио"
        default: return "режим"
        }
    }

    private func gameModeActionTitle(_ mode: GameModeType) -> String {
        "Закрепить: " + gameModeLabel(mode)
    }

    private var collapsedGameActionTitle: String {
        "Закрепить в игре"
    }

    private func gameModeHint(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "быстро вспомнить"
        case .recall: return "собрать слово"
        case .audioRecall: return "узнать на слух"
        default: return "режим тренировки"
        }
    }

    private func gameModeIcon(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "square.grid.2x2.fill"
        case .recall: return "textformat.abc"
        case .audioRecall: return "speaker.wave.2.fill"
        default: return "gamecontroller.fill"
        }
    }

    @ViewBuilder
    private func inlineGameModeSelector() -> some View {
        if let selectedGameMode, let onSelectGameMode {
            HStack(spacing: 8) {
                inlineGameModeCard(.match, selected: selectedGameMode == .match, onSelect: onSelectGameMode)
                inlineGameModeCard(.recall, selected: selectedGameMode == .recall, onSelect: onSelectGameMode)
                inlineGameModeCard(.audioRecall, selected: selectedGameMode == .audioRecall, onSelect: onSelectGameMode)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }


    private func inlineGameModeCard(_ mode: GameModeType,
                                    selected: Bool,
                                    onSelect: @escaping (GameModeType) -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(mode)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: gameModeIcon(mode))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        selected
                        ? AnyShapeStyle(Color.black.opacity(0.86))
                        : AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(gameModeLabel(mode))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            selected
                            ? AnyShapeStyle(Color.black.opacity(0.92))
                            : AnyShapeStyle(CD.ColorToken.text)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(gameModeHint(mode))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(
                            selected
                            ? AnyShapeStyle(Color.black.opacity(0.66))
                            : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.82))
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        selected
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        : AnyShapeStyle(CD.ColorToken.card.opacity(0.82))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        selected
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                        lineWidth: 1.2
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.98))
        .frame(maxWidth: .infinity)
    }

    private var approvedIsFinalState: Bool {
        kind == .course || kind == .catalogEnd
    }

    private var approvedPrimaryCaption: String {
        if let primaryCaption, !primaryCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return primaryCaption
        }
        if approvedIsFinalState { return "Кун Кру уже приготовила следующий маршрут" }
        let value = primaryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("дальше:") {
            return value.replacingOccurrences(of: "Дальше:", with: "Следующий урок:")
        }
        return value
    }

    private func approvedMetaValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @ViewBuilder
    private func approvedCompletionMetaRibbon() -> some View {
        let duration = approvedMetaValue(lessonDurationText)
        let progress = approvedMetaValue(overallProgressText)
        HStack(spacing: 6) {
            approvedMetaChip(
                approvedIsFinalState ? "курс закрыт" : "урок закрыт",
                system: approvedIsFinalState ? "checkmark.seal.fill" : "sparkles"
            )
            if let progress {
                approvedMetaChip(progress, system: "book.closed")
            }
            if let duration {
                approvedMetaChip(duration, system: "clock")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func approvedMetaChip(_ text: String, system: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(CD.ColorToken.textSecondary)
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(Capsule(style: .continuous).fill(CD.ColorToken.card.opacity(0.55)))
        .overlay(Capsule(style: .continuous).stroke(Theme.Strokes.strokeSubtle, lineWidth: 1))
    }

    @ViewBuilder
    private func approvedCompletionFooter() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                TaikaSectionLabel(title: "ДАЛЬШЕ")
                Button(action: {
                    runApprovedAction {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onPrimary()
                    }
                }) {
                    Text(primaryTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                        .overlay(Capsule(style: .continuous).fill(LinearGradient(colors: [Color.white.opacity(0.16), .clear], startPoint: .top, endPoint: .center)).blendMode(.plusLighter))
                        .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
                .scaleEffect(animateHint ? 1.025 : 1)

                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(approvedPrimaryCaption)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(animateHint ? 1 : 0.72))
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if let onSpeakerPractice {
                VStack(alignment: .leading, spacing: 7) {
                    TaikaSectionLabel(title: approvedIsFinalState ? "ЗАКРЕПИТЬ" : "КУН КРУ СОВЕТУЕТ")
                    Button(action: {
                        runApprovedAction {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            onSpeakerPractice()
                        }
                    }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(ThemeManager.shared.currentAccentFill.opacity(0.18))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(speakerPracticeTitle == "К каталогу курсов" ? "Попробовать в Спикере" : speakerPracticeTitle)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(CD.ColorToken.text)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text("Скажи вслух — я поймаю тоны")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(CD.ColorToken.textSecondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(CD.ColorToken.card.opacity(0.52))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(ThemeManager.shared.currentAccentFill.opacity(0.7), lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
                }
            }

            if showGameReinforce, let onSelectGameMode {
                VStack(alignment: .leading, spacing: 7) {
                    TaikaSectionHeaderRow("ИЛИ ИГРА") {
                        Text("откроется сразу")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                    }
                    VStack(spacing: 6) {
                        ForEach(GameModeType.modesLessonAndPark, id: \.rawValue) { mode in
                            approvedGameChip(mode, selected: selectedGameMode == mode, onSelect: onSelectGameMode)
                        }
                    }
                }
            }

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onClose()
            }) {
                Text(approvedIsFinalState ? "Вернуться к курсам" : "Остаться в курсе")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
        }
    }

    @ViewBuilder
    private func approvedGameChip(_ mode: GameModeType, selected: Bool, onSelect: @escaping (GameModeType) -> Void) -> some View {
        let locked = mode.isPro && !isProUser
        Button(action: {
            UIImpactFeedbackGenerator(style: locked ? .light : .medium).impactOccurred()
            if locked {
                onLockedGame?(mode)
            } else {
                onSelect(mode)
                if let onOpenGame {
                    runApprovedAction {
                        onOpenGame(mode)
                    }
                } else if mode == selectedGameMode {
                    onSecondary()
                }
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            locked
                            ? AnyShapeStyle(CD.ColorToken.card.opacity(0.7))
                            : AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(selected ? 0.28 : 0.16))
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: approvedGameIcon(mode))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            locked
                            ? AnyShapeStyle(CD.ColorToken.textSecondary)
                            : AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        )
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(approvedGameTitle(mode))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(locked ? CD.ColorToken.textSecondary : CD.ColorToken.text)
                        .lineLimit(1)
                    Text(locked ? "Taika+ · \(approvedGameHint(mode))" : approvedGameHint(mode))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                } else {
                    Text(selected ? "играть" : "")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        selected && !locked
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.14))
                        : AnyShapeStyle(CD.ColorToken.card.opacity(0.48))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        selected && !locked
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.9))
                        : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                        lineWidth: selected && !locked ? 1.4 : 1
                    )
            )
            .opacity(locked ? 0.82 : 1)
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
    }

    private func approvedGameTitle(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "Чап-кху"
        case .recall: return "Там-кхам"
        case .audioRecall: return "Фанг-лыак"
        case .grandDialogue: return "Диалог"
        }
    }

    private func approvedGameHint(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "найди пару"
        case .recall: return "собери слово"
        case .audioRecall: return "послушай"
        case .grandDialogue: return "поговори"
        }
    }

    private func approvedGameIcon(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "square.grid.2x2.fill"
        case .recall: return "textformat.abc"
        case .audioRecall: return "speaker.wave.2.fill"
        case .grandDialogue: return "bubble.left.and.bubble.right.fill"
        }
    }

    @ViewBuilder
    private func footerBlock() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if kind == .course || kind == .catalogEnd {
                courseCompleteCTA()
            } else if let onSpeaker = onSpeakerPractice {
                consolidateChipsWithSpeaker(onSpeaker: onSpeaker)
            } else {
                buttonsBrandChips()
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Итог курса/трека: один главный хук (голос) + тихий продолжить. Игры — на уровне урока.
    private func courseCompleteCTA() -> some View {
        let h: CGFloat = 48
        return VStack(spacing: 12) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onPrimary()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text(primaryTitle)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundColor(Color.black.opacity(0.92))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: h, maxHeight: h)
                .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                .overlay(
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center))
                        .blendMode(.plusLighter)
                )
                .clipShape(Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))

            if let onSpeaker = onSpeakerPractice {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    onSpeaker()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: speakerPracticeSystemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        Text(speakerPracticeTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.55))
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                    .background(Capsule(style: .continuous).fill(CD.ColorToken.card.opacity(0.55)))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
            }

            Text(kind == .catalogEnd
                 ? "Голос закрепит всё, что ты прошёл. Каталог — когда захочешь новый путь."
                 : "Сначала проговори курс — следующий откроется, когда будешь готов.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Итоги урока: следующий шаг → спикер → нативный выбор игры (без expand-танца).
    private func consolidateChipsWithSpeaker(onSpeaker: @escaping () -> Void) -> some View {
        let h: CGFloat = 44
        return VStack(spacing: 12) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPrimary()
            }) {
                Text(primaryTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: h, maxHeight: h)
                    .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
                            .blendMode(.plusLighter)
                    )
                    .clipShape(Capsule(style: .continuous))
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))

            Button(action: {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onSpeaker()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: speakerPracticeSystemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    Text(speakerPracticeTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: h, maxHeight: h)
                .background(Capsule(style: .continuous).fill(CD.ColorToken.card.opacity(0.82)))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))

            if showGameReinforce, selectedGameMode != nil, onSelectGameMode != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Закрепить в игре")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                    inlineGameModeSelector()
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSecondary()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: gameModeIcon(selectedGameMode!))
                                .font(.system(size: 14, weight: .semibold))
                            Text("Играть · \(gameModeLabel(selectedGameMode!))")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1.4)
                        )
                    }
                    .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func progressAndSubtitleBlock() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(
                        size: (kind == .course || kind == .catalogEnd) ? 16 : 13,
                        weight: (kind == .course || kind == .catalogEnd) ? .semibold : .regular
                    ))
                    .foregroundStyle(
                        (kind == .course || kind == .catalogEnd)
                        ? CD.ColorToken.text.opacity(0.88)
                        : CD.ColorToken.textSecondary.opacity(0.7)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // Legacy Taika FM guidance removed from lesson-complete (game picker is inline below).

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                PD.ColorToken.background
                    .ignoresSafeArea()

                Circle()
                    .fill(ThemeManager.shared.currentAccentTintColor.opacity(checkBurst ? 0.34 : 0.08))
                    .frame(width: 280, height: 280)
                    .blur(radius: 48)
                    .offset(y: -40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                TaikaRootVerticalScroll {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("taikA")
                                .font(.taikaLogo(18))
                                .foregroundStyle(CD.ColorToken.text)
                            Spacer(minLength: 44)
                        }

                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(ThemeManager.shared.currentAccentTintColor.opacity(0.18))
                                    .frame(width: 76, height: 76)
                                    .scaleEffect(checkBurst ? 1.18 : 0.7)
                                    .opacity(checkBurst ? 0.9 : 0)
                                Circle()
                                    .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 2.4)
                                    .frame(width: 62, height: 62)
                                    .shadow(color: ThemeManager.shared.currentAccentTintColor.opacity(0.55), radius: 16)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            }
                            .scaleEffect(animateIntro ? 1 : 0.78)
                            .opacity(animateIntro ? 1 : 0)

                            VStack(alignment: .center, spacing: 8) {
                                Text(title)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(CD.ColorToken.text)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                Text(subtitle)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(CD.ColorToken.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.85)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(animateIntro ? 1 : 0)
                        .offset(y: animateIntro ? 0 : 16)

                        approvedCompletionMetaRibbon()
                            .opacity(animateReward ? 1 : 0)
                            .offset(y: animateReward ? 0 : 12)

                        approvedCompletionFooter()
                            .opacity(animateCTA ? 1 : 0)
                            .offset(y: animateCTA ? 0 : 18)

                        if let hacksAccessory {
                            hacksAccessory
                                .frame(maxWidth: .infinity)
                                .hidden()
                                .frame(height: 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, max(proxy.safeAreaInsets.top, 10) + 48)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 24) + 18)
                }

                Button(action: { onClose() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                        .overlay(Circle().stroke(Theme.Strokes.strokeSubtle, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, max(proxy.safeAreaInsets.top, 10) + 4)
                .padding(.trailing, 16)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear { startIntroAnimationIfNeeded() }
            .onChange(of: title) { _, _ in
                animateIntro = false
                animateReward = false
                animateCTA = false
                animateHint = false
                checkBurst = false
                startIntroAnimationIfNeeded()
            }
        }
        .ignoresSafeArea()
    }

}

// MARK: - HomeTask Summary Overlay (glass, same visuals as LessonSummaryOverlay)
public struct HomeTaskSummaryOverlay: View {
    public var title: String              // e.g. "Урок 1 — закрепление"
    public var subtitle: String           // e.g. "пары: 6 из 6 • попытки: 9"
    public var primaryTitle: String       // e.g. "ещё раз"
    public var secondaryTitle: String     // e.g. "закрыть" / "к уроку"
    public var onPrimary: () -> Void
    public var onSecondary: () -> Void
    public var onClose: () -> Void = {}
    public var ctaStyle: SummaryCTAStyle
    public var isProUser: Bool = true

    public init(
        title: String,
        subtitle: String,
        primaryTitle: String,
        secondaryTitle: String,
        onPrimary: @escaping () -> Void = {},
        onSecondary: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        ctaStyle: SummaryCTAStyle = .brandChips,
        isProUser: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.onClose = onClose
        self.ctaStyle = ctaStyle
        self.isProUser = isProUser
    }

    // Reuse chipLabel from LessonSummaryOverlay style (local copy to avoid refactoring)
    private func chipLabel(title: String, system: String, titleColor: Color) -> some View {
        let iconSize: CGFloat = 22
        let puckSize: CGFloat = 30
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(CD.ColorToken.accent).frame(width: puckSize, height: puckSize)
                Image(systemName: system)
                    .font(.system(size: iconSize - 6, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.9))
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    @ViewBuilder
    private func buttonsBrandChips() -> some View {
        let h: CGFloat = 44
        VStack(spacing: 12) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPrimary()
            }) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text(primaryTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: h, maxHeight: h)
                .background(Capsule(style: .continuous).fill(Theme.Colors.accent))
                .overlay(
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center))
                        .blendMode(.plusLighter)
                )
                .clipShape(Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))

            Button(action: {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onSecondary()
            }) {
                // --- Label ink & accessories
                let titleView: some View = Group {
                    if !isProUser {
                        // Gradient ink for PRO-gated
                        let t = Text(secondaryTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        ZStack { Theme.Colors.accent.blur(radius: 3).opacity(0.70).mask(t); t.foregroundStyle(Theme.Colors.accent) }
                    } else {
                        Text(secondaryTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                HStack(spacing: 12) {
                    titleView
                    Spacer(minLength: 0)
                    if !isProUser {
                        AppProChip()
                            .scaleEffect(0.78)
                            .padding(.trailing, 2)
                    }
                    // Chevron in a tiny puck for better affordance
                    ZStack {
                        Circle().fill(CD.ColorToken.card.opacity(0.9))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                    }
                    .frame(width: 26, height: 26)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: h, maxHeight: h)
                .background(
                    Capsule(style: .continuous)
                        .fill(CD.ColorToken.card.opacity(0.82))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            !isProUser ? AnyShapeStyle(Theme.Colors.accent.opacity(0.85))
                                       : AnyShapeStyle(Color.white.opacity(0.16)),
                            lineWidth: !isProUser ? 1.6 : 1.1
                        )
                )
                .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 3)
                .contentShape(Capsule())
            }
            .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
        }
        .frame(maxWidth: .infinity)
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Backdrop (tap-catcher handled by host)
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()

                // Vertically centered mascot + card, like LessonSummaryOverlay
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    ZStack(alignment: .top) {
                        // Mascot on top (identical sizing/offset)
                        Image("mascot.message")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 170, height: 170)
                            .taikaMascotChrome()
                            .offset(y: -100)
                            .zIndex(2)
                            .allowsHitTesting(false)

                        // Card body (centered)
                        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
                        VStack(alignment: .center, spacing: 22) {
                            // Title
                            Text(title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(CD.ColorToken.text)
                                .lineLimit(2)
                                .minimumScaleFactor(0.9)
                                .padding(.top, 2)

                            // Plain subtitle
                            Text(subtitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .minimumScaleFactor(0.95)
                                .allowsTightening(true)
                                .padding(.horizontal, 4)

                            // CTAs — same variants as summary, with PRO gating on secondary
                            Group {
                                switch ctaStyle {
                                case .brandChips:
                                    buttonsBrandChips()
                                default:
                                    buttonsBrandChips()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 22)
                        .frame(width: min(proxy.size.width - CD.Spacing.screen * 2, 340))
                        .fixedSize(horizontal: false, vertical: true)
                        .background(shape.fill(CD.ColorToken.card.opacity(0.92)))
                        .overlay(
                            shape
                                .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom))
                                .blendMode(.plusLighter)
                        )
                        .clipShape(shape)
                        .shadow(color: Color.black.opacity(0.28), radius: 24, x: 0, y: 12)
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 0)
                        // Close button overlaid, not affecting title centering
                        .overlay(alignment: .topTrailing) {
                            Button(action: { onClose() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(CD.ColorToken.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(CD.ColorToken.card.opacity(0.4)))
                                    .overlay(Circle().stroke(CD.ColorToken.stroke, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                        }
                        .offset(y: -10)
                    }

                    Spacer(minLength: 0)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

// MARK: - Activity log templates (profile-ready, DS only)

public struct AppActivityRingSlice: Identifiable, Equatable {
    public let id: UUID
    public var kind: AppActivityEventKind
    public var value: CGFloat

    public init(id: UUID = UUID(), kind: AppActivityEventKind, value: CGFloat) {
        self.id = id
        self.kind = kind
        self.value = value
    }
}

/// a tiny ring chart that shows the share of activity by category (lesson/steps/like/etc.)
/// uses the current accent fill with different opacities per kind to stay on-brand.
public struct AppActivityCategoryRing: View {
    public var slices: [AppActivityRingSlice]
    public var size: CGFloat = 36
    public var lineWidth: CGFloat = 7
    @Binding public var selectedKind: AppActivityEventKind?

    public init(
        slices: [AppActivityRingSlice],
        size: CGFloat = 36,
        lineWidth: CGFloat = 7,
        selectedKind: Binding<AppActivityEventKind?> = .constant(nil)
    ) {
        self.slices = slices
        self.size = size
        self.lineWidth = lineWidth
        self._selectedKind = selectedKind
    }

    private func opacity(for kind: AppActivityEventKind) -> CGFloat {
        switch kind {
        case .lesson:         return 0.95
        case .steps:          return 0.78
        case .like:           return 0.66
        case .addCourse:      return 0.56
        case .completeCourse: return 0.72
        case .note:           return 0.50
        }
    }

    private struct Segment: Identifiable {
        let id = UUID()
        let kind: AppActivityEventKind
        let value: CGFloat
        let start: CGFloat   // 0..1
        let end: CGFloat     // 0..1
    }

    private func buildSegments() -> [Segment] {
        let total = max(0.0001, slices.reduce(0) { $0 + max(0, $1.value) })
        let clean = slices
            .filter { $0.value > 0.0001 }
            .sorted { $0.value > $1.value }

        var segments: [Segment] = []
        segments.reserveCapacity(clean.count)
        var cursor: CGFloat = 0
        for s in clean {
            let frac = max(0, s.value) / total
            let start = cursor
            let end = min(1, cursor + frac)
            segments.append(Segment(kind: s.kind, value: s.value, start: start, end: end))
            cursor = end
        }
        return segments
    }

    private func kindAt(location: CGPoint, in size: CGSize, segments: [Segment]) -> AppActivityEventKind? {
        let cx = size.width / 2
        let cy = size.height / 2
        let dx = location.x - cx
        let dy = location.y - cy

        // angle: -pi..pi, where 0 is to the right
        let angle = atan2(dy, dx)
        // rotate so 0 starts at top (-90deg)
        var a = angle + (.pi / 2)
        if a < 0 { a += 2 * .pi }
        let t = CGFloat(a / (2 * .pi)) // 0..1

        for s in segments {
            if t >= s.start && t <= s.end {
                return s.kind
            }
        }
        return nil
    }

    private func valueForSelected(in segments: [Segment]) -> Int? {
        guard let k = selectedKind else { return nil }
        let v = segments.first(where: { $0.kind == k })?.value
        guard let v else { return nil }
        return Int(round(v))
    }

    public var body: some View {
        let segments = buildSegments()
        let hasData = !segments.isEmpty
        let gap: CGFloat = hasData ? 0.010 : 0.0 // ~3.6deg

        return GeometryReader { geo in
            let s = geo.size

            ZStack {
                // base rail
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)

                if hasData {
                    ForEach(segments) { seg in
                        let span = max(0, seg.end - seg.start)
                        let start = seg.start + min(gap, span / 3)
                        let end = seg.end - min(gap, span / 3)

                        Circle()
                            .trim(from: start, to: max(start, end))
                            .stroke(
                                AnyShapeStyle(
                                    ThemeManager.shared.currentAccentFill
                                        .opacity(opacity(for: seg.kind))
                                ),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .overlay(
                                // selected ring emphasis (subtle)
                                Group {
                                    if selectedKind == seg.kind {
                                        Circle()
                                            .trim(from: start, to: max(start, end))
                                            .stroke(
                                                AnyShapeStyle(ThemeManager.shared.currentAccentFill),
                                                style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round)
                                            )
                                            .rotationEffect(.degrees(-90))
                                            .opacity(0.35)
                                    }
                                }
                            )
                    }
                } else {
                    // empty state: subtle accent hint
                    Circle()
                        .trim(from: 0, to: 0.20)
                        .stroke(
                            AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.35)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                // center value (only when a segment is selected)
                if let v = valueForSelected(in: segments) {
                    Text("\(v)")
                        .font(.system(size: max(14, size * 0.20), weight: .bold))
                        .foregroundStyle(CD.ColorToken.text)
                        .monospacedDigit()
                        .transition(.opacity)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { g in
                        guard hasData else { return }
                        let k = kindAt(location: g.location, in: s, segments: segments)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            if selectedKind == k { selectedKind = nil } else { selectedKind = k }
                        }
                    }
            )
            .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
    }
}

public enum AppActivityEventKind {
    case lesson
    case steps
    case like
    case addCourse
    case completeCourse
    case note

    var systemIcon: String {
        switch self {
        case .lesson:         return "graduationcap"
        case .steps:          return "checkmark.circle"
        case .like:           return "heart"
        case .addCourse:      return "plus.circle"
        case .completeCourse: return "checkmark.seal"
        case .note:           return "note.text"
        }
    }
}

public struct AppActivityEvent: Identifiable, Equatable {
    public let id: UUID
    public var kind: AppActivityEventKind
    public var title: String
    public var subtitle: String?

    public init(id: UUID = UUID(), kind: AppActivityEventKind, title: String, subtitle: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
    }
}

public enum AppActivityIntensity {
    case empty
    case low
    case mid
    case high

    var fillOpacity: CGFloat {
        switch self {
        case .empty: return 0.00
        case .low:   return 0.08
        case .mid:   return 0.14
        case .high:  return 0.22
        }
    }
}

/// One compact day card: summary row + optional event list (no logic).
/// Intended usage: profile "моя активность" — tap a day square → show this note.
public struct AppActivityDayNoteCard: View {
    public var dayTitle: String          // e.g. "сегодня", "вт", "чт"
    public var summary: String           // e.g. "1 урок • 6 шагов • 3 лайка"
    public var intensity: AppActivityIntensity
    public var events: [AppActivityEvent]
    public var onDetails: () -> Void

    @State private var selectedKind: AppActivityEventKind? = nil

    private var ringSlices: [AppActivityRingSlice] {
        // group by kind, count occurrences
        let grouped = Dictionary(grouping: events, by: { $0.kind })
        let slices = grouped.map { (k, v) in
            AppActivityRingSlice(kind: k, value: CGFloat(v.count))
        }
        return slices
    }

    public init(
        dayTitle: String,
        summary: String,
        intensity: AppActivityIntensity = .empty,
        events: [AppActivityEvent] = [],
        onDetails: @escaping () -> Void = {}
    ) {
        self.dayTitle = dayTitle
        self.summary = summary
        self.intensity = intensity
        self.events = events
        self.onDetails = onDetails
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 14) {
                // left content
                VStack(alignment: .leading, spacing: 12) {
                    // header
                    Text(dayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)

                    // summary
                    Text(summary)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .lineLimit(2)

                    // optional events (template; may be shown in overlay later)
                    if !events.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(events) { e in
                                Button(action: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                        if selectedKind == e.kind { selectedKind = nil } else { selectedKind = e.kind }
                                    }
                                }) {
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Image(systemName: e.kind.systemIcon)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                                            .frame(width: 16)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(e.title)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(CD.ColorToken.text)
                                                .lineLimit(1)
                                            if let s = e.subtitle, !s.isEmpty {
                                                Text(s)
                                                    .font(.system(size: 12, weight: .regular))
                                                    .foregroundStyle(CD.ColorToken.textSecondary)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(
                                                selectedKind == e.kind
                                                ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.12))
                                                : AnyShapeStyle(Color.clear)
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                selectedKind == e.kind
                                                ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.45))
                                                : AnyShapeStyle(Color.clear),
                                                lineWidth: 1
                                            )
                                    )
                                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                // right column (ring centered in the free space; big and readable)
                let ringSize: CGFloat = 140
                let ringLine: CGFloat = 20

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if !events.isEmpty {
                        AppActivityCategoryRing(
                            slices: ringSlices,
                            size: ringSize,
                            lineWidth: ringLine,
                            selectedKind: $selectedKind
                        )
                    }
                    Spacer(minLength: 0)
                }
                // reserve enough space so the ring sits centered in the empty area on the right
                .frame(width: ringSize + 50)
                .padding(.trailing, 2)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    selectedKind = nil
                }
            }

            // info button pinned to top-right (separate from ring)
            Button(action: onDetails) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(CD.ColorToken.card.opacity(0.75)))
                    .overlay(Circle().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
            }
            .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
            .zIndex(2)
        }
        .padding(14)
        .background(
            ZStack {
                shape.fill(CD.ColorToken.card.opacity(0.88))

                shape
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)

                shape.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            }
        )
        .clipShape(shape)
    }
}

/// One day square (for 7-day row). Use intensity to control fill; use isSelected for outline.
public struct AppActivityDaySquare: View {
    public var intensity: AppActivityIntensity
    public var isSelected: Bool
    public var onTap: () -> Void

    public init(intensity: AppActivityIntensity, isSelected: Bool = false, onTap: @escaping () -> Void = {}) {
        self.intensity = intensity
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        Button(action: onTap) {
            ZStack {
                shape
                    .fill(CD.ColorToken.card.opacity(0.80))

                if intensity != .empty {
                    shape
                        .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .opacity(intensity.fillOpacity)
                }

                shape
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)

                if isSelected {
                    shape
                        .stroke(AnyShapeStyle(ThemeManager.shared.currentAccentFill), lineWidth: 1.4)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(shape)
        }
        .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
        .accessibilityHidden(true)
    }
}

/// A 7-day row built from DS squares (no state; caller drives selection).
public struct AppActivityWeekRow: View {
    public var intensities: [AppActivityIntensity]
    public var selectedIndex: Int
    public var onSelect: (Int) -> Void

    public init(intensities: [AppActivityIntensity], selectedIndex: Int = 0, onSelect: @escaping (Int) -> Void = { _ in }) {
        self.intensities = intensities
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(intensities.enumerated()), id: \.offset) { idx, it in
                AppActivityDaySquare(intensity: it, isSelected: idx == selectedIndex) {
                    onSelect(idx)
                }
            }
        }
    }
}

// MARK: - App Stats Graphs (minimal, reusable)

public enum AppSparkStyle { case neutral, accent }

/// A tiny sparkline (line) for quick trends. Minimal, monochrome (neutral) or accent.
public struct AppSparkline: View {
    public var values: [CGFloat]            // arbitrary; normalized internally
    public var height: CGFloat = 22
    public var lineWidth: CGFloat = 2
    public var style: AppSparkStyle = .neutral

    public init(values: [CGFloat], height: CGFloat = 22, lineWidth: CGFloat = 2, style: AppSparkStyle = .neutral) {
        self.values = values
        self.height = height
        self.lineWidth = lineWidth
        self.style = style
    }

    private var strokeStyle: AnyShapeStyle {
        style == .accent
        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.85))
    }

    public var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, height)
            let vals = values
            let minV = vals.min() ?? 0
            let maxV = vals.max() ?? 1
            let range = max(0.0001, maxV - minV)
            let n = max(2, vals.count)

            Path { p in
                for i in 0..<n {
                    let v = i < vals.count ? vals[i] : (vals.last ?? 0)
                    let x = w * CGFloat(i) / CGFloat(n - 1)
                    let y = h - ((v - minV) / range) * h
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(strokeStyle, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A tiny bar chart (e.g., last 7 days). Uses subtle rails + accent fill.
public struct AppMiniBars: View {
    public var values: [CGFloat]        // arbitrary; normalized internally
    public var height: CGFloat = 34
    public var barWidth: CGFloat = 8
    public var spacing: CGFloat = 6
    public var style: AppSparkStyle = .accent

    public init(values: [CGFloat], height: CGFloat = 34, barWidth: CGFloat = 8, spacing: CGFloat = 6, style: AppSparkStyle = .accent) {
        self.values = values
        self.height = height
        self.barWidth = barWidth
        self.spacing = spacing
        self.style = style
    }

    private var fillStyle: AnyShapeStyle {
        style == .accent
        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.85))
    }

    public var body: some View {
        let vals = values
        let maxV = max(0.0001, vals.max() ?? 1)

        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(vals.enumerated()), id: \.offset) { _, v in
                let pct = max(0, min(1, v / maxV))
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(CD.ColorToken.card.opacity(0.70))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fillStyle)
                        .frame(height: max(2, height * pct))
                }
                .frame(width: barWidth, height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A 7-day heat row (activity squares). Good for “последние 7 дней”.
public struct AppHeatRow: View {
    public var values: [CGFloat]            // 0…1 preferred; clamped
    public var size: CGFloat = 14
    public var spacing: CGFloat = 8

    public init(values: [CGFloat], size: CGFloat = 14, spacing: CGFloat = 8) {
        self.values = values
        self.size = size
        self.spacing = spacing
    }

    public var body: some View {
        let vals = values
        HStack(spacing: spacing) {
            ForEach(Array(vals.enumerated()), id: \.offset) { _, v in
                let c = max(0, min(1, v))
                let base = CD.ColorToken.card.opacity(0.72)
                let isActive = c > 0.01

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isActive ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(base))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(isActive ? 0.10 : 0.08), lineWidth: 1)
                    )
                    .opacity(isActive ? (0.30 + 0.70 * c) : 1)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Simple donut ring for progress (0…1). Minimal, matches DS.
public struct AppDonut: View {
    public var value: CGFloat
    public var size: CGFloat = 46
    public var lineWidth: CGFloat = 7

    public init(value: CGFloat, size: CGFloat = 46, lineWidth: CGFloat = 7) {
        self.value = value
        self.size = size
        self.lineWidth = lineWidth
    }

    public var body: some View {
        let v = max(0, min(1, value))
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: v)
                .stroke(
                    AnyShapeStyle(ThemeManager.shared.currentAccentFill),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A small “stats card” that composes heat + bars + spark + donut.
public struct AppStatsMiniCard: View {
    public var title: String
    public var subtitle: String
    public var heat: [CGFloat]
    public var bars: [CGFloat]
    public var spark: [CGFloat]
    public var progress: CGFloat

    public init(
        title: String,
        subtitle: String,
        heat: [CGFloat],
        bars: [CGFloat],
        spark: [CGFloat],
        progress: CGFloat
    ) {
        self.title = title
        self.subtitle = subtitle
        self.heat = heat
        self.bars = bars
        self.spark = spark
        self.progress = progress
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                AppDonut(value: progress, size: 42, lineWidth: 7)
            }

            AppHeatRow(values: heat, size: 12, spacing: 8)

            HStack(alignment: .center, spacing: 12) {
                AppMiniBars(values: bars, height: 28, barWidth: 7, spacing: 6, style: .accent)
                AppSparkline(values: spark, height: 28, lineWidth: 2, style: .neutral)
            }
        }
        .padding(14)
        .background(
            ZStack {
                shape.fill(CD.ColorToken.card.opacity(0.88))
                shape
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
                shape.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            }
        )
        .clipShape(shape)
    }
}

// MARK: - Stat Chips (profile-ready)

public struct AppMetricDeltaItem: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var value: String
    public var delta: String?   // e.g. "+1", "0", nil

    public init(id: UUID = UUID(), title: String, value: String, delta: String? = nil) {
        self.id = id
        self.title = title
        self.value = value
        self.delta = delta
    }
}

public enum AppMetricDeltaSize { case s, m }

public struct AppMetricDeltaChip: View {
    public var item: AppMetricDeltaItem
    public var size: AppMetricDeltaSize
    public var onTap: () -> Void

    public init(item: AppMetricDeltaItem, size: AppMetricDeltaSize = .m, onTap: @escaping () -> Void = {}) {
        self.item = item
        self.size = size
        self.onTap = onTap
    }

    private var corner: CGFloat { size == .m ? 16 : 14 }
    private var height: CGFloat { size == .m ? 62 : 56 }
    private var hPad: CGFloat { size == .m ? 14 : 12 }
    private var vPad: CGFloat { size == .m ? 12 : 10 }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
    }

    private var a11yText: String {
        item.title + ": " + item.value + (item.delta.map { " (" + $0 + ")" } ?? "")
    }

    public var body: some View {
        Button(action: onTap) {
            AppMetricDeltaChipLabel(
                title: item.title,
                value: item.value,
                delta: item.delta,
                hPad: hPad,
                vPad: vPad,
                minHeight: height,
                shape: shape
            )
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
        .accessibilityLabel(a11yText)
    }

    private struct AppMetricDeltaChipLabel: View {
        var title: String
        var value: String
        var delta: String?
        var hPad: CGFloat
        var vPad: CGFloat
        var minHeight: CGFloat
        var shape: RoundedRectangle

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(CD.ColorToken.text)
                        .monospacedDigit()
                        .lineLimit(1)

                    if let d = delta, !d.isEmpty {
                        Text(d)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            .monospacedDigit()
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(minHeight: minHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppMetricDeltaChipBackground(shape: shape))
            .contentShape(shape)
        }
    }

    private struct AppMetricDeltaChipBackground: View {
        let shape: RoundedRectangle

        var body: some View {
            ZStack {
                shape.fill(CD.ColorToken.card.opacity(0.72))
                shape
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
                shape.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            }
        }
    }
}

public struct AppMetricDeltaRow: View {
    public var items: [AppMetricDeltaItem]
    public var size: AppMetricDeltaSize
    public var onTap: (UUID) -> Void

    public init(items: [AppMetricDeltaItem], size: AppMetricDeltaSize = .m, onTap: @escaping (UUID) -> Void = { _ in }) {
        self.items = items
        self.size = size
        self.onTap = onTap
    }

    public var body: some View {
        HStack(spacing: 12) {
            ForEach(items) { it in
                AppMetricDeltaChip(item: it, size: size) { onTap(it.id) }
            }
        }
    }
}

// MARK: - Speaker icon buttons (used by SpeakerDS)

public enum AppSpeakerIconKind {
    case mic
    case stop
    case refresh
    case clear
    case user

    var systemName: String {
        switch self {
        case .mic: return "mic.fill"
        case .stop: return "stop.fill"
        case .refresh: return "arrow.clockwise"
        case .clear: return "trash"
        case .user: return "person.fill"
        }
    }
}

/// Unified circular icon button for Speaker/Chat controls.
/// Visual style matches AppDS (card glass + thin stroke + accent ring when active).
public struct AppSpeakerIconButton: View {
    public var kind: AppSpeakerIconKind
    public var size: CGFloat
    public var isEnabled: Bool
    public var isActive: Bool
    public var onTap: () -> Void

    public init(
        kind: AppSpeakerIconKind,
        size: CGFloat = 44,
        isEnabled: Bool = true,
        isActive: Bool = false,
        onTap: @escaping () -> Void = {}
    ) {
        self.kind = kind
        self.size = size
        self.isEnabled = isEnabled
        self.isActive = isActive
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onTap()
        }) {
            ZStack {
                let shape = Circle()

                // background
                Group {
                    if isActive {
                        // active like card icons: solid accent fill
                        shape.fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            .overlay(
                                shape
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.08), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .blendMode(.plusLighter)
                            )
                    } else {
                        // inactive: neutral glass like card icons
                        shape.fill(CD.ColorToken.card.opacity(0.78))
                            .overlay(
                                shape
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.06), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .blendMode(.plusLighter)
                            )
                    }
                }

                // stroke (same weight as card icons)
                shape
                    .stroke(
                        isActive
                        ? AnyShapeStyle(Color.white.opacity(0.12))
                        : AnyShapeStyle(Color.white.opacity(0.14)),
                        lineWidth: 1
                    )

                // icon
                Image(systemName: kind.systemName)
                    .font(.system(size: size * 0.40, weight: .semibold))
                    .foregroundStyle(
                        isEnabled
                        ? (isActive
                            ? AnyShapeStyle(Color.black.opacity(0.92))
                            : AnyShapeStyle(CD.ColorToken.text)
                          )
                        : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.45))
                    )
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityTitle)
    }

    private var accessibilityTitle: String {
        switch kind {
        case .mic: return "микрофон"
        case .stop: return "стоп"
        case .refresh: return "повторить"
        case .clear: return "очистить"
        case .user: return "пользователь"
        }
    }
}

/// Small pill control that pairs an AppSpeakerIconButton with a label.
/// Useful for compact chat rows.
public struct AppSpeakerIconPill: View {
    public var kind: AppSpeakerIconKind
    public var title: String
    public var isEnabled: Bool
    public var isActive: Bool
    public var onTap: () -> Void

    public init(
        kind: AppSpeakerIconKind,
        title: String,
        isEnabled: Bool = true,
        isActive: Bool = false,
        onTap: @escaping () -> Void = {}
    ) {
        self.kind = kind
        self.title = title
        self.isEnabled = isEnabled
        self.isActive = isActive
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 10) {
                AppSpeakerIconButton(kind: kind, size: 34, isEnabled: isEnabled, isActive: isActive) {}
                    .allowsHitTesting(false)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isEnabled ? CD.ColorToken.text : CD.ColorToken.textSecondary.opacity(0.45))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(CD.ColorToken.card.opacity(0.78))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
        .disabled(!isEnabled)
    }
}

// MARK: - Audio (play + inline waveform)

/// A compact, on-brand audio control: single tappable capsule that contains the play icon
/// and an inline waveform. No labels. No layout jumps: waveform is always present.
public struct AppAudioWaveButton: View {
    public var isPlaying: Bool
    public var width: CGFloat
    public var height: CGFloat
    public var onTap: () -> Void

    public init(
        isPlaying: Bool,
        width: CGFloat = 128,
        height: CGFloat = 34,
        onTap: @escaping () -> Void = {}
    ) {
        self.isPlaying = isPlaying
        self.width = width
        self.height = height
        self.onTap = onTap
    }

    public var body: some View {
        let shape = Capsule(style: .continuous)

        return Button(action: {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 10) {
                // icon puck (chip-like, no hard stroke)
                ZStack {
                    if isPlaying {
                        Circle()
                            .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.10), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .blendMode(.plusLighter)
                            )
                    } else {
                        Circle()
                            .fill(CD.ColorToken.card.opacity(0.62))
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.06), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .blendMode(.plusLighter)
                            )
                    }

                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            isPlaying
                            ? AnyShapeStyle(Color.black.opacity(0.92))
                            : AnyShapeStyle(CD.ColorToken.text)
                        )
                }
                .frame(width: 26, height: 26)

                // waveform (always present)
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    AppAudioWaveform(
                        time: t,
                        isActive: isPlaying,
                        barCount: 14,
                        maxHeight: height * 0.46
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .frame(width: width, height: height)
            .background(
                ZStack {
                    // base glass (no hard outline)
                    shape
                        .fill(CD.ColorToken.card.opacity(0.72))

                    // subtle gloss
                    shape
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.plusLighter)

                    // active accent aura (soft, not a border)
                    if isPlaying {
                        shape
                            .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            .opacity(0.10)
                            .blur(radius: 6)
                            .mask(shape)
                    }
                }
            )
            .clipShape(shape)
            .contentShape(shape)
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.98))
        .accessibilityLabel(isPlaying ? "остановить" : "прослушать")
    }
}

private struct AppAudioWaveform: View {
    var time: TimeInterval
    var isActive: Bool
    var barCount: Int
    var maxHeight: CGFloat

    private func barHeight(index: Int) -> CGFloat {
        // calm baseline when idle; animated when active
        let base: CGFloat = max(2, maxHeight * 0.22)
        guard isActive else {
            // gentle static variation
            let f = 0.65 + 0.25 * CGFloat((index % 4))
            return min(maxHeight, base * f)
        }

        // animated: phase-shifted sines → looks like a voice wave, stable and cheap
        let i = CGFloat(index)
        let w1 = sin(CGFloat(time) * 4.1 + i * 0.55)
        let w2 = sin(CGFloat(time) * 2.2 + i * 0.90)
        let mix = (w1 * 0.65 + w2 * 0.35)
        let amp = (0.45 + 0.55 * abs(mix))
        return max(2, min(maxHeight, base + (maxHeight - base) * amp))
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(
                        isActive
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.80))
                        : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.35))
                    )
                    .frame(width: 3, height: barHeight(index: idx))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .center)
        .animation(.linear(duration: 0.12), value: time)
        .accessibilityHidden(true)
    }
}

// MARK: - Filters (template)
public struct AppFilterItem: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var isActive: Bool
    public init(id: UUID = UUID(), title: String, isActive: Bool = false) {
        self.id = id
        self.title = title
        self.isActive = isActive
    }
}

public enum AppFilterScale { case xs, s }

private enum AppFilterMetrics {
    static let xsHeight: CGFloat = 30
    static let sHeight: CGFloat  = 32
    static let xsHPad: CGFloat   = 16
    static let sHPad: CGFloat    = 18
    static let corner: CGFloat   = 18
    // unified min widths for visual stability
}

/// Single filter chip styled like MiniChip:
/// - active: accent-filled pill with light gloss
/// - inactive: neutral glassy pill
public struct AppFilterChip: View {
    public var title: String
    public var isActive: Bool
    public var scale: AppFilterScale = .xs
    public var onTap: () -> Void

    public init(title: String, isActive: Bool, scale: AppFilterScale = .xs, onTap: @escaping () -> Void = {}) {
        self.title = title
        self.isActive = isActive
        self.scale = scale
        self.onTap = onTap
    }

    private var height: CGFloat { scale == .xs ? AppFilterMetrics.xsHeight : AppFilterMetrics.sHeight }
    private var hpad: CGFloat  { scale == .xs ? AppFilterMetrics.xsHPad  : AppFilterMetrics.sHPad }

    public var body: some View {
        let label = Text(title.capitalized)
            .font(.system(size: 13, weight: .semibold))
            .kerning(0.1)
            .lineLimit(1)
            .minimumScaleFactor(0.95)

        Button(action: onTap) {
            label
                .foregroundStyle(
                    isActive
                    ? AnyShapeStyle(Color.black.opacity(0.92))
                    : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.92))
                )
                .padding(.horizontal, hpad)
                .frame(height: height, alignment: .center)
                .background(
                    ZStack {
                        let shape = Capsule(style: .continuous)
                        if isActive {
                            // active: accent-filled pill with soft gloss, matching accent CTA / favorite visuals
                            shape
                                .fill(ThemeManager.shared.currentAccentFill)
                            shape
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.06), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .blendMode(.plusLighter)
                            shape
                                .stroke(CD.ColorToken.stroke, lineWidth: 1.1)
                        } else {
                            // inactive: neutral glass pill, same base as cards / mini chips
                            shape
                                .fill(CD.ColorToken.card.opacity(0.78))
                            shape
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.05), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .blendMode(.plusLighter)
                            shape
                                .stroke(CD.ColorToken.stroke.opacity(0.9), lineWidth: 1)
                        }
                    }
                )
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
        .accessibilityLabel(title + (isActive ? ", выбран" : ", не выбран"))
    }
}

/// Horizontal filter chips (AppDS identity).
public struct AppFiltersBar: View {
    public var items: [AppFilterItem]
    public var scale: AppFilterScale
    public var onToggle: (UUID) -> Void

    public init(items: [AppFilterItem], scale: AppFilterScale = .s, onToggle: @escaping (UUID) -> Void = { _ in }) {
        self.items = items
        self.scale = scale
        self.onToggle = onToggle
    }

    public var body: some View {
        TaikaCarouselScroll {
            HStack(spacing: 10) {
                ForEach(items) { it in
                    AppFilterChip(title: it.title, isActive: it.isActive, scale: scale) {
                        onToggle(it.id)
                    }
                }
            }
        }
    }
}

/// Интерактивный фильтр в одну капсулу (справа от заголовка страницы):
/// показывает текущий выбор; по тапу — меню вариантов в айдентике AppDS.
public struct AppInlineFilterPicker: View {
    public var titles: [String]
    public var selectedIndex: Int
    public var onSelect: (Int) -> Void
    /// Если false — в закрытом чипе только стрелка (название видно в меню / в заголовке секции).
    public var showsSelectedTitle: Bool

    public init(
        titles: [String],
        selectedIndex: Int,
        showsSelectedTitle: Bool = true,
        onSelect: @escaping (Int) -> Void
    ) {
        self.titles = titles
        self.selectedIndex = selectedIndex
        self.showsSelectedTitle = showsSelectedTitle
        self.onSelect = onSelect
    }

    private var selectedTitle: String {
        guard titles.indices.contains(selectedIndex) else { return titles.first ?? "" }
        return titles[selectedIndex]
    }

    public var body: some View {
        Menu {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Button {
                    guard index != selectedIndex else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(index)
                } label: {
                    if index == selectedIndex {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if showsSelectedTitle {
                    Text(selectedTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(0.1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(ThemeManager.shared.currentAccentFill)
            .padding(.horizontal, showsSelectedTitle ? 12 : 10)
            .frame(height: 32)
            .frame(minWidth: showsSelectedTitle ? nil : 32)
            .background(
                ZStack {
                    let shape = Capsule(style: .continuous)
                    shape.fill(CD.ColorToken.card)
                    shape.fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
                    shape.stroke(Theme.Strokes.strokeStrong, lineWidth: Theme.Strokes.strokeLineWidth)
                }
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
        .accessibilityLabel(showsSelectedTitle ? "Фильтр: \(selectedTitle)" : "Фильтр категорий")
        .accessibilityHint("Выбрать раздел")
        .accessibilityValue(selectedTitle)
    }
}

/// Сегмент-фильтр в одной капсуле (legacy / оверлеи):
/// общая обводка, активный пункт — акцент-текст + мягкая внутренняя подложка.
/// Сегменты делят ширину экрана поровну (без горизонтального скролла).
public struct AppSegmentFilterBar: View {
    public var titles: [String]
    public var selectedIndex: Int
    public var onSelect: (Int) -> Void

    public init(titles: [String], selectedIndex: Int, onSelect: @escaping (Int) -> Void) {
        self.titles = titles
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
    }

    private let barHeight: CGFloat = 40
    private let innerInset: CGFloat = 3

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                let isOn = index == selectedIndex
                Button {
                    guard !isOn else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(index)
                } label: {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(0.1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(
                            isOn
                            ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                            : AnyShapeStyle(CD.ColorToken.text.opacity(0.88))
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight - innerInset * 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isOn ? CD.ColorToken.card.opacity(0.92) : Color.clear)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: isOn
                                                ? [Color.white.opacity(0.07), .clear]
                                                : [.clear, .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .blendMode(.plusLighter)
                                )
                        )
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.98))
                .accessibilityLabel(title + (isOn ? ", выбран" : ""))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(innerInset)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.42))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
        .padding(.horizontal, CD.Spacing.screen)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedIndex)
    }
}


#if DEBUG
// MARK: - Unified, tidy previews for the App Design System
private struct DSSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
            content()
        }
    }
}

struct AppDS_Previews: PreviewProvider {
    static var previews: some View {
        TabView {
            mainTab
                .tabItem { Label("main", systemImage: "square.grid.2x2") }

            statsTab
                .tabItem { Label("stats", systemImage: "chart.xyaxis.line") }
        }
    }

    private static var mainTab: some View {
        TaikaRootVerticalScroll {
            VStack(alignment: .leading, spacing: 24) {
                DSSection("Headers") {
                    VStack(spacing: 8) {
                        AppHeader()
                        AppBackHeader()
                    }
                }

                DSSection("Status chips") {
                    TaikaCarouselScroll {
                        HStack(spacing: 8) {
                            AppStatusChip(kind: .new, scale: .xs)
                            AppStatusChip(kind: .inProgress, scale: .xs)
                            AppStatusChip(kind: .completed, scale: .xs)
                            AppProChip()
                        }
                        .padding(.horizontal, 2)
                    }
                }

                // Stat chips section removed

                DSSection("Metric delta chips") {
                    let items: [AppMetricDeltaItem] = [
                        AppMetricDeltaItem(title: "пройдено", value: "1", delta: "+1"),
                        AppMetricDeltaItem(title: "начато", value: "2", delta: "+0"),
                        AppMetricDeltaItem(title: "активно", value: "3", delta: "+1")
                    ]
                    AppMetricDeltaRow(items: items, size: .m) { _ in }
                }

                DSSection("Console icon buttons") {
                    HStack(spacing: 10) {
                        AppConsoleIconButton(nav: .prev, state: .idle) {}
                        AppConsoleIconButton(nav: .next, state: .pressed) {}
                        AppConsoleIconButton(nav: .minus, state: .disabled) {}
                        AppConsoleIconButton(nav: .plus, state: .active) {}
                        AppConsoleIconButton(act: .play, state: .active, isEnabled: true, isActive: true) {}
                        AppConsoleIconButton(act: .modes, state: .idle, isEnabled: true) {}
                        AppConsoleIconButton(act: .chat, state: .idle, isEnabled: true) {}
                        AppConsoleIconButton(act: .info, state: .idle, isEnabled: true) {}
                        AppConsoleIconButton(act: .play, state: .disabled, isEnabled: false) {}
                    }
                }

                DSSection("Card icon buttons") {
                    HStack(spacing: 10) {
                        AppCardIconButton(kind: .favorite, isActive: false) {}
                        AppCardIconButton(kind: .favorite, isActive: true) {}
                        AppCardIconButton(kind: .console, isEnabled: false) {}
                        AppCardIconButton(kind: .console, isEnabled: true) {}
                        AppFavCounterButton(count: 0) {}
                        AppFavCounterButton(count: 3) {}
                        AppFavCounterButton(count: 12) {}
                    }
                }

                DSSection("Speaker icon buttons") {
                    HStack(spacing: 10) {
                        AppSpeakerIconButton(kind: .mic, isEnabled: true, isActive: false) {}
                        AppSpeakerIconButton(kind: .mic, isEnabled: true, isActive: true) {}
                        AppSpeakerIconButton(kind: .stop, isEnabled: true, isActive: true) {}
                        AppSpeakerIconButton(kind: .refresh, isEnabled: true, isActive: false) {}
                        AppSpeakerIconButton(kind: .clear, isEnabled: true, isActive: false) {}
                        AppSpeakerIconButton(kind: .user, isEnabled: false, isActive: false) {}
                    }
                }

                DSSection("Audio wave button") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            AppAudioWaveButton(isPlaying: false, width: 128, height: 34) {}
                            AppAudioWaveButton(isPlaying: true, width: 128, height: 34) {}
                        }
                        HStack(spacing: 10) {
                            AppAudioWaveButton(isPlaying: false, width: 160, height: 38) {}
                            AppAudioWaveButton(isPlaying: true, width: 160, height: 38) {}
                        }
                    }
                }

                DSSection("Progress") {
                    AppProgressBar(value: 0.62, height: 12)
                }

                DSSection("CTA — XS (unified)") {
                    VStack(spacing: 12) {
                        AppCTAButtons(primary: .start, scale: .xs, visual: .brandStatus)
                        AppCTAButtons(primary: .resume, scale: .xs, visual: .brandStatus)
                        AppCTAButtons(primary: .reinforce, secondary: .next, scale: .xs, unifiedWidth: true, visual: .brandStatus)
                    }
                    .padding(.horizontal, 2)
                }

                DSSection("CTA — S (unified)") {
                    VStack(spacing: 12) {
                        AppCTAButtons(primary: .start, scale: .s, unifiedWidth: true, visual: .brandDark)
                        AppCTAButtons(primary: .reinforce, secondary: .next, scale: .s, unifiedWidth: true, visual: .brandDark)
                    }
                    .padding(.horizontal, 2)
                }

                DSSection("CTA inside card") {
                    CardFooterRail {
                        AppCTAButtons(primary: .start, scale: .s, unifiedWidth: true, visual: .brandDark)
                    } right: {
                        AppCardIconButton(kind: .favorite, isActive: false) {}
                    }
                    .padding(.vertical, 6)
                }

                DSSection("Mini Chips") {
                    HStack(spacing: 8) {
                        AppMiniChip(title: "Запомнил", style: .accent) {}
                        AppMiniChip(title: "Слово", style: .neutral) {}
                    }
                }

                DSSection("Filters (template)") {
                    let demo: [AppFilterItem] = [
                        AppFilterItem(title: "все", isActive: true),
                        AppFilterItem(title: "грамматика", isActive: false),
                        AppFilterItem(title: "лексика", isActive: false),
                        AppFilterItem(title: "про", isActive: false)
                    ]
                    AppFiltersBar(items: demo, scale: .s) { _ in }
                        .padding(.horizontal, CD.Spacing.screen)
                }
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.bottom, CD.Spacing.screen)
        }
        .id(UUID())
        .background(CD.ColorToken.background.ignoresSafeArea())
        .environmentObject(ThemeManager.shared)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("AppDS — main")
    }

    private static var statsTab: some View {
        TaikaRootVerticalScroll {
            let heat: [CGFloat] = [0.0, 0.25, 0.0, 0.6, 1.0, 0.2, 0.8]
            let bars: [CGFloat] = [1, 2, 0.5, 3.4, 2.2, 4.0, 1.4]
            let spark: [CGFloat] = [1, 1.2, 1.1, 1.6, 1.4, 1.9, 1.7, 2.2, 2.0]

            VStack(alignment: .leading, spacing: 18) {
                // Stat chips section removed

                DSSection("Stat mini card") {
                    AppStatsMiniCard(
                        title: "моя активность",
                        subtitle: "последние 7 дней",
                        heat: heat,
                        bars: bars,
                        spark: spark,
                        progress: 0.42
                    )
                }

                DSSection("Graphs") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("heat")
                                    .font(.caption)
                                    .foregroundStyle(CD.ColorToken.textSecondary)
                                AppHeatRow(values: heat, size: 14, spacing: 8)
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                Text("bars")
                                    .font(.caption)
                                    .foregroundStyle(CD.ColorToken.textSecondary)
                                AppMiniBars(values: bars, height: 34, barWidth: 8, spacing: 6, style: .accent)
                            }
                        }

                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("spark")
                                    .font(.caption)
                                    .foregroundStyle(CD.ColorToken.textSecondary)
                                AppSparkline(values: spark, height: 34, lineWidth: 2, style: .neutral)
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                Text("donut")
                                    .font(.caption)
                                    .foregroundStyle(CD.ColorToken.textSecondary)
                                AppDonut(value: 0.62, size: 44, lineWidth: 7)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DSSection("Activity scenarios") {
                    // Intensity examples for 7 days (0..6)
                    let week: [AppActivityIntensity] = [.mid, .high, .low, .empty, .mid, .high, .low]

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("последние 7 дней")
                                .font(.caption)
                                .foregroundStyle(CD.ColorToken.textSecondary)
                            Spacer(minLength: 0)
                            Image(systemName: "info.circle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(CD.ColorToken.textSecondary)
                        }

                        AppActivityWeekRow(intensities: week, selectedIndex: 1) { _ in }

                        AppActivityDayNoteCard(
                            dayTitle: "вт",
                            summary: "1 урок • 6 шагов • 3 лайка",
                            intensity: .high,
                            events: [
                                AppActivityEvent(kind: .lesson, title: "урок пройден", subtitle: "арт и студии"),
                                AppActivityEvent(kind: .steps, title: "шаги", subtitle: "6"),
                                AppActivityEvent(kind: .like, title: "лайк", subtitle: "3 карточки"),
                                AppActivityEvent(kind: .addCourse, title: "добавлен курс", subtitle: "старт")
                            ],
                            onDetails: {}
                        )

                        AppActivityDayNoteCard(
                            dayTitle: "сегодня",
                            summary: "0 уроков • 0 шагов",
                            intensity: .empty,
                            events: [],
                            onDetails: {}
                        )
                    }
                }
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.bottom, CD.Spacing.screen)
        }
        .id(UUID())
        .background(CD.ColorToken.background.ignoresSafeArea())
        .environmentObject(ThemeManager.shared)
        .previewLayout(.sizeThatFits)
        .previewDisplayName("AppDS — stats")
    }
}

#endif

