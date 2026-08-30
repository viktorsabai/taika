//
//  SpeakerManager.swift
//  taika
//
//  Created by product on 26.12.2025.
//

import Foundation
import SwiftUI
import UIKit
import CryptoKit
import Speech
import AVFoundation

@MainActor
public final class SpeakerManager: ObservableObject {

    public static let shared = SpeakerManager()

    // MARK: - phase

    struct PronunciationResult: Equatable {
        let totalScore: Int
        let accuracy: Int
        let fluency: Int
        let completeness: Int
        let hint: String
    }

    struct SyllableFeedback: Identifiable, Equatable {
        let id = UUID()
        let syllable: String
        let score: Int
        let comment: String?
        let toneExpected: String?
        let toneActual: String?
        let f0Contour: [Double]?
        /// Seconds in lastAttempt recording (from /assess segmentation).
        let segmentStart: Double?
        let segmentEnd: Double?
    }

    enum Phase: Equatable {
        case idle
        case recording
        case analyzing
        case analyzingTranslation
        case hint
        case feedback(result: PronunciationResult)

        var isFeedback: Bool {
            if case .feedback = self { return true }
            return false
        }

        var label: String {
            switch self {
            case .idle: return "готов к записи"
            case .recording: return "запись…"
            case .analyzing: return "анализ…"
            case .analyzingTranslation: return "перевод…"
            case .hint: return "совет"
            case .feedback(let result): return "оценка: \(result.totalScore)"
            }
        }
    }

    /// UI mode: Training (cards, filters, score) vs Conversation (mic only, say in Russian → translate → phonetic + TTS).
    public enum SpeakerUIMode: String, CaseIterable, Equatable {
        case training
        case conversation
    }

    /// Переключение режима. Сбрасываем результат/подсказку/фазу независимо от направления переключения —
    /// иначе, например, подсказка «демо готово…» из «Своей речи» протекает в «По фразам» (общий `taikaHints`/`phase`).
    public func setSpeakerUIMode(_ mode: SpeakerUIMode) {
        guard speakerUIMode != mode else { return }
        if mode != .conversation {
            cancelScheduledConversationListening()
            pendingConversationAutoRecord = false
        }
        speakerUIMode = mode
        clearConversationResult()
        taikaHints = []
        if mode == .conversation {
            SpeakerConversationAttemptsStore.shared.refreshDayIfNeeded()
            sanitizeConversationHistory()
        }
        // Ленту «Своя речь» не трогаем при смене режима — она персистится.
    }

