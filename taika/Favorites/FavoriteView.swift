import UIKit
import SwiftUI

private extension View {
    func fvSheetChrome() -> some View {
        self
            .presentationDetents([.fraction(0.66), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationBackground(.ultraThinMaterial)
    }
}

#if DEBUG
struct FavoriteView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            FavoriteView()
                .environmentObject(ThemeManager.shared)
                .environmentObject(NavigationIntent())
        }
        .preferredColorScheme(.dark)
    }
}
#endif

private extension Notification.Name {
    static let favShowAllCards   = Notification.Name("fav.showAll.cards")
    static let favShowAllCourses = Notification.Name("fav.showAll.courses")
    static let favShowAllHacks   = Notification.Name("fav.showAll.hacks")
}

/// Состояние фильтра избранного (хедер открывает оверлей; FavoriteView читает)
@MainActor
public final class FavoritesFilterState: ObservableObject {
    public static let shared = FavoritesFilterState()
    @Published public var selected: FDK = .all
    private init() {}
}

struct FavoriteView: View {
    @EnvironmentObject private var nav: NavigationIntent
    @StateObject private var manager = FavoriteManager.shared
    @ObservedObject private var favFilter = FavoritesFilterState.shared
    private var selected: FDK { favFilter.selected }
    @State private var isEditing: Bool = false

    @State private var goAllCards   = false
    @State private var goAllCourses = false
    @State private var goAllHacks   = false
    @State private var openedCard: FDCardDTO? = nil

    // Route to open full StepView from mini overlay
    private struct StepRoute: Identifiable, Hashable { let id = UUID(); let courseId: String; let lessonId: String; let index: Int }
    @State private var stepRoute: StepRoute? = nil
    @State private var pendingItems: [FavoriteItem]? = nil

    // MARK: - Helpers to reduce type-checker load
    private func visibleCoursesList() -> [FDCourseDTO] {
        (selected == .all || selected == .courses) ? manager.coursesDTO : []
    }
    private func visibleCardsList() -> [FDCardDTO] {
        let base = (selected == .all || selected == .cards) ? manager.cardsDTO : []
        return base.filter { card in
            !canonicalId(card).lowercased().hasPrefix("hack:")
        }
    }
    private func visibleHacksList() -> [FDHackDTO] {
        (selected == .all || selected == .hacks) ? manager.hacksDTO : []
    }

    @ViewBuilder
    private func buildFavContent() -> some View {
        FavoriteDS(
            courses: visibleCoursesList(),
            cards:   visibleCardsList(),
            hacks:   visibleHacksList(),
            isEditing: $isEditing,
            selectedFilter: $favFilter.selected,
            onUnfavorite: { id in manager.remove(id: id) },
            onReorder: { order in manager.applyOrder(order) },
            onShowAllCards:   { DispatchQueue.main.async { goAllCards = true } },
            onShowAllCourses: { DispatchQueue.main.async { goAllCourses = true } },
            onShowAllHacks:   { DispatchQueue.main.async { goAllHacks = true } },
            onOpenCard: { card in
                stepRoute = nil
                // карточки — по возможности свежий DTO из менеджера; лайфхаки в cardsDTO нет → используем переданный card
                let fid = canonicalId(card)
                let fresh = manager.cardsDTO.first { canonicalId($0) == fid }
                withAnimation(.easeOut(duration: 0.25)) {
                    openedCard = fresh ?? card
                }
            },
            onOpenCourse: { course in
                // Глобальный стек: хедер «назад» и корректный pop (не локальный destination)
                nav.go(.lessons(courseId: course.id))
            }
        )
        .scrollDisabled(openedCard != nil)
        .background(PD.ColorToken.background)
    }

