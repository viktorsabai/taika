//
//  taikafmData.swift
//  taika
//

import Foundation

// единый скоуп для всех экранов, где есть таика fm
public enum TaikaFMScope: String, CaseIterable, Codable {
    case main
    case course
    case resume
    case scenarios
    case dictionary
    case mine
    case lessons
    case step
    case fav
    case speaker
    case profile
    case games
}

// конфиг для одного скоупа в taikafm.json
public struct TaikaFMScopeConfig: Decodable {
    public let messages: [String]
    public let reactions: [String]

    public init(messages: [String] = [], reactions: [String] = []) {
        self.messages = messages
        self.reactions = reactions
    }

    public static let empty = TaikaFMScopeConfig()
}

// корневой json taikafm.json — все ключи опциональны, чтобы один пропуск не ломал весь файл
private struct TaikaFMRootConfig: Decodable {
    let version: Int?
    let main: TaikaFMScopeConfig?
    let course: TaikaFMScopeConfig?
    let resume: TaikaFMScopeConfig?
    let scenarios: TaikaFMScopeConfig?
    let dictionary: TaikaFMScopeConfig?
    let mine: TaikaFMScopeConfig?
    let lessons: TaikaFMScopeConfig?
    let step: TaikaFMScopeConfig?
    let fav: TaikaFMScopeConfig?
    let speaker: TaikaFMScopeConfig?
    let profile: TaikaFMScopeConfig?
    let games: TaikaFMScopeConfig?

    func config(for scope: TaikaFMScope) -> TaikaFMScopeConfig {
        switch scope {
        case .main:       return main ?? .empty
        case .course:     return course ?? .empty
        case .resume:     return resume ?? .empty
        case .scenarios:  return scenarios ?? .empty
        case .dictionary: return dictionary ?? .empty
        case .mine:       return mine ?? .empty
        case .lessons:    return lessons ?? .empty
        case .step:       return step ?? .empty
        case .fav:        return fav ?? .empty
        case .speaker:    return speaker ?? .empty
        case .profile:    return profile ?? .empty
        case .games:      return games ?? .empty
        }
    }
}

/// один фрагмент текста Таика FM с пометкой, акцентный он или нет
public struct TaikaFMChunk: Equatable {
    public let text: String
    public let isAccent: Bool
}

/// единая точка доступа к taikafm.json
public final class TaikaFMData {
    public static let shared = TaikaFMData()

    private let root: TaikaFMRootConfig?

    private init() {
        if
            let url = Bundle.main.url(forResource: "taikafm", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(TaikaFMRootConfig.self, from: data)
        {
            self.root = decoded
        } else {
            self.root = nil
            #if DEBUG
            print("[TaikaFMData] failed to load taikafm.json")
            #endif
        }
    }

    /// сообщения для конкретного экрана
    public func messages(for scope: TaikaFMScope) -> [String] {
        root?.config(for: scope).messages ?? []
    }

    /// реакции для конкретного экрана в виде маленьких групп по одному эмодзи
    public func reactionGroups(for scope: TaikaFMScope) -> [[String]] {
        guard let flat = root?.config(for: scope).reactions, !flat.isEmpty else { return [] }
        return flat.map { [$0] }
    }

    /// сообщения в виде акцентных чанков ([[accent]])
    public func accentMessages(for scope: TaikaFMScope) -> [[TaikaFMChunk]] {
        messages(for: scope).map { Self.parseAccentChunks($0) }
    }

    // MARK: - Rotation (без таймера — меняется раз в день / по extra-ключу вкладки)

    /// Стабильный индекс ротации: день года + scope + optional extra (вкладка).
    public func rotationSeed(for scope: TaikaFMScope, extra: String = "") -> Int {
        let cal = Calendar.current
        let day = cal.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let year = cal.component(.year, from: Date())
        var hasher = Hasher()
        hasher.combine(scope.rawValue)
        hasher.combine(extra)
        hasher.combine(year)
        hasher.combine(day)
        return abs(hasher.finalize())
    }

    /// Сообщения, начиная с «сегодняшнего» — для typing-режима или цепочки.
    public func rotatedMessages(for scope: TaikaFMScope, extra: String = "") -> [String] {
        let msgs = messages(for: scope)
        guard msgs.count > 1 else { return msgs }
        let start = rotationSeed(for: scope, extra: extra) % msgs.count
        return Array(msgs[start...]) + Array(msgs[..<start])
    }

    /// Одна строка на сегодня (perf-safe, без таймера).
    public func primaryRotatedMessage(for scope: TaikaFMScope, extra: String = "") -> String {
        rotatedMessages(for: scope, extra: extra).first ?? ""
    }

    // MARK: - Step chain

    /// tip → hints → текст карточки → taikafm step scope
    public func messagesForStep(tip: String?, hints: [String], cardText: String?) -> [String] {
        var result: [String] = []

        func appendUnique(_ raw: String) {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !result.contains(t) else { return }
            result.append(t)
        }

        if let tip { appendUnique(tip) }
        for h in hints { appendUnique(h) }
        if let cardText { appendUnique(cardText) }
        for m in messages(for: .step) { appendUnique(m) }

        if result.isEmpty {
            result.append("Листай карточки — рядом [[подсказки]] по уроку.")
        }
        return result
    }

    /// tip из steps.json → один message
    public func accentMessagesFromStepTip(_ tip: String?) -> [[TaikaFMChunk]] {
        guard let raw = tip?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return []
        }
        return [Self.parseAccentChunks(raw)]
    }

    /// Короткие строки Taika FM после завершения урока (итоги).
    public func lessonCompletionAccentMessages() -> [[TaikaFMChunk]] {
        let lines = [
            "[[Молодец.]] Урок пройден.",
            "Ты это сделал. Дальше — только [[легче]].",
            "Закрепи в игре или в [[Спикере]] — так запомнится крепче.",
            "Слово за словом — и вот ты уже [[дальше]], чем вчера."
        ]
        return lines.map { Self.parseAccentChunks($0) }
    }

    // MARK: - Accent Parsing

    private static func parseAccentChunks(_ raw: String) -> [TaikaFMChunk] {
        var result: [TaikaFMChunk] = []
        var buffer = ""
        var isAccent = false

        var index = raw.startIndex

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            result.append(TaikaFMChunk(text: buffer, isAccent: isAccent))
            buffer.removeAll(keepingCapacity: true)
        }

        while index < raw.endIndex {
            if raw[index...].hasPrefix("[[") {
                flushBuffer()
                isAccent = true
                index = raw.index(index, offsetBy: 2)
                continue
            }

            if raw[index...].hasPrefix("]]") {
                flushBuffer()
                isAccent = false
                index = raw.index(index, offsetBy: 2)
                continue
            }

            buffer.append(raw[index])
            index = raw.index(after: index)
        }

        flushBuffer()
        return result
    }
}
