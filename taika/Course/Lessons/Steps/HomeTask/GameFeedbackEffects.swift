//
//  GameFeedbackEffects.swift
//  taika
//
//  Общие тайминги, тактильные отклики и визуальные эффекты для игр домашнего задания
//  (матч / дисматч). Логика раундов остаётся в менеджерах — здесь только «сок» и константы.
//

import SwiftUI
import UIKit

// MARK: - Тайминги и кривые

public enum TaikaGameFeedbackMotion {

    /// Пауза перед первой фазой «успех», чтобы смена экрана успела зарегистрироваться.
    public static let matchIntroDelayNanoseconds: UInt64 = 160_000_000
    public static let staggerMeaningAfterHeroNanoseconds: UInt64 = 260_000_000
    public static let staggerFooterAfterMeaningNanoseconds: UInt64 = 140_000_000

    public static var matchHeroSpring: Animation {
        .spring(response: 0.78, dampingFraction: 0.88)
    }

    public static var matchSparkleEase: Animation {
        .easeOut(duration: 1.05)
    }

    public static var matchMeaningEase: Animation {
        .easeOut(duration: 0.55)
    }

    public static var matchFooterEase: Animation {
        .easeOut(duration: 0.5)
    }

    /// Выбор карточки в «Найди пару».
    public static var pairSelectSpring: Animation {
        .spring(response: 0.22, dampingFraction: 0.85)
    }

    /// Состояние «ошибка» на карточке (мини-карта).
    public static var cardWrongSpring: Animation {
        .spring(response: 0.20, dampingFraction: 0.78)
    }

    /// Подсветка выбранной карточки (flip).
    public static var cardSelectSpring: Animation {
        .spring(response: 0.28, dampingFraction: 0.78)
    }

    public static let mismatchShakeDuration: Double = 0.22
    public static let mismatchShakeShakes: CGFloat = 3
    public static let mismatchShakeAmplitude: CGFloat = 6
}

// MARK: - Тактильно

public enum TaikaGameFeedbackHaptics {

    public static func matchSuccess() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public static func mismatch() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// Верный ответ в квизе / сборке (без дублирующего light impact — только системный «success»).
    public static func answerCorrect() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Встряска (GeometryEffect)

public struct TaikaGameShakeGeometryEffect: GeometryEffect {
    public var pct: CGFloat
    public var amplitude: CGFloat
    public var shakes: CGFloat

    public init(
        pct: CGFloat,
        amplitude: CGFloat = TaikaGameFeedbackMotion.mismatchShakeAmplitude,
        shakes: CGFloat = TaikaGameFeedbackMotion.mismatchShakeShakes
    ) {
        self.pct = pct
        self.amplitude = amplitude
        self.shakes = shakes
    }

    public var animatableData: CGFloat {
        get { pct }
        set { pct = newValue }
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = sin(pct * .pi * shakes) * amplitude
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

public extension View {
    func taikaGameShake(
        amount: CGFloat,
        amplitude: CGFloat = TaikaGameFeedbackMotion.mismatchShakeAmplitude,
        shakes: CGFloat = TaikaGameFeedbackMotion.mismatchShakeShakes
    ) -> some View {
        modifier(TaikaGameShakeModifier(pct: amount, amplitude: amplitude, shakes: shakes))
    }
}

private struct TaikaGameShakeModifier: ViewModifier {
    var pct: CGFloat
    var amplitude: CGFloat
    var shakes: CGFloat

    func body(content: Content) -> some View {
        content.modifier(TaikaGameShakeGeometryEffect(pct: pct, amplitude: amplitude, shakes: shakes))
    }
}

// MARK: - Одноразовая встряска при появлении (дисматч-баннер и т.п.)

public struct TaikaGameShakeOnceOnAppear: ViewModifier {
    @State private var phase: CGFloat = 0

    public init() {}

    public func body(content: Content) -> some View {
        content
            .taikaGameShake(amount: phase)
            .onAppear {
                withAnimation(.linear(duration: TaikaGameFeedbackMotion.mismatchShakeDuration)) {
                    phase = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + TaikaGameFeedbackMotion.mismatchShakeDuration + 0.02) {
                    phase = 0
                }
            }
    }
}

public extension View {
    func taikaGameShakeOnceOnAppear() -> some View {
        modifier(TaikaGameShakeOnceOnAppear())
    }
}

// MARK: - Лёгкий «пульс» при успехе (баннер, чип)

public struct TaikaGameSuccessPulseModifier: ViewModifier {
    @State private var pulse: CGFloat = 0
    private let active: Bool

    public init(active: Bool) {
        self.active = active
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(1 + 0.05 * pulse)
            .onAppear {
                guard active else { return }
                pulse = 0
                withAnimation(TaikaGameFeedbackMotion.matchHeroSpring) {
                    pulse = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        pulse = 0
                    }
                }
            }
    }
}

public extension View {
    func taikaGameSuccessPulse(active: Bool) -> some View {
        modifier(TaikaGameSuccessPulseModifier(active: active))
    }
}

// MARK: - Искры вокруг «якоря» (успех)

public struct TaikaGameSparkleBurst: View {
    public var progress: CGFloat
    public var accentColor: Color

    public init(progress: CGFloat, accentColor: Color) {
        self.progress = progress
        self.accentColor = accentColor
    }

    public var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                sparkleDot(index: i)
            }
        }
        .accessibilityHidden(true)
    }

    private func sparkleDot(index i: Int) -> some View {
        let t = Double(i) / 16.0 * Double.pi * 2 + 0.15
        let radius = 26.0 + Double(i % 7) * 11
        let p = Double(progress)
        let ox = CGFloat(cos(t) * radius * p)
        let oy = CGFloat(sin(t) * radius * p - p * 28)
        let side = CGFloat(3 + (i % 4))
        let fillOpacity = CGFloat(0.28 + Double(i % 5) * 0.1)
        let fadeOut = CGFloat(1) - progress * CGFloat(0.55)
        return Circle()
            .fill(accentColor.opacity(fillOpacity))
            .frame(width: side, height: side)
            .offset(x: ox, y: oy)
            .opacity(fadeOut)
    }
}

// MARK: - Кнопка-вариант с лёгким нажатием (квиз)

public struct TaikaGameChoiceButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Стагер успеха (Audio Recall и др.)

@MainActor
public enum TaikaGameMatchStagger {

    public static func run(
        bounceTick: @escaping () -> Void,
        setHero: @escaping (CGFloat) -> Void,
        setSparkle: @escaping (CGFloat) -> Void,
        setMeaning: @escaping (CGFloat) -> Void,
        setFooter: @escaping (CGFloat) -> Void
    ) async {
        try? await Task.sleep(nanoseconds: TaikaGameFeedbackMotion.matchIntroDelayNanoseconds)
        bounceTick()
        withAnimation(TaikaGameFeedbackMotion.matchHeroSpring) {
            setHero(1)
        }
        withAnimation(TaikaGameFeedbackMotion.matchSparkleEase) {
            setSparkle(1)
        }
        try? await Task.sleep(nanoseconds: TaikaGameFeedbackMotion.staggerMeaningAfterHeroNanoseconds)
        withAnimation(TaikaGameFeedbackMotion.matchMeaningEase) {
            setMeaning(1)
        }
        try? await Task.sleep(nanoseconds: TaikaGameFeedbackMotion.staggerFooterAfterMeaningNanoseconds)
        withAnimation(TaikaGameFeedbackMotion.matchFooterEase) {
            setFooter(1)
        }
    }
}
