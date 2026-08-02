import Foundation

/// Единая логика: какой `lessonId` подставить для «Поток диалога», когда в навигации урок не передан.
@MainActor
enum GameLessonContextResolver {

    static func resolveConversationLessonId(courseId: String, explicitLessonId: String) -> String {
        let raw = explicitLessonId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty { return raw }

        let cid = courseId.trimmingCharacters(in: .whitespacesAndNewlines)
        if cid.isEmpty { return "" }
        if cid == "__favorites__" {
            return pickFavoritesConversationLessonId() ?? ""
        }
        if LearnedGameSource.isPseudoCourseId(cid) {
            // Парк «все выученные»: берём курс с наибольшим прогрессом, где есть диалог.
            return pickBestLearnedConversationLessonId() ?? ""
        }
        LessonsData.shared.preload()
        StepData.shared.preload()
        return pickCourseConversationLessonId(courseId: cid) ?? ""
    }

    // MARK: - Course (без явного урока)

    private static func pickCourseConversationLessonId(courseId: String) -> String? {
        let catalog = catalogLessonsSorted(courseId: courseId)
        guard !catalog.isEmpty else { return nil }

        let byLesson = progressByLesson(for: courseId)
        let started = startedLessons(for: courseId)

        let inProgress = catalog.filter { byLesson[$0.lessonID]?.status == .inProgress }
        if let id = firstLessonWithConversationTurns(in: inProgress) { return id }

        let startedOrdered = catalog.filter { started.contains($0.lessonID) }
        if let id = firstLessonWithConversationTurns(in: startedOrdered) { return id }

        let notCompleted = catalog.filter { byLesson[$0.lessonID]?.status != .completed }
        if let id = firstLessonWithConversationTurns(in: notCompleted) { return id }

        return firstLessonWithConversationTurns(in: catalog) ?? catalog.first?.lessonID
    }

    private static func catalogLessonsSorted(courseId: String) -> [LessonBundle] {
        var list = LessonsData.shared.lessons(for: courseId)
        if list.isEmpty {
            let dashed = courseId.replacingOccurrences(of: "_", with: "-")
            list = LessonsData.shared.lessons(for: dashed)
        }
        if list.isEmpty {
            let underscored = courseId.replacingOccurrences(of: "-", with: "_")
            list = LessonsData.shared.lessons(for: underscored)
        }
        return list.sorted { $0.order < $1.order }
    }

    private static func courseIdVariants(_ raw: String) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        func add(_ s: String) {
            guard !s.isEmpty, seen.insert(s).inserted else { return }
            out.append(s)
        }
        add(raw)
        add(raw.replacingOccurrences(of: "_", with: "-"))
        add(raw.replacingOccurrences(of: "-", with: "_"))
        return out
    }

    private static func progressByLesson(for courseId: String) -> [String: LessonProgress] {
        for v in courseIdVariants(courseId) {
            let m = LessonsManager.shared.progress[v] ?? [:]
            if !m.isEmpty { return m }
        }
        return [:]
    }

    private static func startedLessons(for courseId: String) -> Set<String> {
        var out = Set<String>()
        for v in courseIdVariants(courseId) {
            if let s = LessonsManager.shared.started[v] {
                out.formUnion(s)
            }
        }
        return out
    }

    private static func firstLessonWithConversationTurns(in lessons: [LessonBundle]) -> String? {
        for l in lessons {
            let items = StepData.shared.items(for: l.lessonID)
            if !ConversationFlowEngine.buildTurns(from: items).isEmpty {
                return l.lessonID
            }
        }
        return nil
    }

    // MARK: - Favorites

    private static func parseFavoriteStepRef(_ ref: String) -> (courseId: String, lessonId: String)? {
        let parts = ref.split(separator: ":").map(String.init)
        guard parts.count >= 4, parts[0] == "step" else { return nil }
        return (parts[1], parts[2])
    }

    /// Урок с максимальным числом избранных карточек среди тех, где есть сценарий диалога.
    private static func pickFavoritesConversationLessonId() -> String? {
        var counts: [String: Int] = [:]
        for ref in FavoriteManager.shared.speakerStepIds() {
            guard let (_, lidRaw) = parseFavoriteStepRef(ref) else { continue }
            let lid = StepData.shared.lessonIdForCaseInsensitiveLookup(lidRaw) ?? lidRaw
            counts[lid, default: 0] += 1
        }
        let ordered = counts.keys.sorted { lhs, rhs in
            let cL = counts[lhs] ?? 0
            let cR = counts[rhs] ?? 0
            if cL != cR { return cL > cR }
            return lhs < rhs
        }
        for lid in ordered {
            let items = StepData.shared.items(for: lid)
            if !ConversationFlowEngine.buildTurns(from: items).isEmpty {
                return lid
            }
        }
        return ordered.first
    }

    /// Курс/урок с наибольшим числом выученных среди тех, где есть диалог.
    private static func pickBestLearnedConversationLessonId() -> String? {
        LessonsData.shared.preload()
        StepData.shared.preload()
        var courseCounts: [String: Int] = [:]
        for (key, steps) in ProgressManager.shared.learnedSteps where !steps.isEmpty {
            courseCounts[key.courseId, default: 0] += steps.count
        }
        let orderedCourses = courseCounts.keys.sorted { lhs, rhs in
            let cL = courseCounts[lhs] ?? 0
            let cR = courseCounts[rhs] ?? 0
            if cL != cR { return cL > cR }
            return lhs < rhs
        }
        for cid in orderedCourses {
            if let lid = pickCourseConversationLessonId(courseId: cid) {
                return lid
            }
        }
        return nil
    }
}
