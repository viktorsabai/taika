import Foundation

/// Persists last-focused carousel index for course/lesson reels (restore on back navigation).
enum CarouselScrollPersistence {
    private static let baseKey = "taika.carousel.courseBase.index"
    private static let allKey = "taika.carousel.courseAll.index"
    private static func clampedNonNegative(_ value: Int, upperExclusive: Int) -> Int {
        guard upperExclusive > 0 else { return 0 }
        let lowerBounded = Swift.max(0, value)
        return Swift.min(lowerBounded, upperExclusive - 1)
    }
    private static func canonicalCourseKey(_ courseId: String) -> String {
        courseId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
    }

    static func baseIndex(max: Int) -> Int {
        guard max > 0 else { return 0 }
        let v = UserDefaults.standard.integer(forKey: baseKey)
        return clampedNonNegative(v, upperExclusive: max)
    }

    static func setBaseIndex(_ index: Int) {
        UserDefaults.standard.set(Swift.max(0, index), forKey: baseKey)
    }

    static func allCoursesIndex(max: Int) -> Int {
        guard max > 0 else { return 0 }
        let v = UserDefaults.standard.integer(forKey: allKey)
        return clampedNonNegative(v, upperExclusive: max)
    }

    static func setAllCoursesIndex(_ index: Int) {
        UserDefaults.standard.set(Swift.max(0, index), forKey: allKey)
    }

    private static func lessonKey(courseId: String) -> String {
        "taika.carousel.lessons.\(canonicalCourseKey(courseId))"
    }

    static func lessonReelIndex(courseId: String, max: Int) -> Int {
        guard max > 0 else { return 0 }
        let v = UserDefaults.standard.integer(forKey: lessonKey(courseId: courseId))
        return clampedNonNegative(v, upperExclusive: max)
    }

    static func setLessonReelIndex(courseId: String, index: Int) {
        UserDefaults.standard.set(Swift.max(0, index), forKey: lessonKey(courseId: courseId))
    }
}
