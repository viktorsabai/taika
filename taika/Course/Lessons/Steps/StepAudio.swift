import Foundation
import Combine
@preconcurrency import AVFoundation

/// Единый вход озвучки. Учитель карточек — Apple th-TH.
/// usage: StepAudio.shared.speakThai(_:) or .speak(text:language:)
final class StepAudio: NSObject, ObservableObject {
    static let shared = StepAudio()

    /// When set from step cards, matches `SDStepItem.id` while that utterance is actively playing.
    @Published private(set) var activeStepSpeechItemId: UUID?
    /// После обычного прослушивания карточки — можно тапнуть «медленнее».
    @Published private(set) var slowOfferItemId: UUID?

    private let synth = AVSpeechSynthesizer()
    private var sessionConfigured = false
    private var sessionActive = false
    private var progressCallback: ((Double) -> Void)?
    private var finishCallback: (() -> Void)?
    private var currentUtteranceLength: Int = 0
    private var pendingStepItemId: UUID?
    private var thaiVoice: AVSpeechSynthesisVoice?
    private var didWarmEngine = false
    private var isWarmupUtterance = false
    private var playbackGeneration = 0
    /// Один прогон окраски из настроек. Карточка после этого снова говорит учителем.
    private var previewChoice: TaikaVoicePreference.PlaybackChoice?
    private var remotePlayer: AVAudioPlayer?
    private var remoteProgressTimer: Timer?
    private var activeUtteranceText = ""
    private var suppressSynthCallbacks = false

    /// Темп эталона: обычный тап и удержание «слушать».
    enum SpeechPace: Sendable {
        case usual
        case slow
    }

    // default voice params
    private let defaultRate: Float = 0.48  // 0.0...1.0 (system maps to AVSpeechUtteranceDefaultSpeechRate scale)
    private let defaultPitch: Float = 1.05 // 0.5...2.0
    private let defaultVolume: Float = 1.0 // 0.0...1.0
    private var pendingPace: SpeechPace = .usual
    private var pendingOffersSlow = false

    private override init() {
        super.init()
        synth.delegate = self
    }

    // MARK: - Public API

    /// speak thai phrase with th-TH voice; falls back gracefully if no thai voice
    func speakThai(_ text: String, stepItemId: UUID? = nil, pace: SpeechPace = .usual, offersSlowOnFinish: Bool = false, onFinished: (() -> Void)? = nil) {
        speak(text: text, language: "th-TH", onProgress: nil, stepItemId: stepItemId, pace: pace, offersSlowOnFinish: offersSlowOnFinish, onFinished: onFinished)
    }

    /// Пример голоса из настроек. Не меняет сохранённый выбор.
    func speakThaiPreview(_ text: String, choice: TaikaVoicePreference.PlaybackChoice) {
        let work = { self.previewChoice = choice }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
        speakThai(text)
    }

    /// Speak Thai and report playback progress 0.0...1.0 (for syncing UI e.g. tone graph). Callback is invoked on main queue.
    func speakThai(_ text: String, onProgress: @escaping (Double) -> Void, stepItemId: UUID? = nil, pace: SpeechPace = .usual, offersSlowOnFinish: Bool = false, onFinished: (() -> Void)? = nil) {
        speak(text: text, language: "th-TH", onProgress: onProgress, stepItemId: stepItemId, pace: pace, offersSlowOnFinish: offersSlowOnFinish, onFinished: onFinished)
    }

