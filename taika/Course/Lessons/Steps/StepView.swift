private struct StepChrome: ViewModifier {
    let isOverlay: Bool

    func body(content: Content) -> some View {
        // Как разминка на Main: карусель по центру доступной высоты, не прижата к верху.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

extension UserSession {
    /// persist last opened step index for a given course/lesson
    func setLastStepIndex(courseId: String, lessonId: String, index: Int) {
        let key = "lastStepIndex.\(courseId).\(lessonId)"
        UserDefaults.standard.set(index, forKey: key)
    }
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
        /// When `false` (default), only the shell `AppHeader` row is shown on the lesson route — no second `AppBackHeader` with centered wordmark.
        showInternalHeader: Bool = false,
        useInternalBackground: Bool = true,
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

    /// 0 = Лайфхаки, 1 = Карточки — переключатель в shell header (две карусели).
    @State private var stepSegment: Int = 1
    @State private var activeIndexTips: Int = 0
    @State private var activeIndexCards: Int = 0

    // Overlay state for lesson summary
    @State private var showLessonSummary: Bool = false
    @State private var summaryOverlaySettled: Bool = false
    @State private var didShowSummaryOnce: Bool = false
    @State private var summaryGameMode: GameModeType = .match

    @StateObject private var anim = StepAnimator()
    @State private var resetGuardUntil: Date = .distantPast
    @State private var progressRenderNonce: Int = 0 // forces SDStepProgress to fully re-render after resets
    @State private var needsPostResetHydrate: Bool = false
    @State private var progressReady: Bool = false
    @State private var didSetInitialIndex: Bool = false
    @State private var pendingProgressPost: DispatchWorkItem? = nil
    @State private var pendingIndexPersist: DispatchWorkItem? = nil
    @State private var pendingFavoriteHydrate: DispatchWorkItem? = nil
    @State private var pendingLearnAdvanceToken: UUID? = nil
    @State private var isMounted: Bool = false
    @State private var suppressFavoriteHydrationUntil: Date = .distantPast
    // live favorites sync
    @ObservedObject private var favManager = FavoriteManager.shared
    @ObservedObject private var stepManager = StepManager.shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.taikaRootHeaderClearance) private var rootHeaderClearance
    @EnvironmentObject private var nav: NavigationIntent
    @EnvironmentObject private var overlay: OverlayPresenter

    @State private var hints: [String] = []
    @State private var itemTips: [Int: String] = [:]
    /// Лайфхаки урока (`.tip` в JSON) — сохраняем отдельно для аналитики/счётчиков, но показываем прямо в карусели.
    @State private var lessonHackEntries: [(orig: Int, item: SDStepItem)] = []
    /// Оригинальные индексы шагов tip/dialog в `steps.json` (для зачёта урока и счётчиков).
    @State private var tipOriginalIndicesStored: Set<Int> = []
    @State private var lessonStartedAt: Date = Date()
    @State private var frozenLessonDurationText: String? = nil
    @State private var resolvedTitle: String? = nil
    @State private var resolvedLessonId: String = ""
    @State private var resolvedCourseId: String = ""
    // Optional override to swap lesson in-place (used for "Следующий урок")
    @State private var overrideLessonId: String? = nil

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

    private var tipIndices: [Int] { items.indices.filter { items[$0].kind == .tip } }
    private var cardIndices: [Int] { items.indices.filter { items[$0].kind != .tip } }
    private var tipItems: [SDStepItem] { tipIndices.map { items[$0] } }
    private var cardItems: [SDStepItem] { cardIndices.map { items[$0] } }
    /// Две карусели только в полном уроке (не overlay / не фильтр избранного).
    private var hasTwoSegments: Bool {
        !isOverlay && showKinds == nil && !tipItems.isEmpty && !cardItems.isEmpty
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

    /// Локальный UI после сброса. Persistence уже чистит LessonsManager/ProgressManager —
    /// повторный `ProgressManager.reset*` здесь вызывал бесконечный цикл нотификаций и зависание.
    private func applyLocalLessonResetVisuals() {
        // Несколько нотификаций на один сброс — обрабатываем UI один раз в окне guard.
        if isUnderResetGuard {
            anim.learned.removeAll()
            anim.favorites.removeAll()
            return
        }
        anim.learned.removeAll()
        anim.favorites.removeAll()
        let keep = anim.activeIndex
        anim.activeIndex = min(keep, max(0, items.count - 1))
        didSetInitialIndex = true
        rebuildProgressIndexMaps()
        forceColdCarousel()
        progressRenderNonce &+= 1
        beginResetGuard()
        needsPostResetHydrate = true
        schedulePostResetHydrate()
    }

    private func noteMatchesCurrentLesson(_ note: Notification) -> Bool {
        if let lid = note.userInfo?["lessonId"] as? String,
           !resolvedLessonId.isEmpty,
           lid != resolvedLessonId {
            return false
        }
        return true
    }

    private func noteMatchesCurrentCourse(_ note: Notification) -> Bool {
        if let cid = note.userInfo?["courseId"] as? String,
           !resolvedCourseId.isEmpty,
           cid != resolvedCourseId,
           cid != "*" {
            return false
        }
        return true
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
        let cid = resolvedCourseId.isEmpty ? {
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }() : resolvedCourseId
        let lid = resolvedLessonId
        // Progress/Speaker ключуются по `order` из steps.json, не по UI-индексу карусели.
        // НО: `order` — поле из контента и не гарантированно уникально на карточку (два слова в
        // одном уроке иногда авторски помечены одним order). Если это тот случай — пишем по
        // позиции в карусели (`orig`, гарантированно уникальна), иначе один тап красит сразу
        // две карточки при обратной гидратации (см. `hydrateLearnedFromSession`).
        let persistIndex: Int = {
            guard items.indices.contains(stepIndex) else { return stepIndex }
            let order = items[stepIndex].canonicalOrder
            guard order >= 0 else { return originalIndex(for: stepIndex) }
            let sharesOrderWithAnotherCard = items.enumerated().contains { i, it in
                i != stepIndex && isLearnable(it) && it.canonicalOrder == order
            }
            return sharesOrderWithAnotherCard ? originalIndex(for: stepIndex) : order
        }()

        DispatchQueue.main.async {
            ProgressManager.shared.setStepLearned(courseId: cid, lessonId: lid, index: persistIndex, isLearned: nowLearned)
            ProgressManager.shared.markCompletedIfNeeded(
                courseId: cid,
                lessonId: lid,
                totalSteps: learnableCount,
                tipIndexes: tipOriginalIndicesStored
            )
            self.scheduleProgressSnapshot()
        }
    }

    private func hydrateLearnedFromSession() {
        let cid = resolvedCourseId.isEmpty ? {
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }() : resolvedCourseId
        let saved = ProgressManager.shared.learnedSet(courseId: cid, lessonId: resolvedLessonId)
        guard !saved.isEmpty else {
            if !anim.learned.isEmpty { anim.learned = [] }
            return
        }

        // Раньше здесь каждая карточка независимо проверялась сразу по трём пространствам индексов
        // (order/orig/ui) через ИЛИ — если у двух РАЗНЫХ карточек совпадало число в разных
        // пространствах (например order одной == orig другой), обе помечались выученными от
        // одного тапа. Теперь каждое сохранённое значение матчим МАКСИМУМ на одну карточку:
        // строим обратный индекс order->ui и orig->ui (первое совпадение побеждает), затем идём
        // по `saved`, а не по `items` — гарантированно 1:1.
        var uiByOrder: [Int: Int] = [:]
        var uiByOrig: [Int: Int] = [:]
        var uiByLearnableOrdinal: [Int: Int] = [:]
        var learnableOrdinal = 0
        for (ui, item) in items.enumerated() where isLearnable(item) {
            let order = item.canonicalOrder
            if order >= 0, uiByOrder[order] == nil { uiByOrder[order] = ui }
            let orig = originalIndex(for: ui)
            if uiByOrig[orig] == nil { uiByOrig[orig] = ui }
            if uiByLearnableOrdinal[learnableOrdinal] == nil {
                uiByLearnableOrdinal[learnableOrdinal] = ui
            }
            learnableOrdinal += 1
        }

        var uiLearned = Set<Int>()
        for value in saved {
            if let ui = uiByOrder[value] {
                uiLearned.insert(ui)
            } else if let ui = uiByOrig[value] {
                uiLearned.insert(ui)
            } else if let ui = uiByLearnableOrdinal[value] {
                uiLearned.insert(ui)
            } else if items.indices.contains(value), isLearnable(items[value]) {
                uiLearned.insert(value)
            }
        }
        anim.learned = uiLearned
    }

    private func hydrateFavoritesFromManager() {
        let courseId: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        let fm = FavoriteManager.shared
        // Собираем в локальный Set и присваиваем `anim.favorites` ОДИН раз — раньше тут был
        // `removeAll()` + поштучные `insert()` прямо на @Published Set, и каждый вызов гонял
        // отдельный re-render карусели (заметный лаг при быстрых тапах по сердечку).
        var next = Set<Int>()
        for (i, item) in items.enumerated() {
            let oi = originalIndex(for: i)
            if item.kind == .tip {
                // Канон: hack:step:… ; legacy: ошибочно сохранённый step:… тоже считаем.
                if fm.containsHack(courseId: courseId, lessonId: resolvedLessonId, index: oi)
                    || fm.contains(stepId: "step:\(courseId):\(resolvedLessonId):idx\(oi)") {
                    next.insert(i)
                }
                continue
            }
            if fm.contains(step: item, courseId: courseId, lessonId: resolvedLessonId, order: oi) {
                next.insert(i)
                continue
            }
            let legacyId = "step:\(courseId):\(resolvedLessonId):idx\(oi)"
            if fm.contains(stepId: legacyId) {
                next.insert(i)
            }
        }
        if next != anim.favorites {
            anim.favorites = next
        }
    }
    // Map UI (filtered/mapped) index to original raw StepData index using id-stable mapping
    private func originalIndex(for uiIndex: Int) -> Int {
        guard uiIndex >= 0 && uiIndex < items.count else { return uiIndex }
        return uiToOrig[uiIndex] ?? uiIndex
    }

    // Debounced progress snapshot to avoid chatty notifications
    private func scheduleProgressSnapshot(_ delay: TimeInterval = 0.12) {
        // Do not post while we're under a reset guard window
        if isUnderResetGuard { return }
        // Cancel any pending post
        pendingProgressPost?.cancel()
        let work = DispatchWorkItem { [resolvedLessonId] in
            // Double-check lesson is resolved before posting
            guard !resolvedLessonId.isEmpty else { return }
            postStepProgressSnapshot()
        }
        pendingProgressPost = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // Push a snapshot of the current in-lesson progress to LessonsManager/LessonsView
    private func postStepProgressSnapshot() {
        // Compact projection indices for the progress strip
        let learnedIdx = Array(learnedForProgress).sorted()                  // only learnable
        let allIdx = Array(0..<max(0, progressTotal))                        // all progress cells including tips
        // В карусели нет лайфхаков — полоса прогресса без tip-сегментов; счётчик для списка уроков из JSON.
        let hacksIdx: [Int] = []

        // Resolve course id from explicit value or from lesson id prefix
        let cid: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()

        NotificationCenter.default.post(
            name: .stepProgressDidChange,
            object: nil,
            userInfo: [
                "courseId": cid,
                "lessonId": resolvedLessonId,
                // Preferred rich payload with raw indices
                "learnedContent": learnedIdx,
                "allCards": allIdx,
                "lifehacks": hacksIdx,
                // Aggregates for consumers that only need counts
                "learnedCount": learnedIdx.count,
                "totalCount": allIdx.count,
                "lifehackCount": tipOriginalIndicesStored.count
            ]
        )
    }

    private func rebuildProgressIndexMaps() {
        progressMap.removeAll()
        reverseProgressMap.removeAll()
        var p = 0
        for i in items.indices {
            switch items[i].kind {
            case .word, .phrase, .casual:
                progressMap[i] = p
                reverseProgressMap[p] = i
                p += 1
            default:
                // intro/summary/tip (в карусели нет) — не попадают в мини‑бар
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

    /// После удаления `.tip` из карусели: индексы «выучено» и lastStep пересчитываем по `orig` из steps.json.
    private func migrateStorageAfterStrippingCarouselTips(
        courseId: String,
        lessonId: String,
        fullPairs: [(orig: Int, item: SDStepItem)],
        carouselPairs: [(orig: Int, item: SDStepItem)]
    ) {
        guard fullPairs.count > carouselPairs.count else { return }

        let fullItems = fullPairs.map { $0.item }
        var fullUiToOrig: [Int: Int] = [:]
        for (ui, p) in fullPairs.enumerated() { fullUiToOrig[ui] = p.orig }

        let savedLearned = ProgressManager.shared.learnedSet(courseId: courseId, lessonId: lessonId)
        let migratedLearned: Set<Int> = Set(savedLearned.compactMap { oldUi -> Int? in
            guard oldUi >= 0, oldUi < fullItems.count else { return nil }
            switch fullItems[oldUi].kind {
            case .word, .phrase, .casual:
                let o = fullUiToOrig[oldUi]!
                return carouselPairs.firstIndex(where: { $0.orig == o })
            default:
                return nil
            }
        })

        if migratedLearned != savedLearned {
            for oldUi in savedLearned {
                ProgressManager.shared.setStepLearned(courseId: courseId, lessonId: lessonId, index: oldUi, isLearned: false)
            }
            for newUi in migratedLearned {
                ProgressManager.shared.setStepLearned(courseId: courseId, lessonId: lessonId, index: newUi, isLearned: true)
            }
        }

        guard let savedStep = UserSession.shared.lastStepIndex(courseId: courseId, lessonId: lessonId) else { return }
        guard savedStep >= 0, savedStep < fullItems.count else { return }

        let clampCarousel: (Int) -> Int = { max(0, min($0, max(0, carouselPairs.count - 1))) }

        switch fullItems[savedStep].kind {
        case .word, .phrase, .casual, .intro, .summary:
            let o = fullUiToOrig[savedStep]!
            if let nu = carouselPairs.firstIndex(where: { $0.orig == o }) {
                UserSession.shared.setLastStepIndex(courseId: courseId, lessonId: lessonId, index: clampCarousel(nu))
            }
        case .tip:
            let o = fullUiToOrig[savedStep]!
            if let nu = carouselPairs.firstIndex(where: { $0.orig > o }) {
                UserSession.shared.setLastStepIndex(courseId: courseId, lessonId: lessonId, index: clampCarousel(nu))
            } else if let nu = carouselPairs.lastIndex(where: { $0.orig < o }) {
                UserSession.shared.setLastStepIndex(courseId: courseId, lessonId: lessonId, index: clampCarousel(nu))
            }
        }
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
        self.resolvedCourseId = self.courseId ?? {
            let parts = lid.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return ""
        }()
        self.lessonStartedAt = Date()
        // Always resolve from current lid — init `lessonTitle` is only a cold-start fallback
        // (otherwise in-place next-lesson keeps the first lesson's header title).
        self.resolvedTitle = LessonsData.shared.lessonTitle(for: lid) ?? self.lessonTitle
        let raw = StepData.shared.items(for: lid)
        // debug print removed
        // Map StepData.StepItem -> SDStepItem for DS
        let mapped: [SDStepItem] = raw.compactMap { it in
            switch it.kind {
            case .word:
                if let ru = it.ru, let th = it.thai, let ph = it.phonetic {
                    return SDStepItem(kind: .word, titleRU: ru, subtitleTH: th, phonetic: ph, canonicalOrder: it.order)
                }
            case .phrase:
                if let ru = it.ru, let th = it.thai, let ph = it.phonetic {
                    return SDStepItem(kind: .phrase, titleRU: ru, subtitleTH: th, phonetic: ph, canonicalOrder: it.order)
                }
            case .casual:
                if let ru = it.ru, let th = it.thai, let ph = it.phonetic {
                    return SDStepItem(kind: .casual, titleRU: ru, subtitleTH: th, phonetic: ph, canonicalOrder: it.order)
                }
            case .tip:
                if let text = it.text {
                    let title = it.tip ?? "Лайфхак"
                    return SDStepItem(kind: .tip, titleRU: title, subtitleTH: text, phonetic: "", canonicalOrder: it.order)
                }
            case .dialog:
                if let scene = it.scene {
                    return SDStepItem(kind: .tip, titleRU: "Сцена", subtitleTH: scene, phonetic: "", canonicalOrder: it.order)
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

        // Полный урок: лайфхаки снова участвуют в карусели как отдельный тип карточки.
        let carouselPairs: [(orig: Int, item: SDStepItem)] = filteredPairs

        let hackPairs: [(orig: Int, item: SDStepItem)] = {
            if effectiveKinds != nil { return [] }
            return filteredPairs.filter { $0.item.kind == .tip }
        }()

        let cidForMigrate: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = lid.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return lid
        }()

        migrateStorageAfterStrippingCarouselTips(
            courseId: cidForMigrate,
            lessonId: lid,
            fullPairs: filteredPairs,
            carouselPairs: carouselPairs
        )

        self.tipOriginalIndicesStored = Set(raw.compactMap { it -> Int? in
            switch it.kind {
            case .tip, .dialog: return it.order
            default: return nil
            }
        })
        self.lessonHackEntries = hackPairs.map { (orig: $0.orig, item: $0.item) }

        // FM: короткие tips для карточек — по индексам карусели
        var tipsByUI: [Int: String] = [:]
        for (ui, pair) in carouselPairs.enumerated() {
            let orig = pair.orig
            if orig >= 0 && orig < raw.count, let tip = raw[orig].tip, !tip.isEmpty {
                tipsByUI[ui] = tip
            }
        }
        self.itemTips = tipsByUI

        self.items = carouselPairs.map { $0.item }

        var u2o: [Int: Int] = [:]
        var o2u: [Int: Int] = [:]
        for (ui, pair) in carouselPairs.enumerated() {
            u2o[ui] = pair.orig
            o2u[pair.orig] = ui
        }
        self.uiToOrig = u2o
        self.origToUI = o2u

        // Clear any stale learned state before rebuilding progress index maps
        self.anim.learned.removeAll()
        rebuildProgressIndexMaps()
        self.hints = StepData.shared.hints(for: lid)

        // Safety fallback: if no data loaded, inject a tiny demo so DS still renders
        if self.items.isEmpty {
            self.items = [
                .init(kind: .word,   titleRU: "Привет",            subtitleTH: "สวัสดี",                    phonetic: "са-ват-ди́"),
                .init(kind: .phrase, titleRU: "Счёт, пожалуйста",  subtitleTH: "เช็คบิล",                   phonetic: "чек-бин")
            ]
            self.lessonHackEntries = []
            self.tipOriginalIndicesStored = []
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
        let startIdx = hasTwoSegments ? baseStart : normalizeToLearnableIndex(baseStart)

        // Set initial index exactly once and coalesce progress snapshot
        if !didSetInitialIndex {
            if hasTwoSegments {
                if let cardPos = cardIndices.firstIndex(of: normalizeToLearnableIndex(baseStart)) {
                    activeIndexCards = cardPos
                } else {
                    activeIndexCards = 0
                }
                activeIndexTips = 0
                stepSegment = cardItems.isEmpty ? 0 : 1
                let global = stepSegment == 0 ? tipIndices[activeIndexTips] : cardIndices[activeIndexCards]
                self.anim.jump(to: global)
                DispatchQueue.main.async { self.anim.jump(to: global) }
            } else {
                self.anim.jump(to: startIdx)
                DispatchQueue.main.async { self.anim.jump(to: startIdx) }
            }
            self.didSetInitialIndex = true
        }


        self.progressReady = false
        self.progressRenderNonce &+= 1
        // Post snapshot after the view tree binds to the new index
        DispatchQueue.main.async { self.scheduleProgressSnapshot() }
        self.progressReady = true
    }
    // (Old hydrateActiveIndexFromActivity() removed and replaced by hydratedActiveStartIndex())


    /// Строка «Урок» + каноничные filter chips (фразы / лайфхаки).
    @ViewBuilder
    private func stepTitleAndFiltersRow() -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Урок")
                .taikaSectionTitleStyle()
            Spacer(minLength: 8)
            if hasTwoSegments, !tipItems.isEmpty {
                HStack(spacing: 8) {
                    AppFilterChip(
                        title: "фразы",
                        isActive: stepSegment == 1,
                        scale: .xs
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            stepSegment = 1
                        }
                    }
                    AppFilterChip(
                        title: "лайфхаки",
                        isActive: stepSegment == 0,
                        scale: .xs
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                            stepSegment = 0
                        }
                    }
                }
            }
        }
        .padding(.bottom, 2)
    }

    /// Taika FM — тот же атом, что на Main/Profile (`showBubble: false`).
    @ViewBuilder
    private func stepTaikaFMBlock(messages: [String]) -> some View {
        TaikaFMRow(
            scope: .step,
            overrideMessages: messages,
            mode: .typing,
            showBubble: false,
            repeats: true
        )
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
            loop: false,
            compactSection: true
        )
        .environment(\.stepLessonSuppressCardWordmark, false)
        .environment(\.taikaStepActionCaptions, true)
    }

    // Split out to reduce type-checking pressure in the main body
    @ViewBuilder
    private func carouselView() -> some View {
        if hasTwoSegments {
            if stepSegment == 0 {
                stepCarouselOne(
                    items: tipItems,
                    activeIndex: $activeIndexTips,
                    learned: [],
                    favorites: Set(tipIndices.enumerated().filter { anim.favorites.contains(tipIndices[$0.offset]) }.map(\.offset))
                )
            } else {
                stepCarouselOne(
                    items: cardItems,
                    activeIndex: $activeIndexCards,
                    learned: Set(cardIndices.enumerated().filter { anim.learned.contains(cardIndices[$0.offset]) }.map(\.offset)),
                    favorites: Set(cardIndices.enumerated().filter { anim.favorites.contains(cardIndices[$0.offset]) }.map(\.offset))
                )
            }
        } else {
        let activeBinding = Binding<Int>(
            get: { anim.activeIndex },
            set: { anim.activeIndex = $0 }
        )

        SDStepCarousel(
            title: "",
            items: items,
            activeIndex: activeBinding,
            subtitle: nil,
            learned: anim.learned,
            favorites: anim.favorites,
            onTap: { handleTapItem($0) },
            onPlay: { handlePlayItem($0) },
            onFav: { handleFavItem($0) },
            onDone: { handleDoneItem($0) },
            onNext: { handleNextItem($0) },
            isOverlay: isOverlay,
            loop: false,
            compactSection: true
        )
        // Keep step-card top chrome canonical and symmetric in all lesson modes.
        .environment(\.stepLessonSuppressCardWordmark, false)
        .environment(\.taikaStepActionCaptions, true)
        }
    }

    @ViewBuilder
    private func bottomProgressView(proxy: GeometryProxy) -> some View {
        let resetAction: () -> Void = {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let cid = resolvedCourseId
            let lid = resolvedLessonId
            guard !cid.isEmpty, !lid.isEmpty else { return }
            overlay.present(.lessonResetConfirm(courseId: cid, lessonId: lid))
        }

        if hasTwoSegments {
            let total = stepSegment == 0 ? tipItems.count : cardItems.count
            let active = stepSegment == 0 ? activeIndexTips : activeIndexCards
            let indices = stepSegment == 0 ? tipIndices : cardIndices
            let learnedSeg: Set<Int> = stepSegment == 0 ? [] : Set(indices.enumerated().filter { anim.learned.contains(indices[$0.offset]) }.map(\.offset))
            let favoritesSeg: Set<Int> = Set(indices.enumerated().filter { anim.favorites.contains(indices[$0.offset]) }.map(\.offset))
            let tipIndicesSeg: Set<Int> = stepSegment == 0 ? Set(0..<total) : []
            if total > 0 {
                SDStepProgress(
                    total: total,
                    activeIndex: min(active, max(0, total - 1)),
                    learned: learnedSeg,
                    favorites: favoritesSeg,
                    tipIndices: tipIndicesSeg,
                    onTap: { i in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if stepSegment == 0 {
                            activeIndexTips = min(max(0, i), total - 1)
                        } else {
                            activeIndexCards = min(max(0, i), total - 1)
                        }
                    },
                    onReset: stepSegment == 1 ? resetAction : nil
                )
                .id("progress-\(resolvedLessonId)-\(stepSegment)-\(progressRenderNonce)")
                .padding(.bottom, max(proxy.safeAreaInsets.bottom > 0 ? 0 : 4, 4))
            }
        } else if progressTotal > 0 {
            let raw = progressActiveIndexForDisplay()
            let p: Int = raw
            SDStepProgress(
                total: progressTotal,
                activeIndex: p,
                learned: learnedForProgress,
                favorites: favoritesForProgress,
                tipIndices: [],
                onTap: { i in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let original = reverseProgressMap[i] ?? i
                    didSetInitialIndex = true
                    anim.jump(to: original)
                },
                onReset: resetAction
            )
            .id("progress-\(resolvedLessonId)-\(progressRenderNonce)")
            .padding(.bottom, 4)
        }
    }

    // MARK: - Subviews to reduce type-checking pressure


    @ViewBuilder
    private func summaryOverlayView() -> some View {
        let cid: String = {
            if !resolvedCourseId.isEmpty { return resolvedCourseId }
            let parts = resolvedLessonId.split(separator: "_")
            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
            return resolvedLessonId
        }()
        let advance = CourseNavigator.shared.advance(from: cid, lessonId: resolvedLessonId)
        let courseTitle = CourseNavigator.shared.courseTitle(for: cid)
        let lessonsInCourse = CourseNavigator.shared.orderedLessons(in: cid)
        let lessonCount = lessonsInCourse.count
        let coursePhraseTotal = lessonsInCourse.reduce(0) { partial, lid in
            partial + StepData.shared.items(for: lid).filter {
                switch $0.kind {
                case .word, .phrase, .casual: return true
                default: return false
                }
            }.count
        }
        let summaryKind: LessonSummaryKind = {
            switch advance {
            case .nextLesson: return .lesson
            case .nextCourse: return .course
            case .end: return .catalogEnd
            }
        }()
        let isCourseMoment = summaryKind != .lesson

        let config: (title: String, subtitle: String, eyebrow: String?) = {
            switch advance {
            case .nextLesson:
                return ("Урок завершён", "ты продвинулся дальше", nil)
            case .nextCourse:
                return (
                    "Курс пройден",
                    courseTitle,
                    "курс закрыт"
                )
            case .end:
                return (
                    "Трек пройден",
                    "ты закрыл весь путь — красивый момент",
                    "финал"
                )
            }
        }()

        let hacksAccessory: AnyView? = AnyView(
            rewardAccessoryView(
                learnedCount: learnedForProgress.count,
                totalCount: learnableCount,
                lessonCountInCourse: lessonCount,
                coursePhraseTotal: coursePhraseTotal,
                isCourseComplete: isCourseMoment
            )
        )

        let primaryTitle: String = {
            switch advance {
            case .nextLesson(_, let nextId):
                let nextTitle = LessonsData.shared.lessonTitle(for: nextId) ?? "следующий урок"
                return "Дальше: \(nextTitle)"
            case .nextCourse, .end:
                return "Закрепить голосом"
            }
        }()

        let speakerTitle: String = {
            switch advance {
            case .nextCourse:
                return "К следующему курсу"
            case .nextLesson:
                return "Практика в Спикере"
            case .end:
                return "К каталогу курсов"
            }
        }()

        let speakerIcon: String = {
            switch advance {
            case .nextCourse, .end: return "arrow.right"
            case .nextLesson: return "mic.fill"
            }
        }()

        LessonSummaryOverlay(
            title: config.title,
            subtitle: config.subtitle,
            primaryTitle: primaryTitle,
            secondaryTitle: "Игра",
            onPrimary: {
                switch advance {
                case .end:
                    openSpeakerPractice(courseId: cid, lessonId: resolvedLessonId)
                case .nextLesson:
                    prepareNextLessonAndNavigate()
                case .nextCourse:
                    openSpeakerPractice(courseId: cid, lessonId: resolvedLessonId)
                }
            },
            onSecondary: {
                withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                scheduleAuthSoftWallIfNeeded()
                nav.go(.game(courseId: cid, lessonId: resolvedLessonId, gameType: summaryGameMode.rawValue))
            },
            onClose: {
                withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                scheduleAuthSoftWallIfNeeded()
            },
            kind: summaryKind,
            eyebrow: config.eyebrow,
            hacksAccessory: hacksAccessory,
            onSpeakerPractice: {
                switch advance {
                case .nextLesson:
                    openSpeakerPractice(courseId: cid, lessonId: resolvedLessonId)
                case .nextCourse(let nextCourseId, let firstLessonId):
                    navigateToNextCourse(courseId: nextCourseId, lessonId: firstLessonId)
                case .end:
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                    scheduleAuthSoftWallIfNeeded()
                    nav.openCourseCatalog()
                }
            },
            speakerPracticeTitle: speakerTitle,
            speakerPracticeSystemImage: speakerIcon,
            selectedGameMode: isCourseMoment ? nil : summaryGameMode,
            onSelectGameMode: isCourseMoment ? nil : { mode in
                withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                    summaryGameMode = mode
                }
            },
            showGameReinforce: !isCourseMoment,
            lessonDurationText: lessonDurationTextValue(),
            overallProgressText: overallProgressTextValue(courseId: cid, lessonId: resolvedLessonId)
        )
        .scaleEffect(summaryOverlaySettled ? 1.0 : 0.975)
        .opacity(summaryOverlaySettled ? 1.0 : 0.0)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: summaryOverlaySettled)
        .transition(.scale.combined(with: .opacity))
        .zIndex(1)
    }

    @ViewBuilder
    private func rewardAccessoryView(
        learnedCount: Int,
        totalCount: Int,
        lessonCountInCourse: Int,
        coursePhraseTotal: Int,
        isCourseComplete: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isCourseComplete ? "Итог курса" : "Твой результат")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)

            if isCourseComplete {
                HStack(spacing: 10) {
                    rewardMetricPill(
                        title: "\(max(lessonCountInCourse, 1))",
                        subtitle: lessonCountInCourse == 1 ? "урок" : "уроков"
                    )
                    rewardMetricPill(
                        title: "\(max(coursePhraseTotal, learnedCount))",
                        subtitle: "фраз"
                    )
                    rewardMetricPill(
                        title: lessonDurationTextValue(),
                        subtitle: "финал"
                    )
                }
            } else {
                HStack(spacing: 10) {
                    rewardMetricPill(
                        title: "+\(max(learnedCount, 0))",
                        subtitle: learnedCount == 1 ? "слово" : "слов"
                    )

                    rewardMetricPill(
                        title: "\(max(learnedCount, 0))/\(max(totalCount, 0))",
                        subtitle: "урок"
                    )
                }

                HStack(spacing: 10) {
                    rewardMetricPill(
                        title: lessonDurationTextValue(),
                        subtitle: "время"
                    )
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func rewardInsightText(learnedCount: Int, totalCount: Int, lessonTitle: String) -> String {
        let cleanTitle = lessonTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanTitle.isEmpty {
            if learnedCount >= max(totalCount, 1) {
                return "Ты закрыл тему «\(cleanTitle.lowercased())» целиком."
            }
            if learnedCount >= max(1, totalCount / 2) {
                return "Ты уже уверенно идёшь по теме «\(cleanTitle.lowercased())»."
            }
        }

        if learnedCount >= 8 {
            return "Ты уже понимаешь базовые фразы и можешь двигаться дальше."
        }
        if learnedCount >= 4 {
            return "Материал уже знакомый — дальше будет собираться быстрее."
        }
        return "Небольшой шаг тоже считается — дальше станет проще."
    }

    @ViewBuilder
    private func rewardMetricPill(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.taikaStat(24))
                .foregroundStyle(PD.ColorToken.text)
                .monospacedDigit()

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PD.ColorToken.card.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PD.ColorToken.stroke.opacity(0.7), lineWidth: 1)
        )
    }

    private func lessonDurationTextValue() -> String {
        if let frozen = frozenLessonDurationText { return frozen }
        let elapsed = max(0, Int(Date().timeIntervalSince(lessonStartedAt)))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func overallProgressTextValue(courseId: String, lessonId: String) -> String? {
        let trimmed = lessonId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let markerRange = trimmed.range(of: "_l", options: .backwards) else { return nil }
        let afterMarker = trimmed[markerRange.upperBound...]
        let digitSlice = afterMarker.prefix { $0.isNumber }
        guard let currentNumber = Int(digitSlice), !digitSlice.isEmpty else { return nil }

        let coursePrefix = String(trimmed[..<markerRange.lowerBound])
        guard !coursePrefix.isEmpty else { return nil }

        var total = 0
        for idx in 1...50 {
            let probeId = "\(coursePrefix)_l\(idx)"
            if LessonsData.shared.lessonTitle(for: probeId) != nil {
                total = idx
            } else if idx > currentNumber {
                break
            }
        }

        if total <= 0 { return "урок \(currentNumber)" }
        return "урок \(min(currentNumber, total)) из \(total)"
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
        let currentItem: SDStepItem? = items.indices.contains(idx) ? items[idx] : nil
        let stepCardCaption: String? = {
            guard let currentItem, currentItem.kind != .tip else { return nil }
            let ru = currentItem.titleRU.trimmingCharacters(in: .whitespacesAndNewlines)
            return ru.isEmpty ? nil : ru
        }()
        let stepFMMessages = TaikaFMData.shared.messagesForStep(
            tip: currentTipText,
            hints: hints,
            cardText: stepCardCaption
        )
        // Как разминка на Main: заголовок сверху, карусель по центру, прогресс/FM снизу.
        let stack = VStack(spacing: 0) {
            if !isOverlay {
                stepTitleAndFiltersRow()
                    .padding(.horizontal, PD.Spacing.inner)
                    .padding(.top, rootHeaderClearance > 0 ? rootHeaderClearance + 4 : 10)
            } else if rootHeaderClearance > 0 {
                Color.clear
                    .frame(height: rootHeaderClearance)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 8)

            carouselView()
                .frame(maxWidth: .infinity)
                .modifier(StepChrome(isOverlay: isOverlay))
                .animation(.spring(response: 0.32, dampingFraction: 0.88), value: stepSegment)

            if !isOverlay && showBottomProgress {
                bottomProgressView(proxy: proxy)
                    .padding(.top, 8)
            }

            Spacer(minLength: 8)

            if !layoutCardsOnly && !isOverlay {
                stepTaikaFMBlock(messages: stepFMMessages)
                    .padding(.horizontal, PD.Spacing.inner)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        stack
            .animation(.easeInOut(duration: 0.18), value: showLessonSummary)
            .allowsHitTesting(isOverlay ? true : !showLessonSummary)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if useInternalBackground && !isOverlay {
                    PD.ColorToken.background
                        .ignoresSafeArea()
                }
                stepMainContent(proxy)
                if showLessonSummary {
                    Theme.Surfaces.blackGlassScrim
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                    summaryOverlayView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: showLessonSummary) { _, isOn in
                if isOn {
                    frozenLessonDurationText = lessonDurationTextValue()
                    stepManager.stepHeaderTimerText = frozenLessonDurationText ?? "0:00"
                    summaryGameMode = .match
                    summaryOverlaySettled = false
#if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        if showLessonSummary {
                            summaryOverlaySettled = true
                        }
                    }
                } else {
                    frozenLessonDurationText = nil
                    summaryOverlaySettled = false
                }
            }
            .onAppear {
                GameHeaderStore.shared.config = nil
                isMounted = true
                summaryOverlaySettled = !showLessonSummary
                // debug print removed
                loadFromStepData()
                if !isOverlay && !resolvedCourseId.isEmpty {
                    UserSession.shared.markActive(courseId: resolvedCourseId, lessonId: resolvedLessonId)
                }
                needsPostResetHydrate = false
                // Hydration now handled inside loadFromStepData()
                // DispatchQueue.main.async { hydrateLearnedFromSession() }
                // DispatchQueue.main.async { hydrateFavoritesFromManager() }
                // Safety net: ensure snapshot after appear
                syncStepHeaderSegmentState()
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                guard !isOverlay, isMounted, !showLessonSummary else { return }
                stepManager.stepHeaderTimerText = lessonDurationTextValue()
            }
            .onChange(of: hasTwoSegments) { _, _ in
                syncStepHeaderSegmentState()
            }
            .onChange(of: tipItems.count) { _, _ in
                if hasTwoSegments, !isOverlay { stepManager.stepHeaderTipCount = tipItems.count }
            }
            .onChange(of: cardItems.count) { _, _ in
                if hasTwoSegments, !isOverlay { stepManager.stepHeaderCardCount = cardItems.count }
            }
            .onChange(of: stepManager.stepHeaderSegment) { _, newValue in
                guard hasTwoSegments, !isOverlay else { return }
                if stepSegment != newValue { stepSegment = newValue }
            }
            .onChange(of: stepSegment) { _, newValue in
                guard hasTwoSegments, !isOverlay else { return }
                if stepManager.stepHeaderSegment != newValue {
                    stepManager.stepHeaderSegment = newValue
                }
            }
            .onChange(of: activeIndexTips) { _, newValue in
                guard hasTwoSegments, stepSegment == 0, tipIndices.indices.contains(newValue) else { return }
                anim.jump(to: tipIndices[newValue])
            }
            .onChange(of: activeIndexCards) { _, newValue in
                guard hasTwoSegments, stepSegment == 1, cardIndices.indices.contains(newValue) else { return }
                anim.jump(to: cardIndices[newValue])
            }
            .onChange(of: startIndex) { newStart in
                // Prevent re-initialization after the first application of startIndex
                guard !didSetInitialIndex else { return }
                guard let s = newStart, !items.isEmpty else { return }
                let clamped = max(0, min(s, max(0, items.count - 1)))
                if anim.activeIndex != clamped {
                    anim.jump(to: clamped)
                    didSetInitialIndex = true
                }
            }
            .onChange(of: anim.activeIndex) { newValue in
                guard isMounted else { return }
                guard didSetInitialIndex else { return }
                guard progressReady else { return }
                guard !items.isEmpty else { return }
                if !isOverlay {
                    // Debounce persisting last step index to avoid chatty writes while scrolling
                    pendingIndexPersist?.cancel()
                    let clamped: Int = {
                        if hasTwoSegments, stepSegment == 1, cardIndices.indices.contains(activeIndexCards) {
                            return cardIndices[activeIndexCards]
                        }
                        return max(0, min(newValue, max(0, items.count - 1)))
                    }()
                    let work = DispatchWorkItem {
                        let cid: String = {
                            if !resolvedCourseId.isEmpty { return resolvedCourseId }
                            let parts = resolvedLessonId.split(separator: "_")
                            if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                            return resolvedLessonId
                        }()
                        UserSession.shared.setLastStepIndex(courseId: cid, lessonId: resolvedLessonId, index: clamped)
                    }
                    pendingIndexPersist = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
                }
            }
            .safeAreaInset(edge: .top) {
                // Показывать по флагу даже при scope == .overlay: локальные navigationDestination не в nav.path,
                // иначе нет ни системного back, ни строки AppHeader «назад».
                if showInternalHeader {
                    AppBackHeader {
                        if let onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    }
                    .padding(.horizontal, PD.Spacing.inner)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarBackButtonHidden(true)
            .onDisappear {
                GameHeaderStore.shared.config = nil
                isMounted = false
                pendingFavoriteHydrate?.cancel()
                stepManager.stepHeaderShowsSegment = false
                stepManager.stepHeaderTipCount = 0
                stepManager.stepHeaderCardCount = 0
                stepManager.stepHeaderLessonTitle = ""
                stepManager.stepHeaderTimerText = ""
            }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: .lessonProgressDidReset)) { note in
                guard noteMatchesCurrentLesson(note) else { return }
                applyLocalLessonResetVisuals()
            }
            // Listen to namespaced course progress reset notification
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LessonsManager.courseProgressDidReset"))) { note in
                guard noteMatchesCurrentCourse(note) else { return }
                applyLocalLessonResetVisuals()
            }
            // Listen to namespaced lesson progress reset notification
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LessonsManager.lessonProgressDidReset"))) { note in
                guard noteMatchesCurrentLesson(note) else { return }
                applyLocalLessonResetVisuals()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("stepLocalStateShouldReset"))) { note in
                // scope: "all" | "course" | "lesson"
                let scope = (note.userInfo?["scope"] as? String) ?? "all"
                switch scope {
                case "lesson":
                    guard noteMatchesCurrentLesson(note) else { return }
                case "course":
                    guard noteMatchesCurrentCourse(note) else { return }
                default:
                    break
                }
                applyLocalLessonResetVisuals()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("stepProgressDidReset"))) { note in
                if let cidNote = note.userInfo?["courseId"] as? String,
                   !resolvedCourseId.isEmpty,
                   cidNote != resolvedCourseId { return }
                if let lidNote = note.userInfo?["lessonId"] as? String,
                   !resolvedLessonId.isEmpty,
                   lidNote != resolvedLessonId { return }
                applyLocalLessonResetVisuals()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("usCourseProgressDidReset"))) { note in
                guard noteMatchesCurrentCourse(note) else { return }
                applyLocalLessonResetVisuals()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("usLessonProgressDidReset"))) { note in
                guard noteMatchesCurrentLesson(note) else { return }
                applyLocalLessonResetVisuals()
            }
            .onReceive(NotificationCenter.default.publisher(for: .progressDidChange)) { _ in
                // No-op on in-lesson progress changes to avoid resetting the carousel and causing a jump-from-first illusion.
                // We already keep local `anim.learned` in sync on toggle; progress strip reads from it directly.
            }
            .onReceive(NotificationCenter.default.publisher(for: .progressCourseDidReset)) { note in
                guard noteMatchesCurrentCourse(note) else { return }
                applyLocalLessonResetVisuals()
            }
            .onReceive(NotificationCenter.default.publisher(for: .progressLessonDidReset)) { note in
                guard noteMatchesCurrentLesson(note) else { return }
                applyLocalLessonResetVisuals()
            }
            // Только $items: и так обновляется при любом изменении избранного; второй подписчик дублировал hydrate и давал лишний кадр лагов.
            .onReceive(favManager.$items) { _ in
                guard isMounted else { return }
                if Date() >= suppressFavoriteHydrationUntil {
                    hydrateFavoritesFromManager()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stepProgressDidChange)) { note in
                guard !isOverlay else { return }
                // Global notification: only react for this lesson (avoids summary/layout work on every tap app-wide).
                if let u = note.userInfo as? [String: Any],
                   let nCourse = u["courseId"] as? String,
                   let nLesson = u["lessonId"] as? String,
                   !resolvedLessonId.isEmpty {
                    let myCourse = resolvedCourseId.isEmpty ? {
                        let parts = resolvedLessonId.split(separator: "_")
                        if parts.count > 1 { return parts.dropLast().joined(separator: "_") }
                        return resolvedLessonId
                    }() : resolvedCourseId
                    func norm(_ s: String) -> String {
                        s.trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "_", with: "-")
                            .lowercased()
                    }
                    if norm(nCourse) != norm(myCourse) || norm(nLesson) != norm(resolvedLessonId) {
                        return
                    }
                }
                // If all learnable cards are done, show the canonical summary overlay
                let totalLearnable = learnableCount
                if totalLearnable > 0 {
                    let learnedNowCount = anim.learned.filter { idx in
                        guard idx >= 0 && idx < items.count else { return false }
                        switch items[idx].kind {
                        case .word, .phrase, .casual:
                            return true
                        default:
                            return false
                        }
                    }.count
                    if learnedNowCount >= totalLearnable {
                        if !didShowSummaryOnce {
                            didShowSummaryOnce = true
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                showLessonSummary = true
                            }
                        }
                    } else {
                        // Progress is no longer full → allow the summary to appear again on the next completion
                        didShowSummaryOnce = false
                        if showLessonSummary {
                            withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                        }
                    }
                }
            }
        }
    }

    private func syncStepHeaderSegmentState() {
        guard !isOverlay else {
            stepManager.stepHeaderShowsSegment = false
            stepManager.stepHeaderLessonTitle = ""
            stepManager.stepHeaderTimerText = ""
            return
        }
        // Чипы сегмента — в теле рядом с «Урок»; в shell — название + таймер.
        stepManager.stepHeaderShowsSegment = false
        stepManager.stepHeaderTipCount = tipItems.count
        stepManager.stepHeaderCardCount = cardItems.count
        if hasTwoSegments {
            stepManager.stepHeaderSegment = stepSegment
        }
        let title: String = {
            if let t = resolvedTitle, !t.isEmpty { return t }
            if !resolvedLessonId.isEmpty,
               let t = LessonsData.shared.lessonTitle(for: resolvedLessonId),
               !t.isEmpty {
                return t
            }
            return "Урок"
        }()
        stepManager.stepHeaderLessonTitle = title
        stepManager.stepHeaderTimerText = lessonDurationTextValue()
    }

    private func index(of item: SDStepItem) -> Int? {
        items.firstIndex(where: { $0.id == item.id })
    }

    // MARK: - Handlers extracted to reduce type-checking complexity
    private func handleTapItem(_ item: SDStepItem) {
        if let i = index(of: item) {
            if item.kind == .tip {
                if hasTwoSegments, stepSegment == 0 {
                    if activeIndexTips + 1 < tipItems.count {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        activeIndexTips += 1
                    }
                    return
                }
                if i + 1 < items.count {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        anim.jump(to: i + 1)
                    }
                }
                return
            }
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

    /// Тайская строка для озвучки без латиницы в скобках (как в карточке).
    private func thaiLineForSpeech(from item: SDStepItem) -> String {
        let raw = item.subtitleTH.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        if let open = raw.firstIndex(of: "("), open > raw.startIndex {
            return String(raw[..<open]).trimmingCharacters(in: .whitespaces)
        }
        return raw
    }

    private func handleFavItem(_ item: SDStepItem) {
        guard let i = index(of: item) else { return }
        let wasFavorite = anim.favorites.contains(i)
        let fav = makeStepFav(for: item, index: i)
        pendingFavoriteHydrate?.cancel()
        suppressFavoriteHydrationUntil = Date().addingTimeInterval(0.35)
        // instant local UI feedback to avoid visual lag
        if wasFavorite {
            anim.favorites.remove(i)
        } else {
            anim.favorites.insert(i)
        }
        // На следующем тике main: FM пишет синхронно — сердце не сбросится hydrate'ом.
        DispatchQueue.main.async {
            StepManager.shared.toggleFavorite(fav)
            guard self.isMounted else { return }
            self.suppressFavoriteHydrationUntil = .distantPast
            self.hydrateFavoritesFromManager()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Есть ли ещё невыученные учебные карточки (кроме `excluding`).
    private func hasUnlearnedCards(excluding uiIndex: Int) -> Bool {
        let learnable = cardIndices.isEmpty
            ? items.indices.filter { idx in
                switch items[idx].kind { case .word, .phrase, .casual: return true; default: return false }
            }
            : cardIndices
        return learnable.contains { $0 != uiIndex && !anim.learned.contains($0) }
    }

    /// Следующая невыученная по кругу после текущей (с середины урока → к началу).
    private func advanceToNextUnlearned(afterUIIndex i: Int) {
        let learnableUI: [Int] = {
            if hasTwoSegments, !cardIndices.isEmpty { return cardIndices }
            return items.indices.filter { idx in
                switch items[idx].kind { case .word, .phrase, .casual: return true; default: return false }
            }
        }()
        guard !learnableUI.isEmpty else { return }
        guard let startPos = learnableUI.firstIndex(of: i) else {
            if hasTwoSegments, stepSegment == 1, let firstUnlearned = learnableUI.first(where: { !anim.learned.contains($0) }),
               let pos = cardIndices.firstIndex(of: firstUnlearned) {
                activeIndexCards = pos
            }
            return
        }
        let n = learnableUI.count
        for offset in 1...n {
            let candidate = learnableUI[(startPos + offset) % n]
            if !anim.learned.contains(candidate) {
                if hasTwoSegments, stepSegment == 1, let pos = cardIndices.firstIndex(of: candidate) {
                    activeIndexCards = pos
                } else {
                    anim.jump(to: candidate)
                }
                return
            }
        }
    }

    private func handleDoneItem(_ item: SDStepItem) {
        switch item.kind {
        case .word, .phrase, .casual:
            // Respect read-only flows (e.g., Favorites overlay)
            guard allowLearning else { return }
            guard let i = index(of: item) else {
                return
            }
            let wasLearned = anim.learned.contains(i)
            anim.toggleLearned(i)
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
                pendingLearnAdvanceToken = nil
                didShowSummaryOnce = false
                if showLessonSummary {
                    withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
                }
            }
            // Обучение: при «запомнил» сначала закрепляем слухом, затем листаем — только после конца TTS.
            if !wasLearned && nowLearned {
                let thai = thaiLineForSpeech(from: item)
                let shouldAdvance = i < items.count - 1 || hasUnlearnedCards(excluding: i)
                let advanceToken = UUID()
                pendingLearnAdvanceToken = advanceToken

                let advanceIfStillCurrent = {
                    guard self.isMounted else { return }
                    guard self.pendingLearnAdvanceToken == advanceToken else { return }
                    self.pendingLearnAdvanceToken = nil
                    guard shouldAdvance else { return }
                    self.advanceToNextUnlearned(afterUIIndex: i)
                }

                if thai.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: advanceIfStillCurrent)
                } else {
                    StepAudio.shared.speakThai(thai, stepItemId: item.id) {
                        // Короткая пауза после фразы — карточка не прыгает поверх голоса.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: advanceIfStillCurrent)
                    }
                }
            }
            // Show summary only when user completes ALL learnable cards (transition from not-all to all)
            let totalLearnable = learnableCount
            let learnedNowCount = anim.learned.filter { idx in
                guard idx >= 0 && idx < items.count else { return false }
                switch items[idx].kind { case .word, .phrase, .casual: return true; default: return false }
            }.count
            if !wasLearned && nowLearned && totalLearnable > 0 && learnedNowCount >= totalLearnable && !didShowSummaryOnce {
                didShowSummaryOnce = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        showLessonSummary = true
                    }
                }
            } else {
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
        default:
            break
        }
    }

    private func handleNextItem(_ item: SDStepItem) {
        // Карусель сама двигает activeIndex (goNext / свайп / CTA «далее»).
        // Раньше здесь был ещё один +1 → «запомнил»/свайп перескакивали через карточку.
        _ = item
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showLessonSummary = false }
            scheduleAuthSoftWallIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                didSetInitialIndex = false
                didShowSummaryOnce = false
                frozenLessonDurationText = nil
                stepSegment = 1
                activeIndexTips = 0
                activeIndexCards = 0
                overrideLessonId = nextId
                anim.learned.removeAll(); anim.favorites.removeAll()
                loadFromStepData()
                syncStepHeaderSegmentState()
                if !resolvedCourseId.isEmpty {
                    UserSession.shared.markActive(courseId: resolvedCourseId, lessonId: resolvedLessonId)
                }
            }
        case .nextCourse(let nextCourseId, let firstLesson):
            navigateToNextCourse(courseId: nextCourseId, lessonId: firstLesson)
        case .end:
            withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
            scheduleAuthSoftWallIfNeeded()
        }
    }

    /// Same chrome as AppShell.continueLearning: pop current lesson, push next course via canonical routes.
    private func navigateToNextCourse(courseId: String, lessonId: String) {
        _ = StepData.shared.items(for: lessonId)
        let leavingCourseId = resolvedCourseId
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) { showLessonSummary = false }
        scheduleAuthSoftWallIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            // In-place next-lesson keeps the first lesson id on the stack — always pop by course.
            while let last = nav.path.last {
                if case .game = last {
                    nav.path.removeLast()
                    continue
                }
                if case .lesson(let c, _, _) = last,
                   !leavingCourseId.isEmpty,
                   c == leavingCourseId {
                    nav.path.removeLast()
                    continue
                }
                break
            }
            if case .lessons(let oldCid) = nav.path.last,
               !leavingCourseId.isEmpty,
               oldCid == leavingCourseId {
                nav.path.removeLast()
            }
            nav.go(.lessons(courseId: courseId))
            nav.go(.lesson(courseId: courseId, lessonId: lessonId, presentation: .canonical))
        }
    }

    private func openSpeakerPractice(courseId: String, lessonId: String) {
        UserSession.shared.markActive(courseId: courseId, lessonId: lessonId, stepIndex: 0)
        NotificationCenter.default.post(name: Notification.Name("Step.progressDidChange"), object: nil)
        SpeakerManager.shared.rebuildQueue()
        SpeakerManager.shared.setSpeakerUIMode(.training)
        SpeakerRequestedCourseId.shared.set(courseId, lessonId: lessonId)
        withAnimation(.easeInOut(duration: 0.2)) { showLessonSummary = false }
        scheduleAuthSoftWallIfNeeded()
        nav.requestTab(2)
    }

    /// Отложенный soft wall «Закрепи результат» после закрытия summary урока.
    private func scheduleAuthSoftWallIfNeeded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            Task { @MainActor in
                ProgressManager.shared.refreshProfileState()
                AuthSoftWallState.tryPresentSoftWall()
            }
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
            NavigationStack {
                StepView(
                    courseId: "course_b_1",
                    lessonId: "course_b_1_l1",
                    lessonTitle: "ПРИВЕТСТВИЯ",
                    scope: .full,
                    layoutCardsOnly: false,
                    allowLearning: true,
                    showBottomProgress: true,
                    showInternalHeader: false
                )
            }
            .previewDisplayName("step · full (canonical, shell-style header)")

            // тот же урок, но в overlay-режиме, как когда тянем секцию из других экранов
            NavigationStack {
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
            }
            .previewDisplayName("step · overlay (cards section)")
        }
        .environmentObject(NavigationIntent())
        .environmentObject(OverlayPresenter.shared)
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
