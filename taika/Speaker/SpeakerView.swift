//
//  SpeakerView.swift
//  taika
//
//  Created by product on 26.12.2025.
//

import SwiftUI

/// host screen (assembly + navigation only). visuals live in speaker ds.
struct SpeakerView: View {
    @EnvironmentObject private var overlay: OverlayPresenter
    @EnvironmentObject private var nav: NavigationIntent
    @ObservedObject private var speakerFilterState = SpeakerFilterState.shared
    @ObservedObject private var speaker = SpeakerManager.shared
    @ObservedObject private var conversationAttempts = SpeakerConversationAttemptsStore.shared
    @ObservedObject private var returnContext = SpeakerReturnContext.shared
    private let pro = ProManager.shared
    @State private var showSpeakerBreakdown = false
    @State private var isRecordingFromBreakdown = false
    /// When non-nil, shell switched to Speaker tab from course card; we load this course and clear. (Fixes onAppear not running in time.)
    @Binding var pendingCourseId: String?
    /// Optional lesson scope when opened from Step summary / lesson CTA.
    @Binding var pendingLessonId: String?
    /// Shell tab — для CTA «К обучению» без back в хедере.
    @Binding var selectedTab: Int

    init(
        pendingCourseId: Binding<String?> = .constant(nil),
        pendingLessonId: Binding<String?> = .constant(nil),
        selectedTab: Binding<Int> = .constant(2)
    ) {
        _pendingCourseId = pendingCourseId
        _pendingLessonId = pendingLessonId
        _selectedTab = selectedTab
        _speakerFilterState = ObservedObject(wrappedValue: SpeakerFilterState.shared)
        _speaker = ObservedObject(wrappedValue: SpeakerManager.shared)
        _showSpeakerBreakdown = State(initialValue: false)
    }

    /// Читаемое название урока для чипа на карточке (из контента, не «урок 1»).
    private func displayLessonTitle(for lessonId: String) -> String {
        if let title = LessonsData.shared.lessonTitle(for: lessonId),
           !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // fallback: человекочитаемо по id (course_b_1_l1 → «урок 1»)
        let lower = lessonId.lowercased()
        if let r = lower.range(of: "_l", options: .backwards) {
            let tail = String(lower[r.upperBound...])
            let digits = tail.prefix { $0.isNumber }
            if let n = Int(digits), n > 0 { return "урок \(n)" }
        }
        let digits = lower.reversed().prefix { $0.isNumber }.reversed()
        if let n = Int(String(digits)), n > 0 { return "урок \(n)" }
        return ""
    }

    private func ensureActiveSelection() {
        // if nothing is selected yet, bind selection to current (or first visible item)
        if speaker.selectedId == nil {
            if let cur = speaker.current {
                speaker.selectCard(by: speaker.resolveId(cur))
            } else if let first = speaker.carouselItems.first {
                speaker.selectCard(by: speaker.resolveId(first))
            }
        }
    }

    private func openConversationBreakdownIfNeeded(force: Bool) {
        guard force || !showSpeakerBreakdown else { return }
        showSpeakerBreakdown = true
        speaker.refreshConversationUserPhoneticFromASRIfNeeded()
        guard hasFullToneBreakdownAccess else { return }
        let thaiSnap = speaker.conversationExpectedThai?.trimmingCharacters(in: .whitespacesAndNewlines)
        let phSnap = speaker.conversationExpectedTranslitForFeedback?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? speaker.current.map { $0.face.phonetic }?.trimmingCharacters(in: .whitespacesAndNewlines)
        let thaiForAssess: String? = {
            if let thaiSnap, !thaiSnap.isEmpty { return thaiSnap }
            let thai = speaker.current?.face.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return thai.isEmpty ? nil : thai
        }()
        speaker.requestToneBreakdownFromAPI(
            expectedThaiForAssess: thaiForAssess,
            expectedPhoneticForTones: (phSnap?.isEmpty == false) ? phSnap : nil,
            completion: {}
        )
    }

    /// Full tone breakdown: Pro, or still inside today's free attempts (incl. the last used one).
    private var hasFullToneBreakdownAccess: Bool {
        if pro.isPro { return true }
        if speaker.speakerUIMode == .conversation {
            let used = conversationAttempts.usedToday
            return used > 0 && used <= 3
        }
        let used = SpeakerDailyAttemptsStore.shared.usedToday
        return used > 0 && used <= 10
    }

