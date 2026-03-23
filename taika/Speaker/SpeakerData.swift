//
//  SpeakerData.swift
//  taika
//
//  Created by product on 26.12.2025.
//

import Foundation
import CryptoKit

// MARK: - B3: Persistence models for speaker attempts

/// Stored result of a speaker attempt for a specific step
struct SpeakerAttemptResult: Codable, Equatable {
    let courseId: String
    let lessonId: String
    let stepIndex: Int
    
    let heardThai: String?
    let heardTranslit: String?
    let heardConfidence: Int
    let attemptCount: Int
    let lastAttemptURL: String? // stored as path string
    
    let timestamp: Date
}

/// Storage key for UserDefaults
private let speakerAttemptsStoreKey = "SpeakerManager.attempts.v1"

/// B3: Persistence helper for speaker attempts
struct SpeakerAttemptsStore {
    static func save(attempt: SpeakerAttemptResult, forKey key: String) {
        var all = loadAll()
        all[key] = attempt
        saveAll(all)
    }
    
    static func load(forKey key: String) -> SpeakerAttemptResult? {
        return loadAll()[key]
    }
    
    static func loadAll() -> [String: SpeakerAttemptResult] {
        guard let data = UserDefaults.standard.data(forKey: speakerAttemptsStoreKey) else {
            return [:]
        }
        do {
            return try JSONDecoder().decode([String: SpeakerAttemptResult].self, from: data)
        } catch {
            return [:]
        }
    }
    
    static func saveAll(_ attempts: [String: SpeakerAttemptResult]) {
        do {
            let data = try JSONEncoder().encode(attempts)
            UserDefaults.standard.set(data, forKey: speakerAttemptsStoreKey)
        } catch {
            // silent fail in production
        }
    }
    
    /// Generate storage key for a step
    static func key(courseId: String, lessonId: String, stepIndex: Int) -> String {
        return "\(courseId)|\(lessonId)|\(stepIndex)"
    }

    /// Unique file URL for this step's recording (one file per card; не перезаписываем общим рекордером).
    /// Храним в Application Support, чтобы iOS не удалял файлы при нехватке места (Caches могут очищаться).
    static func recordingFileURL(courseId: String, lessonId: String, stepIndex: Int) -> URL {
        let k = key(courseId: courseId, lessonId: lessonId, stepIndex: stepIndex)
        let digest = SHA256.hash(data: Data(k.utf8))
        let hex = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SpeakerRecordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(hex).m4a")
    }

    /// Remove persisted attempt for one step (e.g. user "сбросить запись" in Speaker). Удаляет и файл записи.
    static func remove(forKey key: String) {
        if let attempt = load(forKey: key),
           let path = attempt.lastAttemptURL,
           let url = URL(string: path),
           FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        var all = loadAll()
        all.removeValue(forKey: key)
        saveAll(all)
    }

    /// Clear all persisted attempts (e.g. on app-wide progress reset in Profile). Удаляет и файлы записей.
    static func clearAll() {
        for (_, attempt) in loadAll() {
            if let path = attempt.lastAttemptURL,
               let url = URL(string: path),
               FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        saveAll([:])
    }
}

// MARK: - EPIC 2: Daily attempts for Speaker (header badge; resets daily)
import Combine

private let dailyAttemptsDateKey = "SpeakerDailyAttempts.date"
private let dailyAttemptsUsedKey = "SpeakerDailyAttempts.used"

@MainActor
public final class SpeakerDailyAttemptsStore: ObservableObject {
    public static let shared = SpeakerDailyAttemptsStore()

    @Published public private(set) var remainingToday: Int

    private let limit: Int

    public init(limit: Int = 10) {
        self.limit = limit
        self.remainingToday = limit
        ensureDayReset()
        remainingToday = max(0, limit - Self.loadUsedToday())
    }

