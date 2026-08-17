//
//  SpeakerDS.swift
//  taika
//
//  first DS scaffold for tAIka (speaker) — visual only, no integrations
//  architecture: sub-header below shell AppHeader, tokens background, no local whites
//

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - tokens shortcuts
private typealias T = Theme

// MARK: - public entry
public struct SpeakerDSRoot: View {

    // when external != nil, this DS is driven by app logic (SpeakerManager)
    private struct External {
        let current: StepData.SpeakerResolved?
        let items: [StepData.SpeakerResolved]?
        let selectedId: UUID?
        let activeFilterId: UUID?
        let phase: SpeakerManager.Phase
        let heardThai: String?
        let heardRU: String?
        let heardTranslit: String?
        let heardConfidence: Int
        /// Одна общая оценка: без разбора = текст; с разбором = min(текст, тон). Показывать и на карточке, и в шапке разбора.
        let displayScore: Int
        /// Средний тон по слогам (для подписи «Тон X%» в разборе); nil, если разбора ещё нет.
        let toneAverageScore: Int?
        let taikaHints: [String]
        let syllableFeedback: [SpeakerManager.SyllableFeedback]
        let breakdownRequestInFlight: Bool
        /// true, если запрос разбора по тонам завершился ошибкой (показать подсказку в карточке).
        let breakdownRequestFailed: Bool
        /// Гибридная оценка (0.4×текст + 0.3×фонема + 0.3×тон), если API вернул hybrid_score.
        let breakdownHybridScore: Int?
        let recordingMeter: Double
        let recordingPartialThai: String?
        let recordingPartialTranslit: String?
        let recordingPartialRU: String?
        let lastAttempt: URL?
        let attemptCount: Int
        let lastPlayed: SpeakerManager.LastPlayed
        let onPlayReference: () -> Void
        let onPlayAttempt: () -> Void
        let onPlayReferenceForId: ((UUID) -> Void)?
        let onMicTap: () -> Void
        let onNext: () -> Void
        let onPrev: (() -> Void)?
        let onRepeat: () -> Void
        let onSubmitText: (String) -> Void
        let onSelectFilter: (UUID) -> Void
        let onSelectCard: (UUID) -> Void
        let onShuffle: (() -> Void)?
        let onToggleFavorite: (() -> Void)?
        let isFavorite: Bool
        let resolveId: (StepData.SpeakerResolved) -> UUID
        let         lessonTitleForLessonId: ((String) -> String?)?
        /// When provided, parent controls breakdown overlay (e.g. PRO gate + paywall via onRequestBreakdown).
        let showBreakdownOverlay: Binding<Bool>?
        let onRequestBreakdown: (() -> Void)?
        /// Начать запись из разбора (разбор не закрываем; после стопа — обновить разбор на месте).
        let onRecordAgainFromBreakdown: (() -> Void)?
        /// Идёт запись, запущенная из разбора (показать «Стоп» в оверлее).
        let isRecordingFromBreakdown: Bool
        /// Остановить запись (из разбора); после анализа вызовется обновление разбора.
        let onStopRecordingFromBreakdown: (() -> Void)?
        /// Сбросить запись по текущей карточке (удалить попытку из хранилища и обнулить UI).
        let onClearAttempt: (() -> Void)?
        /// Умный спикер: сбросить результат (русский/тайский/транслит), вернуться к пустому состоянию.
        let onClearConversationResult: (() -> Void)?
        /// Second-level filter for "выученные": lesson IDs and current selection.
        let learnedLessonIds: [String]
        let learnedLessonFilter: String?
        let onSelectLearnedLessonFilter: ((String?) -> Void)?
        /// EPIC 2: when false, filter strip is hidden (filters only in header overlay).
        let showFilterStrip: Bool
        /// When Speaker was opened from a course card: course id, card count, session attempts and avg score for the strip under header.
        let courseContextCourseId: String?
        let courseContextCardCount: Int
        let courseContextAttemptCount: Int
        let courseContextAvgScore: Int
        /// Exit course-scoped Speaker context back to normal Speaker flow.
        let onExitCourseContext: (() -> Void)?
        /// Вернуться в обучение / избранное (вместо back в хедере).
        let onReturnToLearning: (() -> Void)?
        let returnToLearningTitle: String?
        let returnToLearningIcon: String?
        /// Open Courses tab to pick a course/lesson when Speaker has no cards.
        let onOpenCourses: (() -> Void)?
        /// Training launcher (idle "По фразам"): courses with learned phrases ready to practice, for the multi-select picker.
        let trainingCourseOptions: [SpeakerTrainingCourseOption]
        /// Training launcher: start a session scoped to the picked courses + lessons (empty lessons = all in those courses).
        let onStartCourseTraining: ((Set<String>, Set<String>) -> Void)?
        /// Быстрый старт: избранное / словарь (`__favorites__` / `__dictionary__`).
        let trainingFavoritesCount: Int
        let trainingDictionaryCount: Int
        let onStartSpecialTraining: ((String) -> Void)?
        /// UI mode: training (cards, filters) vs conversation (mic only).
        let speakerUIMode: SpeakerManager.SpeakerUIMode
        let onSpeakerUIModeChange: (SpeakerManager.SpeakerUIMode) -> Void
        /// Conversation mode: play TTS of the Thai result.
        let onPlayConversationTTS: () -> Void
        /// Conversation mode: reset and record again ("Повтори на тайском" or new phrase).
        let onConversationRepeat: () -> Void
        /// Conversation mode free-demo: run prepared RU phrase without recording.
        let onConversationDemoPhrase: ((String) -> Void)?
        /// Confirm draft: addToDictionary, startPractice.
        let onConfirmConversationDraft: ((Bool, Bool) -> Void)?
        /// Re-translate after editing Russian draft.
        let onRetranslateConversationDraft: ((String) -> Void)?
        /// Discard draft without committing to history.
        let onDiscardConversationDraft: (() -> Void)?
        /// Is current user PRO (for demo/onboarding branching in UI).
        let isProUser: Bool
        /// Full tone graph + syllables: Pro or still within today's free attempts.
        let hasFullToneBreakdownAccess: Bool
        /// Conversation mode: remaining demo attempts today (free); Pro ignores.
        let conversationRemainingToday: Int
        /// Conversation mode: elapsed recording seconds for timer ring; 0 when idle.
        let conversationRecordingElapsed: TimeInterval
        /// Conversation mode: max recording duration (seconds) for timer ring.
        let conversationRecordingMaxDuration: TimeInterval
        /// Conversation mode: whether user can start recording (attempts left or Pro).
        let conversationCanRecord: Bool
        /// Conversation mode: when non-nil, we're in "repeat and check" flow (recording/analyzing/feedback). Used to hide result block and show recording/feedback.
        let conversationExpectedThai: String?
        /// Conversation mode: expected translit for feedback block "нужно было" (set when entering pronunciation check).
        let conversationExpectedTranslitForFeedback: String?
        /// Тайский с ASR после проверки произношения (сырой текст микрофона).
        let conversationHeardThaiASR: String?
        /// Кириллическая фонетика распознанной фразы (POST /thai_phonetic) — как `heardTranslit` в практике.
        let conversationHeardPhoneticFromASR: String?
        /// Conversation mode: start pronunciation check (record Thai, then score).
        let onConversationRepeatAndCheck: () -> Void
        /// Smart Speaker: "male" | "female" | "kathoey".
        let smartSpeakerPoliteness: String
        /// Smart Speaker: persist politeness selection ("male" | "female" | "kathoey").
        let onSetSmartSpeakerPoliteness: (String) -> Void
        /// 0…1 во время воспроизведения эталона (TTS); для прорисовки графика тона 1:1 с аудио.
        let referencePlaybackProgress: Double
        /// Вызывается при появлении оверлея «разбор» — сбросить прогресс эталона, чтобы график «Эталон» был виден целиком.
        let onBreakdownAppear: (() -> Void)?
    }

    private let external: External?

#if DEBUG
    struct PreviewExternal {
        let current: SpeakerItem?
        let items: [SpeakerItem]
        let activeFilterId: UUID?
        let phase: SpeakerPhase
        let heardThai: String?
        let heardRU: String?
        let heardTranslit: String?
        let heardConfidence: Int
        let taikaHints: [String]
        let recordingMeter: Double
        let recordingPartialThai: String?
        let recordingPartialTranslit: String?
        let lastAttempt: URL?
        let attemptCount: Int
        let lastPlayed: SpeakerManager.LastPlayed
    }
#endif

#if DEBUG
    private let previewExternal: PreviewExternal?
#else
    private let previewExternal: Any? = nil
#endif


    // reference audio bubble (messenger-style)
    @State private var refIsPlaying: Bool = false
    @State private var helperHasInteracted: Bool = false
    @State private var helperIsVisible: Bool = true
    @State private var helperTypedText: String = ""

    // local fallback selection for DS (used when external.selectedId is not wired yet)
    @State private var localSelectedId: UUID? = nil
    @State private var isBreakdownExpanded: Bool = false

    @State private var showAnalysis: Bool = false
    @State private var showBreakdownOverlayLocal: Bool = false
    /// Снимок эталона при открытии разбора, чтобы слоги не «моргали» после ответа API.
    @State private var breakdownSnapshotExpected: String = ""
    @State private var breakdownSnapshotPhraseLabel: String = ""
    @State private var breakdownSnapshotScore: Int? = nil

    @State private var activeCardRect: CGRect = .zero
    @State private var hasActiveCardRect: Bool = false

    @ObservedObject private var favoriteManager = FavoriteManager.shared
    @ObservedObject private var conversationEngine = SpeakerManager.shared
    /// Выбранные курсы на экране-лаунчере тренировки; nil = «ещё не трогали» (тогда берём дефолт — все курсы с фразами).
    /// Optional, а не пустой Set по умолчанию — иначе «снять всё» не отличить от «ещё не открывали экран».
    @State private var selectedTrainingCourseIds: Set<String>? = nil
    /// Выбранные уроки по курсам; при первом выборе курса — все выученные уроки этого курса.
    @State private var selectedTrainingLessonIdsByCourse: [String: Set<String>] = [:]
    /// Раскрытый курс в списке (уроки с галочками).
    @State private var expandedTrainingCourseId: String? = nil
    @Environment(\.taikaRootHeaderClearance) private var rootHeaderClearance
    @State private var conversationThaiCopiedFlash = false
    /// По умолчанию true — иначе при сбое onAppear старт спикера остаётся невидимым.
    @State private var speakerInviteAppeared = true
    @State private var idleMicPulse = false
    @State private var conversationStageAppeared = true
    @State private var trainingTeaserIndex = 0
    @State private var conversationTeaserIndex = 0
    @State private var conversationComposeText = ""
    @State private var conversationEditRU = ""
    @State private var conversationTextComposerExpanded = false
    @FocusState private var conversationComposeFocused: Bool
    @FocusState private var conversationEditFocused: Bool

    /// Плейсхолдер «ты сказал», пока `/thai_phonetic` не вернул кириллицу (не показываем сырой тайский).
    private static let conversationPhoneticLoadingToken = "__taika_conv_phonetic_loading__"

    private var itemsCount: Int {
        allSpeakerItems.count
    }

    private var activeFilterTitle: String {
        let mode = SpeakerMode(id: activeFilterId ?? SpeakerMode.currentMode.id) ?? .current
        switch mode {
        case .current:
            return "последний урок"
        case .favorites:
            return "избранное"
        case .learned:
            return "выученные"
        case .random:
            return "случайные"
        }
    }

    private var activeFilterSubtitle: String? {
        let mode = SpeakerMode(id: activeFilterId ?? SpeakerMode.currentMode.id) ?? .current
        switch mode {
        case .current:
            if let lessonId = external?.current?.lessonId,
               let title = external?.lessonTitleForLessonId?(lessonId),
               !title.isEmpty {
                return title
            }
            // empty or unknown lesson: keep it minimal, user shouldn't think
            return itemsCount > 0 ? nil : "открой урок — появятся фразы"
        case .favorites:
            return itemsCount > 0 ? "сохранённые фразы" : "лайкни пару фраз — они появятся здесь"
        case .learned:
            return itemsCount > 0 ? "то, что уже пройдено" : "пока нет выученных фраз"
        case .random:
            return itemsCount > 0 ? "смешано из доступных" : "пока нечего перемешать"
        }
    }

    private var filterContextPill: some View {
        let accent = AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(activeFilterTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .lineLimit(1)

                Text("\(itemsCount) карт")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(itemsCount > 0 ? accent : AnyShapeStyle(PD.ColorToken.textSecondary))
                    .lineLimit(1)
            }

            if let subtitle = activeFilterSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .opacity(0.85)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(PD.ColorToken.chip.opacity(0.5))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: activeFilterId)
    }


    public init() {
        self.external = nil
#if DEBUG
        self.previewExternal = nil
#endif
    }

    // MARK: - stable ids (critical for canvas + scroll)
    // SwiftUI canvas can hang when ForEach ids are unstable or duplicated.
    // We generate a deterministic UUID from the resolved step identity.
    fileprivate static func stableResolvedId(courseId: String, lessonId: String, index: Int, kindRaw: String) -> UUID {
        let seed = "speaker|\(courseId)|\(lessonId)|\(index)|\(kindRaw)"
        let bytes = [UInt8](seed.utf8)
        // FNV-1a 64-bit x2 -> 128-bit UUID
        var h1: UInt64 = 14695981039346656037
        var h2: UInt64 = 1099511628211
        for b in bytes {
            h1 ^= UInt64(b)
            h1 &*= 1099511628211
            h2 ^= UInt64(b)
            h2 &*= 14695981039346656037
        }
        let uuid = UUID(uuid: (
            UInt8((h1 >> 56) & 0xff), UInt8((h1 >> 48) & 0xff), UInt8((h1 >> 40) & 0xff), UInt8((h1 >> 32) & 0xff),
            UInt8((h1 >> 24) & 0xff), UInt8((h1 >> 16) & 0xff), UInt8((h1 >> 8) & 0xff),  UInt8(h1 & 0xff),
            UInt8((h2 >> 56) & 0xff), UInt8((h2 >> 48) & 0xff), UInt8((h2 >> 40) & 0xff), UInt8((h2 >> 32) & 0xff),
            UInt8((h2 >> 24) & 0xff), UInt8((h2 >> 16) & 0xff), UInt8((h2 >> 8) & 0xff),  UInt8(h2 & 0xff)
        ))
        return uuid
    }

    init(
        current: StepData.SpeakerResolved?,
        items: [StepData.SpeakerResolved]? = nil,
        selectedId: UUID? = nil,
        activeFilterId: UUID? = nil,
        phase: SpeakerManager.Phase,
        heardThai: String? = nil,
        heardRU: String? = nil,
        heardTranslit: String? = nil,
        heardConfidence: Int = 0,
        displayScore: Int = 0,
        toneAverageScore: Int? = nil,
        taikaHints: [String] = [],
        syllableFeedback: [SpeakerManager.SyllableFeedback] = [],
        breakdownRequestInFlight: Bool = false,
        breakdownRequestFailed: Bool = false,
        breakdownHybridScore: Int? = nil,
        recordingMeter: Double = 0,
        recordingPartialThai: String? = nil,
        recordingPartialTranslit: String? = nil,
        recordingPartialRU: String? = nil,
        lastAttempt: URL? = nil,
        attemptCount: Int = 0,
        lastPlayed: SpeakerManager.LastPlayed = .none,
        onPlayReference: @escaping () -> Void,
        onPlayAttempt: @escaping () -> Void,
        onPlayReferenceForId: ((UUID) -> Void)? = nil,
        onMicTap: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrev: (() -> Void)? = nil,
        onRepeat: @escaping () -> Void,
        onSubmitText: @escaping (String) -> Void = { _ in },
        onSelectFilter: @escaping (UUID) -> Void = { _ in },
        onSelectCard: @escaping (UUID) -> Void = { _ in },
        onShuffle: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil,
        isFavorite: Bool = false,
        resolveId: @escaping (StepData.SpeakerResolved) -> UUID = { r in
            SpeakerDSRoot.stableResolvedId(courseId: r.courseId, lessonId: r.lessonId, index: r.index, kindRaw: String(describing: r.kind))
        },
        lessonTitleForLessonId: ((String) -> String?)? = nil,
        showBreakdownOverlay: Binding<Bool>? = nil,
        onRequestBreakdown: (() -> Void)? = nil,
        onRecordAgainFromBreakdown: (() -> Void)? = nil,
        isRecordingFromBreakdown: Bool = false,
        onStopRecordingFromBreakdown: (() -> Void)? = nil,
        onClearAttempt: (() -> Void)? = nil,
        onClearConversationResult: (() -> Void)? = nil,
        learnedLessonIds: [String] = [],
        learnedLessonFilter: String? = nil,
        onSelectLearnedLessonFilter: ((String?) -> Void)? = nil,
        showFilterStrip: Bool = true,
        courseContextCourseId: String? = nil,
        courseContextCardCount: Int = 0,
        courseContextAttemptCount: Int = 0,
        courseContextAvgScore: Int = 0,
        onExitCourseContext: (() -> Void)? = nil,
        onReturnToLearning: (() -> Void)? = nil,
        returnToLearningTitle: String? = nil,
        returnToLearningIcon: String? = nil,
        onOpenCourses: (() -> Void)? = nil,
        trainingCourseOptions: [SpeakerTrainingCourseOption] = [],
        onStartCourseTraining: ((Set<String>, Set<String>) -> Void)? = nil,
        trainingFavoritesCount: Int = 0,
        trainingDictionaryCount: Int = 0,
        onStartSpecialTraining: ((String) -> Void)? = nil,
        speakerUIMode: SpeakerManager.SpeakerUIMode = .training,
        onSpeakerUIModeChange: @escaping (SpeakerManager.SpeakerUIMode) -> Void = { _ in },
        onPlayConversationTTS: @escaping () -> Void = {},
        onConversationRepeat: @escaping () -> Void = {},
        onConversationDemoPhrase: ((String) -> Void)? = nil,
        onConfirmConversationDraft: ((Bool, Bool) -> Void)? = nil,
        onRetranslateConversationDraft: ((String) -> Void)? = nil,
        onDiscardConversationDraft: (() -> Void)? = nil,
        isProUser: Bool = false,
        hasFullToneBreakdownAccess: Bool = false,
        conversationRemainingToday: Int = 3,
        conversationRecordingElapsed: TimeInterval = 0,
        conversationRecordingMaxDuration: TimeInterval = 45,
        conversationCanRecord: Bool = true,
        conversationExpectedThai: String? = nil,
        conversationExpectedTranslitForFeedback: String? = nil,
        conversationHeardThaiASR: String? = nil,
        conversationHeardPhoneticFromASR: String? = nil,
        onConversationRepeatAndCheck: @escaping () -> Void = {},
        smartSpeakerPoliteness: String = "female",
        onSetSmartSpeakerPoliteness: @escaping (String) -> Void = { _ in },
        referencePlaybackProgress: Double = 1.0,
        onBreakdownAppear: (() -> Void)? = nil
    ) {
        self.external = External(
            current: current,
            items: items,
            selectedId: selectedId,
            activeFilterId: activeFilterId,
            phase: phase,
            heardThai: heardThai,
            heardRU: heardRU,
            heardTranslit: heardTranslit,
            heardConfidence: heardConfidence,
            displayScore: displayScore,
            toneAverageScore: toneAverageScore,
            taikaHints: taikaHints,
            syllableFeedback: syllableFeedback,
            breakdownRequestInFlight: breakdownRequestInFlight,
            breakdownRequestFailed: breakdownRequestFailed,
            breakdownHybridScore: breakdownHybridScore,
            recordingMeter: recordingMeter,
            recordingPartialThai: recordingPartialThai,
            recordingPartialTranslit: recordingPartialTranslit,
            recordingPartialRU: recordingPartialRU,
            lastAttempt: lastAttempt,
            attemptCount: attemptCount,
            lastPlayed: lastPlayed,
            onPlayReference: onPlayReference,
            onPlayAttempt: onPlayAttempt,
            onPlayReferenceForId: onPlayReferenceForId,
            onMicTap: onMicTap,
            onNext: onNext,
            onPrev: onPrev,
            onRepeat: onRepeat,
            onSubmitText: onSubmitText,
            onSelectFilter: onSelectFilter,
            onSelectCard: onSelectCard,
            onShuffle: onShuffle,
            onToggleFavorite: onToggleFavorite,
            isFavorite: isFavorite,
            resolveId: resolveId,
            lessonTitleForLessonId: lessonTitleForLessonId,
            showBreakdownOverlay: showBreakdownOverlay,
            onRequestBreakdown: onRequestBreakdown,
            onRecordAgainFromBreakdown: onRecordAgainFromBreakdown,
            isRecordingFromBreakdown: isRecordingFromBreakdown,
            onStopRecordingFromBreakdown: onStopRecordingFromBreakdown,
            onClearAttempt: onClearAttempt,
            onClearConversationResult: onClearConversationResult,
            learnedLessonIds: learnedLessonIds,
            learnedLessonFilter: learnedLessonFilter,
            onSelectLearnedLessonFilter: onSelectLearnedLessonFilter,
            showFilterStrip: showFilterStrip,
            courseContextCourseId: courseContextCourseId,
            courseContextCardCount: courseContextCardCount,
            courseContextAttemptCount: courseContextAttemptCount,
            courseContextAvgScore: courseContextAvgScore,
            onExitCourseContext: onExitCourseContext,
            onReturnToLearning: onReturnToLearning,
            returnToLearningTitle: returnToLearningTitle,
            returnToLearningIcon: returnToLearningIcon,
            onOpenCourses: onOpenCourses,
            trainingCourseOptions: trainingCourseOptions,
            onStartCourseTraining: onStartCourseTraining,
            trainingFavoritesCount: trainingFavoritesCount,
            trainingDictionaryCount: trainingDictionaryCount,
            onStartSpecialTraining: onStartSpecialTraining,
            speakerUIMode: speakerUIMode,
            onSpeakerUIModeChange: onSpeakerUIModeChange,
            onPlayConversationTTS: onPlayConversationTTS,
            onConversationRepeat: onConversationRepeat,
            onConversationDemoPhrase: onConversationDemoPhrase,
            onConfirmConversationDraft: onConfirmConversationDraft,
            onRetranslateConversationDraft: onRetranslateConversationDraft,
            onDiscardConversationDraft: onDiscardConversationDraft,
            isProUser: isProUser,
            hasFullToneBreakdownAccess: hasFullToneBreakdownAccess,
            conversationRemainingToday: conversationRemainingToday,
            conversationRecordingElapsed: conversationRecordingElapsed,
            conversationRecordingMaxDuration: conversationRecordingMaxDuration,
            conversationCanRecord: conversationCanRecord,
            conversationExpectedThai: conversationExpectedThai,
            conversationExpectedTranslitForFeedback: conversationExpectedTranslitForFeedback,
            conversationHeardThaiASR: conversationHeardThaiASR,
            conversationHeardPhoneticFromASR: conversationHeardPhoneticFromASR,
            onConversationRepeatAndCheck: onConversationRepeatAndCheck,
            smartSpeakerPoliteness: smartSpeakerPoliteness,
            onSetSmartSpeakerPoliteness: onSetSmartSpeakerPoliteness,
            referencePlaybackProgress: referencePlaybackProgress,
            onBreakdownAppear: onBreakdownAppear
        )
#if DEBUG
        self.previewExternal = nil
#endif
    }

#if DEBUG
    init(preview: PreviewExternal) {
        self.external = nil
        self.previewExternal = preview
    }
