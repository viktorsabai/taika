import SwiftUI

struct AllFavoritesView: View {
    private let initialFilter: FDK
    @EnvironmentObject private var nav: NavigationIntent
    @EnvironmentObject private var overlay: OverlayPresenter
    @ObservedObject private var pro = ProManager.shared
    @StateObject private var manager = FavoriteManager.shared

    @State private var query: String = ""
    @State private var undoCandidate: UndoCandidate? = nil
    @State private var hideUndoWorkItem: DispatchWorkItem? = nil

    private struct UndoCandidate: Equatable {
        let title: String
        let favoritable: RowFavoritable
    }

    private struct RowFavoritable: Favoritable, Equatable {
        let favoriteId: String
        let favoriteTitle: String
        let favoriteSubtitle: String
        let favoriteMeta: String
        let favoriteCourseId: String
        let favoriteLessonId: String
    }

    init(initialFilter: FDK = .all) {
        self.initialFilter = initialFilter
    }

    private var allCards: [FDCardDTO] {
        manager.cardsDTO
            .filter { !(canonicalId($0).lowercased().hasPrefix("hack:")) }
            .sorted { $0.addedAt > $1.addedAt }
    }

    private var allHacks: [FDHackDTO] {
        let explicit = manager.hacksDTO
        let fromCards: [FDHackDTO] = manager.cardsDTO.compactMap { card in
            let source = canonicalId(card)
            let isHack = source.lowercased().hasPrefix("hack:") || card.meta.lowercased().hasPrefix("hack:")
            guard isHack else { return nil }
            let normalizedSource = source.hasPrefix("hack:") ? source : "hack:\(source)"
            return FDHackDTO(
                sourceId: normalizedSource,
                title: card.title,
                meta: card.meta,
                lessonTitle: card.lessonTitle,
                addedAt: card.addedAt
            )
        }
        var seen = Set<String>()
        return (explicit + fromCards)
            .sorted { $0.addedAt > $1.addedAt }
            .filter { seen.insert($0.sourceId).inserted }
    }

    private var allCourses: [FDCourseDTO] {
        manager.coursesDTO.sorted { $0.addedAt > $1.addedAt }
    }

