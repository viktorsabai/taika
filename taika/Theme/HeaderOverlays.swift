//
//  HeaderOverlays.swift
//  taika
//
//  EPIC 2: Overlay views for header-driven actions (course filters, speaker filters, voice settings, game park).
//

import SwiftUI

// MARK: - Course filters state (shared between CourseView and CourseFiltersOverlayView)
@MainActor
public final class CourseFiltersState: ObservableObject {
    public static let shared = CourseFiltersState()

    @Published public var selectedPrimary: Int = -1
    @Published public var selectedSecondary: Int = -1
    @Published public var selectedCategory: Int = -1
    @Published public var showFilters: Bool = false
    @Published public var showCategories: Bool = false

    private init() {}
}

// MARK: - Speaker filter state (shared so overlay can set filter; SpeakerView applies it)
@MainActor
public final class SpeakerFilterState: ObservableObject {
    public static let shared = SpeakerFilterState()

    @Published public var selectedFilterId: UUID?

    private init() {}
}

// MARK: - Unified filter UI (один стиль секций и строк для Course и Speaker)
private struct OverlayFilterSectionView<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.easeOut(duration: 0.25)) { isExpanded.toggle() } }) {
                HStack {
                    Text(title.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(0.6)
                        .foregroundStyle(CD.ColorToken.textSecondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded {
                content()
            }
        }
    }
}

private struct OverlayFilterRowView: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CD.ColorToken.text)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CD.ColorToken.card.opacity(0.82))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Эталон оверлеев (как PRO корона: заблюренный тёмный фон + карточка в одной айдентике). Internal для использования в SearchOverlayView и др.
let overlayEtalonBackgroundOpacity: Double = 0.35

struct OverlayEtalonBackground: View {
    let onDismiss: () -> Void
    var body: some View {
        Color.black.opacity(overlayEtalonBackgroundOpacity)
            .ignoresSafeArea()
            .onTapGesture(perform: onDismiss)
    }
}

/// Карточка оверлея в стиле PRO: material + тёмный оверлей, скругление 28, обводка, тень.
struct OverlayEtalonCard<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.vertical, 16)

            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, y: 14)
        .frame(maxWidth: 420)
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
}

/// Карточка оверлея «чёрное стекло»: без серого material, только тёмное стекло.
struct OverlayBlackGlassCard<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.vertical, 16)

            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, y: 14)
        .frame(maxWidth: 420)
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
}

/// Кнопка в стиле эталона (как «перейти на pro»): акцент, скругление 18.
struct OverlayEtalonPrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ThemeManager.shared.currentAccentFill)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Вторичная кнопка (как «позже»): только текст.
struct OverlayEtalonSecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared overlay chrome (эталон: тот же стиль что PRO корона)
private struct UnifiedOverlayChrome<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        OverlayEtalonCard(title: title, onDismiss: onDismiss, content: content)
    }
}

// MARK: - Course Filters Overlay (тот же UI/UX что и Speaker: секции + строки)
struct CourseFiltersOverlayView: View {
    @ObservedObject private var state = CourseFiltersState.shared
    var onDismiss: () -> Void

    private let primaryTitles = ["Новый", "В процессе", "Завершено"]
    private let secondaryTitles = ["Free", "Pro"]

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Фильтры и категории", onDismiss: onDismiss) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        OverlayFilterSectionView(title: "Фильтры", isExpanded: $state.showFilters) {
                            VStack(spacing: 12) {
                                OverlayFilterRowView(
                                    title: "Все",
                                    isSelected: state.selectedPrimary < 0 && state.selectedSecondary < 0,
                                    onTap: {
                                        state.selectedPrimary = -1
                                        state.selectedSecondary = -1
                                    }
                                )
                                ForEach(Array(primaryTitles.enumerated()), id: \.offset) { i, title in
                                    OverlayFilterRowView(
                                        title: title,
                                        isSelected: state.selectedPrimary == i,
                                        onTap: { state.selectedPrimary = (state.selectedPrimary == i ? -1 : i) }
                                    )
                                }
                                ForEach(Array(secondaryTitles.enumerated()), id: \.offset) { i, title in
                                    OverlayFilterRowView(
                                        title: title,
                                        isSelected: state.selectedSecondary == i,
                                        onTap: { state.selectedSecondary = (state.selectedSecondary == i ? -1 : i) }
                                    )
                                }
                            }
                        }
                        let categories = courseCategoryChips()
                        if !categories.isEmpty {
                            OverlayFilterSectionView(title: "Категории", isExpanded: $state.showCategories) {
                                VStack(spacing: 12) {
                                    ForEach(Array(categories.enumerated()), id: \.offset) { i, title in
                                        OverlayFilterRowView(
                                            title: title,
                                            isSelected: state.selectedCategory == i,
                                            onTap: { state.selectedCategory = (state.selectedCategory == i ? -1 : i) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(CD.Spacing.screen)
                }
                .frame(maxHeight: 400)
            }
        }
    }
}

// MARK: - Course Search + Filters (unified overlay for Course tab)
struct CourseSearchAndFiltersOverlayView: View {
    @ObservedObject private var state = CourseFiltersState.shared
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var overlay: OverlayPresenter
    var onDismiss: () -> Void

    private let primaryChips = ["Новый", "В процессе", "Завершено"]
    private let secondaryChips = ["Free", "Pro"]

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Поиск и фильтры", onDismiss: onDismiss) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Button {
                            onDismiss()
                            overlay.presentSearch()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.8))
                                Text("Поиск по курсам и урокам")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.75))
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 44)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(CD.ColorToken.card.opacity(0.82))
                            )
                        }
                        .buttonStyle(.plain)

                        CourseFiltersOnlyContent()
                    }
                    .padding(CD.Spacing.screen)
                }
                .frame(maxHeight: 440)
            }
        }
    }
}

