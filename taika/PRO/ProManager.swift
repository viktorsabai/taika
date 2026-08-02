//
//  ProManager.swift
//  taika
//
//  Created by product on 13.12.2025.
//

import Foundation
import Combine
import RevenueCat

// MARK: - Pro Feature Gates

enum ProFeature: String, CaseIterable {
    case dailyPicksExtra
    case unlimitedSessions
    case aiAdvanced
    case speakerAdvanced

    // Games
    case recallGame
    case contextGame
}

// MARK: - Pro Tier

enum ProTier: String {
    case none
    case pro
}

// MARK: - Pro Entitlement Source

enum ProEntitlementSource {
    case none
    case localReceipt
    case server
    case revenueCat
    case debug
}

// MARK: - Pro Manager

@MainActor
final class ProManager: ObservableObject {

    static let shared = ProManager()

    // MARK: Published State

    @Published private(set) var isPro: Bool = false
    @Published private(set) var tier: ProTier = .none
    @Published private(set) var source: ProEntitlementSource = .none

    /// Активное entitlement из RevenueCat (обновляется delegate + sync).
    @Published private(set) var revenueCatEntitled: Bool = false

    // MARK: Debug Override

    private static let debugOverrideKey = "pro.debug.override"

    /// nil = no override, true/false = force entitlement (debug only)
    @Published private(set) var debugOverride: Bool? = UserDefaults.standard.object(forKey: ProManager.debugOverrideKey) as? Bool

    // MARK: Dependencies

    private var cancellables = Set<AnyCancellable>()
    private var session: UserSession?

    // MARK: Init

    private init() {}

    // MARK: Lifecycle

    /// Call once when user session becomes available (login / app start)
    func start(session: UserSession) {
        self.session = session
        bindSession(session)
        applyMergedEntitlement()
    }

    /// Call on logout
    func reset() {
        cancellables.removeAll()
        session = nil
        revenueCatEntitled = false
        setPro(false, tier: .none, source: .none)
    }

    // MARK: Session Binding

    private func bindSession(_ session: UserSession) {
        session.$isProFromServer
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.debugOverride == nil else {
                    self.applyMergedEntitlement()
                    return
                }
                self.applyMergedEntitlement()
            }
            .store(in: &cancellables)
    }

    // MARK: Entitlement

    /// Пересчитать PRO: debug → (сервер ИЛИ RevenueCat).
    func refreshEntitlement() {
        applyMergedEntitlement()
    }

    /// Обновление из RevenueCat (`CustomerInfo`).
    func applyRevenueCatCustomerInfo(_ info: CustomerInfo) {
        let active = info.entitlements[TaikaProConfig.entitlementIdentifier]?.isActive == true
        revenueCatEntitled = active
        applyMergedEntitlement()
    }

    func applyMergedEntitlement() {
        if let forced = debugOverride {
            setPro(forced, tier: forced ? .pro : .none, source: .debug)
            return
        }

        let serverGrantsPro = session?.isProFromServer == true
        let combined = serverGrantsPro || revenueCatEntitled

        let src: ProEntitlementSource
        if combined {
            if serverGrantsPro && revenueCatEntitled {
                src = .revenueCat
            } else if serverGrantsPro {
                src = .server
            } else {
                src = .revenueCat
            }
        } else {
            src = .none
        }

        setPro(combined, tier: combined ? .pro : .none, source: src)
    }

    // MARK: Debug Control

    func setDebugOverride(_ enabled: Bool?) {
        debugOverride = enabled
        if let enabled {
            UserDefaults.standard.set(enabled, forKey: ProManager.debugOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ProManager.debugOverrideKey)
        }
        applyMergedEntitlement()
    }

    func setDebugPro(_ enabled: Bool) {
        setDebugOverride(enabled)
    }

    func clearDebugOverride() {
        setDebugOverride(nil)
    }

    // MARK: Feature Gates

    func can(_ feature: ProFeature) -> Bool {
        guard isPro else { return false }

        switch feature {
        case .dailyPicksExtra,
             .unlimitedSessions,
             .recallGame,
             .contextGame:
            return true

        case .aiAdvanced:
            return tier == .pro

        case .speakerAdvanced:
            return tier == .pro
        }
    }

    // MARK: Purchases (RevenueCat)

    func restorePurchases() async throws {
        try await restorePurchasesRevenueCat()
    }

    // MARK: Internal State

    private func setPro(_ enabled: Bool, tier: ProTier, source: ProEntitlementSource) {
        self.isPro = enabled
        self.tier = tier
        self.source = source
    }
}

// MARK: - Errors

enum ProStoreError: LocalizedError {
    case productsNotConfigured
    case productNotFound
    case purchaseFailed(String)

    var errorDescription: String? {
        switch self {
        case .productsNotConfigured:
            return "Подписка временно недоступна. Попробуй позже."
        case .productNotFound:
            return "Тариф не найден. Попробуй другой план."
        case .purchaseFailed(let message):
            return message.isEmpty ? "Покупка не прошла. Попробуй ещё раз." : message
        }
    }
}
