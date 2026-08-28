//
//  HomeTaskData.swift
//  taika
//
//  Created by product on 03.09.2025.
//
import Foundation

public enum HTaskStatus: String, Codable, Equatable {
    case locked
    case available
    case inProgress
    case done
}

public enum HomeGameType: String, Codable, Equatable {
    case match
    case recall
    /// Legacy: тот же recall/builder UI (сборка по слогам).
    case builder
    /// Legacy rawValue в сохранённых задачах: маршрутизируется как `audioRecall`.
    case conversation
    /// Игра 3 (урок): чат-оболочка, аудио по-тайски, тайский скрыт до ответа; сборка перевода из слов (PRO).
    case audioRecall
    /// Игра 4 (курс): сценарий по `reply_to` / `is_question`, ответ голосом, движок как у Спикера (PRO).
    case grandDialogue
}

public extension HomeGameType {
    /// Старые домашки и `context` в навигации → Audio Recall.
    var normalizedForGameShell: HomeGameType {
        switch self {
        case .conversation:
            return .audioRecall
        case .grandDialogue where !TaikaReleaseFlags.showGrandDialogue:
            return .audioRecall
        default:
            return self
        }
    }

    /// Бесплатно только «Найди пару»; остальные режимы требуют PRO (см. `GameModeType.isPro`).
    var requiresProSubscription: Bool {
        switch normalizedForGameShell {
        case .match:
            return false
        case .recall, .builder, .audioRecall, .conversation, .grandDialogue:
            return true
        }
    }
}

public struct HTask: Identifiable, Codable, Equatable {
    public var id: String
    public var courseId: String
    public var lessonIndex: Int
    public var gameType: HomeGameType
    public var title: String
    public var details: String
    public var status: HTaskStatus
    public var updatedAt: Date

    public init(id: String = UUID().uuidString,
                courseId: String,
                lessonIndex: Int,
                gameType: HomeGameType,
                title: String,
                details: String = "",
                status: HTaskStatus,
                updatedAt: Date = .init()) {
        self.id = id
        self.courseId = courseId
        self.lessonIndex = lessonIndex
        self.gameType = gameType
        self.title = title
        self.details = details
        self.status = status
        self.updatedAt = updatedAt
    }
}

public struct HTaskProgress: Equatable {
    public var done: Int
    public var total: Int
    public var available: Int { min(done, total) }
}

public struct HGameResult: Equatable {
    public var accuracy: Double
    public var averageResponseTime: Double
    public var maxStreak: Int
    public var score: Int

    public init(
        accuracy: Double,
        averageResponseTime: Double,
        maxStreak: Int,
        score: Int
    ) {
        self.accuracy = accuracy
        self.averageResponseTime = averageResponseTime
        self.maxStreak = maxStreak
        self.score = score
    }
}

// MARK: - Lightweight done-status persistence (task ids only — no game state)

enum HomeTaskDoneStore {
    private static let key = "taika.homeTask.done.v1"

    private static func loadAll() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveAll(_ map: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func doneIds(for courseId: String) -> Set<String> {
        Set(loadAll()[courseId] ?? [])
    }

    static func markDone(taskId: String, courseId: String) {
        var map = loadAll()
        var ids = Set(map[courseId] ?? [])
        ids.insert(taskId)
        map[courseId] = Array(ids)
        saveAll(map)
    }

    static func applyDoneStatus(to tasks: inout [HTask], courseId: String) {
        let done = doneIds(for: courseId)
        guard !done.isEmpty else { return }
        for idx in tasks.indices where done.contains(tasks[idx].id) {
            tasks[idx].status = .done
        }
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
