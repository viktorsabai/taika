//
//  TaikaCoachMark.swift
//  taika
//
//  Пачка немых иконок на одном экране. Одна шторка, несколько дырок,
//  подписи на разной длине линии, одно «Понятно».
//

import SwiftUI

enum TaikaCoachMark: String, Hashable {
    case profileCrown = "taika.coach.crown.v2"
    case courseMic = "taika.coach.courseMic.v2"
    case courseJoystick = "taika.coach.joystick.v2"
    case gameStar = "taika.coach.star.v2"
    case speakerPoliteness = "taika.coach.politeness.v2"

    var title: String {
        switch self {
        case .profileCrown: return "Профиль и подписка"
        case .courseMic: return "Тренировка вслух"
        case .courseJoystick: return "Игра из пройденного"
        case .gameStar: return "Подсказка за звёзды"
        case .speakerPoliteness: return "Как ты говоришь"
        }
    }
}

enum TaikaCoachPack: String, CaseIterable {
    case mainCrown = "taika.coach.pack.crown.v2"
    case courseChrome = "taika.coach.pack.course.v4"
    case gameStar = "taika.coach.pack.star.v2"
    case speakerPoliteness = "taika.coach.pack.politeness.v2"

    var marks: [TaikaCoachMark] {
        switch self {
        case .mainCrown: return [.profileCrown]
        case .courseChrome: return [.courseMic, .courseJoystick]
        case .gameStar: return [.gameStar]
        case .speakerPoliteness: return [.speakerPoliteness]
        }
    }
}

struct TaikaCoachFrameKey: PreferenceKey {
    static var defaultValue: [TaikaCoachMark: CGRect] = [:]
    static func reduce(value: inout [TaikaCoachMark: CGRect], nextValue: () -> [TaikaCoachMark: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

@MainActor
final class TaikaCoachCenter: ObservableObject {
    static let shared = TaikaCoachCenter()

    @Published private(set) var frames: [TaikaCoachMark: CGRect] = [:]
    @Published private(set) var revision = 0

    private init() {}

    func seen(_ pack: TaikaCoachPack) -> Bool {
        UserDefaults.standard.bool(forKey: pack.rawValue)
    }

    func dismiss(_ pack: TaikaCoachPack) {
        UserDefaults.standard.set(true, forKey: pack.rawValue)
        for mark in pack.marks {
            UserDefaults.standard.set(true, forKey: mark.rawValue)
        }
        revision += 1
    }

    func update(_ next: [TaikaCoachMark: CGRect]) {
        let snapped = next.mapValues { rect in
            CGRect(
                x: rect.minX.rounded(),
                y: rect.minY.rounded(),
                width: rect.width.rounded(),
                height: rect.height.rounded()
            )
        }.filter { $0.value.width > 12 && $0.value.height > 12 }
        guard snapped != frames else { return }
        frames = snapped
    }

    func activePack(onboardingDone: Bool, overlayVisible: Bool) -> TaikaCoachPack? {
        guard onboardingDone, !overlayVisible else { return nil }
        _ = revision
        return TaikaCoachPack.allCases.first { pack in
            !seen(pack) && pack.marks.contains { frames[$0] != nil }
        }
    }

    func targets(for pack: TaikaCoachPack) -> [(mark: TaikaCoachMark, hole: CGRect)] {
        pack.marks.compactMap { mark in
            guard let hole = frames[mark] else { return nil }
            return (mark, hole)
        }
    }
}

extension View {
    func taikaCoachAnchor(_ mark: TaikaCoachMark) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: TaikaCoachFrameKey.self,
                    value: [mark: geo.frame(in: .global)]
                )
            }
        )
    }
}

struct TaikaCoachScrim: View {
    let targets: [(title: String, hole: CGRect)]
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ink = Color.white.opacity(0.92)
    private let labelWidth: CGFloat = 132
    private let labelHeight: CGFloat = 44

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let placed = Self.place(
                targets: targets,
                origin: origin,
                screen: proxy.size,
                labelWidth: labelWidth,
                labelHeight: labelHeight
            )
            let holes = placed.map(\.hole)
            let button = Self.buttonPoint(placed: placed, screen: proxy.size)