#endif

    private var isExternallyDriven: Bool {
        if external != nil { return true }
#if DEBUG
        if previewExternal != nil { return true }
#endif
        return false
    }

    private var extSelectedId: UUID? {
        external?.selectedId
    }

    private var externalResolveId: (StepData.SpeakerResolved) -> UUID {
        external?.resolveId ?? { _ in UUID() }
    }

    private var speakerUIMode: SpeakerManager.SpeakerUIMode {
        external?.speakerUIMode ?? .training
    }

    private var currentItem: SpeakerItem? {
#if DEBUG
        if let p = previewExternal {
            return p.current
        }
#endif

        guard let cur = external?.current else { return nil }
        return SpeakerItem(
            id: externalResolveId(cur),
            phrase: cur.face.subtitleTH,
            translit: cur.face.phonetic,
            hint: cur.face.titleRU,
            lessonTitle: speakerItemLessonTitle(for: cur.lessonId),
            kindTag: "фраза",
            isFavorite: false,
            isProLocked: false
        )
    }

    private var recordingPartialThai: String? {
#if DEBUG
        if let p = previewExternal {
            return p.recordingPartialThai
        }
#endif
        return external?.recordingPartialThai
    }

    private var recordingPartialTranslit: String? {
#if DEBUG
        if let p = previewExternal {
            return p.recordingPartialTranslit
        }
#endif
        return external?.recordingPartialTranslit
    }

    private var recordingMeter: Double {
#if DEBUG
        if let p = previewExternal {
            return p.recordingMeter
        }
#endif
        return external?.recordingMeter ?? 0
    }

    private var taikaHints: [String] {
#if DEBUG
        if let p = previewExternal {
            return p.taikaHints
        }
#endif
        return external?.taikaHints ?? []
    }

    private var syllableFeedback: [SpeakerManager.SyllableFeedback] {
        return external?.syllableFeedback ?? []
    }

    private var breakdownHybridScore: Int? {
        return external?.breakdownHybridScore
    }

#if DEBUG
    // Computed property to check if running for Xcode previews
    private var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