/// Reusable filters-only body (тот же UI что и CourseFiltersOverlayView)
private struct CourseFiltersOnlyContent: View {
    @ObservedObject private var state = CourseFiltersState.shared
    private let primaryTitles = ["Новый", "В процессе", "Завершено"]
    private let secondaryTitles = ["Free", "Pro"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OverlayFilterSectionView(title: "Фильтры", isExpanded: $state.showFilters) {
                VStack(spacing: 12) {
                    OverlayFilterRowView(title: "Все", isSelected: state.selectedPrimary < 0 && state.selectedSecondary < 0, onTap: { state.selectedPrimary = -1; state.selectedSecondary = -1 })
                    ForEach(Array(primaryTitles.enumerated()), id: \.offset) { i, title in
                        OverlayFilterRowView(title: title, isSelected: state.selectedPrimary == i, onTap: { state.selectedPrimary = (state.selectedPrimary == i ? -1 : i) })
                    }
                    ForEach(Array(secondaryTitles.enumerated()), id: \.offset) { i, title in
                        OverlayFilterRowView(title: title, isSelected: state.selectedSecondary == i, onTap: { state.selectedSecondary = (state.selectedSecondary == i ? -1 : i) })
                    }
                }
            }
            let categories = courseCategoryChips()
            if !categories.isEmpty {
                OverlayFilterSectionView(title: "Категории", isExpanded: $state.showCategories) {
                    VStack(spacing: 12) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { i, title in
                            OverlayFilterRowView(title: title, isSelected: state.selectedCategory == i, onTap: { state.selectedCategory = (state.selectedCategory == i ? -1 : i) })
                        }
                    }
                }
            }
        }
    }
}

private func courseCategoryChips() -> [String] {
    let known = ["Тайский для жизни", "На одной волне", "Тайский для души"]
    let all = loadCourseCategoriesFromBundle()
    var seen = Set<String>()
    var ordered: [String] = []
    for c in all {
        if seen.insert(c).inserted { ordered.append(c) }
    }
    let head = known.filter { ordered.contains($0) }
    let tail = ordered.filter { !known.contains($0) }.sorted()
    return head + tail
}

private func loadCourseCategoriesFromBundle() -> [String] {
    guard let url = Bundle.main.url(forResource: "taika_basa_course", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let courses = try? JSONDecoder().decode([Course].self, from: data) else { return [] }
    return courses.map(\.category).filter { $0 != "База от Тайки" }
}

// MARK: - Speaker Filters Overlay (тот же UI/UX что и Course: секция + строки)
struct SpeakerFiltersOverlayView: View {
    @ObservedObject private var state = SpeakerFilterState.shared
    @State private var sectionExpanded = true
    var onDismiss: () -> Void

    private let modes: [(SpeakerMode, String)] = [
        (.currentMode, "последний урок"),
        (.favoritesMode, "избранное"),
        (.learnedMode, "выученные"),
        (.randomMode, "случайные")
    ]

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Режим Speaker", onDismiss: onDismiss) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        OverlayFilterSectionView(title: "Режим", isExpanded: $sectionExpanded) {
                            VStack(spacing: 12) {
                                ForEach(modes, id: \.0.id) { mode, title in
                                    OverlayFilterRowView(
                                        title: title,
                                        isSelected: state.selectedFilterId == mode.id,
                                        onTap: {
                                            state.selectedFilterId = mode.id
                                            onDismiss()
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(CD.Spacing.screen)
                }
                .frame(maxHeight: 400)
            }
        }
    }
}

// MARK: - Favorites Filters Overlay (тот же UI/UX: секция + строки)
struct FavoritesFiltersOverlayView: View {
    @ObservedObject private var state = FavoritesFilterState.shared
    @State private var sectionExpanded = true
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Избранное", onDismiss: onDismiss) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        OverlayFilterSectionView(title: "Раздел", isExpanded: $sectionExpanded) {
                            VStack(spacing: 12) {
                                ForEach(FDK.allCases, id: \.id) { kind in
                                    OverlayFilterRowView(
                                        title: kind.rawValue,
                                        isSelected: state.selected == kind,
                                        onTap: {
                                            state.selected = kind
                                            onDismiss()
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(CD.Spacing.screen)
                }
                .frame(maxHeight: 400)
            }
        }
    }
}

// MARK: - Voice Settings Overlay (тот же стиль chrome, что и фильтры)
struct VoiceSettingsOverlayView: View {
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Голос Таики", onDismiss: onDismiss) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Скоро здесь можно будет выбрать голос для Таики (стандартный, для PRO — ещё варианты).")
                        .font(.system(size: 15))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                        .multilineTextAlignment(.leading)
                    OverlayEtalonPrimaryButton(title: "Закрыть", action: onDismiss)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CD.Spacing.screen)
            }
        }
    }
}

