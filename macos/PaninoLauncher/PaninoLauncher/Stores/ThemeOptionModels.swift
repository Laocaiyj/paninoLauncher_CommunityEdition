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

enum ThemePreset: String, CaseIterable, Identifiable {
    case vanilla
    case nether
    case deepDark
    case liquidGlass
    case frostedGraphite
    case minecraftAmbient
    case focusSolid
    case highLegibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vanilla:
            return "Vanilla"
        case .nether:
            return "Nether"
        case .deepDark:
            return "Deep Dark"
        case .liquidGlass:
            return "Liquid Glass"
        case .frostedGraphite:
            return "Frosted Graphite"
        case .minecraftAmbient:
            return "Minecraft Ambient"
        case .focusSolid:
            return "Focus Solid"
        case .highLegibility:
            return "High Legibility"
        }
    }
}

enum ThemeGlassStyle: String, CaseIterable, Identifiable {
    case automatic
    case clear
    case frosted
    case solid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .clear: return "Clear"
        case .frosted: return "Frosted"
        case .solid: return "Solid"
        }
    }
}

enum ThemeChromeStyle: String, CaseIterable, Identifiable {
    case integrated
    case floatingToolbar
    case edgeToEdgeSidebar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .integrated: return "Integrated"
        case .floatingToolbar: return "Floating Toolbar"
        case .edgeToEdgeSidebar: return "Edge-to-edge Sidebar"
        }
    }
}

enum ThemeDepthStyle: String, CaseIterable, Identifiable {
    case flat
    case soft
    case layered
    case retro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flat: return "Minimal"
        case .soft: return "Spatial"
        case .layered: return "Liquid"
        case .retro: return "Retro"
        }
    }
}

enum ThemeControlShape: String, CaseIterable, Identifiable {
    case roundedRect
    case capsule
    case concentric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .roundedRect: return "Rounded Rect"
        case .capsule: return "Capsule"
        case .concentric: return "Concentric"
        }
    }
}

enum ThemeMotionStyle: String, CaseIterable, Identifiable {
    case system
    case reduced
    case expressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .reduced: return "Reduced"
        case .expressive: return "Expressive"
        }
    }
}

enum MaterialStrength: String, CaseIterable, Identifiable {
    case off
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    var material: Material? {
        switch self {
        case .off:
            return nil
        case .low:
            return .ultraThinMaterial
        case .medium:
            return .regularMaterial
        case .high:
            return .thickMaterial
        }
    }
}

enum ThemeBackgroundMode: String, CaseIterable, Identifiable {
    case `default`
    case currentInstance
    case customImage
    case solidColor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .currentInstance:
            return "Current Configuration"
        case .customImage:
            return "Custom Image"
        case .solidColor:
            return "Solid Color"
        }
    }
}
