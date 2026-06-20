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