    /// generic speak with BCP-47 language code (e.g., "th-TH", "ru-RU")
    func speak(text: String, language: String, onProgress: ((Double) -> Void)? = nil, stepItemId: UUID? = nil, pace: SpeechPace = .usual, offersSlowOnFinish: Bool = false, onFinished: (() -> Void)? = nil) {
        let work = {
            self.speakNow(text: text, language: language, onProgress: onProgress, stepItemId: stepItemId, pace: pace, offersSlowOnFinish: offersSlowOnFinish, onFinished: onFinished)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func speakNow(text: String, language: String, onProgress: ((Double) -> Void)?, stepItemId: UUID?, pace: SpeechPace, offersSlowOnFinish: Bool, onFinished: (() -> Void)?) {
        let trimmed: String = {
            if language.hasPrefix("th") {
                return Self.sanitizeThaiForSpeech(text)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        guard !trimmed.isEmpty else {
            if let onFinished {
                DispatchQueue.main.async { onFinished() }
            }
            return
        }
        isWarmupUtterance = false
        pendingPace = pace
        pendingOffersSlow = offersSlowOnFinish && pace == .usual
        let clearOffer = {
            self.slowOfferItemId = nil
        }
        if Thread.isMainThread {
            clearOffer()
        } else {
            DispatchQueue.main.sync(execute: clearOffer)
        }
        playbackGeneration += 1
        let generation = playbackGeneration
        suppressSynthCallbacks = true
        stopRemotePlayback()
        prepareSessionIfNeeded()
        bindStepSpeechItem(stepItemId)
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        progressCallback = onProgress
        finishCallback = onFinished
        activeUtteranceText = trimmed
        currentUtteranceLength = trimmed.utf16.count
        if let cb = progressCallback, currentUtteranceLength > 0 {
            cb(0)
        }

        // Окраска Story Lab — только явный preview. Учитель карточек всегда Apple th-TH.
        if language.hasPrefix("th"), let choice = previewChoice, !choice.usesSystem {
            previewChoice = nil
            let baseURL = Self.toneAPIBaseURL()
            Task {
                let audio = await TaikaTTSFetch.mp3(text: trimmed, voice: choice.voiceId, baseURL: baseURL)
                await MainActor.run {
                    guard generation == self.playbackGeneration else { return }
                    if let audio {
                        self.playRemote(audio, rate: choice.rate, generation: generation)
                    } else {
                        self.speakPreviewFailed()
                    }
                }
            }
            return
        }
        previewChoice = nil

        TaikaVoicePreference.shared.clearSystemVoiceCaption()
        speakLocal(trimmed, language: language)
    }

    private func playRemote(_ data: Data, rate: Float, generation: Int) {
        stopRemotePlayback()
        TaikaVoicePreference.shared.clearSystemVoiceCaption()
        do {
            let player = try AVAudioPlayer(data: data)
            player.enableRate = true
            player.rate = rate
            player.delegate = self
            player.prepareToPlay()
            remotePlayer = player
            guard player.play() else {
                speakPreviewFailed()
                return
            }
            trackRemoteProgress(generation: generation)
        } catch {
            speakPreviewFailed()
        }
    }

    /// Окраска не пришла — не подменяем учителя iPhone, иначе ухо слышит другого человека.
    private func speakPreviewFailed() {
        stopRemotePlayback()
        suppressSynthCallbacks = false
        progressCallback = nil
        TaikaVoicePreference.shared.showVoiceUnavailableCaption()
        let finish = finishCallback
        finishCallback = nil
        clearActiveStepSpeechItem()
        if let finish {
            DispatchQueue.main.async { finish() }
        }
    }

    /// Тайское письмо без латиницы в скобках. Кириллица и русский в синтез не едут.
    static func sanitizeThaiForSpeech(_ text: String) -> String {
        var raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        if let open = raw.firstIndex(of: "("), open > raw.startIndex {
            let before = String(raw[..<open]).trimmingCharacters(in: .whitespaces)
            if containsThaiScript(before) {
                raw = before
            }
        }
        guard containsThaiScript(raw) else { return "" }
        return raw
    }

    private func speakLocal(_ text: String, language: String) {
        suppressSynthCallbacks = false
        let utt = AVSpeechUtterance(string: text)
        utt.voice = bestVoice(for: language)
        utt.rate = mappedRate(for: pendingPace)
        utt.pitchMultiplier = defaultPitch
        utt.volume = defaultVolume
        synth.speak(utt)
    }

    private func stopRemotePlayback() {
        remoteProgressTimer?.invalidate()
        remoteProgressTimer = nil
        remotePlayer?.stop()
        remotePlayer = nil
    }

    private func trackRemoteProgress(generation: Int) {
        remoteProgressTimer?.invalidate()
        remoteProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard generation == self.playbackGeneration, let player = self.remotePlayer, player.isPlaying else {
                timer.invalidate()
                return
            }
            let duration = max(player.duration, 0.05)
            let progress = min(1, max(0, player.currentTime / duration))
            self.progressCallback?(progress)
        }
    }

    private static func containsThaiScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0E00...0x0E7F).contains($0.value) }
    }

