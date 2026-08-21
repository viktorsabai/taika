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
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(PD.ColorToken.text)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(PD.ColorToken.stroke.opacity(0.55), lineWidth: 1))
                    }
                    .accessibilityLabel("Назад")
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

    private var rhythmPercent: Int {
        guard !profile.activityWeekDays.isEmpty else { return 0 }
        let total = profile.activityWeekDays.reduce(0.0) { $0 + $1.intensity01 }
        return min(100, max(0, Int((total / Double(profile.activityWeekDays.count) * 100).rounded())))
    }

    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            rhythmHero
            rhythmMetrics
            activitySection
            continueSection
            Button {
                nav.requestTab(1)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("Продолжить практику")
                    Spacer()
                }
                .font(PD.FontToken.body(16, weight: .semibold))
                .foregroundStyle(PD.ColorToken.background)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(theme.currentAccentFill, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var rhythmHero: some View {
        ZStack(alignment: .leading) {
            ProfileRhythmRing(percent: rhythmPercent, phase: orbPhase, reduceMotion: reduceMotion, accent: AnyShapeStyle(theme.currentAccentFill))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 14)
            VStack(alignment: .leading, spacing: 8) {
                Text("Ты уже\nв ритме")
                    .font(PD.FontToken.title(31, weight: .bold))
                    .foregroundStyle(PD.ColorToken.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Последние 7 дней")
                    .font(PD.FontToken.caption(15))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            .padding(.horizontal, 22)
        }
        .frame(height: 238)
        .background(PD.ColorToken.card.opacity(0.46), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.68), lineWidth: 1))
    }

    private var rhythmMetrics: some View {
        VStack(spacing: 0) {
            rhythmMetricRow(title: "Шаги", subtitle: "Закреплённые учебные шаги", value: "\(profile.dashboardLearnedCount)", image: "book.closed")
            Divider().overlay(PD.ColorToken.stroke.opacity(0.45))
            rhythmMetricRow(title: "Дни практики", subtitle: "Возвращения за последние 7 дней", value: "\(profile.dashboardStreakDays)", image: "clock")
            Divider().overlay(PD.ColorToken.stroke.opacity(0.45))
            rhythmMetricRow(title: "Голос", subtitle: "Средняя оценка Speaker", value: profile.dashboardSpeakingScore.map(String.init) ?? "—", image: "waveform")
        }
        .padding(.horizontal, 16)
        .background(PD.ColorToken.card.opacity(0.34), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.54), lineWidth: 1))
    }

    private func rhythmMetricRow(title: String, subtitle: String, value: String, image: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: image)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.currentAccentFill)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PD.FontToken.body(16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Text(subtitle)
                    .font(PD.FontToken.caption(12))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            Spacer()
            Text(value)
                .font(PD.FontToken.title(22, weight: .bold))
                .foregroundStyle(theme.currentAccentFill)
        }
        .padding(.vertical, 14)
    }

    private var continueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Что продолжить")
                .font(PD.FontToken.caption(13, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .textCase(.uppercase)
            Button {
                nav.requestTab(1)
                dismiss()
            } label: {
                profileAction(title: "Продолжить курс", subtitle: "Вернуться к следующему уроку", systemImage: "play")
            }
            .buttonStyle(.plain)
            Button {
                nav.requestTab(2)
                dismiss()
            } label: {
                profileAction(title: "Повторить в Speaker", subtitle: "Фразы, которые ждут повторения", systemImage: "waveform")
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 20) {
            ProfileEmptyRhythmHero(reduceMotion: reduceMotion, phase: orbPhase)
            VStack(spacing: 8) {
                Text("Здесь появится\nтвой прогресс")
                    .font(PD.FontToken.title(29, weight: .bold))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
                Text("Начни с первого урока — Taika будет бережно собирать историю твоей практики.")
                    .font(PD.FontToken.body(16))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            VStack(spacing: 0) {
                emptyMetric(title: "Уроки", image: "book.closed")
                emptyMetric(title: "Минуты", image: "clock")
                emptyMetric(title: "Слова", image: "textformat")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(PD.ColorToken.card.opacity(0.34), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.54), lineWidth: 1))
            Button {
                nav.requestTab(1)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Начать первый урок")
                    Spacer()
                }
                .font(PD.FontToken.body(16, weight: .semibold))
                .foregroundStyle(PD.ColorToken.background)
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .background(theme.currentAccentFill, in: Capsule())
            }
            .buttonStyle(.plain)
            Button {
                nav.requestTab(2)
                dismiss()
            } label: {
                Text("Открыть Speaker")
                    .font(PD.FontToken.body(15, weight: .semibold))
                    .foregroundStyle(theme.currentAccentFill)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyMetric(title: String, image: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: image)
                .foregroundStyle(theme.currentAccentFill)
                .frame(width: 26)
            Text(title)
                .font(PD.FontToken.caption(13))
                .foregroundStyle(PD.ColorToken.textSecondary)
            Spacer()
            Text("—")
                .font(PD.FontToken.body(17, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
        }
        .padding(.vertical, 10)
    }

    private var activityDaysForDisplay: [PDActivityDay] {
        Array(profile.activityWeekDays.suffix(7))
    }

    private var activitySection: some View {
        activityBars
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
                .fill(ThemeManager.shared.currentAccentFill)
                .opacity(0.22)
                .frame(width: 280, height: 280)
                .blur(radius: 110)
                .opacity(0.18)
                .offset(x: 140, y: -300)
                .scaleEffect(reduceMotion ? 1 : 0.94 + phase * 0.06)
            Circle()
                .fill(ThemeManager.shared.currentAccentTintColor.opacity(0.16))
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


private extension ProfileStatisticsView {
    var dayWord: String {
        profile.dashboardStreakDays == 1 ? "день" : "дня"
    }

    func coachingMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(PD.FontToken.title(21, weight: .bold))
                .foregroundStyle(PD.ColorToken.text)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(PD.FontToken.caption(10))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProfileFocusScene: View {
    let phase: CGFloat
    let reduceMotion: Bool
    let accent: AnyShapeStyle

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(accent)
                    .frame(width: 172, height: 172)
                    .blur(radius: 32)
                    .opacity(0.20)
                    .scaleEffect(reduceMotion ? 1 : 0.92 + phase * 0.12)
                    .position(x: proxy.size.width * 0.76, y: proxy.size.height * 0.34)
                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    .frame(width: 142, height: 142)
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(phase) * 360))
                    .position(x: proxy.size.width * 0.76, y: proxy.size.height * 0.34)
                Circle()
                    .stroke(ThemeManager.shared.currentAccentTintColor.opacity(0.30), lineWidth: 1)
                    .frame(width: 196, height: 196)
                    .rotationEffect(.degrees(reduceMotion ? 0 : -Double(phase) * 210))
                    .position(x: proxy.size.width * 0.76, y: proxy.size.height * 0.34)
                Capsule()
                    .fill(Color.white.opacity(0.11))
                    .frame(width: proxy.size.width * 0.62, height: 1)
                    .rotationEffect(.degrees(-18))
                    .position(x: proxy.size.width * 0.58, y: proxy.size.height * 0.58)
                Capsule()
                    .fill(ThemeManager.shared.currentAccentTintColor.opacity(0.20))
                    .frame(width: proxy.size.width * 0.42, height: 1)
                    .rotationEffect(.degrees(24))
                    .position(x: proxy.size.width * 0.45, y: proxy.size.height * 0.30)
            }
        }
        .allowsHitTesting(false)
    }
}


