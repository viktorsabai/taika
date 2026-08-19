//
//  FavoriteTabContent.swift
//  taika
//
//  Избранное: дерево курс→карточки, фильтры как в Курсе/Спикере, свайп «убрать».
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Tabs

public enum FavoriteScreenTab: String, CaseIterable, Identifiable {
    case cards
    case dictionary
    case hacks
    case courses

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cards: return "Карточки"
        case .dictionary: return "Словарь"
        case .hacks: return "Лайфхаки"
        case .courses: return "Курсы"
        }
    }

    public var taikaFMScope: TaikaFMScope { .fav }

    /// Favorites contains only course-derived saved material; personal dictionary has its own route.
    public static var mvpTabs: [FavoriteScreenTab] { [.cards, .hacks, .courses] }

    public init(fdk: FDK) {
        switch fdk {
        case .all, .cards: self = .cards
        case .hacks: self = .hacks
        case .courses: self = .courses
        }
    }
}

public struct FDFavoriteTabBar: View {
    @Binding public var selection: FavoriteScreenTab

    public init(selection: Binding<FavoriteScreenTab>, dictionaryCount: Int = 0) {
        self._selection = selection
        _ = dictionaryCount // счётчики в табах не показываем
    }

    private var tabs: [FavoriteScreenTab] { FavoriteScreenTab.mvpTabs }

    private var titles: [String] {
        tabs.map(\.title)
    }

    public var body: some View {
        AppInlineFilterPicker(
            titles: titles,
            selectedIndex: tabs.firstIndex(of: selection) ?? 0
        ) { index in
            guard tabs.indices.contains(index), selection != tabs[index] else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                selection = tabs[index]
            }
        }
    }
}

// MARK: - Lesson grouping

struct FDFavLessonGroup<Item>: Identifiable {
    let id: String
    let courseId: String?
    let lessonTitle: String
    let courseTitle: String?
    let items: [Item]
    let latestAddedAt: Date
}

struct FDFavCourseGroup<Item>: Identifiable {
    let id: String
    let courseTitle: String
    let lessons: [FDFavLessonGroup<Item>]
    let latestAddedAt: Date
}

enum FDFavLessonGrouping {
    private struct Bucket<Item> {
        var items: [Item] = []
        var lessonTitle: String = ""
        var courseTitle: String?
        var courseId: String?
        var latest: Date = .distantPast
    }

    @MainActor
    static func route(for sourceId: String) -> (courseId: String, lessonId: String)? {
        if let rr = StepManager.shared.resolveRoute(fromFavoriteId: sourceId) {
            return (rr.courseId, rr.lessonId)
        }
        let parts = sourceId.lowercased().split(separator: ":").map(String.init)
        if parts.count >= 4, parts[0] == "step" {
            return (parts[1], parts[2])
        }
        return nil
    }

    @MainActor
    static func courseTitle(for courseId: String) -> String? {
        let id = courseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }

        let candidates = [
            id,
            id.replacingOccurrences(of: "_", with: "-"),
            id.replacingOccurrences(of: "-", with: "_")
        ]

        for cid in candidates {
            if let fromCatalog = CourseData.shared.title(for: cid)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !fromCatalog.isEmpty {
                return fromCatalog
            }
            let fromLessons = LessonsManager.shared.courseTitle(for: cid)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !fromLessons.isEmpty, fromLessons.lowercased() != cid.lowercased() {
                return fromLessons
            }
        }
        return nil
    }

    @MainActor
    static func groups(from cards: [FDCardDTO]) -> [FDFavLessonGroup<FDCardDTO>] {
        buildGroups(
            cards,
            lessonTitle: { $0.lessonTitle },
            addedAt: { $0.addedAt },
            sourceId: { $0.sourceId }
        )
    }

    @MainActor
    static func courseGroups(from cards: [FDCardDTO]) -> [FDFavCourseGroup<FDCardDTO>] {
        courseGroups(from: groups(from: cards))
    }

    @MainActor
    static func courseGroups<Item>(from lessons: [FDFavLessonGroup<Item>]) -> [FDFavCourseGroup<Item>] {
        var map: [String: (title: String, lessons: [FDFavLessonGroup<Item>], latest: Date)] = [:]

        for lesson in lessons {
            let courseKey: String
            let courseTitle: String
            if let cid = lesson.courseId?.trimmingCharacters(in: .whitespacesAndNewlines), !cid.isEmpty {
                courseKey = cid
                if let canonical = Self.courseTitle(for: cid) {
                    courseTitle = canonical
                } else {
                    let fallback = lesson.courseTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    courseTitle = fallback.isEmpty ? cid : fallback
                }
            } else if let title = lesson.courseTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                courseKey = title.lowercased()
                courseTitle = title
            } else {
                courseKey = "other"
                courseTitle = "Другое"
            }

            var entry = map[courseKey] ?? (title: courseTitle, lessons: [], latest: .distantPast)
            entry.lessons.append(lesson)
            entry.latest = max(entry.latest, lesson.latestAddedAt)
            if entry.title.isEmpty || entry.title == courseKey {
                entry.title = courseTitle
            }
            map[courseKey] = entry
        }

        return map.map { key, bucket in
            FDFavCourseGroup(
                id: key,
                courseTitle: bucket.title,
                lessons: bucket.lessons.sorted { $0.latestAddedAt > $1.latestAddedAt },
                latestAddedAt: bucket.latest
            )
        }
        .sorted { $0.latestAddedAt > $1.latestAddedAt }
    }

    @MainActor
    static func groups(from hacks: [FDHackDTO]) -> [FDFavLessonGroup<FDHackDTO>] {
        buildGroups(
            hacks,
            lessonTitle: { $0.lessonTitle },
            addedAt: { $0.addedAt },
            sourceId: { $0.sourceId }
        )
    }

    @MainActor
    private static func buildGroups<Item>(
        _ items: [Item],
        lessonTitle: (Item) -> String,
        addedAt: (Item) -> Date,
        sourceId: (Item) -> String
    ) -> [FDFavLessonGroup<Item>] {
        var buckets: [String: Bucket<Item>] = [:]

        for item in items {
            let sid = sourceId(item)
            let route = route(for: sid)
            let lesson = lessonTitle(item).trimmingCharacters(in: .whitespacesAndNewlines)
            let key: String
            let resolvedLesson: String
            let resolvedCourse: String?
            let resolvedCourseId: String?

            if let route {
                key = "\(route.courseId)|\(route.lessonId)"
                resolvedCourseId = route.courseId
                if lesson.isEmpty {
                    let fromData = LessonsData.shared.lessonTitle(for: route.lessonId)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    resolvedLesson = fromData.isEmpty ? "урок" : fromData
                } else {
                    resolvedLesson = lesson
                }
                resolvedCourse = courseTitle(for: route.courseId)
            } else {
                let fallbackLesson = lesson.isEmpty ? "другое" : lesson
                key = "lesson:\(fallbackLesson.lowercased())"
                resolvedCourseId = nil
                resolvedLesson = fallbackLesson
                resolvedCourse = nil
            }

            var bucket = buckets[key] ?? Bucket()
            bucket.items.append(item)
            if bucket.lessonTitle.isEmpty { bucket.lessonTitle = resolvedLesson }
            if bucket.courseTitle == nil { bucket.courseTitle = resolvedCourse }
            if bucket.courseId == nil { bucket.courseId = resolvedCourseId }
            bucket.latest = max(bucket.latest, addedAt(item))
            buckets[key] = bucket
        }

        return buckets.map { key, bucket in
            FDFavLessonGroup(
                id: key,
                courseId: bucket.courseId,
                lessonTitle: bucket.lessonTitle.isEmpty ? "урок" : bucket.lessonTitle,
                courseTitle: bucket.courseTitle,
                items: bucket.items.sorted { addedAt($0) > addedAt($1) },
                latestAddedAt: bucket.latest
            )
        }
        .sorted { $0.latestAddedAt > $1.latestAddedAt }
    }
}

