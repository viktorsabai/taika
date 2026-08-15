// TaikaFunnelOnboardingView.swift
// Product funnel onboarding: one selected card, one primary gesture, local motion only.
// Uses MainView tokens and cards; no full-screen marketing panels.

import SwiftUI
import Speech
import UIKit

struct TaikaFunnelOnboardingView: View {
    let onFinished: (_ courseId: String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var theme = ThemeManager.shared
    @State private var state: FunnelState = .attract
    @State private var phraseID = "no-spice"
    @State private var courseID = "course_b_1"
    @State private var voiceState: VoiceState = .idle
    @State private var recognizedText = ""
    @State private var resultReveal = 0
    @State private var didFinish = false

    private enum FunnelState: Int, CaseIterable { case attract, choose, listen, speak, analyze, understand, reinforce, choosePath }
    private enum VoiceState: Equatable { case idle, recording, checking, success, failed }

    private let phraseItems: [FunnelPhrase] = [
        .init(id: "no-spice", thai: "ไม่เผ็ด", ru: "Без острого", phonetic: "май→ пхет↘", caption: "кафе и рестораны"),
        .init(id: "hello", thai: "สวัสดี", ru: "Привет", phonetic: "са-ва́т-ди", caption: "каждый день"),
        .init(id: "dont-know", thai: "ไม่เข้าใจ", ru: "Я не понимаю", phonetic: "май кхао-джай", caption: "разговоры")
    ]

    private let courseItems: [FunnelCourse] = [
        .init(id: "course_b_1", title: "База от Taika", subtitle: "Первые фразы без стресса", chip: "старт", isPro: false),
        .init(id: "course_living", title: "Живой Тайский", subtitle: "Говори в реальных ситуациях", chip: "разговор", isPro: false),
        .init(id: "course_speaker", title: "Спикер", subtitle: "Произношение и тоны", chip: "речь", isPro: true)
    ]

    private var selectedPhrase: FunnelPhrase { phraseItems.first(where: { $0.id == phraseID }) ?? phraseItems[0] }
    private var progress: CGFloat { CGFloat(state.rawValue) / CGFloat(FunnelState.allCases.count) }

    var body: some View {
        ZStack {
            WelcomeSpaceBackdropView()
            VStack(spacing: 0) {
                chrome
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .id(state)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity, removal: .opacity))
            }
            .padding(.horizontal, PD.Spacing.screen)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
    }

