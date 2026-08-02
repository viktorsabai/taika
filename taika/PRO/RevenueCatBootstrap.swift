import Foundation
import RevenueCat

enum RevenueCatBootstrap {

    private(set) static var isConfigured = false

    /// Вызов из `taikaApp.init()` — без ключа SDK не трогаем.
    static func configureIfNeeded() {
        guard !isConfigured else { return }
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_PUBLIC_API_KEY") as? String else { return }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }

        Purchases.configure(withAPIKey: key)
        Purchases.shared.delegate = RevenueCatPurchaseDelegate.shared
        isConfigured = true
    }
}

final class RevenueCatPurchaseDelegate: NSObject, PurchasesDelegate {

    static let shared = RevenueCatPurchaseDelegate()

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            ProManager.shared.applyRevenueCatCustomerInfo(customerInfo)
        }
    }
}
