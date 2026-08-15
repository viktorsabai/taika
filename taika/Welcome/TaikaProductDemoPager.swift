//
//  TaikaProductDemoPager.swift
//  taika
//
//  Entry = продающий storyboard; Speaker/Course = короткий product-tour.
//

import SwiftUI

struct TaikaProductDemoPager: View {
    let kind: TaikaProductDemoKind
    let onFinished: () -> Void
    let onSkip: () -> Void
    var compactTop: Bool = false

    @ObservedObject private var theme = ThemeManager.shared
    @State private var page = 0
    @State private var appeared = false
    @State private var contentTick = 0
    @State private var dragX: CGFloat = 0

    private var slides: [TaikaProductDemoScene] { TaikaProductDemoDeck.scenes(for: kind) }
    private var isLast: Bool { page >= slides.count - 1 }
    private var storyboard: Bool { kind.isStoryboard }

    var body: some View {
        ZStack {
            WelcomeSpaceBackdropView()
            accentOrbs

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, compactTop ? 4 : 8)

                Group {
                    if storyboard {
                        storyboardStage
                    } else {
                        tourStage
                    }
                }
                .padding(.horizontal, storyboard ? 20 : 16)
                .padding(.top, storyboard ? 18 : 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .animation(.spring(response: 0.55, dampingFraction: 0.86), value: appeared)

                pageDots
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                primaryCTA
                    .padding(.horizontal, 20)

                if storyboard {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSkip()
                    } label: {
                        Text("Пропустить")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, compactTop ? 8 : 12)
                } else {
                    Color.clear.frame(height: compactTop ? 14 : 22)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                appeared = true
            }
        }
        .onChange(of: page) { _, _ in
            contentTick += 1
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        .gesture(swipeGesture)
    }

    private var accentOrbs: some View {
        ZStack {
            Circle()
                .fill(theme.currentAccentTintColor.opacity(0.3))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -60, y: -140)
            Circle()
                .fill(theme.currentAccentTintColor.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 120, y: 240)
        }
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            if storyboard, let step = slides[page].stepLabel {
                ZStack {
                    Circle()
                        .stroke(AnyShapeStyle(theme.currentAccentFill.opacity(0.55)), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                    Text(step)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Text("tai")
                    .font(.custom("Onmark Trial", size: storyboard ? 24 : 22))
                    .foregroundStyle(.white.opacity(0.92))
                Text("kAAA")
                    .font(.custom("Onmark Trial", size: storyboard ? 24 : 22))
                    .foregroundStyle(AnyShapeStyle(theme.currentAccentFill))
            }

            Spacer(minLength: 8)

            if storyboard {
                Color.clear.frame(width: 32, height: 32)
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSkip()
                } label: {
                    Text("Пропустить")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.black.opacity(0.38)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Продающий онбординг: headline → живой visual → subtitle.
    private var storyboardStage: some View {
        let slide = slides[page]
        return VStack(spacing: 0) {
            Text(slide.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .id("title-\(slide.id)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))

            TaikaProductDemoStageView(stage: slide.stage, tick: contentTick, presentation: .storyboard)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 18)
                .id("stage-\(slide.id)-\(contentTick)")

            Text(slide.subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
                .padding(.horizontal, 4)
                .id("sub-\(slide.id)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: dragX)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: page)
    }

    /// Contextual tour: компактный title + phone scene.
    private var tourStage: some View {
        let slide = slides[page]
        return VStack(spacing: 12) {
            Text(slide.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .id("title-\(slide.id)")

            TaikaProductDemoStageView(stage: slide.stage, tick: contentTick, presentation: .productTour)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id("stage-\(slide.id)-\(contentTick)")

            Text(slide.subtitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .id("sub-\(slide.id)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: dragX)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: page)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(
                        i == page
                        ? AnyShapeStyle(theme.currentAccentFill)
                        : AnyShapeStyle(Color.white.opacity(0.22))
                    )
                    .frame(width: i == page ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: page)
            }
        }
    }

    private var primaryCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if isLast {
                onFinished()
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    page += 1
                }
            }
        } label: {
            Text(isLast ? kind.finishCTA : "Дальше")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(white: 0.1))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(theme.currentAccentFill))
                .overlay(
                    Capsule()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.16), .clear], startPoint: .top, endPoint: .center))
                        .blendMode(.plusLighter)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { v in
                dragX = v.translation.width * 0.35
            }
            .onEnded { v in
                let dx = v.translation.width
                withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                    dragX = 0
                    if dx < -56, page < slides.count - 1 {
                        page += 1
                    } else if dx > 56, page > 0 {
                        page -= 1
                    }
                }
            }
    }
}

// MARK: - Contextual overlay

struct TaikaContextualDemoOverlay: View {
    let kind: TaikaProductDemoKind
    let onDismiss: () -> Void

    var body: some View {
        TaikaProductDemoPager(
            kind: kind,
            onFinished: {
                markSeen()
                onDismiss()
            },
            onSkip: {
                markSeen()
                onDismiss()
            },
            compactTop: true
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func markSeen() {
        switch kind {
        case .speakerFirst: TaikaProductDemoFlags.markSpeakerSeen()
        case .courseFirst: TaikaProductDemoFlags.markCourseSeen()
        case .appIntro: break
        }
    }
}
