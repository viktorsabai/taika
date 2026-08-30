//
//  FavoriteDS.swift (simplified)
//

import SwiftUI
import Combine
import UIKit
import UniformTypeIdentifiers


/// Favorites filter chip row — AppDS identity (`AppFilterChip`).
public struct FDAppFilterItem: Identifiable {
    public let id: String
    public let title: String
    public let isSelected: Bool
    public let onTap: () -> Void

    public init(
        id: String,
        title: String,
        systemImage: String = "",
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
        self.onTap = onTap
    }
}

public struct FDAppFiltersBar: View {
    public let items: [FDAppFilterItem]
    public var scale: AppFilterScale = .s

    public init(items: [FDAppFilterItem], scale: AppFilterScale = .s) {
        self.items = items
        self.scale = scale
    }

    public var body: some View {
        TaikaCarouselScroll {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    AppFilterChip(
                        title: item.title,
                        isActive: item.isSelected,
                        scale: scale
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            item.onTap()
                        }
                    }
                }
            }
        }
    }
}

#if canImport(AVFoundation)
import AVFoundation
#endif


// MARK: - Data

public enum FDK: String, CaseIterable, Identifiable {
    case all = "Все"
    case courses = "Курсы"
    case hacks = "Лайфхаки"
    case cards = "Карточки"

    public var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "star"
        case .courses: return "graduationcap"
        case .hacks: return "lightbulb"
        case .cards: return "rectangle.on.rectangle"
        }
    }
}

struct FDFavItem: Identifiable {
    let id = UUID()
    let sourceId: String   // FavoriteItem.id from FavoriteManager
    let kind: FDK
    let title: String
    let subtitle: String
    let meta: String       // e.g. "7 мин • 6 уроков" / "урок 2 из 6 • ~7 мин" / "карточек: 12"
    let lessonTitle: String?   // <— НОВОЕ
    let tagText: String?       // <— НОВОЕ
    let isPro: Bool
    let addedAt: Date
}


// MARK: - Reusable views


struct FDSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .taikaSectionTitleStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PD.Spacing.screen)
    }
}

struct FDSectionHeaderBar: View {
    let title: String
    var count: Int? = nil
    var onShowAll: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .center) {
            Text(title.uppercased())
                .taikaSectionTitleStyle()
            Spacer()
            if let onShowAll {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onShowAll()
                }) {
                    HStack(spacing: 6) {
                        Text(count != nil ? "Показать все (\(count!))" : "Показать все")
                            .font(.caption2.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    // цвет текста — фирменный градиент, без подложки
                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
                .buttonStyle(.plain) // без системной подложки
                .contentShape(Capsule()) // большая зона тапа
            }
        }
        .padding(.horizontal, PD.Spacing.screen)
    }
}

struct FDChipPill: View {
    let title: String
    let isOn: Bool
    var body: some View {
        AppFilterChip(title: title, isActive: isOn, scale: .xs)
    }
}

enum FDChipSize { case regular, large }

struct FDFiltersBar: View {
    @Binding var selected: FDK
    var size: FDChipSize = .regular
    var body: some View {
        TaikaCarouselScroll {
            HStack(spacing: 10) {
                ForEach(FDK.allCases) { kind in
                    AppFilterChip(
                        title: kind.rawValue,
                        isActive: kind == selected,
                        scale: size == .large ? .s : .xs
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.15)) { selected = kind }
                    }
                }
            }
            .padding(.horizontal, PD.Spacing.screen)
        }
    }
}

struct FDSearchField: View {
    @Binding var query: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            TextField("Поиск в избранном", text: $query)
                .textInputAutocapitalization(.never)
        }
        .font(.body)
        .foregroundStyle(PD.ColorToken.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PD.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PD.ColorToken.stroke, lineWidth: 1)
                )
        )
        .padding(.horizontal, PD.Spacing.screen)
    }
}

struct FDFavRow: View {
    let item: FDFavItem

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PD.ColorToken.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(PD.ColorToken.stroke, lineWidth: 1)
                    )
                Image(systemName: item.kind.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PD.ColorToken.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if item.isPro {
                        Text("PRO")
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(ThemeManager.shared.currentAccentFill)
                            .foregroundStyle(PD.ColorToken.background)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .lineLimit(2)
                if !item.meta.isEmpty {
                    Text(item.meta)
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PD.ColorToken.textSecondary)
        }
        .padding(.horizontal, PD.Spacing.screen)
        .padding(.vertical, 12)
        .background(round.fill(PD.ColorToken.card))
        .overlay(round.stroke(PD.ColorToken.stroke, lineWidth: 1))
    }
}


fileprivate struct FDMiniStepBalancedChrome<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing
    let sideSlotWidth: CGFloat

    init(sideSlotWidth: CGFloat = 92, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.sideSlotWidth = sideSlotWidth
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(width: sideSlotWidth, alignment: .leading)
            Spacer(minLength: 0)
            trailing.frame(width: sideSlotWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Mini card for favorites (compact)
/// Тот же атом, что учебная карточка в шаге (`StepWordCard`), но в mini-формате ленты избранного.
struct FDMiniCardV: View {
    let item: FDCardDTO
    var layoutWidth: CGFloat = 268
    var layoutHeight: CGFloat = 196
    var onSpeak: (() -> Void)? = nil
    var onOpen: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @Binding var isEditing: Bool
    @State private var isJiggling = false
    @State private var isLearnedState = false
    private var cleanMeta: String {
        if item.meta.hasPrefix("card:") { return String(item.meta.dropFirst("card:".count)) }
        return item.meta
    }

    /// В избранном для учебных карточек полезнее показывать контекст — название урока.
    private var stepLabel: String {
        let t = item.lessonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "урок" }
        // Keep chip compact in mini-carousel to avoid layout drifting on long lesson names.
        let maxLen = 16
        if t.count <= maxLen { return t }
        return String(t.prefix(maxLen - 1)) + "…"
    }

    private var miniStepSize: CGSize {
        CGSize(width: layoutWidth, height: layoutHeight)
    }

    private func refreshLearnedState() {
        // Prefer canonical resolver: it handles card:/step:/legacy ids and idx normalization.
        if let rr = StepManager.shared.resolveRoute(fromFavoriteId: item.sourceId) {
            isLearnedState = ProgressManager.shared.learnedSet(courseId: rr.courseId, lessonId: rr.lessonId).contains(rr.stepIndex)
            return
        }

        // Fallback for already-canonical ids if resolver returned nil.
        let low = item.sourceId.lowercased()
        let parts = low.split(separator: ":").map(String.init)
        if parts.count >= 4, parts[0] == "step" {
            let idxRaw = parts[3]
            let idx = Int(idxRaw.filter(\.isNumber)) ?? 0
            isLearnedState = ProgressManager.shared.learnedSet(courseId: parts[1], lessonId: parts[2]).contains(idx)
            return
        }
        isLearnedState = false
    }

    @ViewBuilder
    private func deleteButtonOverlay(_ round: RoundedRectangle) -> some View {
        Group {
            if isEditing {
                Button(action: { onDelete?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(PD.ColorToken.text)
                        .background(Circle().fill(TaikaDynamicColors.scrimPanel))
                }
                .buttonStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)),
                        removal: .opacity
                    )
                )
            }
        }
    }

    var body: some View {
        let round = RoundedRectangle(cornerRadius: CardDS.Metrics.stepCardContentRadius, style: .continuous)
        StepWordCard(
            title: item.title,
            translit: cleanMeta,
            thai: item.subtitle,
            label: stepLabel,
            size: miniStepSize,
            sectionChrome: .seps,
            chromeStyle: .cards,
            phoneticView: nil,
            isFavorite: true,
            isLearned: isLearnedState,
            allowLearn: false,
            isAudioPlaying: false,
            compactActionBar: true,
            miniLearnedCheckmarkOnly: true,
            onPlay: { onSpeak?() },
            onFavorite: {},
            onLearn: {}
        )
        .overlay(deleteButtonOverlay(round))
        .contentShape(round)
        .onTapGesture {
            if isEditing {
                isEditing = false
            } else {
                onOpen?()
            }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isEditing.toggle()
        }
        .onChange(of: isEditing) { _, newValue in
            isJiggling = newValue
        }
        .onAppear { refreshLearnedState() }
    }
}

