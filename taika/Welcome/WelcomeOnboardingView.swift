//
//  WelcomeOnboardingView.swift
//  taika
//
//  Legacy wrapper: единый value-storyboard = TaikaEntryOnboardingView.
//

import SwiftUI

struct WelcomeOnboardingView: View {
    let onClose: () -> Void

    var body: some View {
        TaikaEntryOnboardingView(
            onFinished: onClose,
            onSkipToStart: onClose
        )
    }
}

#Preview {
    WelcomeOnboardingView(onClose: {})
        .environmentObject(ThemeManager.shared)
}
