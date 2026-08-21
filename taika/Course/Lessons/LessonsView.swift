// MARK: - Window Snapshot Helper
import UIKit

/// Captures a snapshot of the key window, including the status/safe-area region, for use as a full-screen background.
@MainActor
private func captureWindowSnapshot() -> Image? {
    // Only when app is active and we have a valid key window
    guard UIApplication.shared.applicationState == .active,
          let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
          let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
        return nil
    }
    let bounds = window.bounds
    guard bounds.width > 0 && bounds.height > 0 else { return nil }
    let renderer = UIGraphicsImageRenderer(size: bounds.size)
    let uiImage = renderer.image { _ in
        // drawHierarchy faster and with correct blur-ready pixels
        window.drawHierarchy(in: bounds, afterScreenUpdates: false)
    }
    return Image(uiImage: uiImage)
}
// Disables the interactive "swipe back" gesture for this screen
private struct NavSwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
        uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}



import SwiftUI

private extension LessonsData {
    func course(withID id: String) -> CourseBundle? {
        courseBundle(matchingAnyId: id)
    }
}


private extension LessonsView {
    var currentCourse: CourseBundle? {
        if let id = courseId {
            return lessonsStore.course(withID: id)
        }
        return lessonsStore.allCourses().first
    }

    var lessonsSorted: [LessonBundle] {
        (currentCourse?.lessons ?? []).sorted { $0.order < $1.order }
    }

    var currentLesson: LessonBundle? {
        if let sel = selectedLessonId, let bySel = lessonsSorted.first(where: { $0.lessonID == sel }) { return bySel }
        if let initial = lessonId, let byInit = lessonsSorted.first(where: { $0.lessonID == initial }) { return byInit }
        return lessonsSorted.first
    }

    var headerTitle: String {
        currentCourse?.courseTitle ?? "Курс: разговорный минимум"
    }

    var headerSubtitle: String {
        // Prefer CourseData description with [[...]] markers if present
        if let cid = currentCourse?.courseID,
           let cd = CourseData.shared.description(for: cid),
           !cd.isEmpty {
            return cd
        }
        // Fallback to lessons.json description
        return currentCourse?.courseDescription ?? ""
    }

    var fmMessages: [String] {
        if let tips = currentLesson?.assistantTips, !tips.isEmpty { return tips }
        return []
    }

    var totalLessonsCount: Int {
        lessonsSorted.count
    }

    var activeLessonIndex: Int {
        let ids = lessonsSorted.map { $0.lessonID }
        // Explicit deep-link wins over any resume heuristic.
        if let initial = lessonId, let i = ids.firstIndex(of: initial) { return i }
        if let selected = selectedLessonId, let i = ids.firstIndex(of: selected) { return i }
        return smartResumeLessonIndex
    }

    /// Resume the course where learning actually stopped, not at the first card.
    /// Priority: in-progress → next locked/unstarted → last completed.
    var smartResumeLessonIndex: Int {
        guard !lessonsSorted.isEmpty else { return 0 }
        if let index = lessonsSorted.firstIndex(where: { statusForLesson($0) == .inProgress }) {
            return index
        }
        if let index = lessonsSorted.firstIndex(where: { statusForLesson($0) == .locked }) {
            return index
        }
        return lessonsSorted.count - 1
    }

    var smartResumeLessonId: String? {
        guard lessonsSorted.indices.contains(smartResumeLessonIndex) else { return nil }
        return lessonsSorted[smartResumeLessonIndex].lessonID
    }