// MARK: - Phrase card for favorites grid (портрет, как лайфхаки/курсы)
struct FDFavPhraseCard: View {
    let item: FDCardDTO
    var layoutWidth: CGFloat = 200
    var layoutHeight: CGFloat = 286
    var onSpeak: (() -> Void)? = nil
    var onOpen: (() -> Void)? = nil
    var onUnfavorite: (() -> Void)? = nil
    @Binding var isEditing: Bool
    @State private var isLearnedState = false

    private var cleanMeta: String {
        var m = item.meta
        if m.hasPrefix("card:") { m = String(m.dropFirst("card:".count)) }
        return m.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var lessonCaption: String {
        let t = item.lessonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "урок" : t
    }

    private func refreshLearnedState() {
        if let rr = StepManager.shared.resolveRoute(fromFavoriteId: item.sourceId) {
            isLearnedState = ProgressManager.shared.learnedSet(courseId: rr.courseId, lessonId: rr.lessonId).contains(rr.stepIndex)
            return
        }
        let low = item.sourceId.lowercased()
        let parts = low.split(separator: ":").map(String.init)
        if parts.count >= 4, parts[0] == "step" {
            let idx = Int(parts[3].filter(\.isNumber)) ?? 0
            isLearnedState = ProgressManager.shared.learnedSet(courseId: parts[1], lessonId: parts[2]).contains(idx)
            return
        }
        isLearnedState = false
    }

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        let thaiSize = min(22, max(16, layoutWidth * 0.105))

        VStack(alignment: .leading, spacing: 12) {
            Text("taikA")
                .font(Font.custom("ONMARK Trial", size: 14))
                .foregroundStyle(PD.ColorToken.textSecondary)

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Text(item.subtitle)
                    .font(.system(size: thaiSize, weight: .medium))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PD.ColorToken.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                    .frame(maxWidth: .infinity)

                if !cleanMeta.isEmpty {
                    Text(cleanMeta)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                }

                Text(lessonCaption)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSpeak?()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary)
                        .frame(minWidth: 34, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onUnfavorite?()
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .frame(minWidth: 34, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if isLearnedState {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .frame(minWidth: 28, minHeight: 32)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(16)
        .frame(width: layoutWidth, height: layoutHeight, alignment: .topLeading)
        .background(Theme.Surfaces.card(round))
        .overlay {
            if isEditing {
                Button(action: { onUnfavorite?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(PD.ColorToken.text)
                        .background(Circle().fill(TaikaDynamicColors.scrimPanel))
                }
                .buttonStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .contentShape(round)
        .onTapGesture {
            if isEditing {
                isEditing = false
            } else {
                onOpen?()
            }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isEditing.toggle()
        }
        .onAppear { refreshLearnedState() }
    }
}

// MARK: - Mini lifehack card (text-first)
struct FDMiniHackCard: View {
    let item: FDHackDTO
    var onOpen: (() -> Void)? = nil
    var onUnfavorite: (() -> Void)? = nil
    /// Без long‑press / jiggle (экран итогов урока и т.п.)
    var readOnly: Bool = false
    /// По умолчанию узкий прямоугольник для избранного; в «Итоги урока» — квадрат как у step (`stepCardWidth`).
    var layoutWidth: CGFloat = 200
    var layoutHeight: CGFloat = 286
    /// Лента итогов урока: без больших `Spacer`, чтобы квадрат читался как квадрат, а не «плакат».
    var lessonSummarySquare: Bool = false
    /// В ленте избранного секция уже называется «Лайфхаки» — дублирующий чип справа сверху не нужен.
    var showTopTrailingKindChip: Bool = true
    /// Итоги урока: play + heart вместо одного чипа урока; тап по карточке отключён.
    var summaryPlayAndFavorite: Bool = false
    var onPlayInLesson: (() -> Void)? = nil
    var onToggleFavorite: (() -> Void)? = nil
    var isFavorite: Bool = false
    @Binding var isEditing: Bool
    @State private var isJiggling: Bool = false

    @ViewBuilder
    private func deleteButtonOverlay(_ round: RoundedRectangle) -> some View {
        Group {
            if isEditing {
                Button(action: { onUnfavorite?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(PD.ColorToken.text)
                        .background(Circle().fill(TaikaDynamicColors.scrimPanel))
                }
                .buttonStyle(.plain)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)),
                        removal: .opacity
                    )
                )
            }
        }
    }

    var body: some View {
        // prefer body text passed via `meta`; fallback to `title`. Strip possible "hack:" prefix.
        let raw0 = item.meta.isEmpty ? item.title : item.meta
        let raw1 = raw0.hasPrefix("hack:") ? String(raw0.dropFirst("hack:".count)) : raw0
        let hackText: String = raw1.trimmingCharacters(in: .whitespacesAndNewlines)
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)

        let pillTitle = item.lessonTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "лайфхак"
            : item.lessonTitle
        let pill = HStack {
            Spacer(minLength: 8)
            AppMiniChip(title: pillTitle.lowercased(), style: .neutral) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onOpen?()
            }
        }

        Group {
            if lessonSummarySquare {
                VStack(alignment: .leading, spacing: 10) {
                    FDMiniStepBalancedChrome {
                        Text("taikA")
                            .font(Font.custom("ONMARK Trial", size: 13))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.9))
                    } trailing: {
                        Group {
                            if showTopTrailingKindChip {
                                AppMiniChip(title: "лайфхак", style: .neutral) { }
                                    .allowsHitTesting(false)
                            }
                        }
                    }

                    taikaFMStyledText(hackText, baseColor: PD.ColorToken.text.opacity(0.94))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .lineLimit(8)
                        .minimumScaleFactor(0.92)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    if summaryPlayAndFavorite {
                        HStack(spacing: 10) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onPlayInLesson?()
                            }) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(ThemeManager.shared.currentAccentFill)
                                    .frame(minWidth: 34, minHeight: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Spacer(minLength: 0)
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onToggleFavorite?()
                            }) {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(
                                        isFavorite
                                            ? AnyShapeStyle(ThemeManager.shared.currentAccentFill)
                                            : AnyShapeStyle(PD.ColorToken.textSecondary)
                                    )
                                    .frame(minWidth: 34, minHeight: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        pill
                    }
                }
                .padding(14)
            } else if !showTopTrailingKindChip {
                VStack(alignment: .leading, spacing: 12) {
                    Text("taikA")
                        .font(Font.custom("ONMARK Trial", size: 14))
                        .foregroundStyle(PD.ColorToken.textSecondary)

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        taikaFMStyledText(hackText, baseColor: PD.ColorToken.text)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(7)
                            .minimumScaleFactor(0.88)
                            .frame(maxWidth: .infinity)

                        Text(pillTitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
            } else {
                VStack(alignment: .center, spacing: 14) {
                    FDMiniStepBalancedChrome {
                        Text("taikA")
                            .font(Font.custom("ONMARK Trial", size: 14))
                            .foregroundStyle(.secondary)
                    } trailing: {
                        Group {
                            if showTopTrailingKindChip {
                                AppMiniChip(title: "лайфхак", style: .neutral) { }
                                    .allowsHitTesting(false)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .center, spacing: 8) {
                        taikaFMStyledText(hackText, baseColor: PD.ColorToken.text)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(7)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Spacer(minLength: 6)

                    pill
                }
                .padding(16)
            }
        }
        .frame(width: layoutWidth, height: layoutHeight, alignment: .topLeading)
        .background {
            ZStack {
                Theme.Surfaces.card(round)
                TaikaLifehackCrayonPalette.wash
                    .clipShape(round)
                TaikaLifehackOrganicLinesOverlay(
                    seedKey: item.id,
                    intensity: 0.95
                )
                .opacity(0.92)
                .mask(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.38), .white.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(round)
            }
        }
        .overlay(deleteButtonOverlay(round))
        .contentShape(round)
        .modifier(FDMiniHackCardGestures(
            readOnly: readOnly,
            isEditing: $isEditing,
            isJiggling: $isJiggling,
            onOpen: onOpen,
            disableCardTap: summaryPlayAndFavorite
        ))
    }
}

/// Вынесено, чтобы `readOnly` не цеплял long‑press / onChange.
private struct FDMiniHackCardGestures: ViewModifier {
    let readOnly: Bool
    @Binding var isEditing: Bool
    @Binding var isJiggling: Bool
    var onOpen: (() -> Void)?
    var disableCardTap: Bool = false

    func body(content: Content) -> some View {
        if readOnly {
            if disableCardTap {
                content
            } else {
                content
                    .onTapGesture { onOpen?() }
            }
        } else {
            content
                .onTapGesture {
                    if isEditing {
                        isEditing = false
                    } else {
                        onOpen?()
                    }
                }
                .onLongPressGesture(minimumDuration: 0.35) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isEditing.toggle()
                }
                .onChange(of: isEditing) { _, newValue in
                    isJiggling = newValue
                }
        }
    }
}

// MARK: - Итоги урока: как `FDFavHacksReel` (200×286) + play и избранное на карточке
struct FDLessonSummaryHacksReel: View {
    let courseId: String
    let lessonId: String
    let entries: [(dto: FDHackDTO, orig: Int, stepItem: SDStepItem)]
    var onPlayInLesson: ((FDHackDTO) -> Void)? = nil

    @ObservedObject private var favManager = FavoriteManager.shared

    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyView()
            } else {
                GeometryReader { geo in
                    let cardWidth: CGFloat = 200
                    let cardHeight: CGFloat = 286
                    let spacing: CGFloat = 14
                    let sideInset: CGFloat = PD.Spacing.screen

                    TaikaCarouselScroll {
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(entries, id: \.dto.id) { entry in
                                GeometryReader { itemGeo in
                                    let midX = itemGeo.frame(in: .global).midX
                                    let containerMidX = geo.frame(in: .global).midX
                                    let distance = abs(midX - containerMidX)
                                    let maxDistance = cardWidth + spacing
                                    let t = min(distance / maxDistance, 1)
                                    // Боковые карточки остаются читаемыми (раньше opacity доходила до ~0.45).
                                    let scale: CGFloat = 0.94 + (1 - t) * 0.08
                                    let opacity: Double = 0.76 + (1 - t) * 0.24
                                    let yOffset: CGFloat = t * 10

                                    FDMiniHackCard(
                                        item: entry.dto,
                                        onOpen: { onPlayInLesson?(entry.dto) },
                                        onUnfavorite: nil,
                                        readOnly: true,
                                        layoutWidth: cardWidth,
                                        layoutHeight: cardHeight,
                                        lessonSummarySquare: true,
                                        showTopTrailingKindChip: false,
                                        summaryPlayAndFavorite: true,
                                        onPlayInLesson: { onPlayInLesson?(entry.dto) },
                                        onToggleFavorite: {
                                            FavoriteManager.shared.toggle(step: entry.stepItem, courseId: courseId, lessonId: lessonId, order: entry.orig)
                                        },
                                        isFavorite: favManager.containsHack(courseId: courseId, lessonId: lessonId, index: entry.orig),
                                        isEditing: .constant(false)
                                    )
                                    .scaleEffect(scale)
                                    .opacity(opacity)
                                    .offset(y: yOffset)
                                }
                                .frame(width: cardWidth, height: cardHeight)
                            }
                        }
                        .padding(.horizontal, sideInset)
                        .padding(.vertical, 4)
                        .frame(height: cardHeight + 36)
                    }
                }
                .frame(height: 286 + 36)
            }
        }
    }
}

