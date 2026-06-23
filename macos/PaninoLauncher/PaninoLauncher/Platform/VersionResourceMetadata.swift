import Foundation

extension MinecraftVersionKind {
    init(manifestType: String) {
        switch manifestType {
        case "release":
            self = .release
        case "snapshot":
            self = .snapshot
        case "old_beta":
            self = .oldBeta
        case "old_alpha":
            self = .oldAlpha
        default:
            self = .release
        }
    }

    var manifestType: String {
        switch self {
        case .release: return "release"
        case .snapshot: return "snapshot"
        case .oldBeta: return "old_beta"
        case .oldAlpha: return "old_alpha"
        }
    }
}
