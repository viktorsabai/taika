import SwiftUI

/// Итог подхода в Спикере: показывается один раз, когда пользователь проговорил
/// все фразы очереди. Говорит числами и одной конкретной рекомендацией — без «молодец».
struct SpeakerSessionSummaryView: View {
    let summary: SpeakerManager.TrainingSessionSummary
    let onNextLap: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: onNextLap)
            OverlayEtalonCard(title: "Подход пройден", onDismiss: onNextLap, role: .choice) {
                VStack(alignment: .leading, spacing: 18) {
                    headline
                    metrics
                    Text(verdict)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    actions
                }
                .padding(.horizontal, CD.Spacing.screen)
                .padding(.bottom, 20)
            }
        }
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(summary.average)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(PD.ColorToken.text)
            VStack(alignment: .leading, spacing: 2) {
                Text("средняя за круг")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Text("\(summary.phrases) \(Self.phraseCountLabel(summary.phrases))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
            }
        }
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            metricTile(title: "лучшая", value: "\(summary.best)")
            metricTile(title: "слабая", value: "\(summary.weakest)")
            metricTile(title: "динамика", value: Self.signed(summary.trend))
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(PD.ColorToken.text)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: 16, style: .continuous)))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button(action: onNextLap) {
                Text("Ещё круг")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ThemeManager.shared.currentAccentFill)
                    )
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))

            Button("Закончить", action: onFinish)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
        }
    }

    /// Одна конкретная рекомендация вместо общей похвалы: сначала смотрим на динамику,
    /// потом на уровень — иначе совет не отличается от круга к кругу.
    private var verdict: String {
        if summary.trend <= -8 {
            return "К концу круга точность просела на \(abs(summary.trend)) — устала артикуляция. Сделай паузу или возьми фразы короче."
        }
        if summary.trend >= 8 {
            return "К концу круга стало ровнее на \(summary.trend). Разогрев работает — следующий круг начни сразу с трудных фраз."
        }
        if summary.weakest <= 50 {
            return "Разрыв между лучшей и слабой — \(summary.best - summary.weakest). Прогони заново те фразы, где просел тон."
        }
        if summary.average >= 85 {
            return "Тон держишь стабильно весь круг. Можно брать фразы длиннее или убрать прослушивание эталона перед попыткой."
        }
        if summary.average >= 65 {
            return "База ровная, теряешь на отдельных слогах. Открывай разбор тонов после каждой попытки — там видно, какой именно."
        }
        return "Тон пока плавает по всему кругу. Слушай эталон перед каждой попыткой и повторяй сразу, не по памяти."
    }

    private static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private static func phraseCountLabel(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1, mod100 != 11 { return "фраза" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "фразы" }
        return "фраз"
    }
}