// MARK: - Cards tab (секции курсов + списки)

private func favCardPhonetic(_ dto: FDCardDTO) -> String {
    var m = dto.meta
    if m.hasPrefix("card:") { m = String(m.dropFirst("card:".count)) }
    return m.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Каталог learnable больше не нужен для UI избранного (блок «На полке» убран).

// MARK: - Shared list chrome
private enum FDFavListChrome {
    static let rowCorner: CGFloat = 16
    static let rowHPad: CGFloat = 14
    static let rowVPad: CGFloat = 15
    static let actionSize: CGFloat = 34
    static let treeRail: CGFloat = 3
    static let treeIndent: CGFloat = 18
}

private struct FavInsetGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FDFavListChrome.rowCorner, style: .continuous)
        VStack(spacing: 0) {
            content
        }
        .background(Theme.Surfaces.card(shape))
        .overlay(
            LinearGradient(
                colors: [
                    ThemeManager.shared.currentAccentFill.opacity(0.12),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(shape)
        )
        .clipShape(shape)
        .padding(.horizontal, CD.Spacing.screen)
    }
}

private struct FavRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(PD.ColorToken.stroke.opacity(0.55))
            .frame(height: 1)
            .padding(.leading, FDFavListChrome.rowHPad)
    }
}

private struct FavCircleIconButton: View {
    let systemName: String
    var isAccent: Bool = false
    /// Без подложки-кружка — меньше визуального шума в плотных списках.
    var showChrome: Bool = true
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: showChrome ? 13 : 15, weight: .semibold))
                .foregroundStyle(
                    isAccent
                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                    : AnyShapeStyle(PD.ColorToken.textSecondary)
                )
                .frame(
                    width: showChrome ? FDFavListChrome.actionSize : 28,
                    height: showChrome ? FDFavListChrome.actionSize : 36
                )
                .background {
                    if showChrome {
                        Circle().fill(PD.ColorToken.chip)
                    }
                }
                .overlay {
                    if showChrome {
                        Circle()
                            .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Горизонтальный свайп «Убрать» — работает в LazyVStack (в отличие от List.swipeActions).
private struct FavSwipeToRemove<Content: View>: View {
    let onRemove: () -> Void
    let content: Content

    init(onRemove: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onRemove = onRemove
        self.content = content()
    }

    @State private var offset: CGFloat = 0
    private let openX: CGFloat = -78
    private let threshold: CGFloat = -56

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { offset = 0 }
                onRemove()
            } label: {
                Text("Убрать")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 78)
                    .frame(maxHeight: .infinity)
                    .background(Color.red.opacity(0.92))
            }
            .buttonStyle(.plain)
            .opacity(offset < -6 ? 1 : 0)

            content
                .offset(x: offset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18, coordinateSpace: .local)
                        .onChanged { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard abs(dx) > abs(dy) * 1.1 else { return }
                            if dx < 0 {
                                offset = max(dx, openX - 12)
                            } else if offset < 0 {
                                offset = min(0, openX + dx)
                            }
                        }
                        .onEnded { value in
                            let dx = value.translation.width
                            let predicted = value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                if dx < threshold || predicted < threshold {
                                    offset = openX
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}

enum FavCardsViewMode: String, CaseIterable, Identifiable {
    case list
    case grid

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .list: return "Список"
        case .grid: return "Карточки"
        }
    }
}

/// Переключатель список/сетка — в шапке слева от табов «Карточки / Словарь…».
struct FDFavViewModeToggle: View {
    @Binding var viewMode: FavCardsViewMode
    private let toggleHeight: CGFloat = 36

    var body: some View {
        HStack(spacing: 2) {
            ForEach(FavCardsViewMode.allCases) { mode in
                let isOn = mode == viewMode
                Button {
                    guard !isOn else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        viewMode = mode
                    }
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            isOn
                            ? AnyShapeStyle(Color.black.opacity(0.9))
                            : AnyShapeStyle(PD.ColorToken.textSecondary)
                        )
                        .frame(width: 40, height: toggleHeight - 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isOn ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(Color.clear))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.accessibilityLabel)
            }
        }
        .padding(2)
        .frame(height: toggleHeight)
        .background(
            Capsule(style: .continuous)
                .fill(PD.ColorToken.chip)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Вид списка")
    }
}

