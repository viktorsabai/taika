//
//  HomeTaskManager.swift
//  taika
//
//  Created by product on 03.09.2025.
//
import Foundation

/// Unified source of favorites cards for games.
/// Used both by pre-check UI (can start game?) and by actual game data build.
@MainActor
public enum FavoritesGameSource {
    public typealias Triple = HomeTaskManager.LearnedTriple

    /// Parse step ref from favorites id variants:
    /// - card:step:courseId:lessonId:idxN
    /// - step:courseId:lessonId:idxN
    /// - step:course.lesson.slug
    /// - course.lesson.slug
    private static func parseStepRefId(_ ref: String) -> (courseId: String, lessonId: String, index: Int)? {
        let normalized = ref.lowercased()
        let parts = normalized.split(separator: ":").map(String.init)

        if parts.count >= 5, parts[0] == "card", parts[1] == "step" {
            let digits = parts[4].filter { $0.isNumber }
            guard let index = Int(digits) else { return nil }
            return (parts[2], parts[3], index)
        }

        if parts.count >= 4, parts[0] == "step" {
            if parts[1].contains("."), !parts[2].isEmpty, !parts[3].isEmpty, !parts[3].contains("idx") {
                let dotted = parts[1].split(separator: ".").map(String.init)
                guard dotted.count >= 2 else { return nil }
                return (dotted[0], dotted[1], 0)
            }
            let digits = parts[3].filter { $0.isNumber }
            guard let index = Int(digits) else { return nil }
            return (parts[1], parts[2], index)
        }

        if normalized.contains(".") {
            let dotted = normalized.split(separator: ".").map(String.init)
            if dotted.count >= 2 {
                return (dotted[0], dotted[1], 0)
            }
        }
        return nil
    }

    private static func normalizedFavoriteRefKey(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("card:") { s.removeFirst("card:".count) }
        return s
    }

    private static func lessonIdCandidatesForResolve(_ normalizedLessonId: String, stepData: StepData) -> [String] {
        var seen = Set<String>()
        var candidates: [String] = []
        func add(_ s: String) {
            guard !s.isEmpty, seen.insert(s).inserted else { return }
            candidates.append(s)
        }
        if let exact = stepData.lessonIdForCaseInsensitiveLookup(normalizedLessonId) { add(exact) }
        add(normalizedLessonId)
        add(normalizedLessonId.replacingOccurrences(of: "_", with: "-"))
        add(normalizedLessonId.replacingOccurrences(of: "-", with: "_"))
        return candidates
    }

    public static func triples() -> [Triple] {
        let manager = FavoriteManager.shared
        var refIds = manager.speakerStepIds()
        if refIds.isEmpty {
            refIds = manager.cardsDTO.map(\.sourceId)
        }
        guard !refIds.isEmpty else { return [] }

        let stepData = StepData.shared
        let cardsByKey: [String: FDCardDTO] = Dictionary(
            uniqueKeysWithValues: manager.cardsDTO.map { (normalizedFavoriteRefKey($0.sourceId), $0) }
        )
        var result: [Triple] = []
        var seen = Set<String>()

        for ref in refIds {
            guard let key = parseStepRefId(ref) else { continue }
            let lessonIds = lessonIdCandidatesForResolve(key.lessonId, stepData: stepData)
            var resolved: StepData.SpeakerResolved?
            var resolvedLessonId: String?
            for lid in lessonIds {
                resolved = stepData.speakerResolved(courseId: key.courseId, lessonId: lid, index: key.index)
                if resolved != nil {
                    resolvedLessonId = lid
                    break
                }
            }
            if let r = resolved {
                let ru = r.face.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !ru.isEmpty else { continue }
                let th = r.face.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines)
                let phRaw = r.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
                let ph = phRaw.isEmpty ? ru : phRaw
                if seen.insert(ru.lowercased()).inserted {
                    let lid = (resolvedLessonId ?? key.lessonId).trimmingCharacters(in: .whitespacesAndNewlines)
                    result.append(.init(ru: ru, th: th, ph: ph, lessonId: lid.isEmpty ? nil : lid))
                }
                continue
            }

            let canonicalStep = "step:\(key.courseId):\(key.lessonId):idx\(key.index)"
            let dto = cardsByKey[normalizedFavoriteRefKey(ref)] ?? cardsByKey[normalizedFavoriteRefKey(canonicalStep)]
            guard let dto else { continue }
            let ru = dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ru.isEmpty else { continue }
            let th = dto.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let phRaw = dto.meta.trimmingCharacters(in: .whitespacesAndNewlines)
            let ph = phRaw.isEmpty ? ru : phRaw
            if seen.insert(ru.lowercased()).inserted {
                result.append(.init(ru: ru, th: th, ph: ph, lessonId: nil))
            }
        }

        if !result.isEmpty { return result }

        // Hard fallback: visible favorites cards only.
        for dto in manager.cardsDTO {
            let sid = dto.sourceId.lowercased()
            let meta = dto.meta.lowercased()
            if sid.hasPrefix("hack:") || meta.hasPrefix("hack:") { continue }
            let ru = dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ru.isEmpty else { continue }
            let th = dto.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let phRaw = dto.meta.trimmingCharacters(in: .whitespacesAndNewlines)
            let ph = phRaw.isEmpty ? ru : phRaw
            if seen.insert(ru.lowercased()).inserted {
                result.append(.init(ru: ru, th: th, ph: ph, lessonId: nil))
            }
        }