#endif

    private var phase: SpeakerPhase {
#if DEBUG
        if let p = previewExternal {
            return p.phase
        }
#endif

        guard let p = external?.phase else { return .idle }
        switch p {
        case .idle: return .idle
        case .recording: return .recording(start: Date())
        case .analyzing: return .analyzing
        case .analyzingTranslation: return .analyzing
        case .hint: return .hint
        case .feedback(let result): return .feedback(score: result.totalScore, hint: result.hint)
        }
    }

    private var effectiveShowBreakdown: Bool {
        get { external?.showBreakdownOverlay?.wrappedValue ?? showBreakdownOverlayLocal }
    }
    private func setEffectiveShowBreakdown(_ value: Bool) {
        if let b = external?.showBreakdownOverlay {
            b.wrappedValue = value
        } else {
            showBreakdownOverlayLocal = value
        }
    }

    private func dismissBreakdownSheet() {
        guard effectiveShowBreakdown else { return }
        breakdownSnapshotExpected = ""
        breakdownSnapshotPhraseLabel = ""
        breakdownSnapshotScore = nil
        setEffectiveShowBreakdown(false)
        // После тренировки из ленты — сразу к карточкам со скором, без залипшего «80%».
        if conversationIsPracticeFlow {
            external?.onConversationRepeat()
        }
    }

    /// Высота верхнего блока (карусель), чтобы вёрстка не скакала.
    /// Вертикальный квадрат как лайфхак — одна айдентика на оба режима.
    private let speakerTopContentHeight: CGFloat = CardDS.Metrics.stepLifehackHeight
    private var speakerCardWidth: CGFloat { CardDS.Metrics.stepLifehackWidth }
    private var speakerCardHeight: CGFloat { CardDS.Metrics.stepLifehackHeight }

    /// Подписи режимов — ценность, не «умный vs тупой».
    private var speakerModeChipTitle: String {
        switch external?.courseContextCourseId {
        case "__dictionary__": return "мой словарь"
        case "__favorites__": return "избранное"
        default:
            return speakerUIMode == .conversation ? "скажи сам" : "закрепление курсов"
        }
    }

    private func speakerItemLessonTitle(for lessonId: String) -> String? {
        switch external?.courseContextCourseId {
        case "__dictionary__": return "мой словарь"
        case "__favorites__": return "избранное"
        default:
            let title = external?.lessonTitleForLessonId?(lessonId)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (title?.isEmpty == false) ? title : nil
        }
    }

    private func conversationPhraseFontSize(for text: String, base: CGFloat = 17) -> CGFloat {
        let len = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        if len > 140 { return max(14, base - 5) }
        if len > 80 { return max(15, base - 3) }
        if len > 48 { return max(16, base - 1) }
        return base
    }

    @ViewBuilder
    private func conversationScrollableRussian(
        _ text: String,
        weight: Font.Weight = .semibold,
        baseSize: CGFloat = 17,
        accent: Bool = true
    ) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            EmptyView()
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                Text(trimmed)
                    .font(.system(size: conversationPhraseFontSize(for: trimmed, base: baseSize), weight: weight))
                    .foregroundStyle(
                        accent
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        : AnyShapeStyle(PD.ColorToken.textSecondary)
                    )
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: min(speakerTopContentHeight + 40, 280))
        }
    }

    @ViewBuilder
    private func conversationScrollablePhonetic(_ phonetic: String, font: Font = .system(size: 22, weight: .semibold)) -> some View {
        let trimmed = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            EmptyView()
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                PhoneticWithColoredArrowsView(phonetic: trimmed, font: font)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: 220)
        }
    }

    /// Тренировка: карусель + панель. «Своя речь» идёт через `conversationLiveWidget`.
    @ViewBuilder private var unifiedSpeakerBody: some View {
        trainingUnifiedBody
    }

    private var trainingUnifiedBody: some View {
        let padH = Theme.Layout.pageHorizontal
        let gap = Theme.Layout.sectionGap
        let returnTitle = external?.returnToLearningTitle
        let returnIcon = external?.returnToLearningIcon ?? "graduationcap.fill"
        let onReturn = external?.onReturnToLearning
        return VStack(spacing: 0) {
            topCarousel
                .frame(maxWidth: .infinity)
                .frame(height: CardDS.Metrics.speakerPhraseCardHeight + 12)
                .padding(.top, gap)

            Rectangle()
                .fill(PD.ColorToken.chip)
                .frame(height: 1)
                .padding(.top, gap)
                .padding(.horizontal, padH)

            speakerPlayerPanel
                .padding(.top, gap)
                .padding(.horizontal, padH)

            Group {
                switch phase {
                case .feedback:
                    simpleResultBlock
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                case .recording:
                    trainingRecordingBlock
                        .transition(.opacity)
                case .analyzing:
                    trainingAnalyzingBlock
                        .transition(.opacity)
                default:
                    idleHelperHint
                }
            }
            .animation(.easeInOut(duration: 0.45), value: phase.label)
            .padding(.top, gap)
            .padding(.horizontal, padH)
            .padding(.bottom, onReturn == nil ? ToolBar.recommendedBottomInset + 18 : 10)

            if !phase.isFeedback {
                Spacer(minLength: 0)
            }

            if let onReturn, let returnTitle, !returnTitle.isEmpty {
                MDMainOutlinePillCTA(
                    title: returnTitle,
                    icon: returnIcon,
                    action: onReturn
                )
                .padding(.horizontal, padH)
                .padding(.top, 4)
                .padding(.bottom, ToolBar.recommendedBottomInset + 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.22), value: phase.label)
        .animation(.easeInOut(duration: 0.22), value: onReturn != nil)
    }

    // MARK: - Своя речь: один живой виджет (лента + live + sticky mic)

    /// Фокус-сценарий (запись / перевод / результат / тренировка / разбор / текстовый ввод): лента уходит под blur.
    private var conversationNeedsFocusOverlay: Bool {
        if conversationTextComposerExpanded { return true }
        if phase.isFeedback { return true }
        if conversationIsPracticeFlow { return true }
        if case .recording = phase { return true }
        if phase == .analyzing { return true }
        // Активный перевод ещё не в ленте — держим фокус, иначе UI падает в idle/ленту.
        if conversationHasResult { return true }
        if phase == .hint, !taikaHints.isEmpty { return true }
        return false
    }

    /// Лента всегда на месте; live — поверх с нативным material+scrim (как lifehack/разбор), без «чёрной дыры».
    @ViewBuilder private var conversationLiveWidget: some View {
        let padH = ToolBar.contentHorizontalInset
        let history = conversationEngine.conversationHistory
        let focused = conversationNeedsFocusOverlay
        let liveStage = focused && !phase.isFeedback && !conversationTextComposerExpanded

        ZStack {
            VStack(spacing: 0) {
                if history.isEmpty, !focused {
                    Spacer(minLength: 8)
                    conversationWidgetIdleCenter
                        .padding(.horizontal, padH)
                    Spacer(minLength: 8)
                } else if !history.isEmpty {
                    conversationHistoryFeed(history)
                        .padding(.horizontal, padH)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                }

                if !focused {
                    conversationUnifiedInputBar
                        .padding(.horizontal, padH)
                        .padding(.top, 10)
                        .padding(.bottom, ToolBar.recommendedBottomInset + 12)
                } else {
                    Color.clear
                        .frame(height: ToolBar.recommendedBottomInset + 100)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(!focused)

            if focused {
                conversationFocusGlassBackdrop
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        if conversationTextComposerExpanded {
                            collapseConversationTextComposer(clearText: true)
                        }
                    }

                VStack(spacing: 0) {
                    if conversationTextComposerExpanded,
                       !conversationHasResult,
                       !conversationIsRecording,
                       phase != .analyzing,
                       !phase.isFeedback {
                        Spacer(minLength: 0)
                        conversationTextComposerPanel
                            .padding(.horizontal, padH)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: .bottom)),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                )
                            )
                        .padding(.bottom, ToolBar.recommendedBottomInset + 12)
                    } else if phase.isFeedback {
                        if conversationIsPracticeFlow, effectiveShowBreakdown {
                            // Разбор уже открыт — промежуточный скор не дублируем.
                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 8)
                            conversationFocusCard
                                .padding(.horizontal, padH)
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            Spacer(minLength: 8)
                            conversationIconChrome
                                .padding(.horizontal, padH)
                                .padding(.top, 4)
                            conversationStickyMicBar
                                .padding(.horizontal, padH)
                                .padding(.top, 8)
                                .padding(.bottom, ToolBar.recommendedBottomInset + 12)
                        }
                    } else if conversationIsRecording || phase == .analyzing {
                        // Live всегда выше «результата»: иначе тренировка из карточки
                        // (heardThai уже есть) прячет орб и оставляет только кнопку Stop.
                        Spacer(minLength: 4)
                        conversationLiveStage
                            .padding(.horizontal, padH)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        Spacer(minLength: 4)
                        Color.clear
                            .frame(height: ToolBar.recommendedBottomInset + 8)
                    } else if conversationHasResult {
                        // Активный перевод: одна карточка + компактные действия.
                        Spacer(minLength: 8)
                        conversationWidgetResultCenter
                            .padding(.horizontal, padH)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        Spacer(minLength: 8)
                        conversationResultActions
                            .padding(.horizontal, padH)
                            .padding(.top, 4)
                            .padding(.bottom, ToolBar.recommendedBottomInset + 12)
                    } else if phase == .hint, !taikaHints.isEmpty {
                        Spacer(minLength: 8)
                        conversationWidgetErrorCenter
                            .padding(.horizontal, padH)
                        Spacer(minLength: 8)
                        conversationUnifiedInputBar
                            .padding(.horizontal, padH)
                            .padding(.top, 8)
                            .padding(.bottom, ToolBar.recommendedBottomInset + 12)
                    } else {
                        Spacer(minLength: 4)
                        conversationLiveStage
                            .padding(.horizontal, padH)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        Spacer(minLength: 4)
                        Color.clear
                            .frame(height: ToolBar.recommendedBottomInset + 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: conversationWidgetStateKey)
        .animation(.easeInOut(duration: 0.22), value: history.count)
        .animation(.easeInOut(duration: 0.22), value: focused)
        .animation(.easeInOut(duration: 0.22), value: liveStage)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: conversationTextComposerExpanded)
    }

    @ViewBuilder private var conversationFocusGlassBackdrop: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            Color.black.opacity(0.58)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.04),
                    Color.clear,
                    Color.black.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)
            ConversationLiveAmbientGlow(
                accent: ThemeManager.shared.currentAccentTintColor,
                intense: conversationIsRecording
            )
        }
    }

    /// Карточка только для feedback (компакт). Live-запись — через `conversationLiveStage`.
    @ViewBuilder private var conversationFocusCard: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        conversationWidgetLiveZone
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(Theme.Surfaces.card(shape))
            .overlay(shape.stroke(Theme.Strokes.strokeSubtle.opacity(0.7), lineWidth: Theme.Strokes.strokeLineWidth))
            .shadow(color: Color.black.opacity(0.28), radius: 20, y: 8)
    }

    /// Immersive live: орб + live-текст + mic в центре. Не серая «карточка статуса».
    @ViewBuilder private var conversationLiveStage: some View {
        let accentFill = ThemeManager.shared.currentAccentFill
        let accentTint = ThemeManager.shared.currentAccentTintColor
        let isRec = conversationIsRecording
        let isBusy = phase == .analyzing
        let mode: ConversationVoiceOrb.Mode = {
            if conversationIsPracticeFlow { return isRec ? .practice : .processing }
            if isRec { return .listening }
            return .processing
        }()

        VStack(spacing: 18) {
            conversationLiveStatusChip

            conversationLiveHeroText
                .frame(minHeight: 72)
                .frame(maxHeight: 160)
                .padding(.horizontal, 8)

            ZStack {
                ConversationVoiceOrb(
                    meter: recordingMeter,
                    mode: mode,
                    accent: accentTint
                )
                .frame(width: 220, height: 220)

                if isBusy {
                    ZStack {
                        Circle()
                            .fill(accentFill)
                            .frame(width: 64, height: 64)
                            .shadow(color: accentTint.opacity(0.45), radius: 16, y: 4)
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.black)
                            .scaleEffect(0.9)
                    }
                    .allowsHitTesting(false)
                    .accessibilityLabel("Обработка")
                } else {
                    conversationLiveMicButton(
                        size: isRec ? 76 : 68,
                        symbol: isRec ? "stop.fill" : "mic.fill",
                        pulsing: false,
                        recording: isRec
                    )
                    .accessibilityLabel(isRec ? "Стоп" : "Микрофон")
                }
            }
            .frame(height: 230)

            if isRec {
                ConversationLiveWaveRibbon(meter: recordingMeter)
                    .frame(height: 36)
                    .frame(maxWidth: 280)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if isBusy {
                ConversationLiveProcessTicks()
                    .frame(height: 28)
                    .transition(.opacity)
            }

            conversationLivePipelineHint
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var conversationLiveStatusChip: some View {
        let isRec = conversationIsRecording
        let label: String = {
            if conversationIsPracticeFlow {
                if isRec { return "говори по-тайски" }
                return "сравниваю"
            }
            if isRec { return "слушаю" }
            if (external?.heardRU?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) {
                return "перевожу"
            }
            return "распознаю"
        }()
        HStack(spacing: 8) {
            if isRec {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.red.opacity(0.65), radius: 4)
                    .accessibilityHidden(true)
            }
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(ThemeManager.shared.currentAccentTintColor.opacity(isRec ? 0.22 : 0.14))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(
                            ThemeManager.shared.currentAccentFill.opacity(isRec ? 0.55 : 0.28),
                            lineWidth: 1
                        )
                )
        )
        .accessibilityLabel(isRec ? "Идёт запись, \(label)" : label)
    }

    @ViewBuilder private var conversationLiveHeroText: some View {
        if conversationIsPracticeFlow {
            conversationWidgetPhoneticStack(
                russian: nil,
                phonetic: (external?.conversationExpectedTranslitForFeedback ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                thai: (external?.conversationExpectedThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else if conversationIsRecording {
            let partial = recordingPartialRU.trimmingCharacters(in: .whitespacesAndNewlines)
            ScrollView(.vertical, showsIndicators: false) {
                Text(partial.isEmpty ? "…" : partial)
                    .font(.system(size: partial.count > 42 ? 22 : 28, weight: .bold, design: .rounded))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeOut(duration: 0.15), value: partial)
            }
            .frame(maxWidth: .infinity, maxHeight: 140)
        } else if let ru = external?.heardRU?.trimmingCharacters(in: .whitespacesAndNewlines), !ru.isEmpty {
            VStack(spacing: 10) {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(ru)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(PD.ColorToken.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: 96)
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill.opacity(0.8))
                Text("тайский")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                    .opacity(0.9)
            }
            .frame(maxWidth: .infinity)
        } else {
            Text("ловлю речь…")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var conversationLivePipelineHint: some View {
        let steps: [(String, Bool)] = {
            if conversationIsPracticeFlow {
                let rec = conversationIsRecording
                let busy = phase == .analyzing
                return [
                    ("фраза", true),
                    ("запись", rec || busy),
                    ("оценка", busy == false && phase.isFeedback)
                ]
            }
            let rec = conversationIsRecording
            let hasRU = !(external?.heardRU?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let busy = phase == .analyzing
            return [
                ("речь", true),
                ("текст", !rec),
                ("перевод", !rec && hasRU && busy)
            ]
        }()
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                if idx > 0 {
                    Capsule()
                        .fill(step.1
                              ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.55))
                              : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.25)))
                        .frame(width: 22, height: 2)
                        .padding(.horizontal, 6)
                }
                Text(step.0)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        step.1
                        ? AnyShapeStyle(PD.ColorToken.text)
                        : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.45))
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var conversationWidgetStateKey: String {
        if conversationTextComposerExpanded { return "text-compose" }
        if phase.isFeedback { return "feedback" }
        if conversationIsPracticeFlow {
            if case .recording = phase { return "practice-rec" }
            if phase == .analyzing { return "practice-analyzing" }
        }
        if case .recording = phase { return "listening" }
        if phase == .analyzing { return "analyzing" }
        if conversationHasResult { return "result" }
        if phase == .hint, !taikaHints.isEmpty { return "error" }
        return conversationEngine.conversationHistory.isEmpty ? "idle-empty" : "idle-ready"
    }

    private var conversationIsPracticeFlow: Bool {
        (external?.conversationExpectedThai?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    private var conversationIsRecording: Bool {
        if case .recording = phase { return true }
        return false
    }

    // MARK: History feed

    @ViewBuilder private func conversationHistoryFeed(_ history: [SpeakerConversationHistoryItem]) -> some View {
        let micReserve: CGFloat = 108
        List {
            ForEach(history) { item in
                conversationHistoryRow(item)
                    .listRowInsets(EdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            conversationEngine.removeConversationHistoryItem(id: item.id)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        let inDict = !item.thai.isEmpty
                            && favoriteManager.hasSmartSpeakerDictionaryEntry(thai: item.thai)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            conversationHistoryToggleDictionary(item)
                        } label: {
                            Label(inDict ? "В словаре" : "В словарь", systemImage: inDict ? "bookmark.fill" : "plus.circle.fill")
                        }
                        .tint(ThemeManager.shared.currentAccentTintColor)
                    }
            }
            Color.clear
                .frame(height: micReserve)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private func conversationHistoryRow(_ item: SpeakerConversationHistoryItem) -> some View {
        let inDict = !item.thai.isEmpty && favoriteManager.hasSmartSpeakerDictionaryEntry(thai: item.thai)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if !item.russian.isEmpty {
                    Text(item.russian)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    if let score = item.lastPracticeScore {
                        Text("\(score)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ThemeManager.shared.currentAccentTintColor.opacity(0.16))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(ThemeManager.shared.currentAccentFill.opacity(0.55), lineWidth: 1)
                                    )
                            )
                            .accessibilityLabel("Тренировка \(score) процентов")
                    }
                    conversationHistoryPlayButton(item)
                    conversationHistoryMoreMenu(item: item, inDict: inDict)
                }
            }

            if !item.phonetic.isEmpty || !item.thai.isEmpty {
                Rectangle()
                    .fill(PD.ColorToken.chip.opacity(0.85))
                    .frame(height: 1)
            }

            if !item.phonetic.isEmpty {
                PhoneticWithColoredArrowsView(
                    phonetic: item.phonetic,
                    font: .system(size: 16, weight: .semibold),
                    alignment: .leading
                )
                .fixedSize(horizontal: false, vertical: true)
            }

            if !item.thai.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.thai)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        copyConversationThaiToClipboard(item.thai)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(PD.ColorToken.chip.opacity(0.9)))
                            .overlay(
                                Circle()
                                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Скопировать тайский")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Surfaces.card(shape))
        .overlay(shape.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
        .contentShape(shape)
        .contextMenu {
            Button {
                conversationEngine.playConversationHistoryTTS(item)
            } label: {
                Label("Послушать", systemImage: "speaker.wave.2.fill")
            }
            if !item.thai.isEmpty {
                Button {
                    copyConversationThaiToClipboard(item.thai)
                } label: {
                    Label("Скопировать тайский", systemImage: "doc.on.doc")
                }
            }
            Button {
                conversationEngine.activateConversationHistoryItem(item)
                external?.onConversationRepeatAndCheck()
            } label: {
                Label("Тренировка", systemImage: "person.wave.2.fill")
            }
            Button {
                conversationHistoryToggleDictionary(item)
            } label: {
                Label(
                    inDict ? "Открыть словарь" : "В словарь",
                    systemImage: inDict ? "bookmark.fill" : "plus.circle.fill"
                )
            }
            Divider()
            Button(role: .destructive) {
                conversationEngine.removeConversationHistoryItem(id: item.id)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private func copyConversationThaiToClipboard(_ thai: String) {
        let trimmed = thai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIPasteboard.general.string = trimmed
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @ViewBuilder private func conversationHistoryMoreMenu(
        item: SpeakerConversationHistoryItem,
        inDict: Bool
    ) -> some View {
        Menu {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                conversationEngine.activateConversationHistoryItem(item)
                external?.onConversationRepeatAndCheck()
            } label: {
                Label("Тренировка", systemImage: "person.wave.2.fill")
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                conversationHistoryToggleDictionary(item)
            } label: {
                Label(
                    inDict ? "Открыть словарь" : "В словарь",
                    systemImage: inDict ? "bookmark.fill" : "plus.circle.fill"
                )
            }

            if !item.thai.isEmpty {
                Button {
                    copyConversationThaiToClipboard(item.thai)
                } label: {
                    Label("Скопировать тайский", systemImage: "doc.on.doc")
                }
            }

            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                conversationEngine.removeConversationHistoryItem(id: item.id)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(PD.ColorToken.chip.opacity(0.9)))
                .overlay(
                    Circle()
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
                .contentShape(Circle())
        }
        .accessibilityLabel("Ещё")
    }

    private func conversationHistoryPlayButton(_ item: SpeakerConversationHistoryItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            conversationEngine.playConversationHistoryTTS(item)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                .frame(width: 34, height: 34)
                .background(Circle().fill(PD.ColorToken.chip.opacity(0.9)))
                .overlay(
                    Circle()
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Послушать")
    }

    private func conversationHistoryToggleDictionary(_ item: SpeakerConversationHistoryItem) {
        let thai = item.thai.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thai.isEmpty else { return }
        if favoriteManager.hasSmartSpeakerDictionaryEntry(thai: thai) {
            NotificationCenter.default.post(name: .taikaOpenSmartSpeakerDictionary, object: nil)
        } else {
            favoriteManager.addSmartSpeakerCard(
                ru: item.russian,
                thai: item.thai,
                phonetic: item.phonetic
            )
        }
    }

    // MARK: Live zone (morphing)

    @ViewBuilder private var conversationWidgetLiveZone: some View {
        if phase.isFeedback {
            conversationWidgetFeedbackCenter
        } else if conversationIsPracticeFlow, conversationIsRecording {
            conversationWidgetPracticeCenter
        } else if conversationIsPracticeFlow, phase == .analyzing {
            conversationWidgetAnalyzingCenter(label: "слушаю…")
        } else if conversationIsRecording {
            conversationWidgetListeningCenter
        } else if phase == .analyzing {
            conversationWidgetAnalyzingCenter(label: {
                if (external?.heardRU?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) {
                    return "перевожу…"
                }
                return "распознаю…"
            }())
        } else if conversationHasResult {
            conversationWidgetResultCenter
        } else if phase == .hint, !taikaHints.isEmpty {
            conversationWidgetErrorCenter
        } else if conversationEngine.conversationHistory.isEmpty {
            conversationWidgetIdleCenter
        } else {
            Text("Скажи или напиши")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder private var conversationWidgetIdleCenter: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            TaikaEmptyStateIcon(systemName: "mic")

            Text("Скажи или напиши")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
                .multilineTextAlignment(.center)

            Text("Микрофон — голосом, клавиатура — текстом. Тайка переведёт и даст потренировать.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            if external?.isProUser != true {
                Text(Self.attemptsLeftLabel(max(0, external?.conversationRemainingToday ?? 0)))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.65))
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var conversationWidgetListeningCenter: some View {
        VStack(spacing: 12) {
            Text(recordingPartialRU.isEmpty ? "Слушаю…" : recordingPartialRU)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
            MiniWaveform(meter: recordingMeter)
                .frame(height: 26)
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder private func conversationWidgetAnalyzingCenter(label: String) -> some View {
        VStack(spacing: 12) {
            if let ru = external?.heardRU?.trimmingCharacters(in: .whitespacesAndNewlines), !ru.isEmpty,
               !conversationIsPracticeFlow {
                Text(ru)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            if conversationIsPracticeFlow {
                conversationWidgetPhoneticStack(
                    russian: nil,
                    phonetic: (external?.conversationExpectedTranslitForFeedback ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    thai: (external?.conversationExpectedThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            conversationLoadingBlock(label: label)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var conversationWidgetResultCenter: some View {
        let ph = (external?.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let thai = (external?.heardThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let heard = (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let editTrimmed = conversationEditRU.trimmingCharacters(in: .whitespacesAndNewlines)
        let canRetranslate = !editTrimmed.isEmpty && editTrimmed != heard
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ПО-РУССКИ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))

                HStack(alignment: .top, spacing: 10) {
                    TextField("Русская фраза", text: $conversationEditRU, axis: .vertical)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .lineLimit(1...4)
                        .focused($conversationEditFocused)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)

                    if canRetranslate {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            conversationEditFocused = false
                            external?.onRetranslateConversationDraft?(editTrimmed)
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(ThemeManager.shared.currentAccentFill))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Перевести заново")
                    }
                }
            }

            if !ph.isEmpty || !thai.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    Text("КАК СКАЗАТЬ")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.72))

                    conversationWidgetPhoneticStack(russian: nil, phonetic: ph, thai: thai)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Surfaces.blackGlass(shape))
        .onAppear {
            if conversationEditRU.isEmpty || conversationEditRU == heard || !conversationEditFocused {
                conversationEditRU = heard
            }
        }
        .onChange(of: heard) { _, newVal in
            if !conversationEditFocused {
                conversationEditRU = newVal
            }
        }
    }

    @ViewBuilder private var conversationWidgetPracticeCenter: some View {
        VStack(spacing: 12) {
            conversationWidgetPhoneticStack(
                russian: nil,
                phonetic: (external?.conversationExpectedTranslitForFeedback ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                thai: (external?.conversationExpectedThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
            Text("Говорите…")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
            MiniWaveform(meter: recordingMeter)
                .frame(height: 24)
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity)
    }

    /// Компакт после попытки: скор + подсказка. Полный разбор открывается сразу оверлеем.
    @ViewBuilder private var conversationWidgetFeedbackCenter: some View {
        if case .feedback(let score, let hint) = phase {
            let scoreToShow = external?.displayScore ?? score
            let hintText = (hint ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            VStack(spacing: 10) {
                SpeakerCountingScore(
                    value: scoreToShow,
                    font: .taikaStat(72),
                    color: AnyShapeStyle(ThemeManager.shared.currentAccentFill),
                    suffix: "%"
                )
                Text(scoreToShow >= 80 ? "почти идеально" : "есть неточности")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                if !hintText.isEmpty {
                    Text(hintText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    /// Кириллица если есть; иначе сразу тайский ASR (не вечный «Загружаем…»).
    private var conversationFeedbackUserText: String {
        let ph = (external?.conversationHeardPhoneticFromASR ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !ph.isEmpty { return ph }
        let asr = (external?.conversationHeardThaiASR ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !asr.isEmpty { return asr }
        let fallback = heardTranslitText
        return fallback.isEmpty ? "—" : fallback
    }

    @ViewBuilder private var conversationWidgetErrorCenter: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(spacing: 10) {
            Image(systemName: "ear.trianglebadge.exclamationmark")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)

            if let ru = external?.heardRU?.trimmingCharacters(in: .whitespacesAndNewlines), !ru.isEmpty {
                Text(ru)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            Text(taikaHints.joined(separator: " "))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(Theme.Surfaces.blackGlass(shape))
    }

    @ViewBuilder private func conversationWidgetPhoneticStack(
        russian: String?,
        phonetic: String,
        thai: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let russian, !russian.isEmpty {
                Text(russian)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !phonetic.isEmpty {
                PhoneticWithColoredArrowsView(
                    phonetic: phonetic,
                    font: .system(size: phonetic.count > 36 ? 17 : 21, weight: .semibold),
                    alignment: .leading
                )
            }

            if !thai.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text(thai)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        copyConversationThaiToClipboard(thai)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(PD.ColorToken.chip.opacity(0.9)))
                            .overlay(
                                Circle()
                                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Скопировать тайский")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: Footer actions + sticky mic

    /// Иконки как в `speakerPlayerPanel` тренинга — без текстовых pills «Послушать / Тренировка / Ещё раз / Готово».
    @ViewBuilder private var conversationIconChrome: some View {
        if phase.isFeedback {
            conversationFeedbackIconChrome
        } else {
            EmptyView()
        }
    }

    private func conversationChromeIconButton(
        systemName: String,
        enabled: Bool,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard enabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    enabled
                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                    : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.35))
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(accessibility)
    }

    /// Слушать / тренировать / закрыть + одна CTA «в ленту».
    @ViewBuilder private var conversationResultActions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 28) {
                Spacer(minLength: 0)
                conversationChromeIconButton(
                    systemName: "speaker.wave.2.fill",
                    enabled: true,
                    accessibility: "Послушать"
                ) {
                    external?.onPlayConversationTTS()
                }
                conversationChromeIconButton(
                    systemName: "mic.fill",
                    enabled: true,
                    accessibility: "Тренировать"
                ) {
                    conversationEditFocused = false
                    external?.onConfirmConversationDraft?(true, true)
                }
                conversationChromeIconButton(
                    systemName: "xmark",
                    enabled: true,
                    accessibility: "Закрыть без сохранения"
                ) {
                    conversationEditFocused = false
                    conversationEditRU = ""
                    external?.onDiscardConversationDraft?()
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                conversationEditFocused = false
                external?.onConfirmConversationDraft?(true, false)
                conversationEditRU = ""
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("В ленту и словарь")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(
                    Capsule(style: .continuous)
                        .fill(ThemeManager.shared.currentAccentFill)
                )
            }
            .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
            .accessibilityLabel("В ленту и словарь")
        }
    }

    @ViewBuilder private var conversationFeedbackIconChrome: some View {
        HStack(spacing: 28) {
            Spacer(minLength: 0)

            conversationChromeIconButton(
                systemName: "speaker.wave.2.fill",
                enabled: true,
                accessibility: "Эталон"
            ) {
                if conversationIsPracticeFlow {
                    external?.onPlayReference()
                } else {
                    external?.onPlayConversationTTS()
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                external?.onConversationRepeatAndCheck()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(ThemeManager.shared.currentAccentFill))
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ещё раз")

            conversationChromeIconButton(
                systemName: "xmark",
                enabled: true,
                accessibility: "К ленте"
            ) {
                setEffectiveShowBreakdown(false)
                external?.onConversationRepeat()
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    @ViewBuilder private var conversationComposeAndMicFooter: some View {
        conversationUnifiedInputBar
    }

    /// Одна полоса: голос (основное) + клавиатура (раскрывает окно ввода). Ширина = капсула тулбара.
    @ViewBuilder private var conversationUnifiedInputBar: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    conversationTextComposerExpanded = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    conversationComposeFocused = true
                }
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(PD.ColorToken.chip.opacity(0.95)))
                    .overlay(
                        Circle()
                            .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                    )
            }
            .buttonStyle(PressDownStyle(scale: 0.94, fade: 0.96))
            .accessibilityLabel("Написать фразу")

            conversationStickyMicBar
        }
    }

    /// Развёрнутое окно текстового ввода на жидком стекле (не поверх сырой ленты).
    @ViewBuilder private var conversationTextComposerPanel: some View {
        let canSubmit = !conversationComposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (external?.conversationCanRecord ?? true)
            && phase != .analyzing
            && !conversationIsRecording
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("Напиши по-русски")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Spacer(minLength: 0)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    collapseConversationTextComposer(clearText: true)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть")
            }

            TextField("Любая фраза…", text: $conversationComposeText, axis: .vertical)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(PD.ColorToken.text)
                .lineLimit(3...6)
                .focused($conversationComposeFocused)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.go)
                .onSubmit { submitConversationCompose() }
                .padding(.horizontal, 4)
                .frame(minHeight: 88, alignment: .topLeading)

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    collapseConversationTextComposer(clearText: true)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Голосом")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(PD.ColorToken.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
                .accessibilityLabel("Голосом")

                Button {
                    submitConversationCompose()
                } label: {
                    HStack(spacing: 8) {
                        Text("Перевести")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                canSubmit
                                ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                : AnyShapeStyle(Color.white.opacity(0.14))
                            )
                    )
                    .opacity(canSubmit ? 1 : 0.55)
                }
                .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
                .disabled(!canSubmit)
                .accessibilityLabel("Перевести")
            }
        }
        .padding(18)
        .background(Theme.Surfaces.blackGlass(shape))
    }

    private func collapseConversationTextComposer(clearText: Bool) {
        conversationComposeFocused = false
        if clearText { conversationComposeText = "" }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            conversationTextComposerExpanded = false
        }
    }

    private func submitConversationCompose() {
        let text = conversationComposeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard external?.conversationCanRecord ?? true else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            external?.onMicTap()
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        collapseConversationTextComposer(clearText: true)
        external?.onConversationDemoPhrase?(text)
    }

    /// CTA записи внизу — pill как в тренировочном спикере (не просто кружок mic).
    @ViewBuilder private var conversationStickyMicBar: some View {
        let canRecord = external?.conversationCanRecord ?? true
        let isRec = conversationIsRecording
        let isBusy = phase == .analyzing
        let isPro = external?.isProUser == true
        let remaining = max(0, external?.conversationRemainingToday ?? 0)
        let title: String = {
            if isRec { return "Стоп" }
            if isBusy { return "Секунду…" }
            if !canRecord { return "Попытки закончились" }
            return "Мгновенный перевод"
        }()
        let subtitle: String? = {
            if isRec || isBusy { return nil }
            if !canRecord { return "открой Taika+ — безлимит" }
            if isPro { return nil }
            return Self.attemptsLeftLabel(remaining)
        }()

        Button {
            if isBusy { return }
            collapseConversationTextComposer(clearText: false)
            if !canRecord && !isRec {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                external?.onMicTap()
                return
            }
            UIImpactFeedbackGenerator(style: isRec ? .medium : .light).impactOccurred()
            external?.onMicTap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isRec ? "stop.fill" : (canRecord ? "mic.fill" : "lock.fill"))
                    .font(.system(size: 15, weight: .bold))
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .opacity(0.72)
                            .lineLimit(1)
                    }
                }
            }
            .foregroundColor(isRec ? .white : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, subtitle == nil ? 14 : 10)
            .padding(.horizontal, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isRec
                        ? AnyShapeStyle(Color.red.opacity(0.92))
                        : AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                    )
            )
            .opacity(isBusy ? 0.55 : 1)
            .scaleEffect(idleMicPulse && canRecord && !isRec && !isBusy && !phase.isFeedback && !conversationHasResult && !conversationIsPracticeFlow ? 1.02 : 1.0)
            .animation(
                canRecord && !isRec && !isBusy
                ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                : .spring(response: 0.32, dampingFraction: 0.82),
                value: idleMicPulse
            )
            .onAppear {
                if canRecord && !isRec && !isBusy { idleMicPulse = true }
            }
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.97))
        .disabled(isBusy)
        .accessibilityLabel(title)
    }

    /// Крупный микрофон виджета — растёт в Listening, становится stop при записи.
    private func conversationLiveMicButton(
        size: CGFloat,
        symbol: String,
        pulsing: Bool,
        recording: Bool = false
    ) -> some View {
        let canRecord = external?.conversationCanRecord ?? true
        let accent = ThemeManager.shared.currentAccentFill
        let accentColor = ThemeManager.shared.currentAccentTintColor
        return Button {
            if !recording && !canRecord {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else {
                UIImpactFeedbackGenerator(style: recording ? .medium : .light).impactOccurred()
            }
            external?.onMicTap()
        } label: {
            ZStack {
                if recording {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: size + 28, height: size + 28)
                } else {
                    Circle()
                        .stroke(accent.opacity(0.35), lineWidth: 1.4)
                        .frame(width: size + 36, height: size + 36)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentColor.opacity(0.28), Color.clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: size * 0.72
                            )
                        )
                        .frame(width: size + 22, height: size + 22)
                }
                Circle()
                    .fill(recording ? AnyShapeStyle(Color.red.opacity(0.92)) : AnyShapeStyle(accent))
                    .frame(width: size, height: size)
                    .shadow(color: (recording ? Color.red : accentColor).opacity(0.4), radius: 14, y: 5)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.30, weight: .bold))
                    .foregroundColor(recording ? .white : .black)
            }
            .scaleEffect(pulsing && idleMicPulse ? 1.04 : 1.0)
            .animation(
                pulsing
                ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                : .spring(response: 0.32, dampingFraction: 0.82),
                value: idleMicPulse
            )
            .onAppear { if pulsing { idleMicPulse = true } }
        }
        .buttonStyle(.plain)
    }

    /// Единый стиль стартовых/статусных подсказок спикера (вместо разношёрстных заглушек).
    @ViewBuilder
    private func speakerStubHint(primary: String, secondary: String? = nil) -> some View {
        VStack(spacing: 6) {
            Text(primary)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let secondary, !secondary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(secondary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder private func conversationLoadingBlock(label: String) -> some View {
        TaikaLoadingView(label: label, compact: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    private static func attemptsLeftLabel(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1, mod100 != 11 { return "\(n) попытка на сегодня" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "\(n) попытки на сегодня" }
        return "\(n) попыток на сегодня"
    }

    private var recordingPartialRU: String {
        external?.recordingPartialRU ?? ""
    }

    /// In conversation mode, show result when we have Thai and/or phonetic from the conversation pipeline.
    private var conversationHasResult: Bool {
        guard speakerUIMode == .conversation else { return false }
        let hasThai = (external?.heardThai?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        let hasPhonetic = (external?.heardTranslit?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        return hasThai || hasPhonetic
    }

    private var conversationExpectedThai: String? { external?.conversationExpectedThai }

    public var body: some View {
        ZStack {
            T.Colors.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome

                Group {
                    if speakerUIMode == .conversation {
                        conversationLiveWidget
                    } else if allSpeakerItems.isEmpty {
                        trainingEmptyScreen
                    } else {
                        unifiedSpeakerBody
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .sheet(isPresented: Binding(
            get: { effectiveShowBreakdown },
            set: { newValue in
                if newValue {
                    setEffectiveShowBreakdown(true)
                } else {
                    dismissBreakdownSheet()
                }
            }
        )) {
            speakerBreakdownSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .animation(.easeInOut(duration: 0.18), value: phase.isFeedback)
        .onChange(of: extSelectedId) { newValue in
            if let v = newValue { localSelectedId = v }
        }
        .onChange(of: activeFilterId) { _ in
            localSelectedId = nil
        }
        .task(id: helperHasInteracted) {
#if DEBUG
            if external == nil {
                await MainActor.run {
                    helperIsVisible = true
                    helperTypedText = "выбери фразу и нажми микрофон"
                }
                return
            }
#endif
            guard !helperHasInteracted else { return }
            let full = "выбери фразу и нажми микрофон"
            let deadline = Date().addingTimeInterval(2.0)
            while phase != .idle, !Task.isCancelled, !helperHasInteracted, Date() < deadline {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            await MainActor.run {
                helperIsVisible = true
                helperTypedText = ""
            }
            for ch in full {
                if Task.isCancelled || helperHasInteracted || phase != .idle { break }
                await MainActor.run { helperTypedText.append(ch) }
                try? await Task.sleep(nanoseconds: 95_000_000)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// «Закрепление курсов» в покое: выбор курсов/уроков + typewriter-гайд с цифрами в сообщении.
    private var trainingEmptyScreen: some View {
        let options = external?.trainingCourseOptions ?? []
        let favCount = external?.trainingFavoritesCount ?? 0
        let dictCount = external?.trainingDictionaryCount ?? 0
        return Group {
            if options.isEmpty && favCount == 0 && dictCount == 0 {
                trainingNoContentYetScreen
            } else {
                trainingLauncherScreen(options: options)
            }
        }
    }

    /// Действительно пусто (ничего не выучено ни в одном курсе).
    private var trainingNoContentYetScreen: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            TaikaEmptyStateIcon(systemName: "mic")
            Text("Заговори, а не просто запоминай")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Text("Пройди пару шагов в уроке — фразы появятся здесь для тренировки голосом.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                external?.onOpenCourses?()
            } label: {
                Text("к урокам")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 48)
            .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .padding(.bottom, ToolBar.recommendedBottomInset + 8)
    }

    /// Выбранные курсы для сессии; по умолчанию выбраны все, у которых есть фразы.
    private func defaultTrainingSelection(_ options: [SpeakerTrainingCourseOption]) -> Set<String> {
        Set(options.map(\.id))
    }

    private func defaultLessonSelection(for courseId: String) -> Set<String> {
        Set(SpeakerManager.shared.learnedTrainingLessonOptions(courseId: courseId).map(\.id))
    }

    private func selectedLessonIds(for options: [SpeakerTrainingCourseOption], selectedCourses: Set<String>) -> Set<String> {
        var out = Set<String>()
        for cid in selectedCourses {
            out.formUnion(selectedTrainingLessonIdsByCourse[cid] ?? defaultLessonSelection(for: cid))
        }
        _ = options
        return out
    }

    private func trainingSelectedPhraseCount(
        options: [SpeakerTrainingCourseOption],
        selectedCourses: Set<String>
    ) -> Int {
        _ = options
        var total = 0
        for cid in selectedCourses {
            let lessons = SpeakerManager.shared.learnedTrainingLessonOptions(courseId: cid)
            let picked = selectedTrainingLessonIdsByCourse[cid] ?? defaultLessonSelection(for: cid)
            total += lessons.filter { picked.contains($0.id) }.reduce(0) { $0 + $1.count }
        }
        return total
    }

    private func trainingLauncherScreen(options: [SpeakerTrainingCourseOption]) -> some View {
        // Курсов в каталоге ~40 — список скроллится сам; CTA и гайд остаются на месте.
        let sortedOptions = options.sorted { $0.count > $1.count }
        let selected = selectedTrainingCourseIds ?? defaultTrainingSelection(options)
        let selectedTotal = trainingSelectedPhraseCount(options: options, selectedCourses: selected)
        let guideLines = trainingGuideLines()

        return VStack(spacing: 0) {
            MDCyclingTypewriter(
                lines: guideLines,
                font: .system(size: 19, weight: .bold),
                holdSeconds: 2.4,
                charInterval: 0.032,
                minHeight: 48,
                accentDigits: false
            )
            .padding(.top, 6)
            .padding(.bottom, 4)
            .accessibilityLabel("Подсказки по тренировке")

            trainingPoolsQuickStartRow()
                .padding(.top, 12)
                .padding(.bottom, 4)

            HStack {
                Text(options.isEmpty ? "Или выбери курсы позже" : "Выбери курсы и уроки")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                Spacer(minLength: 8)
                if !options.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if selected.count == options.count {
                        selectedTrainingCourseIds = []
                        selectedTrainingLessonIdsByCourse = [:]
                        expandedTrainingCourseId = nil
                    } else {
                        let all = defaultTrainingSelection(options)
                        selectedTrainingCourseIds = all
                        var lessons: [String: Set<String>] = [:]
                        for cid in all {
                            lessons[cid] = defaultLessonSelection(for: cid)
                        }
                        selectedTrainingLessonIdsByCourse = lessons
                    }
                } label: {
                    Text(selected.count == options.count ? "снять всё" : "выбрать все")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(
                            Capsule(style: .continuous)
                                .fill(CD.ColorToken.card.opacity(0.9))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    ThemeManager.shared.currentAccentFill.opacity(0.55),
                                    lineWidth: Theme.Strokes.strokeLineWidth
                                )
                        )
                }
                .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
                .accessibilityLabel(selected.count == options.count ? "Снять всё" : "Выбрать все")
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 8) {
                    if sortedOptions.isEmpty {
                        Text("Пока нет выученных фраз в курсах — можно тренировать избранное или словарь выше.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(sortedOptions) { option in
                            trainingCourseBlock(
                                option: option,
                                isSelected: selected.contains(option.id),
                                isExpanded: expandedTrainingCourseId == option.id
                            )
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .onAppear {
                // Сидим выбор уроков один раз при открытии списка.
                let courses = selectedTrainingCourseIds ?? defaultTrainingSelection(options)
                var map = selectedTrainingLessonIdsByCourse
                for cid in courses where map[cid] == nil {
                    map[cid] = defaultLessonSelection(for: cid)
                }
                selectedTrainingLessonIdsByCourse = map
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let lessons = selectedLessonIds(for: options, selectedCourses: selected)
                external?.onStartCourseTraining?(selected, lessons)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text(selectedTotal > 0
                         ? "Начать тренировку · \(selectedTotal)"
                         : "Начать тренировку")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                .shadow(color: ThemeManager.shared.currentAccentTintColor.opacity(0.32), radius: 14, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(selectedTotal == 0 || options.isEmpty)
            .opacity((selectedTotal == 0 || options.isEmpty) ? 0.5 : 1)
            .padding(.top, 14)
            .accessibilityLabel("Начать тренировку, \(selectedTotal) фраз")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, ToolBar.recommendedBottomInset + 8)
        .offset(y: speakerInviteAppeared ? 0 : 12)
        .opacity(speakerInviteAppeared ? 1 : 0.01)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: speakerInviteAppeared)
        .onAppear { triggerSpeakerInviteAppear() }
        .onChange(of: speakerUIMode) { _ in triggerSpeakerInviteAppear() }
    }

    /// Избранное / словарь: один ряд, контурные чипы (иконка · число · подпись).
    private func trainingPoolsQuickStartRow() -> some View {
        let favCount = external?.trainingFavoritesCount ?? 0
        let dictCount = external?.trainingDictionaryCount ?? 0
        return HStack(spacing: 10) {
            trainingPoolOutlineChip(
                systemImage: "heart.fill",
                count: favCount,
                label: "Избранное",
                enabled: favCount > 0
            ) {
                external?.onStartSpecialTraining?("__favorites__")
            }
            trainingPoolOutlineChip(
                systemImage: "bookmark.fill",
                count: dictCount,
                label: "Словарь",
                enabled: dictCount > 0
            ) {
                external?.onStartSpecialTraining?("__dictionary__")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trainingPoolOutlineChip(
        systemImage: String,
        count: Int,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let accent = ThemeManager.shared.currentAccentFill
        return Button {
            guard enabled else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Capsule(style: .continuous).fill(Color.clear))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        AnyShapeStyle(accent.opacity(enabled ? 0.95 : 0.35)),
                        lineWidth: 1.5
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel("\(label), \(count) \(lifehackCountUnitLabel(count, unit: "phrase"))")
        .accessibilityHint(enabled ? "Начать тренировку" : "Пока пусто")
    }

    /// Гайд без цифр — счётчик уезжает в CTA снизу / в чипы пулов.
    private func trainingGuideLines() -> [String] {
        [
            "Жми «Начать тренировку» — и говори",
            "Избранное и словарь — быстрый повтор",
            "Выбери курсы и уроки ниже",
            "Раскрой курс — отметь нужные уроки"
        ]
    }

    private func courseCountUnitLabel(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1, mod100 != 11 { return "курс" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "курса" }
        return "курсов"
    }

    private func lessonCountUnitLabel(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1, mod100 != 11 { return "урок" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "урока" }
        return "уроков"
    }

    private func trainingCourseBlock(
        option: SpeakerTrainingCourseOption,
        isSelected: Bool,
        isExpanded: Bool
    ) -> some View {
        let lessons = SpeakerManager.shared.learnedTrainingLessonOptions(courseId: option.id)
        let pickedLessons = selectedTrainingLessonIdsByCourse[option.id] ?? defaultLessonSelection(for: option.id)

        return VStack(alignment: .leading, spacing: 0) {
            trainingCourseRow(
                option: option,
                isSelected: isSelected,
                isExpanded: isExpanded,
                onToggleCourse: { toggleTrainingCourseSelection(option.id, options: external?.trainingCourseOptions ?? [option]) },
                onToggleExpand: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        if expandedTrainingCourseId == option.id {
                            expandedTrainingCourseId = nil
                        } else {
                            expandedTrainingCourseId = option.id
                            if selectedTrainingLessonIdsByCourse[option.id] == nil {
                                selectedTrainingLessonIdsByCourse[option.id] = defaultLessonSelection(for: option.id)
                            }
                            // Раскрытие курса — сразу отмечаем курс выбранным.
                            var courses = selectedTrainingCourseIds ?? defaultTrainingSelection(external?.trainingCourseOptions ?? [option])
                            courses.insert(option.id)
                            selectedTrainingCourseIds = courses
                        }
                    }
                }
            )

            if isExpanded, !lessons.isEmpty {
                VStack(spacing: 6) {
                    ForEach(lessons) { lesson in
                        trainingLessonRow(
                            lesson: lesson,
                            isSelected: pickedLessons.contains(lesson.id),
                            onToggle: { toggleTrainingLessonSelection(courseId: option.id, lessonId: lesson.id) }
                        )
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 6)
                .padding(.bottom, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func toggleTrainingCourseSelection(_ courseId: String, options: [SpeakerTrainingCourseOption]) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var updated = selectedTrainingCourseIds ?? defaultTrainingSelection(options)
        if updated.contains(courseId) {
            updated.remove(courseId)
            selectedTrainingLessonIdsByCourse[courseId] = []
            if expandedTrainingCourseId == courseId {
                expandedTrainingCourseId = nil
            }
        } else {
            updated.insert(courseId)
            selectedTrainingLessonIdsByCourse[courseId] = defaultLessonSelection(for: courseId)
        }
        selectedTrainingCourseIds = updated
    }

    private func toggleTrainingLessonSelection(courseId: String, lessonId: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var picked = selectedTrainingLessonIdsByCourse[courseId] ?? defaultLessonSelection(for: courseId)
        if picked.contains(lessonId) {
            picked.remove(lessonId)
        } else {
            picked.insert(lessonId)
        }
        selectedTrainingLessonIdsByCourse[courseId] = picked

        var courses = selectedTrainingCourseIds ?? defaultTrainingSelection(external?.trainingCourseOptions ?? [])
        if picked.isEmpty {
            courses.remove(courseId)
        } else {
            courses.insert(courseId)
        }
        selectedTrainingCourseIds = courses
    }

    private func trainingCourseRow(
        option: SpeakerTrainingCourseOption,
        isSelected: Bool,
        isExpanded: Bool,
        onToggleCourse: @escaping () -> Void,
        onToggleExpand: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Button(action: onToggleCourse) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.4)))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "Снять курс" : "Выбрать курс")

            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    Text(option.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    Text("\(option.count) \(lifehackCountUnitLabel(option.count, unit: "phrase"))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Свернуть уроки" : "Открыть уроки")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(PD.ColorToken.chip.opacity(isSelected ? 0.55 : 0.4))
        )
    }

    private func trainingLessonRow(
        lesson: SpeakerTrainingLessonOption,
        isSelected: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(ThemeManager.shared.currentAccentFill) : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.4)))
                Text(lesson.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text("\(lesson.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(ThemeManager.shared.currentAccentFill.opacity(0.08)) : AnyShapeStyle(PD.ColorToken.chip.opacity(0.28)))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lesson.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func minutesUnitLabel(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1, mod100 != 11 { return "минуту" }
        if (2...4).contains(mod10), !(12...14).contains(mod100) { return "минуты" }
        return "минут"
    }

    /// Общий счётчик "N фраз"/"N лайфхаков" с корректным русским склонением по типу unit.
    private func lifehackCountUnitLabel(_ n: Int, unit: String) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        switch unit {
        case "phrase":
            if mod10 == 1, mod100 != 11 { return "фраза" }
            if (2...4).contains(mod10), !(12...14).contains(mod100) { return "фразы" }
            return "фраз"
        default:
            return unit
        }
    }

    private func speakerTeaserIdleStage<Footer: View>(
        slides: [TaikaValueSlide],
        index: Binding<Int>,
        showsMic: Bool,
        micEnabled: Bool,
        micAccessibility: String,
        micCaption: String? = nil,
        onMic: @escaping () -> Void,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            speakerTeaserCoverflow(slides: slides, index: index)
                .padding(.bottom, showsMic ? 14 : 0)

            if showsMic {
                speakerIdleMicButton(
                    enabled: micEnabled,
                    accessibilityLabel: micAccessibility,
                    action: onMic
                )
                .scaleEffect(idleMicPulse ? 1.03 : 1.0)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: idleMicPulse
                )
                .onAppear { idleMicPulse = true }

                if let micCaption, !micCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(micCaption)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .padding(.horizontal, 32)
                }
            }

            footer()
            Spacer(minLength: 0)
        }
        .padding(.bottom, ToolBar.recommendedBottomInset + 8)
        .offset(y: speakerInviteAppeared ? 0 : 12)
        .opacity(speakerInviteAppeared ? 1 : 0.01)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: speakerInviteAppeared)
        .onAppear { triggerSpeakerInviteAppear() }
        .onChange(of: speakerUIMode) { _ in
            triggerSpeakerInviteAppear()
            trainingTeaserIndex = 0
            conversationTeaserIndex = 0
        }
    }

    /// Coverflow 1-в-1 с разминкой / topCarousel Спикера.
    @ViewBuilder
    private func speakerTeaserCoverflow(
        slides: [TaikaValueSlide],
        index: Binding<Int>
    ) -> some View {
        let itemW = speakerCardWidth
        let itemH = speakerCardHeight
        let currentIndex = min(max(0, index.wrappedValue), max(0, slides.count - 1))
        let chip = speakerModeChipTitle

        ZStack {
            ForEach(Array(slides.enumerated()), id: \.element.id) { i, slide in
                let rel = i - currentIndex
                SpeakerTeaserCard(
                    icon: slide.icon,
                    title: slide.title,
                    subtitle: slide.subtitle,
                    chipTitle: slide.badge ?? chip,
                    ctaTitle: slide.ctaTitle ?? "далее",
                    size: CGSize(width: itemW, height: itemH),
                    onCTA: { handleSpeakerTeaserCTA(slide) }
                )
                .frame(width: itemW, height: itemH)
                .scaleEffect(rel == 0 ? 1.0 : 0.82)
                .rotation3DEffect(
                    .degrees(Double(rel) * -18),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.7
                )
                .opacity(abs(rel) > 2 ? 0 : (rel == 0 ? 1.0 : 0.45))
                .offset(x: CGFloat(rel) * (itemW * 0.92))
                .zIndex(rel == 0 ? 10 : Double(10 - abs(rel)))
                .allowsHitTesting(abs(rel) <= 1)
                .onTapGesture {
                    guard i != currentIndex else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        index.wrappedValue = i
                    }
                }
            }
        }
        .frame(height: itemH + 28)
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > 48, abs(dx) > abs(dy) * 1.15 else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        if dx < 0 {
                            index.wrappedValue = min(currentIndex + 1, slides.count - 1)
                        } else {
                            index.wrappedValue = max(currentIndex - 1, 0)
                        }
                    }
                }
        )
        .animation(.easeInOut(duration: 0.35), value: currentIndex)
    }

    private func handleSpeakerTeaserCTA(_ slide: TaikaValueSlide) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch slide.id {
        case "speaker_train_1":
            external?.onOpenCourses?()
        case "speaker_train_2":
            external?.onSelectFilter(SpeakerMode.favorites.id)
        case "speaker_train_3":
            external?.onSpeakerUIModeChange(.conversation)
        case "speaker_conv_1":
            external?.onConversationDemoPhrase?("Привет")
        case "speaker_conv_2":
            OverlayPresenter.shared.present(.speakerPaywall)
        default:
            break
        }
    }

    /// Одна сторона одной карточки: вертикальный квадрат как лайфхак. Режим меняет только текст/чип.
    @ViewBuilder
    private func speakerModeFaceCard(
        title: String,
        subtitle: String,
        primaryCTA: (title: String, action: () -> Void)?,
        secondaryCTA: (title: String, action: () -> Void)?
    ) -> some View {
        speakerFaceCardChrome {
            Spacer(minLength: 8)
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .lineLimit(5)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)

            Spacer(minLength: 8)
            speakerFaceCTAStack(primaryCTA: primaryCTA, secondaryCTA: secondaryCTA)
        }
    }

    private func speakerFaceCardChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("taikA")
                    .font(.custom("ONMARK Trial", size: 14))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.text)
                Spacer(minLength: 0)
                Text(speakerModeChipTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(ThemeManager.shared.currentAccentFill, lineWidth: 1.2)
                    )
            }
            content()
        }
        .padding(18)
        .frame(width: speakerCardWidth, height: speakerCardHeight, alignment: .top)
        .background(Theme.Surfaces.card(shape))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func speakerFaceCTAStack(
        primaryCTA: (title: String, action: () -> Void)?,
        secondaryCTA: (title: String, action: () -> Void)?
    ) -> some View {
        if primaryCTA != nil || secondaryCTA != nil {
            VStack(spacing: 8) {
                if let primaryCTA {
                    Button(action: primaryCTA.action) {
                        Text(primaryCTA.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.9))
                            .padding(.horizontal, 18)
                            .frame(height: 34)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ThemeManager.shared.currentAccentFill)
                            )
                    }
                    .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
                }
                if let secondaryCTA {
                    Button(action: secondaryCTA.action) {
                        Text(secondaryCTA.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(CD.ColorToken.card.opacity(0.78))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                                    )
                            )
                    }
                    .buttonStyle(PressDownStyle(scale: 0.96, fade: 0.97))
                }
            }
            .padding(.bottom, 2)
        }
    }

    /// Один и тот же mic в blank conversation.
    private func speakerIdleMicButton(
        enabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .bold))
                .frame(width: 72, height: 72)
                .background(Circle().fill(ThemeManager.shared.currentAccentFill))
                .foregroundColor(.black)
                .shadow(color: ThemeManager.shared.currentAccentTintColor.opacity(0.35), radius: 14, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .accessibilityLabel(accessibilityLabel)
    }

    private func triggerSpeakerInviteAppear() {
        speakerInviteAppeared = false
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                speakerInviteAppeared = true
            }
        }
    }

    /// Legacy blank (карусель empty) — тот же face, без декоративных иконок.
    @ViewBuilder
    private func speakerBlankBrainInvite(
        title: String,
        subtitle: String,
        primaryCTA: (title: String, action: () -> Void)?,
        secondaryCTA: (title: String, action: () -> Void)?
    ) -> some View {
        speakerModeFaceCard(
            title: title,
            subtitle: subtitle,
            primaryCTA: primaryCTA,
            secondaryCTA: secondaryCTA
        )
    }

    private var emptyPrimaryCTA: (title: String, action: () -> Void)? {
        switch activeMode {
        case .current:
            return ("Выбрать курс", { external?.onOpenCourses?() })
        default:
            return nil
        }
    }

    private var emptySecondaryCTA: (title: String, action: () -> Void)? {
        switch activeMode {
        case .favorites, .learned:
            return ("К последнему уроку", { external?.onSelectFilter(SpeakerMode.currentMode.id) })
        default:
            return nil
        }
    }

    /// Единый блок результата: сравнение + общий скор + короткий вердикт.
    @ViewBuilder private func unifiedFeedbackBlock(
        score: Int,
        expected: String,
        userText: String,
        originalRussian: String?,
        secondaryLabel: String?,
        onSecondary: (() -> Void)?,
        onBreakdown: @escaping () -> Void
    ) -> some View {
        let expectedDisplay = expected.isEmpty ? "—" : expected
        let userDisplay = userText.isEmpty ? "—" : userText
        let verdict: String = {
            if score >= 80 { return "уже звучит живо" }
            if score >= 55 { return "хороший старт — есть куда смотреть" }
            return "нормально — разберём по слогам"
        }()
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("нужно было")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.78))
                        highlightedExpectedText(userText: userDisplay, expected: expectedDisplay)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ты сказал")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.78))
                        highlightedUserText(userText: userDisplay, expected: expectedDisplay)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(score)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill)
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(ThemeManager.shared.currentAccentFill.opacity(0.85))
                    }
                    .accessibilityLabel("\(score) процентов")

                    TaikaTechWaveform(meter: max(0.28, Double(score) / 100.0), pace: .idle, lineCount: 2)
                        .frame(width: 96, height: 22)
                        .opacity(0.9)

                    Text(verdict)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                .frame(width: 118)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 14) {
                Button(action: onBreakdown) {
                    Text("что улучшить")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                        .foregroundColor(.black)
                        .shadow(
                            color: ThemeManager.shared.currentAccentTintColor.opacity(0.28),
                            radius: 12,
                            y: 4
                        )
                }
                .buttonStyle(.plain)
                if let label = secondaryLabel, let action = onSecondary {
                    Button(action: action) {
                        Text(label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var simpleResultBlock: some View {
        if case .feedback(let score, _) = phase {
            let scoreToShow = external?.displayScore ?? score
            let expected = (currentItem?.translit ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            unifiedFeedbackBlock(
                score: scoreToShow,
                expected: expected,
                userText: heardTranslitText,
                originalRussian: nil,
                secondaryLabel: external?.onClearAttempt != nil ? "Сбросить записи в блоке" : nil,
                onSecondary: external?.onClearAttempt,
                onBreakdown: { external?.onRequestBreakdown?() }
            )
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var hasFullToneBreakdownAccess: Bool {
        external?.hasFullToneBreakdownAccess ?? external?.isProUser ?? false
    }

    /// Training mode: recording UI lives in the bottom section (card stays static).
    @ViewBuilder private var trainingRecordingBlock: some View {
        let accent = ThemeManager.shared.currentAccentFill
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 7, height: 7)
                    .opacity(idleMicPulse ? 1 : 0.45)
                Text("идёт запись")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(accent)
            }
            .animation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: idleMicPulse
            )
            .onAppear { idleMicPulse = true }

            TaikaTechWaveform(meter: max(0.28, recordingMeter), pace: .recording, lineCount: 3)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .padding(.horizontal, 8)
                .transition(.opacity)

            Text("нажми микрофон, чтобы остановить")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    /// Training mode: analyzing continues the same wave — soft, not a hard cut to a spinner.
    @ViewBuilder private var trainingAnalyzingBlock: some View {
        VStack(spacing: 12) {
            Text("собираю разбор…")
                .font(.footnote.weight(.bold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)

            TaikaTechWaveform(meter: 0.42, pace: .analyzing, lineCount: 3)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .padding(.horizontal, 8)

            Text("волна затихает — сейчас покажу, куда смотреть")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    @ViewBuilder
    private func highlightedUserText(userText: String, expected: String) -> some View {
        if userText == Self.conversationPhoneticLoadingToken {
            Text("Загружаем кириллическую фонетику…")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else if !isBreakdownExpanded, Self.containsThaiScript(userText) {
            Text(userText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else if !isBreakdownExpanded {
            PhoneticWithColoredArrowsView(phonetic: userText, font: .system(size: 22, weight: .semibold), alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            highlightedUserExpanded(userText: userText, expected: expected)
        }
    }

    /// Развёрнутое сравнение по дефисам (тренажёр).
    private func highlightedUserExpanded(userText: String, expected: String) -> some View {
        let userParts = userText.split(separator: "-").map(String.init)
        let expectedParts = expected.split(separator: "-").map(String.init)
        var composed = Text("")
        for idx in userParts.indices {
            let part = userParts[idx]
            let isWrong = idx >= expectedParts.count ||
                part.lowercased() != expectedParts[idx].lowercased()
            let styled = Text(part)
                .foregroundStyle(
                    isWrong
                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                    : AnyShapeStyle(PD.ColorToken.text)
                )
            composed = composed + styled
            if idx < userParts.count - 1 {
                composed = composed + Text("-").foregroundStyle(PD.ColorToken.text)
            }
        }
        return composed
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static func containsThaiScript(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0E00...0x0E7F).contains($0.value) }
    }

    @ViewBuilder
    private static func breakdownUserSaidLine(userText: String) -> some View {
        if userText == conversationPhoneticLoadingToken {
            Text("Загружаем кириллическую фонетику…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
        } else if userText == "—" {
            Text("—")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
        } else if containsThaiScript(userText) {
            Text(userText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PD.ColorToken.text)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
        } else {
            PhoneticWithColoredArrowsView(phonetic: userText, font: .subheadline.weight(.medium), alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
        }
    }

    private func highlightedExpectedText(userText: String, expected: String) -> some View {
        // "нужно было" — эталон со стрелками тонов. Цвет как в спикере/степе.
        Group {
            if expected.isEmpty {
                Text("—")
                    .foregroundStyle(PD.ColorToken.textSecondary)
            } else {
                PhoneticWithColoredArrowsView(phonetic: expected, font: .system(size: 22, weight: .semibold), alignment: .leading)
            }
        }
        .multilineTextAlignment(.leading)
        .lineLimit(3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }


    // MARK: - breakdown (mvp placeholder, replaced by azure assessment later)

    private struct BreakdownRow: Identifiable {
        let id = UUID()
        let expected: String
        let user: String
        let isWrong: Bool
        let score: Int
        let note: String?
    }

    /// Строка разбора по слогу (слог, оценка, фидбек, тоны, контур для графика).
    private struct SyllableRow {
        let label: String
        let score: Int
        let comment: String
        let toneExpected: String?
        let toneActual: String?
        let f0Contour: [Double]?
        /// API вернул меньше слогов, чем в эталонной фонетике — нейтральная карточка-плейсхолдер.
        let isPlaceholder: Bool
    }

    /// Одна карточка слога в разборе (цвет по score, стрелки тонов, мини-график).
    private struct BreakdownSyllableRowView: View {
        let row: SyllableRow
        var body: some View {
            SpeakerDSRoot.breakdownSyllableRowContent(row: row)
        }
    }

    private static func breakdownSyllableRowContent(row: SyllableRow) -> some View {
        if row.isPlaceholder {
            let expectedArrow = toneToArrow(row.toneExpected)
            return AnyView(
                HStack(alignment: .top, spacing: 10) {
                    Text(row.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .frame(width: 44, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("нужно: \(expectedArrow)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PD.ColorToken.toneExpected)
                        Text("ты: —")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    .frame(width: 56, alignment: .leading)
                    Text("—")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(width: 28, alignment: .trailing)
                    Text(row.comment)
                        .font(.caption2)
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 6)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .padding(.trailing, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PD.ColorToken.chip)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(PD.ColorToken.chip.opacity(0.85), lineWidth: 1)
                        )
                )
            )
        }
        let isGreen = row.score >= 90
        let isYellow = row.score >= 50 && row.score < 90
        let rowColor: Color = isGreen ? Color.green.opacity(0.35) : (isYellow ? Color.orange.opacity(0.35) : Color.red.opacity(0.35))
        let strokeColor: Color = isGreen ? Color.green.opacity(0.5) : (isYellow ? Color.orange.opacity(0.5) : Color.red.opacity(0.5))
        let toneMatch = (row.toneExpected.map { $0 == row.toneActual } ?? true)
        let expectedArrow = toneToArrow(row.toneExpected)
        let actualArrow = toneToArrow(row.toneActual)
        return AnyView(HStack(alignment: .top, spacing: 10) {
            Text(row.label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PD.ColorToken.text)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("нужно: \(expectedArrow)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PD.ColorToken.toneExpected)
                Text("ты: \(actualArrow)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(toneMatch ? PD.ColorToken.toneCorrect : PD.ColorToken.toneWrong)
            }
            .frame(width: 56, alignment: .leading)
            Text("\(row.score)%")
                .font(.caption.weight(.medium))
                .foregroundStyle(isGreen ? PD.ColorToken.toneCorrect : (isYellow ? Color.orange : PD.ColorToken.toneWrong))
                .frame(width: 28, alignment: .trailing)
            Text(row.comment)
                .font(.caption2)
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 6)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .padding(.trailing, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rowColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
        ))
    }

    /// Иконка тона для UI: одна из пяти стрелок. Mid = → (ровный), без данных = прочерк.
    private static func toneToArrow(_ tone: String?) -> String {
        guard let t = tone?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return "—" }
        switch t {
        case "Mid": return "→"
        case "Low": return "↓"
        case "Falling": return "↘"
        case "High": return "↑"
        case "Rising": return "↗"
        default: return "—"
        }
    }

    /// Подсказки тонового API приходят на английском; переводим в русский для UI.
    /// «Идеальный тон!» только когда тон совпал с эталоном (toneMatch == true). Иначе показываем фидбек API.
    private static func localizedToneFeedback(_ en: String?, score: Int, toneMatch: Bool? = nil) -> String {
        let isCorrectTone = toneMatch ?? true
        if score >= 90 && isCorrectTone { return "Идеальный тон!" }
        guard let s = en?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            if score < 50 { return "Совсем другой тон. Послушай эталон ещё раз." }
            return ""
        }
        let map: [String: String] = [
            "Perfect": "Отлично",
            "Perfect tone!": "Идеальный тон!",
            "Good tone": "Тон верный",
            "Good tone.": "Тон верный.",
            "Right tone; try clearer pitch.": "Тон верный; произнеси чётче.",
            "Your pitch didn't fall enough. Try a sharp drop.": "Голос не опустился. Нужен резкий спад в конце.",
            "Your pitch didn't rise enough. Try a clear rise.": "Голос не поднялся. Нужен явный подъём.",
            "Keep pitch flat and mid.": "Держи тон ровно, средний.",
            "Keep pitch high and flat.": "Держи тон высоко и ровно.",
            "Keep pitch low and flat.": "Держи тон низко и ровно.",
            "Not enough pitch data to assess. Speak clearly, closer to the mic.": "По записи не удалось оценить тон. Говори чётче и ближе к микрофону.",
        ]
        if let ru = map[s] {
            if score < 50 && (ru.contains("верный") || ru.contains("Идеальный") || ru.contains("Отлично")) {
                return "Совсем другой тон. Послушай эталон ещё раз."
            }
            return ru
        }
        if s.hasPrefix("You used ") && s.contains(" instead of ") {
            var ru = s
                .replacingOccurrences(of: "You used ", with: "Ты сказал ")
                .replacingOccurrences(of: " instead of ", with: ", нужно было ")
                .replacingOccurrences(of: "Mid", with: "средний")
                .replacingOccurrences(of: "Low", with: "низкий")
                .replacingOccurrences(of: "Falling", with: "нисходящий")
                .replacingOccurrences(of: "High", with: "высокий")
                .replacingOccurrences(of: "Rising", with: "восходящий")
            let hintMap: [String: String] = [
                "Your pitch stayed flat; it should fall at the end.": "Голос шёл ровно — нужен спад в конце.",
                "Your pitch went up; it should fall.": "Голос пошёл вверх — нужен спад.",
                "Your pitch stayed flat; it should rise at the end.": "Голос шёл ровно — нужен подъём в конце.",
                "Your pitch fell; it should rise.": "Голос опустился — нужен подъём.",
                "Your pitch fell; keep it flat and mid.": "Голос опустился — держи ровно, средний тон.",
                "Your pitch rose; keep it flat and mid.": "Голос поднялся — держи ровно, средний тон.",
                "Your pitch was too high; keep it mid.": "Голос слишком высокий — держи средний тон.",
                "Your pitch was too low; keep it mid.": "Голос слишком низкий — держи средний тон.",
            ]
            for (en, hintRu) in hintMap {
                ru = ru.replacingOccurrences(of: en, with: hintRu)
            }
            return ru
        }
        if s.hasPrefix("Expected ") { return "Ожидался другой тон." }
        if score < 50 { return "Совсем другой тон. Послушай эталон ещё раз." }
        return s
    }

    /// Цвет оценки: каноничный brand accent (не muted/system).
    private static func scoreBandColor(_ score: Int) -> Color {
        ThemeManager.shared.currentAccentTintColor
    }

    /// Мини-график высоты тона по слогу (Loora-style «вау»).
    private static func breakdownContourSparkline(values: [Double]) -> some View {
        let v = values
        let minV = v.min() ?? 0
        let maxV = v.max() ?? 0
        let range = maxV - minV
        let scale = range > 0 ? range : 1.0
        let pts = v.enumerated().map { i, y in
            CGPoint(
                x: CGFloat(i) / CGFloat(max(1, v.count - 1)),
                y: 1.0 - CGFloat((y - minV) / scale)
            )
        }
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                guard let f = pts.first else { return }
                path.move(to: CGPoint(x: f.x * w, y: f.y * h))
                for p in pts.dropFirst() {
                    path.addLine(to: CGPoint(x: p.x * w, y: p.y * h))
                }
            }
            .stroke(ThemeManager.shared.currentAccentFill, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }

    /// Слоги из эталона (translit): разбиение по "-", пробелу, "·". Для заглушки разбора по слогам.
    private static func syllablesFromTranslit(_ translit: String) -> [String] {
        let raw = translit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw != "—" else { return [] }
        return raw.split(omittingEmptySubsequences: true) { "- ·".contains($0) }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Убираем стрелки тона и прочерки из подписи слога, чтобы показывать только «ват», «ди», «на».
    private static func syllableLabelWithoutArrows(_ label: String) -> String {
        let arrows = CharacterSet(charactersIn: "↘↗→−↓↑↔—")
        return label.unicodeScalars.filter { !arrows.contains($0) }.map { String($0) }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Одна строка-заключение по разбору тонов (стиль Taika FM). Учитываем, что 100% по тону редко — хвалим уже с 85+.
    private static func breakdownSummaryNote(syllableFeedback: [SpeakerManager.SyllableFeedback]) -> String {
        guard !syllableFeedback.isEmpty else { return "" }
        let avg = syllableFeedback.map(\.score).reduce(0, +) / syllableFeedback.count
        if avg >= 90 { return "Тон отличный, так держать." }
        if avg >= 75 { return "Тон в целом верный — можно чуть чётче по слогам выше." }
        if avg >= 50 { return "Есть ошибки по тону — смотри подсказки по слогам выше." }
        return "Поработай над тоном — смотри оценку по слогам выше."
    }

    /// Онбординг-стиль: без «оценки по слогам» / процентов в тексте.
    private static func breakdownSummaryNoteHuman(syllableFeedback: [SpeakerManager.SyllableFeedback]) -> String {
        guard !syllableFeedback.isEmpty else { return "" }
        let avg = syllableFeedback.map(\.score).reduce(0, +) / syllableFeedback.count
        if avg >= 90 { return "Тон отличный — так и держи." }
        if avg >= 75 { return "Тон в целом верный — чуть чётче там, где подсвечено." }
        if avg >= 50 { return "Есть слоги, где тон «поплыл» — повтори их отдельно." }
        return "Сейчас главное — тоны. Послушай эталон и пройди по слогам ещё раз."
    }

    /// Слоговый разбор как в онбординге: статус словами, без % и плотных «нужно/ты» колонок.
    @ViewBuilder
    private func breakdownSyllableRowsHumanSection(
        expected: String,
        syllableFeedback: [SpeakerManager.SyllableFeedback]
    ) -> some View {
        let chunks = Self.translitChunksForSyllables(expected)
        let accent = ThemeManager.shared.currentAccentTintColor
        VStack(alignment: .leading, spacing: 10) {
            Text("По слогам")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(PD.ColorToken.textSecondary)

            VStack(spacing: 10) {
                if chunks.isEmpty {
                    ForEach(Array(syllableFeedback.enumerated()), id: \.offset) { _, item in
                        breakdownHumanSyllableRow(
                            label: Self.syllableLabelWithoutArrows(item.syllable),
                            score: item.score,
                            toneExpected: item.toneExpected,
                            toneActual: item.toneActual,
                            accent: accent
                        )
                    }
                } else {
                    ForEach(Array(chunks.enumerated()), id: \.offset) { index, rawChunk in
                        let label = Self.syllableLabelWithoutArrows(rawChunk)
                        let item = index < syllableFeedback.count ? syllableFeedback[index] : nil
                        breakdownHumanSyllableRow(
                            label: label,
                            score: item?.score,
                            toneExpected: item?.toneExpected ?? Self.toneNameFromTranslitChunk(rawChunk),
                            toneActual: item?.toneActual,
                            accent: accent,
                            isPlaceholder: item == nil
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func breakdownHumanSyllableRow(
        label: String,
        score: Int?,
        toneExpected: String?,
        toneActual: String?,
        accent: Color,
        isPlaceholder: Bool = false
    ) -> some View {
        let status: (label: String, color: Color) = {
            guard let score, !isPlaceholder else {
                return ("Жду оценку слога", PD.ColorToken.textSecondary)
            }
            if score >= 80 { return ("Держи так", Color.green.opacity(0.85)) }
            if score >= 55 { return ("Почти — ещё раз", accent) }
            return ("Вот сюда внимание", Color.orange.opacity(0.9))
        }()
        let tip: String? = {
            guard !isPlaceholder else { return nil }
            let exp = Self.toneNameRU(toneExpected)
            let act = Self.toneNameRU(toneActual)
            guard !exp.isEmpty else { return nil }
            if act.isEmpty { return "Нужен \(exp)" }
            if exp == act { return "Тон \(exp) — верно" }
            return "Нужен \(exp), сейчас \(act)"
        }()
        let scoreValue = (!isPlaceholder ? score : nil)
        let progress = CGFloat(max(0, min(100, scoreValue ?? 0))) / 100.0

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Circle()
                    .fill(status.color.opacity(0.9))
                    .frame(width: 10, height: 10)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 3) {
                    Text(label.isEmpty ? "слог" : label)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                    Text(status.label)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }

                Spacer(minLength: 8)

                if let scoreValue {
                    // SF system digits — not Taika display/stat font.
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(scoreValue)")
                            .font(.system(size: 22, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(PD.ColorToken.text)
                        Text("%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    .accessibilityLabel("\(scoreValue) процентов")
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    Capsule(style: .continuous)
                        .fill(
                            scoreValue == nil
                            ? AnyShapeStyle(Color.white.opacity(0.12))
                            : AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        )
                        .frame(width: max(4, geo.size.width * progress))
                        .opacity(scoreValue == nil ? 0.35 : 0.95)
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)

            if let tip {
                Text(tip)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PD.ColorToken.chip)
        )
    }

    private static func toneNameRU(_ raw: String?) -> String {
        switch (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "mid", "middle", "m": return "средний"
        case "low", "l": return "низкий"
        case "falling", "fall", "f": return "падающий"
        case "high", "h": return "высокий"
        case "rising", "rise", "r": return "восходящий"
        case "": return ""
        default: return (raw ?? "").lowercased()
        }
    }

    private func breakdownItems(userText: String, expected: String) -> [BreakdownRow] {
        // split by '-' because that's our canonical translit format in Taika
        let u = userText.split(separator: "-").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        let e = expected.split(separator: "-").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        let n = max(u.count, e.count)
        guard n > 0 else {
            return [BreakdownRow(expected: expected.isEmpty ? "—" : expected,
                                 user: userText.isEmpty ? "—" : userText,
                                 isWrong: true,
                                 score: 0,
                                 note: "нет данных")]
        }

        var out: [BreakdownRow] = []
        out.reserveCapacity(n)

        for i in 0..<n {
            let exp = i < e.count ? e[i] : "—"
            let usr = i < u.count ? u[i] : "—"

            let wrong = exp.lowercased() != usr.lowercased()
            // MVP score heuristic: match=100, mismatch=55
            let s = wrong ? 55 : 100
            let note: String? = {
                guard wrong else { return "ок" }
                // placeholder copy until phoneme/tones assessment is wired
                return "проверь тон/ударение в этом слоге"
            }()

            out.append(BreakdownRow(expected: exp, user: usr, isWrong: wrong, score: s, note: note))
        }

        return out
    }

    /// Bottom sheet «разбор» — как в онбординге: выезжает снизу, без отдельного полноэкранного окна.
    @ViewBuilder private var speakerBreakdownSheet: some View {
        // Умный спикер «повторить и проверить»: не подставляем транслит с карточки тренажёра.
        let userText: String = {
            let convPh = external?.conversationHeardPhoneticFromASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !convPh.isEmpty { return convPh }
            let asr = external?.conversationHeardThaiASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Пока нет кириллицы — показываем тайский ASR сразу (не вечный «Загружаем…»).
            if !asr.isEmpty { return asr }
            let t = heardTranslitText.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "—" : t
        }()
        let (liveTranslit, livePhrase): (String, String) = {
            if let convTranslit = external?.conversationExpectedTranslitForFeedback?.trimmingCharacters(in: .whitespacesAndNewlines), !convTranslit.isEmpty {
                let convPhrase = (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return (convTranslit, convPhrase)
            }
            return (
                (currentItem?.translit ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                (currentItem?.hint ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }()
        let liveScore: Int? = {
            guard case .feedback(let score, _) = phase else { return nil }
            return score
        }()
        let expected = breakdownSnapshotExpected.isEmpty ? liveTranslit : breakdownSnapshotExpected
        let expectedDisplay = expected.isEmpty ? "—" : expected
        let phraseLabel = breakdownSnapshotPhraseLabel.isEmpty ? livePhrase : breakdownSnapshotPhraseLabel
        let scoreForBreakdown = breakdownSnapshotScore ?? liveScore
        let showRecordingUnavailable = phase.isFeedback && (external?.lastAttempt == nil) && (external?.attemptCount ?? 0) > 0

        let breakdownPhaseValue = external?.phase ?? .idle
        let isRecordingFromBreakdownValue = external?.isRecordingFromBreakdown ?? false
        let recordingMeterValue = external?.recordingMeter ?? 0
        let referenceRevealValue = external?.referencePlaybackProgress ?? 1.0
        let onRecordAgainValue: (() -> Void)? = external?.onRecordAgainFromBreakdown ?? (showRecordingUnavailable ? nil : {
            dismissBreakdownSheet()
        })

        let displayScoreValue = external?.displayScore ?? scoreForBreakdown ?? 0
        let textScoreValue = external?.heardConfidence ?? scoreForBreakdown ?? 0
        let toneScoreValue = external?.toneAverageScore

        speakerBreakdownOverlayCard(
            userText: userText,
            expected: expectedDisplay,
            phraseLabel: phraseLabel,
            displayScore: displayScoreValue,
            textScore: textScoreValue,
            toneScore: toneScoreValue,
            syllableFeedback: syllableFeedback,
            breakdownRequestInFlight: external?.breakdownRequestInFlight ?? false,
            breakdownRequestFailed: external?.breakdownRequestFailed ?? false,
            breakdownHybridScore: breakdownHybridScore,
            taikaHints: taikaHints,
            showRecordingUnavailable: showRecordingUnavailable,
            breakdownPhase: breakdownPhaseValue,
            isRecordingFromBreakdown: isRecordingFromBreakdownValue,
            recordingMeter: recordingMeterValue,
            referenceRevealProgress: referenceRevealValue,
            isProUser: external?.isProUser ?? false,
            hasFullToneAccess: hasFullToneBreakdownAccess,
            onDismiss: { dismissBreakdownSheet() },
            onRecordAgain: onRecordAgainValue,
            onStopRecordingFromBreakdown: external?.onStopRecordingFromBreakdown,
            onPlayReference: external?.onPlayReference,
            onPlayAttempt: external?.onPlayAttempt,
            presentsAsSheet: true
        )
        .background(PD.ColorToken.background.ignoresSafeArea())
        .onAppear {
            external?.onBreakdownAppear?()
            if breakdownSnapshotExpected.isEmpty && !liveTranslit.isEmpty {
                breakdownSnapshotExpected = liveTranslit
                breakdownSnapshotPhraseLabel = livePhrase
                breakdownSnapshotScore = liveScore
            }
        }
    }

    /// Оверлей «разбор» (legacy path — kept for previews if needed).
    @ViewBuilder private func speakerBreakdownOverlayZStack(
        onDismiss: @escaping () -> Void,
        snapshotExpected: Binding<String>,
        snapshotPhraseLabel: Binding<String>,
        snapshotScore: Binding<Int?>
    ) -> some View {
        // Умный спикер «повторить и проверить»: не подставляем транслит с карточки тренажёра.
        let userText: String = {
            let convPh = external?.conversationHeardPhoneticFromASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !convPh.isEmpty { return convPh }
            let asr = external?.conversationHeardThaiASR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !asr.isEmpty { return asr }
            let t = heardTranslitText.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "—" : t
        }()
        let (liveTranslit, livePhrase): (String, String) = {
            if let convTranslit = external?.conversationExpectedTranslitForFeedback?.trimmingCharacters(in: .whitespacesAndNewlines), !convTranslit.isEmpty {
                let convPhrase = (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return (convTranslit, convPhrase)
            }
            return (
                (currentItem?.translit ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                (currentItem?.hint ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }()
        let liveScore: Int? = {
            guard case .feedback(let score, _) = phase else { return nil }
            return score
        }()
        let expected = snapshotExpected.wrappedValue.isEmpty ? liveTranslit : snapshotExpected.wrappedValue
        let expectedDisplay = expected.isEmpty ? "—" : expected
        let phraseLabel = snapshotPhraseLabel.wrappedValue.isEmpty ? livePhrase : snapshotPhraseLabel.wrappedValue
        let scoreForBreakdown = snapshotScore.wrappedValue ?? liveScore
        let showRecordingUnavailable = phase.isFeedback && (external?.lastAttempt == nil) && (external?.attemptCount ?? 0) > 0

        let breakdownPhaseValue = external?.phase ?? .idle
        let isRecordingFromBreakdownValue = external?.isRecordingFromBreakdown ?? false
        let recordingMeterValue = external?.recordingMeter ?? 0
        let referenceRevealValue = external?.referencePlaybackProgress ?? 1.0
        let onRecordAgainValue: (() -> Void)? = external?.onRecordAgainFromBreakdown ?? (showRecordingUnavailable ? nil : onDismiss)

        let displayScoreValue = external?.displayScore ?? scoreForBreakdown ?? 0
        let textScoreValue = external?.heardConfidence ?? scoreForBreakdown ?? 0
        let toneScoreValue = external?.toneAverageScore

        let cardView = speakerBreakdownOverlayCard(
            userText: userText,
            expected: expectedDisplay,
            phraseLabel: phraseLabel,
            displayScore: displayScoreValue,
            textScore: textScoreValue,
            toneScore: toneScoreValue,
            syllableFeedback: syllableFeedback,
            breakdownRequestInFlight: external?.breakdownRequestInFlight ?? false,
            breakdownRequestFailed: external?.breakdownRequestFailed ?? false,
            breakdownHybridScore: breakdownHybridScore,
            taikaHints: taikaHints,
            showRecordingUnavailable: showRecordingUnavailable,
            breakdownPhase: breakdownPhaseValue,
            isRecordingFromBreakdown: isRecordingFromBreakdownValue,
            recordingMeter: recordingMeterValue,
            referenceRevealProgress: referenceRevealValue,
            isProUser: external?.isProUser ?? false,
            hasFullToneAccess: hasFullToneBreakdownAccess,
            onDismiss: onDismiss,
            onRecordAgain: onRecordAgainValue,
            onStopRecordingFromBreakdown: external?.onStopRecordingFromBreakdown,
            onPlayReference: external?.onPlayReference,
            onPlayAttempt: external?.onPlayAttempt,
            presentsAsSheet: false
        )

        ZStack {
            Theme.Surfaces.blackGlassScrim
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { onDismiss() } }
            cardView
        }
        .padding(.horizontal, 16)
        .transition(.scale.combined(with: .opacity))
        .onAppear {
                external?.onBreakdownAppear?()
                if snapshotExpected.wrappedValue.isEmpty && !liveTranslit.isEmpty {
                    snapshotExpected.wrappedValue = liveTranslit
                    snapshotPhraseLabel.wrappedValue = livePhrase
                    snapshotScore.wrappedValue = liveScore
                }
            }
    }

    /// Две независимые метрики разбора: текст (слова) и тон (мелодия).
    /// Не смешиваем в один «скачущий» процент — иначе кажется, что оценка внезапно поменялась.
    @ViewBuilder
    private func breakdownDualScoreRow(
        textScore: Int,
        toneScore: Int?,
        overallScore: Int,
        toneLoading: Bool,
        isProUser: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                breakdownScoreMetricCard(
                    title: "Текст",
                    subtitle: "слова",
                    value: textScore,
                    ready: true
                )

                if let tone = toneScore {
                    breakdownScoreMetricCard(
                        title: "Тон",
                        subtitle: "мелодия",
                        value: tone,
                        ready: true
                    )
                } else if toneLoading {
                    breakdownScoreMetricCard(
                        title: "Тон",
                        subtitle: "считаю…",
                        value: nil,
                        ready: false
                    )
                } else if !isProUser {
                    breakdownScoreMetricCard(
                        title: "Тон",
                        subtitle: "Taika+",
                        value: nil,
                        ready: false,
                        locked: true
                    )
                }
            }

            if toneScore != nil {
                HStack(spacing: 6) {
                    Text("Итог")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                    Text("\(overallScore)%")
                        .font(.taikaStat(22))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .monospacedDigit()
                    Text("· берём более строгую из двух")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Итог \(overallScore) процентов, берём более строгую оценку")
            }
        }
    }

    @ViewBuilder
    private func breakdownScoreMetricCard(
        title: String,
        subtitle: String,
        value: Int?,
        ready: Bool,
        locked: Bool = false
    ) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
            if let value, ready {
                SpeakerCountingScore(
                    value: value,
                    font: .taikaStat(56),
                    color: AnyShapeStyle(ThemeManager.shared.currentAccentFill),
                    suffix: "%"
                )
            } else if locked {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Pro")
                        .font(.taikaStat(22))
                }
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                .frame(height: 56, alignment: .center)
            } else {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(ThemeManager.shared.currentAccentTintColor)
                    Text("…")
                        .font(.taikaStat(44))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.45))
                }
                .frame(height: 56, alignment: .center)
            }
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if let value, ready { return "\(title) \(value) процентов" }
            if locked { return "\(title), доступно в Taika+" }
            return "\(title), загружается"
        }())
    }

    private func speakerBreakdownOverlayCard(
        userText: String,
        expected: String,
        phraseLabel: String,
        displayScore: Int,
        textScore: Int,
        toneScore: Int?,
        syllableFeedback: [SpeakerManager.SyllableFeedback],
        breakdownRequestInFlight: Bool,
        breakdownRequestFailed: Bool,
        breakdownHybridScore: Int?,
        taikaHints: [String],
        showRecordingUnavailable: Bool,
        breakdownPhase: SpeakerManager.Phase,
        isRecordingFromBreakdown: Bool,
        recordingMeter: Double,
        referenceRevealProgress: Double,
        isProUser: Bool,
        hasFullToneAccess: Bool = false,
        onDismiss: @escaping () -> Void,
        onRecordAgain: (() -> Void)? = nil,
        onStopRecordingFromBreakdown: (() -> Void)? = nil,
        onPlayReference: (() -> Void)? = nil,
        onPlayAttempt: (() -> Void)? = nil,
        presentsAsSheet: Bool = false
    ) -> AnyView {
        let showRecordingInPlace = isRecordingFromBreakdown && breakdownPhase == .recording
        let unlockTone = hasFullToneAccess || isProUser
        let focusTitle: String = {
            if let toneScore, toneScore + 12 < textScore { return "Смотри тоны" }
            if let toneScore, textScore + 12 < toneScore { return "Смотри слова" }
            if textScore >= 75 { return "Уже близко" }
            return "Смотри слоги"
        }()
        let focusBody: String = {
            if let toneScore, toneScore + 12 < textScore {
                return "Слова уже читаются. Главный рычаг сейчас — тоны на каждом слоге."
            }
            if let toneScore, textScore + 12 < toneScore {
                return "Тоны живые. Сделай слоги чуть чётче — и фраза соберётся."
            }
            return "Посмотри график и слоги: где линия совпала — держи, где слабее — повтори."
        }()

        let headerView: AnyView = AnyView(
            HStack(alignment: .center, spacing: 8) {
                Text(presentsAsSheet ? "Разбор" : "разбор")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Spacer(minLength: 8)
                if showRecordingInPlace {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .shadow(color: Color.red.opacity(0.6), radius: 4)
                        Text("Запись")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PD.ColorToken.text)
                        TaikaTechWaveform(meter: max(0.2, recordingMeter), pace: .recording, lineCount: 2)
                            .frame(width: 72, height: 18)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.red.opacity(0.12))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                    )
                }
                if !presentsAsSheet {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { onDismiss() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
        )

        let scrollView: AnyView = AnyView(
            Group {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: presentsAsSheet ? 18 : 10) {
                        if presentsAsSheet {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(focusTitle)
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(PD.ColorToken.text)
                                Text(focusBody)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if !phraseLabel.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(phraseLabel)
                                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundStyle(PD.ColorToken.text)
                                    PhoneticWithColoredArrowsView(
                                        phonetic: Self.phoneticDisplayWithoutHyphens(expected),
                                        font: .system(size: 15, weight: .medium),
                                        alignment: .leading
                                    )
                                }
                            }

                            if unlockTone, !syllableFeedback.isEmpty || showRecordingInPlace {
                                breakdownPhraseGraphSection(
                                    expected: expected,
                                    syllableFeedback: syllableFeedback,
                                    isRecordingFromBreakdown: showRecordingInPlace,
                                    recordingMeter: recordingMeter,
                                    referenceRevealProgress: referenceRevealProgress,
                                    onboardingStyle: true
                                )
                            } else if unlockTone, breakdownRequestInFlight {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("Смотрю слоги…")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                }
                            } else if !unlockTone {
                                breakdownPhraseGraphPlaceholder(expected: expected, isProLocked: true)
                            }

                            if unlockTone, !syllableFeedback.isEmpty {
                                breakdownSyllableRowsHumanSection(
                                    expected: expected,
                                    syllableFeedback: syllableFeedback
                                )
                                let conclusion = Self.breakdownSummaryNoteHuman(syllableFeedback: syllableFeedback)
                                if !conclusion.isEmpty {
                                    Text(conclusion)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                }
                            } else if unlockTone, breakdownRequestFailed {
                                Text("Не удалось загрузить разбор. Попробуй ещё раз с хорошим интернетом.")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            } else if !unlockTone {
                                breakdownProTeaseSection(expected: expected)
                            }
                        } else {
                            // Legacy dense card (non-sheet)
                            VStack(alignment: .leading, spacing: 12) {
                                if !phraseLabel.isEmpty {
                                    Text(phraseLabel)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(PD.ColorToken.text)
                                        .lineLimit(3)
                                        .minimumScaleFactor(0.85)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                breakdownDualScoreRow(
                                    textScore: textScore,
                                    toneScore: toneScore,
                                    overallScore: displayScore,
                                    toneLoading: breakdownRequestInFlight && toneScore == nil && unlockTone,
                                    isProUser: unlockTone
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("нужно было")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                    PhoneticWithColoredArrowsView(
                                        phonetic: Self.phoneticDisplayWithoutHyphens(expected),
                                        font: .subheadline.weight(.medium),
                                        alignment: .leading
                                    )
                                    .lineLimit(5)
                                    .minimumScaleFactor(0.85)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    if let playRef = onPlayReference {
                                        Button { playRef() } label: {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("ты сказал")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                    Self.breakdownUserSaidLine(userText: userText)
                                    if let playAttempt = onPlayAttempt {
                                        Button(action: playAttempt) {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)

                            if !syllableFeedback.isEmpty || showRecordingInPlace {
                                breakdownPhraseGraphSection(
                                    expected: expected,
                                    syllableFeedback: syllableFeedback,
                                    isRecordingFromBreakdown: showRecordingInPlace,
                                    recordingMeter: recordingMeter,
                                    referenceRevealProgress: referenceRevealProgress
                                )
                            } else {
                                breakdownPhraseGraphPlaceholder(expected: expected, isProLocked: !unlockTone)
                            }
                            if !syllableFeedback.isEmpty {
                                breakdownSyllableRowsSection(expected: expected, syllableFeedback: syllableFeedback)
                            }

                            if !syllableFeedback.isEmpty {
                                let conclusion = Self.breakdownSummaryNote(syllableFeedback: syllableFeedback)
                                if !conclusion.isEmpty {
                                    Text(conclusion)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(PD.ColorToken.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 10)
                                        .padding(.bottom, 2)
                                }
                            } else if breakdownRequestInFlight {
                                TaikaLoadingView(
                                    label: "Загружаю разбор…",
                                    hint: "может занять 15–30 сек",
                                    compact: true
                                )
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                            } else if !unlockTone {
                                breakdownProTeaseSection(expected: expected)
                            } else {
                                let noToneMessage = breakdownRequestFailed
                                    ? "Не удалось загрузить разбор. Проверь интернет и Railway: сервис /assess может требовать больше памяти."
                                    : "Пока здесь только сравнение «ты сказал» и «нужно было». Разбор по тонам по слогам появится, когда будет подключён."
                                Text(noToneMessage)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 10)
                                    .padding(.bottom, 2)
                            }
                            if showRecordingUnavailable {
                                Text("запись недоступна")
                                    .font(.footnote)
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                                    .opacity(0.85)
                                    .padding(.top, 6)
                            }
                        }
                    }
                    .padding(.horizontal, presentsAsSheet ? 4 : 6)
                }
            }
        )

        let showPaywallCTA = !unlockTone
            && syllableFeedback.isEmpty
            && !breakdownRequestInFlight
            && !showRecordingInPlace
        let accent = ThemeManager.shared.currentAccentFill

        let footerView: AnyView = AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Divider().padding(.top, 2)
                if showRecordingInPlace, let stop = onStopRecordingFromBreakdown {
                    Button(action: stop) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Стоп")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Color.black.opacity(0.86))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule(style: .continuous).fill(accent))
                    }
                    .buttonStyle(.plain)
                } else {
                    if showPaywallCTA {
                        Button {
                            OverlayPresenter.shared.present(.speakerPaywall)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Открыть разбор по тонам")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(Color.black.opacity(0.86))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule(style: .continuous).fill(accent))
                        }
                        .buttonStyle(.plain)
                    }

                    if let onRecordAgain {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { onRecordAgain() }
                        } label: {
                            HStack(spacing: 8) {
                                Spacer(minLength: 0)
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Записать ещё раз")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(showPaywallCTA ? AnyShapeStyle(accent) : AnyShapeStyle(Color.black.opacity(0.86)))
                            .padding(.vertical, 13)
                            .background(
                                Group {
                                    if showPaywallCTA {
                                        Capsule(style: .continuous)
                                            .stroke(accent, lineWidth: 1.4)
                                    } else {
                                        Capsule(style: .continuous)
                                            .fill(accent)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        )

        let card = VStack(alignment: .leading, spacing: 8) {
            headerView
            scrollView
            footerView
        }
        .padding(.horizontal, 16)
        .padding(.top, presentsAsSheet ? 8 : 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        if presentsAsSheet {
            return AnyView(
                card
                    .background(PD.ColorToken.background.ignoresSafeArea())
            )
        }

        return AnyView(
            card
                .frame(maxHeight: UIScreen.main.bounds.height * 0.72)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .center)
                .taikaBlackGlassBackground(cornerRadius: 30)
        )
    }



    /// Эталонный контур тона для одного слога (полутоны): 8 точек для отображения.
    private static func referenceSegmentForTone(_ tone: String?) -> [Double] {
        let t = (tone ?? "Mid").trimmingCharacters(in: .whitespacesAndNewlines)
        let n = 8
        switch t {
        case "Low": return (0..<n).map { _ in -2.0 }
        case "High": return (0..<n).map { _ in 2.0 }
        case "Falling": return (0..<n).map { 2.0 - 4.0 * Double($0) / Double(n - 1) }
        case "Rising": return (0..<n).map { -2.0 + 4.0 * Double($0) / Double(n - 1) }
        default: return (0..<n).map { _ in 0.0 }
        }
    }

    /// Ожидаемый тон по куску эталонной фонетики (стрелка в транслите).
    private static func toneNameFromTranslitChunk(_ chunk: String) -> String {
        if chunk.contains("↘") { return "Falling" }
        if chunk.contains("↗") { return "Rising" }
        if chunk.contains("→") { return "Mid" }
        if chunk.contains("↓") { return "Low" }
        if chunk.contains("↑") { return "High" }
        return "Mid"
    }

    /// Заглушка графика тона: эталонный контур + «твоя линия» (locked / скоро).
    @ViewBuilder private func breakdownPhraseGraphPlaceholder(expected: String, isProLocked: Bool) -> some View {
        let refChunks = Self.translitChunksForSyllables(expected)
        let referenceContour = refChunks.flatMap { Self.referenceSegmentForTone(Self.toneNameFromTranslitChunk($0)) }
        let syllableLabels = refChunks.map { Self.syllableLabelWithoutArrows($0) }
        let accent = ThemeManager.shared.currentAccentFill

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("График тона по фразе")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                if isProLocked {
                    Text("Taika+")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent)
                }
                Spacer(minLength: 0)
            }

            if referenceContour.count >= 2 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Эталон")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                    AnimatedBreakdownSparkline(
                        values: referenceContour,
                        lineWidth: 2.5,
                        duration: 0.9
                    )
                    .opacity(0.72)
                    .frame(height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Ты сказал")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(PD.ColorToken.chip.opacity(0.55))
                        .frame(height: 28)
                    if isProLocked {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("контур голоса — в Taika+")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(accent)
                    } else {
                        Text("контур появится после разбора")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                    }
                }
                .frame(height: 28)
            }

            if !syllableLabels.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(syllableLabels.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.top, 2)
    }

    /// Два графика на всю фразу: эталон и пользователь. Ось X — подписи слогов, чтобы было видно, где ошибка.
    private func breakdownPhraseGraphSection(
        expected: String,
        syllableFeedback: [SpeakerManager.SyllableFeedback],
        isRecordingFromBreakdown: Bool,
        recordingMeter: Double,
        referenceRevealProgress: Double,
        onboardingStyle: Bool = false
    ) -> some View {
        let userContour = syllableFeedback.flatMap { $0.f0Contour ?? [] }
        let refChunks = Self.translitChunksForSyllables(expected)
        let referenceContour = refChunks.flatMap { Self.referenceSegmentForTone(Self.toneNameFromTranslitChunk($0)) }
        let showReference = referenceContour.count >= 2
        let showUser = isRecordingFromBreakdown || userContour.count >= 2
        // Ось X всегда по разбираемой фразе: все слоги из эталона (expected), а не по ответу API.
        let chunks = Self.translitChunksForSyllables(expected)
        let syllableLabels = chunks.map { Self.syllableLabelWithoutArrows($0) }
        guard showReference || showUser else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: onboardingStyle ? 8 : 6) {
                Text(onboardingStyle ? "График тона" : "График тона по фразе")
                    .font(onboardingStyle
                          ? .system(size: 13, weight: .bold, design: .rounded)
                          : .caption.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                if showReference {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Эталон")
                            .font(onboardingStyle
                                  ? .system(size: 12, weight: .medium)
                                  : .caption2.weight(.medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                        AnimatedBreakdownSparkline(
                            values: referenceContour,
                            lineWidth: 2.5,
                            duration: onboardingStyle ? 1.15 : 0.9
                        )
                        .opacity(0.72)
                        .frame(height: onboardingStyle ? 30 : 28)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ты сказал")
                        .font(onboardingStyle
                              ? .system(size: 12, weight: .medium)
                              : .caption2.weight(.medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                    if isRecordingFromBreakdown {
                        BreakdownLiveMeterLine(liveMeter: recordingMeter)
                            .frame(height: onboardingStyle ? 30 : 28)
                    } else if userContour.count >= 2 {
                        AnimatedBreakdownSparkline(
                            values: userContour,
                            lineWidth: 2.5,
                            duration: onboardingStyle ? 1.35 : 1.15
                        )
                        .frame(height: onboardingStyle ? 30 : 28)
                    } else {
                        EmptyView().frame(height: onboardingStyle ? 30 : 28)
                    }
                }
                if !syllableLabels.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(syllableLabels.enumerated()), id: \.offset) { _, label in
                            Text(label)
                                .font(.system(size: onboardingStyle ? 11 : 10, weight: .medium))
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, onboardingStyle ? 4 : 6)
                }
            }
            .padding(onboardingStyle ? 14 : 8)
            .padding(.horizontal, onboardingStyle ? 0 : 4)
            .background(
                RoundedRectangle(cornerRadius: onboardingStyle ? 16 : 10, style: .continuous)
                    .fill(PD.ColorToken.chip.opacity(onboardingStyle ? 1 : 0.65))
            )
            .padding(.top, 4)
        )
    }

    /// Полноширинный график контура (от края до края). isReference = серый эталон, иначе акцент.
    private static func breakdownPhraseSparkline(values: [Double], isReference: Bool = false) -> some View {
        let v = values
        guard v.count >= 2 else { return AnyView(EmptyView()) }
        let strokeColor: AnyShapeStyle = isReference
            ? AnyShapeStyle(Color.gray.opacity(0.8))
            : AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        return AnyView(
            BreakdownSparklineShape(values: v)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        )
    }

    /// Для отображения в разборе: эталон без дефисов между слогами (разделитель — пробел; тон уже в стрелке).
    private static func phoneticDisplayWithoutHyphens(_ phonetic: String) -> String {
        var result = phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        for arrow in ["→", "↓", "↘", "↑", "↗"] {
            result = result.replacingOccurrences(of: arrow + "-", with: arrow + " ")
        }
        return result
    }

    /// Разбиение эталона на подписи по слогам: по пробелу — слова, внутри слова по "-" и "·" (са-ват-ди кхрап → [са, ват, ди, кхрап]).
    private static func translitChunksForSyllables(_ expectedTranslit: String) -> [String] {
        let words = expectedTranslit
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return words.flatMap { word in
            word.split(omittingEmptySubsequences: true) { "-·".contains($0) }
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    /// Блок «по слогам»: столько строк, сколько слогов в эталонной фонетике; ответ API может быть короче — тогда плейсхолдеры.
    private func breakdownSyllableRowsSection(expected: String, syllableFeedback: [SpeakerManager.SyllableFeedback]) -> some View {
        let translitChunks = Self.translitChunksForSyllables(expected)
        let rows: [SyllableRow]
        if translitChunks.isEmpty {
            rows = syllableFeedback.map { s in
                let raw = s.syllable
                let label = Self.syllableLabelWithoutArrows(raw)
                let toneMatch = (s.toneExpected != nil && s.toneActual != nil) ? (s.toneExpected == s.toneActual) : nil
                return SyllableRow(
                    label: label.isEmpty ? "—" : label,
                    score: s.score,
                    comment: Self.localizedToneFeedback(s.comment, score: s.score, toneMatch: toneMatch),
                    toneExpected: s.toneExpected,
                    toneActual: s.toneActual,
                    f0Contour: s.f0Contour,
                    isPlaceholder: false
                )
            }
        } else {
            rows = translitChunks.enumerated().map { index, rawChunk in
            let label = Self.syllableLabelWithoutArrows(rawChunk)
            let toneFromChunk = Self.toneNameFromTranslitChunk(rawChunk)
            if index < syllableFeedback.count {
                let s = syllableFeedback[index]
                let toneMatch = (s.toneExpected != nil && s.toneActual != nil) ? (s.toneExpected == s.toneActual) : nil
                return SyllableRow(
                    label: label,
                    score: s.score,
                    comment: Self.localizedToneFeedback(s.comment, score: s.score, toneMatch: toneMatch),
                    toneExpected: s.toneExpected ?? toneFromChunk,
                    toneActual: s.toneActual,
                    f0Contour: s.f0Contour,
                    isPlaceholder: false
                )
            }
            return SyllableRow(
                label: label,
                score: 0,
                comment: "Оценка с сервера для этого слога не пришла — ориентируйся на эталон и запись.",
                toneExpected: toneFromChunk,
                toneActual: nil,
                f0Contour: nil,
                isPlaceholder: true
            )
            }
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text("по слогам")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                BreakdownSyllableRowView(row: row)
            }
        }
        .padding(.top, 2)
    }

    /// Free: короткий tease по слогам — без CTA внутри (кнопка только в футере разбора).
    @ViewBuilder private func breakdownProTeaseSection(expected: String) -> some View {
        let syllables = Self.syllablesFromTranslit(expected)
        let preview = Array(syllables.prefix(3))
        let accent = ThemeManager.shared.currentAccentFill

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("по слогам")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                Text("Taika+")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                Spacer(minLength: 0)
            }

            if !preview.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(preview.enumerated()), id: \.offset) { _, syllable in
                        HStack(spacing: 10) {
                            Text(syllable)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PD.ColorToken.text)
                            Text("тон слога")
                                .font(.caption)
                                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                            Spacer(minLength: 0)
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(PD.ColorToken.chip.opacity(0.55))
                        )
                    }
                }
            }

            Text("С Taika+ видно, какой слог «поплыл» по тону.")
                .font(.caption.weight(.medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    /// Заглушка разбора по слогам в модалке «разбор»: показывает слоги эталона и пояснение, что оценка тона/звука будет позже.
    @ViewBuilder private func breakdownSyllableStubSection(expected: String) -> some View {
        breakdownProTeaseSection(expected: expected)
    }

    @ViewBuilder private var idleHelperHint: some View {
        // keep constant vertical space so the carousel doesn't jump between phases
        ZStack {
            if phase == .hint, let first = taikaHints.first, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(first)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(first)
            } else if phase == .idle, !helperHasInteracted {
                Text(helperTypedText.isEmpty ? " " : helperTypedText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .opacity(helperIsVisible ? 0.86 : 0.0)
                    .animation(.easeInOut(duration: 0.22), value: helperIsVisible)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(!helperIsVisible)
            } else {
                // spacer placeholder (same typography metrics)
                Text(" ")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.clear)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 22, alignment: .center)
    }
    // MARK: sub-header — заголовок + режим; курсы — в иконке хедера (бывшая плашка попыток).
    private var isSpecialTrainingContext: Bool {
        guard let cid = external?.courseContextCourseId else { return false }
        return cid == "__dictionary__" || cid == "__favorites__"
    }

    private var trainingModePickerTitle: String {
        switch external?.courseContextCourseId {
        case "__dictionary__": return "Мой словарь"
        case "__favorites__": return "Избранное"
        default: return "Закрепление курсов"
        }
    }

    private var dictionaryContextBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Мой словарь")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Capsule().fill(ThemeManager.shared.currentAccentFill))
        .accessibilityLabel("Режим: мой словарь")
    }

    private var favoritesContextBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Избранное")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Capsule().fill(ThemeManager.shared.currentAccentFill))
        .accessibilityLabel("Режим: избранное")
    }

    private var topChrome: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("Спикер")
                    .font(CD.FontToken.title(28, weight: .bold))
                    .foregroundStyle(CD.ColorToken.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 6)

                if speakerUIMode == .conversation, let ext = external {
                    SmartSpeakerPolitenessMenuButton(
                        value: ext.smartSpeakerPoliteness,
                        onSelect: ext.onSetSmartSpeakerPoliteness
                    )
                }

                if speakerUIMode == .training, external?.courseContextCourseId == "__dictionary__" {
                    dictionaryContextBadge
                    Button {
                        external?.onSpeakerUIModeChange(.conversation)
                    } label: {
                        Text("Скажи сам")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Capsule().fill(CD.ColorToken.chip))
                    }
                    .buttonStyle(.plain)
                } else if speakerUIMode == .training, external?.courseContextCourseId == "__favorites__" {
                    favoritesContextBadge
                    Button {
                        external?.onSpeakerUIModeChange(.conversation)
                    } label: {
                        Text("Скажи сам")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CD.ColorToken.textSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Capsule().fill(CD.ColorToken.chip))
                    }
                    .buttonStyle(.plain)
                } else {
                    AppInlineFilterPicker(
                        titles: [trainingModePickerTitle, "Скажи сам"],
                        selectedIndex: speakerUIMode == .conversation ? 1 : 0
                    ) { index in
                        let mode: SpeakerManager.SpeakerUIMode = index == 1 ? .conversation : .training
                        external?.onSpeakerUIModeChange(mode)
                    }
                }
            }
            .padding(.horizontal, CD.Spacing.screen)

            if speakerUIMode == .training,
               !isSpecialTrainingContext,
               !allSpeakerItems.isEmpty,
               let lessonIds = external?.learnedLessonIds,
               lessonIds.count > 1,
               external?.onSelectLearnedLessonFilter != nil {
                learnedLessonChipsRow(lessonIds: lessonIds)
            }
        }
        .padding(.top, rootHeaderClearance > 0 ? rootHeaderClearance : Theme.Layout.sectionTop)
        .padding(.bottom, 4)
    }

    private func learnedLessonChipsRow(lessonIds: [String]) -> some View {
        let selected = external?.learnedLessonFilter
        let titleFor: (String) -> String = { id in
            external?.lessonTitleForLessonId?(id) ?? id
        }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                AppFilterChip(
                    title: "Все уроки",
                    isActive: selected == nil || selected?.isEmpty == true,
                    scale: .s
                ) {
                    external?.onSelectLearnedLessonFilter?(nil)
                }
                ForEach(lessonIds, id: \.self) { lid in
                    AppFilterChip(
                        title: titleFor(lid),
                        isActive: selected == lid,
                        scale: .s
                    ) {
                        external?.onSelectLearnedLessonFilter?(lid)
                    }
                }
            }
            .padding(.horizontal, CD.Spacing.screen)
        }
        .accessibilityLabel("Фильтр по урокам")
    }



    // MARK: pro wireframe

    private var allSpeakerItems: [SpeakerItem] {
#if DEBUG
        if let p = previewExternal {
            return p.items
        }
#endif

        if let extItems = external?.items {
            var out: [SpeakerItem] = []
            out.reserveCapacity(extItems.count)
            var seen: Set<UUID> = []

            for cur in extItems {
                let id = externalResolveId(cur)
                if seen.contains(id) { continue }
                seen.insert(id)

                out.append(
                    SpeakerItem(
                        id: id,
                        phrase: cur.face.subtitleTH,
                        translit: cur.face.phonetic,
                        hint: cur.face.titleRU,
                        lessonTitle: speakerItemLessonTitle(for: cur.lessonId),
                        kindTag: "фраза",
                        isFavorite: false,
                        isProLocked: false
                    )
                )
            }

            return out
        }

        if let cur = currentItem {
            return [cur]
        }

        return []
    }

    // MARK: - expose current result values for top card
    private var heardRUText: String {
#if DEBUG
        if let p = previewExternal {
            return (p.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
#endif
        return (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var heardTranslitText: String {
#if DEBUG
        if let p = previewExternal {
            return (p.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
#endif
        return (external?.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var heardConfidenceValue: Int {
#if DEBUG
        if let p = previewExternal {
            return p.heardConfidence
        }
#endif
        return external?.heardConfidence ?? 0
    }


    private var activeMode: SpeakerMode {
        if let id = activeFilterId, let m = SpeakerMode(id: id) { return m }
        return .current
    }

    private var emptyStateTitle: String {
        switch activeMode {
        case .current: return "Закрепи фразы голосом"
        case .favorites: return "Избранное ждёт первые фразы"
        case .learned: return "Выученные фразы соберутся тут"
        case .random: return "Скоро будет что сказать"
        }
    }

    private var emptyStateSubtitle: String {
        switch activeMode {
        case .current:
            return "Пройди шаги в уроке — карточки появятся здесь, и можно тренировать произношение."
        case .favorites:
            return "Лайкни фразы в уроках — они станут очередью для спикера."
        case .learned:
            return "Отмечай степы как выученные — и возвращайся сюда закрепить голос."
        case .random:
            return "Открой урок или лайкни фразы — очередь наполнится сама."
        }
    }

    @ViewBuilder private var emptyCarouselState: some View {
        speakerTeaserCoverflow(
            slides: TaikaValueDeck.speakerTraining,
            index: $trainingTeaserIndex
        )
    }

    private struct SpeakerTumbleweed404Scene: View {
        @State private var xOffset: CGFloat = -140
        @State private var rotation: Double = -14

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, CD.ColorToken.textSecondary.opacity(0.18), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .offset(y: -9)

                    TumbleweedGlyph()
                        .frame(width: 34, height: 34)
                        .foregroundStyle(CD.ColorToken.textSecondary.opacity(0.86))
                        .offset(x: xOffset, y: -8)
                        .rotationEffect(.degrees(rotation))
                        .shadow(color: Color.black.opacity(0.18), radius: 4, y: 2)
                        .onAppear {
                            xOffset = -50
                            let target = max(geo.size.width + 50, 220)
                            withAnimation(.linear(duration: 4.2).repeatForever(autoreverses: false)) {
                                xOffset = target
                            }
                            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                                rotation = 346
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }

    private struct TumbleweedGlyph: View {
        var body: some View {
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
                let c = CGPoint(x: rect.midX, y: rect.midY)
                let r = min(rect.width, rect.height) / 2
                var p = Path()
                p.addEllipse(in: rect)
                p.move(to: CGPoint(x: c.x - r, y: c.y))
                p.addLine(to: CGPoint(x: c.x + r, y: c.y))
                p.move(to: CGPoint(x: c.x, y: c.y - r))
                p.addLine(to: CGPoint(x: c.x, y: c.y + r))
                p.move(to: CGPoint(x: c.x - r * 0.72, y: c.y - r * 0.72))
                p.addLine(to: CGPoint(x: c.x + r * 0.72, y: c.y + r * 0.72))
                p.move(to: CGPoint(x: c.x + r * 0.72, y: c.y - r * 0.72))
                p.addLine(to: CGPoint(x: c.x - r * 0.72, y: c.y + r * 0.72))
                context.stroke(p, with: .color(Color.white.opacity(0.72)), lineWidth: 1.25)
            }
        }
    }

    // MARK: - speaker player panel (audio-first, mic-centered)
    // layout:
    // - idle/record/analyze: [play ref] [mic] [play attempt]
    // - result: [play ref] [play attempt] (so user can compare what they said)
    @ViewBuilder
    private var speakerPlayerPanel: some View {

        let isRecording: Bool = {
            if case .recording = phase { return true }
            return false
        }()

        let isAnalyzing: Bool = (phase == .analyzing)
        let isFeedback = phase.isFeedback
        let disabledAll = isAnalyzing

        let canPlayReference = !disabledAll
        let hasAttempt: Bool = {
#if DEBUG
            if let p = previewExternal {
                return p.lastAttempt != nil
            }
#endif
            return external?.lastAttempt != nil
        }()
        // in feedback phase we must ALWAYS allow replaying user attempt if it exists
        let canPlayAttempt = hasAttempt

        HStack(spacing: 18) {

            // PREV
            Button {
                external?.onPrev?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        AnyShapeStyle(
                            disabledAll
                            ? PD.ColorToken.textSecondary.opacity(0.35)
                            : PD.ColorToken.text
                        )
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabledAll)

            // PLAY REFERENCE
            Button {
                guard canPlayReference else { return }
                external?.onPlayReference()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        AnyShapeStyle(
                            canPlayReference
                            ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                            : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.35))
                        )
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canPlayReference)

            // PRIMARY (MIC / STOP / REPEAT)
            Button {
                if isRecording {
                    external?.onMicTap()   // stop recording
                } else if isFeedback {
                    external?.onRepeat()   // repeat after result
                } else {
                    external?.onMicTap()   // start recording
                }
            } label: {
                Image(systemName:
                        isRecording
                        ? "stop.fill"
                        : (isFeedback ? "arrow.clockwise" : "mic.fill")
                )
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 72, height: 72)
                    .background(
                        Circle()
                            .fill(ThemeManager.shared.currentAccentFill)
                    )
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            .disabled(isAnalyzing)

            // PLAY ATTEMPT (что сказал) — тот же стиль, что и play: иконка цветом, активна только после записи
            Button {
                guard canPlayAttempt else { return }
                external?.onPlayAttempt()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        canPlayAttempt
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        : AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.35))
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canPlayAttempt)

            // NEXT
            Button {
                external?.onNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        AnyShapeStyle(
                            disabledAll
                            ? PD.ColorToken.textSecondary.opacity(0.35)
                            : PD.ColorToken.text
                        )
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabledAll)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }


    // nav icons: prev/next/play (always visible, same size)
    private func speakerNavIcon(system: String, isDisabled: Bool) -> some View {
        Image(systemName: system)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(isDisabled ? AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.35)) : AnyShapeStyle(PD.ColorToken.text))
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
    }
    
    // sketchy icons: shuffle/favorite - hand-drawn style
    private func speakerSketchyIcon(system: String, isDisabled: Bool, isActive: Bool = false) -> some View {
        let accent = AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        let fgColor: AnyShapeStyle = {
            if isDisabled {
                return AnyShapeStyle(PD.ColorToken.textSecondary.opacity(0.35))
            } else if isActive {
                return accent
            } else {
                return AnyShapeStyle(PD.ColorToken.textSecondary)
            }
        }()
        
        return ZStack {
            // sketchy background circle (hand-drawn effect)
            Circle()
                .stroke(fgColor, lineWidth: 1.5)
                .frame(width: 40, height: 40)
                .opacity(0.4)
            
            // icon with slight rotation for sketchy feel
            Image(systemName: system)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(fgColor)
                .rotationEffect(.degrees(isActive ? 2 : -1))
        }
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
    }

    // MIC button: simple, in our identity - always same size (now 64x64)
    private func speakerMicButton(phase: SpeakerManager.Phase, isRecording: Bool, isAnalyzing: Bool) -> some View {
        let accent = AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        let isIdle = (phase == .idle)
        let isResult = phase.isFeedback

        // ALWAYS same size: 64x64 (same as nav buttons)
        let buttonSize: CGFloat = 64

        return ZStack {
            // IDLE / RESULT: simple microphone
            if isIdle || isResult {
                Circle()
                    .fill(accent)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(color: Color.accentColor.opacity(0.15), radius: 12, x: 0, y: 0)

                Image(systemName: "mic.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(Color.black.opacity(0.95)))
            }

            // RECORDING: simple pulsing circle with stop icon
            if isRecording {
                // simple pulse ring
                Circle()
                    .stroke(accent.opacity(0.5), lineWidth: 2)
                    .frame(width: buttonSize + 8, height: buttonSize + 8)
                    .scaleEffect(1.0)
                    .opacity(0.6)
                    .animation(
                        .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                        value: isRecording
                    )

                // main button
                Circle()
                    .fill(accent)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 16, x: 0, y: 0)

                // stop icon
                Image(systemName: "stop.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(Color.black.opacity(0.95)))
            }

            // ANALYZING: simple rotating indicator
            if isAnalyzing {
                // rotating circle
                Circle()
                    .trim(from: 0.0, to: 0.75)
                    .stroke(accent.opacity(0.6), lineWidth: 3)
                    .frame(width: buttonSize, height: buttonSize)
                    .rotationEffect(.degrees(isAnalyzing ? 360 : 0))
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: isAnalyzing
                    )

                // center circle
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: buttonSize - 8, height: buttonSize - 8)
            }
        }
        .frame(width: buttonSize, height: buttonSize)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isAnalyzing)
    }

    @ViewBuilder private var topCarousel: some View {
        let items = allSpeakerItems
        if items.isEmpty {
            emptyCarouselState
                .frame(height: CardDS.Metrics.speakerPhraseCardHeight)
        } else {
            let currentId = external?.selectedId ?? localSelectedId ?? currentItem?.id ?? items.first?.id
            let itemW: CGFloat = CardDS.Metrics.speakerPhraseCardWidth
            let itemH: CGFloat = CardDS.Metrics.speakerPhraseCardHeight

            let activeId = currentId
            let currentIndex = items.firstIndex(where: { $0.id == activeId }) ?? 0

            // centered 3d carousel: стрелки + свайп + тап по соседней карточке.
            ZStack {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    let rel = index - currentIndex

                    SpeakerTopCard(
                        item: item,
                        isActive: index == currentIndex,
                        phase: index == currentIndex ? phase : .idle,
                        recordingPartialTranslit: index == currentIndex ? recordingPartialTranslit : nil,
                        recordingMeter: index == currentIndex ? recordingMeter : 0,
                        heardRU: index == currentIndex ? external?.heardRU : nil,
                        heardTranslit: index == currentIndex ? external?.heardTranslit : nil,
                        heardConfidence: index == currentIndex ? heardConfidenceValue : 0,
                        canPlayAttempt: index == currentIndex ? (external?.lastAttempt != nil) : false,
                        attemptCount: index == currentIndex ? (external?.attemptCount ?? 0) : 0,
                        lastPlayed: index == currentIndex ? (external?.lastPlayed ?? .none) : .none,
                        referencePlaybackProgress: index == currentIndex ? (external?.referencePlaybackProgress ?? 1.0) : 1.0,
                        onPlayReference: {
                            if let cb = external?.onPlayReferenceForId {
                                cb(item.id)
                            } else {
                                external?.onPlayReference()
                            }
                        },
                        onPlayAttempt: {
                            external?.onPlayAttempt()
                        }
                    )
                    .frame(width: itemW, height: itemH)
                    .scaleEffect(rel == 0 ? 1.0 : 0.82)
                    .rotation3DEffect(
                        .degrees(Double(rel) * -18),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.7
                    )
                    .opacity(rel == 0 ? 1.0 : 0.45)
                    .offset(x: CGFloat(rel) * (itemW * 0.92))
                    .zIndex(rel == 0 ? 10 : Double(10 - abs(rel)))
                    .animation(.easeInOut(duration: 0.35), value: currentIndex)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard index != currentIndex else { return }
                        // keep local fallback for DS-only previews
                        localSelectedId = item.id
                        // notify external (SpeakerView/SpeakerManager) so result/recording uses the selected card
                        external?.onSelectCard(item.id)
                    }
                }
            }
            .frame(height: itemH + 12)
            .frame(maxWidth: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        // как у стрелок: во время анализа не листаем
                        guard phase != .analyzing else { return }
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > 48, abs(dx) > abs(dy) * 1.15 else { return }
                        if dx < 0 {
                            external?.onNext()
                        } else {
                            external?.onPrev?()
                        }
                    }
            )
        }
    }




    @ViewBuilder private var centerResult: some View {
        // all states are rendered inside the active top carousel card (single-carousel concept)
        EmptyView()
    }

    private var proResultHero: some View {
        guard case .feedback = phase else { return AnyView(EmptyView()) }

        let heardPhonetic: String = {
#if DEBUG
            if let p = previewExternal {
                return (p.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
#endif
            return (external?.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        let heardRU: String = {
#if DEBUG
            if let p = previewExternal {
                return (p.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
#endif
            return (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }()

        return AnyView(
            VStack(alignment: .center, spacing: 0) {
                VStack(alignment: .center, spacing: 10) {
                    // recognized (main) — ru translation
                    Text("перевод")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .opacity(0.85)
                        .padding(.bottom, 2)

                    if !heardRU.isEmpty {
                        Text(heardRU)
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(T.Colors.textPrimary)
                            .kerning(0.35)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.72)
                            .padding(.horizontal, 10)
                    } else {
                        Text("—")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }

                    // phonetic (what user said) — russian letters
                    if !heardPhonetic.isEmpty {
                        Text(heardPhonetic)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .opacity(0.82)
                            .padding(.top, 2)
                    }

                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 12)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 22)
        )
    }

    private var bottomPrimaryAction: some View {
        let title: String
        let icon: String
        let action: () -> Void

        switch phase {
        case .recording:
            title = "stop"
            icon = "stop.circle.fill"
            action = { external?.onMicTap() }
        case .feedback:
            title = "ещё раз"
            icon = "arrow.clockwise"
            action = { external?.onRepeat() }
        case .hint:
            title = "ещё раз"
            icon = "arrow.clockwise"
            action = { external?.onRepeat() }
        default:
            title = "говорить"
            icon = "mic.fill"
            action = { external?.onMicTap() }
        }

        return Button(action: action) {
            HStack {
                Spacer(minLength: 0)

                Text(title)
                    .font(.headline.weight(.semibold))

                Spacer(minLength: 0)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.black.opacity(0.92))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .overlay(Capsule(style: .continuous).stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, alignment: .center)
    }


    private var activeFilterId: UUID? {
#if DEBUG
        if let p = previewExternal {
            return p.activeFilterId
        }
#endif
        return external?.activeFilterId
    }

}


// MARK: - Smart Speaker / LLM phonetic: нормализация + отрисовка как в CardDS (каждая стрелка — accent)
/// LLM часто даёт «буква пробел стрелка» или стрелки между буквами; парсер по пробелам ломал подсветку стрелок.
private enum TaikaSmartSpeakerPhonetic {
    private static let toneArrows: Set<Character> = ["→", "↓", "↘", "↑", "↗"]

    /// Схлопывание «буква пробел стрелка», затем «стрелка-дефис» → «стрелка пробел» (как phoneticDisplayWithoutHyphens).
    static func normalize(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = true
        while changed {
            changed = false
            let chars = Array(t)
            let n = chars.count
            if n < 3 { break }
            for i in 0..<(n - 2) {
                let a = chars[i], b = chars[i + 1], c = chars[i + 2]
                guard b.isWhitespace, Self.toneArrows.contains(c) else { continue }
                guard Self.isPhoneticBodyScalar(a) else { continue }
                let start = t.index(t.startIndex, offsetBy: i)
                let end = t.index(start, offsetBy: 3)
                t.replaceSubrange(start..<end, with: String([a, c]))
                changed = true
                break
            }
        }
        for arrow in Self.toneArrows {
            t = t.replacingOccurrences(of: String(arrow) + "-", with: String(arrow) + " ")
        }
        return t
    }

    private static func isPhoneticBodyScalar(_ ch: Character) -> Bool {
        if "-·'ʼ".contains(ch) { return true }
        guard let s = ch.unicodeScalars.first else { return false }
        let v = s.value
        if (0x0400...0x04FF).contains(v) { return true }
        if v == 0x0451 || v == 0x0401 { return true }
        return false
    }

    /// Как `phoneticStyledText` в CardDS: слоги/пробелы — базовый текст, каждая стрелка — accent (всегда).
    static func styledText(_ raw: String, font: Font) -> Text {
        let norm = normalize(raw)
        guard !norm.isEmpty else {
            return Text("").font(font)
        }
        let separators: Set<Character> = [" ", "-", "·"]
        var result = Text("")
        var chunk = ""
        func flushChunk() {
            guard !chunk.isEmpty else { return }
            result = result + Text(chunk).foregroundStyle(PD.ColorToken.text)
            chunk = ""
        }
        for ch in norm {
            if Self.toneArrows.contains(ch) {
                flushChunk()
                result = result + Text(String(ch)).foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
            } else if separators.contains(ch) {
                flushChunk()
                result = result + Text(String(ch)).foregroundStyle(PD.ColorToken.text)
            } else {
                chunk.append(ch)
            }
        }
        flushChunk()
        return result.font(font)
    }

    /// Слоги для анимации: накапливаем до стрелки, затем сброс (без разбиения по пробелам как «слоги»).
    static func syllableArrowSegments(_ raw: String) -> [(syllable: String, arrow: String)] {
        let norm = normalize(raw)
        var out: [(String, String)] = []
        var buf = ""
        for ch in norm {
            if Self.toneArrows.contains(ch) {
                let syl = buf.trimmingCharacters(in: .whitespacesAndNewlines)
                out.append((syl, String(ch)))
                buf = ""
            } else {
                if ch.isWhitespace && buf.isEmpty { continue }
                buf.append(ch)
            }
        }
        let tail = buf.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            out.append((tail, "→"))
        }
        return out
    }
}

// MARK: - Транслит со стрелками тонов (цвет по accent, как в спикере и степе)
private struct PhoneticWithColoredArrowsView: View {
    let phonetic: String
    var font: Font = .system(size: 22, weight: .semibold)
    var alignment: TextAlignment = .center

    var body: some View {
        TaikaSmartSpeakerPhonetic.styledText(phonetic, font: font)
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    }
}

/// Караоке «заливка слева направо» по строке фонетики (без прыжка по слогам).
private struct ConversationPhoneticFillKaraokeView: View {
    let phonetic: String
    /// Полный цикл заливки (секунды), затем повтор.
    private let cycle: TimeInterval = 4.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let p = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
            let fill = CGFloat(p)
            ZStack(alignment: .leading) {
                PhoneticWithColoredArrowsView(phonetic: phonetic, font: .system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .opacity(0.36)
                PhoneticWithColoredArrowsView(phonetic: phonetic, font: .system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .mask(
                        GeometryReader { g in
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: max(0, g.size.width * fill), height: g.size.height, alignment: .leading)
                                .frame(width: g.size.width, height: g.size.height, alignment: .leading)
                        }
                    )
            }
        }
    }
}

/// Нативное меню вежливости — компактный чип в строке заголовка.
private struct SmartSpeakerPolitenessMenuButton: View {
    let value: String
    let onSelect: (String) -> Void

    private var isMale: Bool { value == "male" }
    private var shortLabel: String { isMale ? "М" : "Ж" }

    var body: some View {
        Menu {
            Button {
#if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                onSelect("male")
            } label: {
                Label("Мужской", systemImage: isMale ? "checkmark" : "")
            }
            Button {
#if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                onSelect("female")
            } label: {
                Label("Женский", systemImage: isMale ? "" : "checkmark")
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(shortLabel)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.92))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                ZStack {
                    let shape = Capsule(style: .continuous)
                    shape.fill(CD.ColorToken.card.opacity(0.78))
                    shape.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                }
            )
        }
        .accessibilityLabel("Вежливость речи, \(shortLabel)")
    }
}

// MARK: - Tone animation (при воспроизведении эталона — направление тона по слогам)

private struct PhoneticToneAnimationView: View {
    let phonetic: String
    let playbackProgress: Double

    private var segments: [(syllable: String, arrow: String)] {
        TaikaSmartSpeakerPhonetic.syllableArrowSegments(phonetic)
    }

    var body: some View {
        let segs = segments
        let n = segs.count
        let activeIndex: Int = n > 0 && playbackProgress < 1.0
            ? min(Int(playbackProgress * Double(n)), n - 1)
            : -1

        HStack(spacing: 4) {
            ForEach(Array(segs.enumerated()), id: \.offset) { index, seg in
                HStack(spacing: 2) {
                    Text(seg.syllable)
                        .foregroundStyle(PD.ColorToken.text)
                    Text(seg.arrow)
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .modifier(ToneArrowAnimationModifier(arrow: seg.arrow, isActive: index == activeIndex))
                }
            }
        }
        .font(.title3.weight(.semibold))
        .lineLimit(2)
        .minimumScaleFactor(0.80)
    }
}

/// Направление тона при воспроизведении: стрелка слегка двигается в сторону тона (↗ вверх, ↘ вниз, → пульс).
private struct ToneArrowAnimationModifier: ViewModifier {
    let arrow: String
    let isActive: Bool

    private var toneOffset: CGFloat {
        guard isActive else { return 0 }
        switch arrow {
        case "↗", "↑": return -5
        case "↘", "↓": return 5
        default: return 0
        }
    }

    private var toneScale: CGFloat {
        guard isActive else { return 1.0 }
        return arrow == "→" ? 1.18 : 1.08
    }

    func body(content: Content) -> some View {
        content
            .offset(y: toneOffset)
            .scaleEffect(toneScale)
            .animation(.easeOut(duration: 0.2), value: isActive)
    }
}

// MARK: - carousel/coverflow effect for top card

private struct SpeakerTopCard: View {
    let item: SpeakerItem
    let isActive: Bool
    let phase: SpeakerPhase
    let recordingPartialTranslit: String?
    let recordingMeter: Double
    let heardRU: String?
    let heardTranslit: String?
    let heardConfidence: Int
    let canPlayAttempt: Bool
    let attemptCount: Int
    let lastPlayed: SpeakerManager.LastPlayed
    /// 0…1 во время воспроизведения эталона — для анимации тона по слогам.
    let referencePlaybackProgress: Double
    let onPlayReference: () -> Void
    let onPlayAttempt: () -> Void

    @State private var recordPulse: CGFloat = 0
    @State private var analyzePulse: CGFloat = 0

    private var isRecordingActive: Bool {
        guard isActive else { return false }
        if case .recording = phase { return true }
        return false
    }

    private var isAnalyzingActive: Bool {
        guard isActive else { return false }
        return phase == .analyzing
    }

    private var isResultActive: Bool {
        guard isActive else { return false }
        return phase.isFeedback
    }

    @ViewBuilder private var attemptChip: some View {
        EmptyView()
    }

    private func clean(_ s: String?) -> String {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var ruTitle: String {
        // main title in the card: russian meaning (what we show as the card title)
        // in speaker items, `hint` is ru meaning.
        clean(item.hint)
    }

    private var translitAccent: String {
        // pink line: reference phonetic/translit
        clean(item.translit)
    }

    private var thaiSecondary: String {
        // secondary grey line: thai script
        clean(item.phrase)
    }

    private var heardRUText: String { clean(heardRU) }
    private var heardTranslitText: String { clean(heardTranslit) }

    private var feedbackScore: Int? {
        guard isResultActive else { return nil }
        if case .feedback(let score, _) = phase { return score }
        return nil
    }

    private var verdictIsMatch: Bool {
        // v0: verdict is driven only by numeric score from SpeakerManager
        // (no string containment hacks; no RU fallback)
        guard let s = feedbackScore else { return false }
        return s >= 70
    }

    // verdictPill removed as per instructions

    @ViewBuilder private var leftAudioButton: some View {
        let isDisabledCommon = (!isActive) || isRecordingActive || isAnalyzingActive
        let canAttempt = canPlayAttempt && !isDisabledCommon
        let canReference = !isDisabledCommon

        HStack(spacing: 6) {
            Button(action: {
                guard canReference else { return }
                onPlayReference()
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!canReference)
            .accessibilityLabel(isRecordingActive ? "идёт запись" : "эталон")

            Button(action: {
                guard canAttempt else { return }
                onPlayAttempt()
            }) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!canAttempt)
            .accessibilityLabel("моя запись")
        }
        .opacity(isActive ? 1.0 : 0.0)
    }



    private enum VerdictKind {
        case match, mismatch

        var title: String {
            switch self {
            case .match: return "совпало"
            case .mismatch: return "не совпало"
            }
        }

        var tint: AnyShapeStyle {
            switch self {
            case .match:
                return AnyShapeStyle(ThemeManager.shared.currentAccentFill)
            case .mismatch:
                return AnyShapeStyle(Color.white)
            }
        }

        var shadowColor: Color {
            switch self {
            case .match:
                // approximate accent for shadows
                return Color.accentColor
            case .mismatch:
                return Color.white
            }
        }

        var dotOpacity: Double {
            switch self {
            case .match: return 0.38
            case .mismatch: return 0.22
            }
        }

        var strokeOpacity: Double {
            switch self {
            case .match: return 0.30
            case .mismatch: return 0.16
            }
        }

        var glowOpacity: Double {
            switch self {
            case .match: return 0.20
            case .mismatch: return 0.10
            }
        }
    }

    private var verdictKind: VerdictKind {
        verdictIsMatch ? .match : .mismatch
    }

    @ViewBuilder private var phaseBadge: some View {
        // bug-02: restore all phase badges for visibility
        if isResultActive {
            resultBadge
        } else if isRecordingActive {
            recordingBadge
        } else if isAnalyzingActive {
            analyzingBadge
        } else {
            EmptyView()
        }
    }

    @ViewBuilder private var resultBadge: some View {
        EmptyView()
    }

    @ViewBuilder private var recordingBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .frame(width: 8, height: 8)
                .opacity(0.85)

            Text("запись")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(Color.clear)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.2)
                )
        )
        .opacity(isActive ? 1.0 : 0.0)
    }

    @ViewBuilder private var analyzingBadge: some View {
        HStack(spacing: 8) {
            TypingDots(scale: 0.90)
                .opacity(0.92)

            Text("анализ")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.95))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(Color.clear)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.2)
                )
        )
        .shadow(
            color: Color.accentColor.opacity(0.12),
            radius: 12,
            x: 0,
            y: 2
        )
        .opacity(isActive ? 1.0 : 0.0)
        .scaleEffect(isActive ? 1.0 : 0.92)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isActive)
    }


    @ViewBuilder private func aiBackGlow(intensity: CGFloat, isCold: Bool) -> some View {
        // single centered “ai core sphere” BEHIND the card.
        // IMPORTANT: we keep it centered and avoid any lateral offsets so it reads as coming out from the card center.
        let a = Color.accentColor
        let w = Color.white

        ZStack {
            // core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            a.opacity((isCold ? 0.10 : 0.18) * intensity),
                            a.opacity((isCold ? 0.05 : 0.09) * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 210
                    )
                )
                .frame(width: 360, height: 360)

            // soft white bloom (depth)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            w.opacity((isCold ? 0.04 : 0.07) * intensity),
                            w.opacity((isCold ? 0.02 : 0.03) * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 260
                    )
                )
                .frame(width: 460, height: 460)

            // outer faint accent haze
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            a.opacity((isCold ? 0.035 : 0.055) * intensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 320
                    )
                )
                .frame(width: 560, height: 560)
        }
        .blur(radius: 40)
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // Mask that removes the card interior from the glow so it never looks like it sits ON TOP of the card.
    // This keeps the “sphere” clearly BEHIND and only visible around the card edges.
    private var glowOutsideCardMask: some View {
        let card = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        return Rectangle()
            .fill(Color.black)
            .overlay(
                card
                    .fill(Color.black)
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
    }

    @ViewBuilder private var hiTechRecordingFrame: some View {
        if !isRecordingActive {
            EmptyView()
        } else {
            let intensity = 0.55 + 0.45 * recordPulse

            aiBackGlow(intensity: intensity, isCold: false)
                // larger than the card so it “leaks” outside
                .frame(width: 700, height: 520)
                // ensure glow does NOT tint the semi-transparent card surface
                .mask(glowOutsideCardMask)
                .opacity(0.78)
                .transition(.opacity)
                .onAppear {
                    recordPulse = 0
                    withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                        recordPulse = 1
                    }
                }
        }
    }

    @ViewBuilder private var hiTechAnalyzingFrame: some View {
        if !isAnalyzingActive {
            EmptyView()
        } else {
            let intensity = 0.45 + 0.35 * analyzePulse

            aiBackGlow(intensity: intensity, isCold: true)
                .frame(width: 700, height: 520)
                .mask(glowOutsideCardMask)
                .opacity(0.64)
                .transition(.opacity)
                .onAppear {
                    analyzePulse = 0
                    withAnimation(.easeInOut(duration: 1.55).repeatForever(autoreverses: true)) {
                        analyzePulse = 1
                    }
                }
        }
    }

    @ViewBuilder private var hiTechResultFrame: some View {
        if !isResultActive {
            EmptyView()
        } else {
            let tint = verdictKind.tint
            RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                .stroke(
                    tint,
                    lineWidth: 1.2
                )
                .shadow(color: verdictKind.shadowColor.opacity(verdictKind.glowOpacity), radius: 18)
                .shadow(color: verdictKind.shadowColor.opacity(verdictKind.glowOpacity * 0.7), radius: 36)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.00),
                            verdictKind.shadowColor.opacity(0.08),
                            Color.white.opacity(0.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.screen)
                    .opacity(0.65)
                    .mask(
                        RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                            .stroke(Color.white, lineWidth: 8)
                    )
                )
                .transition(.opacity)
        }
    }


    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        let normalizedTranslit = TaikaSmartSpeakerPhonetic.normalize(translitAccent)
        let toneSegmentsCount = TaikaSmartSpeakerPhonetic.syllableArrowSegments(translitAccent).count
        let isLongTranslit = normalizedTranslit.count > 22
        let canAnimateToneLine = toneSegmentsCount > 0 && toneSegmentsCount <= 5 && !isLongTranslit
        let translitFont: Font = isLongTranslit
            ? .system(size: 17, weight: .semibold)
            : .system(size: 20, weight: .semibold)

        VStack(alignment: .leading, spacing: 10) {
            // top row: brand + lesson chip
            HStack(alignment: .center, spacing: 8) {
                Text("taikA")
                    .font(.custom("ONMARK Trial", size: 14))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.text)

                Spacer(minLength: 0)

                lessonTitlePill
            }

            Spacer(minLength: 0)

            // center block (FavoriteDS-like typography rhythm)
            Group {
                VStack(alignment: .leading, spacing: 8) {
                    // line 1 (accent): translit (always static; state lives below)
                    Group {
                        if translitAccent.isEmpty {
                            Text("—")
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .opacity(0.45)
                        } else if canAnimateToneLine && (translitAccent.contains("→") || translitAccent.contains("↗") || translitAccent.contains("↘") || translitAccent.contains("↑") || translitAccent.contains("↓")) {
                            PhoneticToneAnimationView(phonetic: translitAccent, playbackProgress: referencePlaybackProgress)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            TaikaSmartSpeakerPhonetic.styledText(translitAccent, font: translitFont)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .font(translitFont)
                    .lineLimit(2)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(translitAccent.isEmpty ? 0.45 : 1.0)
                    .padding(.bottom, 2)

                    // line 2 (title): RU meaning
                    Text(ruTitle.isEmpty ? "—" : ruTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(T.Colors.textPrimary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.80)
                        .opacity(ruTitle.isEmpty ? 0.45 : 1.0)
                        .padding(.top, 4)

                    // line 3 (secondary): thai script
                    Text(thaiSecondary)
                        .font(.footnote)
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .opacity(0.86)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(thaiSecondary.isEmpty ? 0.0 : 1.0)
                }
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                attemptChip
                    .layoutPriority(0)
            }

        }
        .padding(16)
        .frame(width: CardDS.Metrics.speakerPhraseCardWidth, height: CardDS.Metrics.speakerPhraseCardHeight, alignment: .topLeading)
        .background(
            Theme.Surfaces.card(round)
        )
        // .background and .overlay for hi-tech aura/glow removed
        .overlay(alignment: .bottomTrailing) {
            EmptyView()
        }
        .contentShape(round)
    }

    /// Чип режима / урока — outline-капсула в той же айдентике, что face-карточка.
    @ViewBuilder private var lessonTitlePill: some View {
        let title = (item.lessonTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let label = title.isEmpty ? "закрепление курсов" : title
        let isDictionary = label.localizedCaseInsensitiveContains("словар")
        let isFavorites = label.localizedCaseInsensitiveContains("избранн")
        HStack(spacing: 5) {
            if isDictionary {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 11, weight: .semibold))
            } else if isFavorites {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11, weight: .semibold))
            } else if !title.isEmpty {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(Theme.TextBlock.bodyMinimumScale)
        }
        .foregroundStyle(ThemeManager.shared.currentAccentFill)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous).fill(Color.clear)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(ThemeManager.shared.currentAccentFill, lineWidth: 1.2)
        )
        .allowsHitTesting(false)
    }
}