// MARK: - Accent Picker Overlay (тап на радугу в Profile — выбор цвета акцента)
struct AccentPickerOverlayView: View {
    @EnvironmentObject private var theme: ThemeManager
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Цвет акцента", onDismiss: onDismiss) {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        ForEach(ThemeManager.Accent.allCases, id: \.rawValue) { option in
                            Button {
                                theme.accent = option
                                #if os(iOS)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                            } label: {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(option.previewGradient)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(option == theme.accent ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                    Text(option.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(CD.ColorToken.text)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(CD.Spacing.screen)
                }
            }
        }
    }
}

/// Source for game park: main tab (learned steps) or favorites tab (favorite cards).
enum GameParkSource {
    case main
    case favorites
}

// MARK: - Game Park Overlay (random game from completed lesson or from favorites, or CTA)
struct GameParkOverlayView: View {
    var source: GameParkSource = .main
    @State private var selectedMode: GameModeType = .match
    @EnvironmentObject private var nav: NavigationIntent
    var onDismiss: () -> Void
    var onOpenCourses: () -> Void

    private var hasLearnedCards: Bool {
        let snap = UserSession.shared.snapshot
        return snap.learnedSteps.values.contains { !$0.isEmpty }
    }

    private var hasFavoriteCards: Bool {
        !FavoriteManager.shared.speakerStepIds().isEmpty
    }

    private var hasCards: Bool {
        switch source {
        case .main: return hasLearnedCards
        case .favorites: return hasFavoriteCards
        }
    }

    private var randomLearnedLesson: (courseId: String, lessonId: String)? {
        let snap = UserSession.shared.snapshot
        let keys = snap.learnedSteps.keys.filter { !(snap.learnedSteps[$0] ?? []).isEmpty }
        guard !keys.isEmpty, let key = keys.randomElement() else { return nil }
        let parts = key.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        if parts.count >= 2 {
            return (parts[0], parts[1])
        }
        return nil
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            if hasCards {
                let showPicker = (source == .main && randomLearnedLesson != nil) || source == .favorites
                if showPicker {
                    OverlayEtalonCard(title: "Выбери режим", onDismiss: onDismiss) {
                        GameModePickerDS(
                            selected: $selectedMode,
                            isProUser: ProManager.shared.isPro,
                            onStart: { gameType in
                                onDismiss()
                                switch source {
                                case .main:
                                    if let lesson = randomLearnedLesson {
                                        nav.go(.game(courseId: lesson.courseId, lessonId: lesson.lessonId, gameType: gameType.rawValue))
                                    }
                                case .favorites:
                                    nav.go(.game(courseId: "__favorites__", lessonId: nil, gameType: gameType.rawValue))
                                }
                            },
                            onClose: onDismiss,
                            embedInEtalon: false
                        )
                    }
                } else {
                    emptyState
                }
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        UnifiedOverlayChrome(title: "Игровой парк", onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 24))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(emptyTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text)
                        Text(emptyMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(CD.ColorToken.card.opacity(0.82)))
                Button(emptyButtonTitle) {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    onOpenCourses()
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(ThemeManager.shared.currentAccentFill))
                .foregroundStyle(.white)
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CD.Spacing.screen)
        }
    }

    private var emptyTitle: String {
        switch source {
        case .main: return "Пройди хотя бы один урок"
        case .favorites: return "Добавь карточки в избранное"
        }
    }

    private var emptyMessage: String {
        switch source {
        case .main: return "Чтобы запустить игру из главной, нужно выучить карточки в любом уроке."
        case .favorites: return "Чтобы играть из избранного, добавь слова или фразы в избранное в уроках."
        }
    }

    private var emptyButtonTitle: String {
        switch source {
        case .main: return "Перейти к курсам"
        case .favorites: return "Перейти к курсам"
        }
    }
}
