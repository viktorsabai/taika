//
//  SpeakerRecorder.swift
//  taika
//
//  Created by product on 26.12.2025.
//
import AVFoundation
import Speech

extension Notification.Name {
    static let speakerRecorderDidStart = Notification.Name("speakerRecorderDidStart")
    static let speakerRecorderDidStop = Notification.Name("speakerRecorderDidStop")
}

protocol SpeakerRecording: AnyObject {
    var isRecording: Bool { get }
    var recordingMeter: Double { get }
    var partialText: String { get }

    var hasMicrophoneAccess: Bool { get }
    var hasSpeechAccess: Bool { get }

    func requestPermission(completion: @escaping (Bool) -> Void)
    func requestMicrophoneAccess() async -> Bool
    func requestSpeechAccess() async -> Bool
    func ensureCapturePermissions() async -> Bool
    func start(completion: @escaping (URL?) -> Void)
    /// Start capture only after mic permission is already granted.
    func startAuthorized(completion: @escaping (URL?) -> Void)
    func stop() -> URL?
    func currentAudioURL() -> URL?
}

@MainActor
final class SpeakerRecorder: NSObject, ObservableObject, SpeakerRecording {
    @Published var isRecording: Bool = false
    @Published var recordingMeter: Double = 0.0
    @Published var partialText: String = ""

    enum Status: Equatable {
        case idle
        case requestingPermission
        case permissionDenied
        case starting
        case recording
        case startFailed
        case stopping
        case stopFailed
    }

    @Published var status: Status = .idle
    @Published var lastErrorMessage: String? = nil

    private var recorder: AVAudioRecorder?
    private var leveltimer: Timer?
    private let filename = "speaker_attempt.m4a"
    private var currentURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    static let shared = SpeakerRecorder()

    func requestPermission(completion: @escaping (Bool) -> Void) {
        status = .requestingPermission
        lastErrorMessage = nil

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            status = .permissionDenied
            lastErrorMessage = "mic session setup failed"
            completion(false)
            return
        }

        if hasMicrophoneAccess {
            status = .starting
            completion(true)
            return
        }

        session.requestRecordPermission { [weak self] micGranted in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(false)
                    return
                }
                if micGranted {
                    self.status = .starting
                } else {
                    self.status = .permissionDenied
                    self.lastErrorMessage = "mic permission denied"
                }
                completion(micGranted)
            }
        }
    }

    /// Mic already authorized (or legacy granted).
    var hasMicrophoneAccess: Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }

    var hasSpeechAccess: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { cont in
            requestPermission { cont.resume(returning: $0) }
        }
    }

    func requestSpeechAccess() async -> Bool {
        let auth = SFSpeechRecognizer.authorizationStatus()
        switch auth {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async {
                        cont.resume(returning: status == .authorized)
                    }
                }
            }
        @unknown default:
            return false
        }
    }

    /// Mic + speech, in order. Does not start recording.
    func ensureCapturePermissions() async -> Bool {
        let mic = await requestMicrophoneAccess()
        guard mic else { return false }
        return await requestSpeechAccess()
    }

    func start(completion: @escaping (URL?) -> Void) {
        status = .starting
        lastErrorMessage = nil

        requestPermission { [weak self] ok in
            guard ok, let self = self else {
                if let self = self {
                    self.status = .permissionDenied
                    self.lastErrorMessage = "mic permission denied"
                }
                completion(nil)
                return
            }
            self.startAuthorized(completion: completion)
        }
    }

    /// Start capture only after mic permission is already granted.
    func startAuthorized(completion: @escaping (URL?) -> Void) {
        status = .starting
        lastErrorMessage = nil

        guard hasMicrophoneAccess else {
            status = .permissionDenied
            lastErrorMessage = "mic permission denied"
            completion(nil)
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do { try FileManager.default.removeItem(at: currentURL) } catch {}

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let r = try AVAudioRecorder(url: currentURL, settings: settings)
            r.isMeteringEnabled = true
            r.prepareToRecord()
            r.record()

            NotificationCenter.default.post(name: .speakerRecorderDidStart, object: nil)

            recorder = r
            isRecording = true
            status = .recording
            startLevelMeter()
            partialText = ""

            completion(currentURL)
        } catch {
            isRecording = false
            status = .startFailed
            lastErrorMessage = "recorder start failed"
            completion(nil)
        }
    }

    func stop() -> URL? {
        return stopRecording()
    }

    func stopRecording() -> URL? {
        status = .stopping
        lastErrorMessage = nil

        // idempotent stop: just return existing file if any
        if !isRecording {
            let url = currentAudioURL()
            status = .idle
            NotificationCenter.default.post(name: .speakerRecorderDidStop, object: "recording stopped")
            return url
        }

        recorder?.stop()
        let recorderWasValid = (recorder != nil)
        recorder = nil

        partialText = ""

        stopLevelMeter()
        isRecording = false

        // B1: explicit contract: validate audio file exists and has content
        let url = currentAudioURL()
        if url == nil {
            status = .idle
            NotificationCenter.default.post(name: .speakerRecorderDidStop, object: "recording stopped (no file)")
            
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {}
            return nil
        }

        // B1: success: valid URL returned, status -> idle
        status = .idle
        NotificationCenter.default.post(name: .speakerRecorderDidStop, object: lastAttemptSummary())

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {}

        return url
    }

    func currentAudioURL() -> URL? {
        let path = currentURL.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? NSNumber,
              size.intValue > 0
        else { return nil }
        return currentURL
    }

    private func startLevelMeter() {
        stopLevelMeter()
        recordingMeter = 0.0
        leveltimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let r = self.recorder else {
                self.recordingMeter = 0.0
                return
            }
            r.updateMeters()
            let power = r.averagePower(forChannel: 0) // -160...0
            let normalized = max(0.0, min(1.0, Double((power + 160.0) / 160.0)))
            self.recordingMeter = normalized
        }
        RunLoop.main.add(leveltimer!, forMode: .common)
    }

    private func stopLevelMeter() {
        leveltimer?.invalidate()
        leveltimer = nil
        recordingMeter = 0.0
    }

    private func lastAttemptSummary() -> String {
        switch status {
        case .stopFailed:
            return "recording stopped (failed): \(lastErrorMessage ?? "unknown")"
        default:
            return "recording stopped"
        }
    }
}