enum SpeakerPhase: Equatable {
    case idle
    case recording(start: Date)
    case analyzing
    case hint
    case feedback(score: Int, hint: String?)

    var isFeedback: Bool { if case .feedback = self { return true } else { return false } }
    var label: String {
        switch self {
        case .idle: return "нажми и говори"
        case .recording: return "запись…"
        case .analyzing: return "анализ…"
        case .hint: return "совет"
        case .feedback: return "результат"
        }
    }
}

struct SpeakerItem: Identifiable, Hashable {
    let id: UUID
    var phrase: String
    var translit: String
    var hint: String
    var lessonTitle: String? = nil
    var kindTag: String = "фраза"
    var isFavorite: Bool = false
    var isLearned: Bool = false
    var isProLocked: Bool = false
}



// MARK: - components

private struct TypingDots: View {
    var scale: CGFloat = 1.0
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            dot(0)
            dot(1)
            dot(2)
        }
        .scaleEffect(scale)
        .onAppear {
            // preview-safe: avoid repeatForever in canvas (can hang)
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            phase = 1
            guard !isPreview else { return }
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func dot(_ i: Int) -> some View {
        let delay = Double(i) * 0.18
        return Circle()
            .fill(Color.white.opacity(0.55))
            .frame(width: 5, height: 5)
            .opacity(opacity(delay: delay))
    }

    private func opacity(delay: Double) -> Double {
        // simple looping wave
        let t = (Double(phase) * 1.0 + delay).truncatingRemainder(dividingBy: 1.0)
        // peak in the middle
        let v = 1.0 - abs(t - 0.5) * 2.0
        return 0.25 + 0.55 * max(0.0, v)
    }
}



