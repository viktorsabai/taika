// TaikaNativeOnboardingView.swift
// Native first-entry onboarding: full-screen product story, not a compact stage deck.
// Visual system: ONMARK Trial, MVSKIFERRegular, ThemeManager accents, Theme.Surfaces,
// WelcomeSpaceBackdropView, TaikaWordmarkLockup, AppMiniChip and CD.ColorToken.

import SwiftUI
import Speech
import UIKit

struct TaikaNativeOnboardingView: View {
    let onFinished: (_ courseId: String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var overlay = OverlayPresenter.shared
    @ObservedObject private var pro = ProManager.shared

    @State private var phase: Phase = .welcome
    @State private var selectedDoor: TaikaStartDoor = .beginner
    @State private var phraseHeard = false
    @State private var listening = false
    @State private var speakPhase: SpeakPhase = .idle
    @State private var heardThai = ""
    @State private var score: Double = 0
    @State private var valueIndex = 0
    @State private var minutes = 10.0
    @State private var days = 4.0
    @State private var pickedCourseId = "course_b_1"
    @State private var offeredPlus = false
    @State private var didFinish = false
    @State private var appear = false

    private enum Phase: Int, CaseIterable {
        case welcome, level, phrase, record, result, values, plus, rhythm
        var progress: Double { Double(rawValue) / Double(Self.allCases.count - 1) }
    }

    private enum SpeakPhase: Equatable {
        case idle, recording, checking, understood, mismatch, unheard, denied
    }

    private let thai = "ไม่เผ็ด"
    private let phonetic = "mâi pèt"
    private let russian = "Без острого"

    var body: some View {
        ZStack {
            WelcomeSpaceBackdropView()
            accentAtmosphere

            VStack(spacing: 0) {
                topChrome
                progressRail
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(phase)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.45)) { appear = true }
            _ = CourseData.shared.load()
        }
        .onChange(of: overlay.overlay) { _, newValue in
            if offeredPlus, newValue == nil { offeredPlus = false }
        }
    }

