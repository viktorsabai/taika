//
//  TaikaVoicePreference.swift
//  taika
//
//  Эталон обучения — системный тайский голос iPhone.
//  Женский / мужской и окраска Story Lab только слушаются в «Голос», карточки ими не учим.
//

import CryptoKit
import Foundation

@MainActor
final class TaikaVoicePreference: ObservableObject {
    static let shared = TaikaVoicePreference()

    enum Reader: String {
        case system
        case female
        case male
    }

    enum Color: String {
        case base
        case soft
        case low
    }

    struct PlaybackChoice: Sendable {
        var usesSystem: Bool
        var voiceId: String
        var rate: Float
        var male: Bool
    }

    static let usualRate = 0.78
    static let slowRate = 0.62
    static let fastRate = 1.0

    private static let readerKey = "taika.voice.reader"
    private static let colorKey = "taika.voice.color"
    private static let rateKey = "taika.voice.rate"

    @Published private(set) var reader: Reader
    @Published private(set) var color: Color
    @Published private(set) var rate: Double
    /// Пока вместо выбранного голоса играет системный тайский.
    @Published var systemVoiceCaption: String?

    private init() {
        let storedReader = UserDefaults.standard.string(forKey: Self.readerKey)
        reader = Reader(rawValue: storedReader ?? "") ?? .system
        let storedColor = UserDefaults.standard.string(forKey: Self.colorKey)
        color = Color(rawValue: storedColor ?? "") ?? .base
        let storedRate = UserDefaults.standard.object(forKey: Self.rateKey) as? Double
        rate = Self.clampRate(storedRate ?? Self.usualRate)
        if reader != .system {
            reader = .system
            UserDefaults.standard.set(Reader.system.rawValue, forKey: Self.readerKey)
        }
    }

    var profileSubtitle: String {
        "Как в уроках"
    }

    /// Живая фраза урока — ею проверяем и учителя, и окраску.
    static let lessonPreviewThai = "แอร์ไม่ทำงาน"

    var previewThai: String {
        Self.lessonPreviewThai
    }

    var effectiveColor: Color {
        guard reader != .system, ProManager.shared.can(.voiceTuning) else { return .base }
        if reader == .female, color == .low { return .base }
        return color
    }

    var effectiveRate: Double {
        guard reader != .system, ProManager.shared.can(.voiceTuning) else { return Self.usualRate }
        return Self.clampRate(rate)
    }

    func resolvedVoiceId() -> String {
        voiceId(reader: reader, color: effectiveColor)
    }

    private func voiceId(reader: Reader, color: Color) -> String {
        switch (reader, color) {
        case (.system, _), (.female, .base), (.female, .low):
            return "nova"
        case (.female, .soft):
            return "shimmer"
        case (.male, .base):
            return "echo"
        case (.male, .soft):
            return "ash"
        case (.male, .low):
            return "onyx"
        }
    }

    func playbackChoice() -> PlaybackChoice {
        PlaybackChoice(
            usesSystem: true,
            voiceId: resolvedVoiceId(),
            rate: Float(effectiveRate),
            male: reader == .male
        )
    }

    func previewChoice(reader: Reader, color: Color, rate: Double) -> PlaybackChoice {
        let tint: Color = (reader == .female && color == .low) ? .base : color
        let voiced: Reader = reader == .system ? .female : reader
        return PlaybackChoice(
            usesSystem: false,
            voiceId: voiceId(reader: voiced, color: tint),
            rate: Float(Self.clampRate(rate)),
            male: voiced == .male
        )
    }

    /// StepAudio зовёт озвучку не с главного актора. Снимок читаем на main.
    nonisolated func playbackChoiceFromAnyThread() -> PlaybackChoice {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { self.playbackChoice() }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { self.playbackChoice() }
        }
    }

    nonisolated func showSystemVoiceCaption(male: Bool) {
        _ = male
        showVoiceUnavailableCaption()
    }

    nonisolated func showVoiceUnavailableCaption() {
        Task { @MainActor in
            self.systemVoiceCaption = "Голос не загрузился."
        }
    }

    nonisolated func clearSystemVoiceCaption() {
        Task { @MainActor in
            self.systemVoiceCaption = nil
        }
    }

    func selectReader(_ next: Reader) {
        if reader != .system, next != .system, reader != next, color != .base {
            color = .base
            UserDefaults.standard.set(Color.base.rawValue, forKey: Self.colorKey)
        }
        reader = next
        UserDefaults.standard.set(next.rawValue, forKey: Self.readerKey)
    }

    func selectColor(_ next: Color) {
        guard reader != .system else { return }
        if reader == .female, next == .low { return }
        if next != .base, !ProManager.shared.can(.voiceTuning) { return }
        color = next
        UserDefaults.standard.set(next.rawValue, forKey: Self.colorKey)
    }

    func selectRate(_ next: Double) {
        guard reader != .system else { return }
        let clamped = Self.clampRate(next)
        if abs(clamped - Self.usualRate) > 0.02, !ProManager.shared.can(.voiceTuning) { return }
        rate = clamped
        UserDefaults.standard.set(clamped, forKey: Self.rateKey)
    }

    private static func clampRate(_ value: Double) -> Double {
        min(Self.fastRate, max(Self.slowRate, value))
    }
}

enum TaikaTTSFetch {
    static func mp3(text: String, voice: String, baseURL: String?) async -> Data? {
        let thai = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thai.isEmpty, thai.count <= 400 else { return nil }
        let key = cacheKey(voice: voice, text: thai)
        if let cached = readCache(key), !cached.isEmpty { return cached }
        guard let endpoint = endpointURL(baseURL) else { return nil }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "text_th": thai,
            "voice": voice
        ])
        guard let httpBody = request.httpBody else { return nil }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(code), !data.isEmpty, !looksLikeJSON(data) else { return nil }
            writeCache(key, data)
            return data
        } catch {
            return nil
        }
    }

    private static func endpointURL(_ baseURL: String?) -> URL? {
        guard let base = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !base.isEmpty
        else { return nil }
        let root = base.hasSuffix("/") ? String(base.dropLast()) : base
        return URL(string: root + "/tts")
    }

    private static func cacheKey(voice: String, text: String) -> String {
        let raw = Data("\(voice)\n\(text)".utf8)
        let digest = SHA256.hash(data: raw)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func cacheDirectory() -> URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = caches.appendingPathComponent("taika-tts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func readCache(_ key: String) -> Data? {
        guard let dir = cacheDirectory() else { return nil }
        let url = dir.appendingPathComponent("\(key).mp3")
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return data
    }

    private static func writeCache(_ key: String, _ data: Data) {
        guard let dir = cacheDirectory() else { return }
        let url = dir.appendingPathComponent("\(key).mp3")
        try? data.write(to: url, options: .atomic)
    }

    private static func looksLikeJSON(_ data: Data) -> Bool {
        guard let first = data.first else { return false }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }
}
