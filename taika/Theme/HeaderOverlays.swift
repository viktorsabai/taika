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
    // legacy: used by the older row-based overlay; keep expanded by default (MVP UX)
    @Published public var showFilters: Bool = true
    @Published public var showCategories: Bool = true

    private init() {}
}

// MARK: - Speaker filter state (shared so overlay can set filter; SpeakerView applies it)
@MainActor
public final class SpeakerFilterState: ObservableObject {
    public static let shared = SpeakerFilterState()

    @Published public var selectedFilterId: UUID?

    private init() {}
}

// MARK: - Unified filter UI (секции + AppFilterChip для Course / Speaker / Favorites)
private struct OverlayFilterSectionView<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let summary: String?
    let content: () -> Content

    init(
        title: String,
        isExpanded: Binding<Bool>,
        summary: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.summary = summary
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.easeOut(duration: 0.25)) { isExpanded.toggle() } }) {
                HStack {
                    Text(title.uppercased())
                        .taikaSectionTitleStyle()
                    Spacer()
                    if !isExpanded, let s = summary?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                        Text(s)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.75))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
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

// MARK: - Эталон оверлеев: тёмный blur-scrim + чёрное глянцевое стекло.
let overlayEtalonBackgroundOpacity: Double = 0.34

struct OverlayEtalonBackground: View {
    let onDismiss: () -> Void
    var body: some View {
        GlassBackdrop(onDismiss: onDismiss)
    }
}

/// Shared informational overlay frame. The material/header geometry is unified;
/// the role only describes the content density, never a separate visual system.
enum OverlayEtalonCardRole {
    case message
    case choice
    case quota
    case workbench
}

/// Compact = узкая карточка; hub = почти fullscreen центр (закрепление / park).
enum OverlayEtalonLayout {
    case compact
    case hub
}

struct OverlayEtalonCard<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    let role: OverlayEtalonCardRole
    /// Game Park uses the surrounding canvas as its placement context; legacy
    /// overlays keep the root-header clearance for compatibility.
    var usesContextPlacement: Bool = false
    var layout: OverlayEtalonLayout = .compact
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        onDismiss: @escaping () -> Void,
        role: OverlayEtalonCardRole = .message,
        usesContextPlacement: Bool = false,
        layout: OverlayEtalonLayout = .compact,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onDismiss = onDismiss
        self.role = role
        self.usesContextPlacement = usesContextPlacement
        self.layout = layout
        self.content = content
    }

    private var titleSize: CGFloat {
        switch role {
        case .message, .choice, .quota, .workbench: return 18
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(CD.ColorToken.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть")
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.top, 18)
            .padding(.bottom, 14)

            content()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: layout == .hub ? .infinity : nil,
                    alignment: .top
                )
        }
        .background {
            RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.cardRadius, style: .continuous)
                .fill(Color.black.opacity(TaikaOverlayTokens.Material.cardOpacity))
                .background {
                    RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.cardRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.46))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.cardRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(TaikaOverlayTokens.Material.strokeOpacity), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: TaikaOverlayTokens.Layout.cardRadius, style: .continuous))
        .frame(maxWidth: layout == .hub ? .infinity : 420)
        .frame(maxHeight: layout == .hub ? .infinity : nil)
        .padding(.horizontal, layout == .hub ? 12 : 20)
        .padding(
            .top,
            layout == .hub
                ? max(10, Theme.Layout.rootHeaderClearance * 0.45)
                : (usesContextPlacement ? 0 : Theme.Layout.rootHeaderClearance)
        )
        .padding(.bottom, layout == .hub ? 10 : 0)
        .safeAreaPadding(.bottom, layout == .hub ? 6 : 0)
    }
}

/// Alias: тот же канон чёрного стекла (раньше был flat black без gloss).
struct OverlayBlackGlassCard<Content: View>: View {
    let title: String
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        OverlayEtalonCard(title: title, onDismiss: onDismiss, content: content)
    }
}

/// Кнопка в стиле эталона (как «перейти на pro»): акцент, скругление 18.
struct OverlayEtalonPrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        OverlayGlassPrimaryButton(title: title, action: action)
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
    let role: OverlayEtalonCardRole
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        onDismiss: @escaping () -> Void,
        role: OverlayEtalonCardRole = .message,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onDismiss = onDismiss
        self.role = role
        self.content = content
    }

    var body: some View {
        OverlayEtalonCard(title: title, onDismiss: onDismiss, role: role, content: content)
    }
}