private func favCategoryDisplayName(_ raw: String) -> String {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty { return "Другое" }
    if t == "База от Тайки" { return "База" }
    return t
}

/// Короткие читаемые подписи чипов — без «Тайский Для До…».
/// Deprecated for category filters: show full course-category titles instead.
private func favCategoryChipTitle(_ display: String) -> String {
    let t = display.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? "Другое" : t
}

/// Порядок курсов / фраз в списке избранного (long-press drag).
private enum FavCardsOrderStore {
    private static let courseKey = "taika.fav.cards.courseOrder.v1"
    private static func cardKey(_ courseId: String) -> String {
        "taika.fav.cards.cardOrder.v1.\(courseId)"
    }

    static func courseOrder() -> [String] {
        UserDefaults.standard.stringArray(forKey: courseKey) ?? []
    }

    static func saveCourseOrder(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: courseKey)
    }

    static func cardOrder(courseId: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: cardKey(courseId)) ?? []
    }

    static func saveCardOrder(courseId: String, ids: [String]) {
        UserDefaults.standard.set(ids, forKey: cardKey(courseId))
    }

    static func sortedCourses(_ groups: [FDFavCourseGroup<FDCardDTO>]) -> [FDFavCourseGroup<FDCardDTO>] {
        let order = courseOrder()
        guard !order.isEmpty else {
            return groups.sorted { $0.latestAddedAt > $1.latestAddedAt }
        }
        var rank: [String: Int] = [:]
        for (i, id) in order.enumerated() { rank[id] = i }
        return groups.sorted { a, b in
            let ra = rank[a.id] ?? Int.max
            let rb = rank[b.id] ?? Int.max
            if ra != rb { return ra < rb }
            return a.latestAddedAt > b.latestAddedAt
        }
    }

    static func sortedCards(_ items: [FDCardDTO], courseId: String) -> [FDCardDTO] {
        let order = cardOrder(courseId: courseId)
        guard !order.isEmpty else {
            return items.sorted { $0.addedAt > $1.addedAt }
        }
        var rank: [String: Int] = [:]
        for (i, id) in order.enumerated() { rank[id] = i }
        return items.sorted { a, b in
            let ra = rank[a.id] ?? Int.max
            let rb = rank[b.id] ?? Int.max
            if ra != rb { return ra < rb }
            return a.addedAt > b.addedAt
        }
    }

    static func moveCourse(id: String, before targetId: String?, in groups: [FDFavCourseGroup<FDCardDTO>]) {
        var ids = sortedCourses(groups).map(\.id)
        guard let from = ids.firstIndex(of: id) else { return }
        ids.remove(at: from)
        if let targetId, let to = ids.firstIndex(of: targetId) {
            ids.insert(id, at: to)
        } else {
            ids.append(id)
        }
        saveCourseOrder(ids)
    }

    static func moveCard(id: String, before targetId: String?, courseId: String, items: [FDCardDTO]) {
        var ids = sortedCards(items, courseId: courseId).map(\.id)
        guard let from = ids.firstIndex(of: id) else { return }
        ids.remove(at: from)
        if let targetId, let to = ids.firstIndex(of: targetId) {
            ids.insert(id, at: to)
        } else {
            ids.append(id)
        }
        saveCardOrder(courseId: courseId, ids: ids)
    }
}

/// Чипы категорий с нормальными полями по краям (не уезжают за экран).
/// Полные названия — без обрезки и без `.capitalized` (ломает русские заголовки).
private struct FavCategoryChipsRow: View {
    let items: [FDAppFilterItem]
    var edgeInset: CGFloat = CD.Spacing.screen

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            item.onTap()
                        }
                    } label: {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(
                                item.isSelected
                                ? AnyShapeStyle(Color.black.opacity(0.92))
                                : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.92))
                            )
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        item.isSelected
                                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                        : AnyShapeStyle(CD.ColorToken.card.opacity(0.78))
                                    )
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        item.isSelected
                                        ? AnyShapeStyle(Color.clear)
                                        : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                                        lineWidth: Theme.Strokes.strokeLineWidth
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(item.isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, edgeInset)
            .padding(.vertical, 2)
        }
    }
}

@MainActor
private func favCardCourseId(_ dto: FDCardDTO) -> String? {
    FDFavLessonGrouping.route(for: dto.sourceId)?.courseId
}

@MainActor
private func favCardCategoryKey(_ dto: FDCardDTO) -> String {
    guard let cid = favCardCourseId(dto),
          let raw = CourseData.shared.category(for: cid) else {
        return "Другое"
    }
    return favCategoryDisplayName(raw)
}

@MainActor
private func favCardPathLabel(_ dto: FDCardDTO) -> String {
    let lesson = dto.lessonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    let category = favCardCategoryKey(dto)
    if !lesson.isEmpty, lesson.lowercased() != "урок" {
        return "\(category) → \(lesson)"
    }
    if let cid = favCardCourseId(dto),
       let course = FDFavLessonGrouping.courseTitle(for: cid),
       !course.isEmpty {
        return "\(category) → \(course)"
    }
    return category
}

private func favCountLabel(_ n: Int, one: String, few: String, many: String) -> String {
    let mod100 = n % 100
    let mod10 = n % 10
    let word: String
    if mod100 >= 11 && mod100 <= 14 {
        word = many
    } else if mod10 == 1 {
        word = one
    } else if mod10 >= 2 && mod10 <= 4 {
        word = few
    } else {
        word = many
    }
    return "\(n) \(word)"
}

// MARK: - Tree chrome (курс → карточки)

