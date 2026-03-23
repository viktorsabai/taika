//
//  NavigationIntent.swift
//  taika
//
//  Created by product on 15.12.2025.
//

import Foundation
import SwiftUI

/// a tiny, app-wide navigation signal.
///
/// goal: views/managers can *request* navigation without directly owning navigation state.
/// actual navigation is performed by the root view that observes `route`.
@MainActor
public final class NavigationIntent: ObservableObject {

    public enum Route: Hashable {
        case lessons(courseId: String)
        case lesson(courseId: String, lessonId: String)
        case course(courseId: String)
        case game(courseId: String, lessonId: String?, gameType: String)

        // MARK: - legacy aliases (keep call-sites compiling)

        @available(*, deprecated, message: "use .lessons(courseId:) instead")
        public static func steps(courseId: String) -> Route {
            .lessons(courseId: courseId)
        }

        @available(*, deprecated, message: "use .lesson(courseId:lessonId:) instead")
        public static func step(courseId: String, lessonId: String) -> Route {
            .lesson(courseId: courseId, lessonId: lessonId)
        }

        // MARK: - unlabeled convenience factories

        public static func lessons(_ courseId: String) -> Route {
            .lessons(courseId: courseId)
        }

        public static func lesson(_ courseId: String, _ lessonId: String) -> Route {
            .lesson(courseId: courseId, lessonId: lessonId)
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

    public func go(_ route: Route) {
        // important: keep `path` elements homogeneous (Route only)
        path.append(route)
    }

    /// replace the whole stack with a single route (useful to avoid multiple updates per frame)
    public func set(_ route: Route) {
        path = [route]
    }

    /// convenience for returning to root without touching other state
    public func popToRoot() {
        path.removeAll(keepingCapacity: true)
    }

    public func reset() {
        path.removeAll()
    }
}