/// Shape контура для графика тона; поддерживает .trim() для прорисовки эталона в онлайне при воспроизведении.
private struct BreakdownSparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }
        let v = values
        let minV = v.min() ?? 0
        let maxV = v.max() ?? 0
        let range = maxV - minV
        let scale = range > 0 ? range : 1.0
        // Inset по горизонтали, чтобы обводка (lineCap: .round) не обрезалась по краям
        let r = rect.insetBy(dx: 2, dy: 0)
        let w = r.width
        let h = r.height
        for (i, y) in v.enumerated() {
            let x = r.minX + CGFloat(i) / CGFloat(max(1, v.count - 1)) * w
            let yNorm = 1.0 - CGFloat((y - minV) / scale)
            let point = CGPoint(x: x, y: yNorm * h + r.minY)
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        return path
    }
}

/// Прорисовка контура тона: линия «ездит» от 0→1 акцентом.
private struct AnimatedBreakdownSparkline: View {
    let values: [Double]
    var color: Color? = nil
    var lineWidth: CGFloat = 2.5
    var duration: Double = 1.0
    @State private var progress: CGFloat = 0

    var body: some View {
        let strokeStyle: AnyShapeStyle = {
            if let color {
                return AnyShapeStyle(color)
            }
            return AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        }()
        BreakdownSparklineShape(values: values)
            .trim(from: 0, to: progress)
            .stroke(strokeStyle, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .onAppear {
                progress = 0
                withAnimation(.easeInOut(duration: duration)) {
                    progress = 1
                }
            }
            .onChange(of: values.count) { _, _ in
                progress = 0
                withAnimation(.easeInOut(duration: duration)) {
                    progress = 1
                }
            }
    }
}

/// Счётчик очков: анимированно заполняется в акцентном цвете.
private struct SpeakerCountingScore<S: ShapeStyle>: View {
    let value: Int
    let font: Font
    let color: S
    var suffix: String = ""
    @State private var displayed: Int = 0