// MARK: - Course Filters Overlay (тот же UI/UX что и Speaker: секции + строки)
struct CourseFiltersOverlayView: View {
    @ObservedObject private var state = CourseFiltersState.shared
    var onDismiss: () -> Void

    private let primaryTitles = ["Новый", "В процессе", "Завершено"]
    private let secondaryTitles = ["Free", "Pro"]

    private var filtersSummary: String {
        var parts: [String] = []
        if state.selectedPrimary >= 0, state.selectedPrimary < primaryTitles.count {
            parts.append(primaryTitles[state.selectedPrimary])
        }
        if state.selectedSecondary >= 0, state.selectedSecondary < secondaryTitles.count {
            parts.append(secondaryTitles[state.selectedSecondary])
        }
        return parts.isEmpty ? "Все" : parts.joined(separator: " · ")
    }

    private var categorySummary: String {
        let cats = courseCategoryChips()
        guard state.selectedCategory >= 0, state.selectedCategory < cats.count else { return "Все" }
        return cats[state.selectedCategory]
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Фильтры и категории", onDismiss: onDismiss) {
                VStack(spacing: 12) {
                    TaikaRootVerticalScroll {
                        VStack(alignment: .leading, spacing: 20) {
                            OverlayFilterSectionView(title: "Фильтры", isExpanded: $state.showFilters, summary: filtersSummary) {
                                TaikaCarouselScroll {
                                    HStack(spacing: 10) {
                                        AppFilterChip(
                                            title: "Все",
                                            isActive: state.selectedPrimary < 0 && state.selectedSecondary < 0,
                                            scale: .s
                                        ) {
                                            state.selectedPrimary = -1
                                            state.selectedSecondary = -1
                                        }
                                        ForEach(Array(primaryTitles.enumerated()), id: \.offset) { i, title in
                                            AppFilterChip(
                                                title: title,
                                                isActive: state.selectedPrimary == i,
                                                scale: .s
                                            ) {
                                                state.selectedPrimary = (state.selectedPrimary == i ? -1 : i)
                                            }
                                        }
                                        ForEach(Array(secondaryTitles.enumerated()), id: \.offset) { i, title in
                                            AppFilterChip(
                                                title: title,
                                                isActive: state.selectedSecondary == i,
                                                scale: .s
                                            ) {
                                                state.selectedSecondary = (state.selectedSecondary == i ? -1 : i)
                                            }
                                        }
                                    }
                                }
                            }
                            let categories = courseCategoryChips()
                            if !categories.isEmpty {
                                OverlayFilterSectionView(title: "Категории", isExpanded: $state.showCategories, summary: categorySummary) {
                                    TaikaCarouselScroll {
                                        HStack(spacing: 10) {
                                            ForEach(Array(categories.enumerated()), id: \.offset) { i, title in
                                                AppFilterChip(
                                                    title: title,
                                                    isActive: state.selectedCategory == i,
                                                    scale: .s
                                                ) {
                                                    state.selectedCategory = (state.selectedCategory == i ? -1 : i)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(CD.Spacing.screen)
                    }

                    HStack(alignment: .center, spacing: 10) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                state.selectedPrimary = -1
                                state.selectedSecondary = -1
                                state.selectedCategory = -1
                            }
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                                .frame(width: 46, height: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(CD.ColorToken.card.opacity(0.70))
                                        .background(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.9)), lineWidth: 1.2)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Сбросить фильтры")
                        Spacer(minLength: 0)
                        OverlayEtalonPrimaryButton(title: "Готово") { onDismiss() }
                    }
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: 440)
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

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Поиск и фильтры", onDismiss: onDismiss, role: .workbench) {
                TaikaRootVerticalScroll {
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
                VStack(alignment: .leading, spacing: 12) {
                    filterChipsRow {
                        AppFilterChip(
                            title: "Все",
                            isActive: state.selectedPrimary < 0 && state.selectedSecondary < 0,
                            scale: .s
                        ) {
                            state.selectedPrimary = -1
                            state.selectedSecondary = -1
                        }
                        ForEach(Array(primaryTitles.enumerated()), id: \.offset) { i, title in
                            AppFilterChip(
                                title: title,
                                isActive: state.selectedPrimary == i,
                                scale: .s
                            ) {
                                state.selectedPrimary = (state.selectedPrimary == i ? -1 : i)
                            }
                        }
                        ForEach(Array(secondaryTitles.enumerated()), id: \.offset) { i, title in
                            AppFilterChip(
                                title: title,
                                isActive: state.selectedSecondary == i,
                                scale: .s
                            ) {
                                state.selectedSecondary = (state.selectedSecondary == i ? -1 : i)
                            }
                        }
                    }
                }
            }
            let categories = courseCategoryChips()
            if !categories.isEmpty {
                OverlayFilterSectionView(title: "Категории", isExpanded: $state.showCategories) {
                    filterChipsRow {
                        ForEach(Array(categories.enumerated()), id: \.offset) { i, title in
                            AppFilterChip(
                                title: title,
                                isActive: state.selectedCategory == i,
                                scale: .s
                            ) {
                                state.selectedCategory = (state.selectedCategory == i ? -1 : i)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func filterChipsRow<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        TaikaCarouselScroll {
            HStack(spacing: 10) {
                content()
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

// MARK: - Speaker attempts overlay (лимит на сегодня — не фильтры режима)
struct SpeakerAttemptsOverlayView: View {
    @ObservedObject private var trainingAttempts = SpeakerDailyAttemptsStore.shared
    @ObservedObject private var conversationAttempts = SpeakerConversationAttemptsStore.shared
    @ObservedObject private var speaker = SpeakerManager.shared
    @ObservedObject private var pro = ProManager.shared
    var onDismiss: () -> Void

    private var isConversation: Bool {
        speaker.speakerUIMode == .conversation
    }

    private var remaining: Int {
        isConversation ? conversationAttempts.remainingToday : trainingAttempts.remainingToday
    }

    private var used: Int {
        isConversation ? conversationAttempts.usedToday : trainingAttempts.usedToday
    }

    private var limitLabel: String {
        isConversation ? "\(conversationAttempts.dailyLimit)" : "\(trainingAttempts.dailyLimit)"
    }

    private var modeTitle: String {
        isConversation ? "Скажи сам" : "Закрепление курсов"
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Попытки сегодня", onDismiss: onDismiss, role: .quota) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(modeTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(pro.isPro ? "∞" : "\(remaining)")
                            .font(.system(size: 40, weight: .bold).monospacedDigit())
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        Text(pro.isPro ? "без лимита" : "из \(limitLabel)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                        Spacer(minLength: 0)
                    }

                    Text(
                        pro.isPro
                        ? "С Taika+ попытки не заканчиваются — тренируйся сколько нужно."
                        : "В режиме «\(modeTitle)» у free‑аккаунта \(limitLabel) попыток в день. Завтра лимит обновится."
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PD.ColorToken.text.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                    if !pro.isPro {
                        Text("Сегодня использовано: \(used)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onDismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                OverlayPresenter.shared.presentPro(reason: .speakerBreakdown)
                            }
                        } label: {
                            Text("Открыть Taika+")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(ThemeManager.shared.currentAccentFill)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(CD.Spacing.screen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            trainingAttempts.refreshDayIfNeeded()
            conversationAttempts.refreshDayIfNeeded()
        }
    }
}

// MARK: - Speaker courses overlay (канон: курсы + уроки + старт)

private struct SpeakerCoursesInsetGroup<Content: View>: View {
    let content: Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) { content }
            .background(shape.fill(PD.ColorToken.card.opacity(0.52)))
            .overlay(shape.stroke(PD.ColorToken.stroke.opacity(0.42), lineWidth: 1))
            .clipShape(shape)
    }
}

@ViewBuilder
private func speakerCoursesInsetGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    SpeakerCoursesInsetGroup(content: content())
}

private func speakerCoursesInsetDivider(leading: CGFloat = 14) -> some View {
    Rectangle()
        .fill(PD.ColorToken.stroke.opacity(0.32))
        .frame(height: 1)
        .padding(.leading, leading)
}

struct SpeakerCoursesOverlayView: View {
    @ObservedObject private var speaker = SpeakerManager.shared
    @State private var selectedCourseIds: Set<String>? = nil
    @State private var selectedLessonIdsByCourse: [String: Set<String>] = [:]
    @State private var expandedCourseId: String? = nil
    var onDismiss: () -> Void

    private var options: [SpeakerTrainingCourseOption] {
        speaker.learnedTrainingCourseOptions().sorted { $0.count > $1.count }
    }

    private var selected: Set<String> {
        selectedCourseIds ?? Set(options.map(\.id))
    }

    private func defaultLessons(for courseId: String) -> Set<String> {
        Set(speaker.learnedTrainingLessonOptions(courseId: courseId).map(\.id))
    }

    private var selectedLessonIds: Set<String> {
        var out = Set<String>()
        for cid in selected {
            let available = defaultLessons(for: cid)
            let picked = selectedLessonIdsByCourse[cid] ?? available
            out.formUnion(picked.intersection(available))
        }
        return out
    }

    private var selectedTotal: Int {
        var total = 0
        for cid in selected {
            let lessons = speaker.learnedTrainingLessonOptions(courseId: cid)
            let picked = selectedLessonIdsByCourse[cid] ?? defaultLessons(for: cid)
            total += lessons.filter { picked.contains($0.id) }.reduce(0) { $0 + $1.count }
        }
        return total
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Курсы для тренировки", onDismiss: onDismiss, role: .workbench) {
                TaikaRootVerticalScroll {
                    VStack(alignment: .leading, spacing: 16) {
                        let favCount = speaker.trainingFavoritesCount()
                        let dictCount = speaker.trainingDictionaryCount()
                        speakerCoursesInsetGroup {
                            overlayPoolRow(
                                title: "Избранное",
                                count: favCount,
                                enabled: favCount > 0
                            ) {
                                speaker.startSpecialTraining(poolId: "__favorites__")
                                SpeakerFilterState.shared.selectedFilterId = nil
                                onDismiss()
                            }
                            speakerCoursesInsetDivider()
                            overlayPoolRow(
                                title: "Словарь",
                                count: dictCount,
                                enabled: dictCount > 0
                            ) {
                                speaker.startSpecialTraining(poolId: "__dictionary__")
                                SpeakerFilterState.shared.selectedFilterId = nil
                                onDismiss()
                            }
                        }

                        if options.isEmpty {
                            Text("Пройди пару шагов в уроке — фразы появятся здесь для тренировки. Или жми Избранное / Словарь выше.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(selectedTotal) \(Self.phraseUnit(selectedTotal))")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                                Spacer(minLength: 8)
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if selected.count == options.count {
                                        selectedCourseIds = []
                                        selectedLessonIdsByCourse = [:]
                                        expandedCourseId = nil
                                    } else {
                                        let all = Set(options.map(\.id))
                                        selectedCourseIds = all
                                        var map: [String: Set<String>] = [:]
                                        for cid in all { map[cid] = defaultLessons(for: cid) }
                                        selectedLessonIdsByCourse = map
                                    }
                                } label: {
                                    Text(selected.count == options.count ? "снять всё" : "выбрать все")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }

                            speakerCoursesInsetGroup {
                                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                                    courseBlock(option: option)
                                    if index < options.count - 1 {
                                        speakerCoursesInsetDivider(leading: 44)
                                    }
                                }
                            }

                            OverlayEtalonPrimaryButton(title: "Начать тренировку") {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if speaker.speakerUIMode != .training {
                                    speaker.setSpeakerUIMode(.training)
                                }
                                let lessons = selectedLessonIds
                                speaker.startTraining(
                                    withCourseIds: selected,
                                    lessonIds: lessons.isEmpty ? nil : lessons
                                )
                                SpeakerFilterState.shared.selectedFilterId = nil
                                onDismiss()
                            }
                            .disabled(selectedTotal == 0)
                            .opacity(selectedTotal == 0 ? 0.45 : 1)
                        }
                    }
                    .padding(CD.Spacing.screen)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.58)
            }
        }
        .onAppear {
            if selectedCourseIds == nil {
                let all = Set(options.map(\.id))
                selectedCourseIds = all
                var map: [String: Set<String>] = [:]
                for cid in all { map[cid] = defaultLessons(for: cid) }
                selectedLessonIdsByCourse = map
            }
        }
    }

    private func courseBlock(option: SpeakerTrainingCourseOption) -> some View {
        let isSelected = selected.contains(option.id)
        let isExpanded = expandedCourseId == option.id
        let lessons = speaker.learnedTrainingLessonOptions(courseId: option.id)
        let picked = selectedLessonIdsByCourse[option.id] ?? defaultLessons(for: option.id)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    var updated = selected
                    if updated.contains(option.id) {
                        updated.remove(option.id)
                        selectedLessonIdsByCourse[option.id] = []
                        if expandedCourseId == option.id { expandedCourseId = nil }
                    } else {
                        updated.insert(option.id)
                        selectedLessonIdsByCourse[option.id] = defaultLessons(for: option.id)
                    }
                    selectedCourseIds = updated
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                            ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                            : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.38))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        if expandedCourseId == option.id {
                            expandedCourseId = nil
                        } else {
                            expandedCourseId = option.id
                            if selectedLessonIdsByCourse[option.id] == nil {
                                selectedLessonIdsByCourse[option.id] = defaultLessons(for: option.id)
                            }
                            var updated = selected
                            updated.insert(option.id)
                            selectedCourseIds = updated
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(option.title)
                            .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(PD.ColorToken.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 8)
                        Text("\(option.count) \(Self.phraseUnit(option.count))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.55))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            if isExpanded, !lessons.isEmpty {
                ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                    if index > 0 {
                        speakerCoursesInsetDivider(leading: 44)
                    }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        var next = picked
                        if next.contains(lesson.id) {
                            next.remove(lesson.id)
                        } else {
                            next.insert(lesson.id)
                        }
                        selectedLessonIdsByCourse[option.id] = next
                        var courses = selected
                        if next.isEmpty {
                            courses.remove(option.id)
                        } else {
                            courses.insert(option.id)
                        }
                        selectedCourseIds = courses
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: picked.contains(lesson.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(
                                    picked.contains(lesson.id)
                                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                    : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.35))
                                )
                            Text(lesson.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PD.ColorToken.text.opacity(0.92))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Text("\(lesson.count)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .monospacedDigit()
                        }
                        .padding(.leading, 44)
                        .padding(.trailing, 14)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func overlayPoolRow(
        title: String,
        count: Int,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard enabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                    Text(enabled ? "\(count) \(Self.phraseUnit(count))" : "пусто")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    private static func phraseUnit(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1, mod100 != 11 { return "фраза" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "фразы" }
        return "фраз"
    }
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
                TaikaRootVerticalScroll {
                    VStack(alignment: .leading, spacing: 20) {
                        OverlayFilterSectionView(title: "Режим", isExpanded: $sectionExpanded) {
                            TaikaCarouselScroll {
                                HStack(spacing: 10) {
                                    ForEach(modes, id: \.0.id) { mode, title in
                                        AppFilterChip(
                                            title: title,
                                            isActive: state.selectedFilterId == mode.id,
                                            scale: .s
                                        ) {
                                            state.selectedFilterId = mode.id
                                            onDismiss()
                                        }
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

// MARK: - Favorites Filters Overlay (тот же UI/UX: секция + строки)
struct FavoritesFiltersOverlayView: View {
    @ObservedObject private var state = FavoritesFilterState.shared
    @State private var sectionExpanded = true
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Избранное", onDismiss: onDismiss) {
                TaikaRootVerticalScroll {
                    VStack(alignment: .leading, spacing: 20) {
                        OverlayFilterSectionView(title: "Раздел", isExpanded: $sectionExpanded) {
                            TaikaCarouselScroll {
                                HStack(spacing: 10) {
                                    ForEach(FavoriteScreenTab.mvpTabs) { tab in
                                        AppFilterChip(
                                            title: tab.title,
                                            isActive: state.selectedTab == tab,
                                            scale: .s
                                        ) {
                                            state.selectedTab = tab
                                            onDismiss()
                                        }
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
    case dictionary
}

// MARK: - Game Park Overlay → единый «Выбери режим» (без отдельного «Игрового парка»)
struct GameParkOverlayView: View {
    var source: GameParkSource = .main
    /// When set (from Main reinforce pick), park uses this course instead of «all learned».
    var courseId: String? = nil
    @State private var selectedMode: GameModeType = .match
    @EnvironmentObject private var nav: NavigationIntent
    var onDismiss: () -> Void
    var onOpenCourses: () -> Void

    private var resolvedCourseId: String {
        if let courseId, !courseId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return courseId
        }
        switch source {
        case .main: return LearnedGameSource.pseudoCourseId
        case .favorites: return "__favorites__"
        case .dictionary: return DictionaryGameSource.courseId
        }
    }

    private var hasLearnedCards: Bool {
        LearnedGameSource.hasPlayableCards
    }

    private var hasFavoriteCards: Bool {
        !FavoritesGameSource.triples().isEmpty
    }

    private var hasCourseCards: Bool {
        guard let courseId, !courseId.isEmpty else { return false }
        var lessons = LessonsData.shared.lessons(for: courseId)
        if lessons.isEmpty {
            lessons = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "_", with: "-"))
        }
        if lessons.isEmpty {
            lessons = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "-", with: "_"))
        }
        let lessonIds = lessons.map(\.lessonID)
        guard !lessonIds.isEmpty else { return false }
        return !HomeTaskManager().userTriplesForCourse(courseId: courseId, lessonIds: lessonIds).isEmpty
    }

    private var hasCards: Bool {
        if courseId != nil { return hasCourseCards }
        switch source {
        case .main: return hasLearnedCards
        case .favorites: return hasFavoriteCards
        case .dictionary: return DictionaryGameSource.hasPlayableCards
        }
    }

    var body: some View {
        if hasCards {
            GameModePickerDS(
                selected: $selectedMode,
                isProUser: ProManager.shared.isPro,
                onStart: { mode in
                    onDismiss()
                    nav.go(.game(
                        courseId: resolvedCourseId,
                        lessonId: nil,
                        gameType: mode.rawValue
                    ))
                },
                onClose: onDismiss,
                onLockedTap: { mode in
                    if mode.isPro && !ProManager.shared.isPro {
                        onDismiss()
                        OverlayPresenter.shared.presentPro(reason: .games)
                    }
                },
                modes: GameModeType.modesLessonAndPark,
                onSpeaker: speakerAction
            )
        } else {
            gameParkEmptyState
        }
    }

    private var speakerAction: (() -> Void)? {
        switch source {
        case .main:
            if let courseId, !courseId.isEmpty, !LearnedGameSource.isPseudoCourseId(courseId) {
                return {
                    onDismiss()
                    SpeakerManager.shared.setSpeakerUIMode(.training)
                    SpeakerRequestedCourseId.shared.set(courseId)
                    SpeakerReturnContext.shared.saveFromRootTab(0)
                    nav.requestTab(2)
                }
            }
            return {
                onDismiss()
                SpeakerManager.shared.setSpeakerUIMode(.training)
                SpeakerManager.shared.prepareTrainingPoolIfNeeded()
                SpeakerManager.shared.applyFilter(SpeakerMode.learnedMode.id)
                SpeakerReturnContext.shared.saveFromRootTab(0)
                nav.requestTab(2)
            }
        case .favorites:
            return {
                onDismiss()
                SpeakerManager.shared.setSpeakerUIMode(.training)
                SpeakerRequestedCourseId.shared.set("__favorites__")
                SpeakerManager.shared.startSpecialTraining(poolId: "__favorites__")
                SpeakerReturnContext.shared.saveFromRootTab(3)
                nav.requestTab(2)
            }
        case .dictionary:
            return {
                onDismiss()
                SpeakerManager.shared.setSpeakerUIMode(.training)
                SpeakerRequestedCourseId.shared.set("__dictionary__")
                DictionarySessionSelection.shared.activate(nil)
                SpeakerManager.shared.startSpecialTraining(poolId: "__dictionary__")
                SpeakerReturnContext.shared.saveFromRootTab(3)
                nav.requestTab(2)
            }
        }
    }

    private var gameParkEmptyState: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            OverlayEtalonCard(title: "Закрепление", onDismiss: onDismiss, role: .message) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(emptyCopy)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onDismiss()
                        onOpenCourses()
                    }) {
                        Text(source == .main ? "К курсам" : "К карточкам")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ThemeManager.shared.currentAccentFill)
                            )
                    }
                    .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))

                    Button("Позже") {
                        onDismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 20)
            }
        }
    }

    private var emptyCopy: String {
        switch source {
        case .main:
            return "Пока мало выученных фраз для игры. Пройди урок — и возвращайся закрепить."
        case .favorites:
            return "В избранном пока пусто. Сохрани фразы — и можно тренироваться."
        case .dictionary:
            return "В словаре пока пусто. Добавь фразы из «Скажи сам»."
        }
    }
}

// MARK: - Reinforce hub (Main): fullscreen park — pool / speaker / games

struct ReinforcePickOverlayView: View {
    struct CourseRow: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
    }

    private enum Pool: Equatable {
        case allLearned
        case course(String)
    }

    let courses: [CourseRow]
    var hasAllLearnedPool: Bool
    var onDismiss: () -> Void
    /// courseId for `nav.go(.game)` — `LearnedGameSource.pseudoCourseId` for all learned.
    var onStartGame: (String, GameModeType) -> Void
    /// Speaker reinforcement for the selected pool (`nil` courseId → open free conversation).
    var onStartSpeaker: (String?) -> Void
    var onOpenCourses: () -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @State private var selectedPool: Pool?

    private var isEmpty: Bool {
        !hasAllLearnedPool && courses.isEmpty
    }

    private var resolvedCourseId: String? {
        switch selectedPool {
        case .allLearned: return LearnedGameSource.pseudoCourseId
        case .course(let id): return id
        case .none: return nil
        }
    }

    /// Real catalog course for Speaker training; all-learned opens conversation without scope.
    private var speakerCourseId: String? {
        switch selectedPool {
        case .course(let id): return id
        case .allLearned, .none: return nil
        }
    }

    private var poolHasCards: Bool {
        switch selectedPool {
        case .allLearned:
            return LearnedGameSource.hasPlayableCards
        case .course(let courseId):
            return Self.courseHasPlayableCards(courseId)
        case .none:
            return false
        }
    }

    private var isProUser: Bool { ProManager.shared.isPro }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            OverlayEtalonCard(
                title: "Закрепление",
                onDismiss: onDismiss,
                role: .workbench,
                layout: .hub
            ) {
                if isEmpty {
                    emptyBody
                } else {
                    hubBody
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { seedDefaultPool() }
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Сначала пройди курс или отметь карточки выученными — потом здесь появятся варианты закрепления.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismiss()
                onOpenCourses()
            } label: {
                Text("К курсам")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule(style: .continuous).fill(theme.currentAccentFill))
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var hubBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Выбери набор и способ — голос или игра")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // A — scope (selection stays on screen)
                reinforceZone(
                    title: "Что повторить",
                    caption: "Набор карточек для закрепления"
                ) {
                    VStack(spacing: 10) {
                        if hasAllLearnedPool {
                            poolRow(
                                title: "Все выученные",
                                subtitle: "Карточки из всех курсов",
                                isSelected: selectedPool == .allLearned
                            ) {
                                selectedPool = .allLearned
                            }
                        }

                        ForEach(courses) { course in
                            poolRow(
                                title: course.title,
                                subtitle: course.subtitle.isEmpty ? "Пройденный курс" : course.subtitle,
                                isSelected: selectedPool == .course(course.id)
                            ) {
                                selectedPool = .course(course.id)
                            }
                        }
                    }
                }

                if selectedPool != nil {
                    // B — Speaker as separate feature
                    reinforceZone(
                        title: "Спикер",
                        caption: "Отдельная фича · голос, не игра"
                    ) {
                        speakerFeatureCard
                    }

                    // C — Games park
                    reinforceZone(
                        title: "Игры",
                        caption: poolHasCards
                            ? "Режимы на выбранном наборе"
                            : "Пока мало карточек — сначала Спикер"
                    ) {
                        if poolHasCards {
                            VStack(spacing: 10) {
                                ForEach(GameModeType.modesLessonAndPark, id: \.self) { mode in
                                    gameModeRow(mode)
                                }
                            }
                        } else {
                            Text("В этом наборе ещё мало фраз для игр.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding(.horizontal, CD.Spacing.screen)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func reinforceZone<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                ReinforceSectionLabel(title)
                Text(caption)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.88))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var speakerFeatureCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onDismiss()
            onStartSpeaker(speakerCourseId)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(theme.currentAccentFill.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.currentAccentFill)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Тренировка вслух")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Произношение и тоны по выбранному набору")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PD.ColorToken.card.opacity(0.88))
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.42, blue: 0.78),
                                Color(red: 0.68, green: 0.42, blue: 1.0).opacity(0.68)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, 12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.currentAccentFill.opacity(0.42), lineWidth: 1.2)
            )
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
        .accessibilityLabel("Спикер: закрепить произношение и тоны")
    }

    private func poolRow(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ReinforceOptionRow(
                title: title,
                subtitle: subtitle,
                isSelected: isSelected,
                trailing: .selection
            )
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func gameModeRow(_ mode: GameModeType) -> some View {
        let locked = mode.isPro && !isProUser
        Button {
            if locked {
                onDismiss()
                OverlayPresenter.shared.presentPro(reason: .games)
                return
            }
            guard let courseId = resolvedCourseId else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onDismiss()
            onStartGame(courseId, mode)
        } label: {
            ReinforceOptionRow(
                title: mode.title,
                subtitle: locked ? "нужен PRO" : gameSubtitle(mode),
                isLocked: locked,
                showsProCrown: mode.isPro,
                trailing: locked ? .none : .chevron
            )
        }
        .buttonStyle(.plain)
    }

    private func gameSubtitle(_ mode: GameModeType) -> String {
        switch mode {
        case .match: return "закрепление через поиск пар"
        case .recall: return "активное вспоминание в формате sprint"
        case .audioRecall: return "слушай реплику, собери перевод"
        case .grandDialogue: return "полный диалог курса"
        }
    }

    private func seedDefaultPool() {
        guard selectedPool == nil else { return }
        if hasAllLearnedPool {
            selectedPool = .allLearned
        } else if let first = courses.first {
            selectedPool = .course(first.id)
        }
    }

    private static func courseHasPlayableCards(_ courseId: String) -> Bool {
        var lessons = LessonsData.shared.lessons(for: courseId)
        if lessons.isEmpty {
            lessons = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "_", with: "-"))
        }
        if lessons.isEmpty {
            lessons = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "-", with: "_"))
        }
        let lessonIds = lessons.map(\.lessonID)
        guard !lessonIds.isEmpty else { return false }
        return !HomeTaskManager().userTriplesForCourse(courseId: courseId, lessonIds: lessonIds).isEmpty
    }
}

// MARK: - Personal lesson from dictionary (speaker → словарь → урок)

struct PersonalCourseCreateOverlayView: View {
    @ObservedObject private var pack = PersonalPackManager.shared
    @ObservedObject private var pro = ProManager.shared
    @EnvironmentObject private var nav: NavigationIntent
    @EnvironmentObject private var overlay: OverlayPresenter
    var onDismiss: () -> Void