    /// Call when user completes a mic recording in Speaker. PRO users are not limited.
    public func consume() {
        if ProManager.shared.isPro { return }
        ensureDayReset()
        var used = Self.loadUsedToday()
        guard used < limit else { return }
        used += 1
        Self.saveUsedToday(used)
        remainingToday = max(0, limit - used)
    }

    private func ensureDayReset() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let todayStr = formatter.string(from: Date())
        if UserDefaults.standard.string(forKey: dailyAttemptsDateKey) != todayStr {
            UserDefaults.standard.set(todayStr, forKey: dailyAttemptsDateKey)
            Self.saveUsedToday(0)
        }
    }

    private static func loadUsedToday() -> Int {
        UserDefaults.standard.integer(forKey: dailyAttemptsUsedKey)
    }

    private static func saveUsedToday(_ value: Int) {
        UserDefaults.standard.set(value, forKey: dailyAttemptsUsedKey)
    }
}

// MARK: - Conversation mode: 3 demo attempts per day for free; Pro unlimited
private let conversationAttemptsDateKey = "SpeakerConversationAttempts.date"
private let conversationAttemptsUsedKey = "SpeakerConversationAttempts.used"
private let conversationAttemptsLimit = 3

@MainActor
public final class SpeakerConversationAttemptsStore: ObservableObject {
    public static let shared = SpeakerConversationAttemptsStore()

    @Published public private(set) var remainingToday: Int

    public init() {
        self.remainingToday = conversationAttemptsLimit
        ensureDayReset()
        remainingToday = max(0, conversationAttemptsLimit - Self.loadUsedToday())
    }

    public func consume() {
        if ProManager.shared.isPro { return }
        ensureDayReset()
        var used = Self.loadUsedToday()
        guard used < conversationAttemptsLimit else { return }
        used += 1
        Self.saveUsedToday(used)
        remainingToday = max(0, conversationAttemptsLimit - used)
    }

    public var canRecord: Bool { remainingToday > 0 || ProManager.shared.isPro }

    /// Call when entering conversation mode or before starting record so remainingToday is correct after day change.
    public func refreshDayIfNeeded() {
        ensureDayReset()
        remainingToday = max(0, conversationAttemptsLimit - Self.loadUsedToday())
    }

    private func ensureDayReset() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let todayStr = formatter.string(from: Date())
        if UserDefaults.standard.string(forKey: conversationAttemptsDateKey) != todayStr {
            UserDefaults.standard.set(todayStr, forKey: conversationAttemptsDateKey)
            Self.saveUsedToday(0)
        }
    }

    private static func loadUsedToday() -> Int {
        UserDefaults.standard.integer(forKey: conversationAttemptsUsedKey)
    }

    private static func saveUsedToday(_ value: Int) {
        UserDefaults.standard.set(value, forKey: conversationAttemptsUsedKey)
    }
}

// MARK: - Request Speaker opened from course card (show only cards from this course)
@MainActor
public final class SpeakerRequestedCourseId: ObservableObject {
    public static let shared = SpeakerRequestedCourseId()
    @Published public var courseId: String?
    private init() {}
    public func set(_ id: String?) { courseId = id }
    public func consume() -> String? {
        let v = courseId
        courseId = nil
        return v
    }
}

// MARK: - Return context when Speaker was opened via CTA (e.g. from Lessons/Step) — show back to restore tab + path
@MainActor
public final class SpeakerReturnContext: ObservableObject {
    public static let shared = SpeakerReturnContext()
    private var savedTab: Int?
    private var savedPath: [NavigationIntent.Route] = []
    private init() {}
    public var hasContext: Bool { savedTab != nil }
    public func save(tab: Int, path: [NavigationIntent.Route]) {
        savedTab = tab
        savedPath = path
    }
    public func consume() -> (tab: Int, path: [NavigationIntent.Route])? {
        guard let tab = savedTab else { return nil }
        let path = savedPath
        savedTab = nil
        savedPath = []
        return (tab, path)
    }
}