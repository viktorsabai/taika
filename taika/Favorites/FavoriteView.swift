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
                        VStack(spacing: 0) {
                            favoritesTabContent()
                                .frame(maxWidth: .infinity, alignment: .topLeading)

                            if showsBottomTrainingBar {
                                favoritesPracticeSection()
                                    .padding(.horizontal, CD.Spacing.screen)
                                    .padding(.top, 18)
                                    .padding(.bottom, bottomContentInset)
                            } else {
                                Spacer(minLength: bottomContentInset)
                            }
                        }
                    }
                    .environment(\.taikaRootHeaderClearance, 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding(.top, Theme.Layout.rootHeaderClearance)
        }
        .onAppear {
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
        TaikaScreenPageTitle(title: collectionTitle) {
            if showsViewModeToggle {
                FDFavViewModeToggle(viewMode: activeViewMode)
            }
        }
        .padding(.top, 4)
    }

    /// Native practice rows: one hierarchy, one clear next action per row.
    private func favoritesPracticeSection() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(selectedTab == .dictionary ? "ПРАКТИКА СЛОВАРЯ" : "ПРАКТИКА ИЗБРАННОГО")
                .taikaSectionTitleStyle()
                .padding(.bottom, 4)

            favoritesPracticeRow(
                icon: "person.wave.2.fill",
                title: "Спикер",
                detail: selectedTab == .dictionary ? "Произношение карточек словаря" : "Произношение сохранённых карточек",
                accessibilityLabel: selectedTab == .dictionary ? "Тренировать словарь в спикере" : "Тренировать избранное в спикере"
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                trainCurrentTabInSpeaker()
            }

            favoritesPracticeRow(
                icon: "gamecontroller.fill",
                title: "Игры",
                detail: selectedTab == .dictionary ? "Память и закрепление словаря" : "Память и закрепление избранного",
                accessibilityLabel: selectedTab == .dictionary ? "Открыть игры для словаря" : "Открыть игры для избранного"
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                overlay.present(.gameParkFromFavorites)
            }
        }
    }

    private func favoritesPracticeRow(
        icon: String,
        title: String,
        detail: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                    .frame(width: 28, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.text)
                    Text(detail)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.78))
            }
            .padding(.vertical, 13)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PD.ColorToken.stroke.opacity(0.42))
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
        case .hacks, .courses:
            EmptyView()
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
