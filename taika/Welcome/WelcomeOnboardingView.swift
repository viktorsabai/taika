//
//  WelcomeOnboardingView.swift
//  taika
//
//  Full-screen onboarding overlay, opened from WelcomeLandingView.
//

import SwiftUI

struct WelcomeOnboardingView: View {
    let onClose: () -> Void

    @EnvironmentObject private var theme: ThemeManager
    @State private var page: Int = 0
    @State private var visible = false
    @State private var dragY: CGFloat = 0

    var body: some View {
        ZStack {
            WelcomeSpaceBackdropView()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.35),
                            Color.black.opacity(0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )

            VStack(spacing: 0) {
                topBarMinimal
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer(minLength: 18)

                headerBlock
                    .padding(.horizontal, 22)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 10)
                    .blur(radius: visible ? 0 : 10)
                    .animation(.spring(response: 0.6, dampingFraction: 0.86), value: visible)

                Spacer(minLength: 18)

                TaikaValueCarouselView(
                    slides: TaikaValueDeck.about,
                    page: $page,
                    compact: false
                )
                .padding(.horizontal, 18)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 18)
                .blur(radius: visible ? 0 : 14)
                .animation(.spring(response: 0.6, dampingFraction: 0.86).delay(0.05), value: visible)

                Text("Свайпни вниз, чтобы закрыть")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.40))
                    .padding(.top, 16)
                    .opacity(visible ? 1 : 0)

                Spacer(minLength: 22)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { visible = true }
        }
        .offset(y: max(0, dragY))
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: dragY)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { v in
                    if v.translation.height > 0 { dragY = v.translation.height }
                }
                .onEnded { v in
                    if v.translation.height > 120 {
                        onClose()
                    } else {
                        dragY = 0
                    }
                }
        )
    }

    private var topBarMinimal: some View {
        HStack {
            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.34)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var headerBlock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Text("tai")
                    .font(.custom("Onmark Trial", size: 40))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text("kAAA")
                    .font(.custom("Onmark Trial", size: 40))
                    .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
            }
            .accessibilityHidden(true)

            Text("Что внутри Taika")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    WelcomeOnboardingView(onClose: {})
        .environmentObject(ThemeManager.shared)
}
