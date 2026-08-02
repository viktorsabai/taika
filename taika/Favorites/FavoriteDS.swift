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
        .onChange(of: isEditing) { newValue in
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
            AppMiniChip(title: pillTitle.lowercased(), style: .accent) {
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
        .background(
            Theme.Surfaces.card(round)
        )
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
                .onChange(of: isEditing) { newValue in
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

// MARK: - Mini course card (подборка дня): категория сверху справа, outcomes под названием, мета+play внизу
struct FDMiniCourseCard: View {
    let item: FDCourseDTO
    var layoutWidth: CGFloat = 200
    var layoutHeight: CGFloat = 286
    var isPro: Bool = false
    var categoryChip: String? = nil
    var learningOutcomes: [String] = []
    var lessonCount: Int? = nil
    var durationMinutes: Int? = nil
    var onOpen: (() -> Void)? = nil
    /// Избранное: снять курс с избранного (как на старой `FDFavCourseCard`).
    var onUnfavorite: (() -> Void)? = nil

    var body: some View {
        let round = RoundedRectangle(cornerRadius: PD.Radius.card, style: .continuous)
        let tint = ThemeManager.shared.currentAccentTintColor
        let accent = ThemeManager.shared.currentAccentFill

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("taikA")
                        .font(Font.custom("ONMARK Trial", size: 14))
                        .foregroundStyle(isPro ? AnyShapeStyle(accent) : AnyShapeStyle(Color.secondary))
                    Spacer(minLength: 4)
                    if isPro {
                        AppProChip(scale: 0.82)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 6) {
                    if let chip = categoryChip?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !chip.isEmpty {
                        Text(chip)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                            .allowsHitTesting(false)
                    }
                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                    if isPro {
                        Text(item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? "Расширь практику с Taika+"
                             : String(item.subtitle.prefix(72)))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(PD.ColorToken.textSecondary)
                            .lineLimit(2)
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
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 6)

                HStack(spacing: 10) {
                    if isPro {
                        Text("Открыть")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.88))
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Capsule(style: .continuous).fill(accent))
                    } else {
                        Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onOpen?() }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(accent)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(PD.ColorToken.chip)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Strokes.strokeSubtle, lineWidth: Theme.Strokes.strokeLineWidth)
                                )
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    if let unfav = onUnfavorite {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            unfav()
                        }) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(accent)
                                .frame(minWidth: 34, minHeight: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                    if !isPro {
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
            .padding(16)
            .frame(width: layoutWidth, height: layoutHeight, alignment: .topLeading)

            if isPro {
                // Tech mesh wash — продающий баннер, не учебная карточка.
                Canvas { context, size in
                    for i in 0..<6 {
                        let t = Double(i) / 5.0
                        var path = Path()
                        let y0 = size.height * (0.35 + t * 0.45)
                        let amp = 8.0 + t * 10.0
                        var x: CGFloat = 0
                        while x <= size.width {
                            let xn = Double(x / size.width)
                            let y = y0 + sin((xn * 2.2 + t) * .pi * 2) * amp
                            let pt = CGPoint(x: x, y: y)
                            if x == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                            x += 4
                        }
                        context.stroke(
                            path,
                            with: .color(tint.opacity(0.10 + (1 - t) * 0.12)),
                            lineWidth: 0.9
                        )
                    }
                }
                .allowsHitTesting(false)
                .mask(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.55), .white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
        .background {
            ZStack {
                Theme.Surfaces.card(round)
                if isPro {
                    round.fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.16),
                                Color.clear,
                                tint.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
            }
        }
        .overlay(
            Group {
                if isPro {
                    round.stroke(AnyShapeStyle(accent.opacity(0.9)), lineWidth: 1.5)
                }
            }
        )
        .shadow(color: isPro ? tint.opacity(0.28) : .clear, radius: isPro ? 14 : 0, y: isPro ? 6 : 0)
        .contentShape(round)
        .onTapGesture { onOpen?() }
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
