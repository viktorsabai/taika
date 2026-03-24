//
//  SpeakerDS.swift
//  taika
//
//  first DS scaffold for tAIka (speaker) — visual only, no integrations
//  architecture: safeAreaInset header, tokens background, no local whites
//

import SwiftUI
import Foundation

// MARK: - tokens shortcuts
private typealias T = Theme

// MARK: - focus rect preference (for result spotlight)
private struct SpeakerActiveCardAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}


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
        /// UI mode: training (cards, filters) vs conversation (mic only).
        let speakerUIMode: SpeakerManager.SpeakerUIMode
        let onSpeakerUIModeChange: (SpeakerManager.SpeakerUIMode) -> Void
        /// Conversation mode: play TTS of the Thai result.
        let onPlayConversationTTS: () -> Void
        /// Conversation mode: reset and record again ("Повтори на тайском" or new phrase).
        let onConversationRepeat: () -> Void
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
        /// Conversation mode: start pronunciation check (record Thai, then score).
        let onConversationRepeatAndCheck: () -> Void
        /// Smart Speaker: politeness not selected yet (krap/kha).
        let smartSpeakerNeedsPoliteness: Bool
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
    // reserve vertical space so the layout doesn't jump between phases
    // but don't keep a big “air gap” while recording/analyzing
    private let taikaBubbleHeightVisible: CGFloat = 96
    private let taikaBubbleHeightHidden: CGFloat = 0

    private var taikaBubbleReservedHeight: CGFloat {
        // bubble removed from result — no reserved space
        return taikaBubbleHeightHidden
    }

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
                .fill(Color.white.opacity(0.03))
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
        speakerUIMode: SpeakerManager.SpeakerUIMode = .training,
        onSpeakerUIModeChange: @escaping (SpeakerManager.SpeakerUIMode) -> Void = { _ in },
        onPlayConversationTTS: @escaping () -> Void = {},
        onConversationRepeat: @escaping () -> Void = {},
        conversationRemainingToday: Int = 3,
        conversationRecordingElapsed: TimeInterval = 0,
        conversationRecordingMaxDuration: TimeInterval = 45,
        conversationCanRecord: Bool = true,
        conversationExpectedThai: String? = nil,
        conversationExpectedTranslitForFeedback: String? = nil,
        onConversationRepeatAndCheck: @escaping () -> Void = {},
        smartSpeakerNeedsPoliteness: Bool = false,
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
            speakerUIMode: speakerUIMode,
            onSpeakerUIModeChange: onSpeakerUIModeChange,
            onPlayConversationTTS: onPlayConversationTTS,
            onConversationRepeat: onConversationRepeat,
            conversationRemainingToday: conversationRemainingToday,
            conversationRecordingElapsed: conversationRecordingElapsed,
            conversationRecordingMaxDuration: conversationRecordingMaxDuration,
            conversationCanRecord: conversationCanRecord,
            conversationExpectedThai: conversationExpectedThai,
            conversationExpectedTranslitForFeedback: conversationExpectedTranslitForFeedback,
            onConversationRepeatAndCheck: onConversationRepeatAndCheck,
            smartSpeakerNeedsPoliteness: smartSpeakerNeedsPoliteness,
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
            lessonTitle: external?.lessonTitleForLessonId?(cur.lessonId),
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

    /// Высота верхнего блока (карусель / расшифровка), чтобы вёрстка не скакала при смене режима и при появлении текста.
    private let speakerTopContentHeight: CGFloat = 208

    /// Одна вёрстка: верх = расшифровка (карусель или русский), разделитель, панель, низ = перевод + кнопки (как в обычном спикере).
    private var unifiedSpeakerBody: some View {
        let padH = Theme.Layout.pageHorizontal
        let gap = Theme.Layout.sectionGap
        return VStack(spacing: 0) {
            Group {
                if speakerUIMode == .conversation {
                    conversationTopContent
                        .frame(maxWidth: .infinity)
                } else {
                    topCarousel
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(minHeight: speakerTopContentHeight)
            .padding(.top, gap)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.top, gap)
                .padding(.horizontal, padH)

            Group {
                if speakerUIMode == .conversation {
                    conversationPlayerStrip
                } else {
                    speakerPlayerPanel
                }
            }
            .padding(.top, gap)
            .padding(.horizontal, padH)

            if speakerUIMode == .conversation && conversationHasResult {
                Spacer(minLength: 0)
            }

            Group {
                if speakerUIMode == .conversation {
                    conversationBottomSection
                } else {
                    switch phase {
                    case .feedback:
                        simpleResultBlock
                            .transition(.opacity)
                    default:
                        idleHelperHint
                    }
                }
            }
            .padding(.top, gap)
            .padding(.horizontal, padH)
            Spacer(minLength: 0)
        }
    }

    /// Умный спикер: распознавание сверху (спиннер + текст), перевод снизу. Один стиль — разное расположение.
    @ViewBuilder private var conversationTopContent: some View {
        if case .feedback = phase {
            let ru = (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !ru.isEmpty {
                Text(ru)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else {
                conversationFeedbackTopPlaceholder
            }
        } else if phase == .analyzing {
            // Распознавание: спиннер + «распознаю» сверху
            if external?.heardRU?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                conversationLoadingBlock(label: "распознаю…")
            } else {
                // Переводчик: русский сверху, спиннер — снизу
                Text(external?.heardRU ?? "")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        } else if conversationHasResult {
            Text(external?.heardRU ?? "")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: 8) {
                conversationRussianLine
                Text("Нажми и говори")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Индикатор загрузки (спиннер + текст). Один стиль: сверху при распознавании, снизу при переводе.
    @ViewBuilder private func conversationLoadingBlock(label: String) -> some View {
        TaikaLoadingView(label: label, compact: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    @ViewBuilder private var conversationFeedbackTopPlaceholder: some View {
        Color.clear
            .frame(minHeight: speakerTopContentHeight)
    }

    /// Умный спикер: низ — кнопки, под ними: загрузка («перевожу…») или результат (фонетика + тайский).
    @ViewBuilder private var conversationBottomSection: some View {
        if case .feedback = phase {
            conversationFeedbackBlock
                .transition(.opacity)
        } else if phase == .analyzing, external?.heardRU?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            conversationLoadingBlock(label: "перевожу…")
                .transition(.opacity)
        } else if conversationHasResult {
            conversationResultButtonsOnly
                .transition(.opacity)
        } else if phase == .hint,
                  !(external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (external?.heardThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !taikaHints.isEmpty {
            VStack(spacing: 12) {
                Text(taikaHints.joined(separator: " "))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Попробовать ещё раз") {
                    external?.onClearConversationResult?()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .transition(.opacity)
        } else {
            EmptyView()
        }
    }

    /// Умный спикер: перевод сверху, кнопки отдельно внизу экрана.
    @ViewBuilder private var conversationResultButtonsOnly: some View {
        let phonetic = (external?.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let thai = (external?.heardThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ru = (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let canAddToDict = !thai.isEmpty && !phonetic.isEmpty
        let itemGap = Theme.Layout.Section.itemGap
        VStack(spacing: 0) {
            // Блок перевода (фонетика со стрелками + тайский)
            VStack(spacing: itemGap) {
                if !phonetic.isEmpty {
                    PhoneticWithColoredArrowsView(phonetic: phonetic, font: .system(size: 22, weight: .semibold))
                        .multilineTextAlignment(.center)
                }
                if !thai.isEmpty {
                    Text(thai)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 24)

            // Разделитель перед кнопками
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 16)

            // Кнопки внизу экрана
            VStack(spacing: 10) {
                if canAddToDict {
                    Button {
                        FavoriteManager.shared.addSmartSpeakerCard(ru: ru, thai: thai, phonetic: phonetic)
                    } label: {
                        HStack(spacing: Theme.Layout.iconGap) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Добавить в мой словарь")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(PD.ColorToken.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
                        .overlay(Capsule(style: .continuous).stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    external?.onConversationRepeatAndCheck()
                } label: {
                    HStack(spacing: Theme.Layout.iconGap) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Повторить и проверить")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                }
                .buttonStyle(.plain)
                if external?.onClearConversationResult != nil {
                    Button {
                        external?.onClearConversationResult?()
                    } label: {
                        Text("Сбросить результат")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }


    private var smartSpeakerPolitenessOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Как говорить вежливо?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Text("Выбери хвостик для умного спикера. Можно поменять позже.")
                    .font(.caption)
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    Button { external?.onSetSmartSpeakerPoliteness("male") } label: {
                        Text("Мужской: кхрап")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    Button { external?.onSetSmartSpeakerPoliteness("female") } label: {
                        Text("Женский: кха")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    Button { external?.onSetSmartSpeakerPoliteness("kathoey") } label: {
                        Text("Катой: как женский")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(PD.ColorToken.text)
            }
            .padding(16)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.35)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
    }

    /// Conversation mode: Russian text above mic — live hint or recognized phrase. При «Повторить и проверить» фраза не пропадает.
    @ViewBuilder private var conversationRussianLine: some View {
        let isRecording: Bool = {
            if case .recording = phase { return true }
            return false
        }()
        let ruText = (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let isRepeatCheck = (conversationExpectedThai != nil)
        if isRepeatCheck, !ruText.isEmpty {
            VStack(spacing: 6) {
                Text(ruText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                    .multilineTextAlignment(.center)
                if isRecording {
                    Text(recordingPartialRU.isEmpty ? "Говорите…" : recordingPartialRU)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else if isRecording {
            Text(recordingPartialRU.isEmpty ? "Говорите…" : recordingPartialRU)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .multilineTextAlignment(.center)
        } else if !ruText.isEmpty {
            Text(ruText)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .multilineTextAlignment(.center)
        }
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

    /// В диалоге та же идентичность, что и в практике: [озвучить эталон] [микрофон] [моя запись].
    private var conversationPlayerStrip: some View {
        let isRecording: Bool = {
            if case .recording = phase { return true }
            return false
        }()
        let isAnalyzing = (phase == .analyzing)
        let isFeedback = phase.isFeedback
        let canRecord = external?.conversationCanRecord ?? true
        let elapsed = external?.conversationRecordingElapsed ?? 0
        let maxDuration = max(0.1, external?.conversationRecordingMaxDuration ?? 45)
        let progress = isRecording ? min(1, elapsed / maxDuration) : 0
        let canPlayRef: Bool = {
            if conversationExpectedThai != nil { return true }
            let thai = (external?.heardThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return !thai.isEmpty && !isAnalyzing
        }()
        let canPlayAttempt = (external?.lastAttempt != nil)
        return HStack(spacing: 18) {
            Spacer(minLength: 0)
            // Озвучить эталон (что надо было)
            Button {
                guard canPlayRef else { return }
                external?.onPlayConversationTTS()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        canPlayRef
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        : AnyShapeStyle(Color.white.opacity(0.25))
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canPlayRef)
            // Микрофон / стоп / повторить
            ZStack {
                if progress > 0 {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ThemeManager.shared.currentAccentFill, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                }
                Button {
                    if isRecording {
                        external?.onMicTap()
                    } else if isFeedback {
                        external?.onConversationRepeat()
                    } else {
                        external?.onMicTap()
                    }
                } label: {
                    Image(systemName:
                            isRecording
                            ? "stop.fill"
                            : (isFeedback ? "arrow.clockwise" : "mic.fill")
                    )
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(ThemeManager.shared.currentAccentFill))
                    .foregroundColor(.black)
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing || (!canRecord && !isFeedback))
            }
            .frame(width: 96, height: 96)
            // Моя запись (что сказал) — тот же стиль, что и «озвучить»: иконка цветом, активна только после записи
            Button {
                guard canPlayAttempt else { return }
                external?.onPlayAttempt()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        canPlayAttempt
                        ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                        : AnyShapeStyle(Color.white.opacity(0.25))
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canPlayAttempt)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    /// Conversation mode: single centered mic — заменён на conversationPlayerStrip (та же идентичность, что в практике).
    private var conversationMicPanel: some View {
        conversationPlayerStrip
    }

    /// Conversation mode result: транслит + тайский, одна CTA — обводочная «Повторить и проверить» (озвучить эталон уже в полоске над микрофоном).
    @ViewBuilder private var conversationResultBlock: some View {
        let phonetic = (external?.heardTranslit ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let thai = (external?.heardThai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let ru = (external?.heardRU ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let canAddToDict = !thai.isEmpty && !phonetic.isEmpty
        VStack(spacing: 16) {
            if !phonetic.isEmpty {
                Text(phonetic)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
            }
            if !thai.isEmpty {
                Text(thai)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if canAddToDict {
                Button {
                    FavoriteManager.shared.addSmartSpeakerCard(ru: ru, thai: thai, phonetic: phonetic)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Добавить в мой словарь")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(PD.ColorToken.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule(style: .continuous).fill(Color.white.opacity(0.08)))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Button {
                external?.onConversationRepeatAndCheck()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Повторить и проверить")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Capsule(style: .continuous).fill(Color.clear))
                .overlay(Capsule(style: .continuous).stroke(ThemeManager.shared.currentAccentFill, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    /// Conversation mode: feedback after "Повторить и проверить" — тот же блок, что и в практике.
    @ViewBuilder private var conversationFeedbackBlock: some View {
        if case .feedback(let score, _) = phase {
            let scoreToShow = external?.displayScore ?? score
            let expected = (external?.conversationExpectedTranslitForFeedback ?? "")
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
        }
    }

    public var body: some View {
        ZStack {
            T.Colors.backgroundPrimary.ignoresSafeArea()

            unifiedSpeakerBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if speakerUIMode == .conversation && (external?.smartSpeakerNeedsPoliteness == true) {
                smartSpeakerPolitenessOverlay
                    .transition(.opacity)
            }

            // Breakdown overlay (extracted to avoid type-checker timeout)
            if effectiveShowBreakdown {
                speakerBreakdownOverlayZStack(
                    onDismiss: {
                        breakdownSnapshotExpected = ""
                        breakdownSnapshotPhraseLabel = ""
                        breakdownSnapshotScore = nil
                        setEffectiveShowBreakdown(false)
                    },
                    snapshotExpected: $breakdownSnapshotExpected,
                    snapshotPhraseLabel: $breakdownSnapshotPhraseLabel,
                    snapshotScore: $breakdownSnapshotScore
                )
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: phase.isFeedback)
        .onChange(of: extSelectedId) { newValue in
            if let v = newValue { localSelectedId = v }
        }
        .onChange(of: activeFilterId) { _ in
            // reset fallback selection when switching modes
            localSelectedId = nil
        }
        .task(id: helperHasInteracted) {
            // preview защитный рантайм: canvas часто пересоздаёт view и может зависнуть на long-running task.
            // в превью — просто показываем строку и выходим.
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

            // ждём idle ограниченно по времени, чтобы не подвешивать UI
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
        .safeAreaInset(edge: .top) { topChrome }
        // bottom CTA removed: speaker is navigated via the player console in all modes
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var topTaikaBubble: some View {
        Color.clear
    }

    /// Единый блок результата: контент сверху, кнопки внизу экрана (как в умном спикере).
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
        VStack(alignment: .leading, spacing: 0) {
            // Контент сверху: счёт + сравнение
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .contentTransition(.numericText())
                    Text(score >= 80 ? "почти идеально" : "есть неточности")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                }
                .frame(maxWidth: .infinity)
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("нужно было")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                        highlightedExpectedText(userText: userDisplay, expected: expectedDisplay)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ты сказал")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                        highlightedUserText(userText: userDisplay, expected: expectedDisplay)
                            .font(.system(size: 20, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Кнопки внизу (без Spacer — меньше разрыв между блоками)
            VStack(spacing: 12) {
                Button(action: onBreakdown) {
                    Text("получить разбор")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
                if let label = secondaryLabel, let action = onSecondary {
                    Button(action: action) {
                        Text(label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    private func highlightedUserText(userText: String, expected: String) -> some View {
        if !isBreakdownExpanded {
            return Text(userText)
                .foregroundStyle(PD.ColorToken.text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let userParts = userText.split(separator: "-").map(String.init)
            let expectedParts = expected.split(separator: "-").map(String.init)

            // Build a single Text via concatenation instead of HStack
            // so SwiftUI can wrap lines naturally without clipping.
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
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func highlightedExpectedText(userText: String, expected: String) -> some View {
        // "нужно было" — эталон со стрелками тонов. Цвет как в спикере/степе.
        Group {
            if expected.isEmpty {
                Text("—")
                    .foregroundStyle(PD.ColorToken.textSecondary)
            } else {
                PhoneticWithColoredArrowsView(phonetic: expected, font: .system(size: 20, weight: .semibold))
            }
        }
        .multilineTextAlignment(.leading)
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
    }

    /// Одна карточка слога в разборе (цвет по score, стрелки тонов, мини-график).
    private struct BreakdownSyllableRowView: View {
        let row: SyllableRow
        var body: some View {
            SpeakerDSRoot.breakdownSyllableRowContent(row: row)
        }
    }

    private static func breakdownSyllableRowContent(row: SyllableRow) -> some View {
        let isGreen = row.score >= 90
        let isYellow = row.score >= 50 && row.score < 90
        let rowColor: Color = isGreen ? Color.green.opacity(0.35) : (isYellow ? Color.orange.opacity(0.35) : Color.red.opacity(0.35))
        let strokeColor: Color = isGreen ? Color.green.opacity(0.5) : (isYellow ? Color.orange.opacity(0.5) : Color.red.opacity(0.5))
        let toneMatch = (row.toneExpected.map { $0 == row.toneActual } ?? true)
        let expectedArrow = toneToArrow(row.toneExpected)
        let actualArrow = toneToArrow(row.toneActual)
        return HStack(alignment: .top, spacing: 10) {
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
        )
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

    /// Цвет оценки по дорожке: зелёный 90–100, жёлтый 50–89, красный 0–49.
    private static func scoreBandColor(_ score: Int) -> Color {
        if score >= 90 { return .green }
        if score >= 50 { return .orange }
        return .red
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

    /// Оверлей «разбор»: затемнение + карточка. Снимок эталона при открытии — слоги не меняются после ответа API.
    @ViewBuilder private func speakerBreakdownOverlayZStack(
        onDismiss: @escaping () -> Void,
        snapshotExpected: Binding<String>,
        snapshotPhraseLabel: Binding<String>,
        snapshotScore: Binding<Int?>
    ) -> some View {
        let userText = heardTranslitText.isEmpty ? "—" : heardTranslitText
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
            onDismiss: onDismiss,
            onRecordAgain: onRecordAgainValue,
            onStopRecordingFromBreakdown: external?.onStopRecordingFromBreakdown,
            onPlayReference: external?.onPlayReference,
            onPlayAttempt: external?.onPlayAttempt
        )

        ZStack {
            Color.black.opacity(0.55)
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
        onDismiss: @escaping () -> Void,
        onRecordAgain: (() -> Void)? = nil,
        onStopRecordingFromBreakdown: (() -> Void)? = nil,
        onPlayReference: (() -> Void)? = nil,
        onPlayAttempt: (() -> Void)? = nil
    ) -> AnyView {
        let showRecordingInPlace = isRecordingFromBreakdown && breakdownPhase == .recording
        let headerView: AnyView = AnyView(
            HStack(spacing: 8) {
                Text("разбор")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.text)
                Spacer()
                if showRecordingInPlace {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("Запись")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { onDismiss() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }
        )

        let scrollView: AnyView = AnyView(
            Group {
                ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    if !phraseLabel.isEmpty || displayScore >= 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .center, spacing: 8) {
                                if !phraseLabel.isEmpty {
                                    Text(phraseLabel)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Text("\(displayScore)%")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Self.scoreBandColor(displayScore))
                            }
                            if let tone = toneScore {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Текст \(textScore)% · Тон \(tone)%. Общая = минимум из них.")
                                        .font(.caption2)
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                    if displayScore == textScore && tone > textScore {
                                        Text("Сейчас общая оценка ограничена распознаванием фразы.")
                                            .font(.caption2)
                                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                                    }
                                }
                            } else if !syllableFeedback.isEmpty {
                                Text("Ниже — оценка по тону слогов (высота голоса).")
                                    .font(.caption2)
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ты сказал")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PD.ColorToken.textSecondary)
                            Text(userText)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(PD.ColorToken.text)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 4)
                            if let playAttempt = onPlayAttempt {
                                Button(action: playAttempt) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(PD.ColorToken.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Rectangle()
                            .fill(PD.ColorToken.textSecondary.opacity(0.3))
                            .frame(width: 1)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("нужно было")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PD.ColorToken.textSecondary)
                            PhoneticWithColoredArrowsView(phonetic: Self.phoneticDisplayWithoutHyphens(expected), font: .subheadline.weight(.medium))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.trailing, 4)
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )

                    if !syllableFeedback.isEmpty || showRecordingInPlace {
                        breakdownPhraseGraphSection(
                            expected: expected,
                            syllableFeedback: syllableFeedback,
                            isRecordingFromBreakdown: showRecordingInPlace,
                            recordingMeter: recordingMeter,
                            referenceRevealProgress: referenceRevealProgress
                        )
                    }
                    if !syllableFeedback.isEmpty {
                        breakdownSyllableRowsSection(expected: expected, syllableFeedback: syllableFeedback)
                    }

                    // Одно заключение в стиле Taika FM: без дублирования фразы/оценки, без блока «заметки».
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
                .padding(.horizontal, 6)
            }
            .frame(minHeight: 0, maxHeight: .infinity)
            }
        )

        let footerView: AnyView = AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Divider().padding(.top, 4)
                if showRecordingInPlace, let stop = onStopRecordingFromBreakdown {
                    Button(action: stop) {
                        HStack {
                            Spacer()
                            Text("Стоп")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Capsule(style: .continuous).fill(Color.red.opacity(0.85)))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                } else if onRecordAgain != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { onRecordAgain?() }
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                            Text("Записать ещё раз")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(ThemeManager.shared.currentAccentFill.opacity(0.25))
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(ThemeManager.shared.currentAccentFill.opacity(0.5), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { onDismiss() }
                } label: {
                    HStack {
                        Spacer()
                        Text("Понял")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                            )
                    )
                    .foregroundStyle(PD.ColorToken.text)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        )

        let card = VStack(alignment: .leading, spacing: 12) {
            headerView
            scrollView
            footerView
        }
        .padding(24)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                )
        )

        return AnyView(card)
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

    /// Два графика на всю фразу: эталон и пользователь. Ось X — подписи слогов, чтобы было видно, где ошибка.
    private func breakdownPhraseGraphSection(
        expected: String,
        syllableFeedback: [SpeakerManager.SyllableFeedback],
        isRecordingFromBreakdown: Bool,
        recordingMeter: Double,
        referenceRevealProgress: Double
    ) -> some View {
        let userContour = syllableFeedback.flatMap { $0.f0Contour ?? [] }
        let referenceContour = syllableFeedback.flatMap { Self.referenceSegmentForTone($0.toneExpected) }
        let showReference = referenceContour.count >= 2
        let showUser = isRecordingFromBreakdown || userContour.count >= 2
        // Ось X всегда по разбираемой фразе: все слоги из эталона (expected), а не по ответу API.
        let chunks = Self.translitChunksForSyllables(expected)
        let syllableLabels = chunks.map { Self.syllableLabelWithoutArrows($0) }
        guard showReference || showUser else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                Text("График тона по фразе")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                if showReference {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Эталон")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                        BreakdownSparklineShape(values: referenceContour)
                            .trim(from: 0, to: referenceRevealProgress)
                            .stroke(Color.gray.opacity(0.95), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .frame(height: 28)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ты сказал")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                    if isRecordingFromBreakdown {
                        BreakdownLiveMeterLine(liveMeter: recordingMeter)
                            .frame(height: 28)
                    } else if userContour.count >= 2 {
                        Self.breakdownPhraseSparkline(values: userContour, isReference: false)
                            .frame(height: 28)
                    } else {
                        EmptyView().frame(height: 28)
                    }
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
                    .padding(.top, 6)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
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

    /// Блок «по слогам» — только слоги из API; подписи без стрелок (только текст слога: кхоп, кхун, мак).
    private func breakdownSyllableRowsSection(expected: String, syllableFeedback: [SpeakerManager.SyllableFeedback]) -> some View {
        let translitChunks = Self.translitChunksForSyllables(expected)
        let rows: [SyllableRow] = syllableFeedback.enumerated().map { index, s in
            let rawLabel = index < translitChunks.count ? translitChunks[index] : s.syllable
            let label = Self.syllableLabelWithoutArrows(rawLabel)
            let toneMatch = (s.toneExpected != nil && s.toneActual != nil) ? (s.toneExpected == s.toneActual) : nil
            return SyllableRow(
                label: label,
                score: s.score,
                comment: Self.localizedToneFeedback(s.comment, score: s.score, toneMatch: toneMatch),
                toneExpected: s.toneExpected,
                toneActual: s.toneActual,
                f0Contour: s.f0Contour
            )
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

    /// Заглушка разбора по слогам в модалке «разбор»: показывает слоги эталона и пояснение, что оценка тона/звука будет позже.
    @ViewBuilder private func breakdownSyllableStubSection(expected: String) -> some View {
        let syllables = Self.syllablesFromTranslit(expected)
        VStack(alignment: .leading, spacing: 10) {
            Text("по слогам")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .opacity(0.78)

            if syllables.isEmpty {
                Text("эталон без разбиения на слоги (ожидаем оценку тона и звука)")
                    .font(.footnote)
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .opacity(0.85)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(syllables.enumerated()), id: \.offset) { _, syllable in
                        HStack(alignment: .top, spacing: 12) {
                            Text(syllable)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(PD.ColorToken.text)
                                .frame(minWidth: 56, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("ожидаем оценку")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                                Text("тон и звук слога будут оцениваться (5 тонов тайского — подключим позже)")
                                    .font(.caption2)
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                                    .opacity(0.8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                    }
                }
                Text("В тайском важны 5 тонов; когда оценка подключена, здесь будет видно, какой слог произнесён верно и почему.")
                    .font(.caption2)
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .opacity(0.75)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 6)
    }

    @ViewBuilder private var idleHelperHint: some View {
        // keep constant vertical space so the carousel doesn't jump between phases
        ZStack {
            if phase == .idle, !helperHasInteracted {
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
    private var courseContextCardCountLabel: String {
        let n = external?.courseContextCardCount ?? 0
        if n == 1 { return "1 карточка" }
        if n >= 2, n <= 4 { return "\(n) карточки" }
        return "\(n) карточек"
    }

    // MARK: header (safeAreaInset) — section "ПРАКТИКА" with optional course name (переключатель режимов только в хедере приложения)
    private var topChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section title row: "ПРАКТИКА" left, course name right (when from course)
            HStack(alignment: .center, spacing: 8) {
                Text("ПРАКТИКА")
                    .font(PD.FontToken.caption(12, weight: .semibold))
                    .kerning(0.6)
                    .foregroundColor(PD.ColorToken.textSecondary)
                Spacer(minLength: 8)
                if let cid = external?.courseContextCourseId, !cid.isEmpty, speakerUIMode == .training {
                    Text(CourseData.shared.title(for: cid) ?? cid)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, Theme.Layout.pageHorizontal)
            .padding(.top, Theme.Layout.sectionTop)
            .padding(.bottom, 4)

            // Compact stats line when from course (inside section) — training only
            if speakerUIMode == .training, let cid = external?.courseContextCourseId, !cid.isEmpty {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 10))
                        Text(courseContextCardCountLabel)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 10))
                        Text("\(external?.courseContextAttemptCount ?? 0) попыток")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    if (external?.courseContextAvgScore ?? 0) > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "percent")
                                .font(.system(size: 10))
                            Text("\(external?.courseContextAvgScore ?? 0)%")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(PD.ColorToken.textSecondary)
                    }
                }
                .padding(.horizontal, Theme.Layout.pageHorizontal)
                .padding(.bottom, 6)
            }

            if speakerUIMode == .training {
                if external?.showFilterStrip ?? true {
                    filtersStrip
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                }

                learnedLessonStrip
                    .padding(.bottom, 6)

                // taika fm bubble lives under filters (not above the CTA)
                Group { topTaikaBubble }
                    .frame(maxWidth: .infinity)
                    .frame(height: taikaBubbleReservedHeight, alignment: .top)
                    .padding(.horizontal, 18)
                    .padding(.bottom, phase.isFeedback ? 6 : 0)
            }
        }
        .background(T.Colors.backgroundPrimary.ignoresSafeArea())
    }



    // MARK: taika bubble (center)
    @ViewBuilder private func taikaCenterBubble(_ lines: [String]) -> some View {
        let cleaned: [String] = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if cleaned.isEmpty {
            EmptyView()
        } else {
            let accentFill = ThemeManager.shared.currentAccentFill
            let accentStyle: AnyShapeStyle = AnyShapeStyle(accentFill)
            TaikaFMBubble(label: "taika fm", reactions: [], onReactionTap: nil) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentStyle)
                        .opacity(0.75)
                        .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("тайка")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .opacity(0.85)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(cleaned.indices, id: \.self) { idx in
                                Text(cleaned[idx])
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(PD.ColorToken.text)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                                    .opacity(0.94)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder private func taikaCenterBubble(_ text: String) -> some View {
        taikaCenterBubble([text])
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
                        lessonTitle: external?.lessonTitleForLessonId?(cur.lessonId),
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
        case .current: return "в последнем уроке пока нет фраз"
        case .favorites: return "в избранном пока пусто"
        case .learned: return "выученных фраз пока нет"
        case .random: return "пока нечего показать"
        }
    }

    private var emptyStateSubtitle: String {
        switch activeMode {
        case .current:
            return "открой урок со степами и вернись сюда"
        case .favorites:
            return "лайкни пару фраз в уроках — они появятся здесь"
        case .learned:
            return "отмечай степы как выученные — и они соберутся тут"
        case .random:
            return "попробуй другой режим или вернись позже"
        }
    }

    @ViewBuilder private var emptyCarouselState: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        let cardW: CGFloat = 268
        let cardH: CGFloat = 196

        VStack {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))

                    Image(systemName: activeMode == .favorites ? "heart.slash" : (activeMode == .learned ? "checkmark.circle" : "sparkles"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                        .opacity(0.9)
                }

                VStack(spacing: 6) {
                    Text(emptyStateTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(emptyStateSubtitle)
                        .font(.footnote)
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .opacity(0.92)
                }
                .padding(.horizontal, 18)

                if activeMode == .favorites || activeMode == .learned {
                    Button {
                        external?.onSelectFilter(SpeakerMode.currentMode.id)
                    } label: {
                        Text("перейти в последний урок")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(Capsule(style: .continuous).stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: cardW, height: cardH)
            .background(
                Theme.Surfaces.card(round)
            )
            .overlay(
                round
                    .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
            )
        }
        .frame(maxWidth: .infinity)
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
                            ? Color.white.opacity(0.25)
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
                            : AnyShapeStyle(Color.white.opacity(0.25))
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
                        : AnyShapeStyle(Color.white.opacity(0.25))
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
                            ? Color.white.opacity(0.25)
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
            .foregroundStyle(isDisabled ? AnyShapeStyle(Color.white.opacity(0.30)) : AnyShapeStyle(Color.white.opacity(0.85)))
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
    }
    
    // sketchy icons: shuffle/favorite - hand-drawn style
    private func speakerSketchyIcon(system: String, isDisabled: Bool, isActive: Bool = false) -> some View {
        let accent = AnyShapeStyle(ThemeManager.shared.currentAccentFill)
        let fgColor: AnyShapeStyle = {
            if isDisabled {
                return AnyShapeStyle(Color.white.opacity(0.25))
            } else if isActive {
                return accent
            } else {
                return AnyShapeStyle(Color.white.opacity(0.70))
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
            let itemH: CGFloat = 196
            emptyCarouselState
                .frame(height: itemH)
        } else {
            let currentId = external?.selectedId ?? localSelectedId ?? currentItem?.id ?? items.first?.id
            let itemW: CGFloat = 268
            let itemH: CGFloat = 196

            let activeId = currentId
            let currentIndex = items.firstIndex(where: { $0.id == activeId }) ?? 0

            // centered 3d carousel (no scroll). depth is driven by relative index.
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

    private var modeFilters: [AppFilterItem] {
        let active = activeFilterId
        return [
            AppFilterItem(id: SpeakerMode.currentMode.id, title: "последний урок", isActive: active == SpeakerMode.currentMode.id),
            AppFilterItem(id: SpeakerMode.favorites.id, title: "избранное", isActive: active == SpeakerMode.favorites.id),
            AppFilterItem(id: SpeakerMode.learned.id, title: "выученные", isActive: active == SpeakerMode.learned.id),
            AppFilterItem(id: SpeakerMode.random.id, title: "случайные", isActive: active == SpeakerMode.random.id)
        ]
    }

    private var filtersStrip: some View {
        let items = modeFilters

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(Array(items), id: \.id) { (it: AppFilterItem) in
                    let isActive = it.isActive

                    Button {
                        external?.onSelectFilter(it.id)
                    } label: {
                        VStack(spacing: 6) {
                            Text(it.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(
                                    isActive
                                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                    : AnyShapeStyle(PD.ColorToken.textSecondary)
                                )

                            Rectangle()
                                .fill(
                                    isActive
                                    ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                    : AnyShapeStyle(Color.clear)
                                )
                                .frame(height: 2)
                                .frame(maxWidth: .infinity)
                                .opacity(isActive ? 1 : 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PD.Spacing.screen)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var learnedLessonStrip: some View {
        if activeFilterId == SpeakerMode.learnedMode.id, let ext = external, !ext.learnedLessonIds.isEmpty {
            learnedLessonStripContent(ext: ext)
        }
    }

    private func learnedLessonStripContent(ext: External) -> some View {
        let ids = ext.learnedLessonIds
        let currentFilter = ext.learnedLessonFilter ?? ""
        let accent = ThemeManager.shared.currentAccentFill
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button {
                    ext.onSelectLearnedLessonFilter?(nil)
                } label: {
                    Text("Все")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(currentFilter.isEmpty ? AnyShapeStyle(accent) : AnyShapeStyle(PD.ColorToken.textSecondary))
                }
                .buttonStyle(.plain)

                ForEach(ids, id: \.self) { lessonId in
                    let title = ext.lessonTitleForLessonId?(lessonId) ?? "Урок"
                    let isActive = currentFilter == lessonId
                    Button {
                        ext.onSelectLearnedLessonFilter?(lessonId)
                    } label: {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isActive ? AnyShapeStyle(accent) : AnyShapeStyle(PD.ColorToken.textSecondary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PD.Spacing.screen)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    var body: some View {
        TaikaSmartSpeakerPhonetic.styledText(phonetic, font: font)
            .multilineTextAlignment(.center)
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
                .fill(Color.black.opacity(0.18))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
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
        .frame(height: 30)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.24),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
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

        VStack(alignment: .leading, spacing: 10) {
            // top row: бренд + чип урока в тему (как в Fav DS — без наслоения overlay)
            HStack(alignment: .center, spacing: 8) {
                Text("taikA")
                    .font(.custom("ONMARK Trial", size: 14))
                    .tracking(0.6)
                    .foregroundStyle(PD.ColorToken.text)

                Spacer(minLength: 0)

                lessonTitlePill
                attemptChip
                    .layoutPriority(0)
            }

            Spacer(minLength: 0)

            // center block (FavoriteDS-like typography rhythm)
            Group {
                if isAnalyzingActive {
                    TaikaLoadingView(label: "анализирую…", compact: true)
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        // line 1 (accent): translit с анимацией направления тона при воспроизведении эталона
                        Group {
                            if translitAccent.isEmpty {
                                Text("—")
                                    .foregroundStyle(PD.ColorToken.textSecondary)
                                    .opacity(0.45)
                            } else if translitAccent.contains("→") || translitAccent.contains("↗") || translitAccent.contains("↘") || translitAccent.contains("↑") || translitAccent.contains("↓") {
                                PhoneticToneAnimationView(phonetic: translitAccent, playbackProgress: referencePlaybackProgress)
                            } else {
                                Text(translitAccent)
                                    .foregroundStyle(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            }
                        }
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.80)
                        .opacity(translitAccent.isEmpty ? 0.45 : 1.0)

                        if isRecordingActive {
                            // while recording we DON'T show RU meaning (it will appear in result)
                            MiniWaveform(meter: recordingMeter)
                                .padding(.top, 2)

                            Text(thaiSecondary)
                                .font(.footnote)
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .opacity(0.86)
                                .lineLimit(1)
                                .minimumScaleFactor(0.90)
                                .opacity(thaiSecondary.isEmpty ? 0.0 : 1.0)
                        } else {
                            // line 2 (title): RU meaning (shown only when not recording)
                            Text(ruTitle.isEmpty ? "—" : ruTitle)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(T.Colors.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.80)
                                .opacity(ruTitle.isEmpty ? 0.45 : 1.0)

                            // line 3 (secondary): thai script
                            Text(thaiSecondary)
                                .font(.footnote)
                                .foregroundStyle(PD.ColorToken.textSecondary)
                                .opacity(0.86)
                                .lineLimit(1)
                                .minimumScaleFactor(0.90)
                                .opacity(thaiSecondary.isEmpty ? 0.0 : 1.0)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

        }
        .padding(16)
        .frame(width: 268, height: 196, alignment: .topLeading)
        .background(
            Theme.Surfaces.card(round)
        )
        // .background and .overlay for hi-tech aura/glow removed
        .animation(.easeInOut(duration: 0.18), value: isRecordingActive)
        .animation(.easeInOut(duration: 0.18), value: isAnalyzingActive)
        .overlay(alignment: .bottomTrailing) {
            EmptyView()
        }
        .contentShape(round)
    }

    /// Чип с названием урока (стиль как в Fav DS: footnote semibold, 12/8, акцентная капсула, без сердечка).
    @ViewBuilder private var lessonTitlePill: some View {
        let title = (item.lessonTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(Theme.TextBlock.bodyMinimumScale)
                .foregroundStyle(Color.black.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous).fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                )
                .overlay(Capsule(style: .continuous).stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
                .allowsHitTesting(false)
        }
    }
}

// MARK: - domain
public enum SpeakerMode: Hashable {
    case current, favorites, learned, random

    // stable ids for AppFiltersBar (UUID-based)
    private static let currentId = UUID(uuidString: "9C9B0F3C-8B3B-4C7C-9D26-8B0F4C9A1A01")!
    private static let favoritesId = UUID(uuidString: "2A6E4A7B-0B7B-4E7B-8C5A-7B9D1F8E2B02")!
    private static let learnedId = UUID(uuidString: "3B7C5D8A-1C4D-4D2B-9A6C-2D1C7E4B5A04")!
    private static let randomId = UUID(uuidString: "7E1D5B8E-2C5A-4C1C-8B6E-5A2C1D7E3C03")!

    var id: UUID {
        switch self {
        case .current: return Self.currentId
        case .favorites: return Self.favoritesId
        case .learned: return Self.learnedId
        case .random: return Self.randomId
        }
    }

    init?(id: UUID) {
        switch id {
        case Self.currentId: self = .current
        case Self.favoritesId: self = .favorites
        case Self.learnedId: self = .learned
        case Self.randomId: self = .random
        default: return nil
        }
    }
}

// convenience static accessors (to avoid conflict with case names)
extension SpeakerMode {
    public static var currentMode: SpeakerMode { .current }
    public static var favoritesMode: SpeakerMode { .favorites }
    public static var learnedMode: SpeakerMode { .learned }
    public static var randomMode: SpeakerMode { .random }
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
            ? Color.white.opacity(0.88)
            : Color.white.opacity(0.50)

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
        .preferredColorScheme(.dark)
    }
}

#Preview("speaker ds — story") {
    SpeakerDSStoryPreview()
}
#endif




private var analysisRailPlaceholder: some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(" ")
            .font(.caption.weight(.semibold))
        Text(" ")
            .font(.footnote)
        Text(" ")
            .font(.footnote)
    }
    .foregroundStyle(Color.clear)
    .frame(maxWidth: .infinity, alignment: .leading)
}

private func analysisRail(_ hints: [String]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text("заметки")
            .font(.caption.weight(.semibold))
            .foregroundStyle(PD.ColorToken.textSecondary)
            .opacity(0.78)

        ForEach(hints.prefix(3), id: \.self) { hint in            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(ThemeManager.shared.currentAccentFill)
                    .frame(width: 4, height: 4)
                    .padding(.top, 7)

                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(PD.ColorToken.text)
                    .opacity(0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        if hints.count > 3 {
            Text("+\(hints.count - 3) ещё")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .opacity(0.70)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}
