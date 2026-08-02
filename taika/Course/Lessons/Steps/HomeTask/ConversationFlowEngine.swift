import Foundation

/// Один ход: реплика (аудио по `prompt`) и варианты ответа — карточки из того же урока.
struct ConversationTurnModel: Identifiable {
    var id: Int { prompt.order }
    let prompt: StepItem
    /// Перемешанные варианты (2…4 шт.), ровно один с `order == correctOrder`.
    let choices: [StepItem]
    let correctOrder: Int
}

enum ConversationFlowEngine {

    private static let maxTurns = 7

    static func buildTurns(from items: [StepItem]) -> [ConversationTurnModel] {
        let sorted = items.sorted { $0.order < $1.order }
        let learnables = sorted.filter { isLearnable($0) }
        guard learnables.count >= 2 else { return [] }

        let learnableOrders = Set(learnables.map(\.order))
        var usedPromptOrders = Set<Int>()
        var turns: [ConversationTurnModel] = []

        for prompt in learnables {
            guard turns.count < maxTurns else { break }
            guard isDialogPrompt(prompt) else { continue }
            guard let correct = resolveCorrect(prompt: prompt, sorted: sorted, learnableOrders: learnableOrders, learnables: learnables) else { continue }
            guard correct.order != prompt.order else { continue }
            guard let choices = makeChoices(correct: correct, pool: learnables) else { continue }
            guard !usedPromptOrders.contains(prompt.order) else { continue }
            usedPromptOrders.insert(prompt.order)
            turns.append(ConversationTurnModel(prompt: prompt, choices: choices, correctOrder: correct.order))
        }

        if turns.isEmpty {
            for i in 0..<(learnables.count - 1) {
                guard turns.count < maxTurns else { break }
                let prompt = learnables[i]
                let correct = learnables[i + 1]
                guard correct.order != prompt.order else { continue }
                guard let choices = makeChoices(correct: correct, pool: learnables) else { continue }
                guard !usedPromptOrders.contains(prompt.order) else { continue }
                usedPromptOrders.insert(prompt.order)
                turns.append(ConversationTurnModel(prompt: prompt, choices: choices, correctOrder: correct.order))
            }
        }

        return turns
    }

    private static func isLearnable(_ item: StepItem) -> Bool {
        switch item.kind {
        case .word, .phrase, .casual:
            return StepData.isValidForProgress(item)
        case .tip, .dialog:
            return false
        }
    }

    private static func isDialogPrompt(_ item: StepItem) -> Bool {
        if item.is_question == true { return true }
        if item.conversation_is_prompt == true { return true }
        if item.conversation_next_order != nil { return true }
        let ru = (item.ru ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ru.contains("?")
    }

    private static func resolveCorrect(
        prompt: StepItem,
        sorted: [StepItem],
        learnableOrders: Set<Int>,
        learnables: [StepItem]
    ) -> StepItem? {
        if let linked = learnables.first(where: { ($0.reply_to ?? -1) == prompt.order }) {
            return linked
        }
        if let n = prompt.conversation_next_order {
            return learnables.first { $0.order == n }
        }
        guard let idx = sorted.firstIndex(where: { $0.order == prompt.order }) else { return nil }
        for j in (idx + 1)..<sorted.count {
            let cand = sorted[j]
            if learnableOrders.contains(cand.order) { return cand }
        }
        return nil
    }

    private static func ruLabel(_ item: StepItem) -> String {
        (item.ru ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// До 4 уникальных по русской подписи вариантов, минимум 2.
    private static func makeChoices(correct: StepItem, pool: [StepItem]) -> [StepItem]? {
        let correctRU = ruLabel(correct)
        guard !correctRU.isEmpty else { return nil }

        var picks: [StepItem] = [correct]
        var usedLabels: Set<String> = [correctRU]

        let others = pool.filter { $0.order != correct.order }.shuffled()
        for item in others {
            guard picks.count < 4 else { break }
            let lab = ruLabel(item)
            guard !lab.isEmpty, !usedLabels.contains(lab) else { continue }
            usedLabels.insert(lab)
            picks.append(item)
        }

        guard picks.count >= 2 else { return nil }
        picks.shuffle()
        return picks
    }
}