// MARK: - Organic lines (same DNA as CourseLessonCard / CDOrganicLearnedTreatment)

enum TaikaOrganicCardSeed {
    /// Same salt recipe as `CourseLessonCard.organicCardSeed`.
    static func value(for courseId: String) -> CGFloat {
        var hash: UInt64 = 5381
        for unit in courseId.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(unit)
        }
        return CGFloat(hash % 9973) / 997.0 + 0.37
    }
}

struct TaikaOrganicWaveShape: Shape {
    var cardSeed: CGFloat
    var lane: Int
    /// Phrase cards are smaller than course cards — dial waves down so text stays readable.
    var amplitudeScale: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let s0 = cardSeed * 1.618 + CGFloat(lane) * 2.37
        let s1 = sin(s0 * 1.1)
        let s2 = cos(s0 * 0.73)
        let s3 = sin(s0 * 2.05 + 0.4)

        let y0 = rect.height * (0.28 + 0.48 * (0.5 + 0.5 * s1))
        let y1 = rect.height * (0.22 + 0.55 * (0.5 + 0.5 * s2))
        let y2 = rect.height * (0.35 + 0.45 * (0.5 + 0.5 * s3))
        let y3 = rect.height * (0.30 + 0.50 * (0.5 + 0.5 * sin(s0 * 0.91)))