private struct FavTreeCourseHeader: View {
    let title: String
    let count: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(ThemeManager.shared.currentAccentFill)
                    .frame(width: FDFavListChrome.treeRail)
                    .frame(maxHeight: .infinity)

                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .monospacedDigit()

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .padding(.vertical, 8)
            .padding(.trailing, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, CD.Spacing.screen)
        .accessibilityLabel("\(title), \(count)")
        .accessibilityHint(isCollapsed ? "Развернуть" : "Свернуть")
    }
}

private struct FavTreeLeafGuide: View {
    var isLast: Bool

    var body: some View {
        GeometryReader { geo in
            let midY = geo.size.height * 0.5
            let x: CGFloat = 7
            let endX = geo.size.width - 2

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: isLast ? midY : geo.size.height))
                    path.move(to: CGPoint(x: x, y: midY))
                    path.addLine(to: CGPoint(x: endX, y: midY))
                }
                .stroke(
                    ThemeManager.shared.currentAccentFill.opacity(0.1),
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
                )

                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: isLast ? midY : geo.size.height))
                    path.move(to: CGPoint(x: x, y: midY))
                    path.addLine(to: CGPoint(x: endX, y: midY))
                }
                .stroke(
                    ThemeManager.shared.currentAccentFill.opacity(0.32),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                )

                Circle()
                    .fill(ThemeManager.shared.currentAccentFill.opacity(0.45))
                    .frame(width: 3.5, height: 3.5)
                    .position(x: x, y: midY)
            }
        }
        .frame(width: FDFavListChrome.treeIndent + 10)
    }
}

/// Чипы категорий (вид список/сетка — в шапке экрана).
private struct FavCardsChromeBar: View {
    let categoryTitles: [String]
    @Binding var selectedCategory: String?

    var body: some View {
        if !categoryTitles.isEmpty {
            FavTabChromePanel(
                valueTitle: "",
                countLabel: "",
                categoryTitles: categoryTitles,
                selectedCategory: $selectedCategory
            )
        }
    }
}

/// Консоль избранного: капсулы фильтра / trailing-action (без переключателя вида).
private struct FavTabChromePanel: View {
    var valueTitle: String
    var countLabel: String
    var categoryTitles: [String] = []
    var selectedCategory: Binding<String?>? = nil
    var trailingActionTitle: String? = nil
    var trailingAction: (() -> Void)? = nil