    private var chrome: some View {
        VStack(spacing: 8) {
            HStack {
                TaikaWordmarkLockup(fontSize: 18)
                Spacer()
                Text("\(state.rawValue + 1)/\(FunnelState.allCases.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PD.ColorToken.textSecondary.opacity(0.14)).frame(height: 2)
                    Capsule().fill(theme.currentAccentFill).frame(width: geo.size.width * progress, height: 2)
                }
            }
            .frame(height: 2)
        }
        .frame(height: 42)
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .attract: attract
        case .choose: choose
        case .listen: listen
        case .speak: speak
        case .analyze: analyze
        case .understand: understand
        case .reinforce: reinforce
        case .choosePath: choosePath
        }
    }

    private var attract: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 20)
            MDCyclingTypewriter(lines: ["Научись говорить сам", "Taika будет рядом", "Одна фраза — один шаг"], font: .system(size: 28, weight: .bold), holdSeconds: 2.1, charInterval: 0.035, minHeight: 78)
                .frame(height: 78, alignment: .leading)
            Text("Taika не переводит за тебя. Она помогает услышать, сказать и понять следующий шаг.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(PD.ColorToken.textSecondary)
            Spacer(minLength: 10)
            MDPromptHero(greeting: "Начни сам", tagline: "Кун кру рядом: слушает, объясняет и помогает закрепить.") { go(.choose) }
            Spacer(minLength: 10)
        }
    }

    private var choose: some View {
        funnelColumn(prompt: "Выбери фразу", subtitle: "Свайпни — активная карточка всегда остаётся в центре") {
            DepthCarousel(items: phraseItems, selection: $phraseID, reduceMotion: reduceMotion) { item, selected in
                MDWarmupPhraseCard(
                    thai: item.thai,
                    titleRU: item.ru,
                    phonetic: item.phonetic,
                    lessonCaption: item.caption,
                    layoutWidth: 204,
                    layoutHeight: 270,
                    isFavorite: selected,
                    isLearned: false,
                    isPro: false,
                    onSpeak: { phraseID = item.id; playSelected() },
                    onFavorite: { phraseID = item.id },
                    onLearn: { phraseID = item.id },
                    onTap: { phraseID = item.id }
                )
            }
            mainCTA("Послушать фразу") { go(.listen); playSelected() }
        }
    }

    private var listen: some View {
        funnelColumn(prompt: "Слушай", subtitle: "Услышь ритм — потом повтори своим голосом") {
            selectedCard
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "waveform").font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.currentAccentFill).padding(16)
                }
                .scaleEffect(1.0)
            SignalRibbon(tint: theme.currentAccentTintColor, active: true).frame(height: 34)
            mainCTA("Сказать самому") { go(.speak) }
        }
    }

    private var speak: some View {
        funnelColumn(prompt: voiceState == .recording ? "Слушаю тебя" : "Теперь ты", subtitle: voiceState == .recording ? "Говори естественно" : "Нажми на микрофон и повтори") {
            selectedCard
                .overlay {
                    if voiceState == .recording { SignalRibbon(tint: theme.currentAccentTintColor, active: true).frame(height: 34).padding(.horizontal, 18) }
                }
            ZStack {
                if voiceState == .recording { RippleField(tint: theme.currentAccentTintColor, reduceMotion: reduceMotion) }
                Button(action: voiceState == .recording ? stopRecording : startRecording) {
                    Circle().fill(theme.currentAccentFill).frame(width: 96, height: 96).shadow(color: theme.currentAccentTintColor.opacity(0.40), radius: 22, y: 6).overlay(Image(systemName: voiceState == .recording ? "stop.fill" : "mic.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(PD.ColorToken.background))
                }
                .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
            }
            .frame(height: 150)
            Text("Тапни на микрофон, когда будешь готов").font(.caption.weight(.medium)).foregroundStyle(PD.ColorToken.textSecondary).frame(maxWidth: .infinity)
        }
    }

    private var analyze: some View {
        funnelColumn(prompt: "Taika слушает", subtitle: "Разбираем текст и мелодию голоса") {
            selectedCard
                .overlay {
                    ScanSweep(tint: theme.currentAccentTintColor).padding(16)
                }
            SignalRibbon(tint: theme.currentAccentTintColor, active: true).frame(height: 34)
            Text("Это займёт несколько секунд").font(.caption.weight(.medium)).foregroundStyle(PD.ColorToken.textSecondary)
        }
        .onAppear { scheduleAnalysis() }
    }

    private var understand: some View {
        funnelColumn(prompt: "Вот что услышала Taika", subtitle: "Не просто оценка — понятно, что попробовать дальше") {
            selectedCard
            HStack(spacing: 8) {
                metric(title: "Текст", value: "92%", reveal: resultReveal >= 1)
                metric(title: "Тон", value: "68%", reveal: resultReveal >= 2)
            }
            ToneRevealRail(reveal: resultReveal >= 3, tint: theme.currentAccentTintColor)
            mainCTA("Закрепить это") { go(.reinforce) }
        }
        .onAppear { revealResult() }
    }

    private var reinforce: some View {
        funnelColumn(prompt: "Закрепим по-твоему", subtitle: "Одна фраза — три способа, чтобы она осталась в речи") {
            ReinforcementCarousel(accent: theme.currentAccentTintColor, reduceMotion: reduceMotion)
            mainCTA("Выбрать курс") { go(.choosePath) }
        }
    }

    private var choosePath: some View {
        funnelColumn(prompt: "Продолжим здесь", subtitle: "Выбери первый курс — дальше попадёшь в знакомую главную") {
            DepthCarousel(items: courseItems, selection: $courseID, reduceMotion: reduceMotion) { item, selected in
                FDMiniCourseCard(
                    item: FDCourseDTO(courseId: item.id, title: item.title, subtitle: item.subtitle, addedAt: Date()),
                    layoutWidth: 210,
                    layoutHeight: 270,
                    isPro: item.isPro,
                    categoryChip: item.chip,
                    learningOutcomes: ["фразы", "голос"],
                    lessonCount: 12,
                    durationMinutes: 10,
                    onOpen: { courseID = item.id }
                )
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                            .stroke(theme.currentAccentTintColor.opacity(0.8), lineWidth: 1.4)
                    }
                }
            }
            mainCTA("Начать практику") { finish(courseID: courseID) }
        }
    }

    private var selectedCard: some View {
        MDWarmupPhraseCard(
            thai: selectedPhrase.thai,
            titleRU: selectedPhrase.ru,
            phonetic: selectedPhrase.phonetic,
            lessonCaption: selectedPhrase.caption,
            layoutWidth: 210,
            layoutHeight: 270,
            isFavorite: false,
            isLearned: false,
            isPro: false,
            onSpeak: playSelected,
            onFavorite: {},
            onLearn: {},
            onTap: {}
        )
        .frame(width: 210, height: 270)
        .frame(maxWidth: .infinity)
    }

    private func funnelColumn<Content: View>(prompt title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                MDCyclingTypewriter(lines: [title], font: .system(size: 27, weight: .bold), holdSeconds: 2.2, charInterval: 0.035, minHeight: 42).frame(height: 44).clipped()
                Text(subtitle).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(PD.ColorToken.textSecondary).lineLimit(2)
            }
            .frame(height: 70, alignment: .topLeading)
            content()
            Spacer(minLength: 4)
        }
        .padding(.top, 16)
    }

    private func metric(title: String, value: String, reveal: Bool) -> some View {
        VStack(spacing: 3) { Text(title).font(.caption).foregroundStyle(PD.ColorToken.textSecondary); Text(value).font(.taikaStat(29)).foregroundStyle(theme.currentAccentFill) }
            .frame(maxWidth: .infinity).padding(.vertical, 10).background(PD.ColorToken.card.opacity(0.85)).clipShape(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)).opacity(reveal ? 1 : 0).offset(y: reveal ? 0 : 8).animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.86), value: reveal)
    }

    private func mainCTA(_ title: String, action: @escaping () -> Void) -> some View { MDMainFilledPillCTA(title: title, icon: "arrow.right", action: action) }
    private func go(_ next: FunnelState) { withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.46, dampingFraction: 0.86)) { state = next } }
    private func playSelected() { StepAudio.shared.speakThai(selectedPhrase.thai); UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    private func startRecording() {
        SpeakerRecorder.shared.requestPermission { granted in
            guard granted else { voiceState = .failed; return }
            Self.requestSpeechAuth { speechGranted in
                guard speechGranted else { voiceState = .failed; return }
                SpeakerRecorder.shared.start { url in
                    guard url != nil else { voiceState = .failed; return }
                    voiceState = .recording
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    go(.speak)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
                        if voiceState == .recording { stopRecording() }
                    }
                }
            }
        }
    }

    private static func requestSpeechAuth(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { completion(true); return }
        if status == .denied || status == .restricted { completion(false); return }
        SFSpeechRecognizer.requestAuthorization { newStatus in
            DispatchQueue.main.async { completion(newStatus == .authorized) }
        }
    }

    private func stopRecording() {

        let url = SpeakerRecorder.shared.stop(); voiceState = .checking; go(.analyze)
        Task { @MainActor in
            recognizedText = await Self.recognizeThai(url: url); voiceState = recognizedText.isEmpty ? .failed : .success
        }
    }

    private func scheduleAnalysis() { guard voiceState == .checking else { return }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { if voiceState == .checking { go(.understand) } } }
    private func revealResult() { resultReveal = 0; for step in 1...3 { DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.22) { withAnimation { resultReveal = step } } } }
    private func finish(courseId: String) { guard !didFinish else { return }; didFinish = true; TaikaProductDemoFlags.markCourseSeen(); onFinished(courseId) }

    private static func recognizeThai(url: URL?) async -> String {
        guard let url, let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH")) else { return "" }
        let request = SFSpeechURLRecognitionRequest(url: url); request.shouldReportPartialResults = true
        return await withCheckedContinuation { continuation in
            var done = false; var text = ""
            recognizer.recognitionTask(with: request) { result, error in
                if let value = result?.bestTranscription.formattedString, !value.isEmpty { text = value }
                guard !done else { return }
                if result?.isFinal == true || error != nil { done = true; continuation.resume(returning: text) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { guard !done else { return }; done = true; continuation.resume(returning: text) }
        }
    }
}

private struct FunnelPhrase: Identifiable { let id: String; let thai: String; let ru: String; let phonetic: String; let caption: String }
private struct FunnelCourse: Identifiable { let id: String; let title: String; let subtitle: String; let chip: String; let isPro: Bool }

private struct ReinforcementCarousel: View {
    let accent: Color
    let reduceMotion: Bool
    @State private var index = 0
    private let items: [(icon: String, title: String, subtitle: String)] = [
        ("square.grid.2x2.fill", "Матч", "быстро вспомнить глазами"),
        ("textformat.abc", "Слоги", "собрать фразу руками"),
        ("speaker.wave.2.fill", "Аудио Recall", "узнать и сказать на слух")
    ]
    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    VStack(spacing: 10) {
                        Image(systemName: item.icon).font(.system(size: 28, weight: .semibold)).foregroundStyle(accent)
                        Text(item.title).font(.system(size: 22, weight: .semibold, design: .rounded))
                        Text(item.subtitle).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 170)
                    .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)))
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 190)
            HStack(spacing: 6) { ForEach(0..<items.count, id: \.self) { idx in Capsule().fill(idx == index ? AnyShapeStyle(accent) : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.24))).frame(width: idx == index ? 18 : 6, height: 6).animation(.spring(response: 0.3, dampingFraction: 0.85), value: index) } }
            Text("Свайпай, чтобы увидеть остальные").font(.caption.weight(.medium)).foregroundStyle(PD.ColorToken.textSecondary)
        }
    }
}

