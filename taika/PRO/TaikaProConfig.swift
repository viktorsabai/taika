import Foundation

/// Feature flags для TestFlight / App Store scope (код фич остаётся, UI можно вернуть одной строкой).
enum TaikaReleaseFlags {
    /// Курсовой диалог (Grand Dialogue) — ценность MVP, пока скрыт до доработки.
    static let showGrandDialogue = false
}

/// Идентификаторы RevenueCat / App Store — должны совпадать с консолью RevenueCat.
enum TaikaProConfig {

    /// Entitlement в RevenueCat (например `pro`).
    static let entitlementIdentifier = "pro"

    /// Длительность intro trial (должна совпадать с App Store Connect).
    static let introTrialDays = 3

    /// Package identifiers в текущем Offering (дефолтные префиксы RevenueCat).
    enum PackageIdentifier {
        static let annual = "$rc_annual"
        static let monthly = "$rc_monthly"
        static let lifetime = "$rc_lifetime"
    }

    /// Юридические URL (замените при публикации страниц).
    enum Legal {
        static let privacyPolicy = URL(string: "https://taika.app/privacy")!
        static let termsOfUse = URL(string: "https://taika.app/terms")!
    }
}