    private var filteredCardsAll: [FDCardDTO] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allCards }
        return allCards.filter {
            $0.title.lowercased().contains(q) ||
            $0.meta.lowercased().contains(q) ||
            $0.lessonTitle.lowercased().contains(q)
        }
    }

    private var filteredHacksAll: [FDHackDTO] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allHacks }
        return allHacks.filter {
            $0.title.lowercased().contains(q) ||
            $0.meta.lowercased().contains(q) ||
            $0.lessonTitle.lowercased().contains(q)
        }
    }

    private var filteredCoursesAll: [FDCourseDTO] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allCourses }
        return allCourses.filter {
            $0.title.lowercased().contains(q) ||
            $0.subtitle.lowercased().contains(q)
        }
    }

    private var filteredCards: [FDCardDTO] {
        (initialFilter == .all || initialFilter == .cards) ? filteredCardsAll : []
    }

    private var filteredHacks: [FDHackDTO] {
        (initialFilter == .all || initialFilter == .hacks) ? filteredHacksAll : []
    }

    /// Course favorites are represented by Courses → Избранное, never as rows in Favorites.
    private var filteredCourses: [FDCourseDTO] { [] }

    private var shownCount: Int {
        filteredCards.count + filteredHacks.count + filteredCourses.count
    }

    private func rowForCard(_ dto: FDCardDTO) -> FDFavItem {
        let phonetic: String = {
            let raw = dto.meta
            if raw.hasPrefix("card:") { return String(raw.dropFirst("card:".count)) }
            return raw
        }()
        return FDFavItem(
            sourceId: dto.sourceId,
            kind: .cards,
            title: dto.title,
            subtitle: "",
            meta: phonetic,
            lessonTitle: dto.lessonTitle,
            tagText: dto.tagText,
            isPro: false,
            addedAt: dto.addedAt
        )
    }

    private func rowForHack(_ dto: FDHackDTO) -> FDFavItem {
        let normalized = dto.meta.hasPrefix("hack:") ? String(dto.meta.dropFirst("hack:".count)) : dto.meta
        let subtitle = normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? dto.title : normalized
        return FDFavItem(
            sourceId: dto.sourceId,
            kind: .hacks,
            title: "Лайфхак",
            subtitle: subtitle,
            meta: "",
            lessonTitle: dto.lessonTitle,
            tagText: nil,
            isPro: false,
            addedAt: dto.addedAt
        )
    }

    private func rowForCourse(_ dto: FDCourseDTO) -> FDFavItem {
        FDFavItem(
            sourceId: "course:\(dto.courseId)",
            kind: .courses,
            title: dto.title,
            subtitle: dto.subtitle,
            meta: "",
            lessonTitle: nil,
            tagText: nil,
            isPro: false,
            addedAt: dto.addedAt
        )
    }

    /// Вторичная строка: для карточек — фонетика из `meta`; для курсов/лайфхаков — `subtitle`, если `meta` пустой.
    private func compactRowSecondary(_ item: FDFavItem) -> String? {
        let m = item.meta.trimmingCharacters(in: .whitespacesAndNewlines)
        if !m.isEmpty { return m }
        let s = item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    /// Строка списка: тап по ряду — открыть. Русский и фонетика — **две строки** (как нативные списки), без горизонтальной «давки».
    @ViewBuilder
    private func compactRow(
        item: FDFavItem,
        onOpen: @escaping () -> Void,
        onPlay: (() -> Void)? = nil
    ) -> some View {
        let secondary = compactRowSecondary(item)

        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let secondary {
                        Text(secondary)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    if let onPlay {
                        AppCardIconButton(kind: .speaker, forceAccent: true, onTap: onPlay)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.75))
                        .frame(width: 20, alignment: .center)
                        .padding(.vertical, 10)
                }
                .padding(.top, 1)
            }
            .contentShape(Rectangle())
            .onTapGesture { onOpen() }
            .padding(.vertical, 12)

            Rectangle()
                .fill(PD.ColorToken.stroke.opacity(0.65))
                .frame(height: 1)
        }
    }

    private let listRowInsets = EdgeInsets(top: 0, leading: PD.Spacing.screen, bottom: 0, trailing: PD.Spacing.screen)

    @ViewBuilder
    private func favoritesListContent() -> some View {
        Group {
            if !filteredCards.isEmpty {
                Section {
                    ForEach(filteredCards, id: \.sourceId) { dto in
                        compactRow(
                            item: rowForCard(dto),
                            onOpen: { openCard(dto) },
                            onPlay: {
                                let thai = dto.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !thai.isEmpty { StepAudio.shared.speakThai(thai) }
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                removeCard(dto)
                            } label: {
                                Label("Убрать", systemImage: "heart.slash")
                            }
                        }
                        .listRowInsets(listRowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }

            if !filteredHacks.isEmpty {
                Section {
                    ForEach(filteredHacks, id: \.sourceId) { dto in
                        compactRow(
                            item: rowForHack(dto),
                            onOpen: { openHack(dto) },
                            onPlay: nil
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                removeHack(dto)
                            } label: {
                                Label("Убрать", systemImage: "heart.slash")
                            }
                        }
                        .listRowInsets(listRowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }

            if !filteredCourses.isEmpty {
                Section {
                    ForEach(filteredCourses, id: \.courseId) { dto in
                        compactRow(
                            item: rowForCourse(dto),
                            onOpen: {
                                if let c = CourseData.shared.course(with: dto.courseId), c.isPro, !pro.isPro {
                                    overlay.presentPro(reason: .lockedCourse, courseId: dto.courseId)
                                } else {
                                    nav.go(.lessons(courseId: dto.courseId))
                                }
                            },
                            onPlay: nil
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                removeCourse(dto)
                            } label: {
                                Label("Убрать", systemImage: "heart.slash")
                            }
                        }
                        .listRowInsets(listRowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
    }

    private func parseIdx(from sourceId: String) -> Int {
        let low = sourceId.lowercased()
        guard let r = low.range(of: ":idx") else { return 0 }
        return Int(low[r.upperBound...]) ?? 0
    }

    private func routeFromSourceId(_ sourceId: String) -> (courseId: String, lessonId: String, index: Int)? {
        let parts = sourceId.lowercased().split(separator: ":").map(String.init)
        // card:step:course:lesson:idxN / hack:step:course:lesson:idxN
        if parts.count >= 5, (parts[0] == "card" || parts[0] == "hack"), parts[1] == "step" {
            let idx = Int(parts[4].filter(\.isNumber)) ?? 0
            return (parts[2], parts[3], idx)
        }
        // step:course:lesson:idxN
        if parts.count >= 4, parts[0] == "step" {
            let idx = Int(parts[3].filter(\.isNumber)) ?? 0
            return (parts[1], parts[2], idx)
        }
        return nil
    }

    private func mappedStepIndex(courseId: String, lessonId: String, originalIndex: Int, hacksOnly: Bool) -> Int {
        let steps = StepManager.shared.dsStepsCached(courseId: courseId, lessonId: lessonId)
        guard !steps.isEmpty else { return max(0, originalIndex) }
        let allowedKinds: Set<SDStepItem.Kind> = hacksOnly ? [.tip] : [.word, .phrase, .casual]
        let allowedOriginalIndices: [Int] = steps.enumerated().compactMap { idx, step in
            allowedKinds.contains(step.kind) ? idx : nil
        }
        guard !allowedOriginalIndices.isEmpty else { return 0 }
        if let exact = allowedOriginalIndices.firstIndex(of: originalIndex) {
            return exact
        }
        // nearest fallback for legacy/misaligned ids
        var bestPos = 0
        var bestDelta = abs(allowedOriginalIndices[0] - originalIndex)
        for (pos, idx) in allowedOriginalIndices.enumerated() {
            let d = abs(idx - originalIndex)
            if d < bestDelta {
                bestDelta = d
                bestPos = pos
            }
        }
        return bestPos
    }

    private func openCard(_ dto: FDCardDTO) {
        if let parsed = routeFromSourceId(dto.sourceId) {
            let mapped = mappedStepIndex(
                courseId: parsed.courseId,
                lessonId: parsed.lessonId,
                originalIndex: parsed.index,
                hacksOnly: false
            )
            nav.go(.lesson(
                courseId: parsed.courseId,
                lessonId: parsed.lessonId,
                presentation: .favoritesAllList(startIndex: mapped, hacksOnly: false)
            ))
            return
        }
        if let rr = StepManager.shared.resolveRoute(fromFavoriteId: dto.sourceId) {
            let mapped = mappedStepIndex(
                courseId: rr.courseId,
                lessonId: rr.lessonId,
                originalIndex: rr.stepIndex,
                hacksOnly: false
            )
            nav.go(.lesson(
                courseId: rr.courseId,
                lessonId: rr.lessonId,
                presentation: .favoritesAllList(startIndex: mapped, hacksOnly: false)
            ))
            return
        }
        if let fallback = FavoriteData.shared.fallbackRoute(from: dto.sourceId) {
            let idx = max(0, parseIdx(from: dto.sourceId))
            let mapped = mappedStepIndex(
                courseId: fallback.courseId,
                lessonId: fallback.lessonId,
                originalIndex: idx,
                hacksOnly: false
            )
            nav.go(.lesson(
                courseId: fallback.courseId,
                lessonId: fallback.lessonId,
                presentation: .favoritesAllList(startIndex: mapped, hacksOnly: false)
            ))
        }
    }

    private func openHack(_ dto: FDHackDTO) {
        if let parsed = routeFromSourceId(dto.sourceId) {
            let mapped = mappedStepIndex(
                courseId: parsed.courseId,
                lessonId: parsed.lessonId,
                originalIndex: parsed.index,
                hacksOnly: true
            )
            nav.go(.lesson(
                courseId: parsed.courseId,
                lessonId: parsed.lessonId,
                presentation: .favoritesAllList(startIndex: mapped, hacksOnly: true)
            ))
            return
        }
        if let rr = StepManager.shared.resolveRoute(fromFavoriteId: dto.sourceId) {
            let mapped = mappedStepIndex(
                courseId: rr.courseId,
                lessonId: rr.lessonId,
                originalIndex: rr.stepIndex,
                hacksOnly: true
            )
            nav.go(.lesson(
                courseId: rr.courseId,
                lessonId: rr.lessonId,
                presentation: .favoritesAllList(startIndex: mapped, hacksOnly: true)
            ))
            return
        }
        if let fallback = FavoriteData.shared.fallbackRoute(from: dto.sourceId) {
            let idx = max(0, parseIdx(from: dto.sourceId))
            let mapped = mappedStepIndex(
                courseId: fallback.courseId,
                lessonId: fallback.lessonId,
                originalIndex: idx,
                hacksOnly: true
            )
            nav.go(.lesson(
                courseId: fallback.courseId,
                lessonId: fallback.lessonId,
                presentation: .favoritesAllList(startIndex: mapped, hacksOnly: true)
            ))
        }
    }

    private func idsFromSource(_ sourceId: String) -> (courseId: String, lessonId: String) {
        if let r = routeFromSourceId(sourceId) {
            return (r.courseId, r.lessonId)
        }
        if let fallback = FavoriteData.shared.fallbackRoute(from: sourceId) {
            return (fallback.courseId, fallback.lessonId)
        }
        return ("", "")
    }

    private func showUndo(title: String, favoritable: RowFavoritable) {
        hideUndoWorkItem?.cancel()
        undoCandidate = UndoCandidate(title: title, favoritable: favoritable)
        let task = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.2)) { undoCandidate = nil }
        }
        hideUndoWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: task)
    }

    private func removeCard(_ dto: FDCardDTO) {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        let ids = idsFromSource(dto.sourceId)
        let favoritable = RowFavoritable(
            favoriteId: dto.sourceId,
            favoriteTitle: dto.title,
            favoriteSubtitle: dto.subtitle,
            favoriteMeta: dto.meta,
            favoriteCourseId: ids.courseId,
            favoriteLessonId: ids.lessonId
        )
        manager.remove(id: dto.sourceId)
        showUndo(title: dto.title, favoritable: favoritable)
    }

    private func removeHack(_ dto: FDHackDTO) {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        let ids = idsFromSource(dto.sourceId)
        let favoritable = RowFavoritable(
            favoriteId: dto.sourceId,
            favoriteTitle: dto.title.isEmpty ? "Лайфхак" : dto.title,
            favoriteSubtitle: dto.meta.hasPrefix("hack:") ? String(dto.meta.dropFirst("hack:".count)) : dto.meta,
            favoriteMeta: dto.meta.hasPrefix("hack:") ? dto.meta : "hack:\(dto.meta)",
            favoriteCourseId: ids.courseId,
            favoriteLessonId: ids.lessonId
        )
        manager.remove(id: dto.sourceId)
        showUndo(title: "Лайфхак", favoritable: favoritable)
    }

    private func removeCourse(_ dto: FDCourseDTO) {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        let fid = "course:\(dto.courseId)"
        let favoritable = RowFavoritable(
            favoriteId: fid,
            favoriteTitle: dto.title,
            favoriteSubtitle: dto.subtitle,
            favoriteMeta: "",
            favoriteCourseId: dto.courseId,
            favoriteLessonId: ""
        )
        manager.remove(id: fid)
        showUndo(title: dto.title, favoritable: favoritable)
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background.ignoresSafeArea()

            VStack(spacing: 10) {
                FDSearchField(query: $query)

                if shownCount == 0 {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Ничего не найдено")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        favoritesListContent()
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                    .padding(.bottom, ToolBar.recommendedBottomInset)
                }
            }

            if let undo = undoCandidate {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Text("Удалено: \(undo.title)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PD.ColorToken.text)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Button("Отменить") {
#if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                            manager.toggle(item: undo.favoritable)
                            hideUndoWorkItem?.cancel()
                            withAnimation(.easeOut(duration: 0.2)) { undoCandidate = nil }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PD.ColorToken.card.opacity(0.95))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                    )
                    .padding(.horizontal, PD.Spacing.screen)
                    .padding(.bottom, ToolBar.recommendedBottomInset + 10)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private func canonicalId(_ c: FDCardDTO) -> String {
    c.sourceId.isEmpty ? c.id : c.sourceId
}