    var body: some View {
        Text("\(displayed)\(suffix)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear { runCount(to: value) }
            .onChange(of: value) { _, newValue in
                runCount(to: newValue)
            }
    }

    private func runCount(to target: Int) {
        displayed = 0
        let clamped = max(0, target)
        guard clamped > 0 else { return }
        let steps = min(clamped, 28)
        let stepDuration = 0.85 / Double(steps)
        for i in 1...steps {
            let next = Int(round(Double(clamped) * Double(i) / Double(steps)))
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeOut(duration: 0.06)) {
                    displayed = next
                }
            }
        }
    }
}

/// Линия в реальном времени по уровню записи (график «Ты сказал» во время «Записать ещё раз»).
private struct BreakdownLiveMeterLine: View {
    let liveMeter: Double
    @State private var samples: [Double] = []

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            path(in: CGRect(x: 0, y: 0, width: w, height: h))
                .stroke(AnyShapeStyle(ThemeManager.shared.currentAccentFill), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .onAppear { samples = [] }
        .onChange(of: liveMeter) { _, new in
            samples.append(max(0, min(1, new)))
            if samples.count > 100 { samples.removeFirst() }
        }
    }

    private func path(in rect: CGRect) -> Path {
        var path = Path()
        guard samples.count >= 2 else {
            if let v = samples.first {
                let y = rect.height * (1 - CGFloat(v))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y))
            }
            return path
        }
        let step = rect.width / CGFloat(max(1, samples.count - 1))
        for (i, v) in samples.enumerated() {
            let x = CGFloat(i) * step
            let y = rect.height * (1 - CGFloat(v))
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}

