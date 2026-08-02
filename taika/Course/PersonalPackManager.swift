//
//  PersonalPackManager.swift
//  taika
//
//  Персональная подборка Pro: собирается из словаря умного спикера (user_dict).
//

import Foundation
import SwiftUI

// MARK: - Models

struct PersonalPackEntry: Codable, Equatable, Identifiable {
    var id: String { favoriteId }
    let favoriteId: String
    let dictIndex: Int
    let ru: String
    let th: String
    let phonetic: String
}

private struct PersonalPackSnapshot: Codable {
    var intent: String
    var builtAt: Date
    var entries: [PersonalPackEntry]
}

// MARK: - Manager

@MainActor
final class PersonalPackManager: ObservableObject {
    static let shared = PersonalPackManager()

    static let courseId = "user_dict"
    static let lessonId = "personal_pack"
    static let lessonTitle = "Мой словарь"

    private let storeKey = "taika.personal_pack.v1"

    @Published private(set) var entries: [PersonalPackEntry] = []
    @Published var userIntent: String = ""
    @Published private(set) var lastBuiltAt: Date?

    private init() {
        load()
    }

    var dictionaryCount: Int {
        FavoriteManager.shared.smartSpeakerDictionaryCardsDTO.count
    }

    var hasPack: Bool { !entries.isEmpty }

    // MARK: - UI helpers

    func carouselItems() -> [SDStepItem] {
        entries.enumerated().map { idx, e in
            SDStepItem(
                id: stableUUID(e.favoriteId),
                kind: .phrase,
                titleRU: e.ru,
                subtitleTH: e.th,
                phonetic: e.phonetic,
                isFavorite: true,
                isLearned: ProgressManager.shared
                    .learnedSet(courseId: Self.courseId, lessonId: Self.lessonId)
                    .contains(idx)
            )
        }
    }

    /// Одна строка под заголовком секции — без рамок и карточек.
    func sectionSubtitle(isPro: Bool) -> String {
        let n = dictionaryCount
        let packN = entries.count
        if !isPro {
            return n > 0
                ? "\(n) \(pluralPhrases(n)) в словаре · тренировка в Pro"
                : "Фразы из умного спикера · Pro"
        }
        if n == 0 { return "Скажи фразу в спикере — появится в словаре" }
        if packN == 0 { return "\(n) \(pluralPhrases(n)) · нажми «собрать»" }
        return "\(packN) \(pluralPhrases(packN)) · тапни карточку"
    }

    func taikaMessages(isPro: Bool) -> [String] {
        [sectionSubtitle(isPro: isPro)]
    }

    func fmHints() -> [String] {
        var hints: [String] = []
        let intent = userIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !intent.isEmpty {
            hints.append("Цель: \(intent)")
        }
        hints.append("Твои фразы из словаря — повторяй вслух и отмечай выученным.")
        if dictionaryCount > entries.count {
            hints.append("В словаре новые фразы — нажми «собрать» на экране курсов.")
        }
        return hints
    }

    // MARK: - Build / persist

    @discardableResult
    func buildPack() -> Int {
        let intent = userIntent.trimmingCharacters(in: .whitespacesAndNewlines)
        let built = buildEntriesFromDictionary()
        entries = built
        lastBuiltAt = Date()
        persist(intent: intent, entries: built)
        objectWillChange.send()
        return built.count
    }

    func bootstrapPackIfNeeded(isPro: Bool) {
        guard isPro, entries.isEmpty, dictionaryCount > 0 else { return }
        _ = buildPack()
    }

    func saveIntent(_ intent: String) {
        let trimmed = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        userIntent = trimmed
        if !entries.isEmpty {
            persist(intent: trimmed, entries: entries)
        }
    }

    /// Умный спикер в режиме диалога — собрать фразы для персонального курса.
    func openSmartSpeakerForPhrases(nav: NavigationIntent, returnTab: Int = 1) {
        SpeakerReturnContext.shared.save(tab: returnTab, path: nav.path)
        SpeakerManager.shared.setSpeakerUIMode(.conversation)
        nav.popToRoot()
        nav.requestTab(2)
    }

    @discardableResult
    func buildAndOpenLesson(nav: NavigationIntent) -> Bool {
        let count = buildPack()
        guard count > 0 else { return false }
        nav.go(.lesson(
            courseId: Self.courseId,
            lessonId: Self.lessonId,
            presentation: .personalPack(startIndex: 0)
        ))
        return true
    }

    // MARK: - StepData bridge (sync, no MainActor)

    nonisolated static func stepItemsFromStorage() -> [StepItem] {
        guard let snap = loadSnapshot() else { return [] }
        return snap.entries.enumerated().map { idx, e in
            StepItem(
                personalPackOrder: idx + 1,
                ru: e.ru,
                thai: e.th,
                phonetic: e.phonetic
            )
        }
    }

    nonisolated static func hintsFromStorage() -> [String] {
        guard let snap = loadSnapshot() else { return [] }
        var hints: [String] = []
        let intent = snap.intent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !intent.isEmpty { hints.append("Цель: \(intent)") }
        hints.append("Твои фразы из словаря — повторяй вслух и отмечай выученным.")
        return hints
    }

    // MARK: - Private

    private func buildEntriesFromDictionary() -> [PersonalPackEntry] {
        let favs = FavoriteManager.shared.items.filter { FavoriteManager.shared.isUserDictionaryItem($0) }
        let sorted = favs.sorted { a, b in
            if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
            return a.id > b.id
        }
        return sorted.compactMap { item in
            guard let idx = Self.parseDictIndex(from: item.id) else { return nil }
            return PersonalPackEntry(
                favoriteId: item.id,
                dictIndex: idx,
                ru: item.ru,
                th: item.th,
                phonetic: item.phonetic
            )
        }
    }

    private func load() {
        guard let snap = Self.loadSnapshot() else { return }
        entries = snap.entries
        userIntent = snap.intent
        lastBuiltAt = snap.builtAt
    }

    private func persist(intent: String, entries: [PersonalPackEntry]) {
        let snap = PersonalPackSnapshot(intent: intent, builtAt: Date(), entries: entries)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    nonisolated private static func loadSnapshot() -> PersonalPackSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: "taika.personal_pack.v1") else { return nil }
        return try? JSONDecoder().decode(PersonalPackSnapshot.self, from: data)
    }

    nonisolated static func parseDictIndex(from favoriteId: String) -> Int? {
        let fid = favoriteId.lowercased()
        guard fid.contains("step:\(courseId):\("smart_speaker"):idx") else { return nil }
        guard let last = fid.split(separator: ":").last, last.hasPrefix("idx") else { return nil }
        return Int(last.dropFirst(3))
    }

    private func stableUUID(_ seed: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, b) in seed.utf8.enumerated() where i < 16 {
            bytes[i] = b
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func pluralPhrases(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "фраз" }
        switch mod10 {
        case 1: return "фраза"
        case 2, 3, 4: return "фразы"
        default: return "фраз"
        }
    }
}

// MARK: - StepItem factory

extension StepItem {
    init(personalPackOrder order: Int, ru: String, thai: String, phonetic: String) {
        self.init(favoritesAudioRecallOrder: order, ru: ru, thai: thai, phonetic: phonetic)
    }
}
