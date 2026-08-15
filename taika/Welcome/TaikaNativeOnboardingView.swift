// TaikaNativeOnboardingView.swift
// MainView-native onboarding: lightweight cards, typewriter-led prompts and continuity motion.
// Reuses MainDS components instead of introducing a second visual language.

import SwiftUI
import Speech
import UIKit

struct TaikaNativeOnboardingView: View {
    let onFinished: (_ courseId: String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var overlay = OverlayPresenter.shared
    @ObservedObject private var pro = ProManager.shared

    @State private var stage: Stage = .prompt
    @State private var phraseIndex = 0
    @State private var selectedDoor: TaikaStartDoor = .beginner
    @State private var speakPhase: SpeakPhase = .idle
    @State private var heardThai = ""
    @State private var courseIndex = 0
    @State private var finished = false

    private enum Stage: Int, CaseIterable { case prompt, phrase, speak, breakdown, course, finish }
    private enum SpeakPhase: Equatable { case idle, recording, checking, success, mismatch, denied }

    private let phrases: [(thai: String, ru: String, phonetic: String, caption: String)] = [
        ("ไม่เผ็ด", "Без острого", "май→ пхет↘", "кафе и рестораны"),
        ("สวัสดี", "Привет", "са-ва́т-ди", "каждый день"),
        ("ไม่เข้าใจ", "Я не понимаю", "май кхао-джай", "разговоры")
    ]

    private var courses: [(item: FDCourseDTO, chip: String, outcomes: [String], count: Int, duration: Int, isPro: Bool)] {
        [
            (FDCourseDTO(courseId: "course_b_1", title: "База от Taika", subtitle: "Первые фразы без стресса", addedAt: Date()), "старт", ["фразы", "слушать"], 12, 10, false),
            (FDCourseDTO(courseId: "course_living", title: "Живой Тайский", subtitle: "Говори в реальных ситуациях", addedAt: Date()), "разговор", ["ситуации", "уверенность"], 18, 12, false),
            (FDCourseDTO(courseId: "course_speaker", title: "Спикер", subtitle: "Произношение и тоны", addedAt: Date()), "речь", ["тоны", "голос"], 10, 8, true)
        ]
    }

    private var currentPhrase: (thai: String, ru: String, phonetic: String, caption: String) { phrases[phraseIndex % phrases.count] }

    var body: some View {
        ZStack {
            WelcomeSpaceBackdropView()
            VStack(spacing: 0) {
                header
                stageBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .id(stage)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
            }
            .padding(.horizontal, PD.Spacing.screen)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .onChange(of: stage) { _, _ in UISelectionFeedbackGenerator().selectionChanged() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                TaikaWordmarkLockup(fontSize: 18)
                Spacer()
                if stage.rawValue > Stage.prompt.rawValue { Text("\(stage.rawValue)/\(Stage.allCases.count - 1)").font(.caption2.weight(.semibold)).foregroundStyle(PD.ColorToken.textSecondary) }
            }
            if stage != .prompt {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PD.ColorToken.textSecondary.opacity(0.16)).frame(height: 2)
                        Capsule().fill(theme.currentAccentFill).frame(width: geo.size.width * CGFloat(stage.rawValue) / CGFloat(Stage.allCases.count - 1), height: 2)
                    }
                }
                .frame(height: 2)
            }
        }
        .frame(height: stage == .prompt ? 44 : 54)
    }

    @ViewBuilder private var stageBody: some View {
        switch stage {
        case .prompt: promptStage
        case .phrase: phraseStage
        case .speak: speakStage
        case .breakdown: breakdownStage
        case .course: courseStage
        case .finish: finishStage
        }
    }

    private var promptStage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 22)
            MDCyclingTypewriter(
                lines: ["Скажи одну фразу", "Почувствуй тайский", "Говори — Taika услышит"],
                font: .system(size: 27, weight: .bold),
                holdSeconds: 2.0,
                charInterval: 0.035,
                minHeight: 70
            )
            Text("Taika покажет, где голос уже звучит уверенно — и что попробовать дальше.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 18)
            Button { go(.phrase) } label: {
                ZStack {
                    Circle().fill(theme.currentAccentTintColor.opacity(0.11)).frame(width: 190, height: 190)
                    Circle().stroke(theme.currentAccentTintColor.opacity(0.30), lineWidth: 1.3).frame(width: 148, height: 148)
                    Circle().fill(theme.currentAccentFill).frame(width: 96, height: 96).shadow(color: theme.currentAccentTintColor.opacity(0.55), radius: 22, y: 7)
                    Image(systemName: "mic.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(PD.ColorToken.background)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
            .accessibilityLabel("Начать знакомство с Taika")
            MDExamplePhraseMarquee(onTapPhrase: { go(.phrase) })
            Spacer(minLength: 12)
            mainCTA("Попробовать") { go(.phrase) }
        }
    }

    private var phraseStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            prompt("Сначала послушай", subtitle: "Потом выбери фразу, которую хочется сказать")
            phraseCarousel
            secondaryCTA("Листай карточки — выбери фразу") { phraseIndex = (phraseIndex + 1) % phrases.count }
            mainCTA("Сказать самому") { go(.speak) }
            Spacer(minLength: 10)
        }
    }

    private var phraseCarousel: some View {
        GeometryReader { outer in
            let width = min(208, outer.size.width * 0.64)
            let side = max(0, (outer.size.width - width) / 2)
            TaikaCarouselScroll {
                HStack(spacing: 12) {
                    ForEach(Array(phrases.enumerated()), id: \.offset) { idx, item in
                        MDWarmupPhraseCard(
                            thai: item.thai,
                            titleRU: item.ru,
                            phonetic: item.phonetic,
                            lessonCaption: item.caption,
                            layoutWidth: width,
                            layoutHeight: MDPortraitCarouselMetrics.cardHeight,
                            isFavorite: idx == phraseIndex,
                            isLearned: false,
                            isPro: false,
                            onSpeak: { phraseIndex = idx; playPhrase() },
                            onFavorite: { phraseIndex = idx },
                            onLearn: { phraseIndex = idx },
                            onTap: { phraseIndex = idx }
                        )
                        .frame(width: width, height: MDPortraitCarouselMetrics.cardHeight)
                        .scaleEffect(idx == phraseIndex ? 1 : 0.90)
                        .opacity(idx == phraseIndex ? 1 : 0.58)
                        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.84), value: phraseIndex)
                    }
                }
                .padding(.horizontal, side)
                .padding(.vertical, 8)
            }
        }
        .frame(height: 306)
        .clipped()
    }

    private var speakStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            prompt(speakPhase == .recording ? "Слушаю тебя" : "Теперь ты", subtitle: speakPhase == .recording ? "Скажи фразу естественно" : "Тапни на микрофон и повтори")
            phraseMiniCard
            Spacer(minLength: 2)
            ZStack {
                if speakPhase == .recording {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().stroke(theme.currentAccentTintColor.opacity(0.22 - Double(i) * 0.05), lineWidth: 1).frame(width: 124 + CGFloat(i * 46), height: 124 + CGFloat(i * 46)).scaleEffect(reduceMotion ? 1 : 1.07).animation(.easeOut(duration: 1.1).repeatForever().delay(Double(i) * 0.14), value: speakPhase)
                    }
                }
                Button(action: speakPhase == .recording ? stopSpeak : startSpeak) {
                    Circle().fill(theme.currentAccentFill).frame(width: 104, height: 104).shadow(color: theme.currentAccentTintColor.opacity(0.38), radius: 22, y: 6).overlay(Image(systemName: speakPhase == .recording ? "stop.fill" : "mic.fill").font(.system(size: 28, weight: .bold)).foregroundStyle(PD.ColorToken.background))
                }
                .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            if speakPhase == .recording { NativeSignalBars(tint: theme.currentAccentTintColor).frame(height: 30) }
            Text(speakPhase == .checking ? "Разбираю слова и тоны…" : (speakPhase == .recording ? "Говори" : "Тапни, когда будешь готов"))
                .font(.caption.weight(.medium)).foregroundStyle(PD.ColorToken.textSecondary).frame(maxWidth: .infinity)
            secondaryCTA("Показать пример разбора") { go(.breakdown) }
            Spacer(minLength: 4)
        }
    }

    private var phraseMiniCard: some View {
        MDWarmupPhraseCard(
            thai: currentPhrase.thai,
            titleRU: currentPhrase.ru,
            phonetic: currentPhrase.phonetic,
            lessonCaption: currentPhrase.caption,
            layoutWidth: MDPortraitCarouselMetrics.cardWidth,
            layoutHeight: 222,
            isFavorite: false,
            isLearned: false,
            isPro: false,
            onSpeak: { playPhrase() },
            onFavorite: {},
            onLearn: {},
            onTap: {}
        )
        .frame(width: MDPortraitCarouselMetrics.cardWidth, height: 222)
        .frame(maxWidth: .infinity)
    }

    private var breakdownStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            prompt("Вот что услышала Taika", subtitle: "Не оценка ради оценки — следующий шаг уже рядом")
            phraseMiniCard
            HStack(spacing: 8) {
                breakdownPill("Текст", "92%")
                breakdownPill("Тон", "68%")
            }
            ToneRevealRail()
            mainCTA("Попробовать ещё раз") { go(.speak) }
            secondaryCTA("Посмотреть курсы") { go(.course) }
            Spacer(minLength: 8)
        }
    }

    private func breakdownPill(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) { Text(title).font(.caption).foregroundStyle(PD.ColorToken.textSecondary); Text(value).font(.taikaStat(28)).foregroundStyle(theme.currentAccentFill) }
            .frame(maxWidth: .infinity).padding(.vertical, 10).background(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous).fill(PD.ColorToken.card.opacity(0.85)))
    }

    private var courseStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            prompt("Теперь — твой путь", subtitle: "Выбери, с чего продолжить после первой фразы")
            courseCarousel
            mainCTA("Начать с этого курса") { finish(courseId: courses[courseIndex].item.courseId) }
            secondaryCTA("Начать с главной") { finish(courseId: courses[courseIndex].item.courseId) }
            Spacer(minLength: 8)
        }
    }

    private var courseCarousel: some View {
        GeometryReader { outer in
            let width: CGFloat = min(240, outer.size.width * 0.72)
            let side = max(0, (outer.size.width - width) / 2)
            TaikaCarouselScroll {
                HStack(spacing: 12) {
                    ForEach(Array(courses.enumerated()), id: \.offset) { idx, course in
                        FDMiniCourseCard(
                            item: course.item,
                            layoutWidth: width,
                            layoutHeight: 230,
                            isPro: course.isPro,
                            categoryChip: course.chip,
                            learningOutcomes: course.outcomes,
                            lessonCount: course.count,
                            durationMinutes: course.duration,
                            onOpen: { courseIndex = idx }
                        )
                        .frame(width: width, height: 230)
                        .scaleEffect(idx == courseIndex ? 1 : 0.91)
                        .opacity(idx == courseIndex ? 1 : 0.58)
                        .onTapGesture { courseIndex = idx; UISelectionFeedbackGenerator().selectionChanged() }
                        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.84), value: courseIndex)
                    }
                }
                .padding(.horizontal, side)
                .padding(.vertical, 8)
            }
        }
        .frame(height: 250)
    }

    private var finishStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            prompt("Готово", subtitle: "Дальше Taika подстроится под твой ритм")
            VStack(alignment: .leading, spacing: 12) {
                Text("Каждый день — одна живая фраза.").font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(PD.ColorToken.text)
                Text("Слушай. Повторяй. Расти.").font(.system(size: 16, weight: .medium, design: .rounded)).foregroundStyle(PD.ColorToken.textSecondary)
            }
            .padding(.top, 30)
            Spacer()
            mainCTA("Начать практику") { finish(courseId: courses[courseIndex].item.courseId) }
        }
    }

    private func prompt(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MDCyclingTypewriter(lines: [title], font: .system(size: 27, weight: .bold), holdSeconds: 2.4, charInterval: 0.035, minHeight: 42)
                .frame(height: 44, alignment: .leading)
                .clipped()
            Text(subtitle)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 18)
    }

    private func mainCTA(_ title: String, action: @escaping () -> Void) -> some View {
        MDMainFilledPillCTA(title: title, icon: "arrow.right", action: action)
    }

    private func secondaryCTA(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(PD.ColorToken.textSecondary).frame(maxWidth: .infinity).padding(.vertical, 8) }.buttonStyle(.plain)
    }

    private func go(_ next: Stage) { withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.46, dampingFraction: 0.86)) { stage = next } }
    private func playPhrase() { StepAudio.shared.speakThai(currentPhrase.thai); UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    private func startSpeak() {
        heardThai = ""
        SpeakerRecorder.shared.requestPermission { ok in
            guard ok else { speakPhase = .denied; return }
            Self.requestSpeechAuth { speechOK in
                guard speechOK else { speakPhase = .denied; return }
                SpeakerRecorder.shared.start { url in
                    guard url != nil else { speakPhase = .denied; return }
                    speakPhase = .recording; UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { if speakPhase == .recording { stopSpeak() } }
                }
            }
        }
    }

    private func stopSpeak() {
        let url = SpeakerRecorder.shared.stop(); speakPhase = .checking
        Task { @MainActor in
            heardThai = await Self.recognizeThai(url: url)
            if heardThai.isEmpty { speakPhase = .mismatch; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            else { speakPhase = .success; UINotificationFeedbackGenerator().notificationOccurred(.success); go(.breakdown) }
        }
    }

    private static func requestSpeechAuth(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { completion(true); return }
        if status == .denied || status == .restricted { completion(false); return }
        SFSpeechRecognizer.requestAuthorization { newStatus in DispatchQueue.main.async { completion(newStatus == .authorized) } }
    }

    private static func recognizeThai(url: URL?) async -> String {
        guard let url, let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH")) else { return "" }
        let request = SFSpeechURLRecognitionRequest(url: url); request.shouldReportPartialResults = true
        return await withCheckedContinuation { continuation in
            var done = false; var lastText = ""
            recognizer.recognitionTask(with: request) { result, error in
                if let text = result?.bestTranscription.formattedString, !text.isEmpty { lastText = text }
                guard !done else { return }
                if result?.isFinal == true || error != nil { done = true; continuation.resume(returning: lastText) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { guard !done else { return }; done = true; continuation.resume(returning: lastText) }
        }
    }

    private func finish(courseId: String) { guard !finished else { return }; finished = true; TaikaProductDemoFlags.markCourseSeen(); onFinished(courseId) }
}

private struct NativeSignalBars: View {
    let tint: Color
    var body: some View { HStack(spacing: 3) { ForEach(0..<26, id: \.self) { index in Capsule().fill(tint.opacity(0.75)).frame(width: 3, height: CGFloat(8 + ((index * 19) % 22))) } } }
}

private struct ToneRevealRail: View {
    @State private var revealed = false
    var body: some View {
        HStack(spacing: 7) {
            Text("май").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
            Text("→").foregroundStyle(.secondary)
            Text("средний").font(.caption).foregroundStyle(.secondary)
            Text("пхет").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(revealed ? .pink : .secondary)
            Text("↘").foregroundStyle(revealed ? .pink : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .opacity(revealed ? 1 : 0.45)
        .onAppear { withAnimation(.easeOut(duration: 0.45).delay(0.18)) { revealed = true } }
    }
}

#Preview("Taika MainView Native Onboarding") { TaikaNativeOnboardingView { _ in } }
