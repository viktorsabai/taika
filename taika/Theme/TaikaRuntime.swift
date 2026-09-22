//
//  TaikaRuntime.swift
//  taika
//
//  Process/runtime flags (Xcode Previews, etc.).
//

import Foundation

enum TaikaRuntime {
    /// True when the process is hosted by Xcode Canvas / Previews.
    /// Only trust Apple's official env flag — broader heuristics can blank a normal Run.
    static let isXcodePreview: Bool =
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

/// One wait for the whole app start: catalog + the Main feed.
/// Splash holds until this finishes. Main does not show a second loader.
enum TaikaCatalogBoot {
    private static let lock = NSLock()
    private static var task: Task<Void, Never>?
    private static var finished = false
    private static var hubReady = false

    static var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }

    /// Main copied the feed and had a chance to lay out. Splash may lift.
    static var isHubReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return hubReady
    }

    static func start() {
        lock.lock()
        defer { lock.unlock() }
        guard task == nil else { return }
        task = Task.detached(priority: .userInitiated) {
            await run()
        }
    }

    static func ensure() async {
        start()
        let running: Task<Void, Never> = {
            lock.lock()
            defer { lock.unlock() }
            return task!
        }()
        await running.value
    }

    private static func run() async {
        StepData.shared.preload()
        LessonsData.shared.preload()
        await MainActor.run {
            StepAudio.shared.warmEngineIfNeeded()
        }
        await loadMainFeed()
        lock.lock()
        finished = true
        lock.unlock()
    }

    @MainActor
    private static func loadMainFeed() async {
        await MainManager.shared.refresh()
        if MainManager.shared.weekSummary.isEmpty {
            await MainManager.shared.rebuildWeekSummary()
        }
        await MainManager.shared.reloadDailyPicks()
        await MainManager.shared.reloadDailyCoursePicks()
    }

    static func markHubReady() {
        lock.lock()
        hubReady = true
        lock.unlock()
    }
}
