//
//  SpeakerManager.swift
//  taika
//
//  Created by product on 26.12.2025.
//

import Foundation
import SwiftUI
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

    /// Переключение режима. При входе в умный спикер сбрасываем результат/карточку тренажёра, чтобы сверху не показывать «ны-нг» и т.п.
    public func setSpeakerUIMode(_ mode: SpeakerUIMode) {
        guard speakerUIMode != mode else { return }
        speakerUIMode = mode
        if mode == .conversation {
            clearConversationResult()
        }
    }

    /// Сброс результата умного спикера (русский/тайский/транслит и состояние «Повторить и проверить»). Вызывать при входе в режим, при появлении экрана и по кнопке «Сбросить результат».
    public func clearConversationResult() {
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        conversationExpectedThai = nil
        conversationExpectedTranslitForFeedback = nil
        if phase.isFeedback {
            setPhase(.idle)
        }
    }

    // MARK: - published

    @Published var speakerUIMode: SpeakerUIMode = .conversation

    @Published private(set) var phase: Phase = .idle

    /// Central transition for state machine; DEBUG logs to trace stuck states (EPIC 3).
    private func setPhase(_ p: Phase) {
        #if DEBUG
        if phase != p { print("[speaker] phase \(phase.label) -> \(p.label)") }
        #endif
        phase = p
    }
    @Published private(set) var queue: [StepData.SpeakerResolved] = []

    @Published private(set) var current: StepData.SpeakerResolved?
    @Published private(set) var activeFilterId: UUID? = SpeakerMode.currentMode.id

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
    @Published private(set) var sessionScores: [Int] = []

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

    @Published var heardTranslit: String? = nil
    @Published var heardConfidence: Int = 0
    /// Smart Speaker politeness selection ("male" | "female" | "kathoey"); persisted in UserDefaults.
    @Published private var smartSpeakerPolitenessValue: String? = nil

    /// Одна общая оценка для спикера и разбора: без тона = текст; с тоном = min(текст, тон), чтобы не было «100 на карточке и 30 в разборе».
    var displayScore: Int {
        guard !syllableFeedback.isEmpty else { return heardConfidence }
        let toneAvg = syllableFeedback.map(\.score).reduce(0, +) / syllableFeedback.count
        return min(heardConfidence, toneAvg)
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

    // MARK: - UX timings
    // keep analyzing visible long enough to feel intentional (avoid "blink")
    private let minAnalyzingDuration: TimeInterval = 0.65
    private var analyzingStartedAt: Date? = nil

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
            heardTranslit = stored.heardTranslit
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
            
            // restore phase based on stored result
            if stored.heardConfidence > 0 {
                // B3: maintain consistency with initial feedback display - clear heardRU to prevent fake RU recognition
                heardRU = nil
                let hint = feedbackHint(for: stored.heardConfidence)
                let result = PronunciationResult(
                    totalScore: stored.heardConfidence,
                    accuracy: stored.heardConfidence,
                    fluency: stored.heardConfidence,
                    completeness: stored.heardConfidence,
                    hint: hint
                )
                setPhase(.feedback(result: result))
                taikaHints = [
                    resolved.face.titleRU.isEmpty ? "оценка: \(stored.heardConfidence)" : "фраза: \(resolved.face.titleRU)",
                    "оценка: \(stored.heardConfidence)",
                    hint
                ]
            } else {
                // B3: clear heardRU when score is 0 to prevent stale value from previous card
                heardRU = nil
                setPhase(.idle)
                taikaHints = []
            }
        } else {
            // no stored result - reset to clean state
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
    private var meterTimer: Timer?
    private var conversationRecordingTimer: Timer?
    private var conversationRecordingStartTime: Date?
    private var baseQueue: [StepData.SpeakerResolved] = []

    init(session: UserSession = .shared, stepData: StepData = .shared, recorder: (any SpeakerRecording)? = nil) {
        self.session = session
        self.stepData = stepData
        self.recorder = recorder ?? SpeakerRecorder.shared
        // preload Smart Speaker politeness from defaults
        if let stored = UserDefaults.standard.string(forKey: Self.smartSpeakerPolitenessKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            self.smartSpeakerPolitenessValue = stored.lowercased()
        } else {
            self.smartSpeakerPolitenessValue = nil
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
                } else if self.activeFilterId == SpeakerMode.currentMode.id {
                    self.applyFilter(SpeakerMode.currentMode.id)
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
        setPhase(.hint)
    }

    // MARK: - lifecycle

    func loadIfNeeded(force: Bool = false) {
        if didLoad && !force { return }
        didLoad = true
        rebuildQueue()
        activeFilterId = SpeakerMode.currentMode.id
        // По умолчанию открыт «последний урок» — сразу подставляем его очередь, чтобы не показывать baseQueue (выученные) как заглушку.
        queue = buildCurrentLessonQueue()
        pickFirst()
        if let cur = current {
            restoreAttemptResult(for: cur)
        }
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

        #if DEBUG
        let learnedKeysCount = snap.learnedSteps.keys.count
        let learnedTotal = snap.learnedSteps.values.reduce(0) { $0 + $1.count }
        let startedCoursesCount = snap.startedCourses.count
        let startedLessonsCount = snap.startedLessons.values.reduce(0) { $0 + $1.count }

        let lc = snap.lastCourseId ?? ""
        let ll = (lc.isEmpty ? "" : (snap.lastLessonByCourse[lc] ?? ""))
        let lk = (lc.isEmpty || ll.isEmpty) ? "" : "\(lc)|\(ll)"
        let lstep = lk.isEmpty ? nil : snap.lastStepByLesson[lk]

        print("[speaker] snapshot: learnedKeys=\(learnedKeysCount) learnedTotal=\(learnedTotal) startedCourses=\(startedCoursesCount) startedLessons=\(startedLessonsCount) lastCourse=\(lc) lastLesson=\(ll) lastStep=\(String(describing: lstep))")
        #endif

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

        #if DEBUG
        print("[speaker] rebuildQueue: resolved=\(resolved.count) (baseQueue)")
        #endif
        queue = resolved
        baseQueue = resolved
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
        heardConfidence = 0
        taikaHints = []
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
    /// Поддержка "__favorites__": загрузка очереди из избранного (тап по микрофону во вкладке Избранное).
    func loadQueueForCourse(_ courseId: String) {
        if courseId == "__favorites__" {
            speakerContextCourseId = nil
            activeFilterId = SpeakerMode.favoritesMode.id
            if baseQueue.isEmpty { loadIfNeeded(force: true) }
            let fav = buildFavoritesQueue()
            if fav.isEmpty {
                queue = []
                current = nil
                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = ["в избранном пусто"]
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
            loadIfNeeded(force: true)
        }
        let filtered = baseQueue.filter { $0.courseId == courseId }
        speakerContextCourseId = courseId
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
            queue = filtered
            if shuffleQueue { shuffle() }
            pickFirst()
        }
    }

    func applyFilter(_ id: UUID) {
        guard let mode = SpeakerMode(id: id) else { return }
        speakerContextCourseId = nil
        activeFilterId = mode.id

        if baseQueue.isEmpty {
            loadIfNeeded(force: true)
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

        default:
            if baseQueue.isEmpty {
                stopMeter()
                recordingPartialThai = nil
                recordingMeter = 0
                lastAttemptURL = nil
                heardThai = nil
                heardRU = nil
                heardTranslit = nil
                heardConfidence = 0
                taikaHints = ["пройдите урок — здесь появятся фразы"]
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
                queue = baseQueue
                if shuffleQueue { shuffle() }
                current = queue.first
                if let cur = current {
                    restoreAttemptResult(for: cur)
                }
            }
        }
    }

    /// Set second-level filter for "выученные": nil or "" = "Все", otherwise only steps from that lessonId.
    func setLearnedLessonFilter(_ lessonId: String?) {
        learnedLessonFilter = lessonId
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

    /// Reset conversation result and return to "say in Russian" prompt. Clears pronunciation-check state.
    func conversationRepeat() {
        conversationExpectedThai = nil
        conversationExpectedTranslitForFeedback = nil
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        heardConfidence = 0
        taikaHints = []
        lastAttemptURL = nil
        lastAttempt = nil
        lastPlayed = .none
        setPhase(.idle)
    }

    /// Conversation mode: start recording (no card required). Free: limited to conversation attempts per day; max duration enforced.
    func startConversationRecording() {
        if phase == .recording || phase == .analyzing || phase == .analyzingTranslation { return }

        SpeakerConversationAttemptsStore.shared.refreshDayIfNeeded()
        guard SpeakerConversationAttemptsStore.shared.canRecord else {
            taikaHints = ["демо попытки на сегодня закончились. переходи на PRO — безлимит"]
            setPhase(.hint)
            return
        }

        // Ask politeness once (krap/kha); block recording until selected.
        if smartSpeakerNeedsPoliteness {
            taikaHints = ["выбери вежливость: кхрап/кха"]
            setPhase(.hint)
            return
        }

        lastAttemptURL = nil
        lastAttempt = nil
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        recordingPartialRU = ""
        recordingMeter = 0
        conversationRecordingElapsed = 0
        conversationRecordingStartTime = Date()
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        heardConfidence = 0
        taikaHints = []
        lastPlayed = .none

        setPhase(.recording)
        startMeter()

        let token = UUID()
        activeAttemptToken = token

        conversationRecordingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
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
        RunLoop.main.add(conversationRecordingTimer!, forMode: .common)

        recorder.start { [weak self] url in
            guard let self else { return }
            guard self.activeAttemptToken == token else { return }
            if let url {
                self.lastAttemptURL = url
                self.lastAttempt = url
            }
        }
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

                // Limit long "tirades" — keep UX readable
                let words = ruTrimmed.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
                if ruTrimmed.count > 80 || words.count > 12 {
                    await MainActor.run {
                        self.heardRU = ruTrimmed.isEmpty ? nil : ruTrimmed
                        self.heardThai = nil
                        self.heardTranslit = nil
                        self.taikaHints = ["скажи короче: одну фразу"]
                        self.setPhase(.hint)
                    }
                    return
                }

                let (thText, phonetic) = try await self.withTimeout(seconds: 25) {
                    try await self.smartSpeakerTranslate(ru: ruTrimmed)
                }

                await MainActor.run {
                    if self.activeAttemptToken != nil && self.activeAttemptToken != token { return }

                    self.heardRU = ruTrimmed.isEmpty ? nil : ruTrimmed
                    self.heardThai = thText.isEmpty ? nil : thText
                    self.heardTranslit = phonetic.isEmpty ? nil : phonetic
                    self.heardConfidence = 0
                    self.taikaHints = []
                    self.setPhase(.hint)
                    SpeakerConversationAttemptsStore.shared.consume()
                }
            } catch {
                await MainActor.run {
                    if self.activeAttemptToken != nil && self.activeAttemptToken != token { return }
                    self.heardRU = ruTrimmed.isEmpty ? nil : ruTrimmed
                    self.heardThai = nil
                    self.heardTranslit = nil
                    let hint: String
                    if let e = error as NSError?, e.domain == "speaker.smart", e.code == 1 {
                        hint = "API не настроен. Запусти ./start_api.sh в scripts/thai_tone_assessment"
                    } else if let e = error as NSError?, e.domain == "speaker.smart.http", e.code == 404 {
                        hint = "Перевод не сработал. Railway: OPENAI_API_KEY + передеплой. Модель gpt-4o-mini."
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
                                hint = "Ошибка сети: \(e.localizedDescription). Попробуй ещё раз"
                            }
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

    struct SmartSpeakerResponse: Decodable {
        let thai: String
        let phonetic: String
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

    var smartSpeakerPoliteness: String? {
        smartSpeakerPolitenessValue
    }

    var smartSpeakerNeedsPoliteness: Bool {
        smartSpeakerPolitenessValue == nil
    }

    func setSmartSpeakerPoliteness(_ value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        smartSpeakerPolitenessValue = cleaned
        UserDefaults.standard.set(cleaned, forKey: Self.smartSpeakerPolitenessKey)
    }

    private func smartSpeakerTranslate(ru: String) async throws -> (thai: String, phonetic: String) {
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
        let politeness = (smartSpeakerPoliteness ?? SmartSpeakerPoliteness.female.rawValue)
        let body: [String: Any] = [
            "text_ru": ru,
            "politeness": politeness,
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code >= 200, code < 300 else {
            throw NSError(domain: "speaker.smart.http", code: code)
        }
        let decoded = try JSONDecoder().decode(SmartSpeakerResponse.self, from: data)
        return (
            thai: decoded.thai.trimmingCharacters(in: .whitespacesAndNewlines),
            phonetic: decoded.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Conversation mode: start recording Thai for "Повторить и проверить". Saves current translation as expected.
    func startConversationPronunciationCheck() {
        guard speakerUIMode == .conversation else { return }
        let thai = heardThai?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let translit = heardTranslit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !thai.isEmpty else { return }

        if phase == .recording || phase == .analyzing || phase == .analyzingTranslation { return }

        conversationExpectedThai = thai
        conversationExpectedTranslitForFeedback = translit.isEmpty ? nil : translit

        attemptPlayer?.stop()
        attemptPlayer = nil
        lastPlayed = .none
        lastAttemptURL = nil
        lastAttempt = nil
        recordingPartialThai = nil
        recordingPartialTranslit = nil
        recordingMeter = 0
        taikaHints = []

        setPhase(.recording)
        startMeter()

        let token = UUID()
        activeAttemptToken = token

        recorder.start { [weak self] url in
            guard let self else { return }
            guard self.activeAttemptToken == token else { return }
            if let url {
                self.lastAttemptURL = url
                self.lastAttempt = url
            }
        }
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
                let formattedSpoken = self.formattedSyllables(from: spoken)
                let similarityScore = self.similarity(a: spoken, b: expectedThai)
                let score = Int((similarityScore * 100.0).rounded())
                let hint = self.feedbackHint(for: score)

                await MainActor.run {
                    if let t = token, self.activeAttemptToken != nil && self.activeAttemptToken != t { return }

                    self.heardThai = nil
                    let expectedTranslit = self.conversationExpectedTranslitForFeedback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    self.heardTranslit = spoken.isEmpty
                        ? "распознавание не вернуло текст"
                        : (expectedTranslit.isEmpty ? formattedSpoken : expectedTranslit)
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
            } catch {
                await MainActor.run {
                    if let t = token, self.activeAttemptToken != nil && self.activeAttemptToken != t { return }
                    self.taikaHints = ["не удалось распознать. попробуй ещё раз"]
                    self.setPhase(.hint)
                    self.conversationExpectedThai = nil
                    self.conversationExpectedTranslitForFeedback = nil
                }
            }
        }
    }

    /// ASR Russian (SFSpeechRecognizer ru-RU). Replace with shared helper if needed.
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
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
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
            recognizer.recognitionTask(with: request) { result, error in
                if let error { finish(throwing: error); return }
                if let result, result.isFinal {
                    finish(returning: result.bestTranscription.formattedString)
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                finish(returning: "")
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

    func playReference() {
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
        referencePlaybackProgress = 1.0
    }

    private func playReference(resolved r: StepData.SpeakerResolved) {
        let thai = r.face.subtitleTH
        if !thai.isEmpty {
            referencePlaybackProgress = 0
            lastPlayed = .reference
            StepAudio.shared.speakThai(thai) { [weak self] progress in
                DispatchQueue.main.async { self?.referencePlaybackProgress = progress }
            }
        }
    }

    func playAttempt() {
        guard let url = lastAttempt else { return }
        do {
            attemptPlayer?.stop()
            attemptPlayer = try AVAudioPlayer(contentsOf: url)
            attemptPlayer?.prepareToPlay()
            attemptPlayer?.play()
            lastPlayed = .attempt
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
        heardConfidence = 0
        taikaHints = []

        // deterministic phase transition
        setPhase(.recording)
        startMeter()

        // token to ignore late completions
        let token = UUID()
        activeAttemptToken = token

        recorder.start { [weak self] (url: URL?) in
            guard let self else { return }
            // ignore if this is not the latest attempt
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

            // keep urls in sync
            self.lastAttemptURL = url
            self.lastAttempt = url

            // keep context in sync
            self.session.markActive(courseId: cur.courseId, lessonId: cur.lessonId, stepIndex: cur.index)
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

            do {
                // 15s timeout for recognition (user may speak 6–10s; server can take a few seconds)
                let spokenRaw = try await self.withTimeout(seconds: 15) {
                    try await self.recognizeThai(url: url)
                }

                // if card changed while analyzing, still show result but keep it tied to current data
                let spoken = spokenRaw.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    // В UI — эталонный phonetic из StepData, отформатированный по слогам (не ASR → кириллица).
                    let phonetic = cur.face.phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
                    let formattedPhonetic = self.formattedSyllables(from: phonetic)
                    self.heardThai = formattedPhonetic
                    self.heardTranslit = spoken.isEmpty
                        ? "распознавание не вернуло текст"
                        : (formattedPhonetic.isEmpty ? formattedSpoken : formattedPhonetic)
                    self.heardRU = nil

                    self.heardConfidence = score
                    self.sessionScores.append(score)

                    self.taikaHints = [
                        cur.face.titleRU.isEmpty ? "оценка: \(score)" : "фраза: \(cur.face.titleRU)",
                        "оценка: \(score)",
                        hint
                    ]

                    // Разбор по слогам строится в SpeakerDS из heardTranslit и эталона; syllableFeedback — под будущий провайдер.
                    self.syllableFeedback = []

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
                        heardThai: self.heardThai,
                        heardTranslit: self.heardTranslit,
                        heardConfidence: score,
                        attemptCount: self.attemptCount,
                        lastAttemptURL: url
                    )

                    let attemptId = url.lastPathComponent
                    self.session.logActivity(
                        .speakerAttemptCompleted,
                        courseId: cur.courseId,
                        lessonId: cur.lessonId,
                        stepIndex: cur.index,
                        refId: "free_asr:\(cur.courseId):\(cur.lessonId):idx\(cur.index):\(attemptId):try\(self.attemptCount):score\(score)"
                    )
                }
            } catch {
                #if DEBUG
                let ns = error as NSError
                print("[speaker] recognize failed: domain=\(ns.domain) code=\(ns.code) \(ns.localizedDescription)")
                #endif
                await MainActor.run {
                    let ns = error as NSError
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
                    self.heardThai = hint
                    self.heardTranslit = hint
                    self.heardRU = nil
                    self.heardConfidence = 0
                    let result = PronunciationResult(
                        totalScore: 0,
                        accuracy: 0,
                        fluency: 0,
                        completeness: 0,
                        hint: hint
                    )
                    self.setPhase(.feedback(result: result))
                    // Сохраняем попытку с оценкой 0 и копируем запись в Application Support,
                    // чтобы пользователь мог послушать запись даже при ошибке распознавания (1107 и др.)
                    self.saveAttemptResult(
                        courseId: cur.courseId,
                        lessonId: cur.lessonId,
                        stepIndex: cur.index,
                        heardThai: self.heardThai,
                        heardTranslit: self.heardTranslit,
                        heardConfidence: 0,
                        attemptCount: self.attemptCount,
                        lastAttemptURL: url
                    )
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
        for attempt in 0..<2 {
            let useOnDevice = (attempt == 0) ? onDeviceFirst : !onDeviceFirst
            do {
                return try await recognizeThaiAttempt(url: url, recognizer: recognizer, onDevice: useOnDevice)
            } catch {
                lastError = error
                let ns = error as NSError
                let isRetryable = (ns.code == 1107 || ns.code == 1101)
                #if DEBUG
                if isRetryable { print("[speaker] retry recognition (attempt \(attempt + 1)) after \(ns.domain) \(ns.code)") }
                #endif
                if !isRetryable { throw error }
            }
        }
        // Third try: feed file as PCM buffer (avoids URL/silence issues that cause 1107)
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
            recognizer.recognitionTask(with: request) { result, err in
                if let err {
                    #if DEBUG
                    print("[speaker] buffer recognitionTask error: \((err as NSError).code)")
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
                try? await Task.sleep(nanoseconds: 8_000_000_000)
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

            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    #if DEBUG
                    let ns = error as NSError
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
                try? await Task.sleep(nanoseconds: 10_000_000_000)
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

    /// Из phonetic (са-ват-ди↘, кун чыу а-рай↗) — comma-separated тона для API (Mid,Mid,Falling и т.д.).
    private static func expectedTonesFromPhonetic(_ phonetic: String?) -> String? {
        guard let raw = phonetic?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let arrows: [(Character, String)] = [
            ("↘", "Falling"), ("→", "Mid"), ("↗", "Rising"), ("↓", "Low"), ("↑", "High"),
        ]
        let words = raw.split(separator: " ").map { String($0) }
        var tones: [String] = []
        for word in words {
            let parts = word.split(omittingEmptySubsequences: true) { "-·".contains($0) }.map { String($0) }
            for part in parts where !part.isEmpty {
                var tone = "Mid"
                for (arrow, name) in arrows {
                    if part.hasSuffix(String(arrow)) { tone = name; break }
                }
                tones.append(tone)
            }
        }
        return tones.isEmpty ? nil : tones.joined(separator: ",")
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

    /// Запрос разбора по тонам: отправляет lastAttempt и текущий тайский текст на POST /assess, по ответу заполняет syllableFeedback.
    func requestToneBreakdownFromAPI(completion: @escaping () -> Void) {
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
        if let convThai = conversationExpectedThai?.trimmingCharacters(in: .whitespacesAndNewlines), !convThai.isEmpty {
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
        syllableFeedback = []
        breakdownHybridScore = nil
        breakdownRequestFailed = false
        breakdownRequestInFlight = true
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
            syllableFeedback = []
            breakdownHybridScore = nil
            breakdownRequestFailed = true
            completion()
            return
        }
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = body
        req.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                defer {
                    self.breakdownRequestInFlight = false
                    completion()
                }
                if let error = error {
                    #if DEBUG
                    print("[speaker] tone API error: \(error.localizedDescription)")
                    #endif
                    self.syllableFeedback = []
                    self.breakdownHybridScore = nil
                    self.breakdownRequestFailed = true
                    return
                }
                let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? -1
                guard httpStatus >= 200, httpStatus < 300 else {
                    #if DEBUG
                    let preview = data.flatMap { String(data: $0, encoding: .utf8)?.prefix(300) ?? "" } ?? ""
                    print("[speaker] tone API: HTTP \(httpStatus) — \(preview)")
                    #endif
                    self.syllableFeedback = []
                    self.breakdownHybridScore = nil
                    self.breakdownRequestFailed = true
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let syllables = json["syllables"] as? [[String: Any]] else {
                    #if DEBUG
                    let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    print("[speaker] tone API: ответ без syllables — len=\(data?.count ?? 0) raw=\(raw.prefix(400))")
                    #endif
                    self.syllableFeedback = []
                    self.breakdownHybridScore = nil
                    self.breakdownRequestFailed = true
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
                    return SyllableFeedback(
                        syllable: syl,
                        score: score,
                        comment: comment,
                        toneExpected: toneExpected,
                        toneActual: toneActual,
                        f0Contour: f0Contour
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
            }
        }.resume()
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
        resetCurrentCardUI()
    }

    private func resetCurrentCardUI() {
        heardThai = nil
        heardRU = nil
        heardTranslit = nil
        heardConfidence = 0
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
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            // unified metering via protocol
            self.recordingMeter = max(0, min(1, self.recorder.recordingMeter))
            if self.phase == .recording {
                let raw = self.recorder.partialText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.recordingPartialThai = raw.isEmpty ? nil : raw
                // translit will be added later; keep it nil for now
                self.recordingPartialTranslit = nil
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

        for item in lessonItems where learnedSet.contains(item.order) {
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
        heardConfidence: Int,
        attemptCount: Int,
        lastAttemptURL: URL?
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
                // оставляем urlToStore = source (темп); при следующей записи перезатрётся, но хотя бы не падаем
            }
        }

        let result = SpeakerAttemptResult(
            courseId: courseId,
            lessonId: lessonId,
            stepIndex: stepIndex,
            heardThai: heardThai,
            heardTranslit: heardTranslit,
            heardConfidence: heardConfidence,
            attemptCount: attemptCount,
            lastAttemptURL: urlToStore?.absoluteString,
            timestamp: Date()
        )

        SpeakerAttemptsStore.save(attempt: result, forKey: key)
        SpeakerDailyAttemptsStore.shared.consume()
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

