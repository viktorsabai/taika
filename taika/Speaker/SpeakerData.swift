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
    /// Optional advanced score (0...100) when Pro breakdown/hybrid is available.
    let advancedScore: Int?
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
            NotificationCenter.default.post(name: .init("TaikaSpeakerAttemptsDidUpdate"), object: nil)
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
    /// Raw count of attempts today, tracked for Pro too (unlike `remainingToday`, which only gates free users).
    /// Source for "N фраз ≈ M минут, X% сегодня" on the training launcher screen.
    @Published public private(set) var usedToday: Int

    private let limit: Int

    public init(limit: Int = 10) {
        self.limit = limit
        self.remainingToday = limit
        self.usedToday = 0
        ensureDayReset()
        let used = Self.loadUsedToday()
        usedToday = used
        remainingToday = max(0, limit - used)
    }

    /// Call when user completes a mic recording in Speaker. PRO users are not limited but still tracked.
    public func consume() {
        ensureDayReset()
        var used = Self.loadUsedToday()
        if ProManager.shared.isPro {
            used += 1
            Self.saveUsedToday(used)
            usedToday = used
            return
        }
        guard used < limit else { return }
        used += 1
        Self.saveUsedToday(used)
        usedToday = used
        remainingToday = max(0, limit - used)
    }

    public var canRecord: Bool { remainingToday > 0 || ProManager.shared.isPro }

    public func refreshDayIfNeeded() {
        ensureDayReset()
        let used = Self.loadUsedToday()
        usedToday = used
        remainingToday = max(0, limit - used)
    }

    /// Product decision: if user explicitly clears all recordings in current block,
    /// return free attempts for today (onboarding-friendly behavior).
    public func restoreAllForToday() {
        ensureDayReset()
        Self.saveUsedToday(0)
        remainingToday = limit
        usedToday = 0
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
    @Published public private(set) var usedToday: Int

    public init() {
        self.remainingToday = conversationAttemptsLimit
        self.usedToday = 0
        ensureDayReset()
        let used = Self.loadUsedToday()
        usedToday = used
        remainingToday = max(0, conversationAttemptsLimit - used)
    }

    public func consume() {
        if ProManager.shared.isPro { return }
        ensureDayReset()
        var used = Self.loadUsedToday()
        guard used < conversationAttemptsLimit else { return }
        used += 1
        Self.saveUsedToday(used)
        usedToday = used
        remainingToday = max(0, conversationAttemptsLimit - used)
    }

    public var canRecord: Bool { remainingToday > 0 || ProManager.shared.isPro }

    /// Call when entering conversation mode or before starting record so remainingToday is correct after day change.
    public func refreshDayIfNeeded() {
        ensureDayReset()
        let used = Self.loadUsedToday()
        usedToday = used
        remainingToday = max(0, conversationAttemptsLimit - used)
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

// MARK: - Training launcher: course picker for "По фразам" idle screen (mult-select before starting a session)

/// One selectable course row on the training launcher — course id/title + how many phrases are ready to practice.
public struct SpeakerTrainingCourseOption: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let count: Int
}

/// Урок внутри курса на лаунчере тренировки — галочка + число фраз.
public struct SpeakerTrainingLessonOption: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let count: Int
}

/// Одна фраза в ленте «Своя речь» (как история Google Translate).
public struct SpeakerConversationHistoryItem: Identifiable, Equatable, Codable {
    public let id: UUID
    public let russian: String
    public let thai: String
    public let phonetic: String
    public let createdAt: Date
    /// Последний балл тренировки произношения по этой фразе (nil = ещё не тренировали).
    public let lastPracticeScore: Int?

    public init(
        id: UUID = UUID(),
        russian: String,
        thai: String,
        phonetic: String,
        createdAt: Date = Date(),
        lastPracticeScore: Int? = nil
    ) {
        self.id = id
        self.russian = russian
        self.thai = thai
        self.phonetic = phonetic
        self.createdAt = createdAt
        self.lastPracticeScore = lastPracticeScore
    }
}

/// Персист ленты «Своя речь» — сессия не пропадает при уходе с таба.
enum SpeakerConversationHistoryStore {
    private static let key = "taika.speaker.conversationHistory.v1"

