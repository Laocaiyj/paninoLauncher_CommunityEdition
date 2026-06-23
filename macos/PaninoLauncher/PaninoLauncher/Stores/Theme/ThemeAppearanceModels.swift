import AppKit
import SwiftUI

enum ThemeAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case highContrast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Follow System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .highContrast:
            return "High Contrast"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark, .highContrast:
            return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .highContrast:
            return NSAppearance(named: .accessibilityHighContrastDarkAqua)
                ?? NSAppearance(named: .darkAqua)
        }
    }
}

enum ThemeAccentColor: String, CaseIterable, Identifiable {
    case system
    case blue
    case emerald
    case amber
    case red
    case purple
    case graphite
    case teal
    case mint
    case pink
    case indigo
    case slate
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .blue:
            return "Blue"
        case .emerald:
            return "Emerald"
        case .amber:
            return "Amber"
        case .red:
            return "Red"
        case .purple:
            return "Purple"
        case .graphite:
            return "Graphite"
        case .teal:
            return "Teal"
        case .mint:
            return "Mint"
        case .pink:
            return "Pink"
        case .indigo:
            return "Indigo"
        case .slate:
            return "Slate"
        case .custom:
            return "Custom"
        }
    }

    var color: Color? {
        switch self {
        case .system:
            return nil
        case .blue:
            return .blue
        case .emerald:
            return .green
        case .amber:
            return .orange
        case .red:
            return .red
        case .purple:
            return .purple
        case .graphite:
            return .gray
        case .teal:
            return Color(red: 0.05, green: 0.58, blue: 0.62)
        case .mint:
            return Color(red: 0.20, green: 0.78, blue: 0.58)
        case .pink:
            return Color(red: 0.93, green: 0.20, blue: 0.55)
        case .indigo:
            return Color(red: 0.32, green: 0.36, blue: 0.93)
        case .slate:
            return Color(red: 0.38, green: 0.43, blue: 0.50)
        case .custom:
            return nil
        }
    }
}