private struct DepthCarousel<Item: Identifiable, Card: View>: View {
    let items: [Item]
    @Binding var selection: Item.ID
    let reduceMotion: Bool
    let card: (Item, Bool) -> Card

    init(items: [Item], selection: Binding<Item.ID>, reduceMotion: Bool, @ViewBuilder card: @escaping (Item, Bool) -> Card) {
        self.items = items
        self._selection = selection
        self.reduceMotion = reduceMotion
        self.card = card
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        GeometryReader { cell in
                            let center = viewport.size.width / 2
                            let distance = abs(cell.frame(in: .named("depth-carousel")).midX - center)
                            let norm = min(1, distance / max(1, viewport.size.width * 0.74))
                            let isSelected = item.id == selection
                            card(item, isSelected)
                                .scaleEffect(reduceMotion ? 1 : 1.0 - (0.12 * norm))
                                .opacity(1.0 - (0.40 * norm))
                                .rotation3DEffect(.degrees(reduceMotion ? 0 : Double((cell.frame(in: .named("depth-carousel")).midX - center) / 18)), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                                .offset(y: reduceMotion ? 0 : -4 * (1 - norm))
                                .contentShape(Rectangle())
                                .onTapGesture { withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { selection = item.id } }
                        }
                        .frame(width: 210, height: 270)
                        .id(item.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, max(0, (viewport.size.width - 210) / 2))
            }
            .coordinateSpace(name: "depth-carousel")
            .scrollTargetBehavior(.viewAligned)
        }
        .frame(height: 294)
        .clipped()
    }
}

