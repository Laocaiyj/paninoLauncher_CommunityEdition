import Foundation

struct CoreEndpoint: Equatable {
    let baseURL: URL
    let sessionToken: String
}

struct HealthResponse: Decodable, Equatable {
    let status: String
    let service: String
    let time: String
}

enum CoreConnectionState: Equatable {
    case stopped
    case starting
    case running
    case stopping
    case failed(String)

    var title: String {
        switch self {
        case .stopped:
            return "Core stopped"
        case .starting:
            return "Starting Core"
        case .running:
            return "Core connected"
        case .stopping:
            return "Stopping Core"
        case .failed:
            return "Core failed"
        }
    }

    var detail: String {
        switch self {
        case .failed(let message):
            return message
        default:
            return title
        }
    }

    var isReady: Bool {
        self == .running
    }
}
