//
//  TaikaValueDeck.swift
//  taika
//
//  Единый deck ценностей: About Taika + Plus paywall.
//  Контекстный вход (ProGateReason) выбирает стартовый слайд.
//

import SwiftUI

// MARK: - Gate reason (почему открыли Plus)

enum ProGateReason: String, Equatable, CaseIterable, Identifiable {
    case general
    case speakerBreakdown
    case dailyPicks
    case lockedCourse
    case games
    case personalPath
    case dictionary

    var id: String { rawValue }

    /// Стартовый слайд в Plus-карусели.
    var preferredPlusSlideId: String {
        switch self {
        case .general: return TaikaValueSlideID.speakerAI
        case .speakerBreakdown: return TaikaValueSlideID.speakerAI
        case .dailyPicks: return TaikaValueSlideID.reinforce
        case .lockedCourse: return TaikaValueSlideID.moreCourses
        case .games: return TaikaValueSlideID.practiceUnlimited
        case .personalPath: return TaikaValueSlideID.speakerAI
        case .dictionary: return TaikaValueSlideID.practiceUnlimited
        }
    }

    var heroTitle: String {
        switch self {
        case .general:
            return "Открой следующий шаг"
        case .speakerBreakdown:
            return "Услышь, где сорвался тон"
        case .dailyPicks:
            return "Сегодня ещё 5 карточек"
        case .lockedCourse:
            return "Курс без замка"
        case .games:
            return "Играй, пока запомнишь"
        case .personalPath:
            return "Словарь под рукой"
        case .dictionary:
            return "Словарь → тренировка"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .general:
            return "Речь, тон и практика — без лимитов."
        case .speakerBreakdown:
            return "Разбор произношения после каждой попытки."
        case .dailyPicks:
            return "Расширь разминку: до 10 карточек каждый день."
        case .lockedCourse:
            return "Открой этот курс и все сценарии целиком."
        case .games:
            return "Ошибки не стоп — закрепляй, сколько нужно."
        case .personalPath:
            return "Словарь из спикера — практика без лимитов"
        case .dictionary:
            return "Личный словарь уже есть — Taika+ открывает практику."
        }
    }

    var ctaFallback: String {
        switch self {
        case .speakerBreakdown: return "Открыть разбор"
        case .dailyPicks: return "Расширить разминку"
        case .lockedCourse: return "Открыть курс"
        case .games: return "Открыть игры"
        case .personalPath, .dictionary: return "Открыть Taika+"
        case .general: return "Открыть Taika+"
        }
    }
}

// MARK: - Slide IDs

enum TaikaValueSlideID {
    static let steps = "steps"
    static let speaker = "speaker"
    static let dictionary = "dictionary"
    static let shelf = "shelf"
    static let tone = "tone"
    static let warmup = "warmup"
    static let courses = "courses"
    static let games = "games"
    static let personal = "personal"
    static let sync = "sync"
    /// Paywall plus perks (бриф).
    static let reinforce = "reinforce"
    static let speakerAI = "speaker_ai"
    static let practiceUnlimited = "practice_unlimited"
    static let moreCourses = "more_courses"
}

// MARK: - Slide model

struct TaikaValueSlide: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    /// Короткий бейдж под заголовком слайда (опционально).
    var badge: String? = nil
    /// CTA внутри продающей карточки (карусель разминки / спикера).
    var ctaTitle: String? = nil
}

enum TaikaValueDeck {
    /// About / онбординг — что такое продукт целиком.
    static let about: [TaikaValueSlide] = [
        .init(
            id: TaikaValueSlideID.steps,
            icon: "rectangle.stack.fill",
            title: "Короткие шаги",
            subtitle: "Слова и фразы по урокам — без простыней теории.",
            badge: "уроки"
        ),
        .init(
            id: TaikaValueSlideID.speaker,
            icon: "waveform.circle.fill",
            title: "Спикер и тон",
            subtitle: "Скажи вслух — увидишь, как звучит. Разбор — в Taika+.",
            badge: "речь"
        ),
        .init(
            id: TaikaValueSlideID.dictionary,
            icon: "character.book.closed.fill",
            title: "Свой словарь",
            subtitle: "Фразы из своей речи остаются в Избранном — иконка книги в хедере.",
            badge: "словарь"
        ),
        .init(
            id: TaikaValueSlideID.shelf,
            icon: "heart.fill",
            title: "Полка и разминка",
            subtitle: "Избранное, лайфхаки и ежедневная подборка на Main.",
            badge: "практика"
        )
    ]

