import UIKit
import SwiftUI

#if DEBUG
struct FavoriteView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FavoriteView()
                .environmentObject(ThemeManager.shared)
                .environmentObject(NavigationIntent())
                .environmentObject(OverlayPresenter.shared)
        }
    }
}
#endif

/// Состояние таба избранного (оверлей фильтров / deep link).
@MainActor
public final class FavoritesFilterState: ObservableObject {
    public static let shared = FavoritesFilterState()
    @Published public var selectedTab: FavoriteScreenTab = .cards
    /// Шапка Избранного открывает карусель всех сохранённых лайфхаков, не третью вкладку.
    @Published public var showSavedLifehacks = false
    private init() {}
}

struct FavoriteView: View {
    @EnvironmentObject private var nav: NavigationIntent
    @EnvironmentObject private var overlay: OverlayPresenter
    private let pro = ProManager.shared
    @StateObject private var manager = FavoriteManager.shared
    @ObservedObject private var favFilter = FavoritesFilterState.shared

    @State private var selectedTab: FavoriteScreenTab = .cards
    @State private var isEditing: Bool = false
    @State private var isTrainingPickerPresented: Bool = false
    @State private var selectedTrainingGameMode: GameModeType = .match

    @AppStorage(FavCardsViewMode.storageKey) private var viewModeRaw: String = FavCardsViewMode.list.rawValue

    private var cardsList: [FDCardDTO] {
        manager.cardsDTO
            .filter { !canonicalId($0).lowercased().hasPrefix("hack:") }
            .sorted { $0.addedAt > $1.addedAt }
    }

    private var dictionaryList: [FDCardDTO] {
        manager.smartSpeakerDictionaryCardsDTO
    }

    private var bottomContentInset: CGFloat {
        ToolBar.recommendedBottomInset + 8
    }

    private var showsViewModeToggle: Bool {
        selectedTab == .cards || selectedTab == .dictionary
    }

    private var activeViewMode: Binding<FavCardsViewMode> {
        Binding(
            get: { FavCardsViewMode(rawValue: viewModeRaw) ?? .list },
            set: { viewModeRaw = $0.rawValue }
        )
    }

    private var currentEmptySpec: FavEmptySpec? {
        switch selectedTab {
        case .cards where cardsList.isEmpty:
            return FavEmptySpec(
                systemImage: "heart",
                assembleGateKey: "tab.favorites.cards",
                lines: [
                    "Собери свои фразы",
                    "Лайкни первую в уроке — она появится здесь"
                ],
                primaryCTA: TaikaAssistantHubPrimaryCTA(
                    title: "К урокам",
                    accent: Color(red: 0.28, green: 0.72, blue: 0.98),
                    action: openCoursesBase
                )
            )
        case .dictionary where dictionaryList.isEmpty:
            return FavEmptySpec(
                systemImage: "bookmark",
                assembleGateKey: "tab.favorites.dictionary",
                lines: [
                    "Свои слова под рукой",
                    "Скажи фразу и сохрани — она появится здесь"
                ],
                primaryCTA: TaikaAssistantHubPrimaryCTA(
                    title: "Добавить фразу",
                    icon: "plus.circle.fill",
                    action: openOwnSpeech
                )
            )
        default:
            return nil
        }
    }

