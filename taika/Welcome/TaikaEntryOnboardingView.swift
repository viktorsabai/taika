//
//  TaikaEntryOnboardingView.swift
//  taika
//
//  Обязательный product-demo после Welcome: motion на макетах экранов.
//

import SwiftUI

struct TaikaEntryOnboardingView: View {
    let onFinished: () -> Void
    let onSkipToStart: () -> Void

    var body: some View {
        TaikaProductDemoPager(
            kind: .appIntro,
            onFinished: onFinished,
            onSkip: onSkipToStart
        )
    }
}

#Preview {
    TaikaEntryOnboardingView(onFinished: {}, onSkipToStart: {})
        .environmentObject(ThemeManager.shared)
}