    private func onPlayReference() {
        // Умный спикер: эталон в разборе — переведённая фраза, не выбранная карточка карусели.
        if speaker.playReferenceConversationExpectedIfNeeded() { return }
        ensureActiveSelection()
        if let sel = speaker.selectedId {
            speaker.playReference(for: sel)
        } else {
            speaker.playReference()
        }
    }

    private func onPlayAttempt() {
        speaker.playAttempt()
    }

    private func onMicTap() {
        if speaker.speakerUIMode == .conversation {
            switch speaker.phase {
            case .idle, .hint, .feedback:
                speaker.startConversationRecording()
            case .recording:
                if speaker.conversationExpectedThai != nil {
                    speaker.stopConversationPronunciationCheck()
                } else {
                    speaker.stopConversationRecordingAndProcess()
                }
            case .analyzing, .analyzingTranslation:
                return
            }
            return
        }

        ensureActiveSelection()
        guard speaker.selectedId != nil || speaker.current != nil else { return }

        switch speaker.phase {
        case .idle, .hint, .feedback:
            speaker.startAttempt()
        case .recording:
            speaker.stopAttemptAndAnalyze()
        case .analyzing, .analyzingTranslation:
            return
        }
    }

    private func lessonTitle(for lessonId: String) -> String? {
        let t = displayLessonTitle(for: lessonId)
        return t.isEmpty ? nil : t
    }