    var body: some View {
        ZStack {
            PD.ColorToken.background.ignoresSafeArea()
            ZStack(alignment: .top) {
                PD.ColorToken.background
                    .ignoresSafeArea()
                VStack(spacing: Theme.Layout.sectionGap) {

                    // Content (FavoriteDS renders its own scroll content)
                    buildFavContent()
                }
                // .padding(.top, Theme.Layout.pageTopAfterHeader) // Removed legacy top padding
                .allowsHitTesting(openedCard == nil)
                .disabled(openedCard != nil)
            }
            .navigationDestination(isPresented: $goAllCards) {
                AllFavCardsView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(isPresented: $goAllCourses) {
                AllFavCourseView(courses: visibleCoursesList())
                    .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(isPresented: $goAllHacks) {
                AllFavHucksView(hacks: visibleHacksList())
                    .toolbar(.hidden, for: .navigationBar)
            }
            .navigationDestination(item: $stepRoute) { r in
                StepView(
                    courseId: r.courseId,
                    lessonId: r.lessonId,
                    lessonTitle: LessonsData.shared.lessonTitle(for: r.lessonId),
                    startIndex: r.index,
                    scope: .overlay,
                    layoutCardsOnly: true,
                    allowLearning: true,
                    showBottomProgress: false
                )
                .toolbar(.hidden, for: .navigationBar)
            }
            // Курс из избранного открывается через nav.go(.lessons) в AppShell — хедер «назад» и pop работают
            // Removed system sheet, replaced with custom overlay below
            .onChange(of: openedCard) { _, newValue in
                if newValue == nil { pendingItems = nil }
            }
            .onAppear {
                // Preload steps so resolve/mini-host have data ready
                StepData.shared.preload()
            }
            .background(PD.ColorToken.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
        }
        .allowsHitTesting(openedCard == nil)
        .overlay(alignment: .bottom) {
            if let card = openedCard {
                CustomFavOverlay(
                    card: card,
                    onDismiss: {
                        openedCard = nil
                    }
                ) {
                    let fid = canonicalId(card)
                    let fresh = manager.cardsDTO.first { canonicalId($0) == fid } ?? card
                    sheetContent(for: fresh)
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                .animation(.easeOut(duration: 0.32), value: openedCard != nil)
            }
        }
        // .taikaHeader(.custom(title: "Избранное")) // Removed legacy header usage
    }
    // Sheet content moved inside FavoriteView for access to openedCard and stepRoute
    @MainActor
    @ViewBuilder
    private func sheetContent(for card: FDCardDTO) -> some View {
        FavSheetContent(
            card: card,
            onOpenLesson: { c, l, i in
                openedCard = nil
                // Navigate to full StepView on the next runloop without artificial delay
                DispatchQueue.main.async {
                    stepRoute = StepRoute(courseId: c, lessonId: l, index: i)
                }
            }
        )
    }

}

private struct FavSheetContent: View {
    let card: FDCardDTO
    let onOpenLesson: (String, String, Int) -> Void
    @State private var route: (courseId: String, lessonId: String, index: Int)? = nil
    @State private var didResolveOnce: Bool = false

    private var isHack: Bool {
        let fid = (card.sourceId.isEmpty ? card.id : card.sourceId).lowercased()
        return fid.hasPrefix("hack:")
    }

    var body: some View {
        Group {
            if let r = route {
                StepView(
                    courseId: r.courseId,
                    lessonId: r.lessonId,
                    lessonTitle: (card.lessonTitle.isEmpty ? LessonsData.shared.lessonTitle(for: r.lessonId) : card.lessonTitle),
                    startIndex: r.index,
                    scope: .overlay,
                    showKinds: isHack ? [.tip] : [.word, .phrase, .casual],
                    layoutCardsOnly: true,
                    allowLearning: true,
                    showBottomProgress: false
                )
                .toolbar(.hidden, for: .navigationBar)
            } else {
                VStack(spacing: 16) {
                    ProgressView().progressViewStyle(.circular)
                    Text("Готовим карточку…")
                        .font(.footnote)
                        .opacity(0.7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        // chrome handled by CustomFavOverlay
        .onAppear {
            if !didResolveOnce {
                didResolveOnce = true

                let fid = (card.sourceId.isEmpty ? card.id : card.sourceId)
                let idxFromId = parseIdx(from: fid) // canonical :idxN embedded by FavoriteManager
                let kinds: [SDStepItem.Kind] = isHack ? [.tip] : [.word, .phrase, .casual]

                // 1) Try to resolve course/lesson via resolver; prefer the explicit index from fid if present
                if let rr = StepManager.shared.resolveRoute(fromFavoriteId: fid) {
                    let all = StepManager.shared.dsStepsCached(courseId: rr.courseId, lessonId: rr.lessonId)
                    let originalIndex = (idxFromId >= 0 ? idxFromId : rr.stepIndex)
                    let allowedOriginalIndices: [Int] = all.enumerated().compactMap { i, s in kinds.contains(s.kind) ? i : nil }
                    let filteredIndex: Int = {
                        if let exact = allowedOriginalIndices.firstIndex(of: originalIndex) { return exact }
                        return nearestAllowedPosition(originalIndex: originalIndex, allowedOriginalIndices: allowedOriginalIndices)
                    }()
                    let clamped = max(0, min(filteredIndex, max(0, allowedOriginalIndices.count - 1)))
                    route = (courseId: rr.courseId, lessonId: rr.lessonId, index: clamped)
                } else {
                    // 2) Fallback: parse parts directly; require a valid :idxN to avoid jumping to 0
                    let parts = fid.split(separator: ":").map(String.init)
                    if parts.count >= 5, parts[1] == "step", idxFromId >= 0 {
                        let c = parts[2]; let l = parts[3]; let originalIndex = idxFromId
                        let all = StepManager.shared.dsStepsCached(courseId: c, lessonId: l)
                        let allowedOriginalIndices: [Int] = all.enumerated().compactMap { i, s in kinds.contains(s.kind) ? i : nil }
                        let filteredIndex: Int = {
                            if let exact = allowedOriginalIndices.firstIndex(of: originalIndex) { return exact }
                            return nearestAllowedPosition(originalIndex: originalIndex, allowedOriginalIndices: allowedOriginalIndices)
                        }()
                        let clamped = max(0, min(filteredIndex, max(0, allowedOriginalIndices.count - 1)))
                        route = (courseId: c, lessonId: l, index: clamped)
                    }
                }
            }
        }
    }
}

// canonical id helper (prefer sourceId)
private func canonicalId(_ c: FDCardDTO) -> String {
    return c.sourceId.isEmpty ? c.id : c.sourceId
}

// find the nearest position in the filtered list to a given original index
private func nearestAllowedPosition(originalIndex: Int, allowedOriginalIndices: [Int]) -> Int {
    guard !allowedOriginalIndices.isEmpty else { return 0 }
    var bestPos = 0
    var bestDelta = abs(allowedOriginalIndices[0] - originalIndex)
    for (pos, idx) in allowedOriginalIndices.enumerated() {
        let d = abs(idx - originalIndex)
        if d < bestDelta { bestDelta = d; bestPos = pos }
    }
    return bestPos
}

// Extract canonical :idxN from favorite id
private func parseIdx(from fid: String) -> Int {
    let s = fid.lowercased()
    guard let r = s.range(of: ":idx") else { return -1 }
    return Int(s[r.upperBound...]) ?? -1
}


/// Оверлей из избранного: только блюр + затемнение + контент Step (карусель по своей логике). Без лишних обводок и слоёв — как в StepView при «Итоги урока».
private struct CustomFavOverlay<Content: View>: View {
    let card: FDCardDTO
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content

    init(
        card: FDCardDTO,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.card = card
        self.onDismiss = onDismiss
        self.content = content
    }

    @State private var appeared: Bool = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            // 1) Системный материал — размывает то, что реально под окном (список избранного), не зависит от нашего .blur()
            if !reduceTransparency {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // 2) Затемнение (как в Step)
            Color.black.opacity(reduceTransparency ? 0.55 : 0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            // 3) Контент Step: кнопка закрытия + карусель
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { onDismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 20)
                }
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.98)
            .animation(.easeOut(duration: 0.28), value: appeared)
        }
        .onAppear {
            appeared = false
            withAnimation(.easeOut(duration: 0.28)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }
}

private struct TopCorners: Shape {
    var radius: CGFloat = 16
    func path(in rect: CGRect) -> Path {
        let p = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(p.cgPath)
    }
}