        return result
    }
}

/// Персональный словарь умного спикера — пул для игр «закрепить» из drawer.
@MainActor
public enum DictionaryGameSource {
    public static let courseId = "__dictionary__"
    public typealias Triple = HomeTaskManager.LearnedTriple

    public static func isDictionaryCourseId(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == courseId
    }

    public static func triples(selectedSourceIds: Set<String>? = nil) -> [Triple] {
        let cards = FavoriteManager.shared.smartSpeakerDictionaryCardsDTO
        let filtered: [FDCardDTO]
        if let ids = selectedSourceIds, !ids.isEmpty {
            let normalized = Set(ids.map { $0.lowercased() })
            filtered = cards.filter { normalized.contains($0.sourceId.lowercased()) }
        } else {
            filtered = cards
        }
        var seen = Set<String>()
        var result: [Triple] = []
        for dto in filtered {
            let ru = dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ru.isEmpty else { continue }
            let th = dto.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            var phRaw = dto.meta.trimmingCharacters(in: .whitespacesAndNewlines)
            if phRaw.hasPrefix("card:") { phRaw = String(phRaw.dropFirst("card:".count)) }
            let ph = phRaw.isEmpty ? ru : phRaw
            if seen.insert(ru.lowercased()).inserted {
                result.append(.init(ru: ru, th: th, ph: ph, lessonId: nil))
            }
        }
        return result
    }

