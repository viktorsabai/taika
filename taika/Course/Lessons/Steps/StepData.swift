//
//  StepData.swift
//  taika
//
//  Created by product on 29.08.2025.
//

//
//  StepData.swift
//  taika
//
//  Created by product on 29.08.2025.
//

import Foundation

// MARK: - Public access facade
final class StepData {
    static let shared = StepData()

    private let fileName = "steps" // steps.json in bundle
    private var stepsetsByLessonId: [String: StepSet] = [:]
    private var isLoaded = false
    private var loadedURL: URL?
    private var loadedVersion: Int?
    private var loadedHash: String?

    private init() {}

    // Load once, or reload if the bundle file changed/version bumped. Safe to call from App or onAppear.
    func preload(force: Bool = false) {
        // hot path: if already loaded, do nothing (avoid repeated file IO + hashing)
        if isLoaded && !force { return }
        var lastURL: URL?
        do {
            let url = try bundleURL()
            lastURL = url
            let data = try Data(contentsOf: url)

            // Single decode: use result for both version check and map (avoids 2x full parse of large JSON)
            let decoded = try JSONDecoder.stepsDecoder.decode(StepsRoot.self, from: data)

            let version = decoded.version
            let hash = Self.sha256Hex(data)

            let shouldReload: Bool = force || !isLoaded || loadedURL != url || version != loadedVersion || loadedHash != hash
            guard shouldReload else { return }

            var map: [String: StepSet] = [:]
            for set in decoded.stepsets { map[set.lesson_id] = set }

            self.stepsetsByLessonId = map
            self.isLoaded = true
            self.loadedURL = url
            self.loadedVersion = version
            self.loadedHash = hash
            Self.logHead(url: url, data: data, hash: hash)
        } catch {
            if let url = lastURL {
                Self.logJSONSyntaxErrorIfAny(for: url)
            }
            Self.logError(error)
        }
    }

    // Explicit manual reload (e.g., after replacing steps.json or switching targets)
    func reload() { isLoaded = false; loadedURL = nil; loadedVersion = nil; preload(force: true) }

    // Returns stepset for a given lessonId, if present
    func stepset(for lessonId: String) -> StepSet? {
        preload()
        return stepsetsByLessonId[lessonId]
    }

    /// Resolve actual lessonId from steps.json when caller has normalized id (e.g. lowercased from FavoriteManager).
    /// Use in buildFavoritesQueue so Speaker can resolve favorites regardless of case in JSON.
    func lessonIdForCaseInsensitiveLookup(_ normalizedLessonId: String) -> String? {
        preload()
        let lower = normalizedLessonId.lowercased()
        return stepsetsByLessonId.keys.first { $0.lowercased() == lower }
    }

    // Convenience: items for lesson, already sorted by order
    func items(for lessonId: String) -> [StepItem] {
        preload()
        if lessonId == PersonalPackManager.lessonId {
            return PersonalPackManager.stepItemsFromStorage()
        }
        return stepsetsByLessonId[lessonId]?.items.sorted(by: { $0.order < $1.order }) ?? []
    }