    private var dictCount: Int { pack.dictionaryCount }
    private var packCount: Int { pack.entries.count }
    private var isProUser: Bool { pro.isPro }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Урок из моих фраз", onDismiss: onDismiss) {
                TaikaRootVerticalScroll {
                    VStack(alignment: .leading, spacing: 18) {
                        if !isProUser {
                            HStack(spacing: 8) {
                                CDProBadge()
                                Text("Доступно в Pro")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(CD.ColorToken.textSecondary)
                            }
                        }

                        Text("Сохрани фразы в спикере, собери из них урок — и тренируй как в обычном курсе.")
                            .font(CD.FontToken.body(14))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 12) {
                            scriptStep(
                                number: 1,
                                title: "Спикер",
                                detail: "Скажи по-русски → переведу → «в словарь»"
                            )
                            scriptStep(
                                number: 2,
                                title: "Словарь",
                                detail: dictCount > 0
                                    ? "\(dictCount) фраз сохранено"
                                    : "Здесь копятся твои фразы"
                            )
                            scriptStep(
                                number: 3,
                                title: "Собрать урок",
                                detail: dictCount > 0
                                    ? "Упакую фразы в карточки для тренировки"
                                    : "Сначала добавь хотя бы одну фразу"
                            )
                        }

                        if isProUser, dictCount > 0 {
                            OverlayEtalonPrimaryButton(
                                title: packCount > 0 ? "Открыть урок" : "Собрать урок"
                            ) {
                                onDismiss()
                                if !pack.buildAndOpenLesson(nav: nav) {
                                    pack.openSmartSpeakerForPhrases(nav: nav, returnTab: 1)
                                }
                            }
                        }

                        if isProUser {
                            Button {
                                onDismiss()
                                pack.openSmartSpeakerForPhrases(nav: nav, returnTab: 1)
                            } label: {
                                Text(dictCount > 0 ? "Добавить фразы в спикере" : "Открыть спикер")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        } else {
                            OverlayEtalonPrimaryButton(title: "Включить Pro") {
                                onDismiss()
                                overlay.presentPro(reason: .personalPath)
                            }
                        }
                    }
                    .padding(CD.Spacing.screen)
                }
                .frame(maxHeight: 440)
            }
        }
    }

    @ViewBuilder
    private func scriptStep(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(ThemeManager.shared.currentAccentFill))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