        let amp = (22 + 28 * abs(s2)) * amplitudeScale
        let flip: CGFloat = ((Int((cardSeed * 10).rounded()) &+ lane) % 2 == 0) ? 1 : -1

        var path = Path()
        path.move(to: CGPoint(x: -36, y: y0))
        path.addCurve(
            to: CGPoint(x: rect.width * (0.28 + 0.08 * s1), y: y1 + flip * amp * 0.35),
            control1: CGPoint(x: rect.width * 0.08, y: y0 - flip * amp),
            control2: CGPoint(x: rect.width * 0.18, y: y1 + flip * amp * 0.9)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * (0.58 + 0.06 * s2), y: y2 - flip * amp * 0.25),
            control1: CGPoint(x: rect.width * 0.40, y: y1 - flip * amp * 0.75),
            control2: CGPoint(x: rect.width * 0.48, y: y2 + flip * amp * 0.85)
        )
        path.addCurve(
            to: CGPoint(x: rect.width + 36, y: y3),
            control1: CGPoint(x: rect.width * 0.74, y: y2 - flip * amp * 0.55),
            control2: CGPoint(x: rect.width * 0.88, y: y3 + flip * amp * 0.4)
        )
        return path
    }
}

/// Shared vine overlay for course + favorite phrase cards (not lifehack lilac).
struct TaikaOrganicCardLinesOverlay: View {
    let cardSeed: CGFloat
    var intensity: Double = 1.0
    /// Base vine tint (course status glow). Defaults to brand accent.
    var glow: Color? = nil
    /// Optional status stroke (green/sky gradients on course cards).
    var lineStyle: AnyShapeStyle? = nil
    /// Favorite course cards add accent vines on top — phrases in Favorites are always favorited.
    var isFavorite: Bool = true
    /// Stroke thickness scale (phrase grid ≈ 0.5 vs course cards).
    var lineWidthScale: CGFloat = 1
    /// Wave amplitude scale (phrase grid ≈ 0.5).
    var amplitudeScale: CGFloat = 1

    private var resolvedGlow: Color {
        glow ?? ThemeManager.shared.currentAccentTintColor
    }

    private var statusLineStyle: AnyShapeStyle {
        lineStyle ?? AnyShapeStyle(resolvedGlow)
    }

    private var favoriteLineStyle: AnyShapeStyle {
        AnyShapeStyle(ThemeManager.shared.currentAccentFill)
    }

    private var vineCount: Int {
        // Compact phrase cards: fewer vines so text isn't covered.
        let base = 3 + (Int((cardSeed * 17).magnitude) % 2)
        if lineWidthScale < 0.75 { return max(2, base - 1) }
        return base
    }

