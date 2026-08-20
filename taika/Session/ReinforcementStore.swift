import Foundation
import Combine

/// Persistent per-course reinforcement metrics (games practice).
/// MVP goal: let Course card back-face show a meaningful "reinforcement score"
/// derived from real game sessions (not from course progress).
@MainActor
public final class ReinforcementStore: ObservableObject {
    public static let shared = ReinforcementStore()

    public struct ModeMetrics: Codable, Equatable {
        public var sessions: Int
        /// Average score 0...100 when we can compute it; nil if we only track sessions.
        public var averageScore: Int?
        public var lastPlayedAt: Date?

        public init(sessions: Int = 0, averageScore: Int? = nil, lastPlayedAt: Date? = nil) {
            self.sessions = sessions
            self.averageScore = averageScore
            self.lastPlayedAt = lastPlayedAt
        }
    }

    public struct LessonMetrics: Codable, Equatable {
        public var sessions: Int
        public var coveredCardKeys: Set<String>
        /// Canonical lesson|card keys that still need targeted practice.
        public var failedCardKeys: Set<String>
        public var lastScore: Int?

        public init(sessions: Int = 0, coveredCardKeys: Set<String> = [], failedCardKeys: Set<String> = [], lastScore: Int? = nil) {
            self.sessions = sessions
            self.coveredCardKeys = coveredCardKeys
            self.failedCardKeys = failedCardKeys
            self.lastScore = lastScore
        }

        private enum CodingKeys: String, CodingKey {
            case sessions
            case coveredCardKeys
            case failedCardKeys
            case lastScore
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sessions = try container.decodeIfPresent(Int.self, forKey: .sessions) ?? 0
            coveredCardKeys = try container.decodeIfPresent(Set<String>.self, forKey: .coveredCardKeys) ?? []
            failedCardKeys = try container.decodeIfPresent(Set<String>.self, forKey: .failedCardKeys) ?? []
            lastScore = try container.decodeIfPresent(Int.self, forKey: .lastScore)
        }
    }

    public struct CourseMetrics: Codable, Equatable {
        public var byMode: [String: ModeMetrics]   // gameType rawValue -> metrics
        public var byLesson: [String: LessonMetrics]

        public init(byMode: [String: ModeMetrics] = [:], byLesson: [String: LessonMetrics] = [:]) {
            self.byMode = byMode
            self.byLesson = byLesson
        }

        private enum CodingKeys: String, CodingKey {
            case byMode
            case byLesson
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            byMode = try container.decodeIfPresent([String: ModeMetrics].self, forKey: .byMode) ?? [:]
            byLesson = try container.decodeIfPresent([String: LessonMetrics].self, forKey: .byLesson) ?? [:]
        }
    }

    @Published private(set) var courses: [String: CourseMetrics] = [:] // canonical courseId -> metrics

    private let storeKey = "taika.reinforcement.v1"
    private init() { load() }

    // MARK: - Public API

    public func recordSession(
        courseId: String,
        gameType: String,
        score: Int? = nil,
        sourceCardKeys: [String] = [],
        failedCardKeys: [String] = [],
        clearedCardKeys: [String] = [],
        lessonIds: [String] = [],
        playedAt: Date = Date()
    ) {
        let cid = canonicalizeCourseId(courseId)
        let mode = gameType

        var cm = courses[cid] ?? CourseMetrics()
        var mm = cm.byMode[mode] ?? ModeMetrics()

        mm.sessions += 1
        mm.lastPlayedAt = playedAt

        if let score {
            let clamped = max(0, min(100, score))
            if let existingAvg = mm.averageScore {
                // simple running average by sessions with score; good enough for MVP
                let n = max(1, mm.sessions)
                let prevTotal = existingAvg * max(0, n - 1)
                mm.averageScore = (prevTotal + clamped) / n
            } else {
                mm.averageScore = clamped
            }
        }

        cm.byMode[mode] = mm

        let normalizedKeys = Set(sourceCardKeys.compactMap { normalizeSourceCardKey($0) })
        let normalizedFailedKeys = Set(failedCardKeys.compactMap { normalizeSourceCardKey($0) })
        let normalizedClearedKeys = Set(clearedCardKeys.compactMap { normalizeSourceCardKey($0) })
        if !normalizedKeys.isEmpty {
            let grouped = Dictionary(grouping: normalizedKeys) { key in
                key.split(separator: "|", maxSplits: 1).first.map(String.init) ?? ""
            }
            for (rawLessonId, keys) in grouped where !rawLessonId.isEmpty {
                let lid = canonicalizeLessonId(rawLessonId)
                var lesson = cm.byLesson[lid] ?? LessonMetrics()
                lesson.sessions += 1
                lesson.coveredCardKeys.formUnion(keys)
                lesson.failedCardKeys.formUnion(normalizedFailedKeys.filter { $0.hasPrefix("\(rawLessonId)|") })
                lesson.failedCardKeys.subtract(normalizedClearedKeys.filter { $0.hasPrefix("\(rawLessonId)|") })
                lesson.lastScore = score.map { max(0, min(100, $0)) }
                cm.byLesson[lid] = lesson
            }
        } else {
            // Legacy learned cards may lack lessonId metadata. Preserve the result
            // at lesson level when the caller already knows the reinforcement scope.
            let scopedLessonIds = Set(lessonIds.compactMap { raw -> String? in
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : canonicalizeLessonId(value)
            })
            for lid in scopedLessonIds {
                var lesson = cm.byLesson[lid] ?? LessonMetrics()
                lesson.failedCardKeys.subtract(normalizedClearedKeys.filter { $0.hasPrefix("\(lid)|") })
                lesson.failedCardKeys.formUnion(normalizedFailedKeys.filter { $0.hasPrefix("\(lid)|") })
                lesson.sessions += 1
                lesson.lastScore = score.map { max(0, min(100, $0)) }
                cm.byLesson[lid] = lesson
            }
        }

        courses[cid] = cm
        save()
        objectWillChange.send()
    }