    func reconcileResumeSelectionAfterProgressChange() {
        guard lessonId == nil else { return }
        guard let selectedLessonId,
              let selected = lessonsSorted.first(where: { $0.lessonID == selectedLessonId }) else { return }
        guard statusForLesson(selected) == .completed else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            self.selectedLessonId = smartResumeLessonId
        }
    }

    var headerProgress: (completed: Int, total: Int) {
        let total = totalLessonsCount
        guard let cid = currentCourse?.courseID else { return (0, total) }
        return lessonsManager.headerCounts(for: cid, lessonsTotal: total)
    }

    var isCompletedCourse: Bool {
        let total = totalLessonsCount
        guard total > 0 else { return false }
        return headerProgress.completed >= total
    }

    private func toggleTrainingSelection(_ lessonId: String) {
        let available = Set(completedLessonOptions.map(\.id))
        guard available.contains(lessonId) else { return }
        var updated = selectedReinforcementLessonIds ?? available
        if updated.contains(lessonId) {
            updated.remove(lessonId)
        } else {
            updated.insert(lessonId)
        }
        updateReinforcementSelection(updated)
    }

    private func selectAllTrainingLessons() {
        updateReinforcementSelection(Set(completedLessonOptions.map(\.id)))
    }

    private func clearAllTrainingLessons() {
        updateReinforcementSelection([])
    }

    private func openCompletedLesson(_ lessonId: String) {
        guard openLessonIfAllowed(lessonId), let cid = currentCourse?.courseID else { return }
        selectedLessonId = lessonId
        nav.go(.lesson(courseId: cid, lessonId: lessonId, presentation: .directStart))
    }

    private var reinforcementLessonScores: [String: Int] {
        guard let cid = currentCourse?.courseID else { return [:] }
        return Dictionary(uniqueKeysWithValues: completedLessonOptions.compactMap { option in
            guard let score = ReinforcementStore.shared.lessonScore(courseId: cid, lessonId: option.id) else { return nil }
            return (option.id, score)
        })
    }

    private var weakCompletedLessonIds: Set<String> {
        // Keep the lesson scope in lockstep with the row diagnostics. Parsing the
        // persisted card key prefix can normalize IDs differently from lessonID
        // (hyphens/case), which previously produced `ОШИБКИ 0` beside `ошибки 1`.
        Set(lessonItems().filter { item in
            item.status == .completed && item.errorCardCount > 0
        }.map(\.id))
    }

    var completedLessonOptions: [LSCompletedLessonOption] {
        lessonsSorted.compactMap { lesson in
            guard statusForLesson(lesson) == .completed else { return nil }
            let title = lessonsManager.lessonTitle(for: lesson.lessonID)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return LSCompletedLessonOption(
                id: lesson.lessonID,
                title: title.isEmpty ? "Урок \(lesson.order + 1)" : title
            )
        }
    }

    private var effectiveReinforcementLessonIds: [String] {
        let available = Set(completedLessonOptions.map(\.id))
        let selected = selectedReinforcementLessonIds ?? available
        return Array(selected.intersection(available)).sorted()
    }

    private var showsCompletedTrainingBar: Bool {
        isCompletedCourse && courseContentMode == .lessons && !isTheoryBonusCourse && !effectiveReinforcementLessonIds.isEmpty && !showGameOverlay
    }

    private func updateReinforcementSelection(_ ids: Set<String>?) {
        let available = Set(completedLessonOptions.map(\.id))
        guard let ids else {
            selectedReinforcementLessonIds = nil
            return
        }
        let scoped = ids.intersection(available)
        selectedReinforcementLessonIds = scoped.count == available.count ? nil : scoped
    }

    /// Теория-only бонус (`course_b_0`): без игр/спикера в хедере и на карточках.
    var isTheoryBonusCourse: Bool {
        guard let cid = currentCourse?.courseID else { return false }
        return courseExperienceKind(for: cid) == .theoryBonus
    }

    /// Course-level stats for Итоги курса: learned words, favorites, spent minutes.
    /// Spent minutes are estimated from lesson duration * lesson progress percent.
    private var courseOverviewStats: (learnedWords: Int, favorites: Int, spentMinutes: Int) {
        guard let cid = currentCourse?.courseID else { return (0, 0, 0) }
        let ids = lessonsSorted.map(\.lessonID)
        let words = ids.reduce(0) { acc, lid in acc + ProgressManager.shared.learnedEffectiveCount(courseId: cid, lessonId: lid) }
        let favs = ids.reduce(0) { acc, lid in acc + lessonsManager.lessonFavoriteCount(courseId: cid, lessonId: lid) }
        let spent = lessonsSorted.reduce(0.0) { acc, lesson in
            let p = lessonsManager.lessonProgress(courseId: cid, lessonId: lesson.lessonID)?.percent ?? 0.0
            let clamped = max(0.0, min(1.0, p))
            return acc + (Double(lesson.durationMinutes) * clamped)
        }
        return (words, favs, Int(spent.rounded()))
    }

    private var reinforcementSkills: [LSReinforcementSkill] {
        guard let cid = currentCourse?.courseID,
              let metrics = ReinforcementStore.shared.metrics(courseId: cid) else {
            return [
                LSReinforcementSkill(id: "speaker", title: "Спикер", subtitle: "Произношение и тоны", icon: "speaker.wave.2.fill", isSpeaker: true),
                LSReinforcementSkill(id: "match", title: "Память", subtitle: "Найди пару", icon: "brain.head.profile", modeRawValue: GameModeType.match.rawValue),
                LSReinforcementSkill(id: "recall", title: "Вспоминание", subtitle: "Собери по слогам", icon: "book", modeRawValue: GameModeType.recall.rawValue, isProLocked: !pro.isPro),
                LSReinforcementSkill(id: "audioRecall", title: "На слух", subtitle: "Распознай фразу", icon: "ear", modeRawValue: GameModeType.audioRecall.rawValue, isProLocked: !pro.isPro)
            ]
        }
        let definitions: [(String, String, String, String, Bool)] = [
            ("speaker", "Спикер", "Произношение и тоны", "speaker.wave.2.fill", true),
            ("match", "Память", "Найди пару", "brain.head.profile", false),
            ("recall", "Вспоминание", "Собери по слогам", "book", false),
            ("audioRecall", "На слух", "Распознай фразу", "ear", false)
        ]
        return definitions.map { id, title, subtitle, icon, isSpeaker in
            let mode = metrics.byMode[id]
            return LSReinforcementSkill(
                id: id,
                title: title,
                subtitle: subtitle,
                icon: icon,
                score: mode?.averageScore,
                sessions: mode?.sessions ?? 0,
                isSpeaker: isSpeaker,
                modeRawValue: isSpeaker ? nil : id,
                isProLocked: !isSpeaker && GameModeType(rawValue: id)?.isPro == true && !pro.isPro
            )
        }
    }

    private var reinforcementCourseStats: LSCourseStats {
        LSCourseStats(
            completedLessons: headerProgress.completed,
            totalLessons: headerProgress.total,
            learnedWords: courseOverviewStats.learnedWords,
            favorites: courseOverviewStats.favorites,
            streakDays: 0,
            timeMinutes: courseOverviewStats.spentMinutes,
            gameCoveredCards: currentCourse.map { ReinforcementStore.shared.coveredCardCount(courseId: $0.courseID) } ?? 0,
            gameSessions: currentCourse.map { ReinforcementStore.shared.gameSessions(courseId: $0.courseID) } ?? 0,
            reinforcementScore: currentCourse.flatMap { ReinforcementStore.shared.overallScore(courseId: $0.courseID) },
            reinforcementSkills: reinforcementSkills
        )
    }

    private func launchSpeakerTraining(for scopedLessonIds: [String]? = nil) {
        guard let cid = currentCourse?.courseID else { return }
        let ids = scopedLessonIds?.filter { !$0.isEmpty }
            ?? (effectiveReinforcementLessonIds.isEmpty
                ? lessonsSorted.map { $0.lessonID }
                : effectiveReinforcementLessonIds)
        guard let firstID = ids.first else { return }
        SpeakerManager.shared.setSpeakerUIMode(.training)
        SpeakerRequestedCourseId.shared.set(cid, lessonIds: ids)
        UserSession.shared.markActive(courseId: cid, lessonId: firstID, stepIndex: 0)
        NotificationCenter.default.post(name: Notification.Name("Step.progressDidChange"), object: nil)
        nav.requestTab(2)
    }

    private func presentGameModePicker(for scopedLessonIds: [String]? = nil, cardKeys: [String]? = nil, preselected mode: GameModeType? = nil) {
        guard let cid = currentCourse?.courseID else { return }
        let ids = scopedLessonIds ?? effectiveReinforcementLessonIds
        guard !ids.isEmpty else { return }
        pendingGameLessonIds = ids
        pendingGameCardKeys = cardKeys
        GameRequestedCourseScope.shared.set(courseId: cid, lessonIds: ids, cardKeys: cardKeys)
        selectedGameLessonId = ids.count == 1 ? ids.first : nil
        if let mode { selectedGameType = mode }
        frozenSnapshot = captureWindowSnapshot()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            showGameOverlay = true
            showGameModePicker = true
        }
    }

    private func launchGameTraining(for scopedLessonIds: [String]? = nil, cardKeys: [String]? = nil) {
        if let scopedLessonIds, !scopedLessonIds.isEmpty {
            presentGameModePicker(for: scopedLessonIds, cardKeys: cardKeys)
        } else {
            presentGameModePicker(cardKeys: cardKeys)
        }
    }

    private func launchSelectedErrorFocus() {
        let ids = Array(Set(effectiveReinforcementLessonIds).intersection(weakCompletedLessonIds)).sorted()
        guard !ids.isEmpty else { return }
        let keys = ReinforcementStore.shared.failedCardKeys(
            courseId: currentCourse?.courseID ?? "",
            lessonIds: ids
        )
        updateReinforcementSelection(Set(ids))
        launchGameTraining(for: ids, cardKeys: Array(keys).sorted())
    }

    /// A classified skill row opens its selected mode directly; the generic Game Park entry keeps the picker.
    private func launchClassifiedGame(modeRawValue: String) {
        guard let mode = GameModeType(rawValue: modeRawValue),
              let cid = currentCourse?.courseID else { return }
        let ids = effectiveReinforcementLessonIds.isEmpty
            ? lessonsSorted.map { $0.lessonID }
            : effectiveReinforcementLessonIds
        guard !ids.isEmpty else { return }
        GameRequestedCourseScope.shared.set(courseId: cid, lessonIds: ids)
        selectedGameLessonId = ids.count == 1 ? ids.first : nil
        selectedGameType = mode
        nav.go(.game(
            courseId: cid,
            lessonId: selectedGameLessonId,
            gameType: mode.rawValue
        ))
    }

    /// Locked game access is a local contextual sheet. The user stays in the course grade sheet
    /// and can dismiss without losing lesson selection or the current reinforcement context.
    private func showGamesProSheet() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            showLocalGamesPaywall = true
        }
    }

    @ViewBuilder
    private var completedTaikaFMSection: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.sectionTitleToContent) {
            Text("ТАЙКА FM")
                .taikaSectionTitleStyle()
            TaikaFMRow(
                scope: .lessons,
                overrideMessages: [
                    "Курс пройден. Теперь закрепляем то, что должно остаться в речи.",
                    "Выбери ошибки — Taika соберёт короткую тренировку.",
                    "Один подход сегодня сильнее, чем повторить всё завтра."
                ],
                mode: .typing,
                showBubble: false,
                repeats: false
            )
        }
    }

    @ViewBuilder
    private var completedTrainingDashboard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 7) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        if !nav.path.isEmpty { nav.path.removeLast() }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(PD.ColorToken.textSecondary)
                Spacer(minLength: 10)
                Text(headerTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            completedTaikaFMSection
            courseMaterialsPicker
            LSCompletedTrainingHero(
                stats: reinforcementCourseStats,
                selectedCount: effectiveReinforcementLessonIds.count,
                totalLessons: completedLessonOptions.count,
                weakCount: weakCompletedLessonIds.count,
                onSpeaker: isTheoryBonusCourse || effectiveReinforcementLessonIds.isEmpty ? nil : { launchSpeakerTraining() },
                onGamePark: isTheoryBonusCourse || effectiveReinforcementLessonIds.isEmpty ? nil : { launchGameTraining() },
                onGameMode: isTheoryBonusCourse || effectiveReinforcementLessonIds.isEmpty ? nil : { mode in launchClassifiedGame(modeRawValue: mode) },
                onProLocked: isTheoryBonusCourse || effectiveReinforcementLessonIds.isEmpty ? nil : { showGamesProSheet() },
                selectedWeakCount: Set(effectiveReinforcementLessonIds).intersection(weakCompletedLessonIds).count,
                onFocus: isTheoryBonusCourse || Set(effectiveReinforcementLessonIds).intersection(weakCompletedLessonIds).isEmpty ? nil : { launchSelectedErrorFocus() }
            )

            LSCompletedLessonList(
                items: lessonItems(),
                selectedIds: Set(effectiveReinforcementLessonIds),
                weakIds: weakCompletedLessonIds,
                scores: reinforcementLessonScores,
                courseSessionCount: reinforcementCourseStats.gameSessions,
                onToggle: toggleTrainingSelection,
                onOpen: openCompletedLesson,
                onSelectAll: selectAllTrainingLessons,
                onClearAll: clearAllTrainingLessons,
                onSelectWeak: weakCompletedLessonIds.isEmpty ? nil : {
                    updateReinforcementSelection(weakCompletedLessonIds)
                },
                onTrainWeak: weakCompletedLessonIds.isEmpty ? nil : { selectedIds in
                    let ids = Array(selectedIds.intersection(weakCompletedLessonIds)).sorted()
                    guard !ids.isEmpty else { return }
                    let keys = ReinforcementStore.shared.failedCardKeys(
                        courseId: currentCourse?.courseID ?? "",
                        lessonIds: ids
                    )
                    updateReinforcementSelection(Set(ids))
                    launchGameTraining(for: ids, cardKeys: Array(keys).sorted())
                },
                accentFill: AnyShapeStyle(TaikaMasteryTokens.greenGradient),
                accentColor: TaikaMasteryTokens.greenGlow,
                showFocusAction: false
            )
        }
    }

    /// Remaining estimated minutes to finish the whole course.
    private var remainingCourseMinutes: Int {
        guard let cid = currentCourse?.courseID else { return 0 }
        let left = lessonsSorted.reduce(0.0) { acc, lesson in
            let p = lessonsManager.lessonProgress(courseId: cid, lessonId: lesson.lessonID)?.percent ?? 0.0
            let remaining = max(0.0, 1.0 - min(1.0, max(0.0, p)))
            return acc + (Double(lesson.durationMinutes) * remaining)
        }
        return Int(left.rounded())
    }

    /// Per-lesson completion percentage array (0...1) for the header slots
    func perLessonPercents() -> [Double] {
        guard let cid = currentCourse?.courseID else { return [] }
        // Build fractions from the same source, lesson-by-lesson.
        // This avoids relying on an optional ProgressManager API and guarantees
        // the header reflects the real state used across the app.
        return lessonsSorted.map { l in
            let p = lessonsManager.lessonProgress(courseId: cid, lessonId: l.lessonID)?.percent ?? 0
            // Clamp to [0,1] just in case
            return max(0, min(1, p))
        }
    }

    // MARK: – Adapters to DS models
    func contentItems() -> [LS.ContentItem] {
        guard let lesson = currentLesson else { return [] }
        var seen = Set<String>()
        return lesson.content.compactMap { block in
            let kind: LS.ContentKind
            switch block.kind {
            case .intro:   kind = .intro
            case .outline: kind = .outline
            case .apply:   kind = .apply
            case .outcome: kind = .outcome
            }
            let key = "\(kind)-\(block.text)"
            if seen.contains(key) {
                return nil
            } else {
                seen.insert(key)
                return LS.ContentItem(kind: kind, text: block.text, imageName: nil)
            }
        }
    }

    /// Resolve DS status for a lesson using LessonsManager, with sensible fallback
    func statusForLesson(_ l: LessonBundle) -> LS.Status {
        guard let cid = currentCourse?.courseID,
              let p = lessonsManager.lessonProgress(courseId: cid, lessonId: l.lessonID) else {
            return .locked
        }
        switch p.status {
        case .completed: return .completed
        case .inProgress: return .inProgress
        case .locked: return .locked
        }
    }

    private func speakerScore(courseId: String, lessonId: String) -> Int? {
        let scores = SpeakerAttemptsStore.loadAll().values
            .filter {
                $0.courseId == courseId &&
                $0.lessonId == lessonId
            }
            .map { $0.advancedScore ?? $0.heardConfidence }
        guard !scores.isEmpty else { return nil }
        return max(0, min(100, Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())))
    }

    func lessonItems() -> [LS.Item] {
        guard let cid = currentCourse?.courseID else { return [] }
        return lessonsSorted.enumerated().map { (i, l) in
            {
                let lp = lessonsManager.lessonProgress(courseId: cid, lessonId: l.lessonID)
                let rawPercent = lp?.percent ?? 0.0
                let clamped = max(0.0, min(1.0, rawPercent))

                let status = statusForLesson(l)

                // Show progress only if lesson is not locked
                let progressValue: Double? = (status == .locked) ? nil : clamped

                let learnableCount: Int = {
                    let counts = StepData.shared.progressCounts(for: l.lessonID)
                    return counts.learnable > 0 ? counts.learnable : l.cardCount
                }()
                let learnedCardCount = min(learnableCount, max(0, Int((clamped * Double(max(1, learnableCount))).rounded())))
                let errorCardCount = ReinforcementStore.shared.failedCardKeys(courseId: cid, lessonIds: [l.lessonID]).count
                let reinforcementScore = ReinforcementStore.shared.lessonScore(courseId: cid, lessonId: l.lessonID)
                let reinforcementSessionCount = ReinforcementStore.shared.gameSessions(courseId: cid, lessonId: l.lessonID)
                let speakerScore = speakerScore(courseId: cid, lessonId: l.lessonID)
                return LS.Item(
                    id: l.lessonID,
                    index: i,
                    title: l.title,
                    subtitle: l.subtitle,
                    durationMinutes: l.durationMinutes,
                    isPro: false,
                    status: status,
                    tags: l.tags,
                    progress: progressValue,
                    cardCount: learnableCount,
                    favoriteCount: FavoriteManager.shared.countCardsForLesson(courseId: cid, lessonId: l.lessonID),
                    learnedCardCount: learnedCardCount,
                    errorCardCount: errorCardCount,
                    reinforcementScore: reinforcementScore,
                    reinforcementSessionCount: reinforcementSessionCount,
                    speakerScore: speakerScore
                )
            }()
        }
    }

    var homeTaskProgress: (done: Int, total: Int) {
        guard let cid = currentCourse?.courseID else { return (0, 0) }
        let p = homeTaskManager.progress(for: cid)
        return (p.done, p.total)
    }

    func hometaskItems() -> [HT.Item] {
        let cid = currentCourse?.courseID ?? ""
        let lessonIDs = lessonsSorted.map { $0.lessonID }

        // 1) Try real tasks from the manager
        let rows: [(task: HTask, locked: Bool, minutes: Int?)] =
            homeTaskManager.hometasksFor(courseId: cid) { t, locked, minutes, _ in
                (t, locked, minutes)
            }
        if !rows.isEmpty {
            return rows.enumerated().map { idx, row in
                HT.Item(
                    id: row.task.id,
                    index: idx,
                    title: row.task.title,
                    subtitle: nil,
                    durationMinutes: row.minutes,
                    isLocked: row.locked
                )
            }
        }

        // 2) No concrete tasks yet → use availability (status + game kind) for richer placeholders
        let annotated = homeTaskManager.availability(
            for: cid,
            lessonIds: lessonIDs,
            rule: .everyNLessons(3),
            samplePerTask: 6,
            minTriples: 6
        )
        if !annotated.isEmpty {
            return annotated.enumerated().map { idx, a in
                let p = a.descriptor
                // rough duration estimate from pool size to avoid empty look
                let est = max(6, min(18, p.triples.count))
                let locked = (a.status == .locked)
                let gameSubtitle = "игра: \(a.game)"
                return HT.Item(
                    id: p.id,
                    index: idx,
                    title: p.title,
                    subtitle: gameSubtitle,
                    durationMinutes: est,
                    isLocked: locked
                )
            }
        }

        // 3) Absolute fallback — structural placeholders by grouping lessons (3 per task) + final
        let total = lessonsSorted.count
        let groupCount = max(1, total > 0 ? Int(ceil(Double(total) / 3.0)) : 1)
        var items: [HT.Item] = []
        for i in 0..<groupCount {
            items.append(
                HT.Item(
                    id: "ht-placeholder-\(i+1)",
                    index: i,
                    title: "Практика #\(i+1)",
                    subtitle: "мини‑игры: пары • викторина • аудио",
                    durationMinutes: 8,
                    isLocked: true
                )
            )
        }
        items.append(
            HT.Item(
                id: "ht-placeholder-final",
                index: groupCount,
                title: "Итоговая практика",
                subtitle: "мини‑игры: пары • викторина • аудио",
                durationMinutes: 10,
                isLocked: true
            )
        )
        return items
    }

}