    /// Убрать фантомные записи без русского (stray фонетика вроде «саватди»).
    func sanitizeConversationHistory() {
        let cleaned = conversationHistory.filter {
            !$0.russian.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard cleaned.count != conversationHistory.count else { return }
        conversationHistory = cleaned
        persistConversationHistory()
    }

    /// Сброс результата умного спикера (русский/тайский/транслит и состояние «Повторить и проверить»). Вызывать при входе в режим, при появлении экрана и по кнопке «Сбросить результат».
    public func clearConversationResult() {
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        heardPhraseParts = []
        conversationExpectedThai = nil
        conversationExpectedTranslitForFeedback = nil
        conversationHeardThaiASR = nil
        conversationHeardPhoneticFromASR = nil
        clearConversationCoach()
        clearPhrasePartsState()
        recordingPartialRU = ""
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        recordingMeter = 0
        activePracticeHistoryId = nil
        if phase != .recording && phase != .analyzing && phase != .analyzingTranslation {
            setPhase(.idle)
        }
    }

    // MARK: - published

    // Default to training: Smart Speaker is PRO-only and should be user-initiated.
    @Published var speakerUIMode: SpeakerUIMode = .conversation

    /// Main mic: после перехода на вкладку Спикер сразу стартовать запись (не чипы с фразой).
    @Published var pendingConversationAutoRecord: Bool = false

    /// Main kun-kru composer: открыть Спикер и сразу перевести эту русскую фразу.
    @Published var pendingConversationDemoRU: String? = nil

    /// One-shot token: delayed auto-listen must not fire twice or after cancel.
    private var conversationListenKickToken = UUID()

    @Published private(set) var phase: Phase = .idle

    @discardableResult
    public func consumePendingConversationAutoRecord() -> Bool {
        guard pendingConversationAutoRecord else { return false }
        pendingConversationAutoRecord = false
        return true
    }

    @discardableResult
    public func consumePendingConversationDemoRU() -> String? {
        let t = pendingConversationDemoRU?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        pendingConversationDemoRU = nil
        guard let t, !t.isEmpty else { return nil }
        return t
    }

    /// Central transition for state machine; DEBUG logs to trace stuck states (EPIC 3).
    private func setPhase(_ p: Phase) {
        #if DEBUG
        if phase != p { print("[speaker] phase \(phase.label) -> \(p.label)") }
        #endif
        phase = p
    }
    @Published private(set) var queue: [StepData.SpeakerResolved] = []

    @Published private(set) var current: StepData.SpeakerResolved?
    @Published private(set) var activeFilterId: UUID? = nil

    /// When true, queue is shown in random order (toggle in header). Applied when queue is built and when toggled on.
    @Published public var shuffleQueue: Bool = false

    /// When non-nil, Speaker was opened from a course card; queue is scoped to this course. Cleared when user picks a filter.
    @Published private(set) var speakerContextCourseId: String? = nil

    /// Lesson IDs present in learned queue (for second-level filter chips). Updated when applying "выученные" filter.
    @Published private(set) var learnedLessonIds: [String] = []
    /// Selected lesson for "выученные" filter; nil or empty = "Все".
    @Published var learnedLessonFilter: String? = nil

    @Published private(set) var lastAttempt: URL? = nil
    @Published private(set) var attemptCount: Int = 0
    @Published private(set) var sessionScores: [Int] = [] {
        didSet {
            // Подход сбрасывают в дюжине мест (смена очереди, фильтр, выход) — везде через `= []`.
            // Ловим это здесь, чтобы итог круга не пережил свою сессию.
            if sessionScores.isEmpty {
                sessionScoredCardKeys.removeAll()
                trainingSessionSummary = nil
            }
        }
    }

    /// Карточки, по которым в этом подходе была засчитанная попытка. Круг закрыт, когда набор
    /// покрыл всю очередь — это честное «подход завершён», а не выдуманное «через N фраз».
    private var sessionScoredCardKeys: Set<String> = []

    /// Итог круга: показывается один раз, когда пользователь проговорил все фразы очереди.
    struct TrainingSessionSummary: Equatable {
        let phrases: Int
        let average: Int
        let best: Int
        let weakest: Int
        /// Вторая половина подхода минус первая: видно, разогрелся человек или устал.
        let trend: Int
    }

    @Published private(set) var trainingSessionSummary: TrainingSessionSummary? = nil

    enum LastPlayed: Equatable {
        case none
        case reference
        case attempt
    }

    @Published private(set) var lastPlayed: LastPlayed = .none

    // live ui while recording (mvp)
    @Published var recordingMeter: Double = 0
    @Published var recordingPartialThai: String? = nil
    @Published var recordingPartialTranslit: String? = nil
    /// Conversation mode: live Russian transcript while recording (optional; empty until wired).
    @Published var recordingPartialRU: String = ""

    /// Conversation mode: elapsed recording time for timer UI; 0 when not recording. Max = conversationRecordingMaxDuration.
    @Published var conversationRecordingElapsed: TimeInterval = 0
    /// Max recording duration in conversation mode (anti-fraud + UX). Auto-stop when reached.
    let conversationRecordingMaxDuration: TimeInterval = 45

    // result fields (google-translate style)
    @Published private(set) var heardThai: String? = nil
    @Published private(set) var heardRU: String? = nil

    // taika fm bubble (can show multiple short hints)
    @Published private(set) var taikaHints: [String] = []
    @Published private(set) var syllableFeedback: [SyllableFeedback] = []
    /// true, пока запрос разбора в полёте (показать «Загружаю разбор…»).
    @Published private(set) var breakdownRequestInFlight: Bool = false
    /// true, если последний запрос разбора по тонам завершился ошибкой или пустым ответом (подсказка в UI).
    @Published private(set) var breakdownRequestFailed: Bool = false
    /// Гибридная оценка разбора (0.4×текст + 0.3×фонема + 0.3×тон), если API вернул hybrid_score.
    @Published private(set) var breakdownHybridScore: Int? = nil
    @Published var isAnalysisExpanded: Bool = false
    /// 0…1 во время воспроизведения эталона (TTS); для синхронной прорисовки графика тона. 1 = не играет / конец.
    @Published var referencePlaybackProgress: Double = 1.0
    /// 0…1 во время воспроизведения записи пользователя (целиком или слог).
    @Published var attemptPlaybackProgress: Double = 1.0

    @Published var heardTranslit: String? = nil
    /// Word-level gloss from smart_speaker (`parts`: translit chunk → Russian meaning).
    @Published private(set) var heardPhraseParts: [SmartSpeakerPart] = []
    /// Course/training: raw Thai from Apple ASR.
    @Published private(set) var trainingHeardThaiASR: String? = nil
    /// Course/training: Cyrillic phonetic of `trainingHeardThaiASR`.
    @Published private(set) var trainingHeardPhoneticFromASR: String? = nil
    @Published var heardConfidence: Int = 0
    /// Smart Speaker politeness ("male" | "female" | "kathoey"); persisted in UserDefaults. Default female — без стартового оверлея.
    @Published private var smartSpeakerPolitenessValue: String = "female"

    /// Одна общая оценка для спикера и разбора: без тона = текст; с тоном = min(текст, тон) или hybrid с API.
    var displayScore: Int {
        if let hybrid = breakdownHybridScore {
            return max(0, min(100, hybrid))
        }
        guard !syllableFeedback.isEmpty else { return heardConfidence }
        let toneAvg = syllableFeedback.map(\.score).reduce(0, +) / syllableFeedback.count
        return min(heardConfidence, toneAvg)
    }

    /// Сброс tone/hybrid между попытками — иначе displayScore тянет прошлый разбор.
    private func clearToneBreakdownState() {
        syllableFeedback = []
        breakdownHybridScore = nil
        breakdownRequestFailed = false
        breakdownCacheAttemptPath = nil
        breakdownRequestInFlight = false
        breakdownRequestGeneration = UUID()
    }

    private static func compactStoredSyllables(from items: [SyllableFeedback]) -> [StoredSyllableFeedback] {
        items.map {
            StoredSyllableFeedback(
                syllable: $0.syllable,
                score: $0.score,
                comment: $0.comment,
                toneExpected: $0.toneExpected,
                toneActual: $0.toneActual,
                f0Contour: nil,
                segmentStart: $0.segmentStart,
                segmentEnd: $0.segmentEnd
            )
        }
    }

    private func restoreConversationBreakdownFromCache(itemId: UUID) -> Bool {
        guard let entry = SpeakerConversationToneCacheStore.load(historyItemId: itemId),
              !entry.toneSyllables.isEmpty,
              let path = Self.normalizedRecordingPath(entry.recordingPath),
              FileManager.default.fileExists(atPath: path) else { return false }

        let url = URL(fileURLWithPath: path)
        lastAttempt = url
        lastAttemptURL = url
        heardConfidence = entry.heardConfidence
        conversationHeardThaiASR = entry.heardThaiASR
        conversationHeardPhoneticFromASR = Self.teachingPhoneticOrNil(entry.heardPhoneticFromASR)
        applyBreakdownCache(
            syllables: Self.syllables(from: entry.toneSyllables),
            hybrid: entry.toneHybridScore,
            recordingPath: path
        )
        return true
    }

    private func persistConversationToneCache(historyItemId: UUID, sourceRecording: URL) {
        guard !syllableFeedback.isEmpty else { return }
        let stablePath = SpeakerConversationToneCacheStore.persistRecording(
            from: sourceRecording,
            historyItemId: historyItemId
        ) ?? Self.normalizedRecordingPath(sourceRecording.path)
        let entry = ConversationToneCacheEntry(
            historyItemId: historyItemId.uuidString.lowercased(),
            toneSyllables: Self.compactStoredSyllables(from: syllableFeedback),
            toneHybridScore: breakdownHybridScore,
            recordingPath: stablePath,
            heardConfidence: heardConfidence,
            heardThaiASR: conversationHeardThaiASR,
            heardPhoneticFromASR: conversationHeardPhoneticFromASR,
            updatedAt: Date()
        )
        SpeakerConversationToneCacheStore.save(entry)
        if let path = stablePath, FileManager.default.fileExists(atPath: path) {
            breakdownCacheAttemptPath = path
            let url = URL(fileURLWithPath: path)
            lastAttempt = url
            lastAttemptURL = url
        }
    }

    /// Path of the recording the in-memory breakdown belongs to.
    private var breakdownCacheAttemptPath: String?
    /// Invalidates a stale /assess response after the user starts a new phrase.
    private var breakdownRequestGeneration = UUID()

    private static func storedSyllables(from items: [SyllableFeedback]) -> [StoredSyllableFeedback] {
        items.map {
            StoredSyllableFeedback(
                syllable: $0.syllable,
                score: $0.score,
                comment: $0.comment,
                toneExpected: $0.toneExpected,
                toneActual: $0.toneActual,
                f0Contour: $0.f0Contour,
                segmentStart: $0.segmentStart,
                segmentEnd: $0.segmentEnd
            )
        }
    }

    private static func syllables(from stored: [StoredSyllableFeedback]) -> [SyllableFeedback] {
        stored.map {
            SyllableFeedback(
                syllable: $0.syllable,
                score: $0.score,
                comment: $0.comment,
                toneExpected: $0.toneExpected,
                toneActual: $0.toneActual,
                f0Contour: $0.f0Contour,
                segmentStart: $0.segmentStart,
                segmentEnd: $0.segmentEnd
            )
        }
    }

    private static func normalizedRecordingPath(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("file://"), let url = URL(string: raw) {
            return url.path
        }
        return raw
    }

    private func recordingPathMatchesBreakdownCache(_ path: String?) -> Bool {
        guard let live = Self.normalizedRecordingPath(path),
              let cached = Self.normalizedRecordingPath(breakdownCacheAttemptPath) else { return false }
        return live == cached
    }

    private func applyBreakdownCache(
        syllables: [SyllableFeedback],
        hybrid: Int?,
        recordingPath: String?
    ) {
        syllableFeedback = syllables
        breakdownHybridScore = hybrid
        breakdownRequestFailed = syllables.isEmpty
        breakdownCacheAttemptPath = recordingPath
        syncFeedbackPhaseScoreIfNeeded()
    }

    private func restoreBreakdownFromStored(_ stored: SpeakerAttemptResult, recordingPath: String?) -> Bool {
        guard let rows = stored.toneSyllables, !rows.isEmpty else { return false }
        guard let livePath = Self.normalizedRecordingPath(recordingPath) else { return false }
        let cachedPath = Self.normalizedRecordingPath(stored.toneBreakdownRecordingPath)
            ?? Self.normalizedRecordingPath(stored.lastAttemptURL)
        guard cachedPath == livePath else { return false }
        applyBreakdownCache(
            syllables: Self.syllables(from: rows),
            hybrid: stored.toneHybridScore ?? stored.advancedScore,
            recordingPath: livePath
        )
        return true
    }

    /// Skip redundant /assess when breakdown for this recording is already in memory or on disk.
    func hasBreakdownForCurrentAttempt() -> Bool {
        let path = lastAttempt?.path ?? lastAttempt?.absoluteString
        if lastAttempt != nil, !syllableFeedback.isEmpty, recordingPathMatchesBreakdownCache(path) {
            return true
        }
        if let id = activePracticeHistoryId {
            if !syllableFeedback.isEmpty, recordingPathMatchesBreakdownCache(path) {
                return true
            }
            if let entry = SpeakerConversationToneCacheStore.load(historyItemId: id),
               !entry.toneSyllables.isEmpty {
                let cachedPath = Self.normalizedRecordingPath(entry.recordingPath)
                let livePath = Self.normalizedRecordingPath(path)
                // `livePath == nil` used to count as a hit and restored the previous
                // phrase's syllables onto the next attempt.
                if livePath != nil, livePath == cachedPath {
                    if syllableFeedback.isEmpty {
                        _ = restoreConversationBreakdownFromCache(itemId: id)
                    }
                    return !syllableFeedback.isEmpty
                }
            }
        }
        guard lastAttempt != nil else { return false }
        guard let cur = current else { return false }
        let key = SpeakerAttemptsStore.key(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
        guard let stored = SpeakerAttemptsStore.load(forKey: key) else { return false }
        return restoreBreakdownFromStored(stored, recordingPath: path)
    }

    private func persistBreakdownFailureUnlessCached(requestAttemptPath: String) {
        let path = Self.normalizedRecordingPath(requestAttemptPath) ?? requestAttemptPath
        guard recordingPathMatchesBreakdownCache(path), !syllableFeedback.isEmpty else {
            if let id = activePracticeHistoryId,
               restoreConversationBreakdownFromCache(itemId: id),
               recordingPathMatchesBreakdownCache(path) {
                breakdownRequestFailed = false
                return
            }
            syllableFeedback = []
            breakdownHybridScore = nil
            breakdownRequestFailed = true
            return
        }
        breakdownRequestFailed = false
    }
    private func syncFeedbackPhaseScoreIfNeeded() {
        guard case .feedback(let result) = phase else { return }
        let unified = displayScore
        guard result.totalScore != unified else {
            persistCurrentAttemptIfNeeded()
            return
        }
        let updated = PronunciationResult(
            totalScore: unified,
            accuracy: unified,
            fluency: unified,
            completeness: unified,
            hint: result.hint
        )
        setPhase(.feedback(result: updated))
        persistCurrentAttemptIfNeeded()
    }

    private func clearTrainingASRResult() {
        trainingHeardThaiASR = nil
        trainingHeardPhoneticFromASR = nil
    }

    /// Re-save after tone breakdown updates unified score (no extra daily-attempt consume).
    private func persistCurrentAttemptIfNeeded() {
        guard phase.isFeedback, let cur = current, let url = lastAttempt else { return }
        let expectedPhonetic = cur.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        saveAttemptResult(
            courseId: cur.courseId,
            lessonId: cur.lessonId,
            stepIndex: cur.index,
            heardThai: expectedPhonetic.isEmpty ? nil : expectedPhonetic,
            heardTranslit: trainingHeardPhoneticFromASR ?? trainingHeardThaiASR,
            heardThaiASR: trainingHeardThaiASR,
            heardPhoneticFromASR: trainingHeardPhoneticFromASR,
            heardConfidence: heardConfidence,
            attemptCount: attemptCount,
            lastAttemptURL: url,
            consumeDailyAttempt: false
        )
    }

    /// Когда есть разбор по тонам — средний тон по слогам (для подписи «Тон X%» в карточке разбора).
    var toneAverageScore: Int? {
        guard !syllableFeedback.isEmpty else { return nil }
        return syllableFeedback.map(\.score).reduce(0, +) / syllableFeedback.count
    }

    /// When non-nil, we're in "repeat and check" flow (recording or analyzing or showing feedback). Expected Thai for scoring.
    @Published var conversationExpectedThai: String? = nil
    /// Expected translit for conversation feedback block "нужно было".
    @Published var conversationExpectedTranslitForFeedback: String? = nil
    /// Тайский с ASR после «Повторить и проверить». Эталонный перевод остаётся в `heardThai`.
    @Published var conversationHeardThaiASR: String? = nil
    /// Кириллическая фонетика того, что распознали с записи (POST /thai_phonetic — тот же стиль, что эталон в практике).
    @Published var conversationHeardPhoneticFromASR: String? = nil
    /// Одна конкретная правка после тренировки (POST /semantic_coach): что именно исправить.
    /// Опциональная надстройка — экран остаётся полноценным, если сервис недоступен.
    @Published private(set) var conversationCoachHeadline: String? = nil
    /// Пояснение к правке на 1–2 предложения; показываем в разборе тонов.
    @Published private(set) var conversationCoachDetail: String? = nil
    /// true, пока запрос коуча в полёте — чтобы строка не «прыгала» пустотой.
    @Published private(set) var conversationCoachInFlight: Bool = false
    /// true, пока разбор догружается отдельным запросом (сервер не отдал его вместе с фразой).
    @Published private(set) var phrasePartsInFlight: Bool = false
    /// Фраза, по которой уже ходили за разбором: не долбим сервер на каждый ре-рендер.
    private var phrasePartsRequestKey: String? = nil
    /// Invalidates an in-flight word-gloss fetch when the user starts a new phrase.
    private var phrasePartsFetchGeneration = UUID()
    /// Лента прошлых переводов «Своя речь» (newest first). Персистится; не чистится при «Новая фраза».
    @Published private(set) var conversationHistory: [SpeakerConversationHistoryItem] = SpeakerConversationHistoryStore.load()
    /// Карточка ленты, по которой сейчас идёт тренировка произношения (не создавать дубль).
    @Published private(set) var activePracticeHistoryId: UUID? = nil

    private let conversationHistoryLimit = 30

    private func persistConversationHistory() {
        SpeakerConversationHistoryStore.save(conversationHistory)
    }

    private func updateHistoryPracticeScore(id: UUID, score: Int) {
        guard let idx = conversationHistory.firstIndex(where: { $0.id == id }) else { return }
        let old = conversationHistory[idx]
        let updated = SpeakerConversationHistoryItem(
            id: old.id,
            russian: old.russian,
            thai: old.thai,
            phonetic: old.phonetic,
            createdAt: old.createdAt,
            lastPracticeScore: max(0, min(100, score))
        )
        conversationHistory[idx] = updated
        // Поднимаем тренированную фразу наверх — видно свежий балл.
        if idx > 0 {
            conversationHistory.remove(at: idx)
            conversationHistory.insert(updated, at: 0)
        }
        persistConversationHistory()
    }

    // MARK: - UX timings
    // keep analyzing visible long enough to feel intentional (avoid "blink")
    private let minAnalyzingDuration: TimeInterval = 0.65
    private var analyzingStartedAt: Date? = nil
    /// Temporary cooldown after repeated Apple ASR failures (1107/1101).
    /// During this window we prefer server-based scoring to avoid blocking practice.
    private var asrDegradedUntil: Date? = nil
    private let asrDegradedCooldown: TimeInterval = 120

    private var isASRTemporarilyDegraded: Bool {
        guard let until = asrDegradedUntil else { return false }
        return Date() < until
    }

    private func markASRDegradedNow() {
        asrDegradedUntil = Date().addingTimeInterval(asrDegradedCooldown)
    }

    private func clearASRDegradedIfNeeded() {
        asrDegradedUntil = nil
    }

    // MARK: - stable ids (for ui carousel selection)

    // must be stable and depend only on ids + canonical index (no face text)
    func resolveId(_ r: StepData.SpeakerResolved) -> UUID {
        // stable across renders and independent of localized text (avoid id drift)
        // key = courseId + lessonId + canonical step order/index
        let key = [
            r.courseId,
            r.lessonId,
            String(r.index)
        ].joined(separator: "|")

        let digest = SHA256.hash(data: Data(key.utf8))
        var uuidBytes: [UInt8] = Array(digest.prefix(16))

        // UUID v4 + RFC4122 variant
        uuidBytes[6] = (uuidBytes[6] & 0x0F) | 0x40
        uuidBytes[8] = (uuidBytes[8] & 0x3F) | 0x80

        return uuidFromBytes(uuidBytes)
    }

    var selectedId: UUID? {
        guard let cur = current else { return nil }
        return resolveId(cur)
    }

    /// small window for the top carousel (current + a few neighbors)
    var carouselItems: [StepData.SpeakerResolved] {
        guard !queue.isEmpty else { return [] }
        guard let cur = current else {
            return Array(queue.prefix(5))
        }

        let currentId = resolveId(cur)
        guard let i = queue.firstIndex(where: { resolveId($0) == currentId }) else {
            return Array(queue.prefix(5))
        }

        let n = queue.count
        if n <= 5 { return queue }

        let i0 = (i - 2 + n) % n
        let i1 = (i - 1 + n) % n
        let i2 = i
        let i3 = (i + 1) % n
        let i4 = (i + 2) % n

        return [queue[i0], queue[i1], queue[i2], queue[i3], queue[i4]]
    }

    func selectCard(by id: UUID) {
        guard !queue.isEmpty else { return }
        if let match = queue.first(where: { resolveId($0) == id }) {
            current = match
            // A1: keep "current lesson" source-of-truth in sync
            session.markActive(courseId: match.courseId, lessonId: match.lessonId, stepIndex: match.index)
            
            // B3: restore persisted attempt result for this card
            restoreAttemptResult(for: match)
        }
    }
    
    // B3: restore persisted attempt result for a card
    private func restoreAttemptResult(for resolved: StepData.SpeakerResolved) {
        let key = SpeakerAttemptsStore.key(
            courseId: resolved.courseId,
            lessonId: resolved.lessonId,
            stepIndex: resolved.index
        )
        
        if let stored = SpeakerAttemptsStore.load(forKey: key) {
            heardThai = stored.heardThai
            heardTranslit = Self.teachingPhoneticOrNil(stored.heardTranslit)
            trainingHeardThaiASR = stored.heardThaiASR
            trainingHeardPhoneticFromASR = Self.teachingPhoneticOrNil(stored.heardPhoneticFromASR)
            heardConfidence = stored.heardConfidence
            attemptCount = stored.attemptCount
            
            // restore audio URL if file still exists
            if let path = stored.lastAttemptURL,
               let url = URL(string: path),
               FileManager.default.fileExists(atPath: url.path) {
                lastAttemptURL = url
                lastAttempt = url
            } else {
                lastAttemptURL = nil
                lastAttempt = nil
            }

            let recordingPath = lastAttempt?.path ?? lastAttempt?.absoluteString
            if !restoreBreakdownFromStored(stored, recordingPath: recordingPath) {
                clearToneBreakdownState()
            }
            
            // restore phase based on stored result
            if stored.heardConfidence > 0 {
                heardRU = nil
                let scoreToShow = stored.advancedScore ?? stored.heardConfidence
                let hint = feedbackHint(for: scoreToShow)
                let result = PronunciationResult(
                    totalScore: scoreToShow,
                    accuracy: scoreToShow,
                    fluency: scoreToShow,
                    completeness: scoreToShow,
                    hint: hint
                )
                setPhase(.feedback(result: result))
                taikaHints = [
                    resolved.face.titleRU.isEmpty ? "оценка: \(scoreToShow)" : "фраза: \(resolved.face.titleRU)",
                    "оценка: \(scoreToShow)",
                    hint
                ]
                if lastAttempt != nil, syllableFeedback.isEmpty, !breakdownRequestInFlight {
                    requestToneBreakdownFromAPI(
                        expectedPhoneticForTones: resolved.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? nil
                            : resolved.face.phonetic,
                        completion: {}
                    )
                }
            } else {
                // B3: clear heardRU when score is 0 to prevent stale value from previous card
                heardRU = nil
                setPhase(.idle)
                taikaHints = []
            }
        } else {
            clearTrainingASRResult()
            heardThai = nil
            heardRU = nil
            heardTranslit = nil
            heardConfidence = 0
            taikaHints = []
            setPhase(.idle)
            lastAttemptURL = nil
            lastAttempt = nil
            attemptCount = 0
        }
        
        lastPlayed = .none
        attemptPlayer?.stop()
        attemptPlayer = nil
    }
    
    // B3: helper to generate feedback hint from score
    private func feedbackHint(for score: Int) -> String {
        switch score {
        case 92...100: return "очень похоже. попробуй быстрее и слитно"
        case 78...91: return "норм. добей окончания и тон"
        case 60...77: return "слышно похоже, но есть ошибки. сравни по слогам"
        default: return "пока мимо. включи эталон и повторяй по 1–2 слога"
        }
    }

    // MARK: - deps

    private let session: UserSession
    private let stepData: StepData

    private let recorder: any SpeakerRecording

    // MARK: - state

    private var didLoad: Bool = false
    private var lastAttemptURL: URL?
    private var activeAttemptToken: UUID? = nil
    private var attemptPlayer: AVAudioPlayer?
    private var syllablePlaybackStopWork: DispatchWorkItem?
    private var playbackProgressTimer: Timer?
    private var meterTimer: Timer?
    private var conversationRecordingTimer: Timer?
    private var conversationRecordingStartTime: Date?
    private var baseQueue: [StepData.SpeakerResolved] = []

    init(session: UserSession? = nil, stepData: StepData? = nil, recorder: (any SpeakerRecording)? = nil) {
        self.session = session ?? UserSession.shared
        self.stepData = stepData ?? StepData.shared
        self.recorder = recorder ?? SpeakerRecorder.shared
        // Smart Speaker: вежливость из UserDefaults или по умолчанию female
        if let stored = UserDefaults.standard.string(forKey: Self.smartSpeakerPolitenessKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty,
           SmartSpeakerPoliteness(rawValue: stored.lowercased()) != nil {
            self.smartSpeakerPolitenessValue = stored.lowercased()
        } else {
            self.smartSpeakerPolitenessValue = SmartSpeakerPoliteness.female.rawValue
        }
        // Do NOT preload here: Task { loadIfNeeded(force: true) } runs after onAppear and overwrites
        // queue with buildCurrentLessonQueue() (6 cards) when user opened from course card. Load in onAppear only.
        // when user taps "сбросить прогресс" in Profile, clear Speaker state so next open = start state
        NotificationCenter.default.addObserver(forName: Notification.Name("AppResetAll"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.resetForAppReset()
            }
        }
        // when progress changes (e.g. user completed a step elsewhere), invalidate and refresh so "последний урок" updates in real time
        NotificationCenter.default.addObserver(forName: Notification.Name("Step.progressDidChange"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.didLoad = false
                if let cid = self.speakerContextCourseId {
                    self.rebuildQueue()
                    self.loadQueueForCourse(cid)
                } else if self.queue.isEmpty {
                    // На лаунчере — только обновить пул курсов, не открывать сессию.
                    self.rebuildQueue()
                } else if let filterId = self.activeFilterId {
                    self.rebuildQueue()
                    self.applyFilter(filterId)
                } else {
                    self.rebuildQueue()
                }
            }
        }
    }

    /// Called when app-wide progress reset (Profile). Clears queue, persisted attempts, and in-memory state; next loadIfNeeded will rebuild from empty UserSession.
    private func resetForAppReset() {
        SpeakerAttemptsStore.clearAll()
        stopMeter()
        recordingPartialThai = nil
        recordingMeter = 0
        recordingPartialTranslit = nil
        lastAttemptURL = nil
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        heardConfidence = 0
        taikaHints = ["пройдите урок — здесь появятся фразы для тренировки"]
        syllableFeedback = []
        queue = []
        baseQueue = []
        current = nil
        lastAttempt = nil
        attemptCount = 0
        sessionScores = []
        lastPlayed = .none
        attemptPlayer?.stop()
        attemptPlayer = nil
        activeAttemptToken = nil
        didLoad = false
        conversationHistory = []
        SpeakerConversationHistoryStore.clear()
        SpeakerConversationToneCacheStore.clearAll()
        setPhase(.hint)
    }

    // MARK: - lifecycle

    func loadIfNeeded(force: Bool = false) {
        if didLoad && !force { return }
        didLoad = true
        rebuildQueue()
        // Корень «Закрепление курсов» — лаунчер выбора курсов, не «последний урок».
        returnToTrainingHome()
    }

    /// Подготовить пул выученных фраз без сброса активной сессии (для входа из Step/курса).
    func prepareTrainingPoolIfNeeded() {
        if !didLoad {
            didLoad = true
            rebuildQueue()
            return
        }
        if baseQueue.isEmpty {
            rebuildQueue()
        }
    }

    /// Сбросить активную сессию и показать лаунчер выбора курсов.
    func returnToTrainingHome() {
        speakerContextCourseId = nil
        activeFilterId = nil
        learnedLessonIds = []
        learnedLessonFilter = nil
        if baseQueue.isEmpty {
            rebuildQueue()
        }
        queue = []
        current = nil
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        heardConfidence = 0
        taikaHints = []
        recordingPartialThai = nil
        recordingPartialRU = ""
        recordingMeter = 0
        lastAttemptURL = nil
        lastAttempt = nil
        attemptCount = 0
        sessionScores = []
        lastPlayed = .none
        attemptPlayer?.stop()
        attemptPlayer = nil
        syllableFeedback = []
        setPhase(.idle)
    }

    /// Same source as game (ProgressManager): so "52 пары" in game = same cards in Speaker when opened from course.
    private func learnedStepsFromProgressManager() -> [String: Set<Int>] {
        var out: [String: Set<Int>] = [:]
        let pm = ProgressManager.shared
        for course in CourseData.shared.courses {
            let courseId = course.courseID
            for lesson in LessonsData.shared.lessons(for: courseId) {
                let set = pm.learnedSet(courseId: courseId, lessonId: lesson.lessonID)
                if !set.isEmpty {
                    out["\(courseId)|\(lesson.lessonID)"] = set
                }
            }
        }
        return out
    }

    func rebuildQueue() {
        let snap = session.snapshot

        // Snapshot debug log removed: this method is called often and flooded console.

        var resolved: [StepData.SpeakerResolved] = []
        resolved.reserveCapacity(64)

        // 1) learned steps — use ProgressManager (same as game "52 пары"), fallback to UserSession for legacy
        var learned = learnedStepsFromProgressManager()
        if learned.isEmpty {
            learned = snap.learnedSteps
            if learned.isEmpty {
                learned = collectLearnedStepsFallback(from: snap)
            }
        }
        for (key, set) in learned {
            guard let ids = StepData.splitLearnedKey(key) else { continue }
            for idx in set.sorted() {
                if let r = stepData.speakerResolved(courseId: ids.courseId, lessonId: ids.lessonId, index: idx) {
                    resolved.append(r)
                }
            }
        }

        // No daily picks fallback: empty queue → empty state per filter (EPIC 3, убрали заглушки «са ват ди»).

        // avoid duplicate items → duplicate UUIDs in SwiftUI ForEach
        resolved = dedupResolved(resolved)

        // stable order (course+lesson+index)
        resolved.sort { a, b in
            if a.courseId != b.courseId { return a.courseId < b.courseId }
            if a.lessonId != b.lessonId { return a.lessonId < b.lessonId }
            return a.index < b.index
        }

        // Queue-size debug log removed: frequent and low value in normal debug sessions.
        baseQueue = resolved
        // Не трогаем `queue` здесь: активная сессия / лаунчер решают сами
        // (`returnToTrainingHome`, `startTraining`, `applyFilter`, `loadQueueForCourse`).
    }

    /// Course picker options for the training launcher (idle "По фразам" screen): one row per course
    /// that has at least one learned phrase ready to practice, with its count. Same pool as `baseQueue`
    /// (learned across all courses, via ProgressManager — matches Game Park counts).
    public func learnedTrainingCourseOptions() -> [SpeakerTrainingCourseOption] {
        var counts: [String: Int] = [:]
        for r in baseQueue { counts[r.courseId, default: 0] += 1 }
        return LessonsData.shared.allCourses().compactMap { course in
            guard let c = counts[course.courseID], c > 0 else { return nil }
            return SpeakerTrainingCourseOption(id: course.courseID, title: course.courseTitle, count: c)
        }
    }

    /// Сколько фраз в избранном (уроки), без словаря «Скажи сам».
    public func trainingFavoritesCount() -> Int {
        buildFavoritesQueue().filter {
            !($0.courseId == "user_dict" && $0.lessonId == "smart_speaker")
        }.count
    }

    /// Сколько фраз в словаре умного спикера.
    public func trainingDictionaryCount() -> Int {
        buildFavoritesQueue().filter {
            $0.courseId == "user_dict" && $0.lessonId == "smart_speaker"
        }.count
    }

    /// Быстрый старт: избранное уроков или словарь.
    public func startSpecialTraining(poolId: String) {
        guard poolId == "__favorites__" || poolId == "__dictionary__" else { return }
        if poolId == "__dictionary__" {
            startDictionaryTraining(selectedSourceIds: DictionarySessionSelection.shared.activeSourceIds)
            return
        }
        prepareTrainingPoolIfNeeded()
        loadQueueForCourse(poolId)
        if !queue.isEmpty {
            setPhase(.idle)
            taikaHints = []
        }
    }

    /// Только полностью пройденные уроки курса с числом фраз — для чекбоксов на лаунчере / в сессии.
    /// Наличие отдельных выученных фраз недостаточно: незавершённый урок не должен появляться
    /// в scope picker, иначе Speaker может стартовать без валидного training context.
    public func learnedTrainingLessonOptions(courseId: String) -> [SpeakerTrainingLessonOption] {
        let completedLessonIds = Set(
            LessonsManager.shared.progress[courseId, default: [:]]
                .compactMap { lessonId, progress in
                    progress.status == .completed ? lessonId : nil
                }
        )

        guard !completedLessonIds.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for r in baseQueue where r.courseId == courseId && completedLessonIds.contains(r.lessonId) {
            counts[r.lessonId, default: 0] += 1
        }
        guard !counts.isEmpty else { return [] }

        let bundles = LessonsData.shared.lessons(for: courseId)
        var ordered: [SpeakerTrainingLessonOption] = []
        var seen = Set<String>()
        for lesson in bundles {
            guard let c = counts[lesson.lessonID], c > 0 else { continue }
            seen.insert(lesson.lessonID)
            let title = LessonsData.shared.lessonTitle(for: lesson.lessonID) ?? lesson.lessonID
            ordered.append(SpeakerTrainingLessonOption(id: lesson.lessonID, title: title, count: c))
        }
        // Уроки вне каталога (старые id) — в конец, но только если их progress status completed.
        for (lid, c) in counts.sorted(by: { $0.key < $1.key }) where !seen.contains(lid) {
            let title = LessonsData.shared.lessonTitle(for: lid) ?? lid
            ordered.append(SpeakerTrainingLessonOption(id: lid, title: title, count: c))
        }
        return ordered
    }

    /// Тренировка словаря; `selectedSourceIds` nil = все фразы.
    public func startDictionaryTraining(selectedSourceIds: Set<String>? = nil) {
        prepareTrainingPoolIfNeeded()
        speakerContextCourseId = "__dictionary__"
        activeFilterId = SpeakerMode.favoritesMode.id
        var fav = buildFavoritesQueue().filter {
            $0.courseId == "user_dict" && $0.lessonId == "smart_speaker"
        }
        if let ids = selectedSourceIds, !ids.isEmpty {
            let selectedThai = Set(
                FavoriteManager.shared.items
                    .filter { ids.contains($0.id) }
                    .map { $0.th.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            )
            fav = fav.filter {
                selectedThai.contains($0.face.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            }
        }
        applySpecialTrainingQueue(fav, emptyHint: "в словаре пока пусто")
    }

    private func applySpecialTrainingQueue(_ fav: [StepData.SpeakerResolved], emptyHint: String) {
        if fav.isEmpty {
            queue = []
            current = nil
            heardThai = nil
            heardRU = nil
            heardTranslit = nil
            heardConfidence = 0
            taikaHints = [emptyHint]
            recordingPartialThai = nil
            recordingMeter = 0
            lastAttemptURL = nil
            lastAttempt = nil
            attemptCount = 0
            sessionScores = []
            lastPlayed = .none
            attemptPlayer?.stop()
            attemptPlayer = nil
            setPhase(.hint)
        } else {
            queue = fav
            if shuffleQueue { shuffle() }
            current = queue.first
            if let cur = current { restoreAttemptResult(for: cur) }
            setPhase(.idle)
            taikaHints = []
        }
    }

    /// Start a training session scoped to the courses (and optional lessons) picked on the launcher.
    public func startTraining(withCourseIds courseIds: Set<String>, lessonIds: Set<String>? = nil) {
        if baseQueue.isEmpty {
            rebuildQueue()
        }
        var selected = baseQueue.filter { courseIds.contains($0.courseId) }
        if let lessonIds, !lessonIds.isEmpty {
            let needles = Set(lessonIds.map { $0.lowercased() })
            selected = selected.filter { needles.contains($0.lessonId.lowercased()) }
        }
        guard !selected.isEmpty else { return }
        speakerContextCourseId = courseIds.count == 1 ? courseIds.first : nil
        activeFilterId = SpeakerMode.learned.id
        learnedLessonIds = Array(Set(selected.map(\.lessonId))).sorted()
        learnedLessonFilter = nil
        queue = shuffleQueue ? selected.shuffled() : selected
        current = queue.first
        if let cur = current {
            restoreAttemptResult(for: cur)
        }
        taikaHints = []
        setPhase(.idle)
    }

    /// Queue built only from learned steps (no daily picks). Used for "выученные" filter.
    private func buildLearnedOnlyQueue() -> [StepData.SpeakerResolved] {
        let snap = session.snapshot
        var learned = snap.learnedSteps
        if learned.isEmpty {
            learned = collectLearnedStepsFallback(from: snap)
        }
        var resolved: [StepData.SpeakerResolved] = []
        resolved.reserveCapacity(64)
        for (key, set) in learned {
            guard let ids = StepData.splitLearnedKey(key) else { continue }
            let actualLessonId = stepData.lessonIdForCaseInsensitiveLookup(ids.lessonId) ?? ids.lessonId
            for idx in set.sorted() {
                if let r = stepData.speakerResolved(courseId: ids.courseId, lessonId: actualLessonId, index: idx) {
                    resolved.append(r)
                }
            }
        }
        resolved = dedupResolved(resolved)
        resolved.sort { a, b in
            if a.courseId != b.courseId { return a.courseId < b.courseId }
            if a.lessonId != b.lessonId { return a.lessonId < b.lessonId }
            return a.index < b.index
        }
        return resolved
    }

    private func collectLearnedStepsFallback(from snap: Any) -> [String: Set<Int>] {
        // defensive fallback: if the canonical `learnedSteps` is empty due to migration/renaming,
        // scan snapshot for any properties shaped like [String: Set<Int>].
        var out: [String: Set<Int>] = [:]

        func merge(_ dict: [String: Set<Int>]) {
            for (k, v) in dict {
                if var cur = out[k] {
                    cur.formUnion(v)
                    out[k] = cur
                } else {
                    out[k] = v
                }
            }
        }

        func walk(_ value: Any) {
            let m = Mirror(reflecting: value)
            for child in m.children {
                if let d = child.value as? [String: Set<Int>] {
                    merge(d)
                }
            }
            if let sup = m.superclassMirror {
                for child in sup.children {
                    if let d = child.value as? [String: Set<Int>] {
                        merge(d)
                    }
                }
            }
        }

        walk(snap)
        return out
    }

    private func pickFirst() {
        current = queue.first
        if let cur = current {
            session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
            restoreAttemptResult(for: cur)
        }
    }

    // MARK: - navigation

    func next() {
        guard !queue.isEmpty else {
            current = nil
            return
        }
        guard let cur = current else {
            current = queue.first
            return
        }
        let currentId = resolveId(cur)
        guard let i = queue.firstIndex(where: { resolveId($0) == currentId }) else {
            current = queue.first
            return
        }
        let nextIndex = (i + 1) % queue.count
        current = queue[nextIndex]
        if let cur = current {
            // A1: keep "current lesson" source-of-truth in sync
            session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
            // B3: restore persisted attempt result
            restoreAttemptResult(for: cur)
        }
    }
    
    // C1: prev navigation for player panel
    func shuffle() {
        guard !queue.isEmpty else { return }
        let currentId = current.map { resolveId($0) }
        // create shuffled copy to trigger @Published update
        var shuffled = queue
        shuffled.shuffle()
        queue = shuffled
        // restore current card if it exists in shuffled queue
        if let id = currentId, let found = queue.first(where: { resolveId($0) == id }) {
            current = found
        } else {
            current = queue.first
            if let cur = current {
                session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
                restoreAttemptResult(for: cur)
            }
        }
    }
    
    // Convert StepItem.Kind to SDStepItem.Kind
    private func convertKind(_ kind: StepItem.Kind) -> SDStepItem.Kind {
        switch kind {
        case .word: return .word
        case .phrase: return .phrase
        case .casual: return .casual
        case .tip: return .tip
        case .dialog: return .tip // dialog maps to tip in SDStepItem
        }
    }
    
    func toggleFavorite() {
        guard let cur = current else { return }
        // create step item for FavoriteManager
        let stepItem = SDStepItem(
            id: UUID(),
            kind: convertKind(cur.kind),
            titleRU: cur.face.titleRU,
            subtitleTH: cur.face.subtitleTH,
            phonetic: cur.face.phonetic
        )
        FavoriteManager.shared.toggle(step: stepItem, courseId: cur.courseId, lessonId: cur.lessonId, order: cur.index)
    }
    
    var isCurrentFavorite: Bool {
        guard let cur = current else { return false }
        let stepItem = SDStepItem(
            id: UUID(),
            kind: convertKind(cur.kind),
            titleRU: cur.face.titleRU,
            subtitleTH: cur.face.subtitleTH,
            phonetic: cur.face.phonetic
        )
        return FavoriteManager.shared.contains(step: stepItem, courseId: cur.courseId, lessonId: cur.lessonId, order: cur.index)
    }
    
    func prev() {
        guard !queue.isEmpty else {
            current = nil
            return
        }
        guard let cur = current else {
            current = queue.first
            return
        }
        let currentId = resolveId(cur)
        guard let i = queue.firstIndex(where: { resolveId($0) == currentId }) else {
            current = queue.first
            return
        }
        let prevIndex = (i - 1 + queue.count) % queue.count
        current = queue[prevIndex]
        if let cur = current {
            // A1: keep "current lesson" source-of-truth in sync
            session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
            // B3: restore persisted attempt result
            restoreAttemptResult(for: cur)
        }
    }

    func repeatCurrent() {
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        clearTrainingASRResult()
        heardConfidence = 0
        taikaHints = []
        clearToneBreakdownState()
        setPhase(.idle)
        lastAttemptURL = nil
        lastAttempt = nil
        attemptCount = 0
        sessionScores = []
        lastPlayed = .none
        attemptPlayer?.stop()
        attemptPlayer = nil
    }

    func toggleAnalysis() {
        isAnalysisExpanded.toggle()
    }

    /// Загрузить очередь только карточек из указанного курса (тап по иконке Speaker на карточке курса).
    /// Спец. id: `__favorites__` — всё избранное; `__dictionary__` — только словарь умного спикера.
    /// `lessonId` — опционально сузить до одного урока.
    /// `lessonIds` — multi-select scope из LessonsView; в него попадают только выбранные уроки.
    func loadQueueForCourse(_ courseId: String, lessonId: String? = nil, lessonIds: [String]? = nil, cardKeys: [String]? = nil) {
        if courseId == "__favorites__" || courseId == "__dictionary__" {
            speakerContextCourseId = courseId
            activeFilterId = SpeakerMode.favoritesMode.id
            learnedLessonIds = []
            learnedLessonFilter = nil
            if baseQueue.isEmpty { prepareTrainingPoolIfNeeded() }
            let fav: [StepData.SpeakerResolved] = {
                if courseId == "__dictionary__" {
                    return buildFavoritesQueue().filter {
                        $0.courseId == "user_dict" && $0.lessonId == "smart_speaker"
                    }
                }
                // Избранное уроков — без словаря «Скажи сам» (для него отдельный вход).
                return buildFavoritesQueue().filter {
                    !($0.courseId == "user_dict" && $0.lessonId == "smart_speaker")
                }
            }()
            if fav.isEmpty {
                queue = []
                current = nil
                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = [
                    courseId == "__dictionary__"
                    ? "в словаре пока пусто"
                    : "в избранном пусто"
                ]
                recordingPartialThai = nil
                recordingMeter = 0
                lastAttemptURL = nil
                lastAttempt = nil
                attemptCount = 0
                sessionScores = []
                lastPlayed = .none
                attemptPlayer?.stop()
                attemptPlayer = nil
                setPhase(.hint)
            } else {
                queue = fav
                if shuffleQueue { shuffle() }
                current = queue.first
                if let cur = current { restoreAttemptResult(for: cur) }
            }
            return
        }
        if baseQueue.isEmpty {
            prepareTrainingPoolIfNeeded()
        }
        let byCourse = baseQueue.filter { $0.courseId == courseId }
        let preferredLessonRaw = lessonId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredLesson = (preferredLessonRaw?.isEmpty == false) ? preferredLessonRaw : nil
        let preferredLower = preferredLesson?.lowercased()
        let selectedLessonSet = Set(
            (lessonIds ?? []).compactMap { raw in
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return value.isEmpty ? nil : value
            }
        )

        let lessonFiltered: [StepData.SpeakerResolved] = {
            if !selectedLessonSet.isEmpty {
                return byCourse.filter { selectedLessonSet.contains($0.lessonId.lowercased()) }
            }
            guard let preferredLower else { return byCourse }
            let byLesson = byCourse.filter { $0.lessonId.lowercased() == preferredLower }
            // Если в этом уроке ещё нет выученных — не молчим: весь курс, но старт с предпочитаемого места.
            return byLesson.isEmpty ? byCourse : byLesson
        }()
        let filtered: [StepData.SpeakerResolved] = {
            guard let cardKeys else { return lessonFiltered }
            let wanted = Set(cardKeys.map(Self.normalizedCardKey))
            return lessonFiltered.filter {
                wanted.contains(Self.normalizedCardKey("\($0.lessonId)|\($0.face.titleRU)"))
            }
        }()
        speakerContextCourseId = courseId
        activeFilterId = SpeakerMode.learned.id
        learnedLessonIds = !selectedLessonSet.isEmpty
            ? Array(Set(byCourse.filter { selectedLessonSet.contains($0.lessonId.lowercased()) }.map(\.lessonId))).sorted()
            : Array(Set(byCourse.map(\.lessonId))).sorted()
        // Single lesson keeps its chip; a multi-select session is already scoped and shows no misleading one-lesson chip.
        if !selectedLessonSet.isEmpty {
            learnedLessonFilter = nil
        } else if let preferredLower,
                  byCourse.contains(where: { $0.lessonId.lowercased() == preferredLower }) {
            learnedLessonFilter = byCourse.first(where: { $0.lessonId.lowercased() == preferredLower })?.lessonId
        } else {
            learnedLessonFilter = nil
        }
        if filtered.isEmpty {
            queue = []
            current = nil
            heardThai = nil
            heardRU = nil
            heardTranslit = nil
            heardConfidence = 0
            taikaHints = ["в этом курсе пока нет пройденных карточек для Speaker"]
            recordingPartialThai = nil
            recordingMeter = 0
            lastAttemptURL = nil
            lastAttempt = nil
            attemptCount = 0
            sessionScores = []
            lastPlayed = .none
            attemptPlayer?.stop()
            attemptPlayer = nil
            setPhase(.hint)
        } else {
            // Старт с нужного урока, а не с первого в каталоге.
            let startLessonLower = preferredLower
                ?? session.snapshot.lastLessonByCourse[courseId]?.lowercased()
            let ordered: [StepData.SpeakerResolved]
            if shuffleQueue {
                ordered = filtered.shuffled()
            } else if let startLessonLower,
                      let pivot = filtered.firstIndex(where: { $0.lessonId.lowercased() == startLessonLower }) {
                ordered = Array(filtered[pivot...]) + Array(filtered[..<pivot])
            } else {
                ordered = filtered
            }
            queue = ordered
            pickFirst()
        }
    }

    func applyFilter(_ id: UUID) {
        guard let mode = SpeakerMode(id: id) else { return }

        // A course-scoped Speaker session must never fall back to the global learned pool.
        // The filter strip can re-emit the active `.learned` id during onAppear; preserve
        // the handoff from Step/Course and rebuild only that course's queue instead.
        if mode == .learned,
           let courseId = speakerContextCourseId,
           courseId != "__favorites__",
           courseId != "__dictionary__" {
            activeFilterId = mode.id
            loadQueueForCourse(courseId, lessonId: learnedLessonFilter)
            return
        }

        speakerContextCourseId = nil
        activeFilterId = mode.id

        if baseQueue.isEmpty {
            prepareTrainingPoolIfNeeded()
        }

        switch mode {
        case .current:
            let cur = buildCurrentLessonQueue()
            if cur.isEmpty {
                // A2/A3: "current lesson" must not silently fall back to another pool.
                // If we can't resolve the active lesson or it has no speaker cards, show empty state.
                queue = []
                current = nil
                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = []
                recordingPartialThai = nil
                recordingMeter = 0
                lastAttemptURL = nil
                lastAttempt = nil
                attemptCount = 0
                sessionScores = []
                lastPlayed = .none
                attemptPlayer?.stop()
                attemptPlayer = nil
                setPhase(.idle)
            } else {
                queue = cur
                if shuffleQueue { shuffle() }
                current = queue.first
                if let cur = current {
                    restoreAttemptResult(for: cur)
                }
            }

        case .random:
            if baseQueue.isEmpty {
                stopMeter()
                recordingPartialThai = nil
                recordingMeter = 0
                lastAttemptURL = nil
                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = ["пройдите урок — здесь появятся фразы для тренировки"]
                queue = []
                current = nil
                setPhase(.hint)
                lastAttempt = nil
                attemptCount = 0
                sessionScores = []
                lastPlayed = .none
                attemptPlayer?.stop()
                attemptPlayer = nil
            } else {
                queue = baseQueue.shuffled()
                current = queue.first
                if let cur = current {
                    restoreAttemptResult(for: cur)
                }
            }

        case .favorites:
            let fav = buildFavoritesQueue()
            if fav.isEmpty {
                // clear any previous state so UI doesn't show stale cards
                stopMeter()
                recordingPartialThai = nil
                recordingMeter = 0
                lastAttemptURL = nil

                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = ["в избранном пусто"]

                queue = []
                current = nil
                setPhase(.hint)
                lastAttempt = nil
                attemptCount = 0
                sessionScores = []
                lastPlayed = .none
                attemptPlayer?.stop()
                attemptPlayer = nil
            } else {
                queue = fav
                if shuffleQueue { shuffle() }
                current = queue.first
                if let cur = current {
                    restoreAttemptResult(for: cur)
                }
            }

        case .learned:
            let learnedOnly = buildLearnedOnlyQueue()
            learnedLessonIds = Array(Set(learnedOnly.map(\.lessonId))).sorted()
            let filtered: [StepData.SpeakerResolved]
            if let f = learnedLessonFilter, !f.isEmpty {
                filtered = learnedOnly.filter { $0.lessonId == f }
            } else {
                filtered = learnedOnly
            }
            if filtered.isEmpty {
                stopMeter()
                recordingPartialThai = nil
                recordingMeter = 0
                lastAttemptURL = nil
                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = learnedOnly.isEmpty ? ["пока нет выученных фраз"] : ["в этом уроке нет фраз для спикера"]
                queue = []
                current = nil
                setPhase(.hint)
                lastAttempt = nil
                attemptCount = 0
                sessionScores = []
                lastPlayed = .none
                attemptPlayer?.stop()
                attemptPlayer = nil
            } else {
                queue = filtered
                if shuffleQueue { shuffle() }
                current = queue.first
                if let cur = current {
                    restoreAttemptResult(for: cur)
                }
            }

        }
    }

    /// Set second-level filter for "выученные": nil or "" = "Все", otherwise only steps from that lessonId.
    private static func normalizedCardKey(_ raw: String) -> String {
        let parts = raw.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return raw.lowercased() }
        return "\(parts[0].lowercased().replacingOccurrences(of: "_", with: "-"))|\(parts[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    func setLearnedLessonFilter(_ lessonId: String?) {
        let normalized = lessonId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (normalized?.isEmpty == false) ? normalized : nil
        learnedLessonFilter = value
        if let cid = speakerContextCourseId,
           cid != "__favorites__",
           cid != "__dictionary__" {
            // Перезагружаем очередь курса с учётом выбранного урока (или всех).
            loadQueueForCourse(cid, lessonId: value)
            return
        }
        if activeFilterId == SpeakerMode.learnedMode.id {
            applyFilter(SpeakerMode.learnedMode.id)
        }
    }

    // MARK: - conversation mode (say in Russian → translate → phonetic + TTS)

    /// Play TTS of the Thai result in conversation mode. No-op until pipeline wired.
    func playConversationTTS() {
        guard let thai = heardThai?.trimmingCharacters(in: .whitespacesAndNewlines), !thai.isEmpty else { return }
        // Will use StepAudio or AVSpeechSynthesizer th-TH in pipeline step
        StepAudio.shared.speak(text: thai, language: "th-TH")
    }

    /// Play TTS for a history row (or current Thai if empty).
    func playConversationHistoryTTS(_ item: SpeakerConversationHistoryItem) {
        let thai = item.thai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thai.isEmpty else { return }
        StepAudio.shared.speak(text: thai, language: "th-TH")
    }

    /// Commit current translation only when the user explicitly starts pronunciation training.
    /// The Dictionary save action uses FavoriteManager independently.
    func commitConversationToHistoryIfNeeded() {
        // Тренировка существующей фразы — только балл на карточке, без новой записи.
        if activePracticeHistoryId != nil || conversationExpectedThai != nil { return }

        let ru = (heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let thai = (heardThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ph = Self.teachingPhoneticOrNil(heardTranslit) ?? ""
        // Без русского не коммитим — иначе в ленте появляются фантомы вроде «са-ва-тд-и-и» без смысла.
        guard !ru.isEmpty, !thai.isEmpty || !ph.isEmpty else { return }

        // Dedup по всей ленте (не только first) — иначе тренировка 2-й карточки плодила дубль.
        if let existingIdx = conversationHistory.firstIndex(where: {
            $0.russian == ru && (thai.isEmpty || $0.thai == thai)
        }) {
            if existingIdx > 0 {
                let item = conversationHistory.remove(at: existingIdx)
                conversationHistory.insert(item, at: 0)
                persistConversationHistory()
            }
            return
        }

        let item = SpeakerConversationHistoryItem(russian: ru, thai: thai, phonetic: ph)
        conversationHistory.insert(item, at: 0)
        if conversationHistory.count > conversationHistoryLimit {
            conversationHistory = Array(conversationHistory.prefix(conversationHistoryLimit))
        }
        persistConversationHistory()
    }

    /// End first-entry / demo pronunciation so main Speaker opens on a clean start — not the leftover onboarding phrase.
    func endEphemeralPracticeSession() {
        cancelScheduledConversationListening()
        pendingConversationAutoRecord = false
        pendingConversationDemoRU = nil
        activeAttemptToken = nil
        if phase == .recording {
            _ = recorder.stop()
            stopMeter()
        }
        attemptPlayer?.stop()
        attemptPlayer = nil
        lastPlayed = .none
        lastAttemptURL = nil
        lastAttempt = nil
        finishConversationPractice(saveScore: false)
    }

    /// Закрыть тренировку/фокус: записать балл на карточку, без дубля и без залипшего скора.
    func finishConversationPractice(saveScore: Bool = true) {
        if saveScore, let id = activePracticeHistoryId {
            let score = displayScore
            if score > 0 {
                updateHistoryPracticeScore(id: id, score: score)
            }
        }
        activePracticeHistoryId = nil
        conversationExpectedThai = nil
        conversationExpectedTranslitForFeedback = nil
        conversationHeardThaiASR = nil
        conversationHeardPhoneticFromASR = nil
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        heardConfidence = 0
        taikaHints = []
        lastAttemptURL = nil
        lastAttempt = nil
        lastPlayed = .none
        syllableFeedback = []
        breakdownHybridScore = nil
        clearToneBreakdownState()
        clearPhrasePartsState()
        setPhase(.idle)
    }

    /// Drop a pending delayed auto-listen so it cannot start after the user left or chose another action.
    func cancelScheduledConversationListening() {
        conversationListenKickToken = UUID()
    }

    /// Start free conversation listening after UI/tab has settled. Token + phase guards prevent double-start.
    func scheduleConversationListening(after delay: TimeInterval) {
        let token = UUID()
        conversationListenKickToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard self.conversationListenKickToken == token else { return }
            guard self.speakerUIMode == .conversation else { return }
            guard self.conversationExpectedThai == nil, self.activePracticeHistoryId == nil else { return }
            switch self.phase {
            case .recording, .analyzing, .analyzingTranslation:
                return
            default:
                self.startConversationRecording()
            }
        }
    }

    /// «Новая фраза» / закрытие фокуса: без лишнего commit при тренировке.
    /// `startListening` — сразу слушать, без второго тапа по микрофону.
    func conversationRepeat(startListening: Bool = false) {
        if !startListening {
            cancelScheduledConversationListening()
        }
        if activePracticeHistoryId != nil || conversationExpectedThai != nil {
            finishConversationPractice(saveScore: true)
        } else {
            conversationExpectedThai = nil
            conversationExpectedTranslitForFeedback = nil
            conversationHeardThaiASR = nil
            conversationHeardPhoneticFromASR = nil
            heardThai = nil
            heardRU = nil
            heardTranslit = nil
            heardConfidence = 0
            taikaHints = []
            lastAttemptURL = nil
            lastAttempt = nil
            lastPlayed = .none
            syllableFeedback = []
            breakdownHybridScore = nil
            activePracticeHistoryId = nil
            clearToneBreakdownState()
            clearPhrasePartsState()
            setPhase(.idle)
        }
        if startListening {
            scheduleConversationListening(after: 0.16)
        }
    }

    func removeConversationHistoryItem(id: UUID) {
        conversationHistory.removeAll { $0.id == id }
        if activePracticeHistoryId == id { activePracticeHistoryId = nil }
        SpeakerConversationToneCacheStore.remove(historyItemId: id)
        persistConversationHistory()
    }

    /// Restore a history phrase as the active result (for «Тренировка» / listen from row).
    func activateConversationHistoryItem(_ item: SpeakerConversationHistoryItem) {
        cancelScheduledConversationListening()
        activePracticeHistoryId = item.id
        conversationExpectedThai = item.thai.isEmpty ? nil : item.thai
        let ph = Self.teachingPhoneticOrNil(item.phonetic)
        conversationExpectedTranslitForFeedback = ph
        heardRU = item.russian.isEmpty ? nil : item.russian
        heardThai = item.thai.isEmpty ? nil : item.thai
        heardTranslit = ph
        taikaHints = []
        lastPlayed = .none
        attemptPlayer?.stop()
        attemptPlayer = nil

        if restoreConversationBreakdownFromCache(itemId: item.id) {
            let scoreToShow = displayScore
            if scoreToShow > 0 {
                let hint = feedbackHint(for: scoreToShow)
                let result = PronunciationResult(
                    totalScore: scoreToShow,
                    accuracy: scoreToShow,
                    fluency: scoreToShow,
                    completeness: scoreToShow,
                    hint: hint
                )
                setPhase(.feedback(result: result))
                taikaHints = ["оценка: \(scoreToShow)", hint]
                return
            }
        }

        conversationHeardThaiASR = nil
        conversationHeardPhoneticFromASR = nil
        heardConfidence = 0
        lastAttemptURL = nil
        lastAttempt = nil
        clearToneBreakdownState()
        setPhase(.hint)
    }

    /// User chose text mode: drop pending auto-listen and abort free capture so the mic does not keep running.
    func abandonConversationListeningForText() {
        cancelScheduledConversationListening()
        pendingConversationAutoRecord = false
        guard speakerUIMode == .conversation else { return }
        guard conversationExpectedThai == nil, activePracticeHistoryId == nil else { return }

        switch phase {
        case .analyzing, .analyzingTranslation:
            return
        case .recording:
            conversationRecordingTimer?.invalidate()
            conversationRecordingTimer = nil
            conversationRecordingStartTime = nil
            conversationRecordingElapsed = 0
            activeAttemptToken = nil
            _ = recorder.stop()
            stopMeter()
            recordingPartialThai = nil
            recordingPartialTranslit = nil
            recordingPartialRU = ""
            recordingMeter = 0
            setPhase(.idle)
        default:
            // Permission may still be in-flight with phase idle — invalidate so beginCapture no-ops.
            activeAttemptToken = nil
        }
    }

    /// Conversation mode: start recording (no card required). Free: limited to conversation attempts per day; max duration enforced.
    func startConversationRecording() {
        cancelScheduledConversationListening()
        if phase == .recording || phase == .analyzing || phase == .analyzingTranslation { return }

        SpeakerConversationAttemptsStore.shared.refreshDayIfNeeded()
        guard SpeakerConversationAttemptsStore.shared.canRecord else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            taikaHints = ["демо попытки на сегодня закончились. переходи на Taika+ — безлимит"]
            setPhase(.hint)
            return
        }

        activePracticeHistoryId = nil
        conversationExpectedThai = nil
        conversationExpectedTranslitForFeedback = nil
        conversationHeardThaiASR = nil
        conversationHeardPhoneticFromASR = nil

        lastAttemptURL = nil
        lastAttempt = nil
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        recordingPartialRU = ""
        recordingMeter = 0
        conversationRecordingElapsed = 0
        conversationRecordingStartTime = nil
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        heardConfidence = 0
        taikaHints = []
        lastPlayed = .none
        clearPhrasePartsState()
        clearToneBreakdownState()

        let token = UUID()
        activeAttemptToken = token

        let beginCapture: () -> Void = { [weak self] in
            guard let self else { return }
            guard self.activeAttemptToken == token else { return }

            self.conversationRecordingStartTime = Date()
            self.setPhase(.recording)
            self.startMeter()

            self.conversationRecordingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.phase == .recording, let start = self.conversationRecordingStartTime else { return }
                    let elapsed = Date().timeIntervalSince(start)
                    self.conversationRecordingElapsed = min(elapsed, self.conversationRecordingMaxDuration)
                    if elapsed >= self.conversationRecordingMaxDuration {
                        self.conversationRecordingTimer?.invalidate()
                        self.conversationRecordingTimer = nil
                        self.stopConversationRecordingAndProcess()
                    }
                }
            }
            if let timer = self.conversationRecordingTimer {
                RunLoop.main.add(timer, forMode: .common)
            }

            self.recorder.startAuthorized { [weak self] (url: URL?) in
                guard let self else { return }
                guard self.activeAttemptToken == token else { return }
                if let url {
                    self.lastAttemptURL = url
                    self.lastAttempt = url
                }
            }
        }

        if recorder.hasMicrophoneAccess {
            beginCapture()
        } else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let ok = await self.recorder.requestMicrophoneAccess()
                guard self.activeAttemptToken == token else { return }
                guard ok else {
                    self.activeAttemptToken = nil
                    self.taikaHints = ["нужен доступ к микрофону"]
                    self.setPhase(.hint)
                    return
                }
                beginCapture()
            }
        }
    }