private struct ProfileRhythmRing: View {
    let percent: Int
    let phase: CGFloat
    let reduceMotion: Bool
    let accent: AnyShapeStyle

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 14)
                .frame(width: 172, height: 172)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 172, height: 172)
                .rotationEffect(.degrees(-90))
                .shadow(color: ThemeManager.shared.currentAccentTintColor.opacity(0.34), radius: 12)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(phase) * 2), axis: (x: 0, y: 1, z: 0))
            VStack(spacing: 2) {
                Text("\(percent)%")
                    .font(PD.FontToken.title(35, weight: .bold))
                    .foregroundStyle(accent)
                Text("ритма")
                    .font(PD.FontToken.caption(13))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
        }
        .frame(width: 196, height: 196)
    }
}

private struct ProfileEmptyRhythmHero: View {
    let reduceMotion: Bool
    let phase: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(ThemeManager.shared.currentAccentFill)
                .opacity(0.18)
                .frame(width: 132, height: 132)
                .blur(radius: 18)
                .scaleEffect(reduceMotion ? 1 : 0.96 + phase * 0.06)
            Circle()
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                .frame(width: 132, height: 132)
            Circle()
                .stroke(ThemeManager.shared.currentAccentTintColor.opacity(0.25), lineWidth: 1)
                .frame(width: 166, height: 166)
                .rotationEffect(.degrees(reduceMotion ? 0 : Double(phase) * 160))
            ProfileWaveLine(reduceMotion: reduceMotion, phase: phase)
                .stroke(ThemeManager.shared.currentAccentTintColor.opacity(0.82), style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                .frame(width: 220, height: 52)
                .shadow(color: ThemeManager.shared.currentAccentTintColor.opacity(0.30), radius: 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }
}

private struct ProfileWaveLine: Shape {
    let reduceMotion: Bool
    let phase: CGFloat