    /// Main → «Скажи сам»: если пришли с микрофона/чипа, сразу стартуем запись.
    private func maybeStartPendingConversationRecording() {
        guard speaker.speakerUIMode == .conversation else { return }
        guard speaker.consumePendingConversationAutoRecord() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard speaker.speakerUIMode == .conversation else { return }
            switch speaker.phase {
            case .idle, .hint, .feedback:
                speaker.startConversationRecording()
            default:
                break
            }
        }
    }

    var body: some View {
        SpeakerDSRoot(
            current: speaker.current,
            items: speaker.carouselItems,
            selectedId: speaker.selectedId,
            activeFilterId: speaker.activeFilterId,
            phase: speaker.phase,
            heardThai: speaker.heardThai,
            heardRU: speaker.heardRU,
            heardTranslit: speaker.heardTranslit,
            heardConfidence: speaker.heardConfidence,
            displayScore: speaker.displayScore,
            toneAverageScore: speaker.toneAverageScore,
            taikaHints: speaker.taikaHints,
            syllableFeedback: speaker.syllableFeedback,
            breakdownRequestInFlight: speaker.breakdownRequestInFlight,
            breakdownRequestFailed: speaker.breakdownRequestFailed,
            breakdownHybridScore: speaker.breakdownHybridScore,
            recordingMeter: speaker.recordingMeter,
            recordingPartialThai: speaker.recordingPartialThai,
            recordingPartialTranslit: speaker.recordingPartialTranslit,
            recordingPartialRU: speaker.recordingPartialRU.isEmpty ? nil : speaker.recordingPartialRU,
            lastAttempt: speaker.lastAttempt,
            attemptCount: speaker.attemptCount,
            lastPlayed: speaker.lastPlayed,
            onPlayReference: onPlayReference,
            onPlayAttempt: onPlayAttempt,
            onPlayReferenceForId: { id in
                speaker.playReference(for: id)
            },
            onMicTap: onMicTap,
            onNext: { speaker.next() },
            onPrev: { speaker.prev() },
            onRepeat: { speaker.repeatCurrent() },
            onSubmitText: { text in
                speaker.submitText(text)
            },
            onSelectFilter: { id in
                speaker.applyFilter(id)
            },
            onSelectCard: { id in
                // Bug 2: check phase BEFORE selectCard to avoid checking the new card's restored phase
                let oldPhase = speaker.phase
                speaker.selectCard(by: id)
                // when user switches cards, keep UI in a stable state
                if oldPhase == .recording {
                    speaker.stopAttemptAndAnalyze()
                } else if oldPhase == .analyzing || oldPhase == .analyzingTranslation {
                    // do nothing; analysis will finish for the previous attempt
                } else if speaker.phase.isFeedback {
                    // Bug 2: if new card has restored feedback state, preserve it (don't call repeatCurrent)
                    // The restored state is already set by restoreAttemptResult in selectCard
                } else {
                    // snap back to idle/hint (manager will provide hints)
                    speaker.repeatCurrent()
                }
            },
            onShuffle: { speaker.shuffle() },
            onToggleFavorite: { speaker.toggleFavorite() },
            isFavorite: speaker.isCurrentFavorite,
            resolveId: { r in
                speaker.resolveId(r)
            },
            lessonTitleForLessonId: lessonTitle,
            showBreakdownOverlay: $showSpeakerBreakdown,
            onRequestBreakdown: {
                openConversationBreakdownIfNeeded(force: true)
            },
            onRecordAgainFromBreakdown: {
                isRecordingFromBreakdown = true
                if speaker.conversationExpectedThai != nil {
                    speaker.startConversationPronunciationCheck()
                } else {
                    speaker.startAttempt()
                }
            },
            isRecordingFromBreakdown: isRecordingFromBreakdown,
            onStopRecordingFromBreakdown: {
                if speaker.conversationExpectedThai != nil {
                    speaker.stopConversationPronunciationCheck()
                } else {
                    speaker.stopAttemptAndAnalyze()
                }
            },
            onClearAttempt: { speaker.clearAttemptsInCurrentQueue() },
            onClearConversationResult: { speaker.clearConversationResult() },
            learnedLessonIds: speaker.learnedLessonIds,
            learnedLessonFilter: speaker.learnedLessonFilter,
            onSelectLearnedLessonFilter: { lessonId in
                speaker.setLearnedLessonFilter(lessonId)
            },
            showFilterStrip: false,
            courseContextCourseId: speaker.speakerContextCourseId,
            courseContextCardCount: speaker.speakerContextCourseId != nil ? speaker.queue.count : 0,
            courseContextAttemptCount: speaker.speakerContextCourseId != nil ? speaker.attemptCount : 0,
            courseContextAvgScore: speaker.speakerContextCourseId != nil ? speaker.averageScore : 0,
            onExitCourseContext: {
                pendingCourseId = nil
                speaker.returnToTrainingHome()
                speakerFilterState.selectedFilterId = nil
            },
            onReturnToLearning: returnContext.hasContext ? { returnToLearning() } : nil,
            returnToLearningTitle: returnContext.hasContext ? returnContext.returnActionTitle : nil,
            returnToLearningIcon: returnContext.hasContext ? returnContext.returnActionIcon : nil,
            onOpenCourses: {
                nav.popToRoot()
                nav.requestTab(1)
            },
            trainingCourseOptions: speaker.learnedTrainingCourseOptions(),
            // Не синкаем speakerFilterState.selectedFilterId здесь: он привязан к .onChange → applyFilter(id),
            // а applyFilter(.learned) перезаписал бы наш подвыбор курсов общей очередью «все выученные».
            onStartCourseTraining: { courses, lessons in
                speaker.startTraining(
                    withCourseIds: courses,
                    lessonIds: lessons.isEmpty ? nil : lessons
                )
            },
            trainingFavoritesCount: speaker.trainingFavoritesCount(),
            trainingDictionaryCount: speaker.trainingDictionaryCount(),
            onStartSpecialTraining: { poolId in
                speaker.startSpecialTraining(poolId: poolId)
            },
            speakerUIMode: speaker.speakerUIMode,
            onSpeakerUIModeChange: { mode in
                speaker.setSpeakerUIMode(mode)
                if mode == .training,
                   SpeakerRequestedCourseId.shared.courseId == nil,
                   pendingCourseId == nil,
                   speaker.speakerContextCourseId == nil {
                    speaker.returnToTrainingHome()
                    speakerFilterState.selectedFilterId = nil
                }
            },
            onPlayConversationTTS: { speaker.playConversationTTS() },
            onConversationRepeat: { speaker.conversationRepeat() },
            onConversationDemoPhrase: { speaker.startConversationDemoPhrase($0) },
            onConfirmConversationDraft: { addDict, practice in
                speaker.confirmConversationDraft(addToDictionary: addDict, startPractice: practice)
            },
            onRetranslateConversationDraft: { speaker.retranslateConversationDraft($0) },
            onDiscardConversationDraft: { speaker.discardConversationDraft() },
            isProUser: pro.isPro,
            hasFullToneBreakdownAccess: hasFullToneBreakdownAccess,
            conversationRemainingToday: conversationAttempts.remainingToday,
            conversationRecordingElapsed: speaker.conversationRecordingElapsed,
            conversationRecordingMaxDuration: speaker.conversationRecordingMaxDuration,
            conversationCanRecord: conversationAttempts.canRecord,
            conversationExpectedThai: speaker.conversationExpectedThai,
            conversationExpectedTranslitForFeedback: speaker.conversationExpectedTranslitForFeedback,
            conversationHeardThaiASR: speaker.conversationHeardThaiASR,
            conversationHeardPhoneticFromASR: speaker.conversationHeardPhoneticFromASR,
            onConversationRepeatAndCheck: { speaker.startConversationPronunciationCheck() },
            smartSpeakerPoliteness: speaker.smartSpeakerPoliteness,
            onSetSmartSpeakerPoliteness: { speaker.setSmartSpeakerPoliteness($0) },
            referencePlaybackProgress: speaker.referencePlaybackProgress,
            onBreakdownAppear: { speaker.resetReferenceProgress() }
        )
        .onChange(of: speakerFilterState.selectedFilterId) { _, newId in
            if let id = newId {
                speaker.applyFilter(id)
            }
        }
        .onChange(of: speaker.phase) { _, newPhase in
            if isRecordingFromBreakdown, case .feedback = newPhase {
                isRecordingFromBreakdown = false
            }
            // Тренировка «Своя речь»: сразу разбор, без промежуточной полупустой карточки.
            if case .feedback = newPhase,
               speaker.speakerUIMode == .conversation,
               speaker.conversationExpectedThai != nil {
                openConversationBreakdownIfNeeded(force: true)
            }
        }
        .onChange(of: speaker.conversationHeardThaiASR) { _, newVal in
            if newVal != nil {
                speaker.refreshConversationUserPhoneticFromASRIfNeeded()
            }
        }
        .onChange(of: pendingCourseId) { _, newValue in
            if let cid = newValue {
                speaker.loadQueueForCourse(cid, lessonId: pendingLessonId)
                pendingCourseId = nil
                pendingLessonId = nil
            }
        }
        .onAppear {
            // Контекст из Step/курса → очередь урока. Иначе — лаунчер (или текущая сессия, если уже идёт).
            let pending = pendingCourseId.map { ($0, pendingLessonId) }
                ?? SpeakerRequestedCourseId.shared.consume().map { ($0.courseId, $0.lessonId) }
            if let (cid, lid) = pending {
                speaker.prepareTrainingPoolIfNeeded()
                speaker.loadQueueForCourse(cid, lessonId: lid)
                pendingCourseId = nil
                pendingLessonId = nil
                speakerFilterState.selectedFilterId = speaker.activeFilterId
            } else {
                speaker.loadIfNeeded()
                speakerFilterState.selectedFilterId = speaker.activeFilterId
            }
            // Не чистим conversation-результат на каждом appear: tab switch remount'ит SpeakerView
            // и сбрасывал бы только что распознанную фразу. Сброс — при смене режима (`setSpeakerUIMode`).
            speaker.sanitizeConversationHistory()

            maybeStartPendingConversationRecording()
            maybePresentSpeakerProductDemo()

            UserSession.shared.logActivity(
                .speakerOpened,
                courseId: speaker.current?.courseId,
                lessonId: speaker.current?.lessonId,
                stepIndex: speaker.current?.index,
                refId: "speaker:mvp"
            )
        }
        .onChange(of: speaker.pendingConversationAutoRecord) { _, pending in
            if pending { maybeStartPendingConversationRecording() }
        }
    }

    /// Первый визит в Спикер (не из тренировки курса): лёгкий tip в айдентике оверлеев.
    private func maybePresentSpeakerProductDemo() {
        guard !TaikaProductDemoFlags.hasSeenSpeaker else { return }
        // Не перебиваем вход в очередь урока / избранного.
        if pendingCourseId != nil { return }
        if SpeakerManager.shared.speakerContextCourseId != nil { return }
        if SpeakerRequestedCourseId.shared.courseId != nil { return }
        if case .speakerFirstTip = overlay.overlay { return }
        if overlay.overlay != nil { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard !TaikaProductDemoFlags.hasSeenSpeaker else { return }
            guard pendingCourseId == nil else { return }
            guard overlay.overlay == nil else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                overlay.present(.speakerFirstTip)
            }
        }
    }

    private func returnToLearning() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            if let ctx = SpeakerReturnContext.shared.consume() {
                selectedTab = ctx.tab
                nav.path = ctx.path
            } else {
                nav.popToRoot()
                selectedTab = 1
            }
        }
    }
}

#Preview {
    SpeakerPreviewWrapper()
}

private struct SpeakerPreviewWrapper: View {
    @StateObject private var favorites = FavoriteManager.shared
    @StateObject private var overlay = OverlayPresenter.shared
    @StateObject private var nav = NavigationIntent()
    @StateObject private var theme = ThemeManager.shared

    var body: some View {
        NavigationStack {
            SpeakerView()
        }
        .preferredColorScheme(theme.preferredScheme)
        .environmentObject(theme)
        .environmentObject(favorites)
        .environmentObject(overlay)
        .environmentObject(nav)
    }
}
