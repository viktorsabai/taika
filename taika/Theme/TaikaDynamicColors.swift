//
//  TaikaDynamicColors.swift
//  taika
//
//  Semantic surfaces that follow system light/dark (driven by ThemeManager.preferredScheme at root).
//

import SwiftUI
import UIKit

/// Shared light/dark palette for `PD.ColorToken` and `CD.ColorToken` — one source of truth.
public enum TaikaDynamicColors {
    public static var background: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                // Чуть глубже, чтобы карточки «всплывали» отдельным слоем.
                return UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
            default:
                // Чуть темнее «молока», чтобы белая карточка читалась отдельно.
                return UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
            }
        })
    }

    /// Slightly elevated surface (headers, secondary panels).
    public static var backgroundSecondary: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.085, green: 0.085, blue: 0.095, alpha: 1)
            default:
                return UIColor(red: 0.94, green: 0.93, blue: 0.91, alpha: 1)
            }
        })
    }

    public static var card: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                // Явнее отделена от фона — «это карточка», не просто тёмный экран.
                return UIColor(red: 0.125, green: 0.125, blue: 0.145, alpha: 1)
            default:
                return UIColor(white: 1, alpha: 1)
            }
        })
    }

    /// Обводка карточек — достаточно контрастная, чтобы контур читался «бланковым» глазом.
    public static var cardBorder: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(white: 1, alpha: 0.18)
            default:
                return UIColor(white: 0, alpha: 0.22)
            }
        })
    }

    public static var cardShadowAmbient: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(white: 0, alpha: 0.55)
            default:
                return UIColor(white: 0, alpha: 0.10)
            }
        })
    }

    public static var cardShadowTight: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(white: 0, alpha: 0.35)
            default:
                return UIColor(white: 0, alpha: 0.05)
            }
        })
    }

    public static var stroke: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(white: 1, alpha: 0.14)
            default:
                return UIColor(white: 0, alpha: 0.18)
            }
        })
    }

    public static var text: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(white: 1, alpha: 1)
            default:
                return UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
            }
        })
    }

    public static var textSecondary: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(white: 1, alpha: 0.6)
            default:
                // Чуть темнее на светлом фоне — читаемость секций/подписей.
                return UIColor(red: 0.30, green: 0.30, blue: 0.34, alpha: 1)
            }
        })
    }

    public static var chip: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(white: 1, alpha: 0.06)
            default:
                return UIColor(white: 0, alpha: 0.06)
            }
        })
    }

    /// Brand pink — same hue; slightly softer on light backgrounds.
    public static var accent: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.95, green: 0.36, blue: 0.65, alpha: 1)
            default:
                return UIColor(red: 0.88, green: 0.28, blue: 0.58, alpha: 1)
            }
        })
    }

    /// Dimmed panels / scrims (replaces fixed `Color.black.opacity(0.35)` on cards).
    public static var scrimPanel: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(white: 0, alpha: 0.38)
            default:
                return UIColor(white: 0, alpha: 0.14)
            }
        })
    }

    /// Stronger overlay (modals, recording chrome).
    public static var scrimHeavy: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(white: 0, alpha: 0.55)
            default:
                return UIColor(white: 0, alpha: 0.22)
            }
        })
    }
}