    var animatableData: CGFloat {
        get { reduceMotion ? 0 : phase }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let step = rect.width / 32
        path.move(to: CGPoint(x: 0, y: midY))
        for index in 0...32 {
            let x = CGFloat(index) * step
            let envelope = sin(Double(index) / 32 * Double.pi)
            let wave = sin(Double(index) * 0.86 + Double(phase) * 2.4)
            let y = midY + CGFloat(wave) * 16 * CGFloat(envelope)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}


struct ProfileRootContent: View {
    @EnvironmentObject private var theme: ThemeManager
    @ObservedObject private var pro = ProManager.shared
    @ObservedObject private var auth = AuthService.shared

    let appVersionLabel: String
    let authInProgress: Bool
    let authErrorMessage: String?
    let restoreInFlight: Bool
    let onAppleID: () -> Void
    let onRestore: () -> Void
    let onTaikaPlus: () -> Void
    let onRhythm: () -> Void
    let onSupport: () -> Void
    let onLegal: () -> Void
    let onReset: () -> Void
    let onDebug: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Taika+ is the only hero surface on Profile. Everything below is a continuous control list.
            ProfileTaikaPlusCard(pro: pro, restoreInFlight: restoreInFlight, onTap: onTaikaPlus, onRestore: onRestore)
                .environmentObject(theme)

            rootSectionLabel("МОЙ ПРОФИЛЬ")
            VStack(spacing: 0) {
                ProfileAppRow(title: "Твой ритм", subtitle: "Прогресс, активность и следующий шаг", systemImage: "waveform.path.ecg", action: onRhythm)
                    .environmentObject(theme)
                Divider().overlay(PD.ColorToken.stroke.opacity(0.36))
                ProfileAccountCard(
                    isLoggedIn: auth.isLoggedIn,
                    displayName: auth.displayName,
                    isLoading: authInProgress,
                    errorMessage: authErrorMessage,
                    onAppleID: onAppleID,
                    onSignOut: {
                        try? auth.signOut()
                        ProManager.shared.reset()
                    }
                )
                .environmentObject(theme)
            }

            rootSectionLabel("СЕРВИС")
            VStack(spacing: 0) {
                ProfileAppRow(title: "Поддержка и обратная связь", subtitle: "Помощь, вопросы и предложения", systemImage: "questionmark.bubble", action: onSupport)
                Divider().overlay(PD.ColorToken.stroke.opacity(0.40))
                ProfileAppRow(title: "Правовые документы", subtitle: "Политика и условия использования", systemImage: "doc.on.doc", action: onLegal)
                Divider().overlay(PD.ColorToken.stroke.opacity(0.40))
                ProfileAppRow(title: "Что нового", subtitle: "Версия \(appVersionLabel)", systemImage: "info.circle", action: {})
            }

            #if DEBUG
            rootSectionLabel("СИСТЕМА")
            VStack(spacing: 0) {
                ProfileAppRow(title: "Сбросить прогресс", subtitle: "Только локальные данные", systemImage: "trash", action: onReset)
                Divider().overlay(PD.ColorToken.stroke.opacity(0.40))
                ProfileAppRow(title: "Отладка", subtitle: "Только для Debug-сборки", systemImage: "wrench.and.screwdriver", action: onDebug)
            }
            #endif
        }
    }

    private func rootSectionLabel(_ title: String) -> some View {
        Text(title)
            .font(PD.FontToken.caption(12, weight: .semibold))
            .foregroundStyle(PD.ColorToken.textSecondary)
            .tracking(1.1)
            .padding(.leading, 2)
    }
}

private struct ProfileBuildCard: View {
    let appVersionLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hammer.fill")
                .foregroundStyle(PD.ColorToken.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(TaikaBuildChannel.badgeTitle ?? "Debug")
                    .font(PD.FontToken.body(16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Text(TaikaBuildChannel.badgeSubtitle ?? "Локальная сборка для разработки")
                    .font(PD.FontToken.caption(12))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Text(appVersionLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.76))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

private struct ProfileAccountCard: View {
    @EnvironmentObject private var theme: ThemeManager
    let isLoggedIn: Bool
    let displayName: String?
    let isLoading: Bool
    let errorMessage: String?
    let onAppleID: () -> Void
    let onSignOut: () -> Void

    private var accountSubtitle: String {
        isLoggedIn ? (displayName ?? "Вход с Apple ID") : "Вход с Apple ID"
    }

    private var accountAction: () -> Void {
        isLoggedIn ? onSignOut : onAppleID
    }

    private var statusStyle: AnyShapeStyle {
        isLoggedIn
            ? AnyShapeStyle(TaikaMasteryTokens.greenGradient)
            : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.78))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: accountAction) {
                HStack(spacing: 14) {
                    Image(systemName: "apple.logo")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Аккаунт")
                            .font(PD.FontToken.body(17, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.text)
                        Text(accountSubtitle)
                            .font(PD.FontToken.caption(13))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(isLoggedIn ? "Активен" : "Войти")
                            .font(PD.FontToken.caption(12, weight: .semibold))
                            .foregroundStyle(statusStyle)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            if let errorMessage, !errorMessage.isEmpty, !isLoggedIn {
                Text(errorMessage)
                    .font(PD.FontToken.caption(12))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 56)
                    .padding(.bottom, 10)
            }
        }
    }
}

private struct ProfileTaikaPlusCard: View {
    @EnvironmentObject private var theme: ThemeManager
    @ObservedObject var pro: ProManager
    let restoreInFlight: Bool
    let onTap: () -> Void
    let onRestore: () -> Void

