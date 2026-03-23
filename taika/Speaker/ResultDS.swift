//
//  ResultDS.swift
//  taika
//
//  Created by product on 15.01.2026.
//

import SwiftUI

// result ds: animation-only overlay layer.
// ds draws visuals only; view/manager decide when to show.
// IMPORTANT: no cards, no content duplication. this overlay is a short-lived event.

enum ResultOverlayKind: Equatable {
    case success
    case mismatch
    case neutral
}

struct ResultOverlayV: View {
    let kind: ResultOverlayKind
    let title: String?
    let isLooping: Bool
    let focusRect: CGRect?

    init(
        kind: ResultOverlayKind = .neutral,
        title: String? = nil,
        isLooping: Bool = false,
        focusRect: CGRect? = nil
    ) {
        self.kind = kind
        self.title = title
        self.isLooping = isLooping
        self.focusRect = focusRect
    }

    var body: some View {
        ResultSketchOverlayV(kind: kind, title: title, isLooping: isLooping, focusRect: focusRect)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

// MARK: - sketch doodles overlay (minimal 2d)

private struct ResultSketchOverlayV: View {
    let kind: ResultOverlayKind
    let title: String?
    let isLooping: Bool
    let focusRect: CGRect?

    @State private var fade: CGFloat = 1
    @State private var pulse: CGFloat = 0

    private var dimAlpha: CGFloat {
        switch kind {
        case .success: return 0.11
        case .mismatch: return 0.14
        case .neutral: return 0.10
        }
    }

    private var tint: Color {
        switch kind {
        case .success:
            return Color(red: 1.0, green: 0.55, blue: 0.90) // taika pink-ish
        case .mismatch:
            return Color.white
        case .neutral:
            return Color.white
        }
    }

    private var pillText: String {
        if let t = title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return t.lowercased()
        }
        switch kind {
        case .success: return "круто"
        case .mismatch: return "ещё раз"
        case .neutral: return "ок"
        }
    }

    private var hintText: String? {
        // ultra-short learning hint (kept minimal; view/manager may pass a better one later)
        switch kind {
        case .success:
            return "ударение ок"
        case .mismatch:
            return "чётче гласные"
        case .neutral:
            return nil
        }
    }

    var body: some View {
        ZStack {

            // subtle dim layer
            Color.black
                .opacity(dimAlpha)
                .ignoresSafeArea()

            // centered badge
            VStack(spacing: 8) {
                Text(pillText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tint.opacity(0.18))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                            )
                    )
            }
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }
}


// MARK: - previews

#Preview("result overlay") {
    ZStack {
        LinearGradient(colors: [Color.black, Color.black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        // mock active card
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
            )
            .frame(width: 340, height: 420)
            .position(x: 215, y: 360)

        ResultOverlayV(
            kind: .success,
            title: "совпало",
            isLooping: true,
            focusRect: CGRect(x: 45, y: 150, width: 340, height: 420)
        )
    }
    .frame(width: 430, height: 860)
}

#Preview("result overlay mismatch") {
    ZStack {
        LinearGradient(colors: [Color.black, Color.black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        // mock active card
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.overlay)
            )
            .frame(width: 340, height: 420)
            .position(x: 215, y: 360)

        ResultOverlayV(
            kind: .mismatch,
            title: "не совпало",
            isLooping: true,
            focusRect: CGRect(x: 45, y: 150, width: 340, height: 420)
        )
    }
    .frame(width: 430, height: 860)
}