private struct MiniWaveform: View {
    let meter: Double
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            bar(0)
            bar(1)
            bar(2)
            bar(3)
            bar(4)
            bar(5)
        }
        .frame(height: 14)
        .onAppear {
            // preview-safe: avoid repeatForever in canvas (can hang)
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            phase = 1
            guard !isPreview else { return }
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(_ i: Int) -> some View {
        let base: CGFloat = 3
        let amp = CGFloat(max(0.0, min(1.0, meter)))
        let wobble = 0.25 + 0.75 * wave(i)
        let h = base + (12 * amp * wobble)

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
            .frame(width: 3, height: h)
            .opacity(0.85)
    }

    private func wave(_ i: Int) -> CGFloat {
        let t = (Double(phase) + Double(i) * 0.12).truncatingRemainder(dividingBy: 1.0)
        // triangle-ish wave
        let v = 1.0 - abs(t - 0.5) * 2.0
        return CGFloat(max(0.0, v))
    }
}

// MARK: - Conversation live stage visuals

private struct ConversationLiveAmbientGlow: View {
    let accent: Color
    let intense: Bool

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    accent.opacity(intense ? 0.28 : 0.16),
                    accent.opacity(0.06),
                    Color.clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 280
            )
            .blur(radius: 30)
            .offset(y: -20)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                center: UnitPoint(x: 0.3, y: 0.25),
                startRadius: 0,
                endRadius: 220
            )
            .blur(radius: 18)
        }
        .allowsHitTesting(false)
    }
}