    private var showsBottomTrainingBar: Bool {
        switch selectedTab {
        case .cards: return !cardsList.isEmpty
        case .dictionary: return !dictionaryList.isEmpty
        default: return false
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PD.ColorToken.background.ignoresSafeArea()

            VStack(spacing: 0) {
                favoritesScreenHeader()

                if let empty = currentEmptySpec {
                    favEmptyState(
                        systemImage: empty.systemImage,
                        lines: empty.lines,
                        assembleGateKey: empty.assembleGateKey,
                        primaryCTA: empty.primaryCTA,
                        onSelectCourse: openFavoriteCourse
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TaikaRootVerticalScroll {
                        VStack(spacing: 0) {
                            favoritesCollectionSummary()
                                .padding(.horizontal, CD.Spacing.screen)
                                .padding(.top, 6)
                                .padding(.bottom, 8)

                            favoritesTabContent()
                                .frame(maxWidth: .infinity, alignment: .topLeading)

                            // The training CTA is pinned above the app toolbar; keep scroll content clear of it.
                            Spacer(minLength: showsBottomTrainingBar ? ToolBar.recommendedBottomInset + 104 : bottomContentInset)
                        }
                    }
                    .environment(\.taikaRootHeaderClearance, 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding(.top, Theme.Layout.rootHeaderClearance)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.34)) {
                    ThemeManager.shared.hubAtmosphere = .favorites
                }
            }

            if showsBottomTrainingBar {
                favoritesTrainingCTA()
                    .padding(.horizontal, CD.Spacing.screen)
                    .padding(.bottom, ToolBar.recommendedBottomInset + 10)
                    .padding(.top, 12)
                    .background(
                        LinearGradient(
                            colors: [PD.ColorToken.background.opacity(0), PD.ColorToken.background.opacity(0.96)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    )
            }

            if isTrainingPickerPresented {
                GameModePickerDS(
                    selected: $selectedTrainingGameMode,
                    isProUser: pro.isPro,
                    onStart: { mode in
                        isTrainingPickerPresented = false
                        startFavoritesGame(mode: mode)
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                            isTrainingPickerPresented = false
                        }
                    },
                    onLockedTap: { mode in
                        if mode.isPro && !pro.isPro {
                            isTrainingPickerPresented = false
                            overlay.presentPro(reason: .games)
                        }
                    },
                    modes: GameModeType.modesLessonAndPark,
                    onSpeaker: {
                        isTrainingPickerPresented = false
                        trainCurrentTabInSpeaker()
                    }
                )
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isTrainingPickerPresented)
        .onAppear {
            FavCardsViewMode.migrateStorageIfNeeded()
            if favFilter.selectedTab == .hacks || favFilter.selectedTab == .courses {
                favFilter.selectedTab = .cards
            }
            selectedTab = favFilter.selectedTab
            StepData.shared.preload()
        }
        .onChange(of: selectedTab) { _, newValue in
            let normalized: FavoriteScreenTab = (newValue == .hacks || newValue == .courses) ? .cards : newValue
            if selectedTab != normalized {
                selectedTab = normalized
                return
            }
            if favFilter.selectedTab != normalized {
                favFilter.selectedTab = normalized
            }
        }
        .sheet(isPresented: $favFilter.showSavedLifehacks) {
            SavedLifehacksCarouselSheet()
        }
        .onChange(of: favFilter.selectedTab) { _, newValue in
            let normalized: FavoriteScreenTab = (newValue == .hacks || newValue == .courses) ? .cards : newValue
            if selectedTab != normalized {
                selectedTab = normalized
            }
            if favFilter.selectedTab != normalized {
                favFilter.selectedTab = normalized
            }
        }
    }

    private var collectionTitle: String {
        selectedTab == .dictionary ? "Словарь" : "Избранное"
    }

    private func favoritesScreenHeader() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TaikaScreenPageTitle(title: collectionTitle) {
                if showsViewModeToggle {
                    FDFavViewModeToggle(viewMode: activeViewMode)
                }
            }
            FDCollectionSwitch(selection: collectionSelection)
                .padding(.horizontal, CD.Spacing.screen)
        }
        .padding(.top, 4)
    }

    private var collectionSelection: Binding<FavoriteScreenTab> {
        Binding(
            get: {
                selectedTab == .dictionary ? .dictionary : .cards
            },
            set: { next in
                let normalized: FavoriteScreenTab = next == .dictionary ? .dictionary : .cards
                guard selectedTab != normalized else { return }
                selectedTab = normalized
                favFilter.selectedTab = normalized
            }
        )
    }

    private func favoritesCollectionSummary() -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(selectedTab == .dictionary ? "Сохранено в словаре" : "Сохранённые карточки")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
            Text("·")
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.5))
            Text("\(selectedTab == .dictionary ? dictionaryList.count : cardsList.count)")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(PD.ColorToken.text)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func favoritesTrainingCTA() -> some View {
        let count = selectedTab == .dictionary ? dictionaryList.count : cardsList.count
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                isTrainingPickerPresented = true
            }
        } label: {
            DictionarySoftActionLabel(
                icon: "mic.fill",
                title: "Начать тренировку · \(count)"
            )
        }
        .buttonStyle(PressDownStyle(scale: 0.98, fade: 0.98))
        .accessibilityLabel("Начать тренировку, \(count) карточек")
    }

    private func trainCurrentTabInSpeaker() {
        SpeakerManager.shared.setSpeakerUIMode(.training)
        if selectedTab == .dictionary {
            SpeakerRequestedCourseId.shared.set("__dictionary__")
            DictionarySessionSelection.shared.activate(nil)
            SpeakerManager.shared.startSpecialTraining(poolId: "__dictionary__")
            if nav.path.isEmpty {
                SpeakerReturnContext.shared.saveFromRootTab(3)
            } else {
                SpeakerReturnContext.shared.save(tab: 3, path: nav.path)
            }
        } else {
            SpeakerRequestedCourseId.shared.set("__favorites__")
            SpeakerManager.shared.startSpecialTraining(poolId: "__favorites__")
            if nav.path.isEmpty {
                SpeakerReturnContext.shared.saveFromRootTab(3)
            } else {
                SpeakerReturnContext.shared.save(tab: 3, path: nav.path)
            }
        }
        nav.requestTab(2)
    }

    private func startFavoritesGame(mode: GameModeType) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if selectedTab == .dictionary {
            nav.go(.game(
                courseId: DictionaryGameSource.courseId,
                lessonId: nil,
                gameType: mode.rawValue
            ))
        } else {
            nav.go(.game(courseId: "__favorites__", lessonId: nil, gameType: mode.rawValue))
        }
    }

    @ViewBuilder
    private func favoritesTabContent() -> some View {
        switch selectedTab {
        case .cards:
            FDFavCardsTabList(
                cards: cardsList,
                onUnfavorite: { manager.remove(id: $0.sourceId) },
                onOpenCourse: { openFavoriteCourse(courseId: $0) }
            )
        case .dictionary:
            FDFavDictionaryTabList(
                cards: dictionaryList,
                onUnfavorite: { manager.remove(id: $0.sourceId) },
                onOpenSpeaker: {
                    SpeakerManager.shared.setSpeakerUIMode(.conversation)
                    SpeakerReturnContext.shared.save(tab: 3, path: nav.path)
                    nav.requestTab(2)
                },
                onTrainInSpeaker: nil
            )
        case .hacks, .courses:
            EmptyView()
        }
    }

    private func openFavoriteCourse(courseId: String) {
        let id = courseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id != "other" else { return }
        if let c = CourseData.shared.course(with: id), c.isPro, !pro.isPro {
            overlay.presentPro(reason: .lockedCourse, courseId: id)
            return
        }
        CourseAnimation.markLastOpened(id)
        nav.go(.lessons(courseId: id))
    }

    private func openCourse(_ course: FDCourseDTO) {
        if let c = CourseData.shared.course(with: course.courseId), c.isPro, !pro.isPro {
            overlay.presentPro(reason: .lockedCourse, courseId: course.courseId)
            return
        }
        nav.go(.lessons(courseId: course.courseId))
    }

    private func openHack(_ hack: FDHackDTO) {
        guard let route = FDFavLessonGrouping.route(for: hack.sourceId) else { return }
        if let c = CourseData.shared.course(with: route.courseId), c.isPro, !pro.isPro {
            overlay.presentPro(reason: .lockedCourse, courseId: route.courseId)
            return
        }
        nav.go(.lesson(
            courseId: route.courseId,
            lessonId: route.lessonId,
            presentation: .canonical
        ))
    }

    private func openCoursesBase() {
        nav.openCourseCatalog(tab: .base)
    }

    private func openOwnSpeech() {
        SpeakerManager.shared.setSpeakerUIMode(.conversation)
        SpeakerReturnContext.shared.save(tab: 3, path: nav.path)
        nav.requestTab(2)
    }
}

