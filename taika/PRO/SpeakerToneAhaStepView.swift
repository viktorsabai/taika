import SwiftUI

// MARK: - First-seen gate (перед paywall)

@MainActor
enum SpeakerToneAhaState {
    private static let seenKey = "taika.aha.toneDemoSeen"

    static var hasSeen: Bool {
        UserDefaults.standard.bool(forKey: seenKey)
    }

    static var shouldShowBeforePaywall: Bool {
        guard !hasSeen else { return false }
        if ProManager.shared.isPro { return false }
        return true
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }

#if DEBUG
    /// Сброс для QA / превью.
    static func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: seenKey)
    }
#endif
}

// MARK: - Micro-step: разбор тонов перед подпиской

/// Интерактивный aha перед paywall: одна фраза ไม่เผ็ด → слушать / тоны → дальше на Plus.
struct SpeakerToneAhaStepView: View {
    let courseId: String
    let reason: ProGateReason
    /// Если true — после aha открываем `.speakerPaywall`, иначе `.proCoursePaywall`.
    let fromSpeakerPaywall: Bool
    let onDismissWithoutPaywall: () -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @State private var showTones = false
    @State private var tonePulse = false
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            OverlayEtalonBackground(onDismiss: cancelFlow)

            VStack(spacing: 0) {
                Spacer(minLength: Theme.Layout.rootHeaderClearance)

                VStack(alignment: .leading, spacing: 0) {
                    header

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Услышь, как Таика раскладывает тоны — до подписки")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, CD.Spacing.screen)

                        demoBlock
                            .padding(.horizontal, CD.Spacing.screen)

                        VStack(spacing: 12) {
                            OverlayEtalonPrimaryButton(title: "дальше") {
                                continueToPaywall()
                            }
                            OverlayEtalonSecondaryButton(title: "пропустить", action: continueToPaywall)
                        }
                        .padding(.horizontal, CD.Spacing.screen)
                        .padding(.bottom, 20)
                        .padding(.top, 8)
                    }
                    .padding(.top, 4)
                }
                .taikaBlackGlassBackground(cornerRadius: 28)
                .frame(maxWidth: 420)
                .padding(.horizontal, 20)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 12)
                .scaleEffect(contentVisible ? 1 : 0.98)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                contentVisible = true
            }
            // Авто-aha: показать тоны через короткий бит после появления.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                guard !showTones else { return }
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    showTones = true
                }
                pulseTones()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Разбор тонов")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CD.ColorToken.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: cancelFlow) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, CD.Spacing.screen)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var demoBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(MainInstantSpeakerDemo.ru)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(CD.ColorToken.textSecondary)

            Text(MainInstantSpeakerDemo.thai)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(CD.ColorToken.text)

            SpeakerToneAhaPhoneticLine(phonetic: MainInstantSpeakerDemo.phonetic)
                .opacity(showTones ? 0.55 : 1)

            if showTones {
                toneChips
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                ahaPill(title: "слушать", systemImage: "speaker.wave.2.fill", filled: true) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    StepAudio.shared.speakThai(MainInstantSpeakerDemo.thai)
                }
                ahaPill(
                    title: showTones ? "скрыть тоны" : "тоны",
                    systemImage: showTones ? "chevron.up" : "arrow.up.arrow.down",
                    filled: false
                ) {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        showTones.toggle()
                    }
                    if showTones { pulseTones() }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CD.ColorToken.card.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
        )
    }

    private var toneChips: some View {
        HStack(spacing: 8) {
            ForEach(Array(MainInstantSpeakerDemo.toneLabels.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text(item.syllable)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.text)
                        Text(item.arrow)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.currentAccentFill)
                    }
                    Text(item.toneRU)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CD.ColorToken.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CD.ColorToken.chip.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                        )
                )
                .scaleEffect(tonePulse ? 1.03 : 1.0)
            }
        }
    }

    private func ahaPill(
        title: String,
        systemImage: String,
        filled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(filled ? Color.black.opacity(0.88) : CD.ColorToken.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(filled ? AnyShapeStyle(theme.currentAccentFill) : AnyShapeStyle(CD.ColorToken.card.opacity(0.85)))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                filled
                                    ? AnyShapeStyle(Color.clear)
                                    : AnyShapeStyle(theme.currentAccentFill.opacity(0.75)),
                                lineWidth: 1.2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func pulseTones() {
        tonePulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.55).repeatCount(2, autoreverses: true)) {
                tonePulse = true
            }
        }
    }

    private func continueToPaywall() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SpeakerToneAhaState.markSeen()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            if fromSpeakerPaywall {
                OverlayPresenter.shared.present(.speakerPaywall)
            } else {
                OverlayPresenter.shared.present(.proCoursePaywall(courseId: courseId, reason: reason))
            }
        }
    }

    /// Крестик / scrim: закрыть воронку (флаг всё равно ставим — aha уже показан).
    private func cancelFlow() {
        SpeakerToneAhaState.markSeen()
        onDismissWithoutPaywall()
    }
}

private struct SpeakerToneAhaPhoneticLine: View {
    let phonetic: String
    private static let toneArrows: Set<Character> = ["→", "↓", "↘", "↑", "↗"]

    var body: some View {
        styled
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var styled: Text {
        var result = Text("")
        var chunk = ""
        func flush() {
            guard !chunk.isEmpty else { return }
            result = result + Text(chunk).foregroundStyle(CD.ColorToken.text)
            chunk = ""
        }
        for ch in phonetic {
            if Self.toneArrows.contains(ch) {
                flush()
                result = result + Text(String(ch)).foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
            } else {
                chunk.append(ch)
            }
        }
        flush()
        return result
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SpeakerToneAhaStepView(
            courseId: "",
            reason: .speakerBreakdown,
            fromSpeakerPaywall: true,
            onDismissWithoutPaywall: {}
        )
    }
}
