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
    case builder
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
