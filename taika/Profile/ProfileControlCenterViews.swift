// ProfileControlCenterViews.swift
// Taika Profile Control Center — onboarding-derived motion, compact data, native actions.
// Reuses ProfileManager aggregates, PD tokens, ThemeManager and existing legal config.

import SwiftUI
import UIKit

struct ProfileStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var nav: NavigationIntent
    @ObservedObject private var profile = ProfileManager.shared

    @State private var orbPhase: CGFloat = 0

    private var hasActivity: Bool {
        profile.dashboardLearnedCount > 0 ||
        profile.dashboardStreakDays > 0 ||
        profile.activityWeekDays.contains { $0.intensity01 > 0 }
    }

    var body: some View {
        NavigationStack {
            ProfileGlassBackdrop {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        if hasActivity {
                            activeContent
                        } else {
                            emptyContent
                        }
                    }
                    .padding(.horizontal, PD.Spacing.screen)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Твой ритм")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .onAppear {
            profile.refresh()
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                orbPhase = 1
            }
        }
    }

    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                ProfileMotionOrb(phase: orbPhase, reduceMotion: reduceMotion)
                    .frame(height: 170)
                VStack(spacing: 4) {
                    Text("Ты уже в ритме")
                        .font(PD.FontToken.title(24, weight: .bold))
                        .foregroundStyle(PD.ColorToken.text)
                    Text("Твоя практика за последние 7 дней")
                        .font(PD.FontToken.caption(14))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(PD.ColorToken.card.opacity(0.42), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.65), lineWidth: 1))

            HStack(spacing: 10) {
                statsMetric(value: "\(profile.dashboardLearnedCount)", label: "шагов")
                statsMetric(value: "\(profile.dashboardStreakDays)", label: "дней подряд")
                statsMetric(value: profile.dashboardSpeakingScore.map(String.init) ?? "—", label: "Speaker")
            }

            activitySection

            VStack(alignment: .leading, spacing: 10) {
                Text("Что продолжить")
                    .font(PD.FontToken.caption(13, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .textCase(.uppercase)
                Button {
                    nav.requestTab(1)
                    dismiss()
                } label: {
                    profileAction(title: "Продолжить курс", subtitle: "Вернуться к следующему уроку", systemImage: "book.closed")
                }
                .buttonStyle(.plain)
                Button {
                    nav.requestTab(2)
                    dismiss()
                } label: {
                    profileAction(title: "Повторить в Speaker", subtitle: "Потренировать сложные фразы", systemImage: "waveform")
                }
                .buttonStyle(.plain)
            }

            Text("Статистика отражает только твою реальную практику. Здесь нет рейтингов и соревнований.")
                .font(PD.FontToken.caption(12))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                ProfileMotionOrb(phase: orbPhase, reduceMotion: reduceMotion)
                    .frame(height: 180)
                VStack(spacing: 6) {
                    Text("Здесь появится твой прогресс")
                        .font(PD.FontToken.title(22, weight: .bold))
                        .foregroundStyle(PD.ColorToken.text)
                        .multilineTextAlignment(.center)
                    Text("Начни с первого урока — Taika будет бережно собирать историю твоей практики.")
                        .font(PD.FontToken.caption(14))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)
            }
            .frame(maxWidth: .infinity)
            .background(PD.ColorToken.card.opacity(0.42), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.65), lineWidth: 1))

            HStack(spacing: 10) {
                statsMetric(value: "—", label: "уроки")
                statsMetric(value: "—", label: "минуты")
                statsMetric(value: "—", label: "слова")
            }

            Button {
                nav.requestTab(1)
                dismiss()
            } label: {
                Text("Начать первый урок")
                    .font(PD.FontToken.body(16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.currentAccentFill, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                nav.requestTab(2)
                dismiss()
            } label: {
                Text("Открыть Speaker")
                    .font(PD.FontToken.body(15, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    private var activityDaysForDisplay: [PDActivityDay] {
        Array(profile.activityWeekDays.suffix(7))
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Активность")
                .font(PD.FontToken.caption(13, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .textCase(.uppercase)
            activityBars
        }
    }

    private var activityBars: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(activityDaysForDisplay, id: \.key) { day in
                activityBar(for: day)
            }
        }
        .padding(16)
        .background(PD.ColorToken.card.opacity(0.36), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.55), lineWidth: 1))
    }

    private func activityBar(for day: PDActivityDay) -> some View {
        let barHeight: CGFloat = max(10, 18 + CGFloat(day.intensity01) * 54)
        let activeFill = AnyShapeStyle(theme.currentAccentFill)
        let inactiveFill = AnyShapeStyle(PD.ColorToken.stroke.opacity(0.45))
        let fill = day.intensity01 > 0 ? activeFill : inactiveFill

        return VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(fill)
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
            Text(String(day.title.prefix(2)))
                .font(.caption2)
                .foregroundStyle(PD.ColorToken.textSecondary)
        }
    }

    private func statsMetric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(PD.FontToken.title(22, weight: .bold))
                .foregroundStyle(PD.ColorToken.text)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(PD.FontToken.caption(11))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(PD.ColorToken.card.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.48), lineWidth: 1))
    }

    private func profileAction(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.currentAccentFill)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PD.FontToken.body(16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Text(subtitle)
                    .font(PD.FontToken.caption(12))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
        }
        .padding(14)
        .background(PD.ColorToken.card.opacity(0.38), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.5), lineWidth: 1))
    }
}