    private var showsTopRow: Bool {
        !valueTitle.isEmpty || !countLabel.isEmpty || trailingActionTitle != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTopRow {
                HStack(alignment: .center, spacing: 12) {
                    if !valueTitle.isEmpty || !countLabel.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            if !valueTitle.isEmpty {
                                Text(valueTitle)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                            if !countLabel.isEmpty {
                                Text(countLabel)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    if let trailingActionTitle, let trailingAction {
                        Button(action: trailingAction) {
                            Text(trailingActionTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(PD.ColorToken.chip)
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !categoryTitles.isEmpty, let selectedCategory {
                FavCategoryChipsRow(items: categoryChipItems(selectedCategory), edgeInset: 0)
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func categoryChipItems(_ selectedCategory: Binding<String?>) -> [FDAppFilterItem] {
        var items: [FDAppFilterItem] = [
            FDAppFilterItem(
                id: "__all__",
                title: "Все",
                isSelected: selectedCategory.wrappedValue == nil,
                onTap: { selectedCategory.wrappedValue = nil }
            )
        ]
        for title in categoryTitles {
            items.append(
                FDAppFilterItem(
                    id: title,
                    title: title,
                    isSelected: selectedCategory.wrappedValue == title,
                    onTap: { selectedCategory.wrappedValue = title }
                )
            )
        }
        return items
    }
}

private enum FavPortraitGridMetrics {
    static let spacing: CGFloat = 12
    static let columns = [
        GridItem(.flexible(), spacing: spacing),
        GridItem(.flexible(), spacing: spacing)
    ]

    /// Лайфхаки / курсы — вертикальный портрет 200:286.
    static func cardSize(containerWidth: CGFloat) -> CGSize {
        let inner = max(0, containerWidth - CD.Spacing.screen * 2 - spacing)
        let w = floor(inner / 2)
        let h = floor(w * (286.0 / 200.0))
        return CGSize(width: w, height: h)
    }

    /// Фразы в сетке — выше, чтобы RU / фонетика / путь не слипались.
    static func phraseCardSize(containerWidth: CGFloat) -> CGSize {
        let inner = max(0, containerWidth - CD.Spacing.screen * 2 - spacing)
        let w = floor(inner / 2)
        let h = floor(w * 1.08)
        return CGSize(width: w, height: max(156, h))
    }
}

// MARK: - Cards tab UI

private enum FDFavCardsVisual {
    static let phoneticSize: CGFloat = 15
    static let russianSize: CGFloat = 13
}

/// Одна строка: транслит (герой) + RU (вторичный) + слушать.
private struct FDFavPhraseCompactRow: View {
    let dto: FDCardDTO
    var onPlay: () -> Void
    var showsDivider: Bool = false
    var showsDictionaryActions: Bool = false
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onTrain: (() -> Void)? = nil

    private var russian: String {
        dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var phonetic: String {
        favCardPhonetic(dto)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    if !phonetic.isEmpty {
                        TaikaPhoneticText.styled(
                            phonetic,
                            font: .system(size: 16, weight: .semibold),
                            baseColor: PD.ColorToken.text
                        )
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    }
                    if !russian.isEmpty {
                        Text(russian)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(3)
                            .minimumScaleFactor(0.88)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onPlay)

                if showsDictionaryActions {
                    DictionaryPhraseActionsMenu(
                        card: dto,
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onTrain: onTrain
                    )
                } else {
                    FavCircleIconButton(
                        systemName: "speaker.wave.2.fill",
                        isAccent: true,
                        showChrome: false,
                        accessibilityLabel: "Прослушать",
                        action: onPlay
                    )
                }
            }
            .padding(.horizontal, FDFavListChrome.rowHPad)
            .padding(.vertical, FDFavListChrome.rowVPad)

            if showsDivider {
                FavRowDivider()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([phonetic, russian].filter { !$0.isEmpty }.joined(separator: ", "))
    }
}

/// Строка для оверлея поиска — тот же визуальный язык.
private struct FDFavPhraseListRow: View {
    let dto: FDCardDTO
    var onPlay: () -> Void
    var onUnfavorite: (() -> Void)? = nil

    private var russian: String {
        dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var phonetic: String {
        favCardPhonetic(dto)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                if !phonetic.isEmpty {
                    TaikaPhoneticText.styled(
                        phonetic,
                        font: .system(size: FDFavCardsVisual.phoneticSize, weight: .semibold)
                    )
                    .lineLimit(1)
                }
                if !russian.isEmpty {
                    Text(russian)
                        .font(.system(size: FDFavCardsVisual.russianSize, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onPlay)

            FavCircleIconButton(
                systemName: "speaker.wave.2.fill",
                isAccent: true,
                showChrome: false,
                accessibilityLabel: "Прослушать",
                action: onPlay
            )

            if let onUnfavorite {
                FavCircleIconButton(
                    systemName: "heart.slash",
                    accessibilityLabel: "Убрать",
                    action: onUnfavorite
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PD.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PD.ColorToken.stroke, lineWidth: 1)
                )
        )
    }
}

// MARK: - Tab content

struct FDFavCardsTabList: View {
    let cards: [FDCardDTO]
    var onUnfavorite: (FDCardDTO) -> Void

    @AppStorage("taika.fav.cards.viewMode") private var viewModeRaw: String = FavCardsViewMode.list.rawValue
    @State private var collapsedCourseIds: Set<String> = []
    @State private var focusedCourseId: String? = nil
    @State private var selectedCategory: String? = nil
    @State private var draggingCourseId: String? = nil
    @State private var draggingCardId: String? = nil
    /// Bump to refresh after reorder persist.
    @State private var orderEpoch: Int = 0

    private var viewMode: Binding<FavCardsViewMode> {
        Binding(
            get: { FavCardsViewMode(rawValue: viewModeRaw) ?? .list },
            set: { viewModeRaw = $0.rawValue }
        )
    }

    private var categoryTitles: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for card in cards {
            let key = favCardCategoryKey(card)
            if seen.insert(key).inserted {
                ordered.append(key)
            }
        }
        return ordered.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private var categoryFilteredCards: [FDCardDTO] {
        guard let selectedCategory else { return cards }
        return cards.filter { favCardCategoryKey($0) == selectedCategory }
    }

    /// Курсы с учётом пользовательского порядка.
    private var filteredGroups: [FDFavCourseGroup<FDCardDTO>] {
        let _ = orderEpoch
        return FavCardsOrderStore.sortedCourses(
            FDFavLessonGrouping.courseGroups(from: categoryFilteredCards)
        )
    }

    private var gridCards: [FDCardDTO] {
        categoryFilteredCards.sorted { $0.addedAt > $1.addedAt }
    }

    private var cardsGridContent: some View {
        let size = FavPortraitGridMetrics.phraseCardSize(containerWidth: UIScreen.main.bounds.width)
        return LazyVGrid(columns: FavPortraitGridMetrics.columns, spacing: FavPortraitGridMetrics.spacing) {
            ForEach(Array(gridCards.enumerated()), id: \.element.id) { index, dto in
                FDFavPhraseGridCard(
                    dto: dto,
                    pathLabel: favCardPathLabel(dto),
                    size: size,
                    appearIndex: index,
                    onPlay: { playCard(dto) },
                    onUnfavorite: { onUnfavorite(dto) }
                )
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
    }

    var body: some View {
        if cards.isEmpty {
            favEmptyState(
                systemImage: "rectangle.on.rectangle.slash",
                title: "Пока нет карточек",
                subtitle: "Лайкни фразу в уроке — она появится здесь."
            )
        } else {
            cardsFilledContent
        }
    }

    private var cardsFilledContent: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            FavCardsChromeBar(
                categoryTitles: categoryTitles,
                selectedCategory: $selectedCategory
            )

            if categoryFilteredCards.isEmpty {
                Text("В этой категории пока пусто")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if viewMode.wrappedValue == .grid {
                cardsGridContent
            } else {
                cardsListContent
            }
        }
        .padding(.top, 6)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: viewModeRaw)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: selectedCategory)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: orderEpoch)
        .onChange(of: selectedCategory) { _ in
            collapsedCourseIds.removeAll()
            focusedCourseId = nil
        }
    }

    private var cardsListContent: some View {
        ForEach(filteredGroups) { course in
            let isCollapsed = collapsedCourseIds.contains(course.id)
            let isFocused = focusedCourseId == course.id && !isCollapsed
            FavCourseBlock(
                title: course.courseTitle,
                phraseCount: course.lessons.flatMap(\.items).count,
                isCollapsed: isCollapsed,
                isFocused: isFocused,
                isDragging: draggingCourseId == course.id,
                onToggle: { toggleCourse(course.id) }
            ) {
                if !isCollapsed {
                    FavCardsCourseRows(
                        course: course,
                        orderEpoch: orderEpoch,
                        draggingCardId: $draggingCardId,
                        onUnfavorite: onUnfavorite,
                        onPlay: playCard,
                        onReorderCard: { cardId, beforeId in
                            let items = course.lessons.flatMap(\.items)
                            FavCardsOrderStore.moveCard(
                                id: cardId,
                                before: beforeId,
                                courseId: course.id,
                                items: items
                            )
                            orderEpoch += 1
                        },
                        insetInParent: true
                    )
                }
            }
            .padding(.horizontal, CD.Spacing.screen)
            .opacity(draggingCourseId == course.id ? 0.55 : 1)
            .onDrag {
                draggingCourseId = course.id
                return NSItemProvider(object: course.id as NSString)
            }
            .onDrop(of: [.text], delegate: FavCourseReorderDropDelegate(
                targetId: course.id,
                draggingId: $draggingCourseId,
                onMove: { draggedId in
                    guard draggedId != course.id else { return }
                    FavCardsOrderStore.moveCourse(
                        id: draggedId,
                        before: course.id,
                        in: filteredGroups
                    )
                    orderEpoch += 1
                }
            ))
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity
            ))
        }
    }

    private func toggleCourse(_ id: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            if collapsedCourseIds.contains(id) {
                collapsedCourseIds.remove(id)
                focusedCourseId = id
            } else {
                collapsedCourseIds.insert(id)
                if focusedCourseId == id { focusedCourseId = nil }
            }
        }
    }

    private func playCard(_ dto: FDCardDTO) {
        let thai = dto.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !thai.isEmpty { StepAudio.shared.speakThai(thai) }
    }
}

/// Ячейка сетки: перевод слева сверху, крупный транслит по центру, путь снизу.
private struct FDFavPhraseGridCard: View {
    let dto: FDCardDTO
    let pathLabel: String
    let size: CGSize
    var appearIndex: Int = 0
    var onPlay: () -> Void
    var onUnfavorite: () -> Void
    var showsDictionaryActions: Bool = false
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onTrain: (() -> Void)? = nil

    @State private var appeared = false

    private var russian: String {
        dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var phonetic: String {
        favCardPhonetic(dto)
    }

    private var heroPhoneticFont: Font {
        let len = phonetic.count
        if len > 42 { return .system(size: 17, weight: .bold) }
        if len > 28 { return .system(size: 20, weight: .bold) }
        return .system(size: 24, weight: .bold)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                if !russian.isEmpty {
                    Text(russian)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.95))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .padding(.trailing, 28)
                }

                Spacer(minLength: 6)

                Group {
                    if !phonetic.isEmpty {
                        TaikaPhoneticText.styled(
                            phonetic,
                            font: heroPhoneticFont,
                            baseColor: PD.ColorToken.text
                        )
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(4)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)
                    } else if !russian.isEmpty {
                        Text(russian)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(4)
                            .minimumScaleFactor(0.72)
                    } else {
                        Text("—")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 8)

                if !pathLabel.isEmpty {
                    Text(pathLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .padding(.trailing, 22)
            .frame(width: size.width, height: size.height, alignment: .topLeading)

            Button(action: onUnfavorite) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Убрать из избранного")
            .padding(.top, 6)
            .padding(.trailing, 6)
        }
        .background(Theme.Surfaces.card(shape))
        .contentShape(shape)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onPlay()
        }
        .overlay(alignment: .bottomTrailing) {
            if showsDictionaryActions {
                DictionaryPhraseActionsMenu(
                    card: dto,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onTrain: onTrain
                )
                .padding(8)
            }
        }
        .contextMenu {
            if showsDictionaryActions {
                dictionaryPhraseContextMenu(
                    card: dto,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onTrain: onTrain
                )
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            guard !appeared else { return }
            let delay = min(Double(appearIndex), 12) * 0.035
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    appeared = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel([phonetic, russian].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Прослушать")
        .accessibilityAction(named: "Убрать из избранного", onUnfavorite)
    }
}

private struct FavCourseBlock<Content: View>: View {
    let title: String
    let phraseCount: Int
    let isCollapsed: Bool
    let isFocused: Bool
    var isDragging: Bool = false
    let onToggle: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FDFavListChrome.rowCorner, style: .continuous)
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(ThemeManager.shared.currentAccentFill.opacity(isFocused ? 1 : 0.85))
                        .frame(width: isFocused ? 4 : 3, height: 16)

                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.55)
                        .foregroundStyle(
                            isFocused
                            ? AnyShapeStyle(PD.ColorToken.text)
                            : AnyShapeStyle(PD.ColorToken.textSecondary)
                        )
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.45))
                        .accessibilityHidden(true)

                    Text("\(phraseCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.8))
                        .monospacedDigit()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.65))
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
                .padding(.horizontal, FDFavListChrome.rowHPad)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(phraseCount)")
            .accessibilityHint(isCollapsed ? "Развернуть. Зажми и перетащи, чтобы поменять порядок курсов." : "Свернуть. Зажми и перетащи, чтобы поменять порядок курсов.")

            if !isCollapsed {
                Rectangle()
                    .fill(PD.ColorToken.stroke.opacity(0.45))
                    .frame(height: 1)
                    .padding(.leading, FDFavListChrome.rowHPad)
                    .transition(.opacity)

                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            if isFocused {
                shape.fill(ThemeManager.shared.currentAccentTintColor.opacity(0.14))
            } else {
                Theme.Surfaces.card(shape)
            }
        }
        .overlay(
            shape.stroke(
                isFocused
                ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.42))
                : AnyShapeStyle(Theme.Strokes.strokeSubtle),
                lineWidth: Theme.Strokes.strokeLineWidth
            )
        )
        .clipShape(shape)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isCollapsed)
        .animation(.easeOut(duration: 0.22), value: isFocused)
    }
}

