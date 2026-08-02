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
let overlayEtalonBackgroundOpacity: Double = 0.58

struct OverlayEtalonBackground: View {
    let onDismiss: () -> Void
    var body: some View {
        Theme.Surfaces.blackGlassScrim
            .ignoresSafeArea()
            .onTapGesture(perform: onDismiss)
            .accessibilityHidden(true)
    }
}

/// Карточка оверлея: жидкое чёрное стекло (без серого material).
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
        .taikaBlackGlassBackground(cornerRadius: 28)
        .frame(maxWidth: 420)
        .padding(.horizontal, 20)
        .padding(.top, 60)
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
            UnifiedOverlayChrome(title: "Поиск и фильтры", onDismiss: onDismiss) {
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
        isConversation ? max(0, 3 - conversationAttempts.remainingToday) : trainingAttempts.usedToday
    }

    private var limitLabel: String {
        isConversation ? "3" : "10"
    }

    private var modeTitle: String {
        isConversation ? "Скажи сам" : "Закрепление курсов"
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Попытки сегодня", onDismiss: onDismiss) {
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
                        : isConversation
                            ? "В режиме «Скажи сам» у free‑аккаунта \(limitLabel) попытки в день. Завтра лимит обновится."
                            : "В «Закреплении курсов» у free‑аккаунта \(limitLabel) попыток в день. Завтра лимит обновится."
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

// MARK: - Speaker courses overlay (канон: только выбор курсов + старт)
struct SpeakerCoursesOverlayView: View {
    @ObservedObject private var speaker = SpeakerManager.shared
    @State private var selectedCourseIds: Set<String>? = nil
    var onDismiss: () -> Void

    private var options: [SpeakerTrainingCourseOption] {
        speaker.learnedTrainingCourseOptions().sorted { $0.count > $1.count }
    }

    private var selected: Set<String> {
        selectedCourseIds ?? Set(options.map(\.id))
    }

    private var selectedTotal: Int {
        options.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            UnifiedOverlayChrome(title: "Курсы для тренировки", onDismiss: onDismiss) {
                TaikaRootVerticalScroll {
                    VStack(alignment: .leading, spacing: 12) {
                        if options.isEmpty {
                            Text("Пройди пару шагов в уроке — фразы появятся здесь для тренировки.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            HStack {
                                Text("\(selectedTotal) \(Self.phraseUnit(selectedTotal))")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                                Spacer(minLength: 8)
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedCourseIds = selected.count == options.count
                                        ? []
                                        : Set(options.map(\.id))
                                } label: {
                                    Text(selected.count == options.count ? "снять всё" : "выбрать все")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(options) { option in
                                courseRow(option: option)
                            }

                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                if speaker.speakerUIMode != .training {
                                    speaker.setSpeakerUIMode(.training)
                                }
                                speaker.startTraining(withCourseIds: selected)
                                SpeakerFilterState.shared.selectedFilterId = nil
                                onDismiss()
                            } label: {
                                Text("Начать тренировку")
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
                            .disabled(selectedTotal == 0)
                            .opacity(selectedTotal == 0 ? 0.5 : 1)
                            .padding(.top, 8)
                        }
                    }
                    .padding(CD.Spacing.screen)
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.55)
            }
        }
        .onAppear {
            if selectedCourseIds == nil {
                selectedCourseIds = Set(options.map(\.id))
            }
        }
    }

    private func courseRow(option: SpeakerTrainingCourseOption) -> some View {
        let isSelected = selected.contains(option.id)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            var updated = selected
            if updated.contains(option.id) {
                updated.remove(option.id)
            } else {
                updated.insert(option.id)
            }
            selectedCourseIds = updated
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.4))
                    )
                Text(option.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text("\(option.count) \(Self.phraseUnit(option.count))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.1))
                        : AnyShapeStyle(PD.ColorToken.chip.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected
                                ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.5))
                                : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                                lineWidth: Theme.Strokes.strokeLineWidth
                            )
                    )
            )
        }
        .buttonStyle(.plain)
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
}

// MARK: - Game Park Overlay (random game from completed lesson or from favorites, or CTA)
struct GameParkOverlayView: View {
    var source: GameParkSource = .main
    @State private var selectedMode: GameModeType = .match
    @EnvironmentObject private var nav: NavigationIntent
    @EnvironmentObject private var overlay: OverlayPresenter
    var onDismiss: () -> Void
    var onOpenCourses: () -> Void

    private var hasLearnedCards: Bool {
        LearnedGameSource.hasPlayableCards
    }

    private var hasFavoriteCards: Bool {
        !FavoritesGameSource.triples().isEmpty
    }

    private var hasCards: Bool {
        switch source {
        case .main: return hasLearnedCards
        case .favorites: return hasFavoriteCards
        }
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            if hasCards {
                OverlayEtalonCard(title: "Выбери режим", onDismiss: onDismiss) {
                    GameModePickerDS(
                        selected: $selectedMode,
                        isProUser: ProManager.shared.isPro,
                        onStart: { gameType in
                            onDismiss()
                            switch source {
                            case .main:
                                // Все выученные карточки по всем курсам (как «выучено N» на Main).
                                nav.go(.game(
                                    courseId: LearnedGameSource.pseudoCourseId,
                                    lessonId: nil,
                                    gameType: gameType.rawValue
                                ))
                            case .favorites:
                                nav.go(.game(courseId: "__favorites__", lessonId: nil, gameType: gameType.rawValue))
                            }
                        },
                        onClose: onDismiss,
                        onLockedTap: { mode in
                            if mode.isPro && !ProManager.shared.isPro {
                                overlay.presentPro(reason: .games)
                            } else {
#if os(iOS)
                                let gen = UINotificationFeedbackGenerator()
                                gen.notificationOccurred(.warning)
#endif
                            }
                        },
                        modes: GameModeType.modesLessonAndPark,
                        embedInEtalon: false
                    )
                }
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        OverlayEtalonCard(title: "Игровой парк", onDismiss: onDismiss) {
            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.7))

                    Text(emptyTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .multilineTextAlignment(.center)

                    Text(emptyMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        emptyStep(number: 1, text: emptyStepOne)
                        emptyStep(number: 2, text: emptyStepTwo)
                    }
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)

                OverlayEtalonPrimaryButton(title: emptyButtonTitle) {
#if os(iOS)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
                    onOpenCourses()
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 20)
            }
        }
    }

    private func emptyStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(width: 22, height: 22)
                .background(Circle().fill(ThemeManager.shared.currentAccentFill))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyTitle: String {
        switch source {
        case .main: return "Сначала выучи пару фраз"
        case .favorites: return "В избранном пока пусто"
        }
    }

    private var emptyMessage: String {
        switch source {
        case .main:
            return "Парк собирает выученные карточки из уроков. Пока их нет — играть не с чем."
        case .favorites:
            return "Добавь слова или фразы в избранное в уроках — здесь появятся режимы для практики."
        }
    }

    private var emptyStepOne: String {
        switch source {
        case .main: return "Открой любой курс и отметь карточки как «запомнил»."
        case .favorites: return "В уроке нажми сердце на фразе."
        }
    }

    private var emptyStepTwo: String {
        switch source {
        case .main: return "Вернись сюда — режимы откроются сами."
        case .favorites: return "Снова открой консоль из избранного и выбери игру."
        }
    }

    private var emptyButtonTitle: String {
        switch source {
        case .main: return "К курсам"
        case .favorites: return "К курсам"
        }
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