    public func metrics(courseId: String) -> CourseMetrics? {
        courses[canonicalizeCourseId(courseId)]
    }

    /// Lesson-level result with the same canonicalization used when game sessions are persisted.
    public func lessonScore(courseId: String, lessonId: String) -> Int? {
        metrics(courseId: courseId)?.byLesson[canonicalizeLessonId(lessonId)]?.lastScore
    }

    /// Convenience: an overall reinforcement score for a course (0...100).
    /// Uses available mode averages; if none exist, returns nil.
    public func coveredCardCount(courseId: String) -> Int {
        metrics(courseId: courseId)?.byLesson.values.reduce(0) { $0 + $1.coveredCardKeys.count } ?? 0
    }

    public func failedCardKeys(courseId: String, lessonIds: [String] = []) -> Set<String> {
        guard let cm = metrics(courseId: courseId) else { return [] }
        let selected = Set(lessonIds.map(canonicalizeLessonId))
        return cm.byLesson.filter { selected.isEmpty || selected.contains($0.key) }.reduce(into: Set<String>()) { result, entry in
            result.formUnion(entry.value.failedCardKeys)
        }
    }

    public func coveredCardCount(courseId: String, lessonId: String) -> Int {
        let lid = canonicalizeLessonId(lessonId)
        return metrics(courseId: courseId)?.byLesson[lid]?.coveredCardKeys.count ?? 0
    }

    public func gameSessions(courseId: String, lessonId: String? = nil) -> Int {
        guard let cm = metrics(courseId: courseId) else { return 0 }
        if let lessonId {
            return cm.byLesson[canonicalizeLessonId(lessonId)]?.sessions ?? 0
        }
        return cm.byLesson.values.reduce(0) { $0 + $1.sessions }
    }

    public func overallScore(courseId: String, modes: [String] = ["match", "recall", "audioRecall"]) -> Int? {
        guard let cm = metrics(courseId: courseId) else { return nil }
        let scores = modes.compactMap { cm.byMode[$0]?.averageScore }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(courses)
            UserDefaults.standard.set(data, forKey: storeKey)
            NotificationCenter.default.post(name: .init("TaikaReinforcementDidUpdate"), object: nil)
        } catch {
            // silent fail
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return }
        do {
            courses = try JSONDecoder().decode([String: CourseMetrics].self, from: data)
        } catch {
            courses = [:]
        }
    }

    private func normalizeSourceCardKey(_ raw: String) -> String? {
        let parts = raw.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let lesson = canonicalizeLessonId(parts[0])
        let card = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lesson.isEmpty, !card.isEmpty else { return nil }
        return "\(lesson)|\(card)"
    }

    private func canonicalizeLessonId(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        s = s.replacingOccurrences(of: " ", with: "-")
        s = s.replacingOccurrences(of: "_", with: "-")
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        return s
    }

    private func canonicalizeCourseId(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.lowercased()
        s = s.replacingOccurrences(of: " ", with: "-")
        s = s.replacingOccurrences(of: "_", with: "-")
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        return s
    }
}



/// One-shot course lesson scope used when a completed-course selection launches Game Park.
@MainActor
public final class GameRequestedCourseScope: ObservableObject {
    public static let shared = GameRequestedCourseScope()
    @Published public private(set) var courseId: String?
    @Published public private(set) var lessonIds: [String]?
    @Published public private(set) var cardKeys: [String]?

    private init() {}

    public func set(courseId: String, lessonIds: [String], cardKeys: [String]? = nil) {
        self.courseId = courseId
        self.lessonIds = lessonIds
        self.cardKeys = cardKeys
    }

    public func clear() {
        courseId = nil
        lessonIds = nil
        cardKeys = nil
    }
}