    static func load() -> [SpeakerConversationHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        let raw = (try? JSONDecoder().decode([SpeakerConversationHistoryItem].self, from: data)) ?? []
        // Отбрасываем «фантомы» без русского (пустой RU + только фонетика/тайский — как stray «саватди»).
        let cleaned = raw.filter { item in
            !item.russian.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if cleaned.count != raw.count {
            save(cleaned)
        }
        return cleaned
    }

    static func save(_ items: [SpeakerConversationHistoryItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Request Speaker opened from course card (show only cards from this course)
@MainActor
public final class SpeakerRequestedCourseId: ObservableObject {
    public static let shared = SpeakerRequestedCourseId()
    @Published public var courseId: String?
    /// Optional single-lesson scope kept for existing entry points.
    @Published public var lessonId: String?
    /// Optional multi-lesson scope used by course reinforcement selection.
    @Published public var lessonIds: [String]?
    private init() {}

    public func set(_ id: String?, lessonId: String? = nil, lessonIds: [String]? = nil) {
        courseId = id
        self.lessonId = lessonId
        self.lessonIds = lessonIds
    }

    public func consume() -> (courseId: String, lessonId: String?, lessonIds: [String]?)? {
        guard let cid = courseId else { return nil }
        let lid = lessonId
        let lids = lessonIds
        courseId = nil
        lessonId = nil
        lessonIds = nil
        return (cid, lid, lids)
    }
}

// MARK: - Dictionary session scope (multi-select → train / games)
@MainActor
public final class DictionarySessionSelection {
    public static let shared = DictionarySessionSelection()
    /// nil = all dictionary phrases; non-empty = only these FavoriteItem ids.
    private(set) var activeSourceIds: Set<String>?
    private init() {}

    public func activate(_ ids: Set<String>?) {
        activeSourceIds = ids
    }

    public func clear() {
        activeSourceIds = nil
    }
}

// MARK: - Return context when Speaker was opened from a pushed screen (lesson/course) — back restores tab + path.
// Root tab ↔ tab (Избранное → Спикер) не сохраняем: иначе ложный back на одном уровне.
public enum SpeakerReturnSource: Equatable {
    case navigation
    case dictionary
}

public struct SpeakerReturnPayload: Equatable {
    public let tab: Int
    public let path: [NavigationIntent.Route]
    public let source: SpeakerReturnSource
}

@MainActor
public final class SpeakerReturnContext: ObservableObject {
    public static let shared = SpeakerReturnContext()
    private var savedTab: Int?
    private var savedPath: [NavigationIntent.Route] = []
    private var source: SpeakerReturnSource = .navigation
    private init() {}

    public var hasContext: Bool { savedTab != nil }

    /// Подпись CTA «вернуться»: из курса/урока/игры → обучение; из избранного → избранное; из словаря → словарь.
    public var returnActionTitle: String {
        if source == .dictionary { return "К словарю" }
        switch savedTab {
        case 1: return "К обучению"
        case 3: return "К избранному"
        case 0: return "На главную"
        default: return "Назад"
        }
    }

    public var returnActionIcon: String {
        if source == .dictionary { return "bookmark.fill" }
        switch savedTab {
        case 1: return "graduationcap.fill"
        case 3: return "heart.fill"
        case 0: return "house.fill"
        default: return "arrow.uturn.backward"
        }
    }

    /// Путь без игровых роутов: иначе «назад» из Спикера снова монтирует игру с нуля.
    public static func sanitizedPath(_ path: [NavigationIntent.Route]) -> [NavigationIntent.Route] {
        var cleaned = path
        while let last = cleaned.last {
            if case .game = last {
                cleaned.removeLast()
                continue
            }
            break
        }
        return cleaned
    }

    public func save(tab: Int, path: [NavigationIntent.Route]) {
        let cleaned = Self.sanitizedPath(path)
        guard !cleaned.isEmpty else {
            clear()
            return
        }
        savedTab = tab
        savedPath = cleaned
        source = .navigation
        objectWillChange.send()
        ShellHeaderDriver.shared.bump()
    }

    /// Словарь открыт как оверлей — путь пустой, но «назад» должен вернуть в панель словаря.
    public func saveFromDictionary(tab: Int) {
        savedTab = tab
        savedPath = []
        source = .dictionary
        objectWillChange.send()
        ShellHeaderDriver.shared.bump()
    }

    /// Явный переход в Спикер с корня вкладки (без push-стека) — нужна CTA «назад» на ту же вкладку.
    public func saveFromRootTab(_ tab: Int) {
        savedTab = tab
        savedPath = []
        source = .navigation
        objectWillChange.send()
        ShellHeaderDriver.shared.bump()
    }

    public func clear() {
        guard savedTab != nil || !savedPath.isEmpty || source != .navigation else { return }
        savedTab = nil
        savedPath = []
        source = .navigation
        objectWillChange.send()
        ShellHeaderDriver.shared.bump()
    }

    public func consume() -> SpeakerReturnPayload? {
        guard let tab = savedTab else { return nil }
        let payload = SpeakerReturnPayload(tab: tab, path: savedPath, source: source)
        savedTab = nil
        savedPath = []
        source = .navigation
        objectWillChange.send()
        ShellHeaderDriver.shared.bump()
        return payload
    }
}