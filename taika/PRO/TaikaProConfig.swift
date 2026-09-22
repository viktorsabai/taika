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

    /// В ASC free trial вешаем только на годовую; месяц/lifetime — без триала.
    /// Paywall по умолчанию выбирает год; копирайт воронки это отражает.
    static let introTrialOnAnnualOnly = true

    /// Package identifiers в текущем Offering (дефолтные префиксы RevenueCat).
    enum PackageIdentifier {
        static let annual = "$rc_annual"
        static let monthly = "$rc_monthly"
        static let lifetime = "$rc_lifetime"
        /// Non-consumable gift SKU без entitlement у покупателя (ASC + RevenueCat).
        /// Пока пакета нет в Offering — paywall gift-режим использует demo issue при DEBUG / GIFT_DEMO.
        static let giftLifetime = "taika_gift_lifetime"
    }

    /// Маркетинговые fallback-цены (THB), пока offerings не загрузились / для бейджей.
    /// Живые цены всегда из StoreKit `localizedPriceString`.
    enum MarketingPrice {
        static let annualTHB = 1_990
        static let monthlyTHB = 349
        static let lifetimeTHB = 3_990
        /// ~166 ฿/мес при оплате года (1990/12).
        static let annualPerMonthTHB = 166
        /// Плашка на annual: скидка относительно 12× monthly (~52%).
        static let annualDiscountPercent = 52
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
        if introTrialOnAnnualOnly {
            return "\(introTrialDaysPhrase) бесплатно на годовой подписке. Отмена в любой момент в настройках Apple ID."
        }
        return "\(introTrialDaysPhrase) бесплатно, отмена в любой момент в настройках Apple ID."
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

    /// Юридические URL (публичные страницы на taikaa.online).
    enum Legal {
        static let privacyPolicy = URL(string: "https://www.taikaa.online/privacy")!
        static let termsOfUse = URL(string: "https://www.taikaa.online/terms")!
    }
}