    private var statusTitle: String {
        pro.isPro ? "ДОСТУП ОТКРЫТ" : "ДОСТУП ЗАКРЫТ"
    }

    private var statusColor: Color {
        pro.isPro ? TaikaMasteryTokens.green : PD.ColorToken.textSecondary.opacity(0.52)
    }

    private var statusStyle: AnyShapeStyle {
        pro.isPro
            ? AnyShapeStyle(TaikaMasteryTokens.greenGradient)
            : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.78))
    }

    private var statusSubtitle: String {
        pro.isPro ? pro.subscriptionStatusSubtitle : "7 дней бесплатно · курсы и Speaker"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Image(systemName: pro.isPro ? "crown.fill" : "lock.fill")
                            .foregroundStyle(statusStyle)
                        Text(pro.isPro ? "Taika+ активен" : "Открыть Taika+")
                            .font(PD.FontToken.title(21, weight: .bold))
                            .foregroundStyle(PD.ColorToken.text)
                    }
                    Text(statusSubtitle)
                        .font(PD.FontToken.caption(13, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 9, height: 9)
                        .shadow(color: statusColor.opacity(0.7), radius: 7)
                    Text(statusTitle)
                        .font(PD.FontToken.caption(10, weight: .bold))
                        .foregroundStyle(statusStyle)
                        .tracking(0.7)
                }
            }

            Button(action: onTap) {
                HStack(spacing: 8) {
                    Image(systemName: pro.isPro ? "slider.horizontal.3" : "sparkles")
                    Text(pro.isPro ? "Управление подпиской" : "Открыть Taika+")
                        .font(PD.FontToken.body(16, weight: .bold))
                }
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    pro.isPro
                        ? AnyShapeStyle(TaikaMasteryTokens.greenGradient)
                        : AnyShapeStyle(PD.ColorToken.chip.opacity(0.72)),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)

            HStack {
                Button(action: onRestore) {
                    Text(restoreInFlight ? "Восстановление…" : "Восстановить покупку")
                        .font(PD.FontToken.caption(12, weight: .semibold))
                        .foregroundStyle(theme.currentAccentFill)
                }
                .buttonStyle(.plain)
                .disabled(restoreInFlight)
                Spacer()
                Text(pro.isPro ? "Все функции доступны" : "Есть подписка? Восстанови её")
                    .font(PD.FontToken.caption(11))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.78))
                    .lineLimit(1)
            }

            HStack(spacing: 0) {
                profileCapability("book.closed", "Курсы", pro.isPro)
                Divider().frame(height: 30).overlay(PD.ColorToken.stroke.opacity(0.35))
                profileCapability("waveform", "Speaker", pro.isPro)
                Divider().frame(height: 30).overlay(PD.ColorToken.stroke.opacity(0.35))
                profileCapability("gamecontroller", "Игры", pro.isPro)
            }
            .padding(.vertical, 9)
        }
        .padding(16)
        .background(
            pro.isPro
                ? AnyShapeStyle(TaikaMasteryTokens.greenGradient.opacity(0.18))
                : AnyShapeStyle(PD.ColorToken.card.opacity(0.72)),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    pro.isPro
                        ? AnyShapeStyle(TaikaMasteryTokens.greenGradient.opacity(0.62))
                        : AnyShapeStyle(PD.ColorToken.stroke.opacity(0.62)),
                    lineWidth: 1
                )
        )
        .shadow(color: statusColor.opacity(pro.isPro ? 0.16 : 0.04), radius: 18, y: 8)
    }

    private func profileCapability(_ image: String, _ title: String, _ available: Bool) -> some View {
        let capabilityStyle: AnyShapeStyle = available
            ? AnyShapeStyle(TaikaMasteryTokens.greenGradient)
            : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.62))
        return VStack(spacing: 3) {
            Image(systemName: available ? image : "lock.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(capabilityStyle)
            Text(title)
                .font(PD.FontToken.caption(11, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
            Text(available ? "открыто" : "закрыто")
                .font(PD.FontToken.caption(10, weight: .semibold))
                .foregroundStyle(capabilityStyle)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileAppRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .frame(width: 26)
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
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}