    private var accentAtmosphere: some View {
        ZStack {
            Circle()
                .fill(theme.currentAccentTintColor.opacity(0.14))
                .frame(width: 330, height: 330)
                .blur(radius: 84)
                .offset(x: 110, y: -150)
            Circle()
                .fill(theme.currentAccentTintColor.opacity(0.07))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -120, y: 180)
        }
        .allowsHitTesting(false)
    }

    private var topChrome: some View {
        HStack {
            TaikaWordmarkLockup(fontSize: 18)
            Spacer()
            if phase != .welcome {
                AppMiniChip(title: "первый вход", style: .neutral)
            }
        }
        .frame(height: 42)
    }

    private var progressRail: some View {
        Group {
            if phase != .welcome {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10)).frame(height: 3)
                        Capsule().fill(theme.currentAccentFill).frame(width: proxy.size.width * phase.progress, height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.top, 6)
                .accessibilityLabel("Прогресс первого входа")
            } else {
                Color.clear.frame(height: 9)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .welcome: welcome
        case .level: level
        case .phrase: phrase
        case .record: record
        case .result: result
        case .values: values
        case .plus: plus
        case .rhythm: rhythm
        }
    }

    private var welcome: some View {
        fullScreenStack {
            Spacer(minLength: 20)
            BreathingBrandMark(tint: theme.currentAccentTintColor, reduceMotion: reduceMotion)
                .frame(height: 230)
            VStack(spacing: 12) {
                eyebrow("PERSONAL PRONUNCIATION COACH")
                Text("Сделаем твой голос\nвидимым.")
                    .font(.taikaTitle(38))
                    .foregroundStyle(CD.ColorToken.text)
                    .multilineTextAlignment(.center)
                Text("Скажи одну фразу. Taika услышит, как ты говоришь, и покажет следующий шаг — без тестов и лишней теории.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(CD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            Spacer(minLength: 20)
            primaryButton("Попробовать") { go(.level) }
        }
    }

    private var level: some View {
        fullScreenStack {
            sectionHeader(eyebrow: "Сначала настроимся", title: "Какой у тебя тайский?", subtitle: "Это не тест. Выбери ощущение, которое ближе сейчас.")
            Spacer(minLength: 18)
            VStack(spacing: 12) {
                levelChoice(.beginner, icon: "leaf.fill", title: "Начинаю с нуля", subtitle: "Хочу уверенно начать")
                levelChoice(.speaking, icon: "waveform", title: "Что-то понимаю", subtitle: "Хочу прокачать базу")
                levelChoice(.living, icon: "sun.max.fill", title: "Уже говорю", subtitle: "Хочу звучать естественно")
            }
            Spacer(minLength: 18)
            primaryButton("Дальше") { persistDoor(); go(.phrase) }
        }
    }

    private func levelChoice(_ door: TaikaStartDoor, icon: String, title: String, subtitle: String) -> some View {
        let selected = selectedDoor == door
        return Button {
            selectedDoor = door
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? theme.currentAccentFill : AnyShapeStyle(CD.ColorToken.textSecondary))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(selected ? theme.currentAccentTintColor.opacity(0.15) : Color.white.opacity(0.05)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(CD.ColorToken.text)
                    Text(subtitle).font(Theme.Fonts.caption).foregroundStyle(CD.ColorToken.textSecondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? theme.currentAccentFill : AnyShapeStyle(CD.ColorToken.textSecondary.opacity(0.42)))
            }
            .padding(16)
            .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: Theme.Radii.card, style: .continuous)))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radii.card, style: .continuous).stroke(selected ? theme.currentAccentTintColor.opacity(0.55) : Color.clear, lineWidth: 1.4))
        }
        .buttonStyle(PressDownStyle(scale: 0.985, fade: 0.98))
    }

    private var phrase: some View {
        fullScreenStack {
            sectionHeader(eyebrow: "Проверим на практике", title: "Начнём с одной фразы", subtitle: "Сначала послушай. Потом скажи сам — это займёт несколько секунд.")
            Spacer(minLength: 12)
            phraseCard
            Spacer(minLength: 12)
            primaryButton("Я попробую") { go(.record) }
        }
        .onAppear { autoplayPhraseIfNeeded() }
    }

    private var phraseCard: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return VStack(spacing: 0) {
            HStack {
                AppMiniChip(title: "живая фраза", style: .accent)
                Spacer()
                Image(systemName: listening ? "waveform" : "speaker.wave.2.fill")
                    .foregroundStyle(theme.currentAccentFill)
            }
            Spacer(minLength: 20)
            Text(thai).font(.system(size: 42, weight: .medium, design: .rounded)).foregroundStyle(CD.ColorToken.text)
            Text(phonetic).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(theme.currentAccentFill)
            Text(russian).font(Theme.Fonts.body).foregroundStyle(CD.ColorToken.textSecondary)
            Spacer(minLength: 20)
            Button { playPhrase() } label: {
                Label(listening ? "Слушаю пример" : "Послушать пример", systemImage: listening ? "waveform" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CD.ColorToken.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(Theme.Surfaces.card(shape))
    }

    private var record: some View {
        fullScreenStack {
            sectionHeader(eyebrow: "Теперь ты", title: "Скажи фразу вслух", subtitle: speakPhase == .recording ? "Слушаю тебя…" : "Нажми на микрофон и повтори за Taika")
            Spacer(minLength: 12)
            ZStack {
                if speakPhase == .recording {
                    ForEach(0..<3, id: \.self) { index in
                        Circle().stroke(theme.currentAccentTintColor.opacity(0.23), lineWidth: 1.5)
                            .frame(width: 150 + CGFloat(index * 50), height: 150 + CGFloat(index * 50))
                            .scaleEffect(reduceMotion ? 1 : (speakPhase == .recording ? 1.08 : 0.95))
                            .opacity(reduceMotion ? 0.5 : 0.65 - Double(index) * 0.12)
                            .animation(.easeOut(duration: 1.15).repeatForever().delay(Double(index) * 0.18), value: speakPhase)
                    }
                }
                Button(action: speakPhase == .recording ? stopSpeak : startSpeak) {
                    ZStack {
                        Circle().fill(theme.currentAccentFill).frame(width: 126, height: 126)
                        Image(systemName: speakPhase == .recording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(CD.ColorToken.background)
                    }
                }
                .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
                .accessibilityLabel(speakPhase == .recording ? "Остановить запись" : "Начать запись")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 270)
            if speakPhase == .recording { NativeSignalBars(tint: theme.currentAccentTintColor).frame(height: 32) }
            Text(speakPhase == .checking ? "Разбираю слова и тоны…" : (speakPhase == .recording ? "Говори уверенно" : "Тапни, когда будешь готов"))
                .font(Theme.Fonts.caption)
                .foregroundStyle(CD.ColorToken.textSecondary)
                .frame(height: 26)
            Spacer(minLength: 14)
            secondaryButton("Показать пример разбора") { go(.result) }
        }
    }

    private var result: some View {
        fullScreenStack {
            sectionHeader(eyebrow: "Вот что умеет Taika", title: "Твоё произношение", subtitle: "Не просто правильно или неправильно — видно, что именно улучшить дальше.")
            Spacer(minLength: 8)
            scoreCard
            Spacer(minLength: 12)
            primaryButton("Показать, что дальше") { go(.values) }
        }
        .onAppear { revealScore() }
    }

    private var scoreCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.10), lineWidth: 10)
                Circle().trim(from: 0, to: CGFloat(score / 100)).stroke(theme.currentAccentFill, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(score))").font(.taikaStat(62)).foregroundStyle(CD.ColorToken.text)
                    Text("из 100").font(Theme.Fonts.caption).foregroundStyle(CD.ColorToken.textSecondary)
                }
            }
            .frame(width: 220, height: 220)
            Text(score >= 85 ? "Почти идеально" : "Хороший первый шаг")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(CD.ColorToken.text)
            HStack(spacing: 10) {
                scorePill(title: "Текст", value: 92)
                scorePill(title: "Тон", value: 68)
            }
            if !heardThai.isEmpty { Text("Услышала: \(heardThai)").font(Theme.Fonts.caption).foregroundStyle(CD.ColorToken.textSecondary) }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: 28, style: .continuous)))
    }

    private func scorePill(title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title).font(Theme.Fonts.caption).foregroundStyle(CD.ColorToken.textSecondary)
            Text("\(value)%").font(.taikaStat(30)).foregroundStyle(theme.currentAccentFill)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    private var values: some View {
        fullScreenStack {
            sectionHeader(eyebrow: "Твой новый ритуал", title: "Учимся через голос", subtitle: "Taika превращает каждую попытку в понятное ощущение прогресса.")
            Spacer(minLength: 18)
            valueDeck
            Spacer(minLength: 18)
            primaryButton("Посмотреть свой путь") { go(.plus) }
        }
    }

    private var valueDeck: some View {
        let cards = [
            ("waveform", "Слышит нюансы", "Оценивает слова и мелодию голоса, а не только совпадение текста."),
            ("sparkles", "Показывает прогресс", "Каждая попытка заканчивается конкретным следующим шагом."),
            ("arrow.triangle.2.circlepath", "Закрепляет вовремя", "Повторение появляется тогда, когда оно действительно помогает.")
        ]
        let card = cards[valueIndex % cards.count]
        return VStack(spacing: 14) {
            Image(systemName: card.0).font(.system(size: 25, weight: .semibold)).foregroundStyle(theme.currentAccentFill)
            Text(card.1).font(.system(size: 23, weight: .semibold, design: .rounded)).foregroundStyle(CD.ColorToken.text)
            Text(card.2).font(Theme.Fonts.body).foregroundStyle(CD.ColorToken.textSecondary).multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button { valueIndex = (valueIndex + cards.count - 1) % cards.count } label: { Image(systemName: "chevron.left") }
                Text("\(valueIndex + 1) / \(cards.count)").font(Theme.Fonts.caption).foregroundStyle(CD.ColorToken.textSecondary)
                Button { valueIndex = (valueIndex + 1) % cards.count } label: { Image(systemName: "chevron.right") }
            }
            .foregroundStyle(CD.ColorToken.text)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260)
        .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: 28, style: .continuous)))
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.86), value: valueIndex)
    }

    private var plus: some View {
        fullScreenStack {
            sectionHeader(eyebrow: "Когда захочется глубже", title: "Taika растёт вместе с тобой", subtitle: "Начать можно бесплатно. Taika+ открывает больше пространства, когда появится желание идти дальше.")
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 18) {
                HStack { Image(systemName: "crown.fill").foregroundStyle(theme.currentAccentFill); Text("TAIKA+").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(theme.currentAccentFill); Spacer() }
                Text("Практика\nбез потолка.").font(.taikaTitle(34)).foregroundStyle(CD.ColorToken.text)
                plusRow("Больше живых фраз и курсов")
                plusRow("Разбор произношения без лимитов")
                plusRow("Умные повторения и прогресс")
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Surfaces.card(RoundedRectangle(cornerRadius: 28, style: .continuous)))
            Spacer(minLength: 16)
            if pro.isPro {
                primaryButton("Открыть курс") { finish() }
            } else {
                primaryButton("Попробовать \(TaikaProConfig.introTrialDaysPhrase) бесплатно") { offeredPlus = true; UIImpactFeedbackGenerator(style: .medium).impactOccurred(); overlay.presentProDirect(reason: .general) }
                secondaryButton("Начать бесплатно") { go(.rhythm) }
            }
        }
    }

    private func plusRow(_ text: String) -> some View {
        HStack(spacing: 10) { Image(systemName: "checkmark").foregroundStyle(theme.currentAccentFill); Text(text).font(Theme.Fonts.body).foregroundStyle(CD.ColorToken.textSecondary) }
    }

    private var rhythm: some View {
        fullScreenStack {
            sectionHeader(eyebrow: "Последний шаг", title: "Как будем заниматься?", subtitle: "Настрой ритм под себя. Его можно изменить в любой момент.")
            Spacer(minLength: 18)
            rhythmSlider(title: "Минут в день", value: $minutes, range: 5...30, step: 5, suffix: "мин")
            rhythmSlider(title: "Дней в неделю", value: $days, range: 1...7, step: 1, suffix: "дн")
            Spacer(minLength: 18)
            primaryButton("Начать практику") { finish() }
        }
    }

    private func rhythmSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(Theme.Fonts.body).foregroundStyle(CD.ColorToken.text); Spacer(); Text("\(Int(value.wrappedValue)) \(suffix)").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(theme.currentAccentFill) }
            Slider(value: value, in: range, step: step).tint(theme.currentAccentTintColor)
        }
        .padding(18)
        .background(Theme.Surfaces.panel(RoundedRectangle(cornerRadius: 20, style: .continuous)))
    }

    private func fullScreenStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func sectionHeader(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) { eyebrow(eyebrow); Text(title).font(.taikaTitle(31)).foregroundStyle(CD.ColorToken.text).multilineTextAlignment(.center); Text(subtitle).font(Theme.Fonts.body).foregroundStyle(CD.ColorToken.textSecondary).multilineTextAlignment(.center).padding(.horizontal, 8) }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
    }

    private func eyebrow(_ text: String) -> some View { Text(text).font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.4).foregroundStyle(theme.currentAccentFill) }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); action() } label: { Text(title).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(CD.ColorToken.background).frame(maxWidth: .infinity).padding(.vertical, 16).background(Capsule().fill(theme.currentAccentFill)) }.buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(CD.ColorToken.textSecondary).frame(maxWidth: .infinity).padding(.vertical, 10) }.buttonStyle(.plain)
    }

    private func go(_ next: Phase) { withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.48, dampingFraction: 0.86)) { phase = next } }
    private func persistDoor() { selectedDoor.persist; UISelectionFeedbackGenerator().selectionChanged() }
    private func autoplayPhraseIfNeeded() { guard !phraseHeard else { return }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { playPhrase() } }
    private func playPhrase() { phraseHeard = true; listening = true; StepAudio.shared.speakThai("ไม่เผ็ด"); DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { listening = false } }

    private func revealScore() {
        guard score < 91 else { return }
        score = 0
        withAnimation(.easeOut(duration: 1.6)) { score = 91 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }

    private func startSpeak() {
        heardThai = ""
        SpeakerRecorder.shared.requestPermission { ok in
            guard ok else { speakPhase = .denied; return }
            Self.requestSpeechAuth { speechOK in
                guard speechOK else { speakPhase = .denied; return }
                SpeakerRecorder.shared.start { url in
                    guard url != nil else { speakPhase = .denied; return }
                    speakPhase = .recording
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { if speakPhase == .recording { stopSpeak() } }
                }
            }
        }
    }

    private func stopSpeak() {
        let url = SpeakerRecorder.shared.stop(); speakPhase = .checking
        Task { @MainActor in
            let heard = await Self.recognizeThai(url: url); heardThai = heard.trimmingCharacters(in: .whitespacesAndNewlines)
            if heardThai.isEmpty { speakPhase = .unheard; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            else if Self.matchesCanon(heardThai) { speakPhase = .understood; UINotificationFeedbackGenerator().notificationOccurred(.success); go(.result) }
            else { speakPhase = .mismatch; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        }
    }

    private static func matchesCanon(_ raw: String) -> Bool {
        let compact = raw.replacingOccurrences(of: " ", with: "")
        if compact.contains("ไม่เผ็ด") || compact.contains("เผ็ด") { return true }
        let folded = compact.lowercased()
        return folded.contains("maiphet") || folded.contains("maipet") || (folded.contains("mai") && (folded.contains("phet") || folded.contains("pet")))
    }

    private static func requestSpeechAuth(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { completion(true); return }
        if status == .denied || status == .restricted { completion(false); return }
        SFSpeechRecognizer.requestAuthorization { newStatus in DispatchQueue.main.async { completion(newStatus == .authorized) } }
    }

    private static func recognizeThai(url: URL?) async -> String {
        guard let url else { return "" }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "th-TH")) else { return "" }
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

    private func finish() { guard !didFinish else { return }; didFinish = true; TaikaProductDemoFlags.markCourseSeen(); onFinished(pickedCourseId) }
}

private struct BreathingBrandMark: View {
    let tint: Color
    let reduceMotion: Bool
    @State private var breathing = false
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in Circle().stroke(tint.opacity(0.18), lineWidth: 1).frame(width: 116 + CGFloat(index * 44), height: 116 + CGFloat(index * 44)).scaleEffect(breathing ? 1.1 : 0.92).opacity(breathing ? 0.18 : 0.55).animation(reduceMotion ? nil : .easeInOut(duration: 2.1).repeatForever().delay(Double(index) * 0.2), value: breathing) }
            Circle().fill(tint.opacity(0.16)).frame(width: 122, height: 122).blur(radius: 18)
            VStack(spacing: 0) { Text("tai").font(.custom("Onmark Trial", size: 28)).foregroundStyle(Color.white); Text("kAAA").font(.custom("Onmark Trial", size: 28)).fontWeight(.bold).foregroundStyle(tint) }
        }
        .onAppear { breathing = true }
    }
}

private struct NativeSignalBars: View {
    let tint: Color
    var body: some View { HStack(spacing: 3) { ForEach(0..<28, id: \.self) { index in Capsule().fill(tint.opacity(0.88)).frame(width: 3, height: CGFloat(7 + ((index * 17) % 24))).animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(index) * 0.02), value: index) } } }
}

#Preview("Taika Native Onboarding") { TaikaNativeOnboardingView { _ in } }
