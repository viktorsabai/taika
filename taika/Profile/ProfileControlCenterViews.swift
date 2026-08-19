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
            ScrollView {
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
            .background(PD.ColorToken.background.ignoresSafeArea())
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
                NotificationCenter.default.post(name: Notification.Name("ProfileOpenSpeaker"), object: nil)
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

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Активность")
                .font(PD.FontToken.caption(13, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .textCase(.uppercase)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(profile.activityWeekDays.suffix(7).enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(day.intensity01 > 0 ? theme.currentAccentFill : AnyShapeStyle(PD.ColorToken.stroke.opacity(0.45)))
                            .frame(maxWidth: .infinity)
                            .frame(height: max(10, 18 + CGFloat(day.intensity01) * 54))
                        Text(day.title.prefix(2))
                            .font(.caption2)
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(PD.ColorToken.card.opacity(0.36), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PD.ColorToken.stroke.opacity(0.55), lineWidth: 1))
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    profileSupportLink("Сообщить о проблеме", subtitle: "Опиши, что произошло, и добавь скриншот", image: "exclamationmark.bubble") { open("https://t.me/taika_support") }
                    profileSupportLink("Задать вопрос", subtitle: "Поможем разобраться с приложением", image: "questionmark.circle") { open("https://t.me/taika_support") }
                    profileSupportLink("Сайт taikaa.online", subtitle: "Материалы и новости Taika", image: "globe") { open("https://taikaa.online") }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(PD.ColorToken.background)
            .navigationTitle("Поддержка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }

    private func profileSupportLink(_ title: String, subtitle: String, image: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: image).frame(width: 24).foregroundStyle(PD.ColorToken.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).foregroundStyle(PD.ColorToken.text)
                    Text(subtitle).font(.caption).foregroundStyle(PD.ColorToken.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(PD.ColorToken.textSecondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}

struct ProfileLegalView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { UIApplication.shared.open(TaikaProConfig.Legal.privacyPolicy) } label: {
                        Label("Политика конфиденциальности", systemImage: "hand.raised")
                    }
                    Button { UIApplication.shared.open(TaikaProConfig.Legal.termsOfUse) } label: {
                        Label("Условия использования", systemImage: "doc.text")
                    }
                } footer: {
                    Text("Оба документа открываются на сайте Taika.")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(PD.ColorToken.background)
            .foregroundStyle(PD.ColorToken.text)
            .navigationTitle("Правовые документы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}