    /// Atomic contract for learnable steps (word/phrase/casual): transcript must exist so the step can be shown and counted.
    /// Audio is optional for progress (used by Speaker when playing). Invalid steps are excluded from progress totals.
    public static func isValidForProgress(_ item: StepItem) -> Bool {
        switch item.kind {
        case .word, .phrase, .casual:
            let hasTranscript = (item.phonetic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            return hasTranscript
        case .tip, .dialog:
            return false
        }
    }

    /// Indices of steps that are learnable (word/phrase/casual) but invalid (missing transcript).
    /// Caller should exclude these from progressEligibleIndices and add to excludedProgressIndexes.
    public func invalidProgressIndices(for lessonId: String) -> Set<Int> {
        preload()
        let itemsList = stepsetsByLessonId[lessonId]?.items.sorted(by: { $0.order < $1.order }) ?? []
        var invalid = Set<Int>()
        for item in itemsList {
            switch item.kind {
            case .word, .phrase, .casual:
                if !Self.isValidForProgress(item) {
                    invalid.insert(item.order)
                    #if DEBUG
                    print("[StepData] invalid step for progress lessonId=\(lessonId) order=\(item.order) kind=\(item.kind.rawValue)")
                    #endif
                }
            case .tip, .dialog:
                break
            }
        }
        return invalid
    }

    /// Total learnable (word+phrase+casual) and lifehack (tip+dialog) counts for a lesson. Source of truth for progress denominator.
    public func progressCounts(for lessonId: String) -> (learnable: Int, lifehack: Int) {
        preload()
        let itemsList = stepsetsByLessonId[lessonId]?.items.sorted(by: { $0.order < $1.order }) ?? []
        var learnable = 0, lifehack = 0
        for item in itemsList {
            switch item.kind {
            case .word, .phrase, .casual: learnable += 1
            case .tip, .dialog: lifehack += 1
            }
        }
        return (learnable, lifehack)
    }

    // Convenience: Taika FM hints for lesson
    func hints(for lessonId: String) -> [String] {
        preload()
        if lessonId == PersonalPackManager.lessonId {
            return PersonalPackManager.hintsFromStorage()
        }
        return stepsetsByLessonId[lessonId]?.hints ?? []
    }

    /// Returns a flat array of all StepItem across all lessons.
    /// Safe for previews and daily picks; relies on internal cache.
    func allItems() -> [StepItem] {
        preload()
        return stepsetsByLessonId.values.flatMap { $0.items }
    }
    
    /// Returns all lessons with their items, preserving lessonId for callers that need context.
    func allLessonItems() -> [(lessonId: String, items: [StepItem])] {
        preload()
        return stepsetsByLessonId.map { (key: String, value: StepSet) in
            return (lessonId: key, items: value.items)
        }
    }

    // MARK: - Speaker helpers (MVP)

    public struct SpeakerResolved: Equatable {
        public let courseId: String
        public let lessonId: String
        public let index: Int
        public let kind: StepItem.Kind
        public let face: StepFace
        public let audioKey: String?
    }

    /// Resolve a step by canonical key (lessonId + order). Public for SpeakerManager.
    public func item(lessonId: String, order: Int) -> StepItem? {
        preload()
        return resolveItem(lessonId: lessonId, order: order)
    }

    /// Resolve a pronounceable step (word/phrase/casual) into Speaker payload.
    /// Returns nil if the step doesn't exist or isn't suitable for speaking practice.
    public func speakerResolved(courseId: String, lessonId: String, index: Int) -> SpeakerResolved? {
        preload()

        // steps.json uses `order` as the canonical key. Callers may pass order or 0-based UI index.
        // Skip tips/dialogs: if the first match isn't speakable, keep probing +1 (up to a small window).
        for offset in 0..<4 {
            let candidate = index + offset
            guard let it = resolveItem(lessonId: lessonId, order: candidate)
                    ?? (offset == 0 ? resolveItem(lessonId: lessonId, order: index + 1) : nil)
            else { continue }

            switch it.kind {
            case .word, .phrase, .casual:
                let face = face(for: it)
                return SpeakerResolved(
                    courseId: courseId,
                    lessonId: lessonId,
                    index: it.order,
                    kind: it.kind,
                    face: face,
                    audioKey: it.audio
                )
            default:
                continue
            }
        }
        return nil
    }

    /// Parse a learnedSteps key from UserSession snapshot. Expected format: "<courseId>|<lessonId>".
    public static func splitLearnedKey(_ key: String) -> (courseId: String, lessonId: String)? {
        let parts = key.split(separator: "|", omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        return (courseId: String(parts[0]), lessonId: String(parts[1]))
    }
    
    // MARK: - Index helpers (canonical order lookup)

    /// Returns canonical index (order) of a step inside lesson, if it exists.
    /// Primary key is `order`; for safety we can also try to match by contents for tips/words.
    @MainActor
    public func index(of step: StepItem, courseId: String? = nil, lessonId: String) -> Int? {
        preload()
        // Fast path: use declared order when it exists in the lesson
        if let found = resolveItem(lessonId: lessonId, order: step.order) {
            return found.order
        }
        // Content-based fallback (in case orders drifted during mapping)
        guard let set = stepsetsByLessonId[lessonId] else { return nil }
        switch step.kind {
        case .word, .phrase, .casual:
            let ru = (step.ru ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let th = (step.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let idx = set.items.first(where: {
                ($0.ru ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == ru &&
                ($0.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == th
            })?.order {
                return idx
            }
        case .tip:
            let t = (step.text ?? step.tip ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let idx = set.items.first(where: {
                (($0.text ?? $0.tip ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) == t
            })?.order {
                return idx
            }
        case .dialog:
            // dialogs are not used in daily picks; skip
            break
        }
        return nil
    }

    // Overload for DS item → вычисляем канонический order по содержимому
    @MainActor
    public func index(of dsItem: SDStepItem, courseId: String? = nil, lessonId: String) -> Int? {
        preload()
        // быстрый путь: если удаётся найти по содержимому, вернём order
        guard let set = stepsetsByLessonId[lessonId] else { return nil }

        // нормализатор
        func clean(_ s: String?) -> String {
            (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        switch dsItem.kind {
        case .word, .phrase, .casual:
            let ru = clean(dsItem.titleRU)
            let th = clean(dsItem.subtitleTH)
            if let idx = set.items.first(where: {
                clean($0.ru) == ru && clean($0.thai) == th
            })?.order {
                return idx
            }
            // фоллбек: матчим хотя бы по одному полю, если второе пустое в одном из источников
            if let idx = set.items.first(where: {
                let ruMatch = !ru.isEmpty && clean($0.ru) == ru
                let thMatch = !th.isEmpty && clean($0.thai) == th
                return ruMatch || thMatch
            })?.order {
                return idx
            }

        case .tip:
            // в DS для tip текст лежит в titleRU; матчим на StepItem.text/tip
            let t = clean(dsItem.titleRU)
            if let idx = set.items.first(where: {
                clean($0.text ?? $0.tip) == t
            })?.order {
                return idx
            }

        default:
            // у SDStepItem.Kind нет .dialog; прочие типы для daily picks не индексируем
            return nil
        }

        return nil
    }

    /// Returns canonical index by `order` if the item exists in lesson.
    @MainActor
    public func index(ofOrder order: Int, lessonId: String) -> Int? {
        preload()
        return resolveItem(lessonId: lessonId, order: order)?.order
    }

    // MARK: - Daily picks (static for a day)
    private let dailyPicksKeyPrefix = "daily_picks_"
    private let dailySaltKey = "daily_picks_salt"
    private func currentSalt() -> Int { UserDefaults.standard.integer(forKey: dailySaltKey) }

    /// Returns a stable selection for the current day (Asia/Bangkok). Refreshes automatically next day.
    /// The result is deterministic for a given day and steps.json content.
    @MainActor func dailyPicks(count: Int) -> [(lessonId: String, item: StepItem)] {
        return dailyPicksKeys(count: count).map { ($0.lessonId, $0.item) }
    }

    /// Step ref for priority ordering (Smart Discovery contract). Empty = current behavior.
    public struct StepRef: Hashable {
        public let courseId: String
        public let lessonId: String
        public let index: Int
        public init(courseId: String, lessonId: String, index: Int) {
            self.courseId = courseId
            self.lessonId = lessonId
            self.index = index
        }
    }

    /// Returns daily picks with exact keys used by ProgressManager (courseId, lessonId, index).
    /// - Parameter priorityStepRefs: optional list of step refs to prioritize (for future Smart Discovery). Empty = current deterministic behavior.
    @MainActor func dailyPicksKeys(count: Int, priorityStepRefs: [StepRef] = []) -> [(courseId: String, lessonId: String, index: Int, item: StepItem)] {
        preload()

        let key = dailyKey()
        if let data = UserDefaults.standard.data(forKey: key),
           let refs = try? JSONDecoder().decode([PickRef].self, from: data) {
            // Important: keep picks stable for the whole day.
            // We do NOT drop items that became learned after the list was generated.
            let resolved: [(String, String, Int, StepItem)] = refs.compactMap { ref in
                guard let set = stepsetsByLessonId[ref.lessonId],
                      let item = resolveItem(lessonId: ref.lessonId, order: ref.order),
                      isValidForDaily(item) else { return nil }
                return (set.course_id, ref.lessonId, ref.order, item)
            }
            if resolved.count == count { return resolved }
            // if mismatch (e.g., steps.json changed), rebuild below
        }

        // Build deterministic order based on today's seed + content hash + salt, then take first N
        let seed = (loadedHash ?? "") + key + "#salt=" + String(currentSalt())
        // flatten to (courseId, lessonId, item)
        let flattened: [(courseId: String, lessonId: String, item: StepItem)] = stepsetsByLessonId
            .flatMap { (lessonId, set) in set.items
                .filter { isValidForDaily($0) }
                .map { (courseId: set.course_id, lessonId: lessonId, item: $0) } }

        // Exclude already learned
        let candidates = flattened.filter { !isLearned(courseId: $0.courseId, lessonId: $0.lessonId, order: $0.item.order) }

        // Balance types: prefer core (word/phrase/casual), allow up to 2 tips
        var core: [(courseId: String, lessonId: String, item: StepItem)] = []
        var tips: [(courseId: String, lessonId: String, item: StepItem)] = []
        for c in candidates {
            switch c.item.kind {
            case .word, .phrase, .casual: core.append(c)
            case .tip: tips.append(c)
            case .dialog: break
            }
        }
        // deterministic order within buckets
        core.sort { stableScore(seed: seed, lessonId: $0.lessonId, order: $0.item.order) < stableScore(seed: seed, lessonId: $1.lessonId, order: $1.item.order) }
        tips.sort { stableScore(seed: seed, lessonId: $0.lessonId, order: $0.item.order) < stableScore(seed: seed, lessonId: $1.lessonId, order: $1.item.order) }

        let coreQuota = min( max(3, count - 2), count )
        let tipQuota  = min( 2, max(0, count - coreQuota) )

        func interleaveByLesson(_ arr: [(courseId: String, lessonId: String, item: StepItem)], limit: Int, excluding keys: Set<String> = []) -> [(courseId: String, lessonId: String, item: StepItem)] {
            if limit <= 0 || arr.isEmpty { return [] }
            // bucket by lesson
            var buckets: [String: [(courseId: String, lessonId: String, item: StepItem)]] = [:]
            for x in arr {
                let key = "\(x.lessonId)#\(x.item.order)"
                if keys.contains(key) { continue }
                buckets[x.lessonId, default: []].append(x)
            }
            // maintain deterministic order of buckets by the first item's existing order in `arr`
            let lessonOrder: [String] = arr.map { $0.lessonId }
            var uniqueLessons: [String] = []
            for l in lessonOrder { if !uniqueLessons.contains(l), buckets[l] != nil { uniqueLessons.append(l) } }
            var out: [(courseId: String, lessonId: String, item: StepItem)] = []
            var idx = 0
            while out.count < limit && !uniqueLessons.isEmpty {
                let l = uniqueLessons[idx]
                if var bucket = buckets[l], !bucket.isEmpty {
                    out.append(bucket.removeFirst())
                    buckets[l] = bucket
                    if bucket.isEmpty { uniqueLessons.remove(at: idx); if uniqueLessons.isEmpty { break } ; idx = idx % uniqueLessons.count }
                    else { idx = (idx + 1) % uniqueLessons.count }
                } else {
                    uniqueLessons.remove(at: idx)
                    if uniqueLessons.isEmpty { break }
                    idx = idx % uniqueLessons.count
                }
            }
            return out
        }

        var selected: [(courseId: String, lessonId: String, item: StepItem)] = []
        // 1) core round‑robin по урокам
        let corePick = interleaveByLesson(core, limit: coreQuota)
        selected.append(contentsOf: corePick)
        // 2) tips round‑robin по урокам
        let tipPick = interleaveByLesson(tips, limit: tipQuota, excluding: Set(selected.map{ "\($0.lessonId)#\($0.item.order)" }))
        selected.append(contentsOf: tipPick)
        // 3) добиваем остаток, сохраняя разброс по урокам
        if selected.count < count {
            let usedKeys = Set(selected.map{ "\($0.lessonId)#\($0.item.order)" })
            let moreCore = interleaveByLesson(core, limit: count - selected.count, excluding: usedKeys)
            selected.append(contentsOf: moreCore)
        }
        if selected.count < count {
            let usedKeys2 = Set(selected.map{ "\($0.lessonId)#\($0.item.order)" })
            let moreTips = interleaveByLesson(tips, limit: count - selected.count, excluding: usedKeys2)
            selected.append(contentsOf: moreTips)
        }

        // Enforce course diversity: aim for ≥4 unique courses (if available)
        // Phase 1: take at most 1 item per course, round‑robin by course order derived from `selected`
        var bucketsByCourse: [String: [(courseId: String, lessonId: String, item: StepItem)]] = [:]
        for x in selected { bucketsByCourse[x.courseId, default: []].append(x) }
        var courseOrder: [String] = []
        for c in selected.map({ $0.courseId }) { if !courseOrder.contains(c) { courseOrder.append(c) } }

        func takeRound(limit: Int, maxPerCourse: Int, buckets: inout [String: [(courseId: String, lessonId: String, item: StepItem)]], order: inout [String], already: inout [String: Int]) -> [(courseId: String, lessonId: String, item: StepItem)] {
            var out: [(courseId: String, lessonId: String, item: StepItem)] = []
            if limit <= 0 || order.isEmpty { return out }
            var i = 0
            while out.count < limit && !order.isEmpty {
                let c = order[i]
                let taken = already[c] ?? 0
                if taken < maxPerCourse, var bucket = buckets[c], !bucket.isEmpty {
                    let next = bucket.removeFirst()
                    buckets[c] = bucket
                    already[c] = taken + 1
                    out.append(next)
                    if bucket.isEmpty || already[c]! >= maxPerCourse {
                        order.remove(at: i)
                        if order.isEmpty { break }
                        i = i % order.count
                    } else {
                        i = (i + 1) % order.count
                    }
                } else {
                    order.remove(at: i)
                    if order.isEmpty { break }
                    i = i % order.count
                }
            }
            return out
        }

        var diversified: [(courseId: String, lessonId: String, item: StepItem)] = []
        var takenPerCourse: [String: Int] = [:]
        var buckets1 = bucketsByCourse
        var order1 = courseOrder
        diversified.append(contentsOf: takeRound(limit: count, maxPerCourse: 1, buckets: &buckets1, order: &order1, already: &takenPerCourse))

        if diversified.count < count {
            var buckets2 = buckets1
            var order2 = Array(buckets2.keys) // remaining courses still having items
            // keep deterministic ordering based on first appearance in `selected`
            order2.sort { (l, r) in
                (courseOrder.firstIndex(of: l) ?? Int.max) < (courseOrder.firstIndex(of: r) ?? Int.max)
            }
            diversified.append(contentsOf: takeRound(limit: count - diversified.count, maxPerCourse: 2, buckets: &buckets2, order: &order2, already: &takenPerCourse))
        }

        // Fallback: if всё ещё не добрали, просто доливаем в исходном порядке
        if diversified.count < count {
            for x in selected {
                if diversified.count >= count { break }
                // avoid exact duplicates (lessonId+order)
                let key = "\(x.lessonId)#\(x.item.order)"
                let exists = diversified.contains { $0.lessonId == x.lessonId && $0.item.order == x.item.order }
                if !exists { diversified.append(x) }
            }
        }

        let keyed = diversified.prefix(max(0, count)).map { (courseId: $0.courseId, lessonId: $0.lessonId, index: $0.item.order, item: $0.item) }

        // Persist references for the day (with courseId)
        let refs = keyed.map { PickRef(courseId: $0.courseId, lessonId: $0.lessonId, order: $0.index) }
        if let data = try? JSONEncoder().encode(refs) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return keyed
    }

    /// Manually invalidate cached daily picks (e.g., for debug button)
    func resetDailyPicksCache() {
        let key = dailyKey()
        // bump salt so a fresh deterministic order is produced even within the same day
        let salt = UserDefaults.standard.integer(forKey: dailySaltKey)
        UserDefaults.standard.set(salt + 1, forKey: dailySaltKey)
        // drop today's cached refs
        UserDefaults.standard.removeObject(forKey: key)
        // notify listeners to reload immediately
        NotificationCenter.default.post(name: .init("DailyPicksDidReset"), object: nil)
    }

    // Uses Asia/Bangkok to define the day boundary
    private func dailyKey(for date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return "\(dailyPicksKeyPrefix)\(y)-\(String(format: "%02d", m))-\(String(format: "%02d", d))"
    }

    // Only allow items that render properly in daily picks (разминка). Лайфхаки (.tip) не показываем.
    private func isValidForDaily(_ item: StepItem) -> Bool {
        switch item.kind {
        case .word, .phrase, .casual:
            guard let ru = item.ru?.trimmingCharacters(in: .whitespacesAndNewlines), !ru.isEmpty,
                  let th = item.thai?.trimmingCharacters(in: .whitespacesAndNewlines), !th.isEmpty else { return false }
            return true
        case .tip, .dialog:
            return false
        }
    }

    @MainActor private func isLearned(courseId: String, lessonId: String, order: Int) -> Bool {
        ProgressManager.shared.learnedSet(courseId: courseId, lessonId: lessonId).contains(order)
    }
    // Deterministic sortable score from seed + (lessonId, order)
    private func stableScore(seed: String, lessonId: String, order: Int) -> UInt64 {
        let s = "\(seed)#\(lessonId)#\(order)"
        var hash: UInt64 = 1469598103934665603 // FNV-1a 64-bit offset
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    // Resolve StepItem by composite key
    private func resolveItem(lessonId: String, order: Int) -> StepItem? {
        return stepsetsByLessonId[lessonId]?.items.first(where: { $0.order == order })
    }

    private struct PickRef: Codable { let courseId: String; let lessonId: String; let order: Int }
    
    /// Returns a human-readable lesson title; now uses LessonsManager metadata
    @MainActor
    func titleForLesson(courseId: String, lessonId: String) -> String {
        let title = LessonsManager.shared.titleForLesson(courseId: courseId, lessonId: lessonId)
        return title
    }

    // MARK: - Projection for UI (DS-agnostic)
    struct StepFace: Equatable {
        let kind: StepItem.Kind
        let titleRU: String
        let subtitleTH: String
        let phonetic: String
    }

    /// Maps raw StepItem into a UI-friendly face (keeps Data layer independent from DS).
    func face(for item: StepItem) -> StepFace {
        switch item.kind {
        case .word, .phrase, .casual:
            let ru = (item.ru ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let th = (item.thai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let ph = (item.phonetic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return StepFace(kind: item.kind, titleRU: ru, subtitleTH: th, phonetic: ph)
        case .tip:
            // prefer `text`, fallback to `tip`
            let t = (item.text ?? item.tip ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return StepFace(kind: .tip, titleRU: t, subtitleTH: "", phonetic: "")
        case .dialog:
            // dialogs сейчас не идут в подборку дня (isValidForDaily=false), но на всякий — пустой фейс
            return StepFace(kind: .dialog, titleRU: "", subtitleTH: "", phonetic: "")
        }
    }

    /// Build SpeakerResolved from arbitrary RU/TH/phonetic (например, фразы из Smart Speaker, которых нет в steps.json).
    /// Используется для персонального словаря: курс user_dict / урок smart_speaker.
    func speakerResolvedFromCustom(
        courseId: String,
        lessonId: String,
        index: Int,
        ru: String,
        thai: String,
        phonetic: String
    ) -> SpeakerResolved {
        let ruTrim = ru.trimmingCharacters(in: .whitespacesAndNewlines)
        let thTrim = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        let phTrim = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        let face = StepFace(
            kind: .phrase,
            titleRU: ruTrim,
            subtitleTH: thTrim,
            phonetic: phTrim
        )
        return SpeakerResolved(
            courseId: courseId,
            lessonId: lessonId,
            index: index,
            kind: .phrase,
            face: face,
            audioKey: nil
        )
    }
}

// MARK: - Models matching steps.json
struct StepsRoot: Decodable {
    let version: Int
    let stepsets: [StepSet]
}

struct StepSet: Decodable {
    let id: String
    let course_id: String
    let lesson_id: String
    let hints: [String]?
    let items: [StepItem]
}

struct StepItem: Decodable {
    enum Kind: String, Decodable { case word, phrase, casual, tip, dialog }

    let order: Int
    let kind: Kind

    // for word/phrase
    let ru: String?
    let thai: String?
    let phonetic: String?
    let audio: String?
    let tip: String?

    // for tip
    let text: String?

    // for dialog (optional support – won’t break if present)
    let scene: String?
    let lines: [DialogLine]?

    /// Явная связка для игры «поток диалога»: `order` карточки-ответа после реплики-вопроса.
    let conversation_next_order: Int?
    /// Если true, эта карточка считается репликой-сигналом к ответу (без «?» в `ru`).
    let conversation_is_prompt: Bool?
    /// Grand Dialogue: реплика — вопрос/ход NPC, на который нужен ответ пользователя.
    let is_question: Bool?
    /// Grand Dialogue: эта карточка — ответ пользователя на реплику с `order == reply_to` (в том же уроке).
    let reply_to: Int?
}

extension StepItem {
    /// Карточка для Audio Recall из пула избранного (без steps.json); те же поля, что в `LearnedTriple` для матча/викторины.
    init(favoritesAudioRecallOrder order: Int, ru: String, thai: String?, phonetic: String) {
        self.order = order
        self.kind = .phrase
        self.ru = ru
        self.thai = thai
        self.phonetic = phonetic
        self.audio = nil
        self.tip = nil
        self.text = nil
        self.scene = nil
        self.lines = nil
        self.conversation_next_order = nil
        self.conversation_is_prompt = nil
        self.is_question = nil
        self.reply_to = nil
    }
}

struct DialogLine: Decodable {
    let who: String
    let ru: String
    let th: String?
    let phonetic: String?
    let audio: String?
}

// MARK: - JSONDecoder helpers
private extension JSONDecoder {
    static var stepsDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }
}

// MARK: - Bundle + Logging
private extension StepData {
    static func logJSONSyntaxErrorIfAny(for url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            let nsError = error as NSError
            let index = nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int
            let debug = (nsError.userInfo["NSDebugDescription"] as? String) ?? nsError.localizedDescription
            if let index = index {
                let contextRadius = 40
                let start = max(0, index - contextRadius)
                let end = min(data.count, index + contextRadius)
                let slice = data[start..<end]
                let snippet = String(data: slice, encoding: .utf8) ?? ""
                print("[StepsLoader][JSON] syntax error around byte \(index): \(debug)\n...\(snippet)...")
            } else {
                print("[StepsLoader][JSON] syntax error: \(debug)")
            }
        }
    }

    func bundleURL() throws -> URL {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            throw LoaderError.fileNotFound(name: fileName)
        }
        return url
    }

    static func logHead(url: URL, data: Data, hash: String? = nil) {
        let head = String(data: data.prefix(180), encoding: .utf8) ?? ""
        let short = (hash ?? sha256Hex(data)).prefix(8)
        print("[StepsLoader] using: \(url.path) (sha256: \(short))\n[StepsLoader] head: \n\(head)")
    }

    static func logError(_ error: Error) {
        switch error {
        case LoaderError.fileNotFound(let name):
            print("[StepsLoader][ERROR] steps file not found: \(name).json")
        case let DecodingError.dataCorrupted(ctx):
            print("[StepsLoader][DECODE] dataCorrupted at path: \(ctx.codingPath.map{ $0.stringValue }.joined(separator: ".")) — \(ctx.debugDescription)")
        case let DecodingError.keyNotFound(key, ctx):
            print("[StepsLoader][DECODE] keyNotFound: \(key.stringValue) at path: \(ctx.codingPath.map{ $0.stringValue }.joined(separator: ".")) — \(ctx.debugDescription)")
        case let DecodingError.typeMismatch(type, ctx):
            print("[StepsLoader][DECODE] typeMismatch: \(type) at path: \(ctx.codingPath.map{ $0.stringValue }.joined(separator: ".")) — \(ctx.debugDescription)")
        case let DecodingError.valueNotFound(type, ctx):
            print("[StepsLoader][DECODE] valueNotFound: \(type) at path: \(ctx.codingPath.map{ $0.stringValue }.joined(separator: ".")) — \(ctx.debugDescription)")
        default:
            print("[StepsLoader][ERROR] \(error)")
        }
    }

    enum LoaderError: Error { case fileNotFound(name: String) }
}

import CryptoKit

private extension StepData {
    static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