    /// Conversation mode: RU → TH from typed / demo text (no mic). Keeps preview until confirm.
    func startConversationDemoPhrase(_ ruText: String) {
        startConversationFromText(ruText, consumeAttempt: true)
    }

    /// Typed compose or edit-and-retranslate. `consumeAttempt` false when correcting ASR/draft.
    func startConversationFromText(_ ruText: String, consumeAttempt: Bool = true) {
        cancelScheduledConversationListening()
        pendingConversationAutoRecord = false
        if phase == .recording || phase == .analyzing || phase == .analyzingTranslation { return }
        let ruTrimmed = ruText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ruTrimmed.isEmpty else { return }

        SpeakerConversationAttemptsStore.shared.refreshDayIfNeeded()
        if consumeAttempt {
            guard SpeakerConversationAttemptsStore.shared.canRecord else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                taikaHints = ["демо попытки на сегодня закончились. переходи на Taika+ — безлимит"]
                setPhase(.hint)
                return
            }
        }

        let words = ruTrimmed.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
        if ruTrimmed.count > 80 || words.count > 12 {
            heardRU = ruTrimmed
            heardThai = nil
            heardTranslit = nil
            heardPhraseParts = []
            taikaHints = ["скажи короче: одну фразу"]
            setPhase(.hint)
            return
        }

        if consumeAttempt {
            clearConversationResult()
        } else {
            // Edit in place: keep RU, drop old Thai until new translate lands.
            heardThai = nil
            heardTranslit = nil
            heardPhraseParts = []
            conversationExpectedThai = nil
            conversationExpectedTranslitForFeedback = nil
            conversationHeardThaiASR = nil
            conversationHeardPhoneticFromASR = nil
            activePracticeHistoryId = nil
        }

        heardRU = ruTrimmed
        taikaHints = ["перевожу…"]
        setPhase(.analyzing)
        analyzingStartedAt = Date()

