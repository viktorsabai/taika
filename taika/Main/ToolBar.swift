import SwiftUI

/// Floating bottom bar (Instagram-style liquid glass) with Taika center mic.
struct ToolBar: View {
    @Binding var selectedTab: Int   // 0...4
    @EnvironmentObject var theme: ThemeManager

    // MARK: Tokens
    private let capsuleHeight: CGFloat = 48
    private let iconSize: CGFloat = 21
    private let tapSize: CGFloat = 40
    private let bottomFloat: CGFloat = 8

    /// Горизонтальный inset капсулы тулбара — CTA спикера должны совпадать по ширине.
    static let contentHorizontalInset: CGFloat = 28

    /// Host views pad scroll content so it clears the floating capsule.
    static var recommendedBottomInset: CGFloat { Theme.Layout.bottomToolbarHeight }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tab(icon: "house", selectedIcon: "house.fill", index: 0)
            Spacer(minLength: 0)
            tab(icon: "graduationcap", selectedIcon: "graduationcap.fill", index: 1)
            Spacer(minLength: 0)
            centerOrb()
            Spacer(minLength: 0)
            tab(icon: "heart", selectedIcon: "heart.fill", index: 3)
            Spacer(minLength: 0)
            tab(icon: "person", selectedIcon: "person.fill", index: 4)
        }
        .padding(.horizontal, 10)
        .frame(height: capsuleHeight)
        .background { TaikaLiquidGlassCapsule() }
        .padding(.horizontal, Self.contentHorizontalInset)
        .padding(.bottom, bottomFloat)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Elements
    @ViewBuilder
    private func tab(icon: String, selectedIcon: String? = nil, index: Int) -> some View {
        let isSelected = selectedTab == index
        Button {
            selectTab(index)
        } label: {
            tabIcon(system: isSelected ? (selectedIcon ?? icon) : icon, selected: isSelected)
        }
        .buttonStyle(ToolBarIconButtonStyle())
        .accessibilityIdentifier("toolbar_tab_\(index)")
    }

    @ViewBuilder
    private func centerOrb() -> some View {
        let isSelected = selectedTab == 2
        Button {
            selectTab(2)
        } label: {
            tabIcon(system: isSelected ? "mic.fill" : "mic", selected: isSelected)
        }
        .buttonStyle(ToolBarIconButtonStyle())
        .accessibilityIdentifier("toolbar_center_orb")
    }

    @ViewBuilder
    private func tabIcon(system: String, selected: Bool) -> some View {
        Image(systemName: system)
            .symbolRenderingMode(.monochrome)
            .renderingMode(.template)
            .font(.system(size: iconSize, weight: selected ? .semibold : .regular))
            .foregroundStyle(iconColor(selected: selected))
            .scaleEffect(selected ? 1.0 : 0.94)
            .frame(width: tapSize, height: tapSize)
            .contentShape(Rectangle())
            .contentTransition(.symbolEffect(.replace))
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: selected)
            .symbolEffect(.bounce, value: selected ? selectedTab : -1)
    }

    private func selectTab(_ index: Int) {
        guard selectedTab != index else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            selectedTab = index
        }
    }

    private func iconColor(selected: Bool) -> AnyShapeStyle {
        if selected {
            return AnyShapeStyle(theme.currentAccentFill)
        }
        return AnyShapeStyle(Color.white.opacity(0.58))
    }
}

private struct ToolBarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct ToolBar_Previews: PreviewProvider {
    @State static var selectedTab = 2
    static var previews: some View {
        ZStack {
            PD.ColorToken.background.ignoresSafeArea()
            VStack { Spacer() }
                .safeAreaInset(edge: .bottom) {
                    ToolBar(selectedTab: $selectedTab)
                        .ignoresSafeArea(.keyboard, edges: .bottom)
                }
        }
        .previewDisplayName("Tool Bar — liquid glass")
        .environmentObject(ThemeManager.shared)
    }
}
