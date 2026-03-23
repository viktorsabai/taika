private struct StepChrome: ViewModifier {
    let isOverlay: Bool

    func body(content: Content) -> some View {
        if isOverlay {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            content
        }
    }
}



import SwiftUI
import UIKit
import Combine

// MARK: - BlurView (glossy overlay for overlays and backgrounds)
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}

#if canImport(StepAnimation)
import StepAnimation
#else
// Fallback shim so this file builds even if StepAnimation module isn't linked
final class StepAnimator: ObservableObject {
    static let shared = StepAnimator()
    @Published var activeIndex: Int = 0
    @Published var learned: Set<Int> = []
    @Published var favorites: Set<Int> = []
    func jump(to i: Int) { activeIndex = max(0, i) }
    func toggleLearned(_ i: Int) {
        if learned.contains(i) { learned.remove(i) } else { learned.insert(i) }
    }
}

#endif

// управление режимом взаимодействия
enum InteractionScope {
    case full       // обычный режим: меняем прогресс/выучено
    case overlay    // read-only: навигация + избранное, без мутирования прогресса
}



extension UserSession {
    /// persist last opened step index for a given course/lesson
    func setLastStepIndex(courseId: String, lessonId: String, index: Int) {
        let key = "lastStepIndex.\(courseId).\(lessonId)"
        UserDefaults.standard.set(index, forKey: key)
    }
}


enum StepMode: Equatable {
    case lesson
    case loading(HomeGameType)
    case game(HomeGameType)
    case proGate(HomeGameType)
}

struct StepView: View {
    let courseId: String?
    let lessonId: String?
    let lessonTitle: String?
    let startIndex: Int?
    let scope: InteractionScope
    let showKinds: [SDStepItem.Kind]?
    /// layout-only flag: when true, show ONLY the central cards (no FM, no progress)
    let layoutCardsOnly: Bool
    /// permission: allow mutating learning/progress
    let allowLearning: Bool
    /// show mini progress bar and its caption (hide it for Favorites overlay)
    let showBottomProgress: Bool
    /// should StepView render its own internal back header (used only for canonical full-screen)
    let showInternalHeader: Bool
    /// should StepView draw its own full-screen background (disable when embedded in external overlays)
    let useInternalBackground: Bool
    /// optional override for back action (e.g., pop to lessons instead of generic dismiss)
    let onBack: (() -> Void)?

    init(
        courseId: String? = nil,
        lessonId: String? = nil,
        lessonTitle: String? = nil,
        startIndex: Int? = nil,
        scope: InteractionScope = .full,
        showKinds: [SDStepItem.Kind]? = nil,
        layoutCardsOnly: Bool = false,
        allowLearning: Bool = true,
        showBottomProgress: Bool = true,
        showInternalHeader: Bool = true,
        useInternalBackground: Bool = false,
        onBack: (() -> Void)? = nil
    ) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
        self.startIndex = startIndex
        self.scope = scope
        self.showKinds = showKinds
        let overlayMode = (scope == .overlay)
        // overlay — про лейаут (карты/без нижнего прогресса), но право на обучение контролируется параметром allowLearning
        self.layoutCardsOnly = layoutCardsOnly || overlayMode
        self.allowLearning = allowLearning
        self.showBottomProgress = showBottomProgress && !overlayMode && !self.layoutCardsOnly
        self.showInternalHeader = showInternalHeader
        self.useInternalBackground = useInternalBackground
        self.onBack = onBack
    }

    @State private var items: [SDStepItem] = []

    /// 0 = Лайфхаки, 1 = Карточки — переключатель в хедере Step (две карусели). По умолчанию карточки.
    @State private var stepSegment: Int = 1
    @State private var activeIndexTips: Int = 0
    @State private var activeIndexCards: Int = 0

    // Navigation state for Next Lesson
    @State private var goNextLesson: Bool = false

    // Overlay state for lesson summary
    @State private var showLessonSummary: Bool = false
    /// Показать короткую «запомнил»-обратную связь на карточке (галочка) перед переходом к следующей.
    @State private var learnedFeedbackIndex: Int? = nil
    @State private var learnedFeedbackRevealed: Bool = false
    @State private var summaryOverlayRevealed: Bool = false
    @State private var selectedGameType: HomeGameType = .match
    @State private var showReinforceGamePicker: Bool = false
    @State private var mode: StepMode = .lesson

    @StateObject private var anim = StepAnimator()
    @State private var resetGuardUntil: Date = .distantPast
    @State private var progressRenderNonce: Int = 0 // forces SDStepProgress to fully re-render after resets
    @State private var needsPostResetHydrate: Bool = false
    @State private var progressReady: Bool = false
    @State private var didSetInitialIndex: Bool = false
    @State private var pendingIndexPersist: DispatchWorkItem? = nil
    @State private var isMounted: Bool = false
    // live favorites sync
    @ObservedObject private var favManager = FavoriteManager.shared
    @ObservedObject private var stepManager = StepManager.shared

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var nav: NavigationIntent

    @State private var hints: [String] = []
    @State private var itemTips: [Int: String] = [:]
    @State private var resolvedTitle: String? = nil
    @State private var resolvedLessonId: String = ""
    @State private var resolvedCourseId: String = ""
    // Preloaded next-lesson id for smoother navigation
    @State private var nextLessonPreloadedId: String? = nil
    // Optional override to swap lesson in-place (used for "Следующий урок")
    @State private var overrideLessonId: String? = nil
    // Pending push to another course (used when we advance to next course)
    @State private var pendingNavCourseId: String? = nil
    @State private var pendingNavLessonId: String? = nil
    // Fallback presentation for cross-course navigation (when NavigationStack isn't available)
    @State private var presentNextCourse: Bool = false

    // mapping for progress-only items (exclude tips/dialogs from progress)
    @State private var progressMap: [Int: Int] = [:]          // originalIndex -> compactProgressIndex
    @State private var reverseProgressMap: [Int: Int] = [:]    // compactProgressIndex -> originalIndex

    // mapping between raw StepData indices and filtered UI indices
    @State private var origToUI: [Int: Int] = [:]
    @State private var uiToOrig: [Int: Int] = [:]

    // Detect Xcode Previews for isPreview usage
#if DEBUG
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
#else
    private var isPreview: Bool { false }