private struct ConversationVoiceOrb: View {
    enum Mode {
        case listening
        case practice
        case processing
    }

    let meter: Double
    let mode: Mode
    let accent: Color

    @State private var spin: Double = 0

    private var level: CGFloat {
        CGFloat(max(0, min(1, meter)))
    }

    var body: some View {
        let brand = ThemeManager.shared.currentAccentFill
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let reactive: CGFloat = {
                switch mode {
                case .listening, .practice:
                    return 0.92 + level * 0.28 + 0.04 * CGFloat(sin(t * 6))
                case .processing:
                    return 1.0 + 0.06 * CGFloat(sin(t * 2.2))
                }
            }()

            ZStack {
                Circle()
                    .fill(brand.opacity(mode == .processing ? 0.22 : 0.16 + Double(level) * 0.18))
                    .blur(radius: 22)
                    .scaleEffect(reactive * 1.18)

                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(
                            brand.opacity(0.55 - Double(i) * 0.12),
                            lineWidth: mode == .processing ? 1.4 : 1.8
                        )
                        .frame(width: 118 + CGFloat(i) * 28, height: 118 + CGFloat(i) * 28)
                        .scaleEffect(reactive * (1.0 + CGFloat(i) * 0.02))
                        .rotationEffect(.degrees(spin + Double(i) * 40 + (mode == .processing ? t * 28 : t * 12)))
                        .opacity(0.85 - Double(i) * 0.15)
                }

                Circle()
                    .fill(Color.black.opacity(0.42))
                    .frame(width: 96, height: 96)
                    .overlay(
                        Circle()
                            .stroke(brand.opacity(0.45), lineWidth: 1.4)
                    )
            }
        }
        .onAppear {
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            guard !isPreview else { return }
            withAnimation(.linear(duration: mode == .processing ? 8 : 14).repeatForever(autoreverses: false)) {
                spin = 360
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ConversationLiveWaveRibbon: View {
    let meter: Double
    /// Игнорируется: всегда бренд-градиент (не solid tint).
    var accent: Color = .clear
    private let barCount = 28

    var body: some View {
        let fill = ThemeManager.shared.currentAccentFill
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let amp = max(0.12, min(1.0, meter))
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { i in
                    let wave = 0.32 + 0.68 * abs(sin(t * 7.2 + Double(i) * 0.42))
                    let h = 5 + 30 * amp * wave * (i % 3 == 0 ? 1.05 : (i % 2 == 0 ? 0.82 : 0.68))
                    Capsule(style: .continuous)
                        .fill(fill)
                        .opacity(0.55 + 0.45 * amp)
                        .frame(width: 3.5, height: h)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityHidden(true)
    }
}

private struct ConversationLiveProcessTicks: View {
    var body: some View {
        let fill = ThemeManager.shared.currentAccentFill
        TimelineView(.animation(minimumInterval: 0.28)) { timeline in
            let step = Int(timeline.date.timeIntervalSinceReferenceDate / 0.28) % 5
            HStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { i in
                    let active = i == step
                    Circle()
                        .fill(fill)
                        .opacity(active ? 1 : 0.28)
                        .frame(width: active ? 8 : 5, height: active ? 8 : 5)
                        .shadow(color: ThemeManager.shared.currentAccentTintColor.opacity(active ? 0.55 : 0), radius: active ? 6 : 0)
                }
            }
        }
        .accessibilityHidden(true)
    }
}


private struct SpeakerPlayerWave: View {
    let active: Bool
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            HStack(alignment: .center, spacing: 4) {
                waveBar(h: h, i: 0)
                waveBar(h: h, i: 1)
                waveBar(h: h, i: 2)
                waveBar(h: h, i: 3)
                waveBar(h: h, i: 4)
                waveBar(h: h, i: 5)
                waveBar(h: h, i: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            // preview-safe: avoid repeatForever in canvas (can hang)
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            phase = 0
            guard !isPreview else { return }
            withAnimation(.linear(duration: active ? 0.75 : 1.15).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .onChange(of: active) { _ in
            // preview-safe: avoid repeatForever in canvas (can hang)
            let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            guard !isPreview else { return }
            phase = 0
            withAnimation(.linear(duration: active ? 0.75 : 1.15).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .accessibilityHidden(true)
    }

    private func waveBar(h: CGFloat, i: Int) -> some View {
        let t = (Double(phase) + Double(i) * 0.13).truncatingRemainder(dividingBy: 1.0)
        let v = 1.0 - abs(t - 0.5) * 2.0
        let amp = CGFloat(max(0.0, v))
        let base: CGFloat = max(3.0, h * 0.20)
        let maxExtra: CGFloat = max(8.0, h * 0.75)
        let barH = base + maxExtra * (active ? amp : amp * 0.45)

        let fillColor: Color = active
            ? PD.ColorToken.text
            : PD.ColorToken.textSecondary.opacity(0.55)

        return RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(fillColor)
            .frame(width: 3.5, height: barH)
    }
}


// MARK: - previews

// MARK: - previews

#if DEBUG
private struct SpeakerDSStoryPreview: View {
    enum StoryPhase: String, CaseIterable, Identifiable {
        case idle = "idle"
        case recording = "record"
        case analyzing = "analyze"
        case feedback = "result"

        var id: String { rawValue }
    }

    @State private var storyPhase: StoryPhase = .feedback

    // For preview: always use the same currentItem as required in instructions
    private let demoCurrent = SpeakerItem(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        phrase: "ขอบคุณครับ",
        translit: "кхоп-кхун-крап",
        hint: "спасибо",
        lessonTitle: "урок 5",
        kindTag: "фраза",
        isFavorite: false,
        isLearned: false,
        isProLocked: false
    )

    // Replace translit for "ขอบคุณครับ" to "кхоп-кхун-крап" in demoItems
    private let demoItems: [SpeakerItem] = [
        SpeakerItem(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            phrase: "ใช้ได้",
            translit: "чай дай↘︎",
            hint: "норм, пойдёт",
            lessonTitle: "урок 2",
            kindTag: "фраза",
            isFavorite: true,
            isLearned: false,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            phrase: "สวัสดีครับ",
            translit: "са-ва-ди-крап",
            hint: "привет",
            lessonTitle: "урок 5",
            kindTag: "фраза",
            isFavorite: false,
            isLearned: true,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            phrase: "ขอบคุณครับ",
            translit: "кхоп-кхун-крап",
            hint: "спасибо",
            lessonTitle: "урок 5",
            kindTag: "фраза",
            isFavorite: false,
            isLearned: false,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            phrase: "ไม่เป็นไร",
            translit: "май-пен-рай",
            hint: "ничего страшного",
            lessonTitle: "урок 3",
            kindTag: "фраза",
            isFavorite: true,
            isLearned: false,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            phrase: "ขอโทษครับ",
            translit: "кхо-тхот-крап",
            hint: "извини",
            lessonTitle: "урок 4",
            kindTag: "фраза",
            isFavorite: false,
            isLearned: false,
            isProLocked: false
        ),
        SpeakerItem(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            phrase: "ไปไหน",
            translit: "пай-най?",
            hint: "куда идёшь?",
            lessonTitle: "урок 6",
            kindTag: "фраза",
            isFavorite: false,
            isLearned: true,
            isProLocked: false
        )
    ]

    // Always use .feedback(68, "долгий звук ай") for preview phase argument
    private var phase: SpeakerPhase {
        switch storyPhase {
        case .idle:
            return .idle
        case .recording:
            return .recording(start: Date())
        case .analyzing:
            return .analyzing
        case .feedback:
            return .feedback(score: 68, hint: "долгий звук ай")
        }
    }

    private var heardThai: String? {
        switch storyPhase {
        case .feedback:
            return "ฟинดีนะ"
        default:
            return nil
        }
    }

    // Always supply heardTranslitText: "фин-ди-на"
    private var heardPhonetic: String? {
        switch storyPhase {
        case .feedback:
            return "фин-ди-на"
        default:
            return nil
        }
    }

    private var recordingPartialThai: String? {
        switch storyPhase {
        case .recording:
            return ""
        default:
            return nil
        }
    }

    private var recordingPartialTranslit: String? {
        switch storyPhase {
        case .recording:
            // demo: partial should match the currently selected target (not a constant)
            return "чай дай"
        default:
            return nil
        }
    }

    private var meter: Double {
        switch storyPhase {
        case .recording:
            return 0.42
        default:
            return 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // phase switcher (preview-only)
            Picker("phase", selection: $storyPhase) {
                ForEach(StoryPhase.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(T.Colors.backgroundPrimary)

            SpeakerDSRoot(
                preview: .init(
                    current: demoCurrent,
                    items: demoItems,
                    activeFilterId: SpeakerMode.currentMode.id,
                    phase: phase,
                    heardThai: heardThai,
                    heardRU: storyPhase == .feedback ? "мне хорошо" : nil,
                    heardTranslit: "фин-ди-на",
                    heardConfidence: 0,
                    taikaHints: storyPhase == .feedback ? [
                        "норм",
                        "давай медленнее и чётче — будет лучше"
                    ] : [],
                    recordingMeter: meter,
                    recordingPartialThai: recordingPartialThai,
                    recordingPartialTranslit: recordingPartialTranslit,
                    lastAttempt: storyPhase == .feedback ? URL(fileURLWithPath: "/tmp/speaker_preview_attempt.m4a") : nil,
                    attemptCount: storyPhase == .feedback ? 4 : (storyPhase == .recording ? 1 : 0),
                    lastPlayed: storyPhase == .feedback ? .attempt : .none
                )
            )
        }
        .environmentObject(ThemeManager.shared)
    }
}

#Preview("speaker ds — story") {
    SpeakerDSStoryPreview()
}
#endif
