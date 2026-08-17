//
//  NavigationIntent.swift
//  taika
//
//  Created by product on 15.12.2025.
//

import Foundation
import SwiftUI

// MARK: - Lesson presentation (global stack / N1)

/// Параметры `StepView` при открытии урока через `NavigationIntent.path` (единый стек AppShell).
public struct LessonRoutePresentation: Hashable {
    public var startIndex: Int?
    public var scope: InteractionScope
    public var showKinds: [SDStepItem.Kind]?
    public var layoutCardsOnly: Bool
    public var allowLearning: Bool
    public var showBottomProgress: Bool
    public var showInternalHeader: Bool
    public var useInternalBackground: Bool

    public static let canonical = LessonRoutePresentation(
        startIndex: nil,
        scope: .full,
        showKinds: nil,
        layoutCardsOnly: false,
        allowLearning: true,
        showBottomProgress: true,
        showInternalHeader: false,
        useInternalBackground: true
    )

    /// Полноэкранный урок из списка «Показать всё» (push в общем стеке — как канонический урок, с `PD.ColorToken.background` в `StepView`).
    public static func favoritesAllList(startIndex: Int, hacksOnly: Bool) -> LessonRoutePresentation {
        LessonRoutePresentation(
            startIndex: startIndex,
            scope: .full,
            showKinds: hacksOnly ? [.tip] : [.word, .phrase, .casual],
            layoutCardsOnly: false,
            allowLearning: true,
            showBottomProgress: true,
            showInternalHeader: false,
            useInternalBackground: true
        )
    }

    /// Персональная подборка Pro из словаря умного спикера (`user_dict` / `personal_pack`).
    public static func personalPack(startIndex: Int = 0) -> LessonRoutePresentation {
        LessonRoutePresentation(
            startIndex: startIndex,
            scope: .full,
            showKinds: [.word, .phrase, .casual],
            layoutCardsOnly: false,
            allowLearning: true,
            showBottomProgress: true,
            showInternalHeader: false,
            useInternalBackground: true
        )
    }
}

/// a tiny, app-wide navigation signal.
///
/// goal: views/managers can *request* navigation without directly owning navigation state.
/// actual navigation is performed by the root view that observes `route`.
@MainActor
public final class NavigationIntent: ObservableObject {

    public enum Route: Hashable {
        case lessons(courseId: String)
        case lesson(courseId: String, lessonId: String, presentation: LessonRoutePresentation)
        case course(courseId: String)
        case game(courseId: String, lessonId: String?, gameType: String)
        /// Список «Показать всё» на табе избранного (глобальный push).
        case favoritesAll(initialFilter: FDK)
        /// Полноценный личный словарь; не является Favorites filter.
        case dictionary

        public static func lessons(_ courseId: String) -> Route {
            .lessons(courseId: courseId)
        }

        public static func game(_ courseId: String, _ lessonId: String?, _ gameType: String) -> Route {
            .game(courseId: courseId, lessonId: lessonId, gameType: gameType)
        }
    }

    @Published public var path: [Route] = []

    /// Tab index to switch to from shell (0=Main, 1=Course, 2=Speaker, 3=Favorite, 4=Profile). Set by requestTab; shell clears after applying.
    @Published public var requestedTab: Int?

    public init() {}

    /// Request root to switch to the given tab (e.g. Speaker=2). AppShell should observe and clear after applying.
    public func requestTab(_ index: Int) {
        requestedTab = index
    }

    public func clearRequestedTab() {
        requestedTab = nil
    }

    /// Открыть корневой каталог курсов на нужной вкладке (без push `__all__`).
    public func openCourseCatalog(tab: CourseScreenTab = .scenarios) {
        CourseCatalogTabState.shared.request(tab)
        popToRoot()
        requestTab(1)
    }

    public func go(_ route: Route) {
        if case let .favoritesAll(initialFilter) = route {
            FavoritesFilterState.shared.selectedTab = FavoriteScreenTab(fdk: initialFilter)
            requestTab(3)
            return
        }
        path.append(route)
    }

    public func set(_ route: Route) {
        path = [route]
    }

    public func popToRoot() {
        path.removeAll(keepingCapacity: true)
    }

    public func reset() {
        path.removeAll()
    }
}
