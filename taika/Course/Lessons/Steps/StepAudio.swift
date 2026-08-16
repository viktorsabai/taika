import Foundation
import Combine
@preconcurrency import AVFoundation

/// boxed audio helper for step cards (speaker button)
/// usage: StepAudio.shared.speakThai(_:) or .speak(text:language:)
final class StepAudio: NSObject, ObservableObject {
    static let shared = StepAudio()

    /// When set from step cards, matches `SDStepItem.id` while that utterance is actively playing.
    @Published private(set) var activeStepSpeechItemId: UUID?

    private let synth = AVSpeechSynthesizer()
    private var sessionConfigured = false
    private var sessionActive = false
    private var progressCallback: ((Double) -> Void)?
    private var finishCallback: (() -> Void)?
    private var currentUtteranceLength: Int = 0
    private var pendingStepItemId: UUID?

    // default voice params
    private let defaultRate: Float = 0.48  // 0.0...1.0 (system maps to AVSpeechUtteranceDefaultSpeechRate scale)
    private let defaultPitch: Float = 1.05 // 0.5...2.0
    private let defaultVolume: Float = 1.0 // 0.0...1.0

    private override init() {
        super.init()
        synth.delegate = self
    }

    // MARK: - Public API

    /// speak thai phrase with th-TH voice; falls back gracefully if no thai voice
    func speakThai(_ text: String, stepItemId: UUID? = nil, onFinished: (() -> Void)? = nil) {
        speak(text: text, language: "th-TH", onProgress: nil, stepItemId: stepItemId, onFinished: onFinished)
    }

    /// Speak Thai and report playback progress 0.0...1.0 (for syncing UI e.g. tone graph). Callback is invoked on main queue.
    func speakThai(_ text: String, onProgress: @escaping (Double) -> Void, stepItemId: UUID? = nil, onFinished: (() -> Void)? = nil) {
        speak(text: text, language: "th-TH", onProgress: onProgress, stepItemId: stepItemId, onFinished: onFinished)
    }

    /// generic speak with BCP-47 language code (e.g., "th-TH", "ru-RU")
    func speak(text: String, language: String, onProgress: ((Double) -> Void)? = nil, stepItemId: UUID? = nil, onFinished: (() -> Void)? = nil) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if let onFinished {
                DispatchQueue.main.async { onFinished() }
            }
            return
        }
        prepareSessionIfNeeded()

        bindStepSpeechItem(stepItemId)

        // if already speaking, stop and re-speak fresh
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }

        progressCallback = onProgress
        finishCallback = onFinished
        currentUtteranceLength = text.utf16.count
        if let cb = progressCallback, currentUtteranceLength > 0 {
            DispatchQueue.main.async { cb(0) }
        }

        let utt = AVSpeechUtterance(string: text)
        utt.voice = bestVoice(for: language)
        utt.rate = mappedRate(defaultRate)
        utt.pitchMultiplier = defaultPitch
        utt.volume = defaultVolume
        synth.speak(utt)
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

    func stop() {
        finishCallback = nil
        synth.stopSpeaking(at: .immediate)
        deactivateSessionIfNeeded()
    }
    var isSpeaking: Bool { synth.isSpeaking }

    // MARK: - Internals

    private func prepareSessionIfNeeded() {
        guard !sessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            // spokenAudio keeps system routing/ducking behavior sane for TTS
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
            sessionConfigured = true
            sessionActive = true
            observeInterruptions()
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

    private func bestVoice(for lang: String) -> AVSpeechSynthesisVoice? {
        // prefer an exact match; otherwise any voice with the same base language
        if let exact = AVSpeechSynthesisVoice(language: lang) { return exact }
        let base = lang.split(separator: "-").first.map(String.init)
        let fallback = AVSpeechSynthesisVoice.speechVoices().first { v in
            guard let base = base else { return false }
            return v.language.hasPrefix(base)
        }
        return fallback ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    private func mappedRate(_ normalized: Float) -> Float {
        // map 0...1 into iOS tts range around default
        let minR = AVSpeechUtteranceMinimumSpeechRate
        let defR = AVSpeechUtteranceDefaultSpeechRate
        let maxR = AVSpeechUtteranceMaximumSpeechRate
        // keep near default for clarity
        return defR + (maxR - defR) * (normalized - 0.5) * 0.6
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
        DispatchQueue.main.async {
            self.activeStepSpeechItemId = self.pendingStepItemId
        }
        if let cb = progressCallback {
            DispatchQueue.main.async { cb(0) }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        guard let cb = progressCallback, currentUtteranceLength > 0 else { return }
        let progress = min(1.0, Double(characterRange.location + characterRange.length) / Double(currentUtteranceLength))
        DispatchQueue.main.async { cb(progress) }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let cb = progressCallback {
            DispatchQueue.main.async { cb(1.0) }
        }
        progressCallback = nil
        currentUtteranceLength = 0
        print("[StepAudio] didFinish: \(utterance.speechString.prefix(20))...")
        clearActiveStepSpeechItem()
        let finish = finishCallback
        finishCallback = nil
        if let finish {
            DispatchQueue.main.async { finish() }
        }
        deactivateSessionIfNeeded()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if let cb = progressCallback {
            DispatchQueue.main.async { cb(1.0) }
        }
        progressCallback = nil
        currentUtteranceLength = 0
        finishCallback = nil
        print("[StepAudio] didCancel")
        clearActiveStepSpeechItem()
        deactivateSessionIfNeeded()
    }
}