private enum LSCourseContentMode: Int {
    case lessons
    case lifehacks

    var title: String {
        switch self {
        case .lessons: return "Уроки"
        case .lifehacks: return "Лайфхаки"
        }
    }
}

/// A lifehack projected from the current course's own lesson data.
/// The lesson/course ids and canonical order are retained so favorites remain scoped and reversible.
private struct LSCourseLifehack: Identifiable {
    let id: String
    let dto: FDHackDTO
    let step: SDStepItem
    let courseId: String
    let lessonId: String
    let order: Int
}

public struct LessonsView: View {
    // Keep user on the Courses tab while viewing lessons
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var nav: NavigationIntent
    @EnvironmentObject private var overlay: OverlayPresenter
    @ObservedObject private var lessonsStore = LessonsData.shared
    @ObservedObject private var lessonsManager = LessonsManager.shared
    @StateObject private var homeTaskManager = HomeTaskManager()
    @State private var htVersion = UUID()
    @State private var showGameModePicker: Bool = false
    @State private var selectedGameType: GameModeType = .match
    @State private var showGameOverlay: Bool = false
    /// Local paywall sheet for a locked game tapped from the course grade sheet.
    /// It keeps the LessonsView context instead of presenting the global full-screen paywall.
    @State private var showLocalGamesPaywall: Bool = false
    @State private var showCompletedTrainingPicker: Bool = false
    @State private var selectedGameLessonId: String? = nil
    /// Material scope currently owned by the game picker; it must survive mode selection.
    @State private var pendingGameLessonIds: [String] = []
    /// nil = normal reinforcement; non-nil = explicit targeted error-card scope.
    @State private var pendingGameCardKeys: [String]? = nil
    @State private var selectedLessonId: String? = nil
    /// Reinforcement queue selection is independent from the visible carousel focus.
    /// nil means all completed lessons; a non-nil set is the explicit multi-select scope.
    @State private var selectedReinforcementLessonIds: Set<String>? = nil
    @State private var courseContentMode: LSCourseContentMode = .lessons
    @State private var headerChipResolved: String? = nil
    @State private var headerSubtitleResolved: String = ""
    @State private var itemsVersion = UUID()
    // forces full rebuild of lesson progress UI on reset / progress changes
    @State private var progressReloadToken: UUID = UUID()
    // Debounce work item for header refreshes
    @State private var headerRefreshWork: DispatchWorkItem? = nil
    @State private var frozenSnapshot: Image? = nil
    @ObservedObject private var lessonsHeaderStore = LessonsHeaderStore.shared
    @ObservedObject private var pro = ProManager.shared

