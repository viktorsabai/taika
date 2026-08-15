//
//  OverlayPresenter.swift
//  taika
//
//  Created by product on 13.12.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class OverlayPresenter: ObservableObject {

    static let shared = OverlayPresenter()

    enum Overlay: Equatable {
        // search (ui + data)
        case search

        // calendar (data only)
        case calendarAdd(Date)
        case calendarSummary(Date)

        /// Подборка курсов «Кун Кру»: приложение само предлагает курсы для ретеншна (без выбора дня)
        case kunKruSuggestions

        // quickstart loading (ui only)
        case randomCourseLoading

        // pro gating (data only)
        case proCoursePaywall(courseId: String, reason: ProGateReason)
        /// PRO paywall from Speaker "получить разбор" (сквозной процесс завлечения на разбор)
        case speakerPaywall

        // game console (ui only – mode picker)
        case gameConsole(courseId: String, lessonId: String?)

        // concrete game flow (navigation-driven, not overlay-driven)
        case game(courseId: String, lessonId: String, gameType: HomeGameType)

        // EPIC 2: header-driven overlays
        case courseFilters
        case courseSearchAndFilters  // unified: search + filters for Course tab
        /// Сценарий создания персонального курса (Pro: умный спикер → словарь → урок).
        case personalCourseCreate
        case speakerFilters
        /// Режим + выбор курсов для сборки очереди (вместо чипов на экране Спикера).
        case speakerCourses
        /// Лимит попыток спикера на сегодня (не фильтры режима).
        case speakerAttempts
        case voiceSettings
        case gamePark
        case gameParkFromFavorites
        case favoritesFilters
        /// Поиск по избранным фразам (вкладка «Карточки»).
        case favoritesSearch
        /// Превью курса (описание + кнопка «Открыть курс»), открывается по тапу на иконку инфо на карточке.
        case courseInfoPreview(courseId: String)

        /// Подтверждение сброса прогресса курса (тот же chrome, что у PRO).
        case courseResetConfirm(courseId: String)
        /// Подтверждение сброса прогресса одного урока (из StepView).
        case lessonResetConfirm(courseId: String, lessonId: String)

        // theme / accent (ui only)
        case accentPicker

        /// Мягкое окно «Закрепи результат» — привязка аккаунта (bottom sheet).
        case authSoftWall(masteryPercent: Int, streakDays: Int)

        /// Микро-шаг «разбор тонов» перед paywall (один раз).
        case speakerToneAha(courseId: String, reason: ProGateReason, fromSpeakerPaywall: Bool)

        /// First-visit tip: Спикер (black-glass, не fullscreen Welcome).
        case speakerFirstTip
        /// First-visit tip: Курсы.
        case courseFirstTip
    }

    @Published private(set) var overlay: Overlay? = nil

    // MARK: - search state

    @Published var searchQuery: String = ""

    @Published private(set) var searchCourseIds: [String] = []
    @Published private(set) var searchLessonIds: [String] = []

    @Published private(set) var isSearching: Bool = false

    private var searchIndex: SearchIndex? = nil
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        // debounce search so typing does not thrash the main view tree
        $searchQuery
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] q in
                self?.performSearch(query: q)
            }
            .store(in: &cancellables)
    }

    /// Configure search index once (e.g. after Course/Lessons JSON are loaded).
    func configureSearchIndex(courses: [SearchIndex.Entry], lessons: [SearchIndex.Entry]) {
        self.searchIndex = SearchIndex(courses: courses, lessons: lessons)
        // re-run current query against the new index
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        performSearch(query: q)
    }

    func resetSearchState() {
        searchQuery = ""
        searchCourseIds = []
        searchLessonIds = []
        isSearching = false
    }

    var isPresented: Bool { overlay != nil }

    var isSearchPresented: Bool {
        if case .search = overlay { return true }
        return false
    }

    func presentSearch() {
        resetSearchState()
        overlay = .search
    }

    func presentAccentPicker() {
        overlay = .accentPicker
    }

    func present(_ overlay: Overlay) {
        // Один раз перед paywall: интерактивный разбор тонов (Sprint B).
        if SpeakerToneAhaState.shouldShowBeforePaywall {
            switch overlay {
            case .speakerPaywall:
                self.overlay = .speakerToneAha(courseId: "", reason: .speakerBreakdown, fromSpeakerPaywall: true)
                return
            case .proCoursePaywall(let courseId, let reason):
                self.overlay = .speakerToneAha(courseId: courseId, reason: reason, fromSpeakerPaywall: false)
                return
            default:
                break
            }
        }
        self.overlay = overlay
    }

    /// Plus paywall с контекстом (карусель стартует с нужного слайда).
    func presentPro(reason: ProGateReason = .general, courseId: String = "") {
        present(.proCoursePaywall(courseId: courseId, reason: reason))
    }

    /// Онбординг: оффер без микро-шага тонов (aha остаётся на живом Спикере).
    func presentProDirect(reason: ProGateReason = .general) {
        overlay = .proCoursePaywall(courseId: "", reason: reason)
    }

    func dismiss() {
        if isSearchPresented {
            resetSearchState()
        }
        overlay = nil
    }

    // MARK: - search implementation

    struct SearchIndex: Sendable {
        struct Entry: Sendable {
            let id: String
            let haystack: String

            init(id: String, haystack: String) {
                self.id = id
                self.haystack = SearchIndex.normalize(haystack)
            }
        }

        let courses: [Entry]
        let lessons: [Entry]

        init(courses: [Entry], lessons: [Entry]) {
            self.courses = courses
            self.lessons = lessons
        }

        static func normalize(_ s: String) -> String {
            // keep it fast and locale-agnostic
            s.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
        }
    }

    private func performSearch(query raw: String) {
        guard isSearchPresented else { return }

        let q = SearchIndex.normalize(raw)
        guard let idx = searchIndex else {
            // no index yet – keep empty results, but do not thrash
            searchCourseIds = []
            searchLessonIds = []
            isSearching = false
            return
        }

        guard q.count >= 2 else {
            // treat short queries as "empty" to avoid noisy matches
            searchCourseIds = []
            searchLessonIds = []
            isSearching = false
            return
        }

        let courses = idx.courses
        let lessons = idx.lessons

        isSearching = true

        Task.detached(priority: .userInitiated) {
            let courseMatches = courses
                .filter { $0.haystack.contains(q) }
                .prefix(24)
                .map { $0.id }

            let lessonMatches = lessons
                .filter { $0.haystack.contains(q) }
                .prefix(24)
                .map { $0.id }

            let courseIds = Array(courseMatches)
            let lessonIds = Array(lessonMatches)

            await MainActor.run {
                // only apply if we are still in search overlay and query hasn't changed
                guard self.isSearchPresented else { return }
                guard SearchIndex.normalize(self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)) == q else { return }

                self.searchCourseIds = courseIds
                self.searchLessonIds = lessonIds
                self.isSearching = false
            }
        }
    }
}
