import Foundation

enum InstanceStatus: String, Codable, CaseIterable, Identifiable {
    case notInstalled
    case ready
    case installing
    case running
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notInstalled:
            return "Needs Install"
        case .ready:
            return "Ready"
        case .installing:
            return "Installing"
        case .running:
            return "Running"
        case .failed:
            return "Failed"
        }
    }
}

enum LaunchHistoryState: String, Codable, CaseIterable, Identifiable {
    case running
    case succeeded
    case failed
    case cancelled

    var id: String { rawValue }
}