    public static var hasPlayableCards: Bool {
        triples().contains {
            !$0.ru.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.ph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

/// Псевдо-курс игрового парка с Main: все выученные карточки по всем курсам.
@MainActor
public enum LearnedGameSource {
    public static let pseudoCourseId = "__learned__"

    public typealias Triple = HomeTaskManager.LearnedTriple

    public static func isPseudoCourseId(_ raw: String) -> Bool {
        let c = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return c == pseudoCourseId || c == "--learned--"
    }

    /// Все валидные тройки (ru + фонетика) из ProgressManager — пул матча/викторины/Audio Recall с Main.
    public static func triples() -> [Triple] {
        HomeTaskManager().allLearnedUserTriples()
    }

    public static var hasPlayableCards: Bool {
        triples().contains {
            !$0.ru.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.ph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

@MainActor
public final class HomeTaskManager: ObservableObject {
    @Published public private(set) var tasksByCourse: [String: [HTask]] = [:]
    // Learned triples captured for each task id
    private var triplesByTask: [String: [LearnedTriple]] = [:]

    /// Rule for when to spawn a hometask
    public enum Rule {
        case everyNLessons(Int)
        case finalAfter(Int)
    }

    // MARK: - UI adapters
    /// Estimated time (in minutes) based on the number of triples in the task.
    @MainActor
    public func estimatedMinutes(for taskId: String) -> Int? {
        guard let c = triplesByTask[taskId]?.count, c > 0 else { return nil }
        // Heuristic: ~0.7 min per card, at least 3 minutes per task
        return max(3, Int(round(Double(c) * 0.7)))
    }

    /// Generic adapter that maps internal HTask + triples into a UI model using a builder closure.
    /// This lets LessonsDS/HT build its own `HT.Item` without tight coupling here.
    @MainActor
    public func hometasksFor<T>(courseId: String,
                                make: (_ task: HTask, _ isLocked: Bool, _ estMinutes: Int?, _ triples: [LearnedTriple]) -> T) -> [T] {
        let tasks = tasks(for: courseId)
        return tasks.map { t in
            let pool = triplesByTask[t.id] ?? []
            let locked = pool.isEmpty
            let minutes = estimatedMinutes(for: t.id)
            return make(t, locked, minutes, pool)
        }
    }

    public struct LearnedTriple {
        public let ru: String
        public let th: String
        public let ph: String
        /// Курс-источник карточки для global Game Park.
        public let courseId: String?
        /// Урок-источник карточки (для чипа на карточке в recall при игре по всему курсу).
        public let lessonId: String?
        public init(ru: String, th: String, ph: String, courseId: String? = nil, lessonId: String? = nil) {
            self.ru = ru
            self.th = th
            self.ph = ph
            self.courseId = courseId
            self.lessonId = lessonId
        }
    }

    // MARK: - Planning (UI-agnostic)
    public struct PlanDescriptor: Identifiable {
        public let id: String
        public let title: String
        public let index: Int
        public let triples: [LearnedTriple]
        public init(id: String, title: String, index: Int, triples: [LearnedTriple]) {
            self.id = id
            self.title = title
            self.index = index
            self.triples = triples
        }
    }

    // MARK: - Status & Kind (UI-agnostic)
    public enum HTAvailability: Equatable {
        case locked
        case available
        case done
    }

    /// Pick a game kind label by index (cyclic) or mark final as mixed.
    @inline(__always)
    public func gameKind(for index: Int, isFinal: Bool = false) -> String {
        if isFinal { return "смешанная" }
        let kinds = ["пары", "викторина", "аудио"]
        guard index >= 0 else { return kinds[0] }
        return kinds[index % kinds.count]
    }

    /// Determine availability for a planned descriptor using learned triples and any existing task state.
    @MainActor
    public func status(for descriptor: PlanDescriptor, courseId: String, minTriples: Int = 6) -> HTAvailability {
        // If we already have a concrete task with DONE status — surface that.
        if let existing = tasksByCourse[courseId]?.first(where: { $0.id == descriptor.id }) {
            if existing.status == .done { return .done }
            // If a real task exists but not done — consider it available.
            return .available
        }
        // Otherwise decide from the descriptor's pool size
        return descriptor.triples.count >= minTriples ? .available : .locked
    }

    /// Build a plan annotated with availability and game kind (no concrete HTask creation required).
    @MainActor
    public func availability(
        for courseId: String,
        lessonIds: [String],
        rule: Rule = .everyNLessons(3),
        samplePerTask: Int = 6,
        minTriples: Int = 6
    ) -> [(descriptor: PlanDescriptor, status: HTAvailability, game: String)] {
        let plan = plan(for: courseId, lessonIds: lessonIds, rule: rule, samplePerTask: samplePerTask)
        return plan.enumerated().map { idx, d in
            let isFinal = d.id.hasSuffix("-ht-final")
            return (d, status(for: d, courseId: courseId, minTriples: minTriples), gameKind(for: idx, isFinal: isFinal))
        }
    }

    /// Compute a plan of hometasks from learned data without constructing concrete HTask models.
    /// Use this when the caller wants to build view models or domain tasks on their side.
    @MainActor
    public func plan(
        for courseId: String,
        lessonIds: [String],
        rule: Rule = .everyNLessons(2),
        samplePerTask: Int = 6
    ) -> [PlanDescriptor] {
        var output: [PlanDescriptor] = []

        func appendChunked(n: Int) {
            guard n > 0 else { return }
            var i = 0
            var taskIndex = 1
            while i < lessonIds.count {
                let chunk = Array(lessonIds[i..<min(i + n, lessonIds.count)])
                var pool: [LearnedTriple] = []
                for lid in chunk { pool.append(contentsOf: learnedTriples(courseId: courseId, lessonId: lid)) }
                guard !pool.isEmpty else { i += n; continue }
                let picked = sample(pool, count: samplePerTask)
                let title = "Практика #\(taskIndex)"
                let id = "\(courseId)-ht-\(taskIndex)"
                output.append(.init(id: id, title: title, index: taskIndex, triples: picked))
                taskIndex += 1
                i += n
            }
        }

        func appendFinal(total: Int) {
            guard lessonIds.count >= total else { return }
            var pool: [LearnedTriple] = []
            for lid in lessonIds { pool.append(contentsOf: learnedTriples(courseId: courseId, lessonId: lid)) }
            guard !pool.isEmpty else { return }
            let picked = sample(pool, count: max(samplePerTask, 12))
            let id = "\(courseId)-ht-final"
            output.append(.init(id: id, title: "Итоговая практика", index: max(output.count + 1, 1), triples: picked))
        }

        switch rule {
        case .everyNLessons(let n):
            appendChunked(n: n)
        case .finalAfter(let total):
            appendFinal(total: total)
        }
        return output
    }

    public init() {}

    public func setTasks(_ tasks: [HTask], for courseId: String) {
        tasksByCourse[courseId] = tasks
    }

    public func tasks(for courseId: String) -> [HTask] {
        tasksByCourse[courseId] ?? []
    }

    public func triples(for taskId: String) -> [LearnedTriple] {
        triplesByTask[taskId] ?? []
    }

    public func progress(for courseId: String) -> HTaskProgress {
        let ts = tasks(for: courseId)
        let total = ts.count
        let done = ts.filter { $0.status == .done }.count
        return .init(done: done, total: total)
    }

    public func markDone(_ taskId: String, in courseId: String) {
        guard var arr = tasksByCourse[courseId], let idx = arr.firstIndex(where: { $0.id == taskId }) else { return }
        arr[idx].status = .done
        tasksByCourse[courseId] = arr
    }

    // MARK: - Data collection from progress / steps

    /// Parse step ref from FavoriteManager (step:courseId:lessonId:idxN) for favorites triples.
    /// Also accepts legacy/expanded forms like:
    /// - card:step:courseId:lessonId:idxN
    /// - step:course.lesson.slug
    /// - course.lesson.slug
    private func parseStepRefId(_ ref: String) -> (courseId: String, lessonId: String, index: Int)? {
        let normalized = ref.lowercased()
        let parts = normalized.split(separator: ":").map(String.init)

        if parts.count >= 5, parts[0] == "card", parts[1] == "step" {
            let courseId = parts[2]
            let lessonId = parts[3]
            let digits = parts[4].filter { $0.isNumber }
            guard let index = Int(digits) else { return nil }
            return (courseId, lessonId, index)
        }

        if parts.count >= 4, parts[0] == "step" {
            // canonical step:course:lesson:idxN
            if parts[1].contains("."), parts[2].isEmpty == false, parts[3].isEmpty == false, parts[3].contains("idx") == false {
                // legacy step:course.lesson.slug
                let dotted = parts[1].split(separator: ".").map(String.init)
                guard dotted.count >= 2 else { return nil }
                let courseId = dotted[0]
                let lessonId = dotted[1]
                let index = 0
                return (courseId, lessonId, index)
            }
            let courseId = parts[1]
            let lessonId = parts[2]
            let digits = parts[3].filter { $0.isNumber }
            guard let index = Int(digits) else { return nil }
            return (courseId, lessonId, index)
        }

        if normalized.contains(".") {
            let dotted = normalized.split(separator: ".").map(String.init)
            if dotted.count >= 2 {
                return (dotted[0], dotted[1], 0)
            }
        }
        return nil
    }

    /// Normalize mixed favorite ids (`card:step:...`, `step:...`) to one compare key.
    private func normalizedFavoriteRefKey(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("card:") { s.removeFirst("card:".count) }
        return s
    }

    @MainActor
    private func favoritesTriples() -> [LearnedTriple] {
        FavoritesGameSource.triples()
    }

    @MainActor
    private func dictionaryTriples() -> [LearnedTriple] {
        DictionaryGameSource.triples(selectedSourceIds: DictionarySessionSelection.shared.activeSourceIds)
    }

    /// Варианты lessonId для резолва (case-insensitive + underscore/dash), чтобы избранное работало при разном формате ключей в steps.json.
    private func lessonIdCandidatesForResolve(_ normalizedLessonId: String, stepData: StepData) -> [String] {
        var seen = Set<String>()
        var candidates: [String] = []
        func add(_ s: String) {
            guard !s.isEmpty, seen.insert(s).inserted else { return }
            candidates.append(s)
        }
        if let exact = stepData.lessonIdForCaseInsensitiveLookup(normalizedLessonId) { add(exact) }
        add(normalizedLessonId)
        add(normalizedLessonId.replacingOccurrences(of: "_", with: "-"))
        add(normalizedLessonId.replacingOccurrences(of: "-", with: "_"))
        return candidates
    }

    @MainActor
    private func learnedTriples(courseId: String, lessonId: String) -> [LearnedTriple] {
        // Progress keys канонизированы (`_`→`-`); steps.json часто с underscore —
        // резолвим lessonId как в FavoritesGameSource, иначе консоль Main врёт «нет фраз».
        let stepData = StepData.shared
        let candidates = lessonIdCandidatesForResolve(lessonId, stepData: stepData)
        var steps: [StepItem] = []
        for cand in candidates {
            let found = stepData.items(for: cand)
            if !found.isEmpty {
                steps = found
                break
            }
        }
        guard !steps.isEmpty else { return [] }

        let learnedIdx = ProgressManager.shared.learnedSet(courseId: courseId, lessonId: lessonId)
        var out: [LearnedTriple] = []
        var learnableOrdinal = 0
        for (i, it) in steps.enumerated() {
            switch it.kind {
            case .word, .phrase, .casual:
                let orderKey = it.order >= 0 ? it.order : i
                let matched = ProgressManager.matchesLearnedIndex(
                    learnedIdx,
                    order: orderKey,
                    enumerated: i,
                    learnableOrdinal: learnableOrdinal
                )
                learnableOrdinal += 1
                guard matched, let ru = it.ru else { continue }
                let th = it.thai ?? ""
                let ph = it.phonetic ?? ""
                out.append(.init(ru: ru, th: th, ph: ph, courseId: courseId, lessonId: lessonId))
            default:
                continue
            }
        }
        return out
    }

    /// Expose raw learned indices for a lesson (snapshot from ProgressManager)
    @MainActor
    public func learnedIndices(courseId: String, lessonId: String) -> Set<Int> {
        return ProgressManager.shared.learnedSet(courseId: courseId, lessonId: lessonId)
    }

    private func sample<T>(_ array: [T], count: Int) -> [T] {
        guard count < array.count else { return array }
        return Array(array.shuffled().prefix(count))
    }

    /// Rebuild hometasks for a course using a planning rule and a UI-agnostic builder.
    /// - Parameters:
    ///   - courseId: course to plan for
    ///   - lessonIds: ordered lesson ids for this course
    ///   - rule: grouping rule (default: one task per 2 lessons)
    ///   - samplePerTask: how many learned cards to include at most per task
    ///   - makeTask: builder that converts a title and card triples into an `HTask`
    @MainActor
    public func regenerateTasks(
        for courseId: String,
        lessonIds: [String],
        rule: Rule = .everyNLessons(2),
        samplePerTask: Int = 6,
        makeTask: (_ title: String, _ triples: [LearnedTriple], _ index: Int) -> HTask
    ) {
        var produced: [HTask] = []

        // 1) Блоковые домашки (каждые N уроков)
        func appendChunked(n: Int) {
            guard n > 0 else { return }
            var i = 0
            var taskIndex = 1
            while i < lessonIds.count {
                let chunk = Array(lessonIds[i..<min(i + n, lessonIds.count)])
                var pool: [LearnedTriple] = []
                for lid in chunk { pool.append(contentsOf: learnedTriples(courseId: courseId, lessonId: lid)) }
                guard !pool.isEmpty else { i += n; continue }
                let picked = sample(pool, count: samplePerTask)
                let title = "Практика #\(taskIndex)"
                let gameType: HomeGameType
                switch taskIndex % 3 {
                case 1: gameType = .match
                case 2: gameType = .recall
                default: gameType = .audioRecall
                }

                var task = makeTask(title, picked, taskIndex)
                task.gameType = gameType
                produced.append(task)
                triplesByTask[task.id] = picked
                taskIndex += 1
                i += n
            }
        }

        // 2) Финальная домашка (после total уроков)
        func appendFinal(total: Int) {
            guard lessonIds.count >= total else { return }
            var pool: [LearnedTriple] = []
            for lid in lessonIds { pool.append(contentsOf: learnedTriples(courseId: courseId, lessonId: lid)) }
            guard !pool.isEmpty else { return }
            let picked = sample(pool, count: max(samplePerTask, 12))
            let title = "Итоговая практика"
            var task = makeTask(title, picked, (produced.count + 1))
            // Grand Dialogue спрятан до доработки → итоговая = Audio Recall.
            task.gameType = TaikaReleaseFlags.showGrandDialogue ? .grandDialogue : .audioRecall
            produced.append(task)
            triplesByTask[task.id] = picked
        }

        switch rule {
        case .everyNLessons(let n):
            appendChunked(n: n)
        case .finalAfter(let total):
            appendFinal(total: total)
        }

        setTasks(produced, for: courseId)
    }

    // MARK: - Sync with current learned flags
    /// Refresh internal pools (triplesByTask) for already created tasks using the latest learned flags
    /// from ProgressManager. This does NOT create or delete tasks; it only rebinds their card pools
    /// so UI shows up-to-date content and availability/locking is correct.
    /// Call this after toggling learned or on app foreground with the same grouping rule
    /// you used for task creation.
    @MainActor
    public func syncFromProgress(
        for courseId: String,
        lessonIds: [String],
        rule: Rule = .everyNLessons(2),
        samplePerTask: Int = 6
    ) {
        // Build a fresh plan based on current learned flags
        let plan = plan(for: courseId, lessonIds: lessonIds, rule: rule, samplePerTask: samplePerTask)
        // Rebind pools for ids that we already have in tasksByCourse (leave unknown ids untouched)
        var map: [String: [LearnedTriple]] = [:]
        for d in plan {
            map[d.id] = d.triples
        }
        // Update existing tasks' pools
        if let tasks = tasksByCourse[courseId] {
            for task in tasks {
                if let triples = map[task.id] {
                    triplesByTask[task.id] = triples
                }
            }
        }
    }
    // MARK: - Normalization & Game Availability

    // MARK: - Phonetic Model (EPIC 2 Discovery)

    /// Syllable + optional tone marker after it. Tone markers (↘ → ↗) live in the mask, not in the selection pool.
    public struct PhoneticSegment: Equatable {
        public let syllable: String   // clean syllable for pool/validation (no diacritics, no tone)
        public let toneAfter: String? // tone displayed in mask after slot (e.g. "↘", "→", "↗", "↗?")

        public init(syllable: String, toneAfter: String?) {
            self.syllable = syllable
            self.toneAfter = toneAfter
        }
    }

    /// Tone arrow characters used in content (↘ → ↗). Optional ? suffix for questions.
    private static let toneArrows = CharacterSet(charactersIn: "↘→↗")
    /// Combining diacritics to strip from syllable (stress/vowel quality).
    private static let combiningDiacritics = CharacterSet(charactersIn: "\u{0301}\u{0300}\u{0302}\u{030C}\u{0304}\u{0308}")

    /// Parse phonetic string into segments. Syllables are clean; tone markers go into toneAfter.
    public func parsePhonetic(_ ph: String) -> [PhoneticSegment] {
        let trimmed = ph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let parts = trimmed
            .components(separatedBy: CharacterSet(charactersIn: "- "))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return parts.map { raw -> PhoneticSegment in
            var toneAfter: String? = nil
            var tail = raw
            // Trailing ? (question intonation)
            if tail.hasSuffix("?") {
                tail = String(tail.dropLast())
                if let last = tail.last, let scalar = String(last).unicodeScalars.first, Self.toneArrows.contains(scalar) {
                    toneAfter = String(last) + "?"
                    tail = String(tail.dropLast())
                } else {
                    toneAfter = "?"
                }
            }
            // Trailing tone arrow
            if toneAfter == nil, let last = tail.last, let scalar = String(last).unicodeScalars.first, Self.toneArrows.contains(scalar) {
                toneAfter = String(last)
                tail = String(tail.dropLast())
            }
            // Strip combining diacritics from syllable
            let clean = tail.unicodeScalars
                .filter { !Self.combiningDiacritics.contains($0) }
                .map { Character($0) }
            return PhoneticSegment(syllable: String(clean), toneAfter: toneAfter)
        }
    }

    /// Syllable count for a phonetic string (uses parsePhonetic; EPIC 2 Discovery).
    private func syllableCount(fromPhonetic ph: String) -> Int {
        parsePhonetic(ph).count
    }

    // MARK: - Builder Game (Tap-to-build word)

    public enum BuilderState {
        case idle
        case assembling
        case correct
        case wrong
        case finished
    }

    public struct BuilderRound: Identifiable {
        public let id = UUID()
        public let question: String
        public let target: String
        /// Full mask: segments with syllable + toneAfter for assembly zone
        public let segments: [PhoneticSegment]
        /// Clean syllables for pool (shuffled, may include distractors)
        public let syllables: [String]
        /// Correct clean syllables in order (for validation)
        public let correctPieces: [String]
        public let audioText: String?
        public let lessonId: String?
        public var slotCount: Int { segments.count }
    }

    @Published public private(set) var currentBuilderRound: BuilderRound?
    @Published public private(set) var builderAttemptCount: Int = 0
    /// Только неверные проверки (не путать с attemptCount).
    @Published public private(set) var builderMistakeCount: Int = 0
    @Published public private(set) var builderReinforcementScore: Int = 0
    @Published public private(set) var builderState: BuilderState = .idle
    @Published public var assembledBuilder: [String] = []
    /// При тапе по красному слоту — индекс слота на замену; тап по слогу в пуле заменяет этот слот.
    @Published public var builderSelectedSlotForReplacement: Int? = nil

    // Multi-round builder state
    @Published public private(set) var builderQueue: [LearnedTriple] = []
    @Published public private(set) var builderIndex: Int = 0
    @Published public private(set) var builderScore: Int = 0
    /// Ошибочные карточки только текущей builder-сессии; не смешивать с persisted course queue.
    @Published public private(set) var builderSessionFailedKeys: Set<String> = []

    public var builderTotalRounds: Int {
        builderQueue.count
    }

    public static func builderCardKey(_ triple: LearnedTriple) -> String {
        let lesson = (triple.lessonId ?? "").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "_", with: "-").lowercased()
        let phrase = triple.ru.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(lesson)|\(phrase)"
    }

    /// Display info for each round (for carousel). Question, phonetic target, thai.
    public struct BuilderRoundDisplay: Identifiable {
        public let id: Int
        public let question: String
        public let target: String
        public let thai: String
    }

    public var builderRoundDisplays: [BuilderRoundDisplay] {
        builderQueue.enumerated().map { index, triple in
            BuilderRoundDisplay(
                id: index,
                question: triple.ru.trimmingCharacters(in: .whitespacesAndNewlines),
                target: triple.ph.trimmingCharacters(in: .whitespacesAndNewlines),
                thai: triple.th.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    /// Switch to round at index (rebuilds current round, clears assembled). For carousel tap.
    @MainActor
    public func selectBuilderRound(at index: Int) {
        guard index >= 0, index < builderQueue.count else { return }
        builderIndex = index
        startNextBuilderRound()
        assembledBuilder = []
        builderState = .idle
    }

    public var builderProgressText: String {
        guard builderTotalRounds > 0 else { return "0/0" }
        return "\(min(builderIndex + 1, builderTotalRounds))/\(builderTotalRounds)"
    }

    public var builderScoreText: String {
        "\(builderScore)"
    }

    public var builderRequiredPiecesCount: Int {
        currentBuilderRound?.slotCount ?? 0
    }

    public var builderCanCheck: Bool {
        guard let round = currentBuilderRound, assembledBuilder.count == round.correctPieces.count else { return false }
        return assembledBuilder.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Start multi-round builder game from triples pool.
    /// For unified reinforcement logic across games we do NOT cap the queue and
    /// we do not exclude by syllable count here (all eligible learned cards should be included).
    @MainActor
    public func startBuilderRound(from triples: [LearnedTriple]) {
        let valid = triples.filter { !$0.ph.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !valid.isEmpty else { return }

        builderQueue = Array(valid.shuffled())
        builderIndex = 0
        builderScore = 0
        builderAttemptCount = 0
        builderMistakeCount = 0
        builderSessionFailedKeys = []
        assembledBuilder = []
        builderState = .idle

        startNextBuilderRound()
    }

    /// Advance to the next builder round in the queue
    private func startNextBuilderRound() {
        guard builderIndex < builderQueue.count else {
            builderState = .finished
            currentBuilderRound = nil
            return
        }

        let triple = builderQueue[builderIndex]
        let target = triple.ph.trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = parsePhonetic(target)
        let correctPieces = segments.map(\.syllable)

        var distractorPool: [String] = []
        for t in builderQueue where t.ph != triple.ph {
            distractorPool.append(contentsOf: parsePhonetic(t.ph).map(\.syllable))
        }

        distractorPool = Array(Set(distractorPool))
            .filter { !correctPieces.contains($0) }

        let maxTotal = 8
        let allowedDistractors = max(0, maxTotal - correctPieces.count)
        let distractors = distractorPool.shuffled().prefix(allowedDistractors)

        let finalPool = (correctPieces + distractors).shuffled()

        currentBuilderRound = BuilderRound(
            question: triple.ru,
            target: target,
            segments: segments,
            syllables: finalPool,
            correctPieces: correctPieces,
            audioText: triple.th.trimmingCharacters(in: .whitespaces).isEmpty ? nil : triple.th,
            lessonId: triple.lessonId
        )

        assembledBuilder = Array(repeating: "", count: currentBuilderRound?.slotCount ?? 0)
        builderState = .idle
    }

    /// Append tapped syllable into the selected slot, or the first empty slot.
    /// Slots are independent: the learner may fill them in any order.

    @MainActor
    public func appendBuilderPiece(_ piece: String) {
        guard let round = currentBuilderRound else { return }

        let targetIndex = builderSelectedSlotForReplacement
            ?? assembledBuilder.firstIndex(where: { $0.isEmpty })
        guard let idx = targetIndex, assembledBuilder.indices.contains(idx) else { return }
        assembledBuilder[idx] = piece
        builderSelectedSlotForReplacement = nil
        builderState = .assembling
    }

    /// Explicit check triggered by UI (button "Проверить"). No auto-validation; EPIC 2.
    @MainActor
    public func checkBuilderAnswer() {
        guard let round = currentBuilderRound else { return }
        guard builderCanCheck else { return }

        builderSelectedSlotForReplacement = nil
        builderAttemptCount += 1
        let isCorrect = assembledBuilder == round.correctPieces

        if isCorrect {
            builderState = .correct
            builderScore += 1
            builderReinforcementScore += 1
            // do NOT advance index here — wait for explicit advanceBuilderRound()
        } else {
            builderState = .wrong
            builderMistakeCount += 1
            if let triple = builderQueue.indices.contains(builderIndex) ? Optional(builderQueue[builderIndex]) : nil {
                builderSessionFailedKeys.insert(Self.builderCardKey(triple))
            }
            // keep assembled pieces so UI can highlight mismatch,
            // reset will be handled explicitly by UI or next attempt
        }
    }

    /// Remove last syllable (в режиме «неверно» сбрасываем в .assembling, чтобы не показывать красные слоты при неполной сборке).
    @MainActor
    public func removeLastBuilderPiece() {
        if let idx = assembledBuilder.lastIndex(where: { !$0.isEmpty }) {
            assembledBuilder[idx] = ""
            builderSelectedSlotForReplacement = nil
            if builderState == .wrong {
                builderState = .assembling
            }
        }
    }

    /// Снять последнее вхождение слога (повторный тап по чипу в пуле).
    @MainActor
    public func removeLastBuilderPiece(matching piece: String) {
        guard let idx = assembledBuilder.lastIndex(of: piece) else { return }
        assembledBuilder[idx] = ""
        builderSelectedSlotForReplacement = nil
        if builderState == .wrong || builderState == .assembling {
            builderState = assembledBuilder.allSatisfy({ $0.isEmpty }) ? .idle : .assembling
        }
    }

    /// Снять слог в конкретном слоте (тап по заполненному слоту).
    @MainActor
    public func removeBuilderPiece(at index: Int) {
        guard assembledBuilder.indices.contains(index) else { return }
        assembledBuilder[index] = ""
        builderSelectedSlotForReplacement = nil
        if builderState == .wrong || builderState == .assembling {
            builderState = assembledBuilder.allSatisfy({ $0.isEmpty }) ? .idle : .assembling
        }
    }

    /// Выбор слота для замены: при тапе по красному слоту запоминаем индекс; следующий тап по слогу в пуле заменит этот слот.
    @MainActor
    public func selectSlotForReplacement(_ index: Int?) {
        guard let index, assembledBuilder.indices.contains(index) else {
            builderSelectedSlotForReplacement = nil
            return
        }
        guard builderState == .wrong || builderState == .assembling || builderState == .idle else { return }
        builderSelectedSlotForReplacement = index
    }

    /// Снять выбор слота на замену.
    @MainActor
    public func clearSlotForReplacement() {
        builderSelectedSlotForReplacement = nil
    }

    /// Indices of wrong slots when state == .wrong (for highlighting; user can tap to clear from there)
    public var builderWrongSlotIndices: Set<Int> {
        guard builderState == .wrong,
              let round = currentBuilderRound,
              assembledBuilder.count == round.correctPieces.count else { return [] }
        return Set(assembledBuilder.indices.filter { !assembledBuilder[$0].isEmpty && assembledBuilder[$0] != round.correctPieces[$0] })
    }

    /// Reset builder state (очистить сборку и начать раунд заново).
    @MainActor
    public func resetBuilder() {
        assembledBuilder = Array(repeating: "", count: currentBuilderRound?.slotCount ?? 0)
        builderSelectedSlotForReplacement = nil
        builderState = .idle
    }

    /// Explicit transition to next round (called from View after feedback)
    @MainActor
    public func advanceBuilderRound() {
        guard builderState == .correct else { return }

        builderIndex += 1

        if builderIndex >= builderQueue.count {
            builderState = .finished
            currentBuilderRound = nil
            return
        }

        startNextBuilderRound()
        assembledBuilder = []
        builderState = .idle
    }


    // MARK: - Game Engine (v1)
    // Basic scoring & result calculation for gamification layer

    public struct HGameSessionState {
        public var total: Int
        public var correct: Int
        public var totalResponseTime: Double
        public var currentStreak: Int
        public var maxStreak: Int

        public init(total: Int) {
            self.total = total
            self.correct = 0
            self.totalResponseTime = 0
            self.currentStreak = 0
            self.maxStreak = 0
        }
    }

    @MainActor
    public func registerAnswer(
        isCorrect: Bool,
        responseTime: Double,
        state: inout HGameSessionState
    ) {
        state.totalResponseTime += responseTime

        if isCorrect {
            state.correct += 1
            state.currentStreak += 1
            state.maxStreak = max(state.maxStreak, state.currentStreak)
        } else {
            state.currentStreak = 0
        }
    }

    @MainActor
    public func finalizeResult(from state: HGameSessionState) -> HGameResult {
        let accuracy = state.total == 0 ? 0 : Double(state.correct) / Double(state.total)
        let avgTime = state.total == 0 ? 0 : state.totalResponseTime / Double(state.total)

        // simple scoring formula v1:
        // base = correct * 10
        // streak bonus = maxStreak * 5
        // speed bonus = inverse of avg time (capped)
        let base = state.correct * 10
        let streakBonus = state.maxStreak * 5
        let speedBonus = max(0, Int((5.0 - min(avgTime, 5.0)) * 5.0))

        let score = base + streakBonus + speedBonus

        return HGameResult(
            accuracy: accuracy,
            averageResponseTime: avgTime,
            maxStreak: state.maxStreak,
            score: score
        )
    }

    /// Clean user-facing triples: remove duplicates and fallback phonetic to RU if missing
    @MainActor
    public func userTriples(for courseId: String, lessonId: String) -> [LearnedTriple] {
        if LearnedGameSource.isPseudoCourseId(courseId) { return allLearnedUserTriples() }
        if courseId == "__favorites__" { return favoritesTriples() }
        if DictionaryGameSource.isDictionaryCourseId(courseId) { return dictionaryTriples() }
        let raw = learnedTriples(courseId: courseId, lessonId: lessonId)
        var seen = Set<String>()
        var result: [LearnedTriple] = []
        for t in raw {
            let ru = t.ru.trimmingCharacters(in: .whitespacesAndNewlines)
            let th = t.th.trimmingCharacters(in: .whitespacesAndNewlines)
            let phRaw = t.ph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ru.isEmpty else { continue }
            let ph = phRaw.isEmpty ? ru : phRaw
            if seen.insert(ru.lowercased()).inserted {
                result.append(.init(ru: ru, th: th, ph: ph, courseId: t.courseId, lessonId: t.lessonId))
            }
        }
        return result
    }

    /// Aggregate learned triples across multiple lessons (course-level console flow)
    @MainActor
    public func userTriplesForCourse(
        courseId: String,
        lessonIds: [String]
    ) -> [LearnedTriple] {
        if LearnedGameSource.isPseudoCourseId(courseId) { return allLearnedUserTriples() }
        if courseId == "__favorites__" { return favoritesTriples() }
        if DictionaryGameSource.isDictionaryCourseId(courseId) { return dictionaryTriples() }
        var raw: [LearnedTriple] = []
        for lid in lessonIds {
            raw.append(contentsOf: learnedTriples(courseId: courseId, lessonId: lid))
        }

        var seen = Set<String>()
        var result: [LearnedTriple] = []

        for t in raw {
            let ru = t.ru.trimmingCharacters(in: .whitespacesAndNewlines)
            let th = t.th.trimmingCharacters(in: .whitespacesAndNewlines)
            let phRaw = t.ph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ru.isEmpty else { continue }
            let ph = phRaw.isEmpty ? ru : phRaw
            if seen.insert(ru.lowercased()).inserted {
                result.append(.init(ru: ru, th: th, ph: ph, courseId: t.courseId, lessonId: t.lessonId))
            }
        }

        return result
    }

    /// Все выученные карточки по всем курсам (игровой парк с Main).
    @MainActor
    public func allLearnedUserTriples() -> [LearnedTriple] {
        var raw: [LearnedTriple] = []
        for (key, indices) in ProgressManager.shared.learnedSteps where !indices.isEmpty {
            raw.append(contentsOf: learnedTriples(courseId: key.courseId, lessonId: key.lessonId))
        }
        var seen = Set<String>()
        var result: [LearnedTriple] = []
        for t in raw {
            let ru = t.ru.trimmingCharacters(in: .whitespacesAndNewlines)
            let th = t.th.trimmingCharacters(in: .whitespacesAndNewlines)
            let phRaw = t.ph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !ru.isEmpty else { continue }
            let ph = phRaw.isEmpty ? ru : phRaw
            if seen.insert(ru.lowercased()).inserted {
                result.append(.init(ru: ru, th: th, ph: ph, courseId: t.courseId, lessonId: t.lessonId))
            }
        }
        return result
    }

    
    // MARK: - Flow helper
    @MainActor
    public func firstAvailableTask(for courseId: String) -> HTask? {
        let ts = tasks(for: courseId)
        // вернуть первую задачу, которая ещё не помечена done
        if let notDone = ts.first(where: { $0.status != .done }) {
            return notDone
        }
        // иначе просто первую (если массив не пуст)
        return ts.first
    }
}
