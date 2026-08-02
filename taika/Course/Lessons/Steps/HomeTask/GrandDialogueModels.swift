import Foundation

// MARK: - Склейка шагов + граф (отдельный файл — проще для компилятора, чем всё в одном .swift с View)

/// Карточка курса с привязкой к уроку.
struct GrandDialogueStitchedStep: Identifiable {
    var id: String { "\(courseId):\(lessonId):\(item.order)" }
    let courseId: String
    let lessonId: String
    let item: StepItem
}

typealias GrandDialoguePair = (prompt: GrandDialogueStitchedStep, reply: GrandDialogueStitchedStep)

struct GrandDialogueTurn: Identifiable {
    var id: String { prompt.id }
    let prompt: GrandDialogueStitchedStep
    let expectedReplies: [GrandDialogueStitchedStep]
}

@MainActor
enum GrandDialogueEngine {
    private static func canonicalCourseId(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = s.replacingOccurrences(of: "_", with: "-")
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        return s
    }

    private static func isBaseCourse(_ courseId: String) -> Bool {
        let c = canonicalCourseId(courseId)
        return c.hasPrefix("course-b-")
    }

    private static func baseCourseIds() -> [String] {
        LessonsData.shared.preload()
        let all = LessonsData.shared.allCourses().map(\.courseID)
        let base = all.filter { isBaseCourse($0) }
        if !base.isEmpty { return base }
        return ["course_b_1", "course_b_2", "course_b_3", "course_b_4", "course_b_5", "course_b_6", "course_b_7"]
    }

