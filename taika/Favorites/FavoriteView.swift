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

    @AppStorage("taika.fav.cards.viewMode") private var cardsViewModeRaw: String = FavCardsViewMode.list.rawValue
    @AppStorage("taika.fav.dict.viewMode") private var dictViewModeRaw: String = FavCardsViewMode.list.rawValue

    private var cardsList: [FDCardDTO] {
        manager.cardsDTO
            .filter { !canonicalId($0).lowercased().hasPrefix("hack:") }
            .sorted { $0.addedAt > $1.addedAt }
    }

    private var hacksList: [FDHackDTO] {
        let explicit = manager.hacksDTO
        let fromCards: [FDHackDTO] = manager.cardsDTO.compactMap { card in
            let source = canonicalId(card)
            let isHack = source.lowercased().hasPrefix("hack:") || card.meta.lowercased().hasPrefix("hack:")
            guard isHack else { return nil }
            let normalizedSource = source.hasPrefix("hack:") ? source : "hack:\(source)"
            return FDHackDTO(
                sourceId: normalizedSource,
                title: card.title,
                meta: card.meta,
                lessonTitle: card.lessonTitle,
                addedAt: card.addedAt
            )
        }
        var seen = Set<String>()
        return (explicit + fromCards)
            .sorted { $0.addedAt > $1.addedAt }
            .filter { seen.insert($0.sourceId).inserted }
    }

    private var coursesList: [FDCourseDTO] {
        manager.coursesDTO.sorted { $0.addedAt > $1.addedAt }
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
        switch selectedTab {
        case .dictionary:
            return Binding(
                get: { FavCardsViewMode(rawValue: dictViewModeRaw) ?? .list },
                set: { dictViewModeRaw = $0.rawValue }
            )
        default:
            return Binding(
                get: { FavCardsViewMode(rawValue: cardsViewModeRaw) ?? .list },
                set: { cardsViewModeRaw = $0.rawValue }
            )
        }
    }

    private var currentEmptySpec: FavEmptySpec? {
        switch selectedTab {
        case .cards where cardsList.isEmpty:
            return FavEmptySpec(
                systemImage: "heart",
                title: "Собери свои фразы",
                subtitle: "Лайкни первую фразу в уроке — она появится здесь.",
                actionTitle: "к урокам",
                action: openCoursesBase
            )
        case .dictionary where dictionaryList.isEmpty:
            return FavEmptySpec(
                systemImage: "bookmark",
                title: "Свои слова под рукой",
                subtitle: "Скажи фразу в «Скажи сам» и нажми «Добавить».",
                actionTitle: "скажи сам",
                action: openOwnSpeech
            )
        case .hacks where hacksList.isEmpty:
            return FavEmptySpec(
                systemImage: "lightbulb",
                title: "Подсказки, которые жалко потерять",
                subtitle: "Сохраняй лайфхаки в уроках — они появятся здесь.",
                actionTitle: "к урокам",
                action: openCoursesBase
            )
        case .courses where coursesList.isEmpty:
            return FavEmptySpec(
                systemImage: "graduationcap",
                title: "Курсы, к которым хочешь вернуться",
                subtitle: "Добавь курс в избранное — он будет ждать здесь.",
                actionTitle: "к курсам",
                action: openCoursesBase
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
        ZStack {
            PD.ColorToken.background.ignoresSafeArea()

            VStack(spacing: 0) {
                favoritesScreenHeader()

                if showsBottomTrainingBar {
                    favoritesTopActionRow()
                        .padding(.horizontal, CD.Spacing.screen)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                }

                if let empty = currentEmptySpec {
                    favEmptyState(
                        systemImage: empty.systemImage,
                        title: empty.title,
                        subtitle: empty.subtitle,
                        actionTitle: empty.actionTitle,
                        action: empty.action
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, bottomContentInset)
                } else {
                    TaikaRootVerticalScroll {
                        favoritesTabContent()
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.bottom, bottomContentInset)
                    }
                    .environment(\.taikaRootHeaderClearance, 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding(.top, Theme.Layout.rootHeaderClearance)
        }
        .onAppear {
            if favFilter.selectedTab == .dictionary {
                favFilter.selectedTab = .cards
            }
            selectedTab = favFilter.selectedTab
            StepData.shared.preload()
        }
        .onChange(of: selectedTab) { _, newValue in
            let normalized = newValue == .dictionary ? .cards : newValue
            if selectedTab != normalized {
                selectedTab = normalized
                return
            }
            if favFilter.selectedTab != normalized {
                favFilter.selectedTab = normalized
            }
        }
        .onChange(of: favFilter.selectedTab) { _, newValue in
            let normalized = newValue == .dictionary ? .cards : newValue
            if selectedTab != normalized {
                selectedTab = normalized
            }
            if favFilter.selectedTab != normalized {
                favFilter.selectedTab = normalized
            }
        }
    }

    private func favoritesScreenHeader() -> some View {
        TaikaScreenPageTitle(title: "Избранное") {
            HStack(spacing: 8) {
                if showsViewModeToggle {
                    FDFavViewModeToggle(viewMode: activeViewMode)
                }
                FDFavoriteTabBar(
                    selection: $selectedTab,
                    dictionaryCount: dictionaryList.count
                )
            }
        }
        .padding(.top, 8)
    }

    /// Один ряд вместо typewriter + нижнего бара: Спикер | игровая консоль.
    private func favoritesTopActionRow() -> some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                trainCurrentTabInSpeaker()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("В Спикер")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Capsule(style: .continuous).fill(ThemeManager.shared.currentAccentFill))
            }
            .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
            .accessibilityLabel("Тренировать в спикере")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                overlay.present(.gameParkFromFavorites)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("В игры")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(ThemeManager.shared.currentAccentFill)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Capsule(style: .continuous).fill(Color.clear))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(ThemeManager.shared.currentAccentFill, lineWidth: 1.5)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(PressDownStyle(scale: 0.97, fade: 0.97))
            .accessibilityLabel("Открыть игровую консоль")
        }
        .frame(maxWidth: .infinity)
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

    @ViewBuilder
    private func favoritesTabContent() -> some View {
        switch selectedTab {
        case .cards:
            FDFavCardsTabList(
                cards: cardsList,
                onUnfavorite: { manager.remove(id: $0.sourceId) }
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
        case .hacks:
            FDFavHacksTabGrid(
                hacks: hacksList,
                isEditing: $isEditing,
                onUnfavorite: { manager.remove(id: $0.sourceId) },
                onOpen: openHack
            )
        case .courses:
            FDFavCoursesTabGrid(
                courses: coursesList,
                onOpen: openCourse,
                onUnfavorite: { manager.remove(id: "course:\($0.courseId)") }
            )
        }
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

private struct FavEmptySpec {
    let systemImage: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
}

private func canonicalId(_ c: FDCardDTO) -> String {
    c.sourceId.isEmpty ? c.id : c.sourceId
}
