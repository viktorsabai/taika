import SwiftUI

/// Обёртка для совместимости: все вызовы `overlay.present(.proCoursePaywall)` открывают новый paywall.
struct PROView: View {
    let courseId: String?
    let reason: ProGateReason
    let onClose: () -> Void

    init(
        courseId: String?,
        reason: ProGateReason = .general,
        initialPage: Int? = nil,
        onClose: @escaping () -> Void
    ) {
        self.courseId = courseId
        // legacy initialPage=2 был «разбор» — маппим в speakerBreakdown, если reason не задан явно
        if let initialPage, initialPage == 2, reason == .general {
            self.reason = .speakerBreakdown
        } else {
            self.reason = reason
        }
        self.onClose = onClose
    }

    var body: some View {
        TaikaPlusPaywallView(courseId: courseId, reason: reason, onClose: onClose)
    }
}

#Preview {
    ZStack {
        Color.black
        PROView(courseId: "course_test", reason: .lockedCourse) {}
    }
}
