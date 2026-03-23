//
//  TaikaHeaderStyle.swift
//  taika
//

import SwiftUI

// MARK: - Header Style Definition

enum TaikaHeaderStyle {
    case main
    case course(title: String)
    case lesson(title: String)
    case profile
    case custom(title: String)
}

// MARK: - View Extension

extension View {
    
    func taikaHeader(_ style: TaikaHeaderStyle) -> some View {
        modifier(TaikaHeaderModifier(style: style))
    }
}

private struct TaikaHeaderModifier: ViewModifier {
    let style: TaikaHeaderStyle

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                headerItems
            }
    }

    @ToolbarContentBuilder
    private var headerItems: some ToolbarContent {
        switch style {

        case .main:
            ToolbarItem(placement: .principal) {
                TaikaLogoView()
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                HeaderMainActions()
            }

        case .course(let title),
             .lesson(let title),
             .custom(let title):

            ToolbarItem(placement: .navigationBarLeading) {
                BackButtonView()
            }

            ToolbarItem(placement: .principal) {
                Group {
                    switch style {
                    case .profile:
                        Text("Профиль")
                    case .course(let title),
                         .lesson(let title),
                         .custom(let title):
                        Text(title)
                    default:
                        EmptyView()
                    }
                }
                .font(.system(size: 18, weight: .semibold))
            }
            
        case .profile:

            ToolbarItem(placement: .navigationBarLeading) {
                BackButtonView()
            }

            ToolbarItem(placement: .principal) {
                Group {
                    switch style {
                    case .profile:
                        Text("Профиль")
                    case .course(let title),
                         .lesson(let title),
                         .custom(let title):
                        Text(title)
                    default:
                        EmptyView()
                    }
                }
                .font(.system(size: 18, weight: .semibold))
            }
        }
    }
}

// MARK: - Logo View

private struct TaikaLogoView: View {
    var body: some View {
        HStack(spacing: 2) {
            Text("tai")
                .foregroundStyle(.primary)
            Text("kAAA")
                .foregroundStyle(.pink)
        }
        .font(.system(size: 20, weight: .bold))
    }
}

// MARK: - Header Buttons

private struct HeaderMainActions: View {
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Button {
                theme.toggleTheme()
            } label: {
                Image(systemName: theme.preferredScheme == .dark
                      ? "sun.max.fill"
                      : "moon.fill")
            }

            Button {
                // TODO: Open PRO
            } label: {
                Image(systemName: "crown.fill")
            }
        }
    }
}

private struct BackButtonView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("")
            }
            .font(.system(size: 17, weight: .medium))
        }
    }
}

