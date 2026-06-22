import Foundation

enum CoreProcessManagerError: LocalizedError, Equatable {
    case coreExecutableNotFound([String])
    case coreExitedEarly(Int32)
    case healthTimedOut
    case socketFailed(String)
    case tokenFileFailed(String)

    var errorDescription: String? {
        switch self {
        case .coreExecutableNotFound(let searchedPaths):
            return "Core executable was not found. Searched: \(searchedPaths.joined(separator: ", "))"
        case .coreExitedEarly(let status):
            return "Core exited before becoming ready with status \(status)."
        case .healthTimedOut:
            return "Core did not become ready before the health check timeout."
        case .socketFailed(let message):
            return "Failed to allocate a local port: \(message)"
        case .tokenFileFailed(let message):
            return "Failed to prepare Core session token: \(message)"
        }
    }
}
