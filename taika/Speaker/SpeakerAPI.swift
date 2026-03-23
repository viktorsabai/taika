//
//  SpeakerAPI.swift
//  taika
//
//  created by product on 13.01.2026.
//

import Foundation

// MARK: - public models

enum SpeakerAPIError: Error, LocalizedError {
    case notConfigured
    case invalidRequest
    case badResponse
    case http(Int)
    case decode

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "speaker api is not configured"
        case .invalidRequest: return "invalid request"
        case .badResponse: return "bad response"
        case .http(let code): return "http error \(code)"
        case .decode: return "decode error"
        }
    }
}

/// minimal issue item for ui mapping (mvp)
struct SpeakerIssue: Identifiable, Hashable {
    let id: String
    let kind: Kind
    let message: String

    enum Kind: String, Hashable {
        case tone
        case vowel
        case consonant
        case timing
        case stress
        case unknown
    }
}

/// normalized result that speaker manager/ds can consume regardless of provider
struct SpeakerAssessmentResult: Hashable {
    /// 0…100
    let score: Double

    /// what stt heard (thai, if provider returns it)
    let heardThai: String?

    /// what stt heard as translit (optional, provider-specific)
    let heardTranslit: String?

    /// short teacher-style feedback lines (already curated)
    let feedback: [String]

    /// structured issues for later: highlights, chips, etc.
    let issues: [SpeakerIssue]
}

// MARK: - provider contract

protocol SpeakerAssessmentProviding {
    /// assess a recorded attempt against an expected thai text.
    func assess(audioURL: URL, expectedThai: String) async throws -> SpeakerAssessmentResult
}

// MARK: - api entry

/// Single entry point for speaker assessment (e.g. Azure Pronunciation).
/// EPIC 3: Not called in production yet; SpeakerManager uses on-device STT + local score.
/// When ready for prod: configure(provider: AzurePronunciationAssessor(...)) and call assess from SpeakerManager.stopAttemptAndAnalyze.
final class SpeakerAPI {
    static let shared = SpeakerAPI()

    private var provider: SpeakerAssessmentProviding?

    private init() {}

    func configure(provider: SpeakerAssessmentProviding) {
        self.provider = provider
    }

    func assess(audioURL: URL, expectedThai: String) async throws -> SpeakerAssessmentResult {
        guard let provider else { throw SpeakerAPIError.notConfigured }
        let trimmed = expectedThai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SpeakerAPIError.invalidRequest }
        return try await provider.assess(audioURL: audioURL, expectedThai: trimmed)
    }
}

// MARK: - azure skeleton (not wired)

/// azure pronunciation assessment provider skeleton.
///
/// note: keys/endpoints are intentionally not embedded in code.
/// you will configure it from app config.
final class AzurePronunciationAssessor: SpeakerAssessmentProviding {
    struct Config {
        let endpoint: URL
        let subscriptionKey: String
        /// e.g. "th-TH"
        let locale: String

        init(endpoint: URL, subscriptionKey: String, locale: String = "th-TH") {
            self.endpoint = endpoint
            self.subscriptionKey = subscriptionKey
            self.locale = locale
        }
    }

    private let config: Config
    private let session: URLSession

    init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func assess(audioURL: URL, expectedThai: String) async throws -> SpeakerAssessmentResult {

        // TODO: replace with real Azure call.
        // MVP phase: deterministic mock scoring based on simple text similarity.
        // This keeps pipeline stable before wiring real endpoint.

        // basic guard
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw SpeakerAPIError.invalidRequest
        }

        // ---- MOCK LOGIC (temporary) ----
        // simulate heard text as expected text (we don't have real STT yet)
        let heardThai = expectedThai

        // simple deterministic score based on text length (placeholder logic)
        // guarantees stable 60...95 range for UI testing
        let base = Double(min(max(expectedThai.count, 1), 20))
        let score = min(95.0, max(60.0, 60.0 + base))

        // basic feedback tiers
        let feedback: [String]
        if score >= 85 {
            feedback = [
                "отличное произношение",
                "интонация звучит естественно"
            ]
        } else if score >= 70 {
            feedback = [
                "почти получилось",
                "обрати внимание на темп речи"
            ]
        } else {
            feedback = [
                "есть заметные неточности",
                "попробуй произнести медленнее"
            ]
        }

        // minimal structured issue example for future UI highlighting
        let issues: [SpeakerIssue] =
            score < 75
            ? [
                SpeakerIssue(
                    id: "timing-1",
                    kind: .timing,
                    message: "речь слишком быстрая"
                )
            ]
            : []

        return SpeakerAssessmentResult(
            score: score,
            heardThai: heardThai,
            heardTranslit: nil,
            feedback: feedback,
            issues: issues
        )
    }
}