    private static func catalogLessonsSorted(courseId: String) -> [LessonBundle] {
        var list = LessonsData.shared.lessons(for: courseId)
        if list.isEmpty {
            list = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "_", with: "-"))
        }
        if list.isEmpty {
            list = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "-", with: "_"))
        }
        return list.sorted { $0.order < $1.order }
    }

    private static func learnedStepsForCourse(_ courseId: String) -> [GrandDialogueStitchedStep] {
        var out: [GrandDialogueStitchedStep] = []
        for lesson in catalogLessonsSorted(courseId: courseId) {
            let learnedIdx = ProgressManager.shared.learnedSet(courseId: courseId, lessonId: lesson.lessonID)
            for item in StepData.shared.items(for: lesson.lessonID) {
                guard StepData.isValidForProgress(item) else { continue }
                guard learnedIdx.contains(item.order) else { continue }
                out.append(GrandDialogueStitchedStep(courseId: courseId, lessonId: lesson.lessonID, item: item))
            }
        }
        return out
    }

    static func stitchedSteps(courseId: String) -> [GrandDialogueStitchedStep] {
        StepData.shared.preload()
        LessonsData.shared.preload()
        let primary = learnedStepsForCourse(courseId)
        guard !isBaseCourse(courseId) else { return primary }

        let base = baseCourseIds()
            .filter { canonicalCourseId($0) != canonicalCourseId(courseId) }
            .flatMap { learnedStepsForCourse($0) }

        return primary + base
    }

    /// Собирает сессию курсовой: граф `reply_to` → эвристики по урокам → дуга курса → fallback внутри урока.
    static func buildSessionTurns(courseId: String, maxTurns: Int = 12) -> [GrandDialogueTurn] {
        let cid = canonicalCourseId(courseId)
        let allSteps = stitchedSteps(courseId: courseId)
        let primarySteps = allSteps.filter { canonicalCourseId($0.courseId) == cid }
        let steps = primarySteps.count >= 2 ? primarySteps : allSteps
        guard steps.count >= 2 else { return [] }

        var turns = dialogueTurns(from: steps, preferredCourseId: cid)
        let graphPromptIds = Set(turns.map(\.prompt.id))

        if turns.count < maxTurns {
            let heuristic = heuristicTurns(
                from: steps,
                preferredCourseId: cid,
                existingPromptIds: graphPromptIds
            )
            turns.append(contentsOf: heuristic)
        }

        turns = sampleArcTurns(turns, maxTurns: maxTurns, courseId: cid)

        if turns.isEmpty {
            let fallback = lessonScopedAdjacentPairs(from: steps)
            turns = fallback.prefix(maxTurns).map {
                GrandDialogueTurn(prompt: $0.prompt, expectedReplies: [$0.reply])
            }
        }

        return Array(turns.prefix(maxTurns))
    }

    static func dialoguePairs(from steps: [GrandDialogueStitchedStep], preferredCourseId: String? = nil) -> [GrandDialoguePair] {
        let preferred = preferredCourseId.map(canonicalCourseId)
        var pairs: [GrandDialoguePair] = []
        for reply in steps {
            guard let ro = reply.item.reply_to else { continue }
            guard let prompt = steps.first(where: {
                $0.courseId == reply.courseId && $0.lessonId == reply.lessonId && $0.item.order == ro
            }) else { continue }
            guard StepData.isValidForProgress(prompt.item) else { continue }
            pairs.append((prompt: prompt, reply: reply))
        }
        let promptIndex: [String: Int] = Dictionary(uniqueKeysWithValues: steps.enumerated().map { ($0.element.id, $0.offset) })
        pairs.sort(by: { (a: GrandDialoguePair, b: GrandDialoguePair) -> Bool in
            if let preferred {
                let aPrimary = canonicalCourseId(a.prompt.courseId) == preferred
                let bPrimary = canonicalCourseId(b.prompt.courseId) == preferred
                if aPrimary != bPrimary { return aPrimary && !bPrimary }
            }
            if canonicalCourseId(a.prompt.courseId) != canonicalCourseId(b.prompt.courseId) {
                return canonicalCourseId(a.prompt.courseId) < canonicalCourseId(b.prompt.courseId)
            }
            let ia = promptIndex[a.prompt.id] ?? 0
            let ib = promptIndex[b.prompt.id] ?? 0
            if ia != ib { return ia < ib }
            return a.reply.item.order < b.reply.item.order
        })
        var seen = Set<String>()
        var unique: [GrandDialoguePair] = []
        for p in pairs {
            let k = "\(p.prompt.id)→\(p.reply.id)"
            guard seen.insert(k).inserted else { continue }
            unique.append(p)
        }
        return unique
    }

    static func fallbackAdjacentPairs(from steps: [GrandDialogueStitchedStep]) -> [GrandDialoguePair] {
        lessonScopedAdjacentPairs(from: steps)
    }

    static func dialogueTurns(from steps: [GrandDialogueStitchedStep], preferredCourseId: String? = nil) -> [GrandDialogueTurn] {
        let preferred = preferredCourseId.map(canonicalCourseId)
        var byPrompt: [String: (prompt: GrandDialogueStitchedStep, replies: [GrandDialogueStitchedStep])] = [:]

        for reply in steps {
            guard let ro = reply.item.reply_to else { continue }
            guard let prompt = steps.first(where: {
                $0.courseId == reply.courseId && $0.lessonId == reply.lessonId && $0.item.order == ro
            }) else { continue }
            guard StepData.isValidForProgress(prompt.item) else { continue }
            var entry = byPrompt[prompt.id] ?? (prompt: prompt, replies: [])
            if !entry.replies.contains(where: { $0.id == reply.id }) {
                entry.replies.append(reply)
            }
            byPrompt[prompt.id] = entry
        }

        let promptIndex: [String: Int] = Dictionary(uniqueKeysWithValues: steps.enumerated().map { ($0.element.id, $0.offset) })
        var turns = byPrompt.values
            .map { GrandDialogueTurn(prompt: $0.prompt, expectedReplies: $0.replies.sorted { $0.item.order < $1.item.order }) }
            .filter { !$0.expectedReplies.isEmpty }

        turns.sort { a, b in
            if let preferred {
                let aPrimary = canonicalCourseId(a.prompt.courseId) == preferred
                let bPrimary = canonicalCourseId(b.prompt.courseId) == preferred
                if aPrimary != bPrimary { return aPrimary && !bPrimary }
            }
            if canonicalCourseId(a.prompt.courseId) != canonicalCourseId(b.prompt.courseId) {
                return canonicalCourseId(a.prompt.courseId) < canonicalCourseId(b.prompt.courseId)
            }
            let ia = promptIndex[a.prompt.id] ?? 0
            let ib = promptIndex[b.prompt.id] ?? 0
            return ia < ib
        }
        return turns
    }

    // MARK: - Heuristics (уроковый уровень, как ConversationFlowEngine)

    private static func isLearnable(_ item: StepItem) -> Bool {
        switch item.kind {
        case .word, .phrase, .casual:
            return StepData.isValidForProgress(item)
        case .tip, .dialog:
            return false
        }
    }

    private static func isDialogPrompt(_ item: StepItem) -> Bool {
        if item.is_question == true { return true }
        if item.conversation_is_prompt == true { return true }
        if item.conversation_next_order != nil { return true }
        let ru = (item.ru ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ru.contains("?")
    }

    private static func lessonStepsGrouped(_ steps: [GrandDialogueStitchedStep], courseId: String) -> [(lessonId: String, steps: [GrandDialogueStitchedStep])] {
        let lessons = catalogLessonsSorted(courseId: courseId)
        let lessonOrder = Dictionary(uniqueKeysWithValues: lessons.enumerated().map { ($0.element.lessonID, $0.offset) })
        var buckets: [String: [GrandDialogueStitchedStep]] = [:]
        for s in steps {
            buckets[s.lessonId, default: []].append(s)
        }
        return buckets
            .map { (lessonId: $0.key, steps: $0.value.sorted { $0.item.order < $1.item.order }) }
            .sorted { (lessonOrder[$0.lessonId] ?? Int.max) < (lessonOrder[$1.lessonId] ?? Int.max) }
    }

    private static func resolveReply(
        prompt: GrandDialogueStitchedStep,
        in lessonSteps: [GrandDialogueStitchedStep],
        learnables: [GrandDialogueStitchedStep],
        learnableOrders: Set<Int>
    ) -> GrandDialogueStitchedStep? {
        if let linked = learnables.first(where: { ($0.item.reply_to ?? -1) == prompt.item.order }) {
            return linked
        }
        if let n = prompt.item.conversation_next_order,
           let next = learnables.first(where: { $0.item.order == n }) {
            return next
        }
        guard let idx = lessonSteps.firstIndex(where: { $0.id == prompt.id }) else { return nil }
        for j in (idx + 1)..<lessonSteps.count {
            let cand = lessonSteps[j]
            if learnableOrders.contains(cand.item.order) { return cand }
        }
        return nil
    }

    private static func heuristicTurns(
        from steps: [GrandDialogueStitchedStep],
        preferredCourseId: String,
        existingPromptIds: Set<String>
    ) -> [GrandDialogueTurn] {
        var usedPrompts = existingPromptIds
        var result: [GrandDialogueTurn] = []

        for bucket in lessonStepsGrouped(steps, courseId: preferredCourseId) {
            let sorted = bucket.steps
            let learnables = sorted.filter { isLearnable($0.item) }
            guard learnables.count >= 2 else { continue }
            let learnableOrders = Set(learnables.map(\.item.order))
            var lessonPairs: [GrandDialoguePair] = []

            for prompt in learnables {
                guard lessonPairs.count < 2 else { break }
                guard isDialogPrompt(prompt.item) else { continue }
                guard let reply = resolveReply(
                    prompt: prompt,
                    in: sorted,
                    learnables: learnables,
                    learnableOrders: learnableOrders
                ) else { continue }
                guard reply.id != prompt.id else { continue }
                lessonPairs.append((prompt: prompt, reply: reply))
            }

            if lessonPairs.isEmpty {
                let best = pickBestAdjacentPair(from: learnables)
                if let best { lessonPairs.append(best) }
            }

            for pair in lessonPairs {
                guard !usedPrompts.contains(pair.prompt.id) else { continue }
                usedPrompts.insert(pair.prompt.id)
                result.append(GrandDialogueTurn(prompt: pair.prompt, expectedReplies: [pair.reply]))
            }
        }
        return result
    }

    /// Предпочитаем phrase/casual над одиночными словами.
    private static func pairScore(_ step: GrandDialogueStitchedStep) -> Int {
        switch step.item.kind {
        case .phrase, .casual: return 3
        case .word: return 1
        case .tip, .dialog: return 0
        }
    }

    private static func pickBestAdjacentPair(from learnables: [GrandDialogueStitchedStep]) -> GrandDialoguePair? {
        guard learnables.count >= 2 else { return nil }
        var best: GrandDialoguePair?
        var bestScore = -1
        for i in 0..<(learnables.count - 1) {
            let score = pairScore(learnables[i]) + pairScore(learnables[i + 1])
            if score > bestScore {
                bestScore = score
                best = (learnables[i], learnables[i + 1])
            }
        }
        return best
    }

    private static func lessonScopedAdjacentPairs(from steps: [GrandDialogueStitchedStep]) -> [GrandDialoguePair] {
        var out: [GrandDialoguePair] = []
        let courseIds = Set(steps.map(\.courseId))
        for cid in courseIds {
            for bucket in lessonStepsGrouped(steps, courseId: cid) {
                let learnables = bucket.steps.filter { isLearnable($0.item) }
                if let pair = pickBestAdjacentPair(from: learnables) {
                    out.append(pair)
                }
            }
        }
        return out
    }

    /// Начало → середина → конец курса; не больше `maxTurns` реплик.
    private static func sampleArcTurns(
        _ turns: [GrandDialogueTurn],
        maxTurns: Int,
        courseId: String
    ) -> [GrandDialogueTurn] {
        guard turns.count > maxTurns else { return turns }

        let grouped = lessonStepsGrouped(
            turns.map(\.prompt),
            courseId: courseId
        )
        let lessonOrder = grouped.map(\.lessonId)
        var byLesson: [String: [GrandDialogueTurn]] = [:]
        for t in turns {
            byLesson[t.prompt.lessonId, default: []].append(t)
        }

        var picked: [GrandDialogueTurn] = []
        var pickedIds = Set<String>()

        func take(from lessonId: String, limit: Int) {
            for t in (byLesson[lessonId] ?? []) {
                guard picked.count < maxTurns, pickedIds.insert(t.id).inserted else { continue }
                picked.append(t)
                if picked.filter({ $0.prompt.lessonId == lessonId }).count >= limit { break }
            }
        }

        if let first = lessonOrder.first { take(from: first, limit: 2) }
        if lessonOrder.count > 1, let last = lessonOrder.last { take(from: last, limit: 2) }

        let middleLessons = Array(lessonOrder.dropFirst().dropLast())
        if !middleLessons.isEmpty, picked.count < maxTurns {
            let slots = max(1, maxTurns - picked.count)
            let step = max(1, middleLessons.count / slots)
            for (i, lid) in middleLessons.enumerated() where i % step == 0 {
                take(from: lid, limit: 1)
                if picked.count >= maxTurns { break }
            }
        }

        if picked.count < maxTurns {
            for lid in lessonOrder {
                for t in (byLesson[lid] ?? []) {
                    guard picked.count < maxTurns, pickedIds.insert(t.id).inserted else { continue }
                    picked.append(t)
                }
            }
        }

        let lessonIndex = Dictionary(uniqueKeysWithValues: lessonOrder.enumerated().map { ($0.element, $0.offset) })
        return picked.sorted {
            let la = lessonIndex[$0.prompt.lessonId] ?? 0
            let lb = lessonIndex[$1.prompt.lessonId] ?? 0
            if la != lb { return la < lb }
            return $0.prompt.item.order < $1.prompt.item.order
        }
    }
}