private struct FavCardsCourseHeader: View {
    let title: String
    let phraseCount: Int
    let isCollapsed: Bool
    let isFocused: Bool
    var isDragging: Bool = false
    let onToggle: () -> Void

    var body: some View {
        FavCourseBlock(
            title: title,
            phraseCount: phraseCount,
            isCollapsed: isCollapsed,
            isFocused: isFocused,
            isDragging: isDragging,
            onToggle: onToggle
        ) {
            EmptyView()
        }
    }
}

private struct FavCardsCourseRows: View {
    let course: FDFavCourseGroup<FDCardDTO>
    let orderEpoch: Int
    @Binding var draggingCardId: String?
    let onUnfavorite: (FDCardDTO) -> Void
    let onPlay: (FDCardDTO) -> Void
    let onReorderCard: (_ cardId: String, _ beforeId: String?) -> Void
    var insetInParent: Bool = false

    private var flatItems: [FDCardDTO] {
        let _ = orderEpoch
        let items = course.lessons.flatMap(\.items)
        return FavCardsOrderStore.sortedCards(items, courseId: course.id)
    }

    @ViewBuilder
    var body: some View {
        let rows = VStack(spacing: 0) {
            ForEach(Array(flatItems.enumerated()), id: \.element.id) { index, dto in
                FavSwipeToRemove(onRemove: { onUnfavorite(dto) }) {
                    FDFavPhraseCompactRow(
                        dto: dto,
                        onPlay: { onPlay(dto) },
                        showsDivider: index < flatItems.count - 1
                    )
                }
                .opacity(draggingCardId == dto.id ? 0.45 : 1)
                .onDrag {
                    draggingCardId = dto.id
                    return NSItemProvider(object: dto.id as NSString)
                }
                .onDrop(of: [.text], delegate: FavCardReorderDropDelegate(
                    targetId: dto.id,
                    courseId: course.id,
                    draggingId: $draggingCardId,
                    onMove: { draggedId in
                        guard draggedId != dto.id else { return }
                        onReorderCard(draggedId, dto.id)
                    }
                ))
            }
        }

        if insetInParent {
            rows
        } else {
            FavInsetGroup { rows }
        }
    }
}

