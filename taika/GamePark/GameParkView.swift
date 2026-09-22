import SwiftUI

@MainActor
final class GameParkHubState: ObservableObject {
    static let shared = GameParkHubState()

    @Published var selectedCourseId: String = LearnedGameSource.pseudoCourseId
    @Published var selectedMode: GameModeType = .match

    func preselect(_ courseId: String) {
        let id = courseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        selectedCourseId = id
    }
}

struct GameParkView: View {
    @EnvironmentObject private var nav: NavigationIntent
    @EnvironmentObject private var overlay: OverlayPresenter
    @ObservedObject private var pro = ProManager.shared
    @ObservedObject private var hub = GameParkHubState.shared
    @ObservedObject private var main = MainManager.shared

    private struct DeckOption: Identifiable {
        let id: String
        let title: String
        let playable: Bool
    }

    private var learnedPlayable: Bool { LearnedGameSource.hasPlayableCards }
    private var favoritesPlayable: Bool { !FavoritesGameSource.triples().isEmpty }
    private var dictionaryPlayable: Bool { DictionaryGameSource.hasPlayableCards }

    private var deckOptions: [DeckOption] {
        var options: [DeckOption] = [
            DeckOption(id: LearnedGameSource.pseudoCourseId, title: "Выученное", playable: learnedPlayable),
            DeckOption(id: "__favorites__", title: "Избранное", playable: favoritesPlayable),
            DeckOption(id: DictionaryGameSource.courseId, title: "Словарь", playable: dictionaryPlayable)
        ]
        for card in main.reinforcementCourseCards {
            options.append(DeckOption(
                id: card.courseId,
                title: card.title,
                playable: courseHasPlayableCards(card.courseId)
            ))
        }
        return options
    }

    private var playableDeckOptions: [DeckOption] {
        deckOptions.filter(\.playable)
    }

    private var hasAnyPlayable: Bool {
        !playableDeckOptions.isEmpty
    }

    private var selectedIsPlayable: Bool {
        deckPlayable(hub.selectedCourseId)
    }

    private var selectedCardCount: Int {
        triplesCount(for: hub.selectedCourseId)
    }

    private var modeLocked: Bool {
        hub.selectedMode.isPro && !pro.isPro
    }

    private var canStart: Bool {
        hasAnyPlayable && selectedIsPlayable && !modeLocked
    }

    private var selectedDeckTitle: String {
        deckOptions.first(where: { $0.id == hub.selectedCourseId })?.title ?? "Колода"
    }

    private var guideLines: [String] {
        if !hasAnyPlayable {
            return [
                "Сначала выучи фразы",
                "Потом закрепишь их здесь"
            ]
        }
        if !selectedIsPlayable {
            return [
                "В этой колоде пока пусто",
                "Выбери другую колоду"
            ]
        }
        if modeLocked {
            return [
                "Этот режим — Taika Pro",
                "Открой подписку или выбери «Найди пару»"
            ]
        }
        return [
            "Выбери режим игры",
            "\(selectedCardCount) \(cardWord(selectedCardCount)) · \(selectedDeckTitle)"
        ]
    }

    private var modeChipItems: [TaikaNeutralChipItem] {
        GameModeType.modesLessonAndPark.map { mode in
            let locked = mode.isPro && !pro.isPro
            return TaikaNeutralChipItem(
                id: mode.rawValue,
                title: mode.title,
                isSelected: hub.selectedMode == mode,
                isEnabled: true,
                trailingIcon: locked ? "crown.fill" : nil
            )
        }
    }

    private var deckGhostMenuOptions: [TaikaHubGhostMenuOption] {
        deckOptions.map { deck in
            TaikaHubGhostMenuOption(
                id: deck.id,
                title: deck.title,
                isSelected: hub.selectedCourseId == deck.id,
                isEnabled: deck.playable
            )
        }
    }

    private var deckGhostTitle: String {
        guard hasAnyPlayable else { return "Выбери колоду" }
        return "\(selectedDeckTitle) · \(selectedCardCount) \(cardWord(selectedCardCount))"
    }