/// Все сохранённые лайфхаки со всех уроков. Та же карточка, не третья вкладка.
private struct SavedLifehacksCarouselSheet: View {
    @ObservedObject private var manager = FavoriteManager.shared
    @Environment(\.dismiss) private var dismiss

    private var hacks: [FDHackDTO] { manager.hacksDTO }

    var body: some View {
        NavigationStack {
            ZStack {
                PD.ColorToken.background.ignoresSafeArea()
                if hacks.isEmpty {
                    emptyState
                } else {
                    carousel
                }
            }
            .navigationTitle("Лайфхаки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        .tint(TaikaLifehackCrayonPalette.primary)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            lifehackMark
                .frame(width: 28, height: 38)
            Text("Пока нет лайфхаков")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(PD.ColorToken.text)
            Text("Сердце на карточке в уроке — он появится здесь")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private var carousel: some View {
        GeometryReader { geo in
            let cardWidth = min(260, max(210, geo.size.width - 88))
            let cardHeight = min(292, max(220, geo.size.height - 20))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(hacks) { hack in
                        StepLifehackCardVisual(
                            item: SDStepItem(
                                kind: .tip,
                                titleRU: bodyText(for: hack),
                                subtitleTH: "",
                                phonetic: ""
                            ),
                            label: "лайфхак",
                            size: CGSize(width: cardWidth, height: cardHeight),
                            isFavorite: true,
                            onFavorite: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                manager.remove(id: hack.sourceId)
                            },
                            favoriteOnly: true
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
        }
    }

    private func bodyText(for hack: FDHackDTO) -> String {
        if let item = manager.items.first(where: { $0.id.caseInsensitiveCompare(hack.sourceId) == .orderedSame }) {
            let stored = item.th.trimmingCharacters(in: .whitespacesAndNewlines)
            if !stored.isEmpty { return stored }
        }
        var meta = hack.meta.trimmingCharacters(in: .whitespacesAndNewlines)
        if meta.lowercased().hasPrefix("hack:") {
            meta = String(meta.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !meta.isEmpty { return meta }
        let title = hack.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Лайфхак" : title
    }

    private var lifehackMark: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        TaikaLifehackCrayonPalette.colors[2],
                        TaikaLifehackCrayonPalette.primary,
                        TaikaLifehackCrayonPalette.deep
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 0.8)
            )
    }
}

private struct FavEmptySpec {
    let systemImage: String
    var assembleGateKey: String? = nil
    let lines: [String]
    let primaryCTA: TaikaAssistantHubPrimaryCTA
}

private func canonicalId(_ c: FDCardDTO) -> String {
    c.sourceId.isEmpty ? c.id : c.sourceId
}