        Task { [weak self] in
            guard let self else { return }
            do {
                let (thText, phonetic, parts) = try await self.withTimeout(seconds: 25) {
                    try await self.smartSpeakerTranslate(ru: ruTrimmed)
                }
                await MainActor.run {
                    self.heardRU = ruTrimmed
                    let thai = thText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let ph = Self.teachingPhoneticOrNil(phonetic)
                    self.heardThai = thai.isEmpty ? nil : thai
                    self.heardTranslit = ph
                    self.conversationExpectedTranslitForFeedback = ph
                    self.heardPhraseParts = parts
                    self.heardConfidence = 0
                    if thai.isEmpty && ph == nil {
                        self.heardPhraseParts = []
                        self.taikaHints = ["не удалось перевести. попробуй другую формулировку"]
                        self.setPhase(.hint)
                        return
                    }
                    self.taikaHints = []
                    self.setPhase(.idle)
                    self.refreshPhrasePartsIfNeeded()
                    if consumeAttempt {
                        SpeakerConversationAttemptsStore.shared.consume()
                    }
                }
            } catch {
                await MainActor.run {
                    self.heardRU = ruTrimmed
                    self.heardThai = nil
                    self.heardTranslit = nil
                    self.heardPhraseParts = []
                    self.taikaHints = ["не удалось перевести. попробуй ещё раз"]
                    self.setPhase(.hint)
                }
            }
        }
    }

    /// Re-run translate after user edited the Russian draft (no extra attempt spend).
    func retranslateConversationDraft(_ ruText: String) {
        startConversationFromText(ruText, consumeAttempt: false)
    }

    /// Confirm draft: history (+ optional dictionary), then optional immediate practice in the same window.
    func confirmConversationDraft(addToDictionary: Bool = true, startPractice: Bool = false) {
        guard speakerUIMode == .conversation else { return }
        if phase == .recording || phase == .analyzing || phase == .analyzingTranslation { return }

        let ru = (heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let thai = (heardThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ph = Self.teachingPhoneticOrNil(heardTranslit) ?? ""
        guard !ru.isEmpty, !thai.isEmpty || !ph.isEmpty else { return }

        if startPractice {
            commitConversationToHistoryIfNeeded()
        }

        if addToDictionary, !thai.isEmpty, !ph.isEmpty {
            let parts = heardPhraseParts.map { FavoritePhrasePart(p: $0.p, m: $0.m) }
            FavoriteManager.shared.addSmartSpeakerCard(
                ru: ru,
                thai: thai,
                phonetic: ph,
                phraseParts: parts.isEmpty ? nil : parts
            )
        }

        if startPractice {
            if let item = conversationHistory.first(where: {
                $0.russian == ru && (thai.isEmpty || $0.thai == thai)
            }) {
                activateConversationHistoryItem(item)
            }
            startConversationPronunciationCheck()
        } else {
            // Keep the translated phrase visible after saving. The user can train it
            // immediately or explicitly tap “Сказать ещё” to begin a new phrase.
            // This closes the learning loop instead of dropping into an empty state.
        }
    }

    /// Close preview without saving to the feed.
    func discardConversationDraft() {
        guard activePracticeHistoryId == nil, conversationExpectedThai == nil else {
            finishConversationPractice(saveScore: false)
            return
        }
        clearConversationResult()
    }

    /// Conversation mode: stop recording and run pipeline ASR(ru) → translate → translit → UI.
    func stopConversationRecordingAndProcess() {
        guard phase == .recording else { return }

        conversationRecordingTimer?.invalidate()
        conversationRecordingTimer = nil
        conversationRecordingStartTime = nil
        conversationRecordingElapsed = 0

        let token = activeAttemptToken
        activeAttemptToken = nil

        let url = recorder.stop()
        stopMeter()
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        recordingPartialRU = ""
        recordingMeter = 0
        lastAttemptURL = url
        lastAttempt = url
        lastPlayed = .none

        guard let url else {
            taikaHints = ["не получилось записать. проверь доступ к микрофону"]
            setPhase(.hint)
            return
        }

        setPhase(.analyzing)
        analyzingStartedAt = Date()
        taikaHints = ["распознаю…"]

        Task { [weak self] in
            guard let self else { return }
            var ruTrimmed = ""
            do {
                let ruText = try await self.withTimeout(seconds: 15) {
                    try await self.recognizeRussian(url: url)
                }
                ruTrimmed = ruText.trimmingCharacters(in: .whitespacesAndNewlines)

                await MainActor.run {
                    self.heardRU = ruTrimmed.isEmpty ? nil : ruTrimmed
                    self.taikaHints = ["перевожу…"]
                }

                guard !ruTrimmed.isEmpty else {
                    await MainActor.run {
                        self.heardThai = nil
                        self.heardTranslit = nil
                        self.heardPhraseParts = []
                        self.taikaHints = ["не расслышала. нажми микрофон и скажи ещё раз"]
                        self.setPhase(.hint)
                    }
                    return
                }

                // Limit long "tirades" — keep UX readable
                let words = ruTrimmed.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
                if ruTrimmed.count > 80 || words.count > 12 {
                    await MainActor.run {
                        self.heardRU = ruTrimmed
                        self.heardThai = nil
                        self.heardTranslit = nil
                        self.heardPhraseParts = []
                        self.taikaHints = ["скажи короче: одну фразу"]
                        self.setPhase(.hint)
                    }
                    return
                }

                let (thText, phonetic, parts) = try await self.withTimeout(seconds: 25) {
                    try await self.smartSpeakerTranslate(ru: ruTrimmed)
                }

                await MainActor.run {
                    if self.activeAttemptToken != nil && self.activeAttemptToken != token { return }

                    self.heardRU = ruTrimmed
                    let thai = thText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let ph = Self.teachingPhoneticOrNil(phonetic)
                    self.heardThai = thai.isEmpty ? nil : thai
                    self.heardTranslit = ph
                    self.conversationExpectedTranslitForFeedback = ph
                    self.heardPhraseParts = parts
                    self.heardConfidence = 0

                    if thai.isEmpty && ph == nil {
                        self.heardPhraseParts = []
                        self.taikaHints = ["не удалось перевести. попробуй другую формулировку"]
                        self.setPhase(.hint)
                        return
                    }

                    self.taikaHints = []
                    // Держим превью в фокусе: правка RU / подтверждение в ленту+словарь / тренировка.
                    self.setPhase(.idle)
                    self.refreshPhrasePartsIfNeeded()
                    SpeakerConversationAttemptsStore.shared.consume()
                }
            } catch {
                await MainActor.run {
                    if self.activeAttemptToken != nil && self.activeAttemptToken != token { return }
                    self.heardRU = ruTrimmed.isEmpty ? nil : ruTrimmed
                    self.heardThai = nil
                    self.heardTranslit = nil
                    self.heardPhraseParts = []
                    let hint: String
                    if let e = error as NSError?, e.domain == "speaker.timeout" {
                        hint = ruTrimmed.isEmpty
                            ? "не успела распознать. скажи короче и ближе к микрофону"
                            : "перевод занял слишком долго. попробуй ещё раз"
                    } else if let e = error as NSError?, e.domain == "speaker.asr" {
                        hint = "не расслышала. проверь микрофон и скажи ещё раз"
                    } else if let e = error as NSError?, e.domain == "speaker.smart", e.code == 1 {
                        hint = "Разбор сейчас недоступен. Попробуй чуть позже."
                    } else if let e = error as NSError?, e.domain == "speaker.smart.http" {
                        let detail = e.localizedDescription
                        #if DEBUG
                        print("[speaker] smart_speaker.http \(e.code): \(detail)")
                        #endif
                        if detail.contains("Application not found") || detail == "railway_down" {
                            hint = "Сервис разбора временно недоступен. Попробуй снова через минуту."
                        } else if (500...599).contains(e.code) || detail.localizedCaseInsensitiveContains("failed to respond") {
                            hint = "Сервис перевода сейчас не отвечает. Попробуй через минуту."
                        } else if e.code == 404, detail.localizedCaseInsensitiveContains("OPENAI_API_KEY") {
                            hint = "Не удалось разобрать фразу. Попробуй ещё раз."
                        } else if e.code == 404, detail.localizedCaseInsensitiveContains("LLM translation failed") {
                            hint = "Не удалось перевести фразу. Попробуй ещё раз."
                        } else if e.code == 422 || detail.localizedCaseInsensitiveContains("empty") {
                            hint = "не расслышала фразу. скажи ещё раз чётче"
                        } else {
                            hint = "Не удалось перевести. Попробуй ещё раз"
                        }
                    } else if let e = error as NSError? {
                        #if DEBUG
                        print("[speaker] smart_speaker error: \(e.domain) \(e.code) \(e.localizedDescription)")
                        #endif
                        if e.domain == NSURLErrorDomain {
                            switch e.code {
                            case NSURLErrorTimedOut:
                                hint = "Таймаут. Скажи короче и попробуй снова"
                            case NSURLErrorCannotConnectToHost, NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                                hint = "Проверь интернет и попробуй снова"
                            default:
                                hint = "Ошибка сети. Попробуй ещё раз"
                            }
                        } else if e.domain == "kAFAssistantErrorDomain" || e.localizedDescription.localizedCaseInsensitiveContains("speech") {
                            hint = "не расслышала. скажи ещё раз чётче"
                        } else {
                            hint = "Не удалось перевести. Попробуй ещё раз"
                        }
                    } else {
                        hint = "Не удалось перевести. Попробуй ещё раз"
                    }
                    self.taikaHints = [hint]
                    self.setPhase(.hint)
                }
            }
        }
    }

    // MARK: - Smart Speaker API (RU -> TH + phonetic with tones)

    struct SmartSpeakerPart: Codable, Equatable, Hashable {
        let p: String
        let m: String
    }

    struct SmartSpeakerResponse: Decodable {
        let thai: String
        let phonetic: String
        let parts: [SmartSpeakerPart]?
    }

    /// Base URL for Smart Speaker backend. Использует тот же сервер, что и tone API (/assess и /smart_speaker на одном api.py).
    static var smartSpeakerBaseURL: String? {
        if let url = ProcessInfo.processInfo.environment["TAIKA_SMART_SPEAKER_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return url
        }
        return toneAssessmentBaseURL
    }

    private enum SmartSpeakerPoliteness: String {
        case male, female, kathoey
    }

    private static let smartSpeakerPolitenessKey = "taika.smart_speaker.politeness"

    var smartSpeakerPoliteness: String {
        smartSpeakerPolitenessValue
    }

    func setSmartSpeakerPoliteness(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let v = SmartSpeakerPoliteness(rawValue: cleaned)?.rawValue ?? SmartSpeakerPoliteness.female.rawValue
        smartSpeakerPolitenessValue = v
        UserDefaults.standard.set(v, forKey: Self.smartSpeakerPolitenessKey)
    }

    private func smartSpeakerTranslate(ru: String) async throws -> (thai: String, phonetic: String, parts: [SmartSpeakerPart]) {
        guard let base = Self.smartSpeakerBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !base.isEmpty else {
            throw NSError(domain: "speaker.smart", code: 1)
        }
        #if DEBUG
        print("[speaker] smart_speaker POST \(base)/smart_speaker text_ru=\(ru.prefix(30))...")
        #endif
        let url = URL(string: base.hasSuffix("/") ? base + "smart_speaker" : base + "/smart_speaker")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let politeness = smartSpeakerPolitenessValue
        let body: [String: Any] = [
            "text_ru": ru,
            "politeness": politeness,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code >= 200, code < 300 else {
            throw Self.smartSpeakerHTTPError(code: code, data: data)
        }
        let decoded = try JSONDecoder().decode(SmartSpeakerResponse.self, from: data)
        var th = decoded.thai.trimmingCharacters(in: .whitespacesAndNewlines)
        var ph = decoded.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.phoneticLooksLikeRussianSpellout(ru: ru, phonetic: ph) {
            #if DEBUG
            print("[speaker] smart_speaker: dropping phonetic (looks like RU letter-by-letter, not Thai translit)")
            #endif
            ph = ""
        }
        ph = await Self.sanitizeThaiPhonetic(ph, thai: th, repair: { [weak self] thai in
            guard let self else { return nil }
            return try? await self.smartSpeakerPhoneticFromThai(thai: thai)
        })
        // Server owns the single gender particle; collapse LLM/cache duplicates locally too.
        let canon = Self.applyCanonicalPoliteness(thai: th, phonetic: ph, politeness: politeness)
        th = canon.thai
        ph = canon.phonetic
        var parts = (decoded.parts ?? []).compactMap { part -> SmartSpeakerPart? in
            let p = part.p.trimmingCharacters(in: .whitespacesAndNewlines)
            let m = part.m.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !p.isEmpty, !m.isEmpty else { return nil }
            return SmartSpeakerPart(p: p, m: m)
        }
        // Разбора может не быть: сервер не отдаёт его, если он не сошёлся с фонетикой.
        // Не ждём здесь — фраза важнее, а разбор догрузит `refreshPhrasePartsIfNeeded()`.
        parts = Self.resolvedTeachingParts(api: parts, phonetic: ph, thai: th, ru: ru)
        parts = Self.canonicalizeTrailingPolitenessGloss(parts)
        if !Self.partsMatchPhonetic(phonetic: ph, parts: parts) {
            parts = []
        }
        return (thai: th, phonetic: ph, parts: parts)
    }

    /// Mirrors server `_strip_trailing_politeness` + `_apply_politeness`: exactly one particle.
    static func applyCanonicalPoliteness(
        thai: String,
        phonetic: String,
        politeness: String
    ) -> (thai: String, phonetic: String) {
        var th = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        var ph = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        let thaiTrail = try? NSRegularExpression(pattern: #"\s*(ครับ|ค่ะ|คะ)\s*$"#)
        let phTrail = try? NSRegularExpression(
            pattern: #"(?i)\s*(?:кхрап|крап|кха)\s*[→↓↘↑↗↕↔⇕⇅]?\s*$"#
        )
        for _ in 0..<8 {
            var changed = false
            if let thaiTrail {
                let range = NSRange(th.startIndex..<th.endIndex, in: th)
                let next = thaiTrail.stringByReplacingMatches(in: th, range: range, withTemplate: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if next != th { th = next; changed = true }
            }
            if let phTrail {
                let range = NSRange(ph.startIndex..<ph.endIndex, in: ph)
                let next = phTrail.stringByReplacingMatches(in: ph, range: range, withTemplate: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if next != ph { ph = next; changed = true }
            }
            if !changed { break }
        }
        let p = SmartSpeakerPoliteness(rawValue: politeness.lowercased()) ?? .female
        if p == .male {
            th = (th + " ครับ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !ph.isEmpty { ph = (ph + " кхрап↘").trimmingCharacters(in: .whitespacesAndNewlines) }
        } else {
            th = (th + " ค่ะ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !ph.isEmpty { ph = (ph + " кха↘").trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return (th, ph)
    }

    static func canonicalizeTrailingPolitenessGloss(_ parts: [SmartSpeakerPart]) -> [SmartSpeakerPart] {
        guard var last = parts.last else { return parts }
        let key = last.p.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter }
        let gloss: String?
        switch key {
        case "кхрап", "крап": gloss = "вежливость (м)"
        case "кха": gloss = "вежливость (ж)"
        default: gloss = nil
        }
        guard let gloss else { return parts }
        last = SmartSpeakerPart(p: last.p, m: gloss)
        return Array(parts.dropLast()) + [last]
    }

    /// Lock API gloss to «КАК СКАЗАТЬ» space-chunks. No local word dictionary — server owns meanings.
    static func resolvedTeachingParts(
        api: [SmartSpeakerPart],
        phonetic: String,
        thai: String,
        ru: String = ""
    ) -> [SmartSpeakerPart] {
        _ = thai
        // Не режем «ру↑-сык↘» по стрелке: дефис внутри слова — слог, не граница.
        // Старый word_spaces превращал 4 слова в 5 чанков и разбор тихо пропадал.
        let shaped = shapeThaiPhonetic(phonetic)
        let apiClean = api.filter {
            isGoodTeachingMeaning($0.m) && !isWholePhraseGloss($0.m, ru: ru)
        }
        let groups = phoneticWordGroups(shaped)
        guard !groups.isEmpty else { return apiClean }
        return alignPartsToPhoneticGroups(groups: groups, api: apiClean)
    }

    /// Match API glosses onto phonetic chunks; drop leftovers. Never invent meanings.
    private static func alignPartsToPhoneticGroups(
        groups: [String],
        api: [SmartSpeakerPart]
    ) -> [SmartSpeakerPart] {
        var unused = api
        var out: [SmartSpeakerPart] = []

        for g in groups {
            let gk = normalizeTeachingKey(g)
            guard !gk.isEmpty else { continue }

            if let idx = unused.firstIndex(where: { normalizeTeachingKey($0.p) == gk }) {
                let m = unused.remove(at: idx).m
                if isGoodTeachingMeaning(m), !isWeakTeachingGloss(m) {
                    out.append(SmartSpeakerPart(p: g, m: m))
                }
                continue
            }

            // Consume consecutive leftovers that concatenate to this chunk (тхи+ча → ти-ча).
            var acc = ""
            var take: [Int] = []
            for (i, part) in unused.enumerated() {
                let k = normalizeTeachingKey(part.p)
                guard !k.isEmpty else { continue }
                let nxt = acc + k
                if gk.hasPrefix(nxt) {
                    acc = nxt
                    take.append(i)
                    if acc == gk { break }
                } else if acc.isEmpty {
                    continue
                } else {
                    break
                }
            }
            if acc == gk, !take.isEmpty {
                let meanings = take.map { unused[$0].m }
                let m = meanings.first(where: { isGoodTeachingMeaning($0) && !isWeakTeachingGloss($0) })
                for i in take.reversed() { unused.remove(at: i) }
                if let m {
                    out.append(SmartSpeakerPart(p: g, m: m))
                }
            }
        }
        return out
    }

    private static func isWeakTeachingGloss(_ m: String) -> Bool {
        let t = m.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t == "…" || t == "часть слова" || t == "слово" { return true }
        let letters = t.lowercased().filter { $0.isLetter }
        if letters.count <= 1 {
            let ok: Set<String> = ["я", "и", "а"]
            if !ok.contains(String(letters)) { return true }
        }
        let compact = t.lowercased().replacingOccurrences(of: " ", with: "")
        if compact == "в/у" || compact == "у/в" { return true }
        return false
    }

    /// Full Russian sentence dumped onto one chunk — useless for word-level teaching.
    private static func isWholePhraseGloss(_ m: String, ru: String) -> Bool {
        func key(_ s: String) -> String {
            s.lowercased()
                .replacingOccurrences(of: "«", with: "")
                .replacingOccurrences(of: "»", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                .replacingOccurrences(of: "  ", with: " ")
        }
        let mk = key(m)
        let rk = key(ru)
        guard !mk.isEmpty, rk.count >= 3 else { return false }
        if mk == rk { return true }
        if mk.contains(rk), mk.count <= rk.count + 4 { return true }
        return false
    }

    private static func isGoodTeachingMeaning(_ m: String) -> Bool {
        let t = m.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if t == "…" || t == "часть слова" { return false }
        return true
    }

    /// LLM often hyphenates every syllable after tones («кун-ю↘-тхи↗-ни↘»).
    /// After a tone arrow, hyphen = word boundary → space (teaching chunks split on spaces).
    /// Вызывать только на legacy-строках. На ответе /smart_speaker — нет: там дефис после
    /// стрелки это стык слогов внутри слова («ру↑-сык↘»), и резка убивает разбор.
    static func normalizePhoneticWordSpaces(_ phonetic: String) -> String {
        let arrows: [Character] = ["→", "↓", "↘", "↑", "↗", "↕", "↔"]
        var out = phonetic
        for a in arrows {
            out = out.replacingOccurrences(of: "\(a)-", with: "\(a) ")
            out = out.replacingOccurrences(of: "\(a) -", with: "\(a) ")
        }
        while out.contains("  ") {
            out = out.replacingOccurrences(of: "  ", with: " ")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Единственная каноническая фонетика спикера: цифры проговорены, обрубки склеены, ว = у.
    /// Сюда должны сходиться перевод, тренировка, история, «ты сказала» и любая отрисовка.
    nonisolated static func canonicalTeachingPhonetic(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return s }
        let emojiMap: [(String, String)] = [
            ("↘️", "↘"), ("↗️", "↗"), ("➡️", "→"), ("⬇️", "↓"), ("⬆️", "↑"),
            ("➡︎", "→"), ("⬇︎", "↓"), ("⬆︎", "↑"), ("↘︎", "↘"), ("↗︎", "↗"),
            ("➡", "→"), ("⬇", "↓"), ("⬆", "↑")
        ]
        for (from, to) in emojiMap {
            s = s.replacingOccurrences(of: from, with: to)
        }
        s = collapseLetterSpaceArrow(s)
        s = shapeThaiPhonetic(s)
        return s
    }

    nonisolated static func teachingPhoneticOrNil(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let canon = canonicalTeachingPhonetic(trimmed)
        return canon.isEmpty ? nil : canon
    }

    /// «э ↗» → «э↗».
    nonisolated static func collapseLetterSpaceArrow(_ phonetic: String) -> String {
        let arrows: Set<Character> = ["→", "↓", "↘", "↑", "↗"]
        var chars = Array(phonetic)
        var i = 0
        while i + 2 < chars.count {
            let a = chars[i], b = chars[i + 1], c = chars[i + 2]
            let isBody: Bool = {
                if a == "-" { return true }
                guard let v = a.unicodeScalars.first?.value else { return false }
                return (0x0400...0x04FF).contains(v) || v == 0x0451 || v == 0x0401
            }()
            if isBody, b.isWhitespace, arrows.contains(c) {
                chars.remove(at: i + 1)
                continue
            }
            i += 1
        }
        return String(chars)
    }

    /// Цифры → кириллица, обрубок после стрелки → обратно в слог. Границы слов не трогает.
    nonisolated static func shapeThaiPhonetic(_ phonetic: String) -> String {
        var s = expandPhoneticDigits(phonetic)
        s = glueLettersAfterArrows(s)
        s = houseWCoda(s)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Конечная ว — гласный. Курс пишет хиу / лэу / кхиу, не хив.
    nonisolated static func houseWCoda(_ phonetic: String) -> String {
        let arrows = "→↓↘↑↗"
        func replaceCoda(pattern: String, template: String, in s: String) -> String {
            guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            return re.stringByReplacingMatches(in: s, range: range, withTemplate: template)
        }
        var s = phonetic
        s = replaceCoda(pattern: "([аеёиоуыэюя])в(?=[\(arrows)\\s-]|$)", template: "$1у", in: s)
        s = replaceCoda(pattern: "ио(?=[\(arrows)\\s-]|$)", template: "иу", in: s)
        s = replaceCoda(pattern: "ью(?=[\(arrows)\\s-]|$)", template: "иу", in: s)
        return s
    }

    /// หิว is one syllable. «хи↘в» / «хи↘-в» / «хи↘ в» склеивается, затем ว→у → «хиу».
    /// Не склеиваем, если у следующих букв уже есть своя стрелка («хи↘ кхрап↘»).
    nonisolated static func glueLettersAfterArrows(_ phonetic: String) -> String {
        let pattern = #"([а-яёА-ЯЁ\-]+)([→↓↘↑↗])(?:[\s\-]*)([а-яёА-ЯЁ]+)(?![а-яёА-ЯЁ\-]*[→↓↘↑↗])"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return phonetic
        }
        var s = phonetic
        var prev = ""
        while prev != s {
            prev = s
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            s = re.stringByReplacingMatches(in: s, range: range, withTemplate: "$1$3$2")
        }
        return s
    }

    /// 90 → кау→-сип→, 1669 → нынг→-хок→-хок→-кау→, 4x6 / 4кс6 → си→-кху→-хок→.
    nonisolated static func expandPhoneticDigits(_ phonetic: String) -> String {
        let digits = ["сун→", "нынг→", "сонг→", "сам→", "си→", "ха→", "хок→", "чет→", "пэт→", "кау→"]
        let onesPlace = ["сун→", "эт→", "сонг→", "сам→", "си→", "ха→", "хок→", "чет→", "пэт→", "кау→"]
        func spoken(_ n: Int) -> String {
            if n < 10 { return digits[n] }
            if n == 10 { return "сип→" }
            if n < 20 { return "сип→-" + onesPlace[n - 10] }
            if n < 100 {
                let tens = n / 10
                let ones = n % 10
                let tensMap = [2: "ий-сип→", 3: "сам→-сип→", 4: "си→-сип→", 5: "ха→-сип→",
                               6: "хок→-сип→", 7: "чет→-сип→", 8: "пэт→-сип→", 9: "кау→-сип→"]
                let head = tensMap[tens] ?? digits[tens]
                return ones == 0 ? head : head + "-" + onesPlace[ones]
            }
            return String(n).compactMap { Int(String($0)).map { digits[$0] } }.joined(separator: "-")
        }
        var s = phonetic
        func replaceTimes(pattern: String) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            let matches = re.matches(in: s, range: range).reversed()
            for m in matches {
                guard m.numberOfRanges >= 3,
                      let r1 = Range(m.range(at: 1), in: s),
                      let r2 = Range(m.range(at: 2), in: s),
                      let a = Int(s[r1]), let b = Int(s[r2]),
                      let full = Range(m.range, in: s) else { continue }
                s.replaceSubrange(full, with: "\(spoken(a))-кху→-\(spoken(b))")
            }
        }
        replaceTimes(pattern: #"(\d+)\s*[xх×]\s*(\d+)"#)
        replaceTimes(pattern: #"(\d+)\s*кс\s*(\d+)"#)
        guard let numRe = try? NSRegularExpression(pattern: #"(\d+)[→↓↘↑↗]?"#) else { return s }
        var prev = ""
        while prev != s {
            prev = s
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            guard let m = numRe.firstMatch(in: s, range: range),
                  let r1 = Range(m.range(at: 1), in: s),
                  let full = Range(m.range, in: s) else { break }
            let raw = String(s[r1])
            guard let n = Int(raw) else { break }
            let spokenForm = raw.count >= 3
                ? raw.compactMap { Int(String($0)).map { digits[$0] } }.joined(separator: "-")
                : spoken(n)
            s.replaceSubrange(full, with: spokenForm)
        }
        return s
    }

    private static func normalizeTeachingKey(_ p: String) -> String {
        let arrows: Set<Character> = ["→", "↓", "↘", "↑", "↗", "↕", "↔"]
        var s = p.lowercased()
        s = s.replacingOccurrences(of: "ɨ", with: "и")
        s = String(s.filter { !arrows.contains($0) && $0 != " " })
        s = s.replacingOccurrences(of: "-", with: "")
        return s
    }

    /// POST /phrase_parts — word gloss when /smart_speaker returned none (older server / cache).
    private func smartSpeakerFetchPhraseParts(ru: String, thai: String, phonetic: String) async throws -> [SmartSpeakerPart] {
        guard let base = Self.smartSpeakerBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !base.isEmpty else {
            return []
        }
        let urlString = base.hasSuffix("/") ? base + "phrase_parts" : base + "/phrase_parts"
        guard let url = URL(string: urlString) else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 12
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "text_ru": ru,
            "text_th": thai,
            "phonetic": phonetic,
        ])
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code >= 200, code < 300 else { return [] }
        struct PartsOnly: Decodable { let parts: [SmartSpeakerPart]? }
        let decoded = try JSONDecoder().decode(PartsOnly.self, from: data)
        return (decoded.parts ?? []).compactMap { part in
            let p = part.p.trimmingCharacters(in: .whitespacesAndNewlines)
            let m = part.m.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !p.isEmpty, !m.isEmpty else { return nil }
            return SmartSpeakerPart(p: p, m: m)
        }
    }

    /// Тайская графика в пояснении для пользователя бесполезна: он её не читает, всё тайское
    /// приходит к нему кириллицей. Фильтр держим и на клиенте — сервер может быть старой версии.
    nonisolated static func withoutThaiScript(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: { (0x0E00...0x0E7F).contains($0.value) }) else {
            return text
        }
        var out = String(String.UnicodeScalarView(
            text.unicodeScalars.map { (0x0E00...0x0E7F).contains($0.value) ? " " : $0 }
        ))
        out = out.replacingOccurrences(of: #"\(\s*\)|\[\s*\]|«\s*»"#, with: " ", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\s+([,.;:!?])"#, with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: CharacterSet(charactersIn: " -–—,;:"))
    }

    /// Совет, у которого обе стороны противопоставления совпадают: «используй май↗ вместо май↗».
    /// Ничему не учит и читается как поломка. Возникает, когда два тайских слова различаются
    /// только тоном — кириллицей они пишутся одинаково. Стрелки тут значимы: «май↘ вместо май↗»
    /// это нормальный совет, и его трогать нельзя.
    static func isDegenerateAdvice(_ text: String) -> Bool {
        var t = text.lowercased()
        guard !t.isEmpty else { return false }
        for phrase in ["нужно было", "а нужен", "а нужно", "а надо", "а не"] {
            t = t.replacingOccurrences(of: phrase, with: " вместо ")
        }
        let trim = CharacterSet(charactersIn: ".,;:!?«»\"'()[]")
        let tokens = t.split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: trim) }
            .filter { !$0.isEmpty }
        for (i, w) in tokens.enumerated() where w == "вместо" {
            guard i > 0, i + 1 < tokens.count else { continue }
            if tokens[i - 1] == tokens[i + 1] { return true }
        }
        return false
    }

    /// Зеркало серверного `_usable_coach`: сервер может быть развёрнут старой версии,
    /// а показывать пустой заголовок или совет «X вместо X» нельзя ни при каком раскладе.
    /// Пустой заголовок при живом пояснении не теряем — поднимаем первую фразу наверх.
    static func usableCoach(headline rawHeadline: String?, detail rawDetail: String?) -> (headline: String, detail: String?)? {
        var headline = withoutThaiScript(rawHeadline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var detail = withoutThaiScript(rawDetail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if isDegenerateAdvice(headline) { headline = "" }
        if isDegenerateAdvice(detail) { detail = "" }

        if headline.isEmpty {
            guard !detail.isEmpty else { return nil }
            let first = firstSentence(detail)
            headline = first
            detail = String(detail.dropFirst(first.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (headline, detail.isEmpty ? nil : detail)
    }

    private static func firstSentence(_ text: String) -> String {
        let terminators: Set<Character> = [".", "!", "?"]
        if let idx = text.firstIndex(where: { terminators.contains($0) }) {
            return String(text[...idx]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    /// Клиентское зеркало серверного инварианта: один gloss на слово фонетики, в том же порядке.
    /// Дотянутый разбор проверяем сами — доверять «пришло хоть что-то» здесь нельзя.
    static func partsMatchPhonetic(phonetic: String, parts: [SmartSpeakerPart]) -> Bool {
        let groups = phoneticWordGroups(phonetic)
        guard !groups.isEmpty, groups.count == parts.count else { return false }
        return zip(groups, parts).allSatisfy {
            normalizeTeachingKey($0.0) == normalizeTeachingKey($0.1.p)
        }
    }

    /// Разбор для произвольной фразы с проверкой выравнивания. Возвращает пустой массив,
    /// если чистого разбора не вышло: показывать полурассыпавшийся нельзя.
    func alignedPhraseParts(ru: String, thai: String, phonetic: String) async -> [SmartSpeakerPart] {
        let th = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        let ph = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !th.isEmpty, !ph.isEmpty else { return [] }
        guard let fetched = try? await smartSpeakerFetchPhraseParts(ru: ru, thai: th, phonetic: ph),
              !fetched.isEmpty else { return [] }
        var parts = Self.resolvedTeachingParts(api: fetched, phonetic: ph, thai: th, ru: ru)
        parts = Self.canonicalizeTrailingPolitenessGloss(parts)
        return Self.partsMatchPhonetic(phonetic: ph, parts: parts) ? parts : []
    }

    /// Drop leftover word-gloss from the previous phrase so the next one can load its own.
    private func clearPhrasePartsState() {
        phrasePartsFetchGeneration = UUID()
        heardPhraseParts = []
        phrasePartsRequestKey = nil
        phrasePartsInFlight = false
    }

    /// Сервер отдаёт разбор только когда тот сошёлся с фонетикой — иначе его нет вовсе.
    /// Дотягиваем тихо и отдельно: фраза уже на экране, разбор появляется следом.
    /// Не сошлось и со второй попытки — секции просто не будет, без объяснений и плашек.
    func refreshPhrasePartsIfNeeded() {
        let ru = (heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let thai = (heardThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phonetic = (heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thai.isEmpty, !phonetic.isEmpty else { return }

        let key = "\(thai)|\(phonetic)"
        if !heardPhraseParts.isEmpty {
            phrasePartsRequestKey = key
            return
        }
        if phrasePartsInFlight, phrasePartsRequestKey == key {
            return
        }

        phrasePartsRequestKey = key
        phrasePartsInFlight = true
        let generation = UUID()
        phrasePartsFetchGeneration = generation

        Task { [weak self] in
            guard let self else { return }
            var fetched: [SmartSpeakerPart] = []
            for attempt in 0..<2 {
                let got = try? await self.smartSpeakerFetchPhraseParts(ru: ru, thai: thai, phonetic: phonetic)
                if let got, !got.isEmpty {
                    fetched = got
                    break
                }
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
            await MainActor.run {
                guard self.phrasePartsFetchGeneration == generation else { return }
                self.phrasePartsInFlight = false
                // Пока ходили за разбором, фраза могла смениться — тогда он уже не к ней.
                let curThai = (self.heardThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let curPhonetic = (self.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard curThai == thai, curPhonetic == phonetic, self.heardPhraseParts.isEmpty else { return }
                guard !fetched.isEmpty else { return }

                var parts = Self.resolvedTeachingParts(api: fetched, phonetic: phonetic, thai: thai, ru: ru)
                parts = Self.canonicalizeTrailingPolitenessGloss(parts)
                guard Self.partsMatchPhonetic(phonetic: phonetic, parts: parts) else {
                    #if DEBUG
                    print("[speaker] phrase_parts: dropped, still not aligned with phonetic")
                    #endif
                    return
                }
                self.heardPhraseParts = parts
            }
        }
    }

    /// Space-separated pronunciation chunks after stripping tone arrows (arrows must not split syllables).
    static func phoneticWordGroups(_ phonetic: String) -> [String] {
        let arrows: Set<Character> = ["→", "↓", "↘", "↑", "↗", "↕", "↔"]
        var cleaned = phonetic.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        cleaned = cleaned.replacingOccurrences(of: "ɨ", with: "и")
        cleaned = cleaned.replacingOccurrences(of: "і", with: "и")
        // Remove arrows in-place — NOT with spaces (кхун↘ must stay кхун, not кху н).
        cleaned = String(cleaned.filter { !arrows.contains($0) })
        cleaned = cleaned
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
        while cleaned.contains("  ") { cleaned = cleaned.replacingOccurrences(of: "  ", with: " ") }
        return cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Чинит «тон на каждую букву» и приводит emoji-стрелки к текстовым.
    private static func sanitizeThaiPhonetic(
        _ phonetic: String,
        thai: String,
        repair: ((String) async -> String?)? = nil
    ) async -> String {
        var ph = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ph.isEmpty else { return ph }

        ph = Self.canonicalTeachingPhonetic(ph)

        guard Self.phoneticLooksOverFragmented(ph) else { return ph }

        let th = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        if !th.isEmpty, let repair {
            if let repaired = await repair(th) {
                let cleaned = repaired.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty, !Self.phoneticLooksOverFragmented(cleaned) {
                    #if DEBUG
                    print("[speaker] phonetic: repaired over-fragmented via thai_phonetic")
                    #endif
                    return cleaned
                }
            }
        }
        #if DEBUG
        print("[speaker] phonetic: compacting over-fragmented letter tones")
        #endif
        return Self.compactOverFragmentedPhonetic(ph)
    }

    /// Тон на почти каждую 1–2 буквы — баг ответа, не нормальная слоговая фонетика.
    private static func phoneticLooksOverFragmented(_ phonetic: String) -> Bool {
        let arrows: Set<Character> = ["→", "↓", "↘", "↑", "↗"]
        var segs: [String] = []
        var buf = ""
        for ch in phonetic {
            if arrows.contains(ch) {
                let syl = buf.trimmingCharacters(in: .whitespacesAndNewlines)
                if !syl.isEmpty { segs.append(syl) }
                buf = ""
            } else {
                buf.append(ch)
            }
        }
        let tail = buf.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { segs.append(tail) }
        guard segs.count >= 5 else { return false }

        func letters(_ s: String) -> Int {
            s.reduce(0) { n, ch in
                guard let v = ch.unicodeScalars.first?.value else { return n }
                let isCyr = (0x0400...0x04FF).contains(v) || v == 0x0451 || v == 0x0401
                return n + (isCyr ? 1 : 0)
            }
        }
        let lengths = segs.map(letters)
        let short = lengths.filter { $0 <= 2 }.count
        let avg = Double(lengths.reduce(0, +)) / Double(max(1, lengths.count))
        return avg <= 2.4 && Double(short) / Double(lengths.count) >= 0.5
    }

    private static func compactOverFragmentedPhonetic(_ phonetic: String) -> String {
        let arrows: Set<Character> = ["→", "↓", "↘", "↑", "↗"]
        let tokens = phonetic.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return tokens
            .map { String($0.filter { !arrows.contains($0) }) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func smartSpeakerHTTPError(code: Int, data: Data) -> NSError {
        let body = String(data: data, encoding: .utf8) ?? ""
        var detail = body
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let d = json["detail"] as? String {
                detail = d
            } else if let m = json["message"] as? String {
                detail = m
            }
        }
        if body.contains("Application not found") {
            detail = "railway_down"
        }
        return NSError(domain: "speaker.smart.http", code: code, userInfo: [
            NSLocalizedDescriptionKey: detail,
        ])
    }

    private struct ThaiPhoneticOnlyResponse: Decodable {
        let phonetic: String
    }

    /// Кириллическая фонетика по тайской строке (тот же сервер, что `smart_speaker`; эндпоинт `/thai_phonetic`).
    private func smartSpeakerPhoneticFromThai(thai: String) async throws -> String {
        let th = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !th.isEmpty else {
            throw NSError(domain: "speaker.smart", code: 2, userInfo: [NSLocalizedDescriptionKey: "empty thai"])
        }
        guard let base = Self.smartSpeakerBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !base.isEmpty else {
            throw NSError(domain: "speaker.smart", code: 1, userInfo: [NSLocalizedDescriptionKey: "API base URL missing"])
        }
        let urlString = base.hasSuffix("/") ? base + "thai_phonetic" : base + "/thai_phonetic"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "speaker.smart", code: 3, userInfo: [NSLocalizedDescriptionKey: "bad URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 25
        req.httpBody = try JSONSerialization.data(withJSONObject: ["text_th": th])
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code >= 200 && code < 300 else {
            throw NSError(domain: "speaker.smart.http", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
        }
        let decoded = try JSONDecoder().decode(ThaiPhoneticOnlyResponse.self, from: data)
        var out = decoded.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !out.isEmpty else {
            throw NSError(domain: "speaker.smart", code: 4, userInfo: [NSLocalizedDescriptionKey: "empty phonetic"])
        }
        out = await Self.sanitizeThaiPhonetic(out, thai: th, repair: nil)
        return out
    }

    private struct SemanticCoachResponse: Decodable {
        let headline: String
        let detail: String?
    }

    @MainActor
    func clearConversationCoach() {
        conversationCoachHeadline = nil
        conversationCoachDetail = nil
        conversationCoachInFlight = false
    }

    /// Одна конкретная правка по попытке (POST /semantic_coach). Ошибка сервиса — не ошибка экрана:
    /// молча остаёмся без строки, оценка и эталон уже всё показали.
    private func fetchConversationCoach(
        expectedThai: String,
        expectedRU: String,
        expectedPhonetic: String,
        heardThai: String,
        heardPhonetic: String,
        textScore: Int,
        toneScore: Int?,
        weakSyllables: [SyllableFeedback]
    ) async -> (headline: String, detail: String?)? {
        guard let base = Self.smartSpeakerBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !base.isEmpty else {
            return nil
        }
        let urlString = base.hasSuffix("/") ? base + "semantic_coach" : base + "/semantic_coach"
        guard let url = URL(string: urlString) else { return nil }

        var body: [String: Any] = [
            "expected_thai": expectedThai,
            "expected_ru": expectedRU,
            "expected_phonetic": expectedPhonetic,
            "heard_thai": heardThai,
            "heard_phonetic": heardPhonetic,
            "text_score": textScore,
        ]
        if let toneScore { body["tone_score"] = toneScore }
        let weak = weakSyllables
            .filter { $0.score < 70 }
            .prefix(6)
            .map { syl -> [String: Any] in
                var item: [String: Any] = ["syllable": syl.syllable, "score": syl.score]
                if let expected = syl.toneExpected { item["tone_expected"] = expected }
                if let actual = syl.toneActual { item["tone_actual"] = actual }
                return item
            }
        if !weak.isEmpty { body["weak_syllables"] = Array(weak) }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard code >= 200, code < 300 else {
                #if DEBUG
                print("[speaker] semantic_coach HTTP \(code)")
                #endif
                return nil
            }
            let decoded = try JSONDecoder().decode(SemanticCoachResponse.self, from: data)
            let headline = decoded.headline.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !headline.isEmpty else { return nil }
            let detail = decoded.detail?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (headline, (detail?.isEmpty ?? true) ? nil : detail)
        } catch {
            #if DEBUG
            print("[speaker] semantic_coach failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// After pronunciation feedback: wait a beat for tones, then one coach line. Failure stays silent.
    private func runSemanticCoachAfterPronunciation(
        expectedThai: String,
        expectedRU: String,
        expectedPhonetic: String,
        heardThai: String,
        textScore: Int,
        attemptToken: UUID?
    ) async {
        let heard = heardThai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty else {
            await MainActor.run { self.conversationCoachInFlight = false }
            return
        }
        for _ in 0..<6 {
            let waiting = await MainActor.run { self.breakdownRequestInFlight }
            if !waiting { break }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        let ctx = await MainActor.run {
            (
                heardPhonetic: self.speakerUIMode == .conversation
                    ? (self.conversationHeardPhoneticFromASR ?? "")
                    : (self.trainingHeardPhoneticFromASR ?? self.heardTranslit ?? ""),
                tone: self.toneAverageScore,
                weak: self.syllableFeedback
            )
        }
        let coach = await fetchConversationCoach(
            expectedThai: expectedThai,
            expectedRU: expectedRU,
            expectedPhonetic: expectedPhonetic,
            heardThai: heard,
            heardPhonetic: ctx.heardPhonetic,
            textScore: textScore,
            toneScore: ctx.tone,
            weakSyllables: ctx.weak
        )
        await MainActor.run {
            if let t = attemptToken, self.activeAttemptToken != nil, self.activeAttemptToken != t { return }
            guard self.phase.isFeedback else {
                self.conversationCoachInFlight = false
                return
            }
            if let coach, let usable = Self.usableCoach(headline: coach.headline, detail: coach.detail) {
                self.conversationCoachHeadline = usable.headline
                self.conversationCoachDetail = usable.detail
            } else {
                self.conversationCoachHeadline = nil
                self.conversationCoachDetail = nil
            }
            self.conversationCoachInFlight = false
        }
    }

    /// Совпадает с API: в phonetic — русский исходник по буквам или слогам (тво→я→пер→…), не чтение тайского.
    private static func phoneticLooksLikeRussianSpellout(ru: String, phonetic: String) -> Bool {
        let ruLetters = Self.cyrillicLettersJoined(Self.normalizeRuForCompare(ru))
        var phLetters = Self.cyrillicLettersJoined(phonetic)
        if ruLetters.count < 4 || phLetters.isEmpty { return false }
        for suffix in ["кхрап", "кха"] {
            while phLetters.hasSuffix(suffix) {
                phLetters = String(phLetters.dropLast(suffix.count))
            }
        }
        if phLetters == ruLetters { return true }
        if Double(phLetters.count) >= Double(ruLetters.count) * 0.92 {
            let r = Self.cyrillicSequenceSimilarity(ruLetters, phLetters)
            if r >= 0.82 { return true }
        }
        if Double(phLetters.count) < Double(ruLetters.count) * 0.75 { return false }
        var pIdx = phLetters.startIndex
        for rc in ruLetters {
            var found = false
            while pIdx < phLetters.endIndex {
                if phLetters[pIdx] == rc {
                    found = true
                    phLetters.formIndex(after: &pIdx)
                    break
                }
                phLetters.formIndex(after: &pIdx)
            }
            if !found { return false }
        }
        let tail = phLetters.distance(from: pIdx, to: phLetters.endIndex)
        let maxTail = max(12, ruLetters.count / 3)
        return tail <= maxTail
    }

    /// Collapse whitespace like API `_norm_ru` for letter comparison.
    private static func normalizeRuForCompare(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// ~difflib ratio via LCS: 2*lcs / (na+nb).
    private static func cyrillicSequenceSimilarity(_ a: String, _ b: String) -> Double {
        let ac = Array(a)
        let bc = Array(b)
        let na = ac.count
        let nb = bc.count
        if na == 0 && nb == 0 { return 1 }
        if na == 0 || nb == 0 { return 0 }
        var dp = [[Int]](repeating: [Int](repeating: 0, count: nb + 1), count: na + 1)
        for i in 1...na {
            for j in 1...nb {
                dp[i][j] = ac[i - 1] == bc[j - 1] ? dp[i - 1][j - 1] + 1 : max(dp[i - 1][j], dp[i][j - 1])
            }
        }
        let lcs = dp[na][nb]
        return 2.0 * Double(lcs) / Double(na + nb)
    }

    private static func cyrillicLettersJoined(_ s: String) -> String {
        var out = ""
        for ch in s.lowercased() {
            guard let v = ch.unicodeScalars.first?.value else { continue }
            if (0x0430...0x044F).contains(v) || v == 0x0451 {
                out.append(ch)
            }
        }
        return out
    }

    /// Offline seed for first-entry / demo practice (no network translate).
    func seedConversationPracticePhrase(thai: String, phonetic: String, ru: String) {
        guard speakerUIMode == .conversation else { return }
        let t = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if phase == .recording { return }

        heardRU = ru.trimmingCharacters(in: .whitespacesAndNewlines)
        heardThai = t
        let ph = Self.teachingPhoneticOrNil(phonetic)
        heardTranslit = ph
        conversationExpectedThai = t
        conversationExpectedTranslitForFeedback = ph
        conversationHeardThaiASR = nil
        conversationHeardPhoneticFromASR = nil
        taikaHints = []

        if phase == .analyzing || phase == .analyzingTranslation || phase == .hint {
            setPhase(.idle)
        }
    }

    /// Conversation mode: start recording Thai for "Повторить и проверить". Saves current translation as expected.
    @discardableResult
    func startConversationPronunciationCheck() -> Bool {
        guard speakerUIMode == .conversation else { return false }
        cancelScheduledConversationListening()
        pendingConversationAutoRecord = false
        let fromHeard = heardThai?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fromExpected = conversationExpectedThai?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let thai = !fromHeard.isEmpty ? fromHeard : fromExpected
        let translitFromHeard = Self.teachingPhoneticOrNil(heardTranslit) ?? ""
        let translitFromExpected = Self.teachingPhoneticOrNil(conversationExpectedTranslitForFeedback) ?? ""
        let translit = !translitFromHeard.isEmpty ? translitFromHeard : translitFromExpected
        guard !thai.isEmpty else { return false }

        if phase == .recording { return true }
        if phase == .analyzing || phase == .analyzingTranslation { return false }

        heardThai = thai
        if !translit.isEmpty { heardTranslit = translit }
        conversationExpectedThai = thai
        conversationExpectedTranslitForFeedback = translit.isEmpty ? nil : translit
        conversationHeardThaiASR = nil
        conversationHeardPhoneticFromASR = nil
        clearConversationCoach()

        attemptPlayer?.stop()
        attemptPlayer = nil
        lastPlayed = .none
        lastAttemptURL = nil
        lastAttempt = nil
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        recordingMeter = 0
        taikaHints = []
        clearToneBreakdownState()

        let token = UUID()
        activeAttemptToken = token

        let beginCapture: () -> Void = { [weak self] in
            guard let self else { return }
            guard self.activeAttemptToken == token else { return }
            self.setPhase(.recording)
            self.startMeter()
            self.recorder.startAuthorized { [weak self] (url: URL?) in
                guard let self else { return }
                guard self.activeAttemptToken == token else { return }
                if let url {
                    self.lastAttemptURL = url
                    self.lastAttempt = url
                }
            }
        }

        // Never enter .recording while the system permission sheet is up.
        if recorder.hasMicrophoneAccess {
            beginCapture()
        } else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let ok = await self.recorder.requestMicrophoneAccess()
                guard self.activeAttemptToken == token else { return }
                guard ok else {
                    self.activeAttemptToken = nil
                    self.taikaHints = ["нужен доступ к микрофону"]
                    self.setPhase(.hint)
                    return
                }
                beginCapture()
            }
        }
        return true
    }

    /// Conversation mode: stop recording and run Thai ASR → compare with conversationExpectedThai → feedback.
    func stopConversationPronunciationCheck() {
        guard phase == .recording, let expectedThai = conversationExpectedThai else { return }

        let token = activeAttemptToken
        activeAttemptToken = nil

        let url = recorder.stop()
        stopMeter()
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        recordingMeter = 0
        lastAttemptURL = url
        lastAttempt = url
        lastPlayed = .none

        guard let url else {
            taikaHints = ["не получилось записать. проверь доступ к микрофону"]
            setPhase(.hint)
            return
        }

        setPhase(.analyzing)
        analyzingStartedAt = Date()
        taikaHints = ["слушаю…"]

        Task { [weak self] in
            guard let self else { return }
            do {
                let spokenRaw = try await self.withTimeout(seconds: 15) {
                    try await self.recognizeThai(url: url)
                }
                let spoken = spokenRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                let similarityScore = self.similarity(a: spoken, b: expectedThai)
                let score = Int((similarityScore * 100.0).rounded())
                let hint = self.feedbackHint(for: score)

                // Сразу feedback с тайским ASR — кириллицу догружаем фоном (не блокируем UI).
                await MainActor.run {
                    if let t = token, self.activeAttemptToken != nil && self.activeAttemptToken != t { return }

                    self.conversationHeardThaiASR = spoken.isEmpty ? nil : spoken
                    self.conversationHeardPhoneticFromASR = nil
                    self.clearConversationCoach()
                    self.conversationCoachInFlight = !spoken.isEmpty
                    self.heardConfidence = score
                    self.taikaHints = ["оценка: \(score)", hint]

                    let result = PronunciationResult(
                        totalScore: score,
                        accuracy: score,
                        fluency: score,
                        completeness: score,
                        hint: hint
                    )
                    self.setPhase(.feedback(result: result))
                }

                if !spoken.isEmpty {
                    var userPhonetic: String?
                    for attempt in 0..<2 {
                        do {
                            userPhonetic = try await self.smartSpeakerPhoneticFromThai(thai: spoken)
                            break
                        } catch {
                            #if DEBUG
                            print("[speaker] thai_phonetic (attempt \(attempt + 1)): \(error.localizedDescription)")
                            #endif
                            if attempt == 0 {
                                try? await Task.sleep(nanoseconds: 450_000_000)
                            }
                        }
                    }
                    if let ph = userPhonetic?.trimmingCharacters(in: .whitespacesAndNewlines), !ph.isEmpty {
                        await MainActor.run {
                            self.conversationHeardPhoneticFromASR = Self.teachingPhoneticOrNil(ph)
                        }
                    }

                    let ru = await MainActor.run { self.heardRU ?? "" }
                    let phonetic = await MainActor.run { self.conversationExpectedTranslitForFeedback ?? "" }
                    await self.runSemanticCoachAfterPronunciation(
                        expectedThai: expectedThai,
                        expectedRU: ru,
                        expectedPhonetic: phonetic,
                        heardThai: spoken,
                        textScore: score,
                        attemptToken: token
                    )
                }
            } catch {
                await MainActor.run {
                    if let t = token, self.activeAttemptToken != nil && self.activeAttemptToken != t { return }
                    self.taikaHints = ["не удалось распознать. попробуй ещё раз"]
                    self.setPhase(.hint)
                    self.conversationHeardThaiASR = nil
                    self.conversationHeardPhoneticFromASR = nil
                    self.clearConversationCoach()
                    // Keep expectedThai: retry must stay on this phrase, not start a free listen.
                }
            }
        }
    }

    /// Оценка тайской записи против эталона (как сравнение в режиме диалога), без требования `speakerUIMode == .conversation`.
    @MainActor
    func scoreRecordedThaiUtterance(at url: URL, expectedThai: String) async -> (score: Int, spoken: String) {
        let expected = expectedThai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expected.isEmpty else { return (0, "") }
        do {
            let spokenRaw = try await withTimeout(seconds: 15) {
                try await self.recognizeThai(url: url)
            }
            let spoken = spokenRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            let similarityScore = self.similarity(a: spoken, b: expected)
            let score = Int((similarityScore * 100.0).rounded())
            return (max(0, min(100, score)), spoken)
        } catch {
            return (0, "")
        }
    }

    struct GrandDialogueEvaluation {
        let spoken: String
        let matchedThai: String
        let textScore: Int
        let advancedScore: Int?
        let finalScore: Int
        let hint: String
    }

    /// Unified evaluator for Grand Dialogue:
    /// - Free users: ASR text similarity score
    /// - Pro users: blend text similarity with advanced tone/hybrid score (when backend is available)
    @MainActor
    func evaluateGrandDialogueUtterance(
        at url: URL,
        expectedThai: String,
        expectedPhonetic: String?,
        isProUser: Bool
    ) async -> GrandDialogueEvaluation {
        let base = await scoreRecordedThaiUtterance(at: url, expectedThai: expectedThai)
        let textScore = max(0, min(100, base.score))

        var advanced: Int? = nil
        if isProUser {
            advanced = await fetchGrandDialogueAdvancedScore(
                audioURL: url,
                expectedThai: expectedThai,
                expectedPhonetic: expectedPhonetic
            )
        }

        let finalScore: Int = {
            guard let advanced else { return textScore }
            // Pro: combine lexical match + tone/hybrid quality.
            let mixed = (Double(textScore) * 0.65) + (Double(advanced) * 0.35)
            return max(0, min(100, Int(mixed.rounded())))
        }()

        let hint: String = {
            switch finalScore {
            case 90...100: return "очень естественно — звучит уверенно"
            case 75...89: return isProUser ? "хорошо. подтяни тоны и ритм для идеала" : "хорошо. звучит уверенно"
            case 55...74: return "понятно по смыслу, но нужно чище произнести"
            default: return "смысл теряется — попробуй короче и медленнее"
            }
        }()

        return GrandDialogueEvaluation(
            spoken: base.spoken,
            matchedThai: expectedThai,
            textScore: textScore,
            advancedScore: advanced,
            finalScore: finalScore,
            hint: hint
        )
    }

    struct GrandDialogueExpectedCandidate {
        let thai: String
        let phonetic: String?
    }

    /// Evaluate a spoken answer against a set of valid Thai replies, picking the best lexical match.
    /// This keeps course dialogue predictable while allowing reply variability.
    @MainActor
    func evaluateGrandDialogueUtterance(
        at url: URL,
        candidates: [GrandDialogueExpectedCandidate],
        isProUser: Bool
    ) async -> GrandDialogueEvaluation {
        let cleaned: [GrandDialogueExpectedCandidate] = candidates.compactMap { c in
            let thai = c.thai.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !thai.isEmpty else { return nil }
            let phon = c.phonetic?.trimmingCharacters(in: .whitespacesAndNewlines)
            return GrandDialogueExpectedCandidate(thai: thai, phonetic: (phon?.isEmpty == false ? phon : nil))
        }
        guard !cleaned.isEmpty else {
            return GrandDialogueEvaluation(
                spoken: "",
                matchedThai: "",
                textScore: 0,
                advancedScore: nil,
                finalScore: 0,
                hint: "нет эталонных ответов для сравнения"
            )
        }

        let spoken: String
        do {
            let out = try await withTimeout(seconds: 15) {
                try await self.recognizeThai(url: url)
            }
            spoken = out.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            spoken = ""
        }

        guard !spoken.isEmpty else {
            return GrandDialogueEvaluation(
                spoken: "",
                matchedThai: cleaned[0].thai,
                textScore: 0,
                advancedScore: nil,
                finalScore: 0,
                hint: "не удалось распознать ответ"
            )
        }

        var best = cleaned[0]
        var bestSimilarity = similarity(a: spoken, b: cleaned[0].thai)
        if cleaned.count > 1 {
            for candidate in cleaned.dropFirst() {
                let s = similarity(a: spoken, b: candidate.thai)
                if s > bestSimilarity {
                    bestSimilarity = s
                    best = candidate
                }
            }
        }
        let textScore = max(0, min(100, Int((bestSimilarity * 100.0).rounded())))

        var advanced: Int? = nil
        if isProUser {
            advanced = await fetchGrandDialogueAdvancedScore(
                audioURL: url,
                expectedThai: best.thai,
                expectedPhonetic: best.phonetic
            )
        }

        let finalScore: Int = {
            guard let advanced else { return textScore }
            let mixed = (Double(textScore) * 0.65) + (Double(advanced) * 0.35)
            return max(0, min(100, Int(mixed.rounded())))
        }()

        let hint: String = {
            switch finalScore {
            case 90...100: return "отлично"
            case 75...89: return "хорошо"
            case 55...74: return "почти"
            default: return "попробуй еще раз"
            }
        }()

        return GrandDialogueEvaluation(
            spoken: spoken,
            matchedThai: best.thai,
            textScore: textScore,
            advancedScore: advanced,
            finalScore: finalScore,
            hint: hint
        )
    }

    /// Convert Thai ASR text into app-style phonetic for dialogue bubbles.
    /// Returns nil when backend transliteration is unavailable.
    @MainActor
    func transliterateThaiForDialogue(thai: String) async -> String? {
        let trimmed = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            let out = try await smartSpeakerPhoneticFromThai(thai: trimmed)
            let normalized = out.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return nil }
            // Defensive guard: if API returns Thai script instead of phonetic, don't show it in user bubble.
            if containsThaiScript(normalized) { return nil }
            return normalized
        } catch {
            return nil
        }
    }

    private func containsThaiScript(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x0E00 && scalar.value <= 0x0E7F {
                return true
            }
        }
        return false
    }

    private func fetchGrandDialogueAdvancedScore(
        audioURL: URL,
        expectedThai: String,
        expectedPhonetic: String?
    ) async -> Int? {
        let thaiText = expectedThai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thaiText.isEmpty else { return nil }
        guard let base = Self.toneAssessmentBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !base.isEmpty else { return nil }
        guard FileManager.default.fileExists(atPath: audioURL.path) else { return nil }

        guard let requestURL = URL(string: base.hasSuffix("/") ? base + "assess" : base + "/assess") else {
            return nil
        }

        var req = URLRequest(url: requestURL)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"text\"\r\n\r\n")
        append(thaiText)
        append("\r\n")

        let phon = expectedPhonetic?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let expectedTones = Self.expectedTonesFromPhonetic(phon), !expectedTones.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"expected_tones\"\r\n\r\n")
            append(expectedTones)
            append("\r\n")
        }
        if !phon.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"phonetic\"\r\n\r\n")
            append(Self.canonicalTeachingPhonetic(phon))
            append("\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        do {
            body.append(try Data(contentsOf: audioURL))
        } catch {
            return nil
        }
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = body
        req.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard status >= 200, status < 300 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            if let hybrid = json["hybrid_score"] as? Int { return max(0, min(100, hybrid)) }
            if let hybrid = json["hybrid_score"] as? Double { return max(0, min(100, Int(hybrid.rounded()))) }
            if let total = json["total_score"] as? Int { return max(0, min(100, total)) }
            if let total = json["total_score"] as? Double { return max(0, min(100, Int(total.rounded()))) }
            return nil
        } catch {
            return nil
        }
    }

    /// ASR Russian (SFSpeechRecognizer ru-RU).
    /// Важно: Apple часто присылает error после final — нельзя сразу abort'ить; пустой RU не должен уходить в translate.
    private func recognizeRussian(url: URL) async throws -> String {
        let auth = SFSpeechRecognizer.authorizationStatus()
        if auth == .notDetermined {
            let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
            }
            if !granted { throw NSError(domain: "speaker.asr", code: 1) }
        } else if auth != .authorized {
            throw NSError(domain: "speaker.asr", code: 2)
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU")) else {
            throw NSError(domain: "speaker.asr", code: 3)
        }
        if !recognizer.isAvailable { throw NSError(domain: "speaker.asr", code: 4) }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = false
        }

        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
            var resumed = false
            var best = ""
            var task: SFSpeechRecognitionTask?

            func finish(returning s: String) {
                guard !resumed else { return }
                resumed = true
                task?.cancel()
                c.resume(returning: s)
            }
            func finish(throwing e: Error) {
                guard !resumed else { return }
                resumed = true
                task?.cancel()
                c.resume(throwing: e)
            }

            task = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        best = text
                    }
                    if result.isFinal {
                        finish(returning: best)
                        return
                    }
                }
                if let error {
                    // Частый кейс SFSpeech: final уже есть, следом прилетает error — не затираем успех.
                    if !best.isEmpty {
                        finish(returning: best)
                    } else {
                        finish(throwing: error)
                    }
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                // Не кидаем timeout-ошибку поверх уже пойманного текста.
                finish(returning: best)
            }
        }
    }

    /// Stub: ru → th. Replace with real translation API.
    private static func translateRuToThStub(_ ru: String) -> String {
        guard !ru.isEmpty else { return "" }
        // Mock: return placeholder until API wired
        let lower = ru.lowercased()
        if lower.contains("привет") || lower.contains("здравствуй") { return "สวัสดี" }
        if lower.contains("как дела") || lower.contains("как ты") { return "สบายดีไหม" }
        if lower.contains("спасибо") { return "ขอบคุณ" }
        return "—" // no match
    }

    /// Stub: thai text → Cyrillic phonetic. Replace with real translit/lexicon.
    private static func translitThToPhoneticStub(_ th: String) -> String {
        guard !th.isEmpty, th != "—" else { return "" }
        if th == "สวัสดี" { return "са-ва-ди́" }
        if th == "สบายดีไหม" { return "са-бай дии-май" }
        if th == "ขอบคุณ" { return "ко̀п-кун" }
        return th
    }

    // MARK: - reference audio (mvp: tts)

    /// TTS эталона для разбора в умном спикере: фраза перевода, не карточка из очереди тренажёра.
    @discardableResult
    func playReferenceConversationExpectedIfNeeded() -> Bool {
        guard speakerUIMode == .conversation,
              let conv = conversationExpectedThai?.trimmingCharacters(in: .whitespacesAndNewlines),
              !conv.isEmpty
        else { return false }
        playReferenceThai(conv)
        return true
    }

    private func playReferenceThai(_ thai: String) {
        let t = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        stopPlaybackProgressTimer()
        attemptPlaybackProgress = 1.0
        referencePlaybackProgress = 0
        lastPlayed = .reference
        StepAudio.shared.speakThai(t) { [weak self] progress in
            DispatchQueue.main.async {
                self?.referencePlaybackProgress = progress
                if progress >= 1.0 {
                    self?.referencePlaybackProgress = 1.0
                }
            }
        }
    }

    func playReference() {
        if playReferenceConversationExpectedIfNeeded() { return }
        guard let cur = current else { return }
        playReference(resolved: cur)
    }

    func playReference(for id: UUID) {
        guard !queue.isEmpty else { return }
        if let match = queue.first(where: { resolveId($0) == id }) {
            // keep UI context in sync with what is being played
            current = match
            // t1: keep "current lesson" source-of-truth in sync
            session.markActive(courseId: match.courseId, lessonId: match.lessonId, stepIndex: match.index)
            playReference(resolved: match)
        } else {
            return
        }
    }

    /// Сбросить прогресс прорисовки эталонного графика (при открытии разбора — показывать линию целиком).
    func resetReferenceProgress() {
        stopPlaybackProgressTimer()
        referencePlaybackProgress = 1.0
        attemptPlaybackProgress = 1.0
    }

    private func stopPlaybackProgressTimer() {
        playbackProgressTimer?.invalidate()
        playbackProgressTimer = nil
    }

    private func trackAttemptPlaybackProgress(segmentStart: Double, segmentDuration: TimeInterval) {
        stopPlaybackProgressTimer()
        referencePlaybackProgress = 1.0
        attemptPlaybackProgress = 0
        let duration = max(0.05, segmentDuration)
        playbackProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard let player = self.attemptPlayer, player.isPlaying else {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.attemptPlaybackProgress = 1.0
                }
                return
            }
            let relative = player.currentTime - segmentStart
            let progress = min(1.0, max(0.0, relative / duration))
            DispatchQueue.main.async {
                self.attemptPlaybackProgress = progress
            }
        }
    }

    private func playReference(resolved r: StepData.SpeakerResolved) {
        let thai = r.face.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thai.isEmpty else { return }
        playReferenceThai(thai)
    }

    /// TTS эталонного слога (Thai из ответа /assess), не всей фразы.
    func playReferenceSyllable(at index: Int) {
        guard syllableFeedback.indices.contains(index) else {
            playReference()
            return
        }
        let raw = syllableFeedback[index].syllable.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            playReference()
            return
        }
        playReferenceThai(raw)
    }

    func playAttempt() {
        playAttemptSegment(start: nil, end: nil)
    }

    private func playAttemptSegment(start: Double?, end: Double?) {
        guard let url = lastAttempt else { return }
        syllablePlaybackStopWork?.cancel()
        syllablePlaybackStopWork = nil
        stopPlaybackProgressTimer()
        do {
            attemptPlayer?.stop()
            attemptPlayer = try AVAudioPlayer(contentsOf: url)
            attemptPlayer?.prepareToPlay()
            let segmentStart = start ?? 0
            if segmentStart >= 0 {
                attemptPlayer?.currentTime = segmentStart
            }
            attemptPlayer?.play()
            lastPlayed = .attempt
            let segmentDuration: TimeInterval = {
                if let start, let end, end > start { return end - start }
                return attemptPlayer?.duration ?? 1
            }()
            trackAttemptPlaybackProgress(segmentStart: segmentStart, segmentDuration: segmentDuration)
            if let start, let end, end > start {
                let work = DispatchWorkItem { [weak self] in
                    self?.attemptPlayer?.stop()
                    self?.stopPlaybackProgressTimer()
                    self?.attemptPlaybackProgress = 1.0
                }
                syllablePlaybackStopWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + (end - start), execute: work)
            } else if let player = attemptPlayer {
                DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.05) { [weak self] in
                    self?.stopPlaybackProgressTimer()
                    self?.attemptPlaybackProgress = 1.0
                }
            }
        } catch {
            taikaHints = ["не получилось воспроизвести запись"]
            setPhase(.hint)
        }
    }
    
    // MARK: - text input (mvp)

    func submitText(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        // reset any recording ui
        stopMeter()
        recordingPartialThai = nil
        recordingMeter = 0
        lastAttemptURL = nil
        lastAttempt = nil
        lastPlayed = .none

        heardThai = t
        heardTranslit = t
        heardRU = nil
        heardConfidence = 0

        setPhase(.hint)

        if let cur = current {
            heardRU = cur.face.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
            taikaHints = [
                "сравни себя с эталоном",
                "для free: эталон → ты → повтор"
            ]

            session.logActivity(
                .speakerAttemptCompleted,
                courseId: cur.courseId,
                lessonId: cur.lessonId,
                stepIndex: cur.index,
                refId: "free_text:\(cur.courseId):\(cur.lessonId):idx\(cur.index):len\(t.count)"
            )
        } else {
            heardRU = ""
            taikaHints = ["выбери фразу сверху или включи random"]
        }
    }
    // MARK: - attempt (mvp: mock)

    func startAttempt() {
        guard let cur = current else { return }

        // prevent re-entry while recording/analyzing
        if phase == .recording || phase == .analyzing || phase == .analyzingTranslation {
            return
        }

        SpeakerDailyAttemptsStore.shared.refreshDayIfNeeded()
        guard SpeakerDailyAttemptsStore.shared.canRecord else {
            taikaHints = ["лимит попыток на сегодня исчерпан", "на Taika+ — безлимит практики"]
            setPhase(.hint)
            return
        }

        attemptPlayer?.stop()
        attemptPlayer = nil
        lastPlayed = .none

        // reset attempt UI
        lastAttemptURL = nil
        lastAttempt = nil
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        recordingMeter = 0

        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        clearTrainingASRResult()
        heardConfidence = 0
        taikaHints = []
        clearToneBreakdownState()
        clearConversationCoach()

        let token = UUID()
        activeAttemptToken = token

        let beginCapture: () -> Void = { [weak self] in
            guard let self else { return }
            guard self.activeAttemptToken == token else { return }
            self.setPhase(.recording)
            self.startMeter()
            self.recorder.startAuthorized { [weak self] (url: URL?) in
                guard let self else { return }
                guard self.activeAttemptToken == token else { return }

                guard let url else {
                    self.stopMeter()
                    self.recordingPartialThai = nil
                    self.recordingMeter = 0
                    self.taikaHints = ["не получилось начать запись. проверь доступ к микрофону"]
                    self.setPhase(.hint)
                    self.activeAttemptToken = nil
                    return
                }

                self.lastAttemptURL = url
                self.lastAttempt = url
                self.session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
            }
        }

        if recorder.hasMicrophoneAccess {
            beginCapture()
        } else {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let ok = await self.recorder.requestMicrophoneAccess()
                guard self.activeAttemptToken == token else { return }
                guard ok else {
                    self.activeAttemptToken = nil
                    self.taikaHints = ["нужен доступ к микрофону"]
                    self.setPhase(.hint)
                    return
                }
                beginCapture()
            }
        }
    }

    func stopAttemptAndAnalyze() {
        guard let cur = current else { return }

        // only stop if we are recording; otherwise do nothing (no state corruption)
        guard phase == .recording else { return }

        // lock token for this attempt (so any late start completion can't override post-stop state)
        let token = activeAttemptToken
        activeAttemptToken = nil

        let url = recorder.stop()

        stopMeter()
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        recordingMeter = 0

        lastAttemptURL = url
        lastAttempt = url
        lastPlayed = .none

        guard let url else {
            taikaHints = ["не получилось записать. проверь доступ к микрофону"]
            setPhase(.hint)
            return
        }

        attemptCount += 1

        // Use original file URL first (same as before; copy was added later and may cause 1107 on some devices).
        // analyze via on-device/cloud speech (v0) to get a text hypothesis
        setPhase(.analyzing)
        analyzingStartedAt = Date()
        taikaHints = ["слушаю…"]

        let expectedThai = cur.face.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { [weak self] in
            guard let self else { return }
            var didTryServerAssess = false

            do {
                // Optional: external pronunciation assessor (e.g. Azure) — takes precedence when configured.
                if SpeakerAPI.shared.isConfigured {
                    do {
                        let api = try await SpeakerAPI.shared.assess(audioURL: url, expectedThai: expectedThai)
                        let safeScore = max(0, min(100, Int(api.score.rounded())))
                        let expectedPhonetic = cur.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
                        let formattedPhonetic = self.formattedSyllables(from: expectedPhonetic)
                        await MainActor.run {
                            self.heardThai = formattedPhonetic.isEmpty ? (api.heardThai.map { self.formattedSyllables(from: $0) } ?? formattedPhonetic) : formattedPhonetic
                            self.heardTranslit = Self.teachingPhoneticOrNil(api.heardTranslit ?? api.heardThai)
                            self.heardRU = nil
                            self.heardConfidence = safeScore
                            self.registerSessionScore(safeScore)
                            let lines = api.feedback.isEmpty ? ["оценка: \(safeScore)"] : api.feedback
                            self.taikaHints = lines
                            // Structured syllable rows stay on server/tone pipeline; API issues are for future UI chips.
                            self.syllableFeedback = []
                            let result = PronunciationResult(
                                totalScore: safeScore,
                                accuracy: safeScore,
                                fluency: safeScore,
                                completeness: safeScore,
                                hint: lines.last ?? "оценка"
                            )
                            self.setPhase(.feedback(result: result))
                            self.saveAttemptResult(
                                courseId: cur.courseId,
                                lessonId: cur.lessonId,
                                stepIndex: cur.index,
                                heardThai: self.heardThai,
                                heardTranslit: self.heardTranslit,
                                heardConfidence: safeScore,
                                attemptCount: self.attemptCount,
                                lastAttemptURL: url
                            )
                        }
                        return
                    } catch {
                        #if DEBUG
                        print("[speaker] SpeakerAPI.assess failed, falling back: \(error.localizedDescription)")
                        #endif
                    }
                }

                let expectedPhonetic = cur.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
                // Server-first ONLY when Apple ASR is known degraded — not on every attempt
                // just because /assess URL exists (that spammed silent/failed takes with POST /assess).
                let asrDegraded = await MainActor.run(body: { self.isASRTemporarilyDegraded })
                if asrDegraded {
                    didTryServerAssess = true
                    if let serverScore = await self.fetchGrandDialogueAdvancedScore(
                        audioURL: url,
                        expectedThai: expectedThai,
                        expectedPhonetic: expectedPhonetic.isEmpty ? nil : expectedPhonetic
                    ) {
                        await MainActor.run {
                            let safeScore = max(0, min(100, serverScore))
                            let formattedPhonetic = self.formattedSyllables(from: expectedPhonetic)
                            self.heardThai = formattedPhonetic
                            self.heardTranslit = Self.teachingPhoneticOrNil(formattedPhonetic)
                            self.heardRU = nil
                            self.heardConfidence = safeScore
                            self.registerSessionScore(safeScore)
                            self.taikaHints = [
                                "ASR нестабилен — использован серверный разбор записи",
                                "оценка: \(safeScore)"
                            ]
                            let result = PronunciationResult(
                                totalScore: safeScore,
                                accuracy: safeScore,
                                fluency: safeScore,
                                completeness: safeScore,
                                hint: "оценка по записи и тону"
                            )
                            self.setPhase(.feedback(result: result))
                            self.saveAttemptResult(
                                courseId: cur.courseId,
                                lessonId: cur.lessonId,
                                stepIndex: cur.index,
                                heardThai: self.heardThai,
                                heardTranslit: self.heardTranslit,
                                heardConfidence: safeScore,
                                attemptCount: self.attemptCount,
                                lastAttemptURL: url
                            )
                        }
                        return
                    }
                }
                // Keep timeout aligned with internal retry windows.
                // Too small global timeout cancels recognition mid-retry and produces cascaded 1107/1101.
                let spokenRaw = try await self.withTimeout(seconds: 15) {
                    try await self.recognizeThai(url: url)
                }

                // if card changed while analyzing, still show result but keep it tied to current data
                let spoken = spokenRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                if spoken.isEmpty {
                    await MainActor.run {
                        self.taikaHints = [
                            "не удалось распознать речь",
                            "попробуйте ещё раз, говорите чуть медленнее и ближе к микрофону"
                        ]
                        self.heardThai = nil
                        self.heardTranslit = nil
                        self.heardRU = nil
                        // Do not punish with score=0 on ASR empty result.
                        // Keep user in retry flow.
                        self.setPhase(.hint)
                    }
                    return
                }
                let formattedSpoken = self.formattedSyllables(from: spoken)

                let similarityScore = self.similarity(a: spoken, b: expectedThai)
                let score = Int((similarityScore * 100.0).rounded())

                let hint = self.feedbackHint(for: score)

                await MainActor.run {
                    // ignore if a new attempt started after this stop (token mismatch)
                    if let t = token, self.activeAttemptToken != nil && self.activeAttemptToken != t {
                        return
                    }

                    // Сравнение и score — по распознанному тайскому (spoken vs expectedThai, Levenshtein).
                    let phonetic = cur.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
                    let formattedPhonetic = self.formattedSyllables(from: phonetic)
                    self.trainingHeardThaiASR = spoken
                    self.trainingHeardPhoneticFromASR = nil
                    self.heardThai = formattedPhonetic.isEmpty ? nil : formattedPhonetic
                    self.heardTranslit = Self.teachingPhoneticOrNil(formattedSpoken)
                    self.heardRU = nil
                    self.clearToneBreakdownState()

                    self.heardConfidence = score
                    self.registerSessionScore(score)

                    self.taikaHints = [
                        cur.face.titleRU.isEmpty ? "оценка: \(score)" : "фраза: \(cur.face.titleRU)",
                        "оценка: \(score)",
                        hint
                    ]

                    let result = PronunciationResult(
                        totalScore: score,
                        accuracy: score,
                        fluency: score,
                        completeness: score,
                        hint: hint
                    )

                    self.setPhase(.feedback(result: result))

                    self.saveAttemptResult(
                        courseId: cur.courseId,
                        lessonId: cur.lessonId,
                        stepIndex: cur.index,
                        heardThai: formattedPhonetic.isEmpty ? nil : formattedPhonetic,
                        heardTranslit: Self.teachingPhoneticOrNil(formattedSpoken),
                        heardThaiASR: spoken,
                        heardPhoneticFromASR: nil,
                        heardConfidence: score,
                        attemptCount: self.attemptCount,
                        lastAttemptURL: url
                    )
                    self.refreshUserPhoneticFromASRIfNeeded()
                    self.clearASRDegradedIfNeeded()
                    self.clearConversationCoach()
                    self.conversationCoachInFlight = !spoken.isEmpty

                    let attemptId = url.lastPathComponent
                    self.session.logActivity(
                        .speakerAttemptCompleted,
                        courseId: cur.courseId,
                        lessonId: cur.lessonId,
                        stepIndex: cur.index,
                        refId: "free_asr:\(cur.courseId):\(cur.lessonId):idx\(cur.index):\(attemptId):try\(self.attemptCount):score\(score)"
                    )
                }

                if !spoken.isEmpty {
                    for _ in 0..<8 {
                        let ready = await MainActor.run {
                            !(self.trainingHeardPhoneticFromASR ?? "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                        }
                        if ready { break }
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                    await self.runSemanticCoachAfterPronunciation(
                        expectedThai: expectedThai,
                        expectedRU: cur.face.titleRU,
                        expectedPhonetic: cur.face.phonetic,
                        heardThai: spoken,
                        textScore: score,
                        attemptToken: token
                    )
                }
            } catch {
                let ns = error as NSError
                #if DEBUG
                print("[speaker] recognize failed: domain=\(ns.domain) code=\(ns.code) \(ns.localizedDescription)")
                #endif
                let isRetryableASR = (ns.code == 1107 || ns.code == 1101 || ns.domain == "speaker.timeout")
                if isRetryableASR {
                    await MainActor.run {
                        self.markASRDegradedNow()
                    }
                }
                var fallbackScore: Int? = nil
                // One /assess max per attempt — never pile a second upload after prefer-server already ran.
                if isRetryableASR, !didTryServerAssess {
                    let expectedPhonetic = cur.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
                    fallbackScore = await self.fetchGrandDialogueAdvancedScore(
                        audioURL: url,
                        expectedThai: expectedThai,
                        expectedPhonetic: expectedPhonetic.isEmpty ? nil : expectedPhonetic
                    )
                }
                await MainActor.run {
                    if let fallback = fallbackScore {
                        let safeScore = max(0, min(100, fallback))
                        let phonetic = cur.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
                        let formattedPhonetic = self.formattedSyllables(from: phonetic)
                        self.heardThai = formattedPhonetic
                        self.heardTranslit = Self.teachingPhoneticOrNil(formattedPhonetic)
                        self.heardRU = nil
                        self.heardConfidence = safeScore
                        self.registerSessionScore(safeScore)
                        self.taikaHints = [
                            "ASR нестабилен — использован серверный разбор записи",
                            "оценка: \(safeScore)"
                        ]
                        let result = PronunciationResult(
                            totalScore: safeScore,
                            accuracy: safeScore,
                            fluency: safeScore,
                            completeness: safeScore,
                            hint: "оценка по записи и тону"
                        )
                        self.setPhase(.feedback(result: result))
                        self.saveAttemptResult(
                            courseId: cur.courseId,
                            lessonId: cur.lessonId,
                            stepIndex: cur.index,
                            heardThai: self.heardThai,
                            heardTranslit: self.heardTranslit,
                            heardConfidence: safeScore,
                            attemptCount: self.attemptCount,
                            lastAttemptURL: url
                        )
                        return
                    }
                    let is1107 = (ns.code == 1107 || ns.code == 1101)
                    let hint: String
                    if ns.domain == "speaker.timeout" {
                        hint = "таймаут распознавания"
                        self.taikaHints = [hint]
                    } else if is1107 {
                        hint = "не получилось распознать речь"
                        self.taikaHints = [
                            hint,
                            "Настройки → Основные → Клавиатура: включите «Диктовка» и загрузите «Тайский».",
                            "Запись сохранена — можно послушать."
                        ]
                    } else {
                        hint = "не получилось распознать речь"
                        self.taikaHints = [hint]
                    }
                    self.heardThai = nil
                    self.heardTranslit = nil
                    self.heardRU = nil
                    // Keep retry-friendly state on ASR failure instead of producing feedback 0.
                    self.setPhase(.hint)
                }
            }
        }
    }

    // MARK: - async timeout helper
    private func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "speaker.timeout", code: -1)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - computed properties for session scores

    var averageScore: Int {
        guard !sessionScores.isEmpty else { return 0 }
        let total = sessionScores.reduce(0, +)
        return total / sessionScores.count
    }

    private static func sessionCardKey(_ item: StepData.SpeakerResolved) -> String {
        "\(item.courseId)|\(item.lessonId)|\(item.index)"
    }

    /// Оценка засчитана: копим её в подход и проверяем, закрыт ли круг.
    private func registerSessionScore(_ score: Int) {
        sessionScores.append(score)
        if let cur = current {
            sessionScoredCardKeys.insert(Self.sessionCardKey(cur))
        }
        guard trainingSessionSummary == nil,
              !queue.isEmpty,
              sessionScoredCardKeys.count >= queue.count else { return }
        trainingSessionSummary = makeTrainingSessionSummary()
    }

    private func makeTrainingSessionSummary() -> TrainingSessionSummary? {
        let scores = sessionScores
        guard !scores.isEmpty else { return nil }
        let half = scores.count / 2
        let trend: Int = {
            guard half >= 1 else { return 0 }
            let first = Array(scores.prefix(half))
            let second = Array(scores.suffix(scores.count - half))
            guard !first.isEmpty, !second.isEmpty else { return 0 }
            return (second.reduce(0, +) / second.count) - (first.reduce(0, +) / first.count)
        }()
        return TrainingSessionSummary(
            phrases: max(sessionScoredCardKeys.count, 1),
            average: scores.reduce(0, +) / scores.count,
            best: scores.max() ?? 0,
            weakest: scores.min() ?? 0,
            trend: trend
        )
    }

    /// Закрыть итог и начать следующий круг с чистой статистикой
    /// (`sessionScores = []` через didSet обнуляет и набор карточек, и сам итог).
    func startNextTrainingLap() {
        sessionScores = []
    }

    var improvementDelta: Int? {
        guard sessionScores.count >= 2 else { return nil }
        let last = sessionScores[sessionScores.count - 1]
        let prev = sessionScores[sessionScores.count - 2]
        return last - prev
    }

    // MARK: - asr (v0)

    /// kAFAssistantErrorDomain 1107 = too much silence / aborted; 1101 often follows. Retry once and prefer on-device.
    private func recognizeThai(url: URL?) async throws -> String {
        guard let url else { return "" }

        let auth = SFSpeechRecognizer.authorizationStatus()
        if auth == .notDetermined {
            let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    c.resume(returning: status == .authorized)
                }
            }
            if !granted { throw NSError(domain: "speaker.asr", code: 1) }
        } else if auth != .authorized {
            throw NSError(domain: "speaker.asr", code: 2)
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH")) else {
            throw NSError(domain: "speaker.asr", code: 3)
        }
        if !recognizer.isAvailable {
            throw NSError(domain: "speaker.asr", code: 4)
        }
        #if DEBUG
        print("[speaker] th-TH: isAvailable=\(recognizer.isAvailable) supportsOnDevice=\(recognizer.supportsOnDeviceRecognition)")
        #endif

        let onDeviceFirst = recognizer.supportsOnDeviceRecognition
        var lastError: Error?
        var sawRetryableError = false
        for attempt in 0..<2 {
            let useOnDevice = (attempt == 0) ? onDeviceFirst : !onDeviceFirst
            do {
                let text = try await recognizeThaiAttempt(url: url, recognizer: recognizer, onDevice: useOnDevice)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { return text }
                // Empty hypothesis (silence / timeout) — try alternate mode once, but don't pile buffer ASR.
            } catch {
                lastError = error
                let ns = error as NSError
                let isRetryable = (ns.code == 1107 || ns.code == 1101)
                #if DEBUG
                if isRetryable { print("[speaker] retry recognition (attempt \(attempt + 1)) after \(ns.domain) \(ns.code)") }
                #endif
                if !isRetryable { throw error }
                sawRetryableError = true
            }
        }
        // Buffer fallback only after hard retryable ASR errors — not for quiet empty takes.
        guard sawRetryableError else { return "" }
        do {
            let text = try await recognizeThaiViaBuffer(url: url, recognizer: recognizer)
            return text
        } catch {
            #if DEBUG
            print("[speaker] buffer recognition failed: \(error)")
            #endif
            throw lastError ?? error
        }
    }

    /// Keep at most one active th-TH recognition task to avoid overlapping tasks
    /// (which often results in kAFAssistantErrorDomain 1107/1101 on repeated taps).
    private var activeThaiRecognitionTask: SFSpeechRecognitionTask?

    /// Fallback when URL recognition returns 1107: read file, convert to 16kHz PCM, feed buffer request.
    private func recognizeThaiViaBuffer(url: URL, recognizer: SFSpeechRecognizer) async throws -> String {
        let file = try AVAudioFile(forReading: url)
        let srcFormat = file.processingFormat
        guard let dstFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1) else {
            throw NSError(domain: "speaker.asr", code: 10)
        }
        let converter = AVAudioConverter(from: srcFormat, to: dstFormat)
        guard let converter else { throw NSError(domain: "speaker.asr", code: 11) }

        let frameCount = UInt32(file.length)
        guard frameCount > 0 else { return "" }
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frameCount) else {
            throw NSError(domain: "speaker.asr", code: 12)
        }
        try file.read(into: inputBuffer)
        inputBuffer.frameLength = frameCount

        let outCapacity = AVAudioFrameCount(Double(frameCount) * 16000.0 / Double(srcFormat.sampleRate)) + 1024
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: outCapacity) else {
            throw NSError(domain: "speaker.asr", code: 13)
        }
        var inputGiven = false
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if !inputGiven {
                inputGiven = true
                outStatus.pointee = .haveData
                return inputBuffer
            }
            outStatus.pointee = .endOfStream
            return nil
        }
        if let error { throw error }
        if status == .error { throw NSError(domain: "speaker.asr", code: 14) }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.append(outputBuffer)
        request.endAudio()

        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
            var lastText = ""
            var resumed = false
            func finish(returning s: String) {
                guard !resumed else { return }
                resumed = true
                c.resume(returning: s)
            }
            func finish(throwing e: Error) {
                guard !resumed else { return }
                resumed = true
                c.resume(throwing: e)
            }
            // Cancel any previous recognition before starting a new one.
            activeThaiRecognitionTask?.cancel()
            activeThaiRecognitionTask = recognizer.recognitionTask(with: request) { result, err in
                if let err {
                    let ns = err as NSError
                    let isRetryable = (ns.code == 1107 || ns.code == 1101)
                    // If we already got partial text, prefer returning it over hard-failing.
                    if isRetryable, !lastText.isEmpty {
                        finish(returning: lastText)
                        return
                    }
                    #if DEBUG
                    print("[speaker] buffer recognitionTask error: \(ns.code)")
                    #endif
                    finish(throwing: err)
                    return
                }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty { lastText = text }
                    if result.isFinal { finish(returning: text) }
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                finish(returning: lastText)
            }
        }
    }

    private func recognizeThaiAttempt(url: URL, recognizer: SFSpeechRecognizer, onDevice: Bool) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = onDevice

        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
            var lastText = ""
            var resumed = false
            func finish(returning s: String) {
                guard !resumed else { return }
                resumed = true
                c.resume(returning: s)
            }
            func finish(throwing e: Error) {
                guard !resumed else { return }
                resumed = true
                c.resume(throwing: e)
            }

            // Cancel any previous recognition before starting a new one.
            activeThaiRecognitionTask?.cancel()
            activeThaiRecognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    let ns = error as NSError
                    let isRetryable = (ns.code == 1107 || ns.code == 1101)
                    // If we already got partial text, prefer returning it over hard-failing.
                    if isRetryable, !lastText.isEmpty {
                        finish(returning: lastText)
                        return
                    }
                    #if DEBUG
                    print("[speaker] recognitionTask error: \(ns.domain) \(ns.code) \(ns.localizedDescription)")
                    #endif
                    finish(throwing: error)
                    return
                }
                if let result {
                    let text = result.bestTranscription.formattedString
                    if !text.isEmpty { lastText = text }
                    if result.isFinal {
                        finish(returning: text)
                    }
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                finish(returning: lastText)
            }
        }
    }

    private func normalizeThai(_ s: String) -> String {
        // keep thai letters + digits; drop spaces/punct
        let scalars = s.unicodeScalars.filter { sc in
            if CharacterSet.whitespacesAndNewlines.contains(sc) { return false }
            if CharacterSet.punctuationCharacters.contains(sc) { return false }
            if CharacterSet.symbols.contains(sc) { return false }
            return true
        }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    // MARK: - syllable formatting (v1 simple splitter)

    private func formattedSyllables(from thai: String) -> String {
        let clean = normalizeThai(thai)
        guard !clean.isEmpty else { return thai }

        // simple visual grouping every 2–3 characters (MVP)
        var result: [String] = []
        var buffer = ""

        for (index, char) in clean.enumerated() {
            buffer.append(char)

            // naive split logic (can be improved later with real thai syllable rules)
            if buffer.count >= 2 {
                result.append(buffer)
                buffer = ""
            } else if index == clean.count - 1 {
                result.append(buffer)
            }
        }

        if !buffer.isEmpty {
            result.append(buffer)
        }

        return result.joined(separator: "-")
    }

    private func similarity(a: String, b: String) -> Double {
        let x = normalizeThai(a)
        let y = normalizeThai(b)
        if x.isEmpty && y.isEmpty { return 1.0 }
        if x.isEmpty || y.isEmpty { return 0.0 }
        let d = levenshtein(x, y)
        let m = max(x.count, y.count)
        if m == 0 { return 1.0 }
        return max(0.0, 1.0 - (Double(d) / Double(m)))
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var prev = Array(0...b.count)
        var cur = Array(repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                let cost = (a[i - 1] == b[j - 1]) ? 0 : 1
                cur[j] = min(
                    prev[j] + 1,        // delete
                    cur[j - 1] + 1,     // insert
                    prev[j - 1] + cost  // substitute
                )
            }
            prev = cur
        }
        return prev[b.count]
    }

    func resetToIdle() {
        setPhase(.idle)
        taikaHints = []
    }

    /// Из phonetic — по одному тону на каждый учебный чанк (пробел + дефис), как строки разбора.
    /// Не по числу стрелок: «кху↘н↘» — один слог, не два.
    private static func expectedTonesFromPhonetic(_ phonetic: String?) -> String? {
        let chunks = phoneticSyllableChunks(phonetic)
        guard !chunks.isEmpty else { return nil }
        return chunks.map(toneNameFromPhoneticChunk).joined(separator: ",")
    }

    /// Same split as `SpeakerDSRoot.translitChunksForSyllables` / server `phonetic_syllable_chunks`.
    nonisolated static func phoneticSyllableChunks(_ phonetic: String?) -> [String] {
        let raw = canonicalTeachingPhonetic(phonetic ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }
        let words = raw.split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return words.flatMap { word in
            word.split(omittingEmptySubsequences: true) { "-·".contains($0) }
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    private static func toneNameFromPhoneticChunk(_ chunk: String) -> String {
        if chunk.contains("↘") { return "Falling" }
        if chunk.contains("↗") { return "Rising" }
        if chunk.contains("→") { return "Mid" }
        if chunk.contains("↓") { return "Low" }
        if chunk.contains("↑") { return "High" }
        return "Mid"
    }

    // MARK: - Tone assessment API (Phase C backend)

    /// URL бэкенда (Smart Speaker + Tone Assessment). nil = не вызывать API.
    /// Debug: симулятор → localhost; устройство → TAIKA_TONE_API_URL или TaikaAPIBaseURL.
    /// Release: Info.plist → TaikaAPIBaseURL (https://your-api.example.com без слэша в конце).
    static var toneAssessmentBaseURL: String? = {
        // Info.plist или env всегда имеют приоритет (для Railway/прод)
        if let url = (Bundle.main.object(forInfoDictionaryKey: "TaikaAPIBaseURL") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return url
        }
        #if DEBUG
        if let url = ProcessInfo.processInfo.environment["TAIKA_TONE_API_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return url
        }
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8000"
        #else
        return nil
        #endif
        #else
        return nil
        #endif
    }()

    /// Запрос разбора по тонам: отправляет lastAttempt и эталонный тайский на POST /assess.
    /// - Parameters:
    ///   - expectedThaiForAssess: если задан (например снимок при тапе «разбор» в умном спикере), не смешивать с карточкой очереди.
    ///   - expectedPhoneticForTones: транслит для expected_tones; обычно совпадает с эталоном в UI.
    func requestToneBreakdownFromAPI(
        expectedThaiForAssess: String? = nil,
        expectedPhoneticForTones: String? = nil,
        completion: @escaping () -> Void
    ) {
        if breakdownRequestInFlight {
            #if DEBUG
            print("[speaker] tone API: skip — already in flight")
            #endif
            completion()
            return
        }
        if hasBreakdownForCurrentAttempt() {
            #if DEBUG
            print("[speaker] tone API: skip — cached breakdown for current recording")
            #endif
            completion()
            return
        }
        #if DEBUG
        if Self.toneAssessmentBaseURL == nil || Self.toneAssessmentBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            #if targetEnvironment(simulator)
            print("[speaker] tone API: не вызываем — toneAssessmentBaseURL пустой. Собери для Simulator и запусти API на Mac: ./start_api.sh")
            #else
            print("[speaker] tone API: не вызываем — toneAssessmentBaseURL пустой. Задай в Xcode: Edit Scheme → Run → Environment Variables → TAIKA_TONE_API_URL = http://<IP Mac>:8000")
            #endif
        }
        if lastAttempt == nil {
            print("[speaker] tone API: не вызываем — lastAttempt=nil (нет ссылки на запись)")
        } else if let url = lastAttempt, !FileManager.default.fileExists(atPath: url.path) {
            print("[speaker] tone API: не вызываем — файл записи не найден: \(url.path)")
        }
        if current == nil && conversationExpectedThai == nil {
            print("[speaker] tone API: не вызываем — current=nil и conversationExpectedThai=nil")
        }
        #endif
        guard let base = Self.toneAssessmentBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !base.isEmpty,
              let audioURL = lastAttempt,
              FileManager.default.fileExists(atPath: audioURL.path) else {
            syllableFeedback = []
            breakdownHybridScore = nil
            breakdownRequestFailed = false
            completion()
            return
        }
        let thaiText: String
        let phoneticForTones: String
        if let snap = expectedThaiForAssess?.trimmingCharacters(in: .whitespacesAndNewlines), !snap.isEmpty {
            thaiText = snap
            phoneticForTones = expectedPhoneticForTones?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else if let convThai = conversationExpectedThai?.trimmingCharacters(in: .whitespacesAndNewlines), !convThai.isEmpty {
            thaiText = convThai
            phoneticForTones = conversationExpectedTranslitForFeedback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else if let cur = current {
            thaiText = cur.face.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines)
            phoneticForTones = cur.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            syllableFeedback = []
            breakdownHybridScore = nil
            breakdownRequestFailed = false
            completion()
            return
        }
        guard !thaiText.isEmpty else {
            #if DEBUG
            print("[speaker] tone API: не вызываем — эталонный тайский текст пустой")
            #endif
            syllableFeedback = []
            breakdownHybridScore = nil
            completion()
            return
        }
        #if DEBUG
        print("[speaker] tone API: отправляем POST \(base)/assess text=\(thaiText.prefix(20))... file=\(audioURL.lastPathComponent)")
        #endif
        // Не обнуляем syllableFeedback здесь — иначе displayScore скачет на текст-only до ответа API.
        breakdownRequestFailed = false
        breakdownRequestInFlight = true
        let generation = UUID()
        breakdownRequestGeneration = generation
        let requestAttemptURL = audioURL
        let url = URL(string: base.hasSuffix("/") ? base + "assess" : base + "/assess")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 90
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"text\"\r\n\r\n")
        body.append(Data(thaiText.utf8))
        append("\r\n")
        if let expectedTones = Self.expectedTonesFromPhonetic(phoneticForTones), !expectedTones.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"expected_tones\"\r\n\r\n")
            body.append(Data(expectedTones.utf8))
            append("\r\n")
        }
        if let ph = Self.teachingPhoneticOrNil(phoneticForTones) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"phonetic\"\r\n\r\n")
            body.append(Data(ph.utf8))
            append("\r\n")
        }
        let textScore = phase.isFeedback ? (heardConfidence) : 0
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"text_score\"\r\n\r\n")
        append("\(textScore)")
        append("\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        do {
            body.append(try Data(contentsOf: audioURL))
        } catch {
            #if DEBUG
            print("[speaker] tone API: ошибка чтения файла записи: \(error.localizedDescription)")
            #endif
            persistBreakdownFailureUnlessCached(requestAttemptPath: audioURL.path)
            if breakdownRequestGeneration == generation {
                breakdownRequestInFlight = false
            }
            completion()
            return
        }
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = body
        req.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.breakdownRequestGeneration == generation else { return }
                defer {
                    if self.breakdownRequestGeneration == generation {
                        self.breakdownRequestInFlight = false
                    }
                    completion()
                }
                guard self.lastAttempt == requestAttemptURL else {
                    #if DEBUG
                    print("[speaker] tone API: stale response — attempt changed")
                    #endif
                    return
                }
                if let error = error {
                    #if DEBUG
                    print("[speaker] tone API error: \(error.localizedDescription)")
                    #endif
                    self.persistBreakdownFailureUnlessCached(requestAttemptPath: requestAttemptURL.path)
                    return
                }
                let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard httpStatus >= 200, httpStatus < 300 else {
                    #if DEBUG
                    let preview = data.flatMap { String(data: $0, encoding: .utf8)?.prefix(300) ?? "" } ?? ""
                    print("[speaker] tone API: HTTP \(httpStatus) — \(preview)")
                    #endif
                    self.persistBreakdownFailureUnlessCached(requestAttemptPath: requestAttemptURL.path)
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let syllables = json["syllables"] as? [[String: Any]] else {
                    #if DEBUG
                    let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    print("[speaker] tone API: ответ без syllables — len=\(data?.count ?? 0) raw=\(raw.prefix(400))")
                    #endif
                    self.persistBreakdownFailureUnlessCached(requestAttemptPath: requestAttemptURL.path)
                    return
                }
                #if DEBUG
                print("[speaker] tone API: получено \(syllables.count) слогов, total_score=\(json["total_score"] ?? "?")")
                #endif
                let list: [SyllableFeedback] = syllables.compactMap { s in
                    guard let syl = s["syllable"] as? String else { return nil }
                    let score = (s["tone_score"] as? Int) ?? (s["tone_score"] as? Double).map { Int($0) } ?? 0
                    let comment = s["feedback"] as? String
                    let toneExpected = s["tone_expected"] as? String
                    let toneActual = s["tone_actual"] as? String
                    let f0Contour = (s["f0_contour"] as? [NSNumber])?.map { $0.doubleValue }
                        ?? (s["f0_contour"] as? [Double])
                    let segmentStart = (s["start_s"] as? Double) ?? (s["start_s"] as? NSNumber)?.doubleValue
                    let segmentEnd = (s["end_s"] as? Double) ?? (s["end_s"] as? NSNumber)?.doubleValue
                    return SyllableFeedback(
                        syllable: syl,
                        score: score,
                        comment: comment,
                        toneExpected: toneExpected,
                        toneActual: toneActual,
                        f0Contour: f0Contour,
                        segmentStart: segmentStart,
                        segmentEnd: segmentEnd
                    )
                }
                self.syllableFeedback = list
                self.breakdownRequestFailed = list.isEmpty
                if let hybrid = json["hybrid_score"] as? Int {
                    self.breakdownHybridScore = hybrid
                } else if let hybrid = json["hybrid_score"] as? Double {
                    self.breakdownHybridScore = Int(hybrid.rounded())
                } else {
                    self.breakdownHybridScore = nil
                }
                self.breakdownCacheAttemptPath = Self.normalizedRecordingPath(requestAttemptURL.path)
                self.syncFeedbackPhaseScoreIfNeeded()
                if self.speakerUIMode == .conversation, let historyId = self.activePracticeHistoryId {
                    self.persistConversationToneCache(historyItemId: historyId, sourceRecording: requestAttemptURL)
                }
            }
        }.resume()
    }

    /// Training + conversation: fetch Cyrillic phonetic for ASR Thai when missing.
    func refreshUserPhoneticFromASRIfNeeded() {
        refreshTrainingUserPhoneticFromASRIfNeeded()
        refreshConversationUserPhoneticFromASRIfNeeded()
    }

    private var trainingPhoneticRefreshInFlight = false

    private func refreshTrainingUserPhoneticFromASRIfNeeded() {
        let thai = trainingHeardThaiASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !thai.isEmpty else { return }
        let existing = trainingHeardPhoneticFromASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard existing.isEmpty else { return }
        guard !trainingPhoneticRefreshInFlight else { return }
        trainingPhoneticRefreshInFlight = true
        Task { [weak self] in
            defer {
                Task { @MainActor in self?.trainingPhoneticRefreshInFlight = false }
            }
            guard let self else { return }
            for attempt in 0..<2 {
                do {
                    let ph = try await self.smartSpeakerPhoneticFromThai(thai: thai)
                    let trimmed = ph.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    await MainActor.run {
                        let cur = self.trainingHeardPhoneticFromASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        if cur.isEmpty {
                            self.trainingHeardPhoneticFromASR = Self.teachingPhoneticOrNil(trimmed)
                            self.heardTranslit = Self.teachingPhoneticOrNil(trimmed)
                            self.persistCurrentAttemptIfNeeded()
                        }
                    }
                    return
                } catch {
                    if attempt == 0 {
                        try? await Task.sleep(nanoseconds: 450_000_000)
                    }
                }
            }
        }
    }

    /// Если тайский с ASR уже есть, а кириллической фонетики нет — добиваем `/thai_phonetic` (повторы + фон для UI).
    private var phoneticRefreshInFlight = false
    func refreshConversationUserPhoneticFromASRIfNeeded() {
        let thai = conversationHeardThaiASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !thai.isEmpty else { return }
        let existing = conversationHeardPhoneticFromASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard existing.isEmpty else { return }
        guard !phoneticRefreshInFlight else { return }
        phoneticRefreshInFlight = true
        Task { [weak self] in
            defer {
                Task { @MainActor in self?.phoneticRefreshInFlight = false }
            }
            guard let self else { return }
            for attempt in 0..<2 {
                do {
                    let ph = try await self.smartSpeakerPhoneticFromThai(thai: thai)
                    let trimmed = ph.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    await MainActor.run {
                        let cur = self.conversationHeardPhoneticFromASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        if cur.isEmpty {
                            self.conversationHeardPhoneticFromASR = Self.teachingPhoneticOrNil(trimmed)
                        }
                    }
                    return
                } catch {
                    if attempt == 0 {
                        try? await Task.sleep(nanoseconds: 450_000_000)
                    }
                }
            }
        }
    }

    /// Сбросить запись по текущей карточке: удалить из хранилища и обнулить UI (оценка, «ты сказал», счётчик попыток).
    /// Чтобы можно было повторно записать, принудительно останавливаем рекордер, если он был в записи.
    func clearAttemptForCurrentCard() {
        guard let cur = current else { return }
        if phase == .recording {
            _ = recorder.stop()
            stopMeter()
            recordingPartialThai = nil
            recordingMeter = 0
            recordingPartialTranslit = nil
        }
        let key = SpeakerAttemptsStore.key(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
        SpeakerAttemptsStore.remove(forKey: key)
        resetCurrentCardUI()
    }

    /// Сбросить все записи в текущем блоке (все карточки выбранного фильтра: последний урок / выученные / избранное / случайные).
    func clearAttemptsInCurrentQueue() {
        if phase == .recording {
            _ = recorder.stop()
            stopMeter()
            recordingPartialThai = nil
            recordingMeter = 0
            recordingPartialTranslit = nil
        }
        for r in queue {
            let key = SpeakerAttemptsStore.key(courseId: r.courseId, lessonId: r.lessonId, stepIndex: r.index)
            SpeakerAttemptsStore.remove(forKey: key)
        }
        // Free growth loop: user consciously clears block to restart practice.
        SpeakerDailyAttemptsStore.shared.restoreAllForToday()
        resetCurrentCardUI()
        taikaHints = [
            "попытки восстановлены на сегодня",
            "можно записывать снова"
        ]
        setPhase(.hint)
    }

    private func resetCurrentCardUI() {
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        clearTrainingASRResult()
        heardConfidence = 0
        clearToneBreakdownState()
        taikaHints = []
        lastAttemptURL = nil
        lastAttempt = nil
        attemptCount = 0
        sessionScores = []
        lastPlayed = .none
        attemptPlayer?.stop()
        attemptPlayer = nil
        setPhase(.idle)
    }

    /// Сбросить все записи спикера по всему приложению (для Profile «сбросить прогресс»).
    func clearAllSpeakerAttempts() {
        SpeakerAttemptsStore.clearAll()
        resetCurrentCardUI()
    }


    // MARK: - live meter (mvp)

    private func startMeter() {
        stopMeter()
        recordingMeter = 0
        // 8 Hz is enough for UI; 20 Hz was rebuilding Speaker body + techno backdrop constantly.
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let next = max(0, min(1, self.recorder.recordingMeter))
                if abs(next - self.recordingMeter) >= 0.03 || (next < 0.02 && self.recordingMeter > 0) {
                    self.recordingMeter = next
                }
                if self.phase == .recording {
                    let raw = self.recorder.partialText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let partial = raw.isEmpty ? nil : raw
                    if partial != self.recordingPartialThai {
                        self.recordingPartialThai = partial
                        self.recordingPartialTranslit = nil
                    }
                }
            }
        }
    }

    private func stopMeter() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    // MARK: - current lesson filter

    /// Очередь для фильтра «последний урок»: только выученные карточки этого урока (как в «выученные» по уроку).
    private func buildCurrentLessonQueue() -> [StepData.SpeakerResolved] {
        guard let ids = resolveCurrentLessonIds() else { return [] }

        let actualLessonId = stepData.lessonIdForCaseInsensitiveLookup(ids.lessonId) ?? ids.lessonId
        let learnedSet = ProgressManager.shared.learnedSet(courseId: ids.courseId, lessonId: actualLessonId)
        guard !learnedSet.isEmpty else { return [] }

        let lessonItems = stepData.items(for: actualLessonId)
        var out: [StepData.SpeakerResolved] = []
        out.reserveCapacity(learnedSet.count)

        for (arrayIdx, item) in lessonItems.enumerated() {
            switch item.kind {
            case .word, .phrase, .casual:
                break
            default:
                continue
            }
            // order (канон) + legacy UI/array индексы после старых билдов
            let matched = learnedSet.contains(item.order)
                || learnedSet.contains(arrayIdx)
                || learnedSet.contains(arrayIdx + 1)
            guard matched else { continue }
            if let r = stepData.speakerResolved(courseId: ids.courseId, lessonId: actualLessonId, index: item.order) {
                out.append(r)
            }
        }

        out = dedupResolved(out)
        out.sort { $0.index < $1.index }
        return out
    }

    private func resolveCurrentLessonIds() -> (courseId: String, lessonId: String)? {
        let snap = session.snapshot

        // source of truth: UserSession snapshot
        if let courseId = snap.lastCourseId, !courseId.isEmpty {
            if let lessonId = snap.lastLessonByCourse[courseId], !lessonId.isEmpty {
                return (courseId, lessonId)
            }
            // if we have a last course but no last lesson mapped yet, fall back to any started lesson
            if let lessons = snap.startedLessons[courseId], let lessonId = lessons.sorted().first {
                return (courseId, lessonId)
            }
        }

        // fallback: any started lesson (deterministic)
        if let courseId = snap.startedLessons.keys.sorted().first,
           let lessons = snap.startedLessons[courseId],
           let lessonId = lessons.sorted().first {
            return (courseId, lessonId)
        }

        // final fallback: any lastLessonByCourse entry (deterministic)
        if let courseId = snap.lastLessonByCourse.keys.sorted().first {
            let lessonId = snap.lastLessonByCourse[courseId] ?? ""
            if !lessonId.isEmpty {
                return (courseId, lessonId)
            }
        }

        return nil
    }

    private func buildFavoritesQueue() -> [StepData.SpeakerResolved] {
        let refIds = FavoriteManager.shared.speakerStepIds()
        guard !refIds.isEmpty else { return [] }

        var resolved: [StepData.SpeakerResolved] = []
        resolved.reserveCapacity(min(refIds.count, 64))

        for ref in refIds {
            guard let key = parseStepRefId(ref) else { continue }
            if key.courseId == "user_dict", key.lessonId == "smart_speaker" {
                if let fav = FavoriteManager.shared.smartSpeakerItem(index: key.index) {
                    let r = stepData.speakerResolvedFromCustom(
                        courseId: key.courseId,
                        lessonId: key.lessonId,
                        index: key.index,
                        ru: fav.ru,
                        thai: fav.th,
                        phonetic: fav.phonetic
                    )
                    resolved.append(r)
                }
            } else {
                // FavoriteManager stores normalized (lowercased) ids; StepData keys match JSON (may differ by case).
                let actualLessonId = stepData.lessonIdForCaseInsensitiveLookup(key.lessonId) ?? key.lessonId
                if let r = stepData.speakerResolved(courseId: key.courseId, lessonId: actualLessonId, index: key.index) {
                    resolved.append(r)
                }
            }
        }

        resolved = dedupResolved(resolved)
        // stable order
        resolved.sort { a, b in
            if a.courseId != b.courseId { return a.courseId < b.courseId }
            if a.lessonId != b.lessonId { return a.lessonId < b.lessonId }
            return a.index < b.index
        }

        return resolved
    }


    private func parseStepRefId(_ ref: String) -> (courseId: String, lessonId: String, index: Int)? {
        // expected: step:<courseId>:<lessonId>:idx<index>[:...]
        let parts = ref.split(separator: ":").map(String.init)
        guard parts.count >= 4 else { return nil }
        guard parts[0] == "step" else { return nil }

        let courseId = parts[1]
        let lessonId = parts[2]

        let idxPart = parts[3]
        // idx12 or 12
        let digits = idxPart.filter { $0.isNumber }
        guard let index = Int(digits) else { return nil }

        return (courseId, lessonId, index)
    }

    private func uuidFromBytes(_ bytes: [UInt8]) -> UUID {
        let b = bytes + Array(repeating: 0, count: max(0, 16 - bytes.count))
        return UUID(uuid: (
            b[0], b[1], b[2], b[3],
            b[4], b[5], b[6], b[7],
            b[8], b[9], b[10], b[11],
            b[12], b[13], b[14], b[15]
        ))
    }

    // B3: save attempt result to persistence; копируем запись в файл, привязанный к шагу (иначе везде играет последняя из рекордера)
    private func saveAttemptResult(
        courseId: String,
        lessonId: String,
        stepIndex: Int,
        heardThai: String?,
        heardTranslit: String?,
        heardThaiASR: String? = nil,
        heardPhoneticFromASR: String? = nil,
        heardConfidence: Int,
        attemptCount: Int,
        lastAttemptURL: URL?,
        consumeDailyAttempt: Bool = true
    ) {
        let key = SpeakerAttemptsStore.key(
            courseId: courseId,
            lessonId: lessonId,
            stepIndex: stepIndex
        )

        var urlToStore: URL? = lastAttemptURL
        if let source = lastAttemptURL, FileManager.default.fileExists(atPath: source.path) {
            let dest = SpeakerAttemptsStore.recordingFileURL(courseId: courseId, lessonId: lessonId, stepIndex: stepIndex)
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: source, to: dest)
                urlToStore = dest
            } catch {
                #if DEBUG
                print("[speaker] copy recording to step file failed: \(error)")
                #endif
            }
        }

        let hasToneData = breakdownHybridScore != nil || !syllableFeedback.isEmpty
        let unified = displayScore
        let advanced: Int? = hasToneData ? unified : (ProManager.shared.isPro ? unified : nil)
        let recordingPath = Self.normalizedRecordingPath(urlToStore?.path ?? urlToStore?.absoluteString)

        let result = SpeakerAttemptResult(
            courseId: courseId,
            lessonId: lessonId,
            stepIndex: stepIndex,
            heardThai: heardThai,
            heardTranslit: heardTranslit,
            heardThaiASR: heardThaiASR,
            heardPhoneticFromASR: heardPhoneticFromASR,
            heardConfidence: heardConfidence,
            advancedScore: advanced,
            attemptCount: attemptCount,
            lastAttemptURL: urlToStore?.absoluteString,
            toneSyllables: hasToneData ? Self.storedSyllables(from: syllableFeedback) : nil,
            toneHybridScore: breakdownHybridScore,
            toneBreakdownRecordingPath: hasToneData ? recordingPath : nil,
            timestamp: Date()
        )

        SpeakerAttemptsStore.save(attempt: result, forKey: key)
        if consumeDailyAttempt {
            SpeakerDailyAttemptsStore.shared.consume()
        }
    }

    // MARK: - dedup

    private func dedupResolved(_ items: [StepData.SpeakerResolved]) -> [StepData.SpeakerResolved] {
        var seen = Set<String>()
        var out: [StepData.SpeakerResolved] = []
        out.reserveCapacity(items.count)

        for r in items {
            let k = "\(r.courseId)|\(r.lessonId)|\(r.index)"
            if seen.insert(k).inserted {
                out.append(r)
            }
        }
        return out
    }
}

