import SwiftUI
import FirebaseCore

@main
struct taikaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var nav = NavigationIntent()
    @ObservedObject private var theme = ThemeManager.shared

    init() {
        // Keep App.init tiny for Canvas: preview host must become ready in <15s.
        // SDKs configure after first frame (see `bootstrapRuntimeIfNeeded`).
        guard !TaikaRuntime.isXcodePreview else { return }
        applyNavigationBarAppearance()
        if TaikaSplashCover.shouldShowOnLaunch() {
            DispatchQueue.main.async {
                TaikaSplashCover.showIfNeeded()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            // Canvas injects #Preview content separately. Mounting AppShell here
            // (Firebase, splash, tabs, JSON) is what causes AppLaunchTimeoutError.
            if TaikaRuntime.isXcodePreview {
                Color.clear
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            } else {
                AppShell()
                    .environmentObject(nav)
                    .environmentObject(theme)
                    .preferredColorScheme(theme.preferredScheme)
                    .task {
                        bootstrapRuntimeIfNeeded()
                    }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard !TaikaRuntime.isXcodePreview else { return }
            switch newPhase {
            case .active:
                if let uid = AuthService.shared.currentUserID {
                    SyncManager.shared.restoreIfNeeded(userId: uid)
                }
            case .background:
                SyncManager.shared.schedulePush()
            default:
                break
            }
        }
    }

    private func bootstrapRuntimeIfNeeded() {
        guard !TaikaRuntime.isXcodePreview else { return }
        RevenueCatBootstrap.configureIfNeeded()
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
           FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        AuthService.shared.configureIfNeeded()
    }

    private func applyNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor.systemPink
    }
}