    private let courseId: String?
    private let lessonId: String?

    public init(courseId: String? = nil, lessonId: String? = nil) {
        self.courseId = courseId
        self.lessonId = lessonId
    }

    private func resolveHeaderMeta() {
        // Ensure CourseData is loaded
        CourseData.shared.load()
        guard let course = currentCourse else {
            headerChipResolved = nil
            headerSubtitleResolved = ""
            return
        }
        let cid = course.courseID
        let cat = CourseData.shared.category(for: cid)
        let desc = CourseData.shared.description(for: cid)
        headerChipResolved = (cat?.isEmpty == false) ? cat : nil
        headerSubtitleResolved = (desc?.isEmpty == false) ? desc! : (course.courseDescription ?? "")
    }

    /// Debounced header and tasks refresh, to avoid redundant rebuilds.
    private func scheduleHeaderRefresh() {
        headerRefreshWork?.cancel()
        let work = DispatchWorkItem {
            // Recompute header and lightweight IDs
            resolveHeaderMeta()
            if let cid = currentCourse?.courseID {
                let ids = lessonsSorted.map { $0.lessonID }
            homeTaskManager.regenerateTasks(
                for: cid,
                lessonIds: ids
            ) { id, triples, index in
                HTask(
                    id: id,
                    courseId: cid,
                    lessonIndex: index,
                    gameType: .match,
                    title: "Практика #\(index + 1)",
                    status: .locked
                )
            }
            }
            itemsVersion = UUID()
            htVersion = UUID()
        }
        headerRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    @ViewBuilder
    private var mainContent: some View {
        TaikaRootVerticalScroll {
            VStack(spacing: Theme.Layout.sectionGap) {
                headerSection
                    .padding(.horizontal, Theme.Layout.pageHorizontal)

                if courseContentMode == .lessons {
                    if isCompletedCourse {
                        completedTrainingDashboard
                            .padding(.horizontal, Theme.Layout.pageHorizontal)
                    } else {
                        LSSectionTitle("ТАЙКА FM")
                            .padding(.horizontal, Theme.Layout.pageHorizontal)
                            .padding(.top, Theme.Layout.sectionTop)

                        TaikaFMRow(
                            scope: .lessons,
                            mode: .typing,
                            showBubble: false,
                            repeats: false
                        )
                        .padding(.horizontal, Theme.Layout.pageHorizontal)
                        .padding(.top, Theme.Layout.sectionTitleToContent)

                        lessonsReelsSection
                            .padding(.horizontal, Theme.Layout.pageHorizontal)

                        if !isTheoryBonusCourse {
                            LSCompletedLessonList(
                                items: lessonItems().filter { $0.status == .completed },
                                selectedIds: Set(effectiveReinforcementLessonIds),
                                weakIds: weakCompletedLessonIds,
                                scores: reinforcementLessonScores,
                                courseSessionCount: reinforcementCourseStats.gameSessions,
                                onToggle: toggleTrainingSelection,
                                onOpen: openCompletedLesson,
                                onSelectAll: selectAllTrainingLessons,
                                onClearAll: clearAllTrainingLessons,
                                onSelectWeak: weakCompletedLessonIds.isEmpty ? nil : {
                                    updateReinforcementSelection(weakCompletedLessonIds)
                                },
                                onTrainWeak: weakCompletedLessonIds.isEmpty ? nil : { selectedIds in
                                    let ids = Array(selectedIds.intersection(weakCompletedLessonIds)).sorted()
                                    guard !ids.isEmpty else { return }
                                    let keys = ReinforcementStore.shared.failedCardKeys(
                                        courseId: currentCourse?.courseID ?? "",
                                        lessonIds: ids
                                    )
                                    updateReinforcementSelection(Set(ids))
                                    launchGameTraining(for: ids, cardKeys: Array(keys).sorted())
                                },
                                accentFill: AnyShapeStyle(TaikaMasteryTokens.greenGradient),
                                accentColor: TaikaMasteryTokens.greenGlow,
                                isCompletedPresentation: true,
                                sectionTitle: "УРОКИ КУРСА"
                            )
                            .padding(.horizontal, Theme.Layout.pageHorizontal)
                        }
                    }
                } else {
                    if isCompletedCourse {
                        VStack(alignment: .leading, spacing: 18) {
                            completedTaikaFMSection
                            courseMaterialsPicker
                            courseLifehacksReels
                        }
                        .padding(.horizontal, Theme.Layout.pageHorizontal)
                    } else {
                        courseLifehacksReels
                            .padding(.horizontal, Theme.Layout.pageHorizontal)
                    }
                }

                if currentCourse == nil {
                    Text("Не удалось загрузить курс из lessons.json")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom, showsCompletedTrainingBar ? ToolBar.recommendedBottomInset + 104 : Theme.Layout.pageBottomSafeGap)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    public var body: some View {
        buildBody()
    }

    private func completedTrainingFloatingCTA() -> some View {
        let count = effectiveReinforcementLessonIds.count
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showCompletedTrainingPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Начать закрепление · \(count)")
                    .font(.system(size: 17, weight: .semibold))
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(PD.ColorToken.text)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PD.ColorToken.card.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PD.ColorToken.stroke.opacity(0.8), lineWidth: 1)
            )
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
        .accessibilityLabel("Начать закрепление, \(count) уроков")
    }

    @ViewBuilder
    private var overlayStackView: some View {
        ZStack(alignment: .bottom) {
            // Completed state uses local mastery accents only; the screen plane stays graphite.
            PD.ColorToken.background
                .ignoresSafeArea()

            mainContent

            if showsCompletedTrainingBar {
                completedTrainingFloatingCTA()
                    .padding(.horizontal, Theme.Layout.pageHorizontal)
                    .padding(.bottom, ToolBar.recommendedBottomInset + 10)
                    .padding(.top, 12)
                    .background(
                        LinearGradient(
                            colors: [PD.ColorToken.background.opacity(0), PD.ColorToken.background.opacity(0.96)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
            }

            if showGameOverlay {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        Group {
                            if let frozenSnapshot {
                                frozenSnapshot
                                    .resizable()
                                    .scaledToFill()
                                    .blur(radius: 18)
                                    .overlay(Color.black.opacity(0.18))
                                    .ignoresSafeArea()
                            } else {
                                PD.ColorToken.background
                                    .ignoresSafeArea()
                            }
                        }
                        .allowsHitTesting(false)

                        if showGameModePicker {
                            GameModePickerDS(
                                selected: Binding(
                                    get: { selectedGameType },
                                    set: { selectedGameType = $0 }
                                ),
                                isProUser: ProManager.shared.isPro,
                                onStart: { mode in
                                    let cid = currentCourse?.courseID ?? ""
                                    let scopedIds = pendingGameLessonIds.isEmpty
                                        ? effectiveReinforcementLessonIds
                                        : pendingGameLessonIds
                                    guard !scopedIds.isEmpty else { return }
                                    GameRequestedCourseScope.shared.set(
                                        courseId: cid,
                                        lessonIds: scopedIds,
                                        cardKeys: pendingGameCardKeys
                                    )
                                    showGameModePicker = false
                                    showGameOverlay = false
                                    frozenSnapshot = nil
                                    pendingGameLessonIds = []
                                    pendingGameCardKeys = nil
                                    nav.go(.game(
                                        courseId: cid,
                                        lessonId: selectedGameLessonId,
                                        gameType: mode.rawValue
                                    ))
                                },
                                onClose: {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                        showGameModePicker = false
                                        showGameOverlay = false
                                    }
                                    frozenSnapshot = nil
                                    pendingGameLessonIds = []
                                    pendingGameCardKeys = nil
                                },
                                onLockedTap: { mode in
                                    if mode.isPro && !ProManager.shared.isPro {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                            showGameModePicker = false
                                            showGameOverlay = false
                                        }
                                        frozenSnapshot = nil
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            showLocalGamesPaywall = true
                                        }
                                    } else {
#if os(iOS)
                                        let gen = UINotificationFeedbackGenerator()
                                        gen.notificationOccurred(.warning)
#endif
                                    }
                                },
                                modes: GameModeType.modesLessonAndPark
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .ignoresSafeArea(edges: .all)
                }
            }
        }
        .confirmationDialog(
            "Начать закрепление курса",
            isPresented: $showCompletedTrainingPicker,
            titleVisibility: .visible
        ) {
            Button("Спикер") {
                launchSpeakerTraining(for: effectiveReinforcementLessonIds)
            }
            Button("Игры") {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                launchGameTraining(for: effectiveReinforcementLessonIds)
            }
            if !Set(effectiveReinforcementLessonIds).intersection(weakCompletedLessonIds).isEmpty {
                Button("Повторить ошибки") {
                    launchSelectedErrorFocus()
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Выбрано \(effectiveReinforcementLessonIds.count) уроков курса")
        }
    }

    private func buildBody() -> some View {
        let courseResetPub = NotificationCenter.default.publisher(for: Notification.Name("progressCourseDidReset"))
        let courseResetLegacyPub = NotificationCenter.default.publisher(for: Notification.Name("courseProgressDidReset"))
        let lessonResetPub = NotificationCenter.default.publisher(for: Notification.Name("progressLessonDidReset"))
        let lessonResetLegacyPub = NotificationCenter.default.publisher(for: Notification.Name("lessonProgressDidReset"))
        let hometaskRegeneratePub = NotificationCenter.default.publisher(for: Notification.Name("hometaskShouldRegenerate"))
        let favoritesDidChangePub = NotificationCenter.default.publisher(for: .favoritesDidChange)
        let favoritesDidUpdatePub = NotificationCenter.default.publisher(for: .favoritesDidUpdate)
        let favoritesDidChangeLegacyPub = NotificationCenter.default.publisher(for: .FavoritesDidChange)


// Base content

let base = overlayStackView


// Data loading / refresh hooks

let withTasks = base

    // Use the global AppShell header (back header for this screen).

    .task {

        CourseData.shared.load()

        lessonsStore.preload()

        resolveHeaderMeta()

        if let cid = currentCourse?.courseID {

            let ids = lessonsSorted.map { $0.lessonID }

            homeTaskManager.regenerateTasks(for: cid, lessonIds: ids) { id, triples, index in
                HTask(
                    id: id,
                    courseId: cid,
                    lessonIndex: index,
                    gameType: .match,
                    title: "Практика #\(index + 1)",
                    status: .locked
                )
            }

        }

        DispatchQueue.main.async { resolveHeaderMeta() }

    }

    .onChange(of: currentCourse?.courseID) { _, _ in

        resolveHeaderMeta()

        if let cid = currentCourse?.courseID {

            let ids = lessonsSorted.map { $0.lessonID }

            homeTaskManager.regenerateTasks(for: cid, lessonIds: ids) { id, triples, index in
                HTask(
                    id: id,
                    courseId: cid,
                    lessonIndex: index,
                    gameType: .match,
                    title: "Практика #\(index + 1)",
                    status: .locked
                )
            }

        }

        if isTheoryBonusCourse {
            lessonsHeaderStore.setActions(onSpeaker: nil, onReinforce: nil)
        } else {
            lessonsHeaderStore.setActions(
                onSpeaker: {
                    launchSpeakerTraining()
                },
                onReinforce: {
                    guard currentCourse?.courseID != nil else { return }
                    selectedGameLessonId = nil
                    selectedGameType = .match
                    if let cid = currentCourse?.courseID {
                        GameRequestedCourseScope.shared.set(courseId: cid, lessonIds: effectiveReinforcementLessonIds)
                    }
                    frozenSnapshot = captureWindowSnapshot()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                        showGameOverlay = true
                        showGameModePicker = true
                    }
                }
            )
        }

    }

            .onChange(of: selectedLessonId) { _, _ in

                itemsVersion = UUID()

            }
            .onChange(of: isCompletedCourse) { _, completed in
                lessonsHeaderStore.setCompletedCourse(completed)
            }

    .onReceive(lessonsManager.$progress) { _ in

        reconcileResumeSelectionAfterProgressChange()
        scheduleHeaderRefresh()

    }

    .onReceive(NotificationCenter.default.publisher(for: .init("ProgressDidChange"))) { _ in

        progressReloadToken = UUID()

        scheduleHeaderRefresh()

    }

    .onReceive(NotificationCenter.default.publisher(for: .init("AppResetAll"))) { _ in

        progressReloadToken = UUID()

        scheduleHeaderRefresh()

    }

    .onReceive(courseResetPub) { _ in scheduleHeaderRefresh() }

    .onReceive(courseResetLegacyPub) { _ in scheduleHeaderRefresh() }

    .onReceive(lessonResetPub) { _ in scheduleHeaderRefresh() }

    .onReceive(lessonResetLegacyPub) { _ in scheduleHeaderRefresh() }

    .onReceive(favoritesDidChangePub) { _ in
        itemsVersion = UUID()
        scheduleHeaderRefresh()
    }
    .onReceive(favoritesDidUpdatePub) { _ in
        itemsVersion = UUID()
        scheduleHeaderRefresh()
    }
    .onReceive(favoritesDidChangeLegacyPub) { _ in
        itemsVersion = UUID()
        scheduleHeaderRefresh()
    }

    .onReceive(homeTaskManager.objectWillChange) { _ in

        htVersion = UUID()

    }

    .onReceive(hometaskRegeneratePub) { _ in

        htVersion = UUID()

    }

    .onReceive(lessonsStore.objectWillChange) { _ in

        scheduleHeaderRefresh()

    }

    .onReceive(NotificationCenter.default.publisher(for: .init("TaikaReinforcementDidUpdate"))) { _ in
        itemsVersion = UUID()
        scheduleHeaderRefresh()
    }

// Navigation / chrome

        let withChrome = withTasks
            .navigationBarBackButtonHidden(true)
            .toolbar(Visibility.hidden, for: ToolbarPlacement.navigationBar)
            .onAppear {
                GameHeaderStore.shared.config = nil
                lessonsHeaderStore.setCompletedCourse(isCompletedCourse)
                // Resume the course context instead of resetting the carousel to lesson one.
                if selectedLessonId == nil {
                    selectedLessonId = lessonId ?? smartResumeLessonId
                }
                if isTheoryBonusCourse {
                    lessonsHeaderStore.setActions(onSpeaker: nil, onReinforce: nil)
                } else {
                    lessonsHeaderStore.setActions(
                        onSpeaker: {
                            launchSpeakerTraining()
                        },
                        onReinforce: {
                            launchGameTraining()
                        }
                    )
                }
            }
            .onDisappear {
                GameHeaderStore.shared.config = nil
                lessonsHeaderStore.clearActions()
                lessonsHeaderStore.setCompletedCourse(false)
            }
                        .onChange(of: lessonsHeaderStore.resetRequested) { _, requested in
                if requested {
                    lessonsHeaderStore.clearResetRequest()
                    presentCourseResetOverlay()
                }
            }
            .sheet(isPresented: $showLocalGamesPaywall) {
                TaikaPlusPaywallView(
                    courseId: currentCourse?.courseID,
                    reason: .games,
                    onClose: {
                        showLocalGamesPaywall = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        PD.ColorToken.background.opacity(0.92)
                    }
                }
            }
        return withChrome
}
}



extension LessonsView {
    /// Product rule: PRO gating is course-level only.
    /// Lesson-level `is_free` flags are ignored for navigation.
    private func openLessonIfAllowed(_ lessonId: String) -> Bool {
        _ = lessonId
        return true
    }

    /// Заголовок секции: «ИТОГИ» слева, название курса справа (одна строка).
    private var lessonsTotalsSectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("ИТОГИ")
                .taikaSectionTitleStyle()
            Spacer(minLength: 8)
            Text(headerTitle)
                .taikaSubsectionStyle(accent: true)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.trailing)
        }
    }

    private func presentCourseResetOverlay() {
        guard let cid = currentCourse?.courseID, !cid.isEmpty else { return }
        overlay.present(.courseResetConfirm(courseId: cid))
    }

    // MARK: - Extracted Sections
    private var headerSection: some View {
        let slots = perLessonPercents()
        let count = totalLessonsCount
        let baseSlots = !slots.isEmpty ? slots : Array(repeating: 0.0, count: count)
        let slotsResolved: [Double] = baseSlots.isEmpty ? [0.0] : baseSlots
        let courseIsCompleted = isCompletedCourse
        let subtitleResolved = headerSubtitleResolved.isEmpty ? headerSubtitle : headerSubtitleResolved
        return VStack(spacing: 10) {
            if !courseIsCompleted {
                LSLessonHeader(
                title: headerTitle,
                subtitle: courseIsCompleted ? "" : subtitleResolved,
                progressSlots: courseIsCompleted ? nil : slotsResolved,
                selectedIndex: activeLessonIndex,
                onTapSlot: { idx in
                let arr = lessonsSorted
                if idx >= 0 && idx < arr.count {
                    let lid = arr[idx].lessonID
                    guard openLessonIfAllowed(lid) else { return }
                    LSLessonActivity.mark(lid)
                    if let cid = currentCourse?.courseID {
                        UserSession.shared.markActive(courseId: cid, lessonId: lid, stepIndex: 0)
                        CarouselScrollPersistence.setLessonReelIndex(courseId: cid, index: idx)
                    }
                    DispatchQueue.main.async {
                        selectedLessonId = lid
                        nav.go(.lesson(
                            courseId: currentCourse?.courseID ?? "",
                            lessonId: lid,
                            presentation: .canonical
                        ))
                    }
                }
            },
                onBack: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        if !nav.path.isEmpty { nav.path.removeLast() }
                    }
                },
                // Reinforcement is a post-course layer. An in-progress course must keep this hero focused on learning.
                completionSummary: courseIsCompleted ? completedCourseSummary : nil,
                isCompletedCourse: courseIsCompleted,
                // In completed mode the training dock owns material selection; avoid a second, oversized picker in the header card.
                                bottomAccessory: courseIsCompleted ? nil : AnyView(courseMaterialsPicker)
                )
            }
        }
    }
    private var completedCourseSummary: AnyView? {
        guard let cid = currentCourse?.courseID else { return nil }
        let metrics = ReinforcementStore.shared.metrics(courseId: cid)
        let sessions = metrics?.byMode.values.reduce(0) { $0 + $1.sessions } ?? 0
        let covered = ReinforcementStore.shared.coveredCardCount(courseId: cid)
        let totalCards = lessonsSorted.reduce(0) { total, lesson in
            total + StepData.shared.items(for: lesson.lessonID).count
        }
        let score = ReinforcementStore.shared.overallScore(courseId: cid)
        let matchedPercent = totalCards > 0 ? min(100, Int((Double(covered) / Double(totalCards) * 100).rounded())) : nil
        let weakCount = lessonsSorted.reduce(0) { count, lesson in
            let lessonScore = ReinforcementStore.shared.lessonScore(courseId: cid, lessonId: lesson.lessonID) ?? 100
            return count + (lessonScore < 70 ? 1 : 0)
        }
        let recommendation = weakCount > 0
            ? "Начни с \(weakCount) урок\(weakCount == 1 ? "а" : "ов"), где есть ошибки"
            : "Поддержи результат короткой тренировкой"

        return AnyView(
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("КУРС ПРОЙДЕН")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .kerning(0.35)
                    }
                    .foregroundStyle(AnyShapeStyle(Color.black.opacity(0.86)))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(AnyShapeStyle(TaikaMasteryTokens.greenBadgeGradient)))
                    Spacer(minLength: 4)
                    if let score {
                        Text("\(score)%")
                            .font(Theme.Fonts.metric(13))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                Text(recommendation)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                HStack(spacing: 10) {
                    Text("\(covered) карточек")
                    if let matchedPercent { Text("· \(matchedPercent)%") }
                    Text("· \(sessions) игр")
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.58))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
        )
    }

    private var courseGameSummary: AnyView? {
        guard let cid = currentCourse?.courseID else { return nil }
        let metrics = ReinforcementStore.shared.metrics(courseId: cid)
        let sessions = metrics?.byMode.values.reduce(0) { $0 + $1.sessions } ?? 0
        guard sessions > 0 else { return nil }

        let covered = ReinforcementStore.shared.coveredCardCount(courseId: cid)
        let totalCards = lessonsSorted.reduce(0) { total, lesson in
            total + StepData.shared.items(for: lesson.lessonID).count
        }
        let score = ReinforcementStore.shared.overallScore(courseId: cid)
        let matchedPercent = totalCards > 0 ? min(100, Int((Double(covered) / Double(totalCards) * 100).rounded())) : nil
        let legacyRecord = covered == 0

        let action: () -> Void = {
            if !isCompletedCourse,
               let nextLessonId = smartResumeLessonId,
               let courseId = currentCourse?.courseID {
                selectedLessonId = nextLessonId
                nav.go(.lesson(courseId: courseId, lessonId: nextLessonId, presentation: .canonical))
                return
            }
            selectedGameLessonId = nil
            selectedGameType = .match
            pendingGameLessonIds = effectiveReinforcementLessonIds
            GameRequestedCourseScope.shared.set(courseId: cid, lessonIds: effectiveReinforcementLessonIds)
            frozenSnapshot = captureWindowSnapshot()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                showGameOverlay = true
                showGameModePicker = true
            }
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Image(systemName: !isCompletedCourse ? "arrow.forward.circle" : (legacyRecord ? "arrow.triangle.2.circlepath" : "checkmark.seal.fill"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    Text(!isCompletedCourse ? "Курс в процессе" : (legacyRecord ? "Тренировка курса" : "Курс готов к закреплению"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer(minLength: 4)
                    if isCompletedCourse, let score {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(score)%")
                                .font(Theme.Fonts.metric(13))
                                .monospacedDigit()
                            Text("результат игры")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                        .foregroundStyle(.white.opacity(0.92))
                    }
                }

                Text(
                    !isCompletedCourse
                    ? "Первый шаг сделан. Продолжай следующий урок — закрепление будет после завершения курса."
                    : (legacyRecord
                       ? "Старый результат ещё не связан с карточками этого курса."
                       : "Закрепление: \(covered) карточек\(totalCards > 0 ? " из \(totalCards)" : "") · \(sessions) \(sessions == 1 ? "игра" : "игр").")
                )
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)

                HStack(spacing: 10) {
                    if let matchedPercent {
                        Text(isCompletedCourse ? "совпало \(matchedPercent)%" : "первый подход · \(covered) карточек")
                            .font(Theme.Fonts.metric(11))
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer(minLength: 4)
                    Button(action: action) {
                        HStack(spacing: 5) {
                            Text(!isCompletedCourse ? "Продолжить урок" : (legacyRecord ? "Связать игру" : "Закрепить дальше"))
                                .font(.system(size: 11, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        )
    }

    private var courseMaterialsPicker: some View {
        HStack(spacing: 10) {
            Text("Материалы курса")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .textCase(.uppercase)
                .kerning(0.5)
            Spacer(minLength: 8)
            if isCompletedCourse {
                Menu {
                    ForEach(Array([LSCourseContentMode.lessons.title, LSCourseContentMode.lifehacks.title].enumerated()), id: \.offset) { index, title in
                        Button {
                            guard let next = LSCourseContentMode(rawValue: index), next != courseContentMode else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                                courseContentMode = next
                            }
                        } label: {
                            if index == courseContentMode.rawValue {
                                Label(title, systemImage: "checkmark")
                            } else {
                                Text(title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(courseContentMode.title)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PD.ColorToken.card)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(PD.ColorToken.stroke.opacity(0.72), lineWidth: 1)
                    )
                }
                .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
                .accessibilityLabel("Раздел материалов курса")
            } else {
                AppInlineFilterPicker(
                    titles: [LSCourseContentMode.lessons.title, LSCourseContentMode.lifehacks.title],
                    selectedIndex: courseContentMode.rawValue,
                    selectionAccent: AnyShapeStyle(PD.ColorToken.textSecondary)
                ) { index in
                    guard let next = LSCourseContentMode(rawValue: index), next != courseContentMode else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        courseContentMode = next
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Материалы курса")
    }

    private var contentReelsSection: some View {
        VStack(spacing: Theme.Layout.sectionContentV) {
            LSContentReels(
                "СОДЕРЖАНИЕ",
                items: contentItems()
            )
            LSMarqueeSection(
                title: "ТАЙКА FM",
                messages: fmMessages
            )
        }
    }

    private var courseLifehacks: [LSCourseLifehack] {
        guard let cid = currentCourse?.courseID else { return [] }

        return lessonsSorted.flatMap { lesson in
            StepData.shared.items(for: lesson.lessonID).compactMap { raw in
                guard raw.kind == .tip || raw.kind == .dialog else { return nil }
                let face = StepData.shared.face(for: raw)
                let text = face.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }

                let step = SDStepItem(
                    kind: .tip,
                    titleRU: text,
                    subtitleTH: face.subtitleTH,
                    phonetic: face.phonetic,
                    canonicalOrder: raw.order
                )
                let stableId = "\(cid)|\(lesson.lessonID)|\(raw.order)"
                let dto = FDHackDTO(
                    sourceId: FavoriteManager.shared.idForHack(
                        courseId: cid,
                        lessonId: lesson.lessonID,
                        index: raw.order
                    ),
                    title: "Лайфхак",
                    meta: text,
                    lessonTitle: lesson.title,
                    addedAt: Date(timeIntervalSince1970: 0)
                )
                return LSCourseLifehack(
                    id: stableId,
                    dto: dto,
                    step: step,
                    courseId: cid,
                    lessonId: lesson.lessonID,
                    order: raw.order
                )
            }
        }
    }

    private var courseLifehacksReels: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                LSSectionTitle("ЛАЙФХАКИ")
                Spacer(minLength: 8)
                Text("\(courseLifehacks.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }

            if courseLifehacks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "lightbulb.slash")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    Text("В этом курсе пока нет лайфхаков")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(PD.ColorToken.text)
                    Text("Они появятся здесь, когда будут добавлены в материалы курса.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)))
            } else {
                GeometryReader { geo in
                    let cardWidth: CGFloat = CDLessonCarouselCanonical.cardWidth
                    let cardHeight: CGFloat = CDLessonCarouselCanonical.courseLessonCardHeight
                    let spacing: CGFloat = CardDS.Metrics.carouselSpacing
                    let sideInset: CGFloat = PD.Spacing.screen

                    TaikaCarouselScroll {
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(courseLifehacks) { hack in
                                GeometryReader { itemGeo in
                                    let midX = itemGeo.frame(in: .global).midX
                                    let containerMidX = geo.frame(in: .global).midX
                                    let distance = abs(midX - containerMidX)
                                    let maxDistance = cardWidth + spacing
                                    let t = min(distance / maxDistance, 1)
                                    let scale: CGFloat = 0.94 + (1 - t) * 0.08
                                    let opacity: Double = 0.76 + (1 - t) * 0.24
                                    let yOffset: CGFloat = t * 10

                                    StepLifehackCardVisual(
                                        item: hack.step,
                                        label: "лайфхак",
                                        size: CGSize(width: cardWidth, height: cardHeight),
                                        sectionChrome: .seps,
                                        chromeStyle: .cards,
                                        isFavorite: FavoriteManager.shared.containsHack(
                                            courseId: hack.courseId,
                                            lessonId: hack.lessonId,
                                            index: hack.order
                                        ),
                                        onFavorite: {
                                            FavoriteManager.shared.toggle(
                                                step: hack.step,
                                                courseId: hack.courseId,
                                                lessonId: hack.lessonId,
                                                order: hack.order
                                            )
                                        }
                                    )
                                    .scaleEffect(scale)
                                    .opacity(opacity)
                                    .offset(y: yOffset)
                                }
                                .frame(width: cardWidth, height: cardHeight)
                            }
                        }
                        .padding(.horizontal, sideInset)
                        .padding(.vertical, 4)
                        .frame(height: cardHeight + 36)
                    }
                }
                .frame(height: CDLessonCarouselCanonical.courseLessonCardHeight + 36)
            }
        }
    }

    private var lessonsReelsSection: some View {
        LSLessonReels(
            "УРОКИ",
            items: lessonItems(),
            onTap: { item in
                let arr = lessonsSorted
                if item.index >= 0 && item.index < arr.count {
                    let lid = arr[item.index].lessonID
                    if isCompletedCourse {
                        toggleTrainingSelection(lid)
                        return
                    }
                    guard openLessonIfAllowed(lid) else { return }
                    LSLessonActivity.mark(lid)
                    if let cid = currentCourse?.courseID {
                        UserSession.shared.markActive(courseId: cid, lessonId: lid, stepIndex: 0)
                        CarouselScrollPersistence.setLessonReelIndex(courseId: cid, index: item.index)
                    }
                    DispatchQueue.main.async {
                        selectedLessonId = lid
                        nav.go(.lesson(
                            courseId: currentCourse?.courseID ?? "",
                            lessonId: lid,
                            presentation: .directStart
                        ))
                    }
                }
            },
            onTapAccessory: isTheoryBonusCourse ? nil : { item in
                let arr = lessonsSorted
                guard item.index >= 0 && item.index < arr.count else { return }
                let lid = arr[item.index].lessonID
                if item.status == .completed {
                    launchGameTraining(for: [lid])
                    return
                }
                guard openLessonIfAllowed(lid) else {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    return
                }
                LSLessonActivity.mark(lid)
                if let cid = currentCourse?.courseID {
                    UserSession.shared.markActive(courseId: cid, lessonId: lid, stepIndex: 0)
                    CarouselScrollPersistence.setLessonReelIndex(courseId: cid, index: item.index)
                }
                selectedLessonId = lid
                nav.go(.lesson(
                    courseId: currentCourse?.courseID ?? "",
                    lessonId: lid,
                    presentation: .directStart
                ))
            },
            onSpeaker: isTheoryBonusCourse ? nil : { item in
                launchSpeakerTraining(for: [item.id])
            },
            onNext: { item in
                let arr = lessonsSorted
                let nextIndex = item.index + 1
                guard arr.indices.contains(nextIndex) else { return }
                let nextLesson = arr[nextIndex]
                guard openLessonIfAllowed(nextLesson.lessonID) else { return }
                selectedLessonId = nextLesson.lessonID
                if let cid = currentCourse?.courseID {
                    UserSession.shared.markActive(courseId: cid, lessonId: nextLesson.lessonID, stepIndex: 0)
                    CarouselScrollPersistence.setLessonReelIndex(courseId: cid, index: nextIndex)
                }
                nav.go(.lesson(
                    courseId: currentCourse?.courseID ?? "",
                    lessonId: nextLesson.lessonID,
                    presentation: .directStart
                ))
            },
            selectedIndex: activeLessonIndex,
            selectedLessonIds: isCompletedCourse ? Set(effectiveReinforcementLessonIds) : []
        )
    }
}
#Preview("LessonsView – screen") {
    LessonsView()
        .environmentObject(NavigationIntent())
        .environmentObject(OverlayPresenter.shared)
        .task { CourseData.shared.load() } // прогрузи курсовый JSON
}






