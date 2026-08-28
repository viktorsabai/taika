import Foundation
import Combine

/// Persistent «Taika Stars» — earned for correct game answers, spent on in-game hints.
/// Lightweight UserDefaults snapshot; not tied to reinforcement error queue or game session reset.
@MainActor
public final class TaikaStarsStore: ObservableObject {
    public static let shared = TaikaStarsStore()

    public enum HintKind: String, Codable {
        case matchHalfBoard
        case builderListen
        case audioRecallFiftyFifty
    }

    public static let earnPerCorrectAnswer = 1
    public static let costMatchHalfBoard = 3
    public static let costBuilderListen = 1
    public static let costAudioRecallFiftyFifty = 2

    @Published public private(set) var balance: Int = 0

    private static let key = "taika.stars.balance.v1"

    private init() {
        balance = max(0, UserDefaults.standard.integer(forKey: Self.key))
    }

    @discardableResult
    public func earn(_ amount: Int = earnPerCorrectAnswer) -> Int {
        let delta = max(0, amount)
        guard delta > 0 else { return balance }
        balance += delta
        persist()
        return balance
    }

    public func canAfford(_ cost: Int) -> Bool {
        balance >= max(0, cost)
    }

    @discardableResult
    public func spend(_ cost: Int, hint: HintKind) -> Bool {
        let price = max(0, cost)
        guard price > 0, balance >= price else { return false }
        balance -= price
        persist()
        #if DEBUG
        print("[stars] spent \(price) on \(hint.rawValue) → balance \(balance)")
        #endif
        return true
    }

    public func clearAll() {
        balance = 0
        UserDefaults.standard.removeObject(forKey: Self.key)
    }

    private func persist() {
        UserDefaults.standard.set(balance, forKey: Self.key)
    }
}