    var body: some View {
        ZStack {
            ForEach(0..<vineCount, id: \.self) { lane in
                let mid = vineCount / 2
                TaikaOrganicWaveShape(cardSeed: cardSeed, lane: lane, amplitudeScale: amplitudeScale)
                    .stroke(
                        statusLineStyle.opacity((lane == mid ? 0.42 : 0.18) * intensity),
                        style: StrokeStyle(
                            lineWidth: (lane == mid ? 1.45 : (0.75 + CGFloat(lane % 2) * 0.2)) * lineWidthScale,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .offset(
                        x: CGFloat(lane - mid) * (6 + 4 * abs(sin(cardSeed + CGFloat(lane)))) * amplitudeScale,
                        y: CGFloat(lane - mid) * (5 + 3 * abs(cos(cardSeed * 0.7))) * amplitudeScale
                    )
            }

            if isFavorite {
                ForEach(0..<2, id: \.self) { lane in
                    TaikaOrganicWaveShape(
                        cardSeed: cardSeed + 3.1,
                        lane: lane + 1,
                        amplitudeScale: amplitudeScale
                    )
                    .stroke(
                        favoriteLineStyle.opacity((lane == 0 ? 0.38 : 0.20) * intensity),
                        style: StrokeStyle(
                            lineWidth: (lane == 0 ? 1.2 : 0.8) * lineWidthScale,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .offset(
                        x: (CGFloat(lane) * 12 - 4) * amplitudeScale,
                        y: (8 + CGFloat(lane) * 11 + sin(cardSeed) * 4) * amplitudeScale
                    )
                }
            }
        }
        .drawingGroup(opaque: false)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Lifehack crayon identity (lilac / purple — not course pink)

public enum TaikaLifehackCrayonPalette {
    /// Soft lilac → purple → violet (distinct from course accent crayons).
    public static let colors: [Color] = [
        Color(red: 0.72, green: 0.58, blue: 0.96),
        Color(red: 0.58, green: 0.42, blue: 0.88),
        Color(red: 0.82, green: 0.68, blue: 0.98),
        Color(red: 0.48, green: 0.36, blue: 0.78),
        Color(red: 0.66, green: 0.52, blue: 0.92)
    ]

    public static var primary: Color { colors[0] }
    public static var deep: Color { colors[1] }

    public static var wash: LinearGradient {
        LinearGradient(
            colors: [
                colors[0].opacity(0.22),
                colors[1].opacity(0.10),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Crayon vines for lifehack cards — same hand-drawn DNA as courses, lilac/purple only.
struct TaikaLifehackOrganicLinesOverlay: View {
    let cardSeed: CGFloat
    var intensity: Double = 1.0

    private var vineCount: Int {
        4 + (Int((cardSeed * 13).magnitude) % 2) // slightly denser than course cards
    }

    public init(cardSeed: CGFloat, intensity: Double = 1.0) {
        self.cardSeed = cardSeed
        self.intensity = intensity
    }

    public init(seedKey: String, intensity: Double = 1.0) {
        self.cardSeed = TaikaOrganicCardSeed.value(for: seedKey)
        self.intensity = intensity
    }

    var body: some View {
        ZStack {
            ForEach(0..<vineCount, id: \.self) { lane in
                let mid = vineCount / 2
                // Offset lane salt so vines don't mirror course-card patterns 1:1
                TaikaOrganicWaveShape(cardSeed: cardSeed * 1.27 + 0.8, lane: lane + 1)
                    .stroke(
                        TaikaLifehackCrayonPalette.colors[lane % TaikaLifehackCrayonPalette.colors.count]
                            .opacity((lane == mid ? 0.38 : 0.18) * intensity),
                        style: StrokeStyle(
                            lineWidth: lane == mid ? 2.0 : 1.35,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .offset(
                        x: CGFloat(lane - mid) * (5 + 3.5 * abs(sin(cardSeed + CGFloat(lane) * 1.3))),
                        y: CGFloat(lane - mid) * (4 + 3 * abs(cos(cardSeed * 0.9)))
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

enum FDMiniCourseCardStyle {
    case discovery
    case proShowcase
    case reinforcement
}

// MARK: - Mini course card (подборка дня): нейтральная карточка, фон-рисунок, шеврон вместо CTA
struct FDMiniCourseCard: View {
    let item: FDCourseDTO
    var layoutWidth: CGFloat = 200
    var layoutHeight: CGFloat = 286
    var cardStyle: FDMiniCourseCardStyle = .discovery
    var isPro: Bool = false
    var categoryChip: String? = nil
    var learningOutcomes: [String] = []
    var lessonCount: Int? = nil
    var durationMinutes: Int? = nil
    var onOpen: (() -> Void)? = nil
    /// Избранное: снять курс с избранного (как на старой `FDFavCourseCard`).
    var onUnfavorite: (() -> Void)? = nil

    private var resolvedStyle: FDMiniCourseCardStyle {
        if cardStyle == .proShowcase || (isPro && cardStyle == .discovery) {
            return .proShowcase
        }
        return cardStyle
    }

    private var cardSeed: CGFloat {
        TaikaOrganicCardSeed.value(for: item.courseId)
    }

    private var showsProSell: Bool { resolvedStyle == .proShowcase }
    /// Every mini card wears the crayon vines — PRO no longer floods the cell with pink.
    private var showsOrganic: Bool { true }

    /// Two crayon colors picked deterministically per course — cards differ like colored pencils.
    private var crayonLineStyle: AnyShapeStyle {
        let palette = TaikaCrayonCarouselPalette.colors(
            accent: ThemeManager.shared.currentAccentTintColor
        )
        let base = Int((cardSeed * 31).magnitude) % palette.count
        let pair = (base + 2) % palette.count
        return AnyShapeStyle(
            LinearGradient(
                colors: [palette[base], palette[pair]],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    var body: some View {
        cardContent
            .clipShape(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous))
            .background { cardBackground }
            .overlay { cardBorder }
            .clipShape(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous))
            .onTapGesture { onOpen?() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Открыть курс \(item.title)")
    }

    private var cardContent: some View {
        ZStack(alignment: .topTrailing) {
            organicOverlay
            cardMainColumn
        }
    }

    @ViewBuilder
    private var organicOverlay: some View {
        if showsOrganic {
            TaikaOrganicCardLinesOverlay(
                cardSeed: cardSeed,
                intensity: resolvedStyle == .reinforcement ? 1.15 : 1.0,
                lineStyle: crayonLineStyle,
                isFavorite: false,
                lineWidthScale: 0.72,
                amplitudeScale: 0.72
            )
            .clipShape(RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous))
        }
    }

    private var cardMainColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeaderRow
            Spacer(minLength: 0)
            cardTextBlock
            Spacer(minLength: 6)
            cardFooterRow
        }
        .padding(16)
        .frame(width: layoutWidth, height: layoutHeight, alignment: .topLeading)
    }

    private var cardHeaderRow: some View {
        return HStack(spacing: 8) {
            Text("taikA")
                .font(Font.custom("ONMARK Trial", size: 14))
                .foregroundStyle(Color.secondary)
            Spacer(minLength: 4)
            if resolvedStyle == .reinforcement {
                Text("пройден")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PD.ColorToken.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.45))
                .accessibilityHidden(true)
        }
    }

    private var cardTextBlock: some View {
        let style = resolvedStyle
        return VStack(alignment: .leading, spacing: 6) {
            if let chip = categoryChip?.trimmingCharacters(in: .whitespacesAndNewlines), !chip.isEmpty {
                Text(chip)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                    .allowsHitTesting(false)
            }
            Text(item.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            subtitleBlock(style: style)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Cut on a word boundary — a mid-word "…" is what makes the card unreadable.
    private static func trimmedSubtitle(_ raw: String, fallback: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return fallback }
        let limit = 86
        guard text.count > limit else { return text }
        let head = text.prefix(limit)
        guard let lastSpace = head.lastIndex(of: " ") else { return String(head) + "…" }
        return head[..<lastSpace].trimmingCharacters(in: .whitespaces) + "…"
    }

    @ViewBuilder
    private func subtitleBlock(style: FDMiniCourseCardStyle) -> some View {
        if showsProSell {
            Text(Self.trimmedSubtitle(item.subtitle, fallback: "Расширь практику с Taika+"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(3)
        } else if style == .reinforcement {
            Text(Self.trimmedSubtitle(item.subtitle, fallback: "Повтори в играх и Спикере"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(PD.ColorToken.textSecondary)
                .lineLimit(3)
        } else if !learningOutcomes.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(learningOutcomes.prefix(2)), id: \.self) { outcome in
                    Text("#\(outcome)")
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(PD.ColorToken.textSecondary)
            .minimumScaleFactor(0.9)
            .padding(.top, 3)
        }
    }

    private var cardFooterRow: some View {
        HStack(spacing: 10) {
            if let unfav = onUnfavorite {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    unfav()
                }) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.7))
                        .frame(minWidth: 34, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            if !showsProSell, resolvedStyle != .reinforcement {
                HStack(spacing: 10) {
                    if let lc = lessonCount, lc > 0 {
                        Label("\(lc)", systemImage: "square.stack.3d.up")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let dm = durationMinutes, dm > 0 {
                        Label("\(dm)m", systemImage: "clock")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        ZStack {
            Theme.Surfaces.card(round)
            if resolvedStyle == .reinforcement {
                round.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
    }

    private var cardBorder: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        return round.stroke(
            Theme.Strokes.strokeSubtle,
            lineWidth: Theme.Strokes.strokeLineWidth
        )
    }
}

// MARK: - Карточка «Продолжить» для Main: курс + урок, прогресс курса, только иконка play
struct FDContinueCourseCard: View {
    let courseName: String
    let lessonName: String
    let progress: Double
    var layoutWidth: CGFloat = 200
    var layoutHeight: CGFloat = 286
    var lessonMinutes: Int? = nil
    var onOpen: (() -> Void)? = nil

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        let clamped = max(0, min(1, progress))
        let headline = lessonName.isEmpty ? courseName : lessonName
        let showCourseCaption = !lessonName.isEmpty && !courseName.isEmpty

        VStack(alignment: .leading, spacing: 12) {
            Text("taikA")
                .font(Font.custom("ONMARK Trial", size: 14))
                .foregroundStyle(PD.ColorToken.textSecondary)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PD.ColorToken.text)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(PD.ColorToken.textSecondary.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(AnyShapeStyle(ThemeManager.shared.currentAccentFill))
                            .frame(width: max(0, g.size.width * clamped), height: 4)
                    }
                }
                .frame(height: 4)

                if showCourseCaption {
                    Text(courseName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PD.ColorToken.textSecondary.opacity(0.75))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onOpen?() }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.currentAccentFill)
                        .frame(minWidth: 34, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    if let minutes = lessonMinutes, minutes > 0 {
                        Label("\(minutes)m", systemImage: "clock")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text("\(Int(clamped * 100))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)
            }
        }
        .padding(16)
        .frame(width: layoutWidth, height: layoutHeight, alignment: .topLeading)
        .background(Theme.Surfaces.card(round))
        .contentShape(round)
        .onTapGesture { onOpen?() }
    }
}

// MARK: - Compact course card (как «Подборка дня» на Main: `FDMiniCourseCard`)
struct FDFavCourseCard: View {
    let item: FDCourseDTO
    var layoutWidth: CGFloat = 200
    var layoutHeight: CGFloat = 286
    var onOpen: (() -> Void)? = nil
    var onUnfavorite: (() -> Void)? = nil

    private var catalogCourse: Course? {
        CourseData.shared.course(with: item.courseId)
    }

    private var fallbackLessonCount: Int {
        var lessons = LessonsData.shared.lessons(for: item.courseId)
        if lessons.isEmpty {
            lessons = LessonsData.shared.lessons(for: item.courseId.replacingOccurrences(of: "_", with: "-"))
        }
        if lessons.isEmpty {
            lessons = LessonsData.shared.lessons(for: item.courseId.replacingOccurrences(of: "-", with: "_"))
        }
        return lessons.count
    }

    private var outcomeStrings: [String] {
        guard let c = catalogCourse else { return [] }
        return c.learningOutcomes.map(\.type).filter { !$0.isEmpty }
    }

    var body: some View {
        FDMiniCourseCard(
            item: item,
            layoutWidth: layoutWidth,
            layoutHeight: layoutHeight,
            isPro: catalogCourse?.isPro ?? false,
            categoryChip: catalogCourse?.category,
            learningOutcomes: outcomeStrings,
            lessonCount: catalogCourse.map(\.lessonCount) ?? (fallbackLessonCount > 0 ? fallbackLessonCount : nil),
            durationMinutes: nil,
            onOpen: { onOpen?() },
            onUnfavorite: onUnfavorite
        )
    }
}

// MARK: - Horizontal reel for courses
struct FDFavCoursesReel: View {
    let title: String
    let items: [FDCourseDTO]
    var onOpen: ((FDCourseDTO) -> Void)? = nil
    var onUnfavorite: ((FDCourseDTO) -> Void)? = nil
    var onShowAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FDSectionHeaderBar(title: title, count: items.count, onShowAll: onShowAll)

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "graduationcap")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("добавьте курс в избранное")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                GeometryReader { geo in
                    let cardWidth: CGFloat = 200
                    let cardHeight: CGFloat = 286
                    let spacing: CGFloat = 14
                    let sideInset: CGFloat = PD.Spacing.screen

                    let reelItems: [FDCourseDTO] = items
                    let centerIndex = 0

                    ScrollViewReader { proxy in
                        TaikaCarouselScroll {
                            HStack(alignment: .top, spacing: spacing) {
                                ForEach(reelItems.indices, id: \.self) { idx in
                                    let it = reelItems[idx]
                                    FDFavCourseCard(
                                        item: it,
                                        onOpen: { onOpen?(it) },
                                        onUnfavorite: { onUnfavorite?(it) }
                                    )
                                    .frame(width: cardWidth, height: cardHeight)
                                }
                            }
                            .padding(.horizontal, sideInset)
                            .padding(.vertical, 4)
                            .frame(height: cardHeight + 36)
                        }
                        .onAppear {
                            if !reelItems.isEmpty {
                                proxy.scrollTo(centerIndex, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: 286 + 36)
            }
        }
    }
}

// MARK: - Horizontal reel for lifehacks
struct FDFavHacksReel: View {
    let title: String
    let items: [FDHackDTO]
    @Binding var isEditing: Bool
    var onUnfavorite: ((FDHackDTO) -> Void)? = nil
    var onOpen: ((FDHackDTO) -> Void)? = nil
    var onShowAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FDSectionHeaderBar(title: title, count: items.count, onShowAll: onShowAll)

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "lightbulb.slash")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("здесь появятся ваши лайфхаки")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                GeometryReader { geo in
                    let cardWidth: CGFloat = 200
                    let cardHeight: CGFloat = 286
                    let spacing: CGFloat = 14
                    let sideInset: CGFloat = PD.Spacing.screen

                    let reelItems: [FDHackDTO] = items
                    let centerIndex = 0

                    ScrollViewReader { proxy in
                        TaikaCarouselScroll {
                            HStack(alignment: .top, spacing: spacing) {
                                ForEach(reelItems.indices, id: \.self) { idx in
                                    let it = reelItems[idx]
                                    FDMiniHackCard(
                                        item: it,
                                        onOpen: { onOpen?(it) },
                                        onUnfavorite: { onUnfavorite?(it) },
                                        showTopTrailingKindChip: false,
                                        isEditing: $isEditing
                                    )
                                    .frame(width: cardWidth, height: cardHeight)
                                }
                            }
                            .padding(.horizontal, sideInset)
                            .padding(.vertical, 4)
                            .frame(height: cardHeight + 36)
                        }
                        .onAppear {
                            if !reelItems.isEmpty {
                                proxy.scrollTo(centerIndex, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: 286 + 36)
            }
        }
    }
}

// MARK: - Horizontal reels section for favorites
struct FDFavReels: View {
    let title: String
    let items: [FDCardDTO]
    @Binding var order: [String]   // sourceId order for reordering
    @Binding var isEditing: Bool
    var onUnfavorite: ((FDCardDTO) -> Void)? = nil
    var onShowAll: (() -> Void)? = nil
    var onOpen: ((FDCardDTO) -> Void)? = nil
    /// Подпись при пустом списке (по умолчанию — избранное).
    var emptyMessage: String = "здесь появятся ваши избранные карточки"
    var emptySystemImage: String = "star.slash"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                FDSectionHeaderBar(title: title, count: items.count, onShowAll: onShowAll)
            }

            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: emptySystemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(emptyMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                GeometryReader { geo in
                    let cardWidth: CGFloat = 268
                    let cardHeight: CGFloat = 196
                    let spacing: CGFloat = 14
                    let sideInset: CGFloat = PD.Spacing.screen

                    let reelItems: [FDCardDTO] = items
                    let centerIndex = 0

                    ScrollViewReader { proxy in
                        TaikaCarouselScroll {
                            HStack(alignment: .top, spacing: spacing) {
                                ForEach(reelItems.indices, id: \.self) { idx in
                                    let it = reelItems[idx]
                                    FDMiniCardV(
                                        item: it,
                                        onSpeak: {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            StepAudio.shared.speakThai(it.subtitle)
                                        },
                                        onOpen: { onOpen?(it) },
                                        onDelete: { onUnfavorite?(it) },
                                        isEditing: $isEditing
                                    )
                                    .frame(width: cardWidth, height: cardHeight)
                                }
                            }
                            .padding(.horizontal, sideInset)
                            .padding(.vertical, 4)
                            .frame(height: cardHeight + 36)
                        }
                        .onAppear {
                            if !reelItems.isEmpty {
                                proxy.scrollTo(centerIndex, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: 196 + 36)
            }
        }
    }
}



// MARK: - Tiny pulsing dots (for pre-roll)
struct FDDotsIndicator: View {
    private let tick: Double = 0.35

    var body: some View {
        TimelineView(.animation) { context in
            // derive phase from current time, no timers
            let t = context.date.timeIntervalSinceReferenceDate / tick
            let phase = Int(floor(t).truncatingRemainder(dividingBy: 3))

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .frame(width: 5, height: 5)
                        .opacity(phase == i ? 1.0 : 0.35)
                        .scaleEffect(phase == i ? 1.0 : 0.85)
                }
            }
            .animation(.easeInOut(duration: tick), value: phase)
        }
    }
}

// MARK: - Typewriter marquee used in "тайка фм"
struct FDTypewriterMarquee: View {
    let messages: [String]

    var body: some View {
        // Perf-critical: Favorites screen scroll must not be forced to re-render at 20fps by a typing timer.
        // Keep Taika FM message static here (other screens use `TaikaFMBubbleTyping`).
        Text(messages.first ?? "")
        .frame(maxWidth: .infinity, alignment: .leading)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Taika FM section (marquee card)
struct FDTaikaFMSection: View {
    let title: String = "тайка фм"
    let messages: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FDSectionHeader(title: title)

            HStack(alignment: .center, spacing: 12) {
                // Mascot outside the card
                Image("mascot.favorite")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .taikaMascotChrome()
                    .padding(.leading, PD.Spacing.screen)

                // Card only for text
                let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
                FDTypewriterMarquee(messages: messages)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 68, alignment: .leading)
                    .background(
                        round.fill(PD.ColorToken.card)
                            .overlay(
                                round.fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.06), .clear, .black.opacity(0.10)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                            )
                    )
                    .overlay(round.stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth))
                    .padding(.trailing, PD.Spacing.screen)
            }
        }
    }
}

// MARK: - Screen

public struct FavoriteDS: View {
    // inbound data (already resolved by FavoriteData)
    public let courses: [FDCourseDTO]
    public let cards:   [FDCardDTO]
    public let hacks:   [FDHackDTO]

    @Binding public var isEditing: Bool
    /// Когда передан — фильтр в хедере (оверлей), полосу фильтров в теле не показываем.
    public var selectedFilter: Binding<FDK>? = nil

    // callbacks to parent view
    public var onUnfavorite: ((String) -> Void)? = nil   // id to remove
    public var onReorder: (([String]) -> Void)? = nil    // ordered ids for cards
    public var onShowAllCards:   (() -> Void)? = nil
    public var onShowAllCourses: (() -> Void)? = nil
    public var onShowAllHacks:   (() -> Void)? = nil
    public var onOpenCard: ((FDCardDTO) -> Void)? = nil
    public var onOpenCourse: ((FDCourseDTO) -> Void)? = nil

    @State private var cardOrder: [String] = []
    @State private var isHacksEditing: Bool = false
    @State private var selectedFilterInternal: FDK = .all

    public init(
        courses: [FDCourseDTO] = [],
        cards: [FDCardDTO] = [],
        hacks: [FDHackDTO] = [],
        isEditing: Binding<Bool> = .constant(false),
        selectedFilter: Binding<FDK>? = nil,
        onUnfavorite: ((String) -> Void)? = nil,
        onReorder: (([String]) -> Void)? = nil,
        onShowAllCards:   (() -> Void)? = nil,
        onShowAllCourses: (() -> Void)? = nil,
        onShowAllHacks:   (() -> Void)? = nil,
        onOpenCard: ((FDCardDTO) -> Void)? = nil,
        onOpenCourse: ((FDCourseDTO) -> Void)? = nil
    ) {
        self.courses = courses
        self.cards = cards
        self.hacks = hacks
        self._isEditing = isEditing
        self.selectedFilter = selectedFilter
        self.onUnfavorite = onUnfavorite
        self.onReorder = onReorder
        self.onShowAllCards = onShowAllCards
        self.onShowAllCourses = onShowAllCourses
        self.onShowAllHacks = onShowAllHacks
        self.onOpenCard = onOpenCard
        self.onOpenCourse = onOpenCourse
    }

    // Split cards into hacks and normal cards based on meta/sourceId prefix
    private var hackCards: [FDCardDTO] {
        cards.filter { $0.meta.hasPrefix("hack:") || $0.sourceId.hasPrefix("hack:") }
    }

    private var normalCards: [FDCardDTO] {
        cards.filter { !$0.meta.hasPrefix("hack:") && !$0.sourceId.hasPrefix("hack:") }
    }

    private var effectiveFilter: FDK {
        selectedFilter?.wrappedValue ?? selectedFilterInternal
    }

    // Filtered cards for the "карточки" section (excluding hacks)
    private var filtered: [FDCardDTO] {
        if effectiveFilter != .all {
            // Favorites currently exposes cards only for this section; leave the filter hook in place for future expansion.
        }
        // 0) Sort newest → first
        let sorted = normalCards.sorted { $0.addedAt > $1.addedAt }

        let scopeSorted: [FDCardDTO] = {
            switch effectiveFilter {
            case .all:
                return sorted
            case .cards:
                return sorted
            case .courses, .hacks:
                // Not applicable for this list; return empty to avoid confusing results.
                return []
            }
        }()

        // 1) De-duplicate by sourceId, preserving the NEW (sorted) order
        var seen = Set<String>()
        let deduped = scopeSorted.filter { seen.insert($0.sourceId).inserted }

        // 2) Build a safe dictionary; if duplicates still sneak in, prefer the first (newest)
        let dict: [String: FDCardDTO] = Dictionary(deduped.map { ($0.sourceId, $0) },
                                                   uniquingKeysWith: { (first: FDCardDTO, _ : FDCardDTO) in first })

        // 3) Respect persisted order where possible; then prepend the rest (so new ones go to the front)
        let ordered = cardOrder.compactMap { dict[$0] }
        let orderSet = Set(cardOrder)
        let extras = deduped.filter { !orderSet.contains($0.sourceId) }

        // New cards (extras) first, then the persisted order
        return extras + ordered
    }

    @ViewBuilder
    private func favReelsCards(rows: Int) -> some View {
        let reel = FDFavReels(
            title: "карточки",
            items: filtered,
            order: $cardOrder,
            isEditing: $isEditing,
            onUnfavorite: { onUnfavorite?($0.sourceId) },
            onShowAll: { onShowAllCards?() },
            onOpen: { onOpenCard?($0) }
        )
        if rows >= 2 {
            VStack(spacing: 16) { reel; reel }
        } else {
            reel
        }
    }

    @ViewBuilder
    private func favReelsHacks(items: [FDHackDTO], rows: Int) -> some View {
        let reel = FDFavHacksReel(
            title: "лайфхаки",
            items: items,
            isEditing: $isHacksEditing,
            onUnfavorite: { onUnfavorite?($0.sourceId) },
            onOpen: { it in
                let text = it.meta.isEmpty ? it.title : it.meta
                let clean = text.hasPrefix("hack:") ? String(text.dropFirst("hack:".count)) : text
                let hackId = it.sourceId.hasPrefix("hack:") ? it.sourceId : ("hack:" + it.sourceId)
                let dto = FDCardDTO(
                    sourceId: hackId,
                    title: "Лайфхак",
                    subtitle: clean,
                    meta: "hack:" + clean,
                    lessonTitle: it.lessonTitle,
                    tagText: nil,
                    addedAt: it.addedAt
                )
                onOpenCard?(dto)
            },
            onShowAll: { onShowAllHacks?() }
        )
        if rows >= 2 {
            VStack(spacing: 16) { reel; reel }
        } else {
            reel
        }
    }

    @ViewBuilder
    private func favReelsCourses(rows: Int) -> some View {
        let reel = FDFavCoursesReel(
            title: "курсы",
            items: courses,
            onOpen: { onOpenCourse?($0) },
            onUnfavorite: { c in onUnfavorite?("course:\(c.courseId)") },
            onShowAll: { onShowAllCourses?() }
        )
        if rows >= 2 {
            VStack(spacing: 16) { reel; reel }
        } else {
            reel
        }
    }

    public var body: some View {
        // Prepare hacks section: combine original hacks plus hackCards from cards
        let allHacks: [FDHackDTO] = {
            // Convert hackCards (FDCardDTO) to FDHackDTO for the hacks reel
            let hackCardDTOs: [FDHackDTO] = hackCards.map { card in
                let sid = card.sourceId.hasPrefix("hack:") ? card.sourceId : ("hack:" + card.sourceId)
                return FDHackDTO(
                    sourceId: sid,
                    title: card.title,
                    meta: card.meta,
                    lessonTitle: card.lessonTitle,
                    addedAt: card.addedAt
                )
            }
            let combined = hacks + hackCardDTOs
            var seen = Set<String>()
            return combined.filter { if seen.insert($0.sourceId).inserted { return true } else { return false } }
        }()
        TaikaRootVerticalScroll {
            LazyVStack(spacing: 24) {
                if selectedFilter == nil {
                    FDSectionHeader(title: "фильтры")
                    FDAppFiltersBar(
                        items: FDK.allCases.map { kind in
                            FDAppFilterItem(
                                id: kind.id,
                                title: kind.rawValue,
                                systemImage: kind.icon,
                                isSelected: kind == selectedFilterInternal,
                                onTap: {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedFilterInternal = kind
                                    }
                                }
                            )
                        }
                    )
                    .padding(.horizontal, PD.Spacing.screen)
                }

                if effectiveFilter == .all || effectiveFilter == .cards {
                    if !filtered.isEmpty {
                        favReelsCards(rows: effectiveFilter == .all ? 1 : 2)
                    }
                }
                if effectiveFilter == .all || effectiveFilter == .hacks {
                    if !allHacks.isEmpty {
                        favReelsHacks(items: allHacks, rows: effectiveFilter == .all ? 1 : 2)
                    }
                }

                if (effectiveFilter == .all || effectiveFilter == .courses), !courses.isEmpty {
                    favReelsCourses(rows: effectiveFilter == .all ? 1 : 2)
                }
                Spacer(minLength: 8)
            }
            .padding(.top, 16)
            .padding(.vertical, 16)
            .onAppear { syncCardOrder() }
            .onChange(of: cards) { _, _ in syncCardOrder() }
        }
    }

    private func syncCardOrder() {
        // Newest-first ids from normalCards
        let currentIds = normalCards
            .sorted { $0.addedAt > $1.addedAt }
            .reduce(into: [String]()) { arr, item in if !arr.contains(item.sourceId) { arr.append(item.sourceId) } }

        // keep only those ids that still exist and make them unique
        var newOrder: [String] = []
        for id in cardOrder where currentIds.contains(id) {
            if !newOrder.contains(id) { newOrder.append(id) }
        }
        // append missing ids in the currentIds order (already newest-first)
        for id in currentIds where !newOrder.contains(id) {
            newOrder.append(id)
        }
        cardOrder = newOrder
        onReorder?(cardOrder)
    }
}

#Preview {
    struct FavoriteDS_PreviewWrapper: View {
        @State private var isEditing: Bool = false

        var body: some View {
            let sampleCards: [FDCardDTO] = [
                .init(
                    sourceId: "s1",
                    title: "заказ кофе",
                    subtitle: "กาแฟเย็นหนึ่งแก้วครับ",
                    meta: "ка-фае йен нунг гэо кхрап",
                    lessonTitle: "кафе",
                    tagText: "фраза",
                    addedAt: Date()
                ),
                .init(
                    sourceId: "s2",
                    title: "куда едем",
                    subtitle: "ไปที่นี่ได้ไหม",
                    meta: "пай тхии нии дай май?",
                    lessonTitle: "такси",
                    tagText: "фраза",
                    addedAt: Date().addingTimeInterval(-3600)
                )
            ]

            let sampleHacks: [FDHackDTO] = [
                .init(
                    sourceId: "h1",
                    title: "Не перегружай карточку текстом — оставь смысл",
                    meta: "мини-правило UI",
                    lessonTitle: "интерфейс",
                    addedAt: Date()
                )
            ]

            let sampleCourses: [FDCourseDTO] = [
                .init(
                    courseId: "c1",
                    title: "Таиланд: базовые фразы",
                    subtitle: "путешествия и быт",
                    addedAt: Date()
                )
            ]

            return ZStack {
                PD.ColorToken.background.ignoresSafeArea()
                FavoriteDS(
                    courses: sampleCourses,
                    cards: sampleCards,
                    hacks: sampleHacks,
                    isEditing: $isEditing
                )
            }
        }
    }

    return FavoriteDS_PreviewWrapper()
}
