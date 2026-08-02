//
//  SpeakerMode.swift
//  taika
//
//  Режимы фильтра Speaker (вынесено из SpeakerDS для стабильной видимости типа в модуле).
//

import Foundation

// MARK: - domain
public enum SpeakerMode: Hashable {
    case current, favorites, learned, random

    // stable ids for AppFiltersBar (UUID-based)
    private static let currentId = UUID(uuidString: "9C9B0F3C-8B3B-4C7C-9D26-8B0F4C9A1A01")!
    private static let favoritesId = UUID(uuidString: "2A6E4A7B-0B7B-4E7B-8C5A-7B9D1F8E2B02")!
    private static let learnedId = UUID(uuidString: "3B7C5D8A-1C4D-4D2B-9A6C-2D1C7E4B5A04")!
    private static let randomId = UUID(uuidString: "7E1D5B8E-2C5A-4C1C-8B6E-5A2C1D7E3C03")!

    public var id: UUID {
        switch self {
        case .current: return Self.currentId
        case .favorites: return Self.favoritesId
        case .learned: return Self.learnedId
        case .random: return Self.randomId
        }
    }

    public init?(id: UUID) {
        switch id {
        case Self.currentId: self = .current
        case Self.favoritesId: self = .favorites
        case Self.learnedId: self = .learned
        case Self.randomId: self = .random
        default: return nil
        }
    }
}

// convenience static accessors (to avoid conflict with case names)
extension SpeakerMode {
    public static var currentMode: SpeakerMode { .current }
    public static var favoritesMode: SpeakerMode { .favorites }
    public static var learnedMode: SpeakerMode { .learned }
    public static var randomMode: SpeakerMode { .random }
}