private struct SignalRibbon: View {
    let tint: Color
    let active: Bool
    var body: some View { HStack(spacing: 3) { ForEach(0..<28, id: \.self) { i in Capsule().fill(tint.opacity(0.76)).frame(width: 3, height: CGFloat(7 + ((i * 17) % 24))).scaleEffect(y: active ? 1.0 : 0.7).animation(.easeInOut(duration: 0.42).repeatForever().delay(Double(i) * 0.018), value: active) } }.frame(maxWidth: .infinity) }
}

private struct RippleField: View {
    let tint: Color
    let reduceMotion: Bool
    var body: some View { ZStack { ForEach(0..<3, id: \.self) { i in Circle().stroke(tint.opacity(0.18), lineWidth: 1).frame(width: CGFloat(124 + i * 42), height: CGFloat(124 + i * 42)).scaleEffect(reduceMotion ? 1 : 1.08).animation(.easeOut(duration: 1.1).repeatForever().delay(Double(i) * 0.15), value: reduceMotion) } } }
}

private struct ScanSweep: View {
    let tint: Color
    @State private var x: CGFloat = -1
    var body: some View { GeometryReader { geo in Rectangle().fill(tint.opacity(0.32)).frame(width: 2).offset(x: geo.size.width * x).onAppear { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { x = 1 } } } }
}

private struct ToneRevealRail: View {
    let reveal: Bool
    let tint: Color
    var body: some View { HStack(spacing: 7) { Text("май").font(.system(size: 15, weight: .semibold, design: .rounded)); Text("→").foregroundStyle(.secondary); Text("средний").font(.caption).foregroundStyle(.secondary); Text("пхет").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(reveal ? tint : .secondary); Text("↘").foregroundStyle(reveal ? tint : .secondary) }.frame(maxWidth: .infinity).padding(.vertical, 10).opacity(reveal ? 1 : 0.45).animation(.easeOut(duration: 0.35), value: reveal) }

#Preview("Taika Funnel Onboarding") { TaikaFunnelOnboardingView { _ in } }
