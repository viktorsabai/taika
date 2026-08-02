//
//  AllFavCards.swift
//  taika
//
//  Created by product on 16.09.2025.
//

//
//  AllFavCards.swift
//  taika
//
//  full-screen "all favorites" cards page
//  layout: appDS header → bidirectional grid (rubik-like pan) → safe bottom inset
//  NOTE: card view is a drop-in placeholder — swap to FDMiniCardV(model: ...) where marked

import SwiftUI

private typealias T = PD

struct AllFavCardsView: View {
    @State private var cards: [FDCardDTO] = []
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: CardTypeFilter = .all
    @State private var stepRoute: StepRoute? = nil

    private struct StepRoute: Identifiable, Hashable {
        let id = UUID()
        let courseId: String
        let lessonId: String
        let index: Int
    }

    private var displayedCards: [FDCardDTO] {
        switch selectedType {
        case .all:
            return cards
        case .word, .phrase, .informal:
            return cards.filter { $0.matches(selectedType) }
        }
    }

    private func resolve(_ items: [FavoriteItem]) {
        let withoutDict = items.filter { !FavoriteManager.shared.isUserDictionaryItem($0) }
        let resolved = FavoriteData.shared.resolve(withoutDict)
        cards = resolved.cards
    }

    private func parseIdx(from sourceId: String) -> Int {
        let low = sourceId.lowercased()
        guard let r = low.range(of: ":idx") else { return 0 }
        return Int(low[r.upperBound...]) ?? 0
    }

    private func openCard(_ dto: FDCardDTO) {
        if let rr = StepManager.shared.resolveRoute(fromFavoriteId: dto.sourceId) {
            stepRoute = StepRoute(courseId: rr.courseId, lessonId: rr.lessonId, index: rr.stepIndex)
            return
        }
        if let fallback = FavoriteData.shared.fallbackRoute(from: dto.sourceId) {
            let idx = max(0, parseIdx(from: dto.sourceId))
            stepRoute = StepRoute(courseId: fallback.courseId, lessonId: fallback.lessonId, index: idx)
        }
    }

    var body: some View {
        ZStack {
            T.ColorToken.background.ignoresSafeArea()
            VStack(spacing: 10) {
                AppBackHeader { dismiss() }
                HStack {
                    Text("Карточки")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(displayedCards.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, PD.Spacing.screen)

                CardsFiltersBar(selected: $selectedType)

                if displayedCards.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.on.rectangle.slash")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Пока нет карточек в этом фильтре")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(displayedCards, id: \.sourceId) { dto in
                                FDMiniCardV(
                                    item: dto,
                                    onSpeak: { StepAudio.shared.speakThai(dto.subtitle) },
                                    onOpen: { openCard(dto) },
                                    isEditing: .constant(false)
                                )
                            }
                        }
                        .padding(.horizontal, PD.Spacing.screen)
                        .padding(.bottom, ToolBar.recommendedBottomInset)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $stepRoute) { r in
            StepView(
                courseId: r.courseId,
                lessonId: r.lessonId,
                lessonTitle: LessonsData.shared.lessonTitle(for: r.lessonId),
                startIndex: r.index,
                scope: .overlay,
                layoutCardsOnly: true,
                allowLearning: true,
                showBottomProgress: false,
                showInternalHeader: true
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { resolve(FavoriteManager.shared.items) }
        .onReceive(FavoriteManager.shared.$items) { resolve($0) }
    }
}


private struct CardsFiltersBar: View {
    @Binding var selected: CardTypeFilter
    var body: some View {
        TaikaCarouselScroll {
            HStack(spacing: 10) {
                ForEach(CardTypeFilter.allCases) { f in
                    AppFilterChip(
                        title: f.rawValue,
                        isActive: selected == f,
                        scale: .s
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) { selected = f }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - filter enum
private enum CardTypeFilter: String, CaseIterable, Identifiable {
    case all = "все"
    case word = "слово"
    case phrase = "фраза"
    case informal = "неформально"
    var id: String { rawValue }
}

// MARK: - filtering helper (robust to different DTO field names)
private enum CardKind { case word, phrase, informal, unknown }

private extension FDCardDTO {
    func matches(_ filter: CardTypeFilter) -> Bool {
        switch filter {
        case .all: return true
        case .word: return inferredKind() == .word
        case .phrase: return inferredKind() == .phrase
        case .informal: return inferredKind() == .informal
        }
    }

    func inferredKind() -> CardKind {
        // try common string fields first
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            let label = child.label?.lowercased() ?? ""
            if label == "type" || label == "kind" || label == "category" || label == "tag" || label == "group" {
                if let s = child.value as? String {
                    let v = s.lowercased()
                    if v.contains("word") || v == "слово" { return .word }
                    if v.contains("phrase") || v == "фраза" { return .phrase }
                    if v.contains("informal") || v == "неформально" || v == "slang" { return .informal }
                }
            }
            // try boolean flags
            if label == "isword", let b = child.value as? Bool, b { return .word }
            if label == "isphrase", let b = child.value as? Bool, b { return .phrase }
            if label == "isinformal" || label == "isslang", let b = child.value as? Bool, b { return .informal }
        }
        return .unknown
    }
}

#Preview {
    AllFavCardsView()
}