private struct ProfileMotionOrb: View {
    let phase: CGFloat
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(colors: [Color.white.opacity(0.08), Color.purple.opacity(0.26), Color.pink.opacity(0.18), Color.white.opacity(0.08)], center: .center))
                .frame(width: 112, height: 112)
                .blur(radius: 2)
                .scaleEffect(reduceMotion ? 1 : 0.94 + phase * 0.08)
            Circle()
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                .frame(width: 128, height: 128)
                .rotationEffect(.degrees(reduceMotion ? 0 : Double(phase) * 360))
            Circle()
                .stroke(Color.purple.opacity(0.22), lineWidth: 1)
                .frame(width: 156, height: 156)
                .rotationEffect(.degrees(reduceMotion ? 0 : -Double(phase) * 240))
        }
        .compositingGroup()
        .opacity(0.9)
    }
}

struct ProfileSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        NavigationStack {
            ProfileGlassBackdrop {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ProfileDestinationIntro(
                            eyebrow: "TAIKA CARE",
                            title: "Разберёмся вместе",
                            subtitle: "Помощь должна быть короткой: выбери, что произошло, и мы подскажем следующий шаг."
                        )
                        ProfileGlassRow(title: "Сообщить о проблеме", subtitle: "Опиши, что произошло, и добавь скриншот", systemImage: "exclamationmark.bubble", trailing: "arrow.up.right") {
                            open("https://t.me/taika_support")
                        }
                        .environmentObject(theme)
                        ProfileGlassRow(title: "Задать вопрос", subtitle: "Поможем разобраться с приложением", systemImage: "questionmark.circle", trailing: "arrow.up.right") {
                            open("https://t.me/taika_support")
                        }
                        .environmentObject(theme)
                        ProfileGlassRow(title: "Сайт taikaa.online", subtitle: "Материалы и новости Taika", systemImage: "globe", trailing: "arrow.up.right") {
                            open("https://taikaa.online")
                        }
                        .environmentObject(theme)
                    }
                    .padding(.horizontal, PD.Spacing.screen)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Поддержка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}

struct ProfileLegalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        NavigationStack {
            ProfileGlassBackdrop {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ProfileDestinationIntro(
                            eyebrow: "TAIKA TRUST",
                            title: "Всё прозрачно",
                            subtitle: "Здесь собраны документы о данных, подписке и правилах использования Taika."
                        )
                        ProfileGlassRow(title: "Политика конфиденциальности", subtitle: "Как Taika работает с данными", systemImage: "hand.raised", trailing: "arrow.up.right") {
                            UIApplication.shared.open(TaikaProConfig.Legal.privacyPolicy)
                        }
                        .environmentObject(theme)
                        ProfileGlassRow(title: "Условия использования", subtitle: "Правила доступа к материалам и Taika+", systemImage: "doc.text", trailing: "arrow.up.right") {
                            UIApplication.shared.open(TaikaProConfig.Legal.termsOfUse)
                        }
                        .environmentObject(theme)
                    }
                    .padding(.horizontal, PD.Spacing.screen)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Правовые документы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}


// MARK: - Shared profile destination language

struct ProfileGlassBackdrop<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let content: Content
    @State private var phase: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background.ignoresSafeArea()
            Circle()
                .fill(Color.purple.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 110)
                .opacity(0.18)
                .offset(x: 140, y: -300)
                .scaleEffect(reduceMotion ? 1 : 0.94 + phase * 0.06)
            Circle()
                .fill(Color.pink.opacity(0.16))
                .frame(width: 230, height: 230)
                .blur(radius: 100)
                .opacity(0.14)
                .offset(x: -150, y: 260)
                .scaleEffect(reduceMotion ? 1 : 1.04 - phase * 0.05)
            content
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

