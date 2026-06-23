import SwiftUI

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