    private static func toneAPIBaseURL() -> String? {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { SpeakerManager.toneAssessmentBaseURL }
        }
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { SpeakerManager.toneAssessmentBaseURL }
        }
    }

    private func bindStepSpeechItem(_ id: UUID?) {
        let work = {
            self.pendingStepItemId = id
            if id == nil {
                self.activeStepSpeechItemId = nil
            }
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
    }

    private func clearActiveStepSpeechItem() {
        DispatchQueue.main.async {
            self.activeStepSpeechItemId = nil
        }
    }

    private func presentSlowOfferIfNeeded() {
        let offer = pendingOffersSlow
        let itemId = pendingStepItemId
        pendingOffersSlow = false
        guard offer, let itemId else { return }
        DispatchQueue.main.async {
            self.slowOfferItemId = itemId
        }
    }

    /// Cold-start Thai TTS on splash, so the first lesson card is not the first `speak`.
    func warmEngineIfNeeded() {
        guard !didWarmEngine else { return }
        didWarmEngine = true
        prepareSessionIfNeeded()
        _ = cachedThaiVoice()
        isWarmupUtterance = true
        let utt = AVSpeechUtterance(string: "า")
        utt.voice = cachedThaiVoice()
        utt.rate = AVSpeechUtteranceMaximumSpeechRate
        utt.volume = 0
        synth.speak(utt)
    }

    func stop() {
        playbackGeneration += 1
        finishCallback = nil
        progressCallback = nil
        pendingOffersSlow = false
        stopRemotePlayback()
        synth.stopSpeaking(at: .immediate)
        TaikaVoicePreference.shared.clearSystemVoiceCaption()
        deactivateSessionIfNeeded()
        DispatchQueue.main.async {
            self.slowOfferItemId = nil
        }
    }
    var isSpeaking: Bool { synth.isSpeaking || (remotePlayer?.isPlaying ?? false) }

    // MARK: - Internals

    private func prepareSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        do {
            let needsPlaybackRoute = session.category != .playback || session.mode != .spokenAudio
            if needsPlaybackRoute {
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            }
            if needsPlaybackRoute || !sessionActive {
                try session.setActive(true, options: [])
                sessionActive = true
            }
            if !sessionConfigured {
                sessionConfigured = true
                observeInterruptions()
            }
        } catch {
            print("[StepAudio] session error: \(error)")
        }
    }

    private func deactivateSessionIfNeeded() {
        guard sessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            sessionActive = false
        } catch {
            print("[StepAudio] deactivate error: \(error)")
        }
    }

    private func cachedThaiVoice() -> AVSpeechSynthesisVoice? {
        if let thaiVoice { return thaiVoice }
        let voice = AVSpeechSynthesisVoice(language: "th-TH")
        thaiVoice = voice
        return voice
    }

    private func bestVoice(for lang: String) -> AVSpeechSynthesisVoice? {
        if lang.hasPrefix("th") {
            return cachedThaiVoice()
        }
        if let exact = AVSpeechSynthesisVoice(language: lang) { return exact }
        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    private func mappedRate(for pace: SpeechPace) -> Float {
        let defR = AVSpeechUtteranceDefaultSpeechRate
        switch pace {
        case .usual:
            let maxR = AVSpeechUtteranceMaximumSpeechRate
            return defR + (maxR - defR) * (defaultRate - 0.5) * 0.6
        case .slow:
            return defR * 0.70
        }
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            guard let userInfo = note.userInfo,
                  let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
            switch type {
            case .began:
                self.synth.stopSpeaking(at: .immediate)
            case .ended:
                // no auto-resume for now
                self.deactivateSessionIfNeeded()
            @unknown default:
                break
            }
        }
    }
}

extension StepAudio: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard !isWarmupUtterance, !suppressSynthCallbacks else { return }
        DispatchQueue.main.async {
            self.activeStepSpeechItemId = self.pendingStepItemId
        }
        if let cb = progressCallback {
            DispatchQueue.main.async { cb(0) }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        guard !suppressSynthCallbacks, let cb = progressCallback, currentUtteranceLength > 0 else { return }
        let progress = min(1.0, Double(characterRange.location + characterRange.length) / Double(currentUtteranceLength))
        DispatchQueue.main.async { cb(progress) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if isWarmupUtterance {
            isWarmupUtterance = false
            return
        }
        guard !suppressSynthCallbacks else { return }
        if let cb = progressCallback {
            DispatchQueue.main.async { cb(1.0) }
        }
        progressCallback = nil
        currentUtteranceLength = 0
        print("[StepAudio] didFinish: \(utterance.speechString.prefix(20))...")
        clearActiveStepSpeechItem()
        presentSlowOfferIfNeeded()
        TaikaVoicePreference.shared.clearSystemVoiceCaption()
        let finish = finishCallback
        finishCallback = nil
        if let finish {
            DispatchQueue.main.async { finish() }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if isWarmupUtterance {
            isWarmupUtterance = false
            return
        }
        guard !suppressSynthCallbacks else { return }
        pendingOffersSlow = false
        if let cb = progressCallback {
            DispatchQueue.main.async { cb(1.0) }
        }
        progressCallback = nil
        currentUtteranceLength = 0
        finishCallback = nil
        TaikaVoicePreference.shared.clearSystemVoiceCaption()
        print("[StepAudio] didCancel")
        clearActiveStepSpeechItem()
    }
}

extension StepAudio: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            guard player === self.remotePlayer else { return }
            self.remoteProgressTimer?.invalidate()
            self.remoteProgressTimer = nil
            self.progressCallback?(1)
            self.progressCallback = nil
            self.currentUtteranceLength = 0
            self.clearActiveStepSpeechItem()
            self.remotePlayer = nil
            let finish = self.finishCallback
            self.finishCallback = nil
            finish?()
        }
    }
}