            ZStack {
                dim(in: proxy.size, holes: holes)

                ForEach(Array(placed.enumerated()), id: \.offset) { _, item in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ink, lineWidth: 1.5)
                        .frame(width: item.hole.width, height: item.hole.height)
                        .position(x: item.hole.midX, y: item.hole.midY)
                        .allowsHitTesting(false)

                    Path { path in
                        Self.elbow(
                            path: &path,
                            from: item.lineStart,
                            corner: item.corner,
                            to: item.lineEnd
                        )
                    }
                    .stroke(
                        ink,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter)
                    )
                    .allowsHitTesting(false)

                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(item.align)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .frame(
                            width: item.labelWidth,
                            height: labelHeight,
                            alignment: item.frameAlign
                        )
                        .position(item.label)
                        .allowsHitTesting(false)
                }

                Button(action: onDismiss) {
                    Text("Понятно")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
                .position(button)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(targets.map(\.title).joined(separator: ". ") + ". Понятно")
            .accessibilityHint("Закрыть подсказку")
            .accessibilityAddTraits(.isButton)
        }
        .ignoresSafeArea()
        .transition(reduceMotion ? .identity : .opacity)
    }

    private struct Placed {
        let title: String
        let hole: CGRect
        let label: CGPoint
        let labelWidth: CGFloat
        let align: TextAlignment
        let lineStart: CGPoint
        let corner: CGPoint
        let lineEnd: CGPoint

        var frameAlign: Alignment {
            switch align {
            case .trailing: return .trailing
            case .leading: return .leading
            default: return .center
            }
        }
    }

    /// Подпись висит под своей иконкой, линия только 90° и стыкуется сверху текста — не через буквы.
    private static func place(
        targets: [(title: String, hole: CGRect)],
        origin: CGPoint,
        screen: CGSize,
        labelWidth: CGFloat,
        labelHeight: CGFloat
    ) -> [Placed] {
        let pairs = targets.map { item -> (String, CGRect) in
            let hole = item.hole.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -10, dy: -10)
            return (item.title, hole)
        }
        .sorted { $0.1.midX < $1.1.midX }

        guard !pairs.isEmpty else { return [] }

        let cluster = pairs.map(\.1).reduce(CGRect.null) { $0.union($1) }
        let margin: CGFloat = 16
        let below = cluster.maxY + 56 + CGFloat(pairs.count) * 52 + 56 < screen.height
        let rightSide = cluster.midX > screen.width * 0.52
        let align: TextAlignment = pairs.count > 1 ? (rightSide ? .trailing : .leading) : .center

        var result: [Placed] = []
        for (index, pair) in pairs.enumerated() {
            let hole = pair.1
            let width = labelWidth
            let rawX: CGFloat = {
                if pairs.count == 1 {
                    return hole.midX
                }
                if rightSide {
                    return hole.midX - width / 2 + 18
                }
                return hole.midX + width / 2 - 18
            }()
            let labelX = min(max(rawX, margin + width / 2), screen.width - margin - width / 2)
            let stem: CGFloat = 28 + CGFloat(index) * 56
            let labelY = below
                ? hole.maxY + stem + labelHeight / 2
                : hole.minY - stem - labelHeight / 2
            result.append(
                makePlaced(
                    title: pair.0,
                    hole: hole,
                    label: CGPoint(x: labelX, y: labelY),
                    labelWidth: width,
                    labelHeight: labelHeight,
                    below: below,
                    align: align
                )
            )
        }
        return result
    }

    private static func makePlaced(
        title: String,
        hole: CGRect,
        label: CGPoint,
        labelWidth: CGFloat,
        labelHeight: CGFloat,
        below: Bool,
        align: TextAlignment
    ) -> Placed {
        let start = CGPoint(x: hole.midX, y: below ? hole.maxY : hole.minY)
        let labelMinX = label.x - labelWidth / 2
        let labelMaxX = label.x + labelWidth / 2
        let railY = below ? label.y - labelHeight / 2 : label.y + labelHeight / 2

        if hole.midX >= labelMinX + 6 && hole.midX <= labelMaxX - 6 {
            let end = CGPoint(x: hole.midX, y: railY)
            return Placed(
                title: title,
                hole: hole,
                label: label,
                labelWidth: labelWidth,
                align: align,
                lineStart: start,
                corner: end,
                lineEnd: end
            )
        }

        let attachX = hole.midX < label.x ? labelMinX : labelMaxX
        let corner = CGPoint(x: hole.midX, y: railY)
        let end = CGPoint(x: attachX, y: railY)
        return Placed(
            title: title,
            hole: hole,
            label: label,
            labelWidth: labelWidth,
            align: align,
            lineStart: start,
            corner: corner,
            lineEnd: end
        )
    }

    private static func buttonPoint(placed: [Placed], screen: CGSize) -> CGPoint {
        let lowest = placed.max(by: { $0.label.y < $1.label.y })
        let x = lowest?.label.x ?? screen.width * 0.5
        let y = min((lowest?.label.y ?? screen.height * 0.45) + 50, screen.height - 52)
        return CGPoint(x: x, y: y)
    }

    private static func elbow(path: inout Path, from start: CGPoint, corner: CGPoint, to end: CGPoint) {
        path.move(to: start)
        if corner != start {
            path.addLine(to: corner)
        }
        if end != corner {
            path.addLine(to: end)
        }
    }

    private func dim(in size: CGSize, holes: [CGRect]) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            for hole in holes {
                path.addRoundedRect(in: hole, cornerSize: CGSize(width: 16, height: 16))
            }
        }
        .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }
}