    var body: some View {
        VStack(spacing: 0) {
            TaikaScreenPageTitle(title: "Закрепление")
                .padding(.top, 4)

            TaikaAssistantHub(
                lines: guideLines,
                assembleGateKey: "tab.gamepark",
                layout: .mainEmbedded,
                primaryCTA: hubPrimaryCTA,
                showsGhostSlot: true,
                bottomInset: Theme.Layout.bottomToolbarHeight + 12
            ) {
                TaikaAssemblingPlanet(
                    gateKey: "tab.gamepark",
                    scale: 0.72,
                    centerSymbol: "gamecontroller.fill",
                    inviteTap: canStart,
                    palette: .console,
                    idleAccent: canStart ? 0.58 : 0.42,
                    frameSize: 220
                )
                .accessibilityLabel(canStart ? "Закрепление" : "Закрепление недоступно")
                .accessibilityHint(guideLines.first ?? "")
            } chipZone: {
                TaikaNeutralChipRow(items: modeChipItems) { id in
                    guard let mode = GameModeType(rawValue: id) else { return }
                    if mode.isPro && !pro.isPro {
                        overlay.presentPro(reason: .games)
                        return
                    }
                    hub.selectedMode = mode
                }
            } ghostSlot: {
                TaikaHubGhostMenu(
                    icon: "square.stack.3d.up.fill",
                    title: deckGhostTitle,
                    options: deckGhostMenuOptions
                ) { id in
                    hub.selectedCourseId = id
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, Theme.Layout.rootHeaderClearance)
        .background(PD.ColorToken.background.ignoresSafeArea())
        .onAppear {
            Task { await main.reloadReinforcementCourseCards() }
            normalizeSelection()
        }
        .onChange(of: hub.selectedCourseId) { _, _ in
            normalizeSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ProgressDidChange"))) { _ in
            Task { await main.reloadReinforcementCourseCards() }
            normalizeSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FavoritesDidChange"))) { _ in
            normalizeSelection()
        }
    }

    private var hubPrimaryCTA: TaikaAssistantHubPrimaryCTA {
        if !hasAnyPlayable {
            return TaikaAssistantHubPrimaryCTA(
                title: "К курсам",
                accent: Color(red: 0.96, green: 0.68, blue: 0.18),
                action: { nav.openCourseCatalog(tab: .base) }
            )
        }
        return TaikaAssistantHubPrimaryCTA(
            title: "Начать закрепление",
            isEnabled: canStart,
            accent: Color(red: 0.96, green: 0.68, blue: 0.18),
            action: startIfPossible
        )
    }

    private func startIfPossible() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard hasAnyPlayable else {
            nav.openCourseCatalog(tab: .base)
            return
        }
        normalizeSelection()
        guard selectedIsPlayable else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        if modeLocked {
            overlay.presentPro(reason: .games, courseId: hub.selectedCourseId)
            return
        }
        nav.set(.game(
            courseId: hub.selectedCourseId,
            lessonId: nil,
            gameType: hub.selectedMode.rawValue
        ))
    }

    private func normalizeSelection() {
        if deckPlayable(hub.selectedCourseId) { return }
        if learnedPlayable {
            hub.selectedCourseId = LearnedGameSource.pseudoCourseId
            return
        }
        if favoritesPlayable {
            hub.selectedCourseId = "__favorites__"
            return
        }
        if dictionaryPlayable {
            hub.selectedCourseId = DictionaryGameSource.courseId
            return
        }
        if let first = playableDeckOptions.first {
            hub.selectedCourseId = first.id
        }
    }

    private func deckPlayable(_ courseId: String) -> Bool {
        if LearnedGameSource.isPseudoCourseId(courseId) { return learnedPlayable }
        if courseId == "__favorites__" { return favoritesPlayable }
        if DictionaryGameSource.isDictionaryCourseId(courseId) { return dictionaryPlayable }
        return courseHasPlayableCards(courseId)
    }

    private func triplesCount(for courseId: String) -> Int {
        if LearnedGameSource.isPseudoCourseId(courseId) {
            return LearnedGameSource.triples().count
        }
        if courseId == "__favorites__" {
            return FavoritesGameSource.triples().count
        }
        if DictionaryGameSource.isDictionaryCourseId(courseId) {
            return DictionaryGameSource.triples().count
        }
        return HomeTaskManager().userTriplesForCourse(
            courseId: courseId,
            lessonIds: lessonIds(for: courseId)
        ).count
    }

    private func courseHasPlayableCards(_ courseId: String) -> Bool {
        let ids = lessonIds(for: courseId)
        guard !ids.isEmpty else { return false }
        return !HomeTaskManager().userTriplesForCourse(courseId: courseId, lessonIds: ids).isEmpty
    }

    private func lessonIds(for courseId: String) -> [String] {
        var lessons = LessonsData.shared.lessons(for: courseId)
        if lessons.isEmpty {
            lessons = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "_", with: "-"))
        }
        if lessons.isEmpty {
            lessons = LessonsData.shared.lessons(for: courseId.replacingOccurrences(of: "-", with: "_"))
        }
        return lessons.map(\.lessonID)
    }

    private func cardWord(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 14 { return "карточек" }
        switch mod10 {
        case 1: return "карточка"
        case 2, 3, 4: return "карточки"
        default: return "карточек"
        }
    }
}
