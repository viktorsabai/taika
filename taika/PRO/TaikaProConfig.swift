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

    /// Длительность intro trial (должна совпадать с App Store Connect + RevenueCat).
    static let introTrialDays = 7

    /// Package identifiers в текущем Offering (дефолтные префиксы RevenueCat).
    enum PackageIdentifier {
        static let annual = "$rc_annual"
        static let monthly = "$rc_monthly"
        static let lifetime = "$rc_lifetime"
    }

    /// Маркетинговые fallback-цены (THB), пока offerings не загрузились / для бейджей.
    /// Живые цены всегда из StoreKit `localizedPriceString`.
    enum MarketingPrice {
        static let annualTHB = 1_690
        static let monthlyTHB = 349
        static let lifetimeTHB = 3_990
        /// ~140 ฿/мес при оплате года (1690/12).
        static let annualPerMonthTHB = 140
        /// Плашка на annual: скидка относительно 12× monthly.
        static let annualDiscountPercent = 60
    }

    /// Русская форма «N день/дня/дней».
    static var introTrialDaysWord: String {
        russianDaysWord(introTrialDays)
    }

    /// «7 дней».
    static var introTrialDaysPhrase: String {
        "\(introTrialDays) \(introTrialDaysWord)"
    }

    static var introTrialCTAFree: String {
        "Попробовать \(introTrialDaysPhrase) бесплатно"
    }

    static var introTrialCTALogin: String {
        "Войти и попробовать \(introTrialDaysPhrase)"
    }

    static var introTrialChip: String {
        introTrialDaysPhrase
    }

    static var introTrialBannerTitle: String {
        "Попробуй \(introTrialDaysPhrase) бесплатно"
    }

    /// Юридическая строка под CTA.
    static var introTrialLegalLine: String {
        "\(introTrialDaysPhrase) бесплатно, отмена в любой момент в настройках Apple ID."
    }

    static var annualHeroBadge: String {
        "−\(MarketingPrice.annualDiscountPercent)%"
    }

    static func russianDaysWord(_ days: Int) -> String {
        let n = abs(days) % 100
        let n1 = n % 10
        if n > 10 && n < 20 { return "дней" }
        if n1 == 1 { return "день" }
        if n1 >= 2 && n1 <= 4 { return "дня" }
        return "дней"
    }

    /// Юридические URL (замените при публикации страниц).
    enum Legal {
        static let privacyPolicy = URL(string: "https://taika.app/privacy")!
        static let termsOfUse = URL(string: "https://taika.app/terms")!
    }
}
