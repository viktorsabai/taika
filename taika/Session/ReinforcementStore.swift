import Foundation

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

    public struct CourseMetrics: Codable, Equatable {
        public var byMode: [String: ModeMetrics]   // gameType rawValue -> metrics
        public init(byMode: [String: ModeMetrics] = [:]) {
            self.byMode = byMode
        }
    }

    @Published private(set) var courses: [String: CourseMetrics] = [:] // canonical courseId -> metrics

    private let storeKey = "taika.reinforcement.v1"
    private init() { load() }

    // MARK: - Public API

    public func recordSession(courseId: String, gameType: String, score: Int? = nil, playedAt: Date = Date()) {
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
        courses[cid] = cm
        save()
        objectWillChange.send()
    }

    public func metrics(courseId: String) -> CourseMetrics? {
        courses[canonicalizeCourseId(courseId)]
    }

    /// Convenience: an overall reinforcement score for a course (0...100).
    /// Uses available mode averages; if none exist, returns nil.
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

    private func canonicalizeCourseId(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.lowercased()
        s = s.replacingOccurrences(of: " ", with: "-")
        s = s.replacingOccurrences(of: "_", with: "-")
        while s.contains("--") { s = s.replacingOccurrences(of: "--", with: "-") }
        return s
    }
}

