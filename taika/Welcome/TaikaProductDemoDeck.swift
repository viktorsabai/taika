//
//  TaikaProductDemoDeck.swift
//  taika
//
//  Product-demo: value storyboard (entry) + contextual phone tours.
//

import Foundation

// MARK: - Flags

enum TaikaProductDemoFlags {
    static let speakerKey = "taika.demo.speaker.v1"
    static let courseKey = "taika.demo.course.v1"

    /// Debug / QA: сброс entry-флагов + локальный state AppShell.
    static let debugResetOnboardingNotification = Notification.Name("taika.debug.resetOnboarding")

    static var hasSeenSpeaker: Bool {
        UserDefaults.standard.bool(forKey: speakerKey)
    }

    static var hasSeenCourse: Bool {
        UserDefaults.standard.bool(forKey: courseKey)
    }

    static func markSpeakerSeen() {
        UserDefaults.standard.set(true, forKey: speakerKey)
    }

    static func markCourseSeen() {
        UserDefaults.standard.set(true, forKey: courseKey)
    }

#if DEBUG
    static func resetAllForDebug() {
        UserDefaults.standard.removeObject(forKey: speakerKey)
        UserDefaults.standard.removeObject(forKey: courseKey)
        UserDefaults.standard.removeObject(forKey: "taika.demo.flags.migrated.v1")
    }
#endif
}

// MARK: - Kind / stage

enum TaikaProductDemoKind: String, Equatable {
    case appIntro
    case speakerFirst
    case courseFirst

    /// Entry = продающий storyboard; табы = короткий product-tour.
    var isStoryboard: Bool { self == .appIntro }

    var finishCTA: String {
        switch self {
        case .appIntro: return "Выбрать старт"
        case .speakerFirst: return "Попробовать"
        case .courseFirst: return "К курсам"
        }
    }
}

enum TaikaProductDemoStage: String, Equatable {
    // Entry storyboard
    case phraseHero
    case learnPipeline
    case reinforceWays
    case speakerAI

    // Contextual phone tours
    case speakerVoiceOrText
    case speakerPreviewSave
    case speakerPractice
    case courseBase
    case courseScenarios
    case courseLesson
}

struct TaikaProductDemoScene: Identifiable, Equatable {
    let id: String
    let stepLabel: String?
    let title: String
    let subtitle: String
    let stage: TaikaProductDemoStage
}

enum TaikaProductDemoDeck {
    /// Первый вход: зачем / как учиться / чем закреплять / как говорить.
    /// «С чего начнём?» — отдельный QuickStart после.
    static let appIntro: [TaikaProductDemoScene] = [
        .init(
            id: "story_1",
            stepLabel: "1",
            title: "Тайский, который пригодится сегодня",
            subtitle: "Короткие фразы для жизни: смысл, произношение и тоны — без страха перед письмом.",
            stage: .phraseHero
        ),
        .init(
            id: "story_2",
            stepLabel: "2",
            title: "Учишь → закрепляешь → говоришь",
            subtitle: "Одна фраза проходит весь путь — не разовый перевод, а самообучение.",
            stage: .learnPipeline
        ),
        .init(
            id: "story_3",
            stepLabel: "3",
            title: "Закрепляй по-своему",
            subtitle: "Разминка, игры, спикер, словарь — выбираешь, как оставить фразу в памяти.",
            stage: .reinforceWays
        ),
        .init(
            id: "story_4",
            stepLabel: "4",
            title: "Скажи по-русски — начни говорить",
            subtitle: "Taika переведёт и поможет произнести. Помощник рядом, ответ — твой.",
            stage: .speakerAI
        )
    ]

    static let speakerFirst: [TaikaProductDemoScene] = [
        .init(
            id: "demo_spk_1",
            stepLabel: nil,
            title: "Голосом или текстом",
            subtitle: "Один pipeline — два способа сказать фразу.",
            stage: .speakerVoiceOrText
        ),
        .init(
            id: "demo_spk_2",
            stepLabel: nil,
            title: "Сначала проверь — потом сохрани",
            subtitle: "Превью → лента и словарь.",
            stage: .speakerPreviewSave
        ),
        .init(
            id: "demo_spk_3",
            stepLabel: nil,
            title: "Сразу потренируй голос",
            subtitle: "Сказал → услышал → запомнил.",
            stage: .speakerPractice
        )
    ]

    static let courseFirst: [TaikaProductDemoScene] = [
        .init(
            id: "demo_crs_1",
            stepLabel: nil,
            title: "База — фундамент",
            subtitle: "Система: от простого к нужному.",
            stage: .courseBase
        ),
        .init(
            id: "demo_crs_2",
            stepLabel: nil,
            title: "Сценарии — жизнь",
            subtitle: "7-Eleven, такси, рынок.",
            stage: .courseScenarios
        ),
        .init(
            id: "demo_crs_3",
            stepLabel: nil,
            title: "Отмечай — вернёшься в Спикер",
            subtitle: "Начни с «Приветствие».",
            stage: .courseLesson
        )
    ]

    static func scenes(for kind: TaikaProductDemoKind) -> [TaikaProductDemoScene] {
        switch kind {
        case .appIntro: return appIntro
        case .speakerFirst: return speakerFirst
        case .courseFirst: return courseFirst
        }
    }
}
