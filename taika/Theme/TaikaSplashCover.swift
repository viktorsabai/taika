//
//  TaikaSplashCover.swift
//  taika
//
//  Returning cold start: splash lives in its own window so SwiftUI can
//  assemble Main + header underneath without starving the cover.
//

import SwiftUI
import UIKit

@MainActor
enum TaikaSplashCover {
    private static var window: UIWindow?
    private static var startedAt = Date()
    private static var dismissTask: Task<Void, Never>?

    static func shouldShowOnLaunch() -> Bool {
        if TaikaRuntime.isXcodePreview { return false }
        let welcome = UserDefaults.standard.bool(forKey: "taika.welcome.seen.v1")
        if let onboarding = UserDefaults.standard.object(forKey: "taika.onboarding.v2.done") as? Bool {
            return onboarding
        }
        return welcome
    }

    static func showIfNeeded() {
        guard shouldShowOnLaunch() else { return }
        guard window == nil else { return }
        startedAt = Date()
        TaikaCatalogBoot.start()

        guard let scene = foregroundScene() else {
            DispatchQueue.main.async { showIfNeeded() }
            return
        }

        let host = UIHostingController(rootView: SplashTaikaView())
        host.view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)

        let cover = UIWindow(windowScene: scene)
        cover.windowLevel = UIWindow.Level.alert + 1
        cover.backgroundColor = host.view.backgroundColor
        cover.rootViewController = host
        cover.makeKeyAndVisible()
        window = cover
    }

    static func dismissNow() {
        dismissTask?.cancel()
        dismissTask = nil
        tearDown(animated: false)
    }

    static func dismissWhenAppReady() {
        guard shouldShowOnLaunch() else { return }
        showIfNeeded()
        guard dismissTask == nil else { return }
        dismissTask = Task { @MainActor in
            await waitUntilReady()
            guard !Task.isCancelled else { return }
            tearDown(animated: true)
            dismissTask = nil
        }
    }

    private static func waitUntilReady() async {
        let started = startedAt
        while !TaikaCatalogBoot.isReady {
            if Date().timeIntervalSince(started) > 25 { break }
            try? await Task.sleep(nanoseconds: 80_000_000)
            if Task.isCancelled { return }
        }
        while !TaikaCatalogBoot.isHubReady {
            if Date().timeIntervalSince(started) > 25 { break }
            try? await Task.sleep(nanoseconds: 80_000_000)
            if Task.isCancelled { return }
        }
        await waitForMainIdle(cycles: 3)
        let remain = 2.2 - Date().timeIntervalSince(started)
        if remain > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remain * 1_000_000_000))
        }
    }

    /// Fires after the main run loop actually goes idle — layout finished, not a fake sleep.
    private static func waitForMainIdle(cycles: Int) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            final class Box {
                var resumed = false
                var remaining = 0
                var observer: CFRunLoopObserver?
                func finish(_ cont: CheckedContinuation<Void, Never>) {
                    guard !resumed else { return }
                    resumed = true
                    if let observer {
                        CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
                    }
                    observer = nil
                    cont.resume()
                }
            }
            let box = Box()
            box.remaining = max(1, cycles)
            let observer = CFRunLoopObserverCreateWithHandler(
                kCFAllocatorDefault,
                CFRunLoopActivity.beforeWaiting.rawValue,
                true,
                0
            ) { _, _ in
                box.remaining -= 1
                guard box.remaining <= 0 else { return }
                box.finish(cont)
            }
            box.observer = observer
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                box.finish(cont)
            }
        }
    }

    private static func tearDown(animated: Bool) {
        guard let cover = window else { return }
        let finish = {
            cover.isHidden = true
            cover.rootViewController = nil
            window = nil
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: { !$0.isHidden })?
                .makeKey()
        }
        guard animated else {
            finish()
            return
        }
        UIView.animate(withDuration: 0.32, animations: {
            cover.alpha = 0
        }, completion: { _ in
            finish()
        })
    }

    private static func foregroundScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}