struct ProfileGlassRow: View {
    @EnvironmentObject private var theme: ThemeManager
    let title: String
    let subtitle: String?
    let systemImage: String
    let trailing: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.currentAccentFill)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PD.FontToken.body(16, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(PD.FontToken.caption(12))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: trailing ?? "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(PD.ColorToken.card.opacity(0.42), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.62), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ProfileValuesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager

    private let values: [(String, String, String)] = [
        ("Сценарные курсы", "Нужные фразы для жизни в Таиланде — от аренды до разговора с полицией.", "book.closed"),
        ("Speaker", "Переводит твою мысль и помогает спокойно тренировать произношение.", "waveform"),
        ("Игровая практика", "Закрепляет слова и фразы короткими действиями, а не тестами ради тестов.", "gamecontroller"),
        ("Личный ритм", "Собирает твой прогресс и подсказывает следующий полезный шаг.", "circle.dotted.and.circle")
    ]

    var body: some View {
        NavigationStack {
            ProfileGlassBackdrop {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(spacing: 10) {
                            ProfileMotionOrb(phase: 0.35, reduceMotion: true)
                                .frame(height: 120)
                            Text("Taika — твой личный Kun Kru")
                                .font(PD.FontToken.title(26, weight: .bold))
                                .foregroundStyle(PD.ColorToken.text)
                                .multilineTextAlignment(.center)
                            Text("Не просто переводчик. Платформа, которая помогает говорить, понимать и действовать увереннее в Таиланде.")
                                .font(PD.FontToken.caption(14))
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)

                        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                            ProfileGlassRow(title: value.0, subtitle: value.1, systemImage: value.2, trailing: "checkmark") {}
                                .environmentObject(theme)
                        }

                        Text("Смысл · контекст · тон · голос")
                            .font(PD.FontToken.caption(12, weight: .semibold))
                            .foregroundStyle(theme.currentAccentFill)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, PD.Spacing.screen)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Как устроена Taika")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}


struct ProfileDestinationIntro: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(PD.FontToken.caption(11, weight: .semibold))
                .foregroundStyle(PD.ColorToken.accent)
                .tracking(1.2)
            Text(title)
                .font(PD.FontToken.title(26, weight: .bold))
                .foregroundStyle(PD.ColorToken.text)
            Text(subtitle)
                .font(PD.FontToken.caption(14))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}


struct ProfileMoreGlassSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeManager
    let appVersionLabel: String
    @Binding var showResetAllConfirm: Bool
    @Binding var showDebugSheet: Bool
    @Binding var showLegal: Bool

    var body: some View {
        NavigationStack {
            ProfileGlassBackdrop {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ProfileDestinationIntro(
                            eyebrow: "TAIKA SYSTEM",
                            title: "Всё важное рядом",
                            subtitle: "Ссылки, правовые документы и действия с данными — без лишних уровней навигации."
                        )
                        ProfileGlassRow(title: "Сайт taikaa.online", subtitle: "Материалы и новости Taika", systemImage: "globe", trailing: "arrow.up.right") {
                            open("https://taikaa.online")
                        }
                        .environmentObject(theme)
                        ProfileGlassRow(title: "Instagram", subtitle: "Следить за Taika", systemImage: "camera", trailing: "arrow.up.right") {
                            open("https://www.instagram.com/taika.app")
                        }
                        .environmentObject(theme)
                        ProfileGlassRow(title: "Правовые документы", subtitle: "Политика конфиденциальности и условия использования", systemImage: "doc.on.doc", trailing: "chevron.right") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                showLegal = true
                            }
                        }
                        .environmentObject(theme)
                        ProfileVersionRow(version: appVersionLabel)
                        ProfileGlassRow(title: "Сбросить прогресс", subtitle: "Удалить локальный прогресс и избранное", systemImage: "trash", trailing: "chevron.right") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                showResetAllConfirm = true
                            }
                        }
                        .environmentObject(theme)
                        #if DEBUG
                        ProfileGlassRow(title: "Отладка", subtitle: "Только для локальной Debug-сборки", systemImage: "wrench.and.screwdriver", trailing: "chevron.right") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                showDebugSheet = true
                            }
                        }
                        .environmentObject(theme)
                        #endif
                    }
                    .padding(.horizontal, PD.Spacing.screen)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}

private struct ProfileVersionRow: View {
    let version: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "info.circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .frame(width: 26)
            Text("Версия")
                .font(PD.FontToken.body(16, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
            Spacer()
            Text(version)
                .font(.caption.monospacedDigit())
                .foregroundStyle(PD.ColorToken.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(PD.ColorToken.card.opacity(0.32), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.5), lineWidth: 1))
    }
}
