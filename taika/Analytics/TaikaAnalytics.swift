import Foundation

/// Lightweight first-party analytics emitter for the TestFlight MVP.
/// It sends only typed product/technical events; no raw audio or PII.
final class TaikaAnalytics {
    static let shared = TaikaAnalytics()

    enum EventName: String {
        case firstOpen = "first_open"
        case onboardingCompleted = "onboarding_completed"
        case lessonStarted = "lesson_started"
        case lessonCompleted = "lesson_completed"
        case speakerOpened = "speaker_opened"
        case attemptStarted = "attempt_started"
        case attemptCompleted = "attempt_completed"
        case appLaunchFailed = "app_launch_failed"
        case syncFailed = "sync_failed"
    }

    private let defaults = UserDefaults.standard
    private let session = URLSession(configuration: .ephemeral)
    private let queue = DispatchQueue(label: "com.sabishev.taika.analytics")
    private let endpoint: URL?
    private let writeKey: String?
    private var pending: [[String: Any]] = []
    private var sessionID = UUID().uuidString.lowercased()

    private init() {
        let configuredEndpoint = Bundle.main.object(forInfoDictionaryKey: "TAIKA_ANALYTICS_ENDPOINT") as? String
        endpoint = URL(string: configuredEndpoint ?? "https://www.taikaa.online/api/analytics/events")
        writeKey = Bundle.main.object(forInfoDictionaryKey: "TAIKA_ANALYTICS_WRITE_KEY") as? String
        if let stored = defaults.array(forKey: "taika.analytics.pending_events") as? [[String: Any]] {
            pending = stored
        }
        track(.firstOpen)
    }

    func track(_ name: EventName, properties: [String: Any] = [:]) {
        queue.async {
            let event: [String: Any] = [
                "event_id": UUID().uuidString.lowercased(),
                "name": name.rawValue,
                "occurred_at": ISO8601DateFormatter().string(from: Date()),
                "anonymous_id": self.anonymousID,
                "session_id": self.sessionID,
                "app_version": self.appVersion,
                "build_number": self.buildNumber,
                "environment": self.environment,
                "properties": properties.reduce(into: [String: Any]()) { result, item in
                    if item.value is String || item.value is NSNumber || item.value is NSNull { result[item.key] = item.value }
                }
            ]
            self.pending.append(event)
            self.persistPending()
            if self.pending.count >= 10 { self.flush() }
        }
    }

    func flush() {
        queue.async {
            guard !self.pending.isEmpty, let endpoint = self.endpoint else { return }
            let events = Array(self.pending.prefix(50))
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let writeKey = self.writeKey, !writeKey.isEmpty { request.setValue(writeKey, forHTTPHeaderField: "X-Analytics-Write-Key") }
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "schema_version": 1,
                "sent_at": ISO8601DateFormatter().string(from: Date()),
                "device": ["platform": "ios", "os_version": ProcessInfo.processInfo.operatingSystemVersionString],
                "events": events
            ])
            self.session.dataTask(with: request) { _, response, error in
                self.queue.async {
                    guard error == nil, let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
                    self.pending.removeFirst(min(events.count, self.pending.count))
                    self.persistPending()
                }
            }.resume()
        }
    }

    private var anonymousID: String {
        if let value = defaults.string(forKey: "taika.analytics.anonymous_id") { return value }
        let value = UUID().uuidString.lowercased()
        defaults.set(value, forKey: "taika.analytics.anonymous_id")
        return value
    }

    private var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown" }
    private var buildNumber: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown" }
    private var environment: String {
        #if DEBUG
        return "testflight"
        #else
        return (Bundle.main.object(forInfoDictionaryKey: "TAIKA_ANALYTICS_ENVIRONMENT") as? String) ?? "testflight"
        #endif
    }

    private func persistPending() {
        defaults.set(pending, forKey: "taika.analytics.pending_events")
    }
}