#endif

    // Helper: are we in overlay mode?
    private var isOverlay: Bool { scope == .overlay }

    // Compact (progress-only) projections
    private var learnedForProgress: Set<Int> {
        Set(anim.learned.compactMap { progressMap[$0] })
    }
    private var favoritesForProgress: Set<Int> {
        Set(anim.favorites.compactMap { progressMap[$0] })
    }
    private var progressTotal: Int { reverseProgressMap.count }

    // Progress-strip indices that correspond to lifehacks (tips)
    private var tipIndicesForProgress: Set<Int> {
        var s: Set<Int> = []
        for (i, it) in items.enumerated() {
            if it.kind == .tip, let mapped = progressMap[i] { s.insert(mapped) }
        }
        return s
    }

    // Разделение на лайфхаки и остальные карточки (для двух каруселей в Step)
    private var tipIndices: [Int] { items.indices.filter { items[$0].kind == .tip } }
    private var cardIndices: [Int] { items.indices.filter { items[$0].kind != .tip } }
    private var tipItems: [SDStepItem] { tipIndices.map { items[$0] } }
    private var cardItems: [SDStepItem] { cardIndices.map { items[$0] } }
    private var hasTwoSegments: Bool { !tipItems.isEmpty && !cardItems.isEmpty }

    // Original indices for tips, for use with ProgressManager
    private var tipOriginalIndices: Set<Int> {
        var s: Set<Int> = []
        for (i, it) in items.enumerated() {
            if it.kind == .tip { s.insert(i) }
        }
        return s
    }

    // Safe active index for projections (guards against -1 / OOB while data hydrates)
    private var clampedActiveIndex: Int {
        max(0, min(anim.activeIndex, max(0, items.count - 1)))
    }

    // Guard window right after resets: ignore progressDidChange for a short time
    private func beginResetGuard(_ seconds: TimeInterval = 0.7) {
        resetGuardUntil = Date().addingTimeInterval(seconds)
    }
    private var isUnderResetGuard: Bool { Date() < resetGuardUntil }

    // Force a full re-render of the carousel and clear any local visual state
    private func forceColdCarousel() {
        anim.learned.removeAll()
        anim.favorites.removeAll()
    }

    // After a reset, schedule a safe rehydrate from storage (only after guard window ends)
    private func schedulePostResetHydrate() {
        guard needsPostResetHydrate else { return }
        let delay: TimeInterval = 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // If guard window already elapsed, we can safely rehydrate from storage (will be empty after reset)
            if !isUnderResetGuard {
                hydrateLearnedFromSession()
                hydrateFavoritesFromManager()
                progressRenderNonce &+= 1
            } else {
                // Try again shortly after guard ends
                schedulePostResetHydrate()
            }
            needsPostResetHydrate = false
        }
    }


    // Count only learnable cards (exclude tips/intro/summary)
    private var learnableCount: Int {
        items.filter { it in
            switch it.kind { case .word, .phrase, .casual: true; default: false }
        }.count
    }

    // MARK: - Learnability helpers
    private func isLearnable(_ item: SDStepItem) -> Bool {
        switch item.kind { case .word, .phrase, .casual: return true; default: return false }
    }
    private func firstLearnableIndex() -> Int {
        return items.firstIndex(where: { isLearnable($0) }) ?? 0
    }
    private func normalizeToLearnableIndex(_ idx: Int) -> Int {
        guard !items.isEmpty else { return 0 }
        let clamped = max(0, min(idx, items.count - 1))
        if isLearnable(items[clamped]) { return clamped }
        if let fwd = items.indices.dropFirst(clamped).first(where: { isLearnable(items[$0]) }) {
            return fwd
        }
        if let back = items.indices.prefix(clamped).reversed().first(where: { isLearnable(items[$0]) }) {
            return back
        }
        return 0
    }

    private func notifyProgressAfterToggle(stepIndex: Int) {
        let nowLearned = anim.learned.contains(stepIndex)
        let origIdx = originalIndex(for: stepIndex)
        StepManager.shared.setLearned(index: origIdx, nowLearned)
        syncAnimLearnedFromStepManager()
    }

    private func hydrateLearnedFromSession() {
        let cid = resolvedCourseId.isEmpty ? {
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }() : resolvedCourseId
        let saved = ProgressManager.shared.learnedSet(courseId: cid, lessonId: resolvedLessonId)
        let learnableKinds: Set<SDStepItem.Kind> = [.word, .phrase, .casual]
        let uiIndices = Set(saved.compactMap { origToUI[$0] }.filter { ui in
            ui >= 0 && ui < items.count && learnableKinds.contains(items[ui].kind)
        })
        anim.learned = uiIndices
    }

    private var resolvedCourseIdOrPlaceholder: String {
        if !resolvedCourseId.isEmpty { return resolvedCourseId }
        let parts = resolvedLessonId.split(separator: "_")
        if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
        return resolvedLessonId
    }

    private func syncAnimLearnedFromStepManager() {
        guard StepManager.shared.courseId == resolvedCourseIdOrPlaceholder && StepManager.shared.lessonId == resolvedLessonId else { return }
        let learnedOrig = StepManager.shared.learned
        anim.learned = Set(learnedOrig.compactMap { origToUI[$0] })
    }

    private func hydrateFavoritesFromManager() {
        anim.favorites.removeAll()
        let courseId: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        for (i, item) in items.enumerated() {
            let fav = makeStepFav(for: item, index: i)
            let oi = originalIndex(for: i)
            let legacyId = "step:\(courseId):\(resolvedLessonId):idx\(oi)" // old scheme w/o type prefix
            if FavoriteManager.shared.isLiked(id: fav.favoriteId) ||
               FavoriteManager.shared.isLiked(id: legacyId) {
                anim.favorites.insert(i)
            }
        }
    }
    // Map UI (filtered/mapped) index to original raw StepData index using id-stable mapping
    private func originalIndex(for uiIndex: Int) -> Int {
        guard uiIndex >= 0 && uiIndex < items.count else { return uiIndex }
        return uiToOrig[uiIndex] ?? uiIndex
    }

    private func rebuildProgressIndexMaps() {
        progressMap.removeAll()
        reverseProgressMap.removeAll()
        var p = 0
        for i in items.indices {
            switch items[i].kind {
            case .word, .phrase, .casual, .tip:
                progressMap[i] = p
                reverseProgressMap[p] = i
                p += 1
            default:
                // intro/dialog/summary — не попадают в мини‑бар
                continue
            }
        }
    }

    // Returns a clamped and projected index for the progress strip, always valid and deterministic
    private func progressActiveIndexForDisplay() -> Int {
        guard !items.isEmpty else { return 0 }
        let ui = max(0, min(anim.activeIndex, items.count - 1))
        if let p = progressMap[ui] { return p }
        // Если текущая карта не проецируется в прогресс: берём ближайшую проецируемую слева, иначе 0
        var j = ui
        while j >= 0 {
            if let p = progressMap[j] { return p }
            j -= 1
        }
        return 0
    }

    // Normalization helper for ids used in favorites storage
    private func normalizedId(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    private func hydratedActiveStartIndex() -> Int {
        guard !resolvedLessonId.isEmpty else { return 0 }
        let cid: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        // After a reset or when there is no learned progress at all — always start from the first card
        let learnedNow = ProgressManager.shared.learnedSet(courseId: cid, lessonId: resolvedLessonId)
        if isUnderResetGuard || learnedNow.isEmpty { return 0 }
        if let saved = UserSession.shared.lastStepIndex(courseId: cid, lessonId: resolvedLessonId) {
            return max(0, min(saved, max(0, items.count - 1)))
        }
        return 0
    }

    private func loadFromStepData() {
        StepData.shared.preload()
        let lid: String
        if let ov = overrideLessonId, !ov.isEmpty {
            lid = ov
        } else if let lessonId = lessonId, !lessonId.isEmpty {
            lid = lessonId
        } else if let cid = courseId, cid == "course_b_1" {
            lid = "course_b_1_l1"
        } else {
            lid = "course_b_1_l1" // generic fallback to validate steps.json parsing
        }
        // Avoid reloading if the same lesson is already loaded and items are present.
        // BUT: if we came from overlay with a non-nil startIndex and we haven't applied it yet,
        // push that index once and keep the existing items.
        if self.resolvedLessonId == lid && !self.items.isEmpty {
            if let s = self.startIndex, !didSetInitialIndex {
                let clamped = max(0, min(s, max(0, self.items.count - 1)))
                self.anim.jump(to: clamped)
                self.didSetInitialIndex = true
            }
            return
        }
        // debug print removed
        self.resolvedLessonId = lid
        self.resolvedCourseId = self.courseId ?? ""
        // Resolve lesson title early
        self.resolvedTitle = self.lessonTitle ?? LessonsData.shared.lessonTitle(for: lid)
        let raw = StepData.shared.items(for: lid)
        // debug print removed
        // Map StepData.StepItem -> SDStepItem for DS
        let mapped: [SDStepItem] = raw.compactMap { it in
            switch it.kind {
            case .word:
                if let ru = it.ru, let th = it.thai, let ph = it.phonetic {
                    return SDStepItem(kind: .word, titleRU: ru, subtitleTH: th, phonetic: ph)
                }
            case .phrase:
                if let ru = it.ru, let th = it.thai, let ph = it.phonetic {
                    return SDStepItem(kind: .phrase, titleRU: ru, subtitleTH: th, phonetic: ph)
                }
            case .casual:
                if let ru = it.ru, let th = it.thai, let ph = it.phonetic {
                    return SDStepItem(kind: .casual, titleRU: ru, subtitleTH: th, phonetic: ph)
                }
            case .tip:
                if let text = it.text {
                    let title = it.tip ?? "Лайфхак"
                    return SDStepItem(kind: .tip, titleRU: title, subtitleTH: text, phonetic: "")
                }
            case .dialog:
                if let scene = it.scene {
                    return SDStepItem(kind: .tip, titleRU: "Сцена", subtitleTH: scene, phonetic: "")
                }
            }
            return nil
        }
        // Remember original requested start (pre-filter) to keep the same card after filtering
        let originalStart: Int? = self.startIndex.map { max(0, min($0, max(0, mapped.count - 1))) }
        let originalStartId: String? = {
            guard let idx = originalStart,
                  !mapped.isEmpty,
                  idx >= 0, idx < mapped.count else { return nil }
            return mapped[idx].id.uuidString
        }()

        // Effective kinds: explicit showKinds only; otherwise show all kinds, even in overlay
        let effectiveKinds: [SDStepItem.Kind]? = {
            if let explicit = showKinds { return explicit }
            return nil
        }()

        // Filter with preservation of original indices → build mapping UI <-> original
        let filteredPairs: [(orig: Int, item: SDStepItem)] = {
            if let kinds = effectiveKinds {
                return mapped.enumerated().filter { kinds.contains($0.element.kind) }.map { ($0.offset, $0.element) }
            } else {
                return mapped.enumerated().map { ($0.offset, $0.element) }
            }
        }()

        // Build per-UI-index tips from raw StepData items before applying filtered items
        var tipsByUI: [Int: String] = [:]
        for (ui, pair) in filteredPairs.enumerated() {
            let orig = pair.orig
            if orig >= 0 && orig < raw.count, let tip = raw[orig].tip, !tip.isEmpty {
                tipsByUI[ui] = tip
            }
        }
        self.itemTips = tipsByUI

        // Apply filtered items
        self.items = filteredPairs.map { $0.item }

        // Build maps UI → Original and Original → UI (used for favorites & progress projections)
        var u2o: [Int: Int] = [:]
        var o2u: [Int: Int] = [:]
        for (ui, pair) in filteredPairs.enumerated() {
            u2o[ui] = pair.orig
            o2u[pair.orig] = ui
        }
        self.uiToOrig = u2o
        self.origToUI = o2u

        // Configure StepManager so it is the single source of truth for progress (same lesson, index alignment)
        let cid: String = {
            if !self.resolvedCourseId.isEmpty { return self.resolvedCourseId }
            let parts = lid.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return String(lid)
        }()
        let stepModels: [StepModel] = raw.enumerated().map { idx, it in
            let kind: StepKind
            switch it.kind {
            case .word: kind = .word
            case .phrase: kind = .phrase
            case .casual: kind = .word
            case .tip: kind = .lifehack
            case .dialog: kind = .lifehack
            }
            return StepModel(kind: kind, title: it.ru ?? "", thai: it.thai, transcriptionRu: it.phonetic)
        }
        StepManager.shared.configure(courseId: cid, lessonId: lid, steps: stepModels)

        // Clear any stale learned state before rebuilding progress index maps
        self.anim.learned.removeAll()
        rebuildProgressIndexMaps()
        self.hints = StepData.shared.hints(for: lid)

        // Safety fallback: if no data loaded, inject a tiny demo so DS still renders
        if self.items.isEmpty {
            self.items = [
                .init(kind: .word,   titleRU: "Привет",            subtitleTH: "สวัสดี",                    phonetic: "са-ват-ди́"),
                .init(kind: .phrase, titleRU: "Счёт, пожалуйста",  subtitleTH: "เช็คบิล",                   phonetic: "чек-бин"),
                .init(kind: .tip,    titleRU: "Подсказка",         subtitleTH: "Если пусто — проверь steps.json", phonetic: "")
            ]
            print("[StepView] fallback demo injected (empty data)")
        }

        // Immediately hydrate from session and favorites after data load
        self.hydrateLearnedFromSession()
        self.hydrateFavoritesFromManager()

        // Base start index per priority
        let baseStart: Int = {
            if let s = self.startIndex {
                return max(0, min(s, max(0, self.items.count - 1)))
            }
            if let id = originalStartId, let idx = self.items.firstIndex(where: { $0.id.uuidString == id }) {
                return idx
            }
            if self.isOverlay { return 0 }
            return isPreview ? 0 : hydratedActiveStartIndex()
        }()
        // Normalize to a learnable card so mini‑progress and carousel align visually
        let startIdx = normalizeToLearnableIndex(baseStart)

        // Set initial index exactly once and coalesce progress snapshot
        if !didSetInitialIndex {
            self.anim.jump(to: startIdx)
            // Ensure the DS scroll snaps to the same index after layout
            DispatchQueue.main.async { self.anim.jump(to: startIdx) }
            self.didSetInitialIndex = true
        }


        self.progressReady = false
        self.progressRenderNonce &+= 1
        // StepManager.configure already scheduled notifyProgress(); no duplicate snapshot
        self.progressReady = true
    }
    // (Old hydrateActiveIndexFromActivity() removed and replaced by hydratedActiveStartIndex())


    /// Строка заголовка над каруселью (УРОК + название) при двух каруселях; переключатель — в app header.
    @ViewBuilder
    private func stepTitleRowOnly() -> some View {
        let lessonTitleText: String = {
            if let t = resolvedTitle, !t.isEmpty { return t }
            if let t = lessonTitle, !t.isEmpty { return t }
            return "Урок"
        }()
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("УРОК")
                .font(PD.FontToken.caption(12, weight: .medium))
                .foregroundColor(PD.ColorToken.textSecondary.opacity(0.9))
            Spacer(minLength: 8)
            Text(lessonTitleText)
                .font(PD.FontToken.body(15, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                .lineLimit(1)
        }
        .padding(.bottom, 2)
    }

    // Split out to reduce type-checking pressure in the main body
    @ViewBuilder
    private func carouselView() -> some View {
        if hasTwoSegments {
            // Две карусели: показываем одну в зависимости от stepSegment (синхр. с app header)
            if stepSegment == 0 {
                stepCarouselOne(
                    items: tipItems,
                    activeIndex: $activeIndexTips,
                    learned: [],
                    favorites: Set(tipIndices.enumerated().filter { anim.favorites.contains(tipIndices[$0.offset]) }.map { $0.offset })
                )
            } else {
                stepCarouselOne(
                    items: cardItems,
                    activeIndex: $activeIndexCards,
                    learned: Set(cardIndices.enumerated().filter { anim.learned.contains(cardIndices[$0.offset]) }.map { $0.offset }),
                    favorites: Set(cardIndices.enumerated().filter { anim.favorites.contains(cardIndices[$0.offset]) }.map { $0.offset })
                )
            }
        } else {
            // Одна карусель (как раньше)
            let activeBinding = Binding<Int>(
                get: { anim.activeIndex },
                set: { anim.activeIndex = $0 }
            )
            let sectionTitle: String = {
                if let t = resolvedTitle, !t.isEmpty { return t.uppercased() }
                if let t = lessonTitle, !t.isEmpty { return t.uppercased() }
                return "УРОК"
            }()
            let sectionSubtitle: String? = items.isEmpty ? nil : "урок • \(items.count) карт"
            SDStepCarousel(
                title: sectionTitle,
                items: items,
                activeIndex: activeBinding,
                subtitle: sectionSubtitle,
                learned: anim.learned,
                favorites: anim.favorites,
                onTap: { handleTapItem($0) },
                onPlay: { handlePlayItem($0) },
                onFav: { handleFavItem($0) },
                onDone: { handleDoneItem($0) },
                onNext: { handleNextItem($0) },
                isOverlay: isOverlay,
                loop: true
            )
        }
    }

    @ViewBuilder
    private func stepCarouselOne(
        items segmentItems: [SDStepItem],
        activeIndex: Binding<Int>,
        learned: Set<Int>,
        favorites: Set<Int>
    ) -> some View {
        SDStepCarousel(
            title: "",
            items: segmentItems,
            activeIndex: activeIndex,
            subtitle: nil,
            learned: learned,
            favorites: favorites,
            onTap: { handleTapItem($0) },
            onPlay: { handlePlayItem($0) },
            onFav: { handleFavItem($0) },
            onDone: { handleDoneItem($0) },
            onNext: { handleNextItem($0) },
            isOverlay: isOverlay,
            loop: true,
            compactSection: true
        )
    }

    /// Короткая обратная связь «запомнил»: галочка по центру карточки (0.35 с), затем переход.
    @ViewBuilder
    private var learnedCheckmarkOverlay: some View {
        if learnedFeedbackIndex != nil {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                .scaleEffect(learnedFeedbackRevealed ? 1.0 : 0.3)
                .opacity(learnedFeedbackRevealed ? 0.95 : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.65), value: learnedFeedbackRevealed)
                .onAppear { learnedFeedbackRevealed = true }
                .allowsHitTesting(false)
        }
    }

    // Split out the Next-Lesson link to reduce type-checking in the main body
    @ViewBuilder
    private func nextLessonLink() -> some View {
        NavigationLink(isActive: $goNextLesson) {
            let cid: String = pendingNavCourseId ?? {
                if !resolvedCourseId.isEmpty { return resolvedCourseId }
                let parts = resolvedLessonId.split(separator: "_")
                if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                return resolvedLessonId
            }()
            let targetId = pendingNavLessonId ?? nextLessonPreloadedId ?? nextLessonId(from: resolvedLessonId) ?? resolvedLessonId
            StepView(courseId: cid, lessonId: targetId, lessonTitle: guessLessonTitle(for: targetId))
        } label: { EmptyView() }
        .hidden()
    }

    // MARK: - Taika Mascot Helper (for overlays)
    @ViewBuilder
    private var taikaMascotView: some View {
        Image("mascot.message")
            .resizable()
            .scaledToFit()
            .frame(width: 156, height: 156)
            .opacity(0.95)
    }

    @ViewBuilder
    private func bottomProgressView(proxy: GeometryProxy) -> some View {
        if hasTwoSegments {
            // Прогресс только по текущему сегменту (лайфхаки или карточки)
            let total = stepSegment == 0 ? tipItems.count : cardItems.count
            let active = stepSegment == 0 ? activeIndexTips : activeIndexCards
            let indices = stepSegment == 0 ? tipIndices : cardIndices
            let learnedSeg: Set<Int> = stepSegment == 0 ? [] : Set(indices.enumerated().filter { anim.learned.contains(indices[$0.offset]) }.map { $0.offset })
            let favoritesSeg: Set<Int> = Set(indices.enumerated().filter { anim.favorites.contains(indices[$0.offset]) }.map { $0.offset })
            let tipIndicesSeg: Set<Int> = stepSegment == 0 ? Set(0..<total) : []
            if total > 0 {
                SDStepProgress(
                    total: total,
                    activeIndex: min(active, max(0, total - 1)),
                    learned: learnedSeg,
                    favorites: favoritesSeg,
                    tipIndices: tipIndicesSeg,
                    onTap: { i in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if stepSegment == 0 {
                            activeIndexTips = min(max(0, i), total - 1)
                        } else {
                            activeIndexCards = min(max(0, i), total - 1)
                        }
                    }
                )
                .id("progress-\(resolvedLessonId)-\(stepSegment)-\(progressRenderNonce)")
                .padding(.horizontal, PD.Spacing.inner)
                .padding(.bottom, 4)
            }
        } else if progressTotal > 0 {
            let raw = progressActiveIndexForDisplay()
            let p: Int = raw
            let progressView: SDStepProgress = SDStepProgress(
                total: progressTotal,
                activeIndex: p,
                learned: learnedForProgress,
                favorites: favoritesForProgress,
                tipIndices: tipIndicesForProgress,
                onTap: { i in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let original = reverseProgressMap[i] ?? i
                    didSetInitialIndex = true
                    anim.jump(to: original)
                }
            )
            progressView
                .id("progress-\(resolvedLessonId)-\(progressRenderNonce)")
                .padding(.horizontal, PD.Spacing.inner)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Subviews to reduce type-checking pressure
    // MARK: - PRO gating logic
    private func featureFor(_ type: HomeGameType) -> ProFeature {
        switch type {
        case .match: return .recallGame // match is free but feature won't be checked
        case .recall: return .recallGame
        case .builder: return .contextGame
        }
    }

    private func startSelectedGame() {
        let type = selectedGameType

        if type == .match {
            mode = .loading(type)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                mode = .game(type)
            }
            return
        }

        if ProManager.shared.can(featureFor(type)) {
            mode = .loading(type)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                mode = .game(type)
            }
        } else {
            mode = .proGate(type)
        }
    }

    @ViewBuilder
    private func summaryOverlayView() -> some View {
        let cid: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        let advance = CourseNavigator.shared.advance(from: cid, lessonId: resolvedLessonId)
        let accent = ThemeManager.shared.currentAccentFill
        let config: (title: String, subtitle: String, primary: String) = {
            switch advance {
            case .nextLesson:
                return ("Урок пройден", "Выучено \(anim.learned.count) из \(learnableCount)", "Следующий урок")
            case .nextCourse(_, let firstLessonId):
                let nextTitle = LessonsData.shared.lessonTitle(for: firstLessonId) ?? "Следующий курс"
                return ("Курс завершён", nextTitle, "Следующий курс")
            case .end:
                return ("Все пройдено", "Повтори материал или выбери раздел", "К курсам")
            }
        }()

        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                    scheduleAuthSoftWallIfNeeded()
                }

            VStack(spacing: 0) {
                // Заголовок
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(config.subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 12)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                        scheduleAuthSoftWallIfNeeded()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 18)

                // Главный CTA — обводка, тёмный текст (в нашей айдентике)
                Button {
                    switch advance {
                    case .end:
                        withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                        scheduleAuthSoftWallIfNeeded()
                    case .nextLesson:
                        prepareNextLessonAndNavigate()
                    case .nextCourse(let nextCourseId, let firstLessonId):
                        _ = StepData.shared.items(for: firstLessonId)
                        pendingNavCourseId = nextCourseId
                        pendingNavLessonId = firstLessonId
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showLessonSummary = false }
                        scheduleAuthSoftWallIfNeeded()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { presentNextCourse = true }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(config.primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.12))
                            .overlay(Capsule().strokeBorder(accent, lineWidth: 1.5))
                    )
                    .foregroundStyle(accent)
                    .font(.system(size: 17, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

                // Закрепить: либо одна кнопка (сворачиваемо), либо инлайн-блок выбора игры (без системного dialog)
                if showReinforceGamePicker {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Закрепить урок")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        VStack(spacing: 8) {
                            reinforceGameOption(title: "Найди пару", type: .match)
                            reinforceGameOption(title: "Быстрое повторение", type: .recall)
                            reinforceGameOption(title: "Фразы в контексте", type: .builder)
                        }
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                            startSelectedGame()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Начать тренировку")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(white: 0.14))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(accent))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Вторичные действия
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            showReinforceGamePicker.toggle()
                        }
                    } label: {
                        Label(showReinforceGamePicker ? "Свернуть" : "Закрепить", systemImage: "gamecontroller.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().strokeBorder(accent.opacity(0.6), lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                        UserSession.shared.markActive(courseId: resolvedCourseIdOrPlaceholder, lessonId: resolvedLessonId, stepIndex: 0)
                        NotificationCenter.default.post(name: Notification.Name("Step.progressDidChange"), object: nil)
                        nav.requestTab(2)
                    } label: {
                        Label("Произношение", systemImage: "mic.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().strokeBorder(accent.opacity(0.6), lineWidth: 1.2))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
            )
            .scaleEffect(summaryOverlayRevealed ? 1 : 0.92)
            .opacity(summaryOverlayRevealed ? 1 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: summaryOverlayRevealed)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showReinforceGamePicker)
            .onAppear { summaryOverlayRevealed = true }
        }
        .transition(.opacity)
        .zIndex(10)
    }

    private func reinforceGameOption(title: String, type: HomeGameType) -> some View {
        let accent = ThemeManager.shared.currentAccentFill
        let isSelected = selectedGameType == type
        return Button {
            selectedGameType = type
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Spacer(minLength: 8)
                if type == .match {
                    Text("FREE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.4)))
                } else {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(accent.opacity(0.18)) : AnyShapeStyle(Color.primary.opacity(0.06)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(Color.clear), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func stepMainContent(_ proxy: GeometryProxy) -> some View {
        let idx: Int = {
            if hasTwoSegments {
                if stepSegment == 0, activeIndexTips < tipIndices.count {
                    return tipIndices[activeIndexTips]
                }
                if stepSegment == 1, activeIndexCards < cardIndices.count {
                    return cardIndices[activeIndexCards]
                }
            }
            return clampedActiveIndex
        }()
        let currentTipText: String? = itemTips[idx]
        let baseH = max(CardDS.Metrics.stepWordCardHeight, CardDS.Metrics.stepLifehackCardHeight)
        let carouselMinHeight: CGFloat = baseH + 36
        let stack = VStack(spacing: 0) {
            nextLessonLink()

            if hasTwoSegments {
                stepTitleRowOnly()
                    .padding(.horizontal, PD.Spacing.inner)
                    .padding(.top, 12)
            }

            Spacer(minLength: 8)

            carouselView()
                .padding(.horizontal, PD.Spacing.inner)
                .frame(maxWidth: .infinity, minHeight: carouselMinHeight, alignment: .center)
                .modifier(StepChrome(isOverlay: isOverlay))
                .overlay(alignment: .center) { learnedCheckmarkOverlay }

            Spacer(minLength: 8)

            if !isOverlay && showBottomProgress {
                bottomProgressView(proxy: proxy)
                    .padding(.top, 4)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
            }

            if !layoutCardsOnly && !isOverlay {
                TaikaFMBubbleTyping(
                    messages: TaikaFMData.shared
                        .accentMessagesFromStepTip(currentTipText)
                        .map { chunkArray in
                            chunkArray.map { $0.text }.joined()
                        },
                    reactions: TaikaFMData.shared.reactionGroups(for: .step),
                    repeats: true,
                    showBubble: false
                )
                .padding(.horizontal, PD.Spacing.inner)
                .padding(.top, 16)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        stack
            .blur(radius: showLessonSummary ? 12 : 0)
            .saturation(showLessonSummary ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.18), value: showLessonSummary)
            .allowsHitTesting(isOverlay || !showLessonSummary)
    }

    var body: some View {
        GeometryReader { proxy in
            rootContent(proxy: proxy)
                .background(
                    PD.ColorToken.background
                        .ignoresSafeArea()
                )
                .onAppear {
                    if items.isEmpty {
                        loadFromStepData()
                    } else {
                        hydrateLearnedFromSession()
                    }

                    mode = .lesson

                    // if lesson already fully completed → show summary by default
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        let totalLearnable = learnableCount
                        let learnedNowCount = anim.learned.filter { idx in
                            idx >= 0 && idx < items.count && {
                                switch items[idx].kind {
                                case .word, .phrase, .casual: return true
                                default: return false
                                }
                            }()
                        }.count

                        if totalLearnable > 0 && learnedNowCount >= totalLearnable {
                            summaryOverlayRevealed = false
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                showLessonSummary = true
                            }
                        }
                    }
                }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if hasTwoSegments, !isOverlay {
                stepManager.stepHeaderShowsSegment = true
                stepManager.stepHeaderSegment = stepSegment
                stepManager.stepHeaderTipCount = tipItems.count
                stepManager.stepHeaderCardCount = cardItems.count
            }
        }
        .onChange(of: hasTwoSegments) { _, show in
            guard !isOverlay else { return }
            stepManager.stepHeaderShowsSegment = show
            if show {
                stepManager.stepHeaderSegment = stepSegment
                stepManager.stepHeaderTipCount = tipItems.count
                stepManager.stepHeaderCardCount = cardItems.count
            }
        }
        .onChange(of: tipItems.count) { _, _ in
            if hasTwoSegments, !isOverlay { stepManager.stepHeaderTipCount = tipItems.count }
        }
        .onChange(of: cardItems.count) { _, _ in
            if hasTwoSegments, !isOverlay { stepManager.stepHeaderCardCount = cardItems.count }
        }
        .onChange(of: stepManager.stepHeaderSegment) { _, newValue in
            stepSegment = newValue
        }
        .onChange(of: stepSegment) { _, newValue in
            stepManager.stepHeaderSegment = newValue
        }
        .onDisappear {
            stepManager.stepHeaderShowsSegment = false
            stepManager.stepHeaderTipCount = 0
            stepManager.stepHeaderCardCount = 0
        }
    }

    @ViewBuilder
    private func rootContent(proxy: GeometryProxy) -> some View {
        ZStack {
            modeLayer(proxy: proxy)

            // В overlay (из избранного) не показываем «Итоги урока» — только карусель и лайки
            if showLessonSummary && mode == .lesson && !isOverlay {
                summaryOverlayView()
            }
        }
        .fullScreenCover(isPresented: $presentNextCourse) {
            if let cid = pendingNavCourseId, let lid = pendingNavLessonId {
                StepView(courseId: cid, lessonId: lid, lessonTitle: guessLessonTitle(for: lid))
            }
        }
    }

    @ViewBuilder
    private func modeLayer(proxy: GeometryProxy) -> some View {
        switch mode {
        case .lesson:
            ZStack {
                VStack(spacing: 0) {
                    stepMainContent(proxy)
                }
            }

        case .loading(let type):
            loadingView(for: type)

        case .game(let type):
            gameView(for: type)

        case .proGate(let type):
            PROView(
                courseId: resolvedCourseId.isEmpty ? resolvedLessonId : resolvedCourseId,
                initialPage: {
                    switch type {
                    case .match: return 0
                    case .recall: return 0
                    case .builder: return 1
                    }
                }(),
                onClose: {
                    summaryOverlayRevealed = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = .lesson
                        showLessonSummary = true
                    }
                }
            )
            .transition(.opacity)
        }
    }

    private func loadingView(for type: HomeGameType) -> some View {
        ZStack {

            VStack(spacing: 22) {

                ZStack {
                    Circle()
                        .fill(ThemeManager.shared.currentAccentFill.opacity(0.15))
                        .frame(width: 96, height: 96)

                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(ThemeManager.shared.currentAccentFill)
                        .scaleEffect(1.4)
                }

                Text(
                    type == .match
                    ? "найди пару"
                    : type == .recall
                        ? "быстрое повторение"
                        : "фразы в контексте"
                )
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

                Text("taika готовит тренировку")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }

    private func nextGameType(after type: HomeGameType) -> HomeGameType {
        switch type {
        case .match: return .recall
        case .recall: return .builder
        case .builder: return .match
        }
    }

    private func nextGameTitle(after type: HomeGameType) -> String {
        switch nextGameType(after: type) {
        case .match: return "Найди пару"
        case .recall: return "Быстрое повторение"
        case .builder: return "Фразы в контексте"
        }
    }

    private func gameView(for type: HomeGameType) -> some View {
        HomeTaskView(
            courseId: resolvedCourseId.isEmpty ? resolvedLessonId : resolvedCourseId,
            lessonId: resolvedLessonId,
            embedBackground: false,
            onClose: {
                summaryOverlayRevealed = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    mode = .lesson
                    showLessonSummary = true
                }
            },
            onNextGame: {
                summaryOverlayRevealed = false
                let next = nextGameType(after: type)
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        mode = .game(next)
                    }
                }
            },
            nextGameTitle: nextGameTitle(after: type),
            isProUser: ProManager.shared.isPro,
            gameType: type
        )
        .id(type)
        .transition(.opacity)
    }


    private func index(of item: SDStepItem) -> Int? {
        items.firstIndex(where: { $0.id == item.id })
    }

    // MARK: - Handlers extracted to reduce type-checking complexity
    private func handleTapItem(_ item: SDStepItem) {
        if let i = index(of: item) {
            anim.jump(to: i)
        }
    }

    private func handlePlayItem(_ item: SDStepItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch item.kind {
        case .word, .phrase, .casual:
            StepAudio.shared.speakThai(item.subtitleTH)
        default:
            break
        }
    }

    private func handleFavItem(_ item: SDStepItem) {
        guard let i = index(of: item) else { return }
        let wasFavorite = anim.favorites.contains(i)
        let fav = makeStepFav(for: item, index: i)
        // instant local UI feedback to avoid visual lag
        withAnimation(.easeInOut(duration: 0.22)) {
            if wasFavorite {
                anim.favorites.remove(i)
            } else {
                anim.favorites.insert(i)
            }
        }
        // toggle asynchronously to prevent re-entrant updates during render
        DispatchQueue.main.async {
            Task { @MainActor in
                StepManager.shared.toggleFavorite(fav)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isMounted { hydrateFavoritesFromManager() }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if item.kind == .tip, !wasFavorite, i + 1 < items.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                anim.jump(to: i + 1)
            }
        }
    }

    private func handleDoneItem(_ item: SDStepItem) {
        switch item.kind {
        case .word, .phrase, .casual:
            // Respect read-only flows (e.g., Favorites overlay)
            guard allowLearning else { return }
            guard let i = index(of: item) else { return }
            let wasLearned = anim.learned.contains(i)
            withAnimation(.easeInOut(duration: 0.25)) { anim.toggleLearned(i) }
#if !DEBUG
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
            let nowLearned = anim.learned.contains(i)
            notifyProgressAfterToggle(stepIndex: i)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if isMounted { hydrateLearnedFromSession() }
            }
            // If пользователь снял отметку хотя бы с одной карточки → разрешить повторный показ summary при следующем полном завершении
            if wasLearned && !nowLearned {
                if showLessonSummary {
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                }
            }
            let totalLearnable = learnableCount
            let learnedNowCount = anim.learned.filter { idx in
                guard idx >= 0 && idx < items.count else { return false }
                switch items[idx].kind { case .word, .phrase, .casual: return true; default: return false }
            }.count
            let shouldShowSummary = !wasLearned && nowLearned && totalLearnable > 0 && learnedNowCount >= totalLearnable

            if !wasLearned && nowLearned {
                learnedFeedbackRevealed = false
                learnedFeedbackIndex = i
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    learnedFeedbackIndex = nil
                    if i < items.count - 1 {
                        let nextIdx = (i + 1..<items.count).first(where: { isLearnable(items[$0]) }) ?? (i + 1)
                        let targetIdx = min(nextIdx, items.count - 1)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            anim.jump(to: targetIdx)
                        }
                        if StepManager.shared.courseId == resolvedCourseIdOrPlaceholder && StepManager.shared.lessonId == resolvedLessonId {
                            StepManager.shared.setActive(index: originalIndex(for: targetIdx))
                        }
                    }
                    if shouldShowSummary {
                        summaryOverlayRevealed = false
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            showLessonSummary = true
                        }
                    }
                }
            } else if !shouldShowSummary {
                // If пользователь снял галочку на последней — не показываем оверлей и закрываем, если он вдруг открыт
                if showLessonSummary {
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                }
            }
            let cid: String = {
                if !resolvedCourseId.isEmpty { return resolvedCourseId }
                let parts = resolvedLessonId.split(separator: "_")
                if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                return resolvedLessonId
            }()
            NotificationCenter.default.post(
                name: Notification.Name("stepLearnedDidChange"),
                object: nil,
                userInfo: [
                    "courseId": cid,
                    "lessonId": resolvedLessonId,
                    "index": i,
                    "isLearned": nowLearned
                ]
            )
        case .tip:
            if let i = index(of: item), i + 1 < items.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    anim.jump(to: i + 1)
                }
            }
        default:
            break
        }
    }

    private func handleNextItem(_ item: SDStepItem) {
        guard let i = index(of: item), i + 1 < items.count else { return }
        switch item.kind {
        case .word, .phrase, .casual:
            if allowLearning && !anim.learned.contains(i) {
                withAnimation(.easeInOut(duration: 0.25)) { anim.toggleLearned(i) }
#if !DEBUG
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                notifyProgressAfterToggle(stepIndex: i)
                syncAnimLearnedFromStepManager()
            }
            let nextIdx = (i + 1..<items.count).first(where: { isLearnable(items[$0]) }) ?? (i + 1)
            let targetIdx = min(nextIdx, items.count - 1)
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    anim.jump(to: targetIdx)
                }
                if StepManager.shared.courseId == resolvedCourseIdOrPlaceholder && StepManager.shared.lessonId == resolvedLessonId {
                    StepManager.shared.setActive(index: originalIndex(for: targetIdx))
                }
            }
        case .tip:
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    anim.jump(to: i + 1)
                }
                if StepManager.shared.courseId == resolvedCourseIdOrPlaceholder && StepManager.shared.lessonId == resolvedLessonId {
                    StepManager.shared.setActive(index: originalIndex(for: i + 1))
                }
            }
        default:
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    anim.jump(to: i + 1)
                }
                if StepManager.shared.courseId == resolvedCourseIdOrPlaceholder && StepManager.shared.lessonId == resolvedLessonId {
                    StepManager.shared.setActive(index: originalIndex(for: i + 1))
                }
            }
        }
    }

    // Decide where to go next using CourseNavigator; swap in-place for same course, push for next course
    private func prepareNextLessonAndNavigate() {
        let cid: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        switch CourseNavigator.shared.advance(from: cid, lessonId: resolvedLessonId) {
        case .nextLesson(_, let nextId):
            _ = StepData.shared.items(for: nextId) // warm cache
            nextLessonPreloadedId = nextId
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showLessonSummary = false }
            scheduleAuthSoftWallIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                didSetInitialIndex = false
                overrideLessonId = nextId
                anim.learned.removeAll(); anim.favorites.removeAll()
                loadFromStepData()
            }
        case .nextCourse(let nextCourseId, let firstLesson):
            _ = StepData.shared.items(for: firstLesson) // warm cache
            pendingNavCourseId = nextCourseId
            pendingNavLessonId = firstLesson
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showLessonSummary = false }
            scheduleAuthSoftWallIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                // Prefer modal present to avoid dependency on NavigationStack presence
                presentNextCourse = true
            }
        case .end:
            withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
            scheduleAuthSoftWallIfNeeded()
        }
    }

    /// Отложенная проверка и показ мягкого окна «Закрепи результат» (refresh + tryPresentSoftWall через 0.35 с).
    private func scheduleAuthSoftWallIfNeeded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            Task { @MainActor in
                ProgressManager.shared.refreshProfileState()
                AuthSoftWallState.tryPresentSoftWall()
            }
        }
    }

    // Helper to get the next lesson id (robustly increments the lesson number in various formats)
    private func nextLessonId(from lid: String) -> String? {
        // Flexible patterns supported:
        // 1) "..._l3" or "..._l03" or "..._l3_done" → increment the digits right after "_l"
        // 2) fallback: any trailing digits at the end of the string ("lesson12")

        if let lRange = lid.range(of: "_l", options: .backwards) {
            let after = lid[lRange.upperBound...]
            let digitSlice = after.prefix { $0.isNumber }
            if let n = Int(digitSlice), !digitSlice.isEmpty {
                let width = digitSlice.count
                let incremented = String(format: "%0*d", width, n + 1)
                let rest = after.dropFirst(width)
                return String(lid[..<lRange.upperBound]) + incremented + rest
            }
            // if no digits right after _l, fall through to trailing-digits fallback
        }
        // Fallback: increment trailing number at the very end, preserving width
        let trailingDigits = lid.reversed().prefix { $0.isNumber }.reversed()
        if !trailingDigits.isEmpty, let n = Int(String(trailingDigits)) {
            let width = trailingDigits.count
            let base = lid.dropLast(width)
            let incremented = String(format: "%0*d", width, n + 1)
            return String(base) + incremented
        }
        return nil
    }

    private func guessLessonTitle(for lid: String) -> String? {
        switch lid {
        case "course_b_1_l1": return "ПРИВЕТСТВИЯ"
        case "course_b_1_l2": return "ЗНАКОМСТВО"
        case "course_b_1_l3": return "СЕМЬЯ И ОБРАЩЕНИЯ"
        case "course_b_1_l4": return "ВРЕМЯ И ЧИСЛА"
        default: return nil
        }
    }



    private struct StepFavBridge: Favoritable {
        let favoriteId: String
        let favoriteTitle: String
        let favoriteSubtitle: String
        let favoriteMeta: String
        let favoriteCourseId: String
        let favoriteLessonId: String
    }

    private func makeStepFav(for item: SDStepItem, index: Int) -> StepFavBridge {
        let courseId: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        let isHack = (item.kind == .tip)
        let origIndex = originalIndex(for: index)
        let fid = "\(isHack ? "hack" : "card"):step:\(courseId):\(resolvedLessonId):idx\(origIndex)"

        let favTitle: String
        let favSubtitle: String
        let favMeta: String

        if isHack {
            // use lifehack body as subtitle and meta
            let hackText = item.subtitleTH
            favTitle = item.titleRU.isEmpty ? "Лайфхак" : item.titleRU
            favSubtitle = hackText
            favMeta = "hack:" + hackText
        } else {
            favTitle = item.titleRU
            favSubtitle = item.subtitleTH
            favMeta = "card:" + item.phonetic
        }

        return StepFavBridge(
            favoriteId: fid,
            favoriteTitle: favTitle,
            favoriteSubtitle: favSubtitle,
            favoriteMeta: favMeta,
            favoriteCourseId: courseId,
            favoriteLessonId: resolvedLessonId
        )
    }
}




#if DEBUG
struct StepView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // каноничный экран урока через курс → lessons → steps (full)
            StepView(
                courseId: "course_b_1",
                lessonId: "course_b_1_l1",
                lessonTitle: "ПРИВЕТСТВИЯ",
                scope: .full,
                layoutCardsOnly: false,
                allowLearning: true,
                showBottomProgress: true
            )
            .previewDisplayName("step · full (canonical)")

            // тот же урок, но в overlay-режиме, как когда тянем секцию из других экранов
            ZStack {
                taikaGlassBackground()
                StepView(
                    courseId: "course_b_1",
                    lessonId: "course_b_1_l1",
                    lessonTitle: "ПРИВЕТСТВИЯ",
                    scope: .overlay,
                    layoutCardsOnly: true,
                    allowLearning: false,
                    showBottomProgress: false
                )
            }
            .previewDisplayName("step · overlay (cards section)")
        }
        .preferredColorScheme(.dark)
    }
}
#endif






// MARK: - LessonsView stepOverlay backdrop (Fav-style glossy overlay)
@ViewBuilder
func taikaGlassBackground() -> some View {
    BlurView(style: .systemUltraThinMaterialDark)
        .ignoresSafeArea()
        .zIndex(-1)
}