private struct FavCourseReorderDropDelegate: DropDelegate {
    let targetId: String
    @Binding var draggingId: String?
    let onMove: (String) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingId = nil }
        guard let dragged = draggingId, dragged != targetId else { return false }
        onMove(dragged)
        return true
    }

    func dropEntered(info: DropInfo) {
        // Reorder on drop only — live thrashing while dragging is noisy in LazyVStack.
    }
}

private struct FavCardReorderDropDelegate: DropDelegate {
    let targetId: String
    let courseId: String
    @Binding var draggingId: String?
    let onMove: (String) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { draggingId = nil }
        guard let dragged = draggingId, dragged != targetId else { return false }
        _ = courseId
        onMove(dragged)
        return true
    }

    func dropEntered(info: DropInfo) {}
}

/// Словарь из «Своей речи» — тот же chrome, что вкладка Карточки (list / grid).
struct FDFavDictionaryTabList: View {
    let cards: [FDCardDTO]
    var onUnfavorite: (FDCardDTO) -> Void
    var onOpenSpeaker: (() -> Void)? = nil
    var onTrainInSpeaker: (() -> Void)? = nil

    @EnvironmentObject private var nav: NavigationIntent
    @State private var editingCard: DictionaryEditTarget?

    @AppStorage("taika.fav.dict.viewMode") private var viewModeRaw: String = FavCardsViewMode.list.rawValue

    private var viewMode: Binding<FavCardsViewMode> {
        Binding(
            get: { FavCardsViewMode(rawValue: viewModeRaw) ?? .list },
            set: { viewModeRaw = $0.rawValue }
        )
    }

    private var sortedCards: [FDCardDTO] {
        cards.sorted { $0.addedAt > $1.addedAt }
    }

    var body: some View {
        if cards.isEmpty {
            favEmptyState(
                systemImage: "bookmark",
                title: "Словарь пока пуст",
                subtitle: "Скажи фразу в «Скажи сам» и нажми «Добавить» — она появится здесь.",
                actionTitle: onOpenSpeaker == nil ? nil : "скажи сам",
                action: onOpenSpeaker
            )
        } else {
            dictionaryFilledContent
                .sheet(item: $editingCard) { target in
                    DictionaryEditSheet(card: target.card) {
                        editingCard = nil
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
                }
        }
    }

    private var dictionaryFilledContent: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            if viewMode.wrappedValue == .grid {
                dictionaryGrid
            } else {
                dictionaryList
            }
        }
        .padding(.top, 6)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: viewModeRaw)
    }

    private var dictionaryList: some View {
        FavInsetGroup {
            ForEach(Array(sortedCards.enumerated()), id: \.element.id) { index, dto in
                FavSwipeToRemove(onRemove: { onUnfavorite(dto) }) {
                    FDFavPhraseCompactRow(
                        dto: dto,
                        onPlay: { playCard(dto) },
                        showsDivider: index < sortedCards.count - 1,
                        showsDictionaryActions: true,
                        onEdit: { editingCard = DictionaryEditTarget(card: dto) },
                        onDelete: { onUnfavorite(dto) },
                        onTrain: { trainInSpeaker() }
                    )
                }
            }
        }
    }

    private var dictionaryGrid: some View {
        let size = FavPortraitGridMetrics.phraseCardSize(containerWidth: UIScreen.main.bounds.width)
        return LazyVGrid(columns: FavPortraitGridMetrics.columns, spacing: FavPortraitGridMetrics.spacing) {
            ForEach(Array(sortedCards.enumerated()), id: \.element.id) { index, dto in
                FDFavPhraseGridCard(
                    dto: dto,
                    pathLabel: "Скажи сам",
                    size: size,
                    appearIndex: index,
                    onPlay: { playCard(dto) },
                    onUnfavorite: { onUnfavorite(dto) },
                    showsDictionaryActions: true,
                    onEdit: { editingCard = DictionaryEditTarget(card: dto) },
                    onDelete: { onUnfavorite(dto) },
                    onTrain: { trainInSpeaker() }
                )
            }
        }
        .padding(.horizontal, CD.Spacing.screen)
    }

    private func trainInSpeaker() {
        if let onTrainInSpeaker {
            onTrainInSpeaker()
            return
        }
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
#endif
        SpeakerManager.shared.setSpeakerUIMode(.training)
        SpeakerRequestedCourseId.shared.set("__dictionary__")
        DictionarySessionSelection.shared.activate(nil)
        SpeakerManager.shared.startSpecialTraining(poolId: "__dictionary__")
        if nav.path.isEmpty {
            SpeakerReturnContext.shared.saveFromRootTab(3)
        } else {
            SpeakerReturnContext.shared.save(tab: 3, path: nav.path)
        }
        nav.requestTab(2)
    }

    private func playCard(_ dto: FDCardDTO) {
        let thai = dto.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !thai.isEmpty {
            StepAudio.shared.speakThai(thai)
        }
    }
}

// MARK: - Favorites search (оверлей из хедера, как поиск курсов)

struct FavoritesSearchOverlayView: View {
    var onDismiss: () -> Void

