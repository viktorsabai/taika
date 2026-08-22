import SwiftUI
import FirebaseCore

@main
struct taikaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var nav = NavigationIntent()
    @ObservedObject private var theme = ThemeManager.shared

    init() {
        RevenueCatBootstrap.configureIfNeeded()
        _ = TaikaAnalytics.shared
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
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

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(nav)
                .environmentObject(theme)
                .preferredColorScheme(theme.preferredScheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                TaikaAnalytics.shared.flush()
                if let uid = AuthService.shared.currentUserID {
                    SyncManager.shared.restoreIfNeeded(userId: uid)
                }
            case .background:
                TaikaAnalytics.shared.flush()
                SyncManager.shared.schedulePush()
            default:
                break
            }
        }
    }
}
