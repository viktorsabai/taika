//
//  WelcomeSpaceBackdropView.swift
//  taika
//
//  Универсальный нейтральный фон (без привязки к теме/акценту).
//

import SwiftUI

struct WelcomeSpaceBackdropView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.07),
                        Color(red: 0.02, green: 0.02, blue: 0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Мягкие нейтральные “свечения” (без цвета темы)
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.22, y: 0.35),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.75
                )
                .blur(radius: 26)

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.07),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.70, y: 0.55),
                    startRadius: 0,
                    endRadius: max(w, h) * 0.85
                )
                .blur(radius: 28)

                // Лёгкая вуаль для читаемости текста (нейтрально).
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.screen)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    WelcomeSpaceBackdropView()
}