    @StateObject private var manager = FavoriteManager.shared
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    private var cards: [FDCardDTO] {
        manager.cardsDTO.filter { card in
            let id = card.sourceId.isEmpty ? card.id : card.sourceId
            return !id.lowercased().hasPrefix("hack:")
        }
    }

    private var hits: [FDCardDTO] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return cards.filter { dto in
            dto.title.lowercased().contains(q)
                || favCardPhonetic(dto).lowercased().contains(q)
                || dto.lessonTitle.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onDismiss)
            OverlayEtalonCard(title: "поиск", onDismiss: onDismiss) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                        TextField("фраза или транскрипция", text: $query)
                            .font(.system(size: 14))
                            .foregroundStyle(PD.ColorToken.text)
                            .focused($isSearchFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Theme.Surfaces.card(Capsule(style: .continuous)))

                    searchResults
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.bottom, keyboardHeight > 0 ? max(18, min(180, keyboardHeight * 0.45)) : 0)
            .onAppear { isSearchFocused = true }
#if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let endFrame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                let h = max(0, UIScreen.main.bounds.height - endFrame.minY)
                withAnimation(.easeOut(duration: 0.22)) { keyboardHeight = h }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.18)) { keyboardHeight = 0 }
            }
#endif
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            Text("ищи по русскому или транскрипции")
                .font(CD.FontToken.caption(13))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if hits.isEmpty {
            Text("ничего не нашли")
                .font(CD.FontToken.body(14))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TaikaRootVerticalScroll {
                VStack(spacing: 8) {
                    ForEach(hits) { dto in
                        FDFavPhraseListRow(
                            dto: dto,
                            onPlay: {
                                let thai = dto.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !thai.isEmpty { StepAudio.shared.speakThai(thai) }
                            },
                            onUnfavorite: {
                                manager.remove(id: dto.sourceId.isEmpty ? dto.id : dto.sourceId)
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }
}

struct FDFavHacksTabGrid: View {
    let hacks: [FDHackDTO]
    @Binding var isEditing: Bool
    var onUnfavorite: (FDHackDTO) -> Void
    var onOpen: ((FDHackDTO) -> Void)? = nil

    @State private var collapsedCourseIds: Set<String> = []

    private var courseGroups: [FDFavCourseGroup<FDHackDTO>] {
        FDFavLessonGrouping.courseGroups(from: FDFavLessonGrouping.groups(from: hacks))
    }

    var body: some View {
        if hacks.isEmpty {
            favEmptyState(
                systemImage: "lightbulb.slash",
                title: "Пока нет лайфхаков",
                subtitle: "Сохраняй лайфхаки в уроках — они появятся здесь."
            )
        } else {
            LazyVStack(alignment: .leading, spacing: Theme.Layout.sectionGap) {
                FavTabChromePanel(
                    valueTitle: "",
                    countLabel: "",
                    trailingActionTitle: isEditing ? "готово" : "править",
                    trailingAction: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                            isEditing.toggle()
                        }
                    }
                )

                ForEach(courseGroups) { course in
                    let items = course.lessons.flatMap(\.items)
                    let isCollapsed = collapsedCourseIds.contains(course.id)

                    FavTreeCourseHeader(
                        title: course.courseTitle,
                        count: items.count,
                        isCollapsed: isCollapsed
                    ) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if isCollapsed {
                                collapsedCourseIds.remove(course.id)
                            } else {
                                collapsedCourseIds.insert(course.id)
                            }
                        }
                    }

                    if !isCollapsed {
                        let size = FavPortraitGridMetrics.cardSize(containerWidth: UIScreen.main.bounds.width)
                        LazyVGrid(columns: FavPortraitGridMetrics.columns, spacing: FavPortraitGridMetrics.spacing) {
                            ForEach(items) { dto in
                                FDMiniHackCard(
                                    item: dto,
                                    onOpen: { onOpen?(dto) },
                                    onUnfavorite: { onUnfavorite(dto) },
                                    layoutWidth: size.width,
                                    layoutHeight: size.height,
                                    showTopTrailingKindChip: false,
                                    isEditing: $isEditing
                                )
                                .frame(width: size.width, height: size.height)
                            }
                        }
                        .padding(.horizontal, CD.Spacing.screen)
                    }
                }
            }
        }
    }
}

struct FDFavCoursesTabGrid: View {
    let courses: [FDCourseDTO]
    var onOpen: (FDCourseDTO) -> Void
    var onUnfavorite: (FDCourseDTO) -> Void

    var body: some View {
        if courses.isEmpty {
            favEmptyState(
                systemImage: "graduationcap",
                title: "Нет избранных курсов",
                subtitle: "Добавь курс в избранное — он появится здесь."
            )
        } else {
            let size = FavPortraitGridMetrics.cardSize(containerWidth: UIScreen.main.bounds.width)
            LazyVStack(alignment: .leading, spacing: Theme.Layout.sectionGap) {
                CDSection("Избранные курсы") {
                    LazyVGrid(columns: FavPortraitGridMetrics.columns, spacing: FavPortraitGridMetrics.spacing) {
                        ForEach(courses) { dto in
                            FDFavCourseCard(
                                item: dto,
                                layoutWidth: size.width,
                                layoutHeight: size.height,
                                onOpen: { onOpen(dto) },
                                onUnfavorite: { onUnfavorite(dto) }
                            )
                            .frame(width: size.width, height: size.height)
                        }
                    }
                    .padding(.horizontal, CD.Spacing.screen)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Empty state (по центру экрана)

@ViewBuilder
func favEmptyState(
    systemImage: String,
    title: String,
    subtitle: String,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
) -> some View {
    VStack(spacing: 14) {
        Spacer(minLength: 0)
        TaikaEmptyStateIcon(systemName: systemImage)
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(PD.ColorToken.text)
            .multilineTextAlignment(.center)
        Text(subtitle)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)
        if let actionTitle, let action {
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ThemeManager.shared.currentAccentFill)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 48)
            .padding(.top, 4)
        }
        Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
