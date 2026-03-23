//
//  LessonsHeaderStore.swift
//  taika
//
//  Хранилище действий хедера экрана уроков курса (Спикер, Закрепить, Сбросить). LessonsView заполняет при появлении; AppShell читает при построении headerStyle.
//

import SwiftUI

@MainActor
public final class LessonsHeaderStore: ObservableObject {
    public static let shared = LessonsHeaderStore()

    @Published public private(set) var resetRequested: Bool = false

    public var onSpeaker: (() -> Void)?
    public var onReinforce: (() -> Void)?

    private init() {}

    public func requestReset() {
        resetRequested = true
    }

    public func clearResetRequest() {
        resetRequested = false
    }

    public func setActions(onSpeaker: (() -> Void)?, onReinforce: (() -> Void)?) {
        self.onSpeaker = onSpeaker
        self.onReinforce = onReinforce
    }

    public func clearActions() {
        onSpeaker = nil
        onReinforce = nil
    }
}
