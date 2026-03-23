//
//  CourseManager.swift
//  taika
//
//  Created by product on 15.02.2026.
//

import Foundation

@MainActor
final class CourseManager {
    
    static let shared = CourseManager()
    
    private init() {}
    
    private let lessonsManager = LessonsManager.shared
    private let stepManager = StepManager.shared
    
    // MARK: - Aggregation
    
    /// Returns all cards from all lessons of a course
    func allCards(courseId: String) -> [Any] {
        let lessonIds = lessonsManager.lessonIds(for: courseId)
        
        return lessonIds.flatMap { lessonId in
            StepData.shared.items(for: lessonId).map { $0 as Any }
        }
    }
    
    /// Returns only learned (completed) cards from a course
    func learnedCards(courseId: String) -> [Any] {
        let completedLessonIds = lessonsManager.lessonIds(for: courseId)
            .filter { lessonId in
                lessonsManager.progress[courseId]?[lessonId]?.status == .completed
            }
        
        return completedLessonIds.flatMap { lessonId in
            StepData.shared.items(for: lessonId).map { $0 as Any }
        }
    }
    
    /// Returns cards that should be used for game mode at course level
    /// Includes cards from completed lessons only
    func cardsForGame(courseId: String) -> [Any] {
        let completedLessonIds = lessonsManager.lessonIds(for: courseId)
            .filter { lessonId in
                lessonsManager.progress[courseId]?[lessonId]?.status == .completed
            }
        
        return completedLessonIds.flatMap { lessonId in
            StepData.shared.items(for: lessonId).map { $0 as Any }
        }
    }
}
