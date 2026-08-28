import Foundation
import RevenueCat

extension ProManager {

    func restorePurchasesRevenueCat() async throws {
        guard RevenueCatBootstrap.isConfigured else {
            throw ProStoreError.productsNotConfigured
        }
        let info = try await Purchases.shared.restorePurchases()
        applyRevenueCatCustomerInfo(info)
    }

    /// Стартовая синхронизация entitlement с RevenueCat.
    func syncCustomerInfoFromRevenueCat() async {
        guard RevenueCatBootstrap.isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            applyRevenueCatCustomerInfo(info)
        } catch {
            // Ошибки сети не блокируют UI; paywall покажет актуальное при открытии.
        }
    }

    /// Привязка RC-профиля к Firebase UID (или анонимный logOut).
    /// Триал / подписка живут на этом identity — один аккаунт → один intro.
    func syncRevenueCatIdentity(userId: String?) async {
        guard RevenueCatBootstrap.isConfigured else { return }
        do {
            if let userId, !userId.isEmpty {
                let current = Purchases.shared.appUserID
                if current == userId {
                    await syncCustomerInfoFromRevenueCat()
                    return
                }
                let (info, _) = try await Purchases.shared.logIn(userId)
                applyRevenueCatCustomerInfo(info)
            } else {
                // Уже аноним — только sync; иначе logOut сбрасывает в новый anonymous.
                if Purchases.shared.appUserID.hasPrefix("$RCAnonymousID:") {
                    await syncCustomerInfoFromRevenueCat()
                    return
                }
                let info = try await Purchases.shared.logOut()
                applyRevenueCatCustomerInfo(info)
            }
        } catch {
            // Identity sync не должен валить UI.
        }
    }

    /// Eligibility на intro / free trial для продукта пакета.
    func introTrialEligible(for package: Package) async -> Bool {
        guard RevenueCatBootstrap.isConfigured else { return false }
        let productId = package.storeProduct.productIdentifier
        // RC API здесь не throws — eligibility читаем напрямую.
        let map = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: [productId])
        if let status = map[productId]?.status {
            return status == .eligible
        }
        // Fallback: если StoreProduct уже несёт intro — считаем потенциально eligible.
        return package.storeProduct.introductoryDiscount != nil
    }
}