    /// «По фразам»: продающие заглушки как в разминке (CTA внутри карточки).
    static let speakerTraining: [TaikaValueSlide] = [
        .init(
            id: "speaker_train_1",
            icon: "mic.fill",
            title: "Закрепи голосом",
            subtitle: "Фразы из урока — скажи вслух и сразу увидишь, как звучит.",
            badge: "закрепление",
            ctaTitle: "выбрать курс"
        ),
        .init(
            id: "speaker_train_2",
            icon: "heart.fill",
            title: "Очередь из избранного",
            subtitle: "Лайкни фразы в шагах — они станут твоей тренировкой здесь.",
            badge: "избранное",
            ctaTitle: "к избранному"
        ),
        .init(
            id: "speaker_train_3",
            icon: "waveform.circle.fill",
            title: "Или скажи сам",
            subtitle: "Скажи любое по-русски — Тайка переведёт и поможет произнести.",
            badge: "рядом",
            ctaTitle: "скажи сам"
        )
    ]

    /// Taika+ paywall — 4 плюшки по брифу.
    static let plus: [TaikaValueSlide] = [
        .init(
            id: TaikaValueSlideID.reinforce,
            icon: "rectangle.stack.fill.badge.plus",
            title: "Больше закреплений",
            subtitle: "Доп. карточки, упражнения и мини-тренировки."
        ),
        .init(
            id: TaikaValueSlideID.speakerAI,
            icon: "waveform.circle.fill",
            title: "Скажи сам",
            subtitle: "Скажи по-русски — Тайка переведёт и поможет проверить произношение."
        ),
        .init(
            id: TaikaValueSlideID.practiceUnlimited,
            icon: "infinity",
            title: "Безлимит по практике",
            subtitle: "Говори и закрепляй сколько нужно — без дневного стопа."
        ),
        .init(
            id: TaikaValueSlideID.moreCourses,
            icon: "books.vertical.fill",
            title: "Больше курсов",
            subtitle: "Сценарии и полные курсы открываются целиком."
        )
    ]

    static func plusStartIndex(for reason: ProGateReason) -> Int {
        let slides = plus
        if let idx = slides.firstIndex(where: { $0.id == reason.preferredPlusSlideId }) {
            return idx
        }
        return 0
    }
}

// MARK: - Carousel UI

struct TaikaValueCarouselView: View {
    let slides: [TaikaValueSlide]
    @Binding var page: Int
    var compact: Bool = false

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.element.id) { idx, slide in
                    slidePage(slide)
                        .tag(idx)
                        .padding(.horizontal, compact ? 4 : 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: compact ? 118 : 140)

            HStack(spacing: 7) {
                ForEach(0..<slides.count, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(
                            i == page
                            ? AnyShapeStyle(theme.currentAccentFill)
                            : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.28))
                        )
                        .frame(width: i == page ? 16 : 7, height: 7)
                        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: page)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func slidePage(_ slide: TaikaValueSlide) -> some View {
        HStack(alignment: .top, spacing: compact ? 12 : 14) {
            ZStack {
                Circle()
                    .fill(PD.ColorToken.chip)
                    .frame(width: compact ? 44 : 52, height: compact ? 44 : 52)
                Image(systemName: slide.icon)
                    .font(.system(size: compact ? 18 : 22, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(slide.title)
                    .font(.system(size: compact ? 16 : 18, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(slide.subtitle)
                    .font(.system(size: compact ? 13 : 14, weight: .regular))
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 14 : 18)
        .background(
            Theme.Surfaces.card(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        )
    }
}
