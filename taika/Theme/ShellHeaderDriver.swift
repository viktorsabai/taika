import Combine
import Foundation
import SwiftUI

/// Сводит множество `objectWillChange` синглтонов в один сигнал, чтобы `ShellHeaderHost` не держал 8+ `@ObservedObject`
/// и не участвовал в лишних invalidation-цепочках SwiftUI.
@MainActor
final class ShellHeaderDriver: ObservableObject {
    static let shared = ShellHeaderDriver()

    @Published private(set) var generation: UInt64 = 0

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let pubs: [AnyPublisher<Void, Never>] = [
            FavoriteManager.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            ProManager.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            SpeakerManager.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            SpeakerReturnContext.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            GameHeaderStore.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            LessonsHeaderStore.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            StepManager.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            SpeakerDailyAttemptsStore.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            SpeakerConversationAttemptsStore.shared.objectWillChange.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(pubs)
            .debounce(for: .milliseconds(180), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.generation &+= 1
            }
            .store(in: &cancellables)
    }

    /// Мгновенный рефреш хедера (без debounce) — для return-context CTA.
    func bump() {
        generation &+= 1
    }
}
