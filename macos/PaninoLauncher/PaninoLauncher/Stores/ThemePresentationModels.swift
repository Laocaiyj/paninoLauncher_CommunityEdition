import SwiftUI

enum FontDensity: String, CaseIterable, Identifiable {
    case compact
    case standard
    case comfortable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact:
            return "Compact"
        case .standard:
            return "Standard"
        case .comfortable:
            return "Comfortable"
        }
    }

    var spacing: CGFloat {
        switch self {
        case .compact:
            return 8
        case .standard:
            return 12
        case .comfortable:
            return 16
        }
    }

    var controlHeight: CGFloat {
        switch self {
        case .compact:
            return 28
        case .standard:
            return 32
        case .comfortable:
            return 36
        }
    }

    var controlSize: ControlSize {
        switch self {
        case .compact:
            return .small
        case .standard:
            return .regular
        case .comfortable:
            return .large
        }
    }

    var panelPadding: CGFloat {
        switch self {
        case .compact:
            return 12
        case .standard:
            return 16
        case .comfortable:
            return 22
        }
    }

    var buttonHorizontalPadding: CGFloat {
        switch self {
        case .compact:
            return 10
        case .standard:
            return 12
        case .comfortable:
            return 16
        }
    }

    var buttonMinHeight: CGFloat {
        switch self {
        case .compact:
            return 32
        case .standard:
            return 36
        case .comfortable:
            return 44
        }
    }

    var settingsRowVerticalPadding: CGFloat {
        switch self {
        case .compact:
            return 0
        case .standard:
            return 3
        case .comfortable:
            return 7
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case chineseSimplified = "zh-Hans"
    case english = "en"
    case italian = "it"
    case french = "fr"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chineseSimplified:
            return "中文"
        case .english:
            return "English"
        case .italian:
            return "Italiano"
        case .french:
            return "Français"
        case .spanish:
            return "Español"
        }
    }
}
