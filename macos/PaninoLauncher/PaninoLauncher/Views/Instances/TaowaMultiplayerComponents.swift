import Foundation

struct TaowaProfileDraft: Equatable {
    var displayName = ""
    var serverAddr = ""
    var serverPort = "7000"
    var token = ""
    var remotePort = "25565"
    var frpcPath = ""
    var enabled = true
    var hasExistingToken = false

    init() {}

    init(profile: CoreTaowaFrpProfile) {
        displayName = profile.displayName
        serverAddr = profile.serverAddr
        serverPort = String(profile.serverPort)
        token = ""
        remotePort = String(profile.remotePort)
        frpcPath = profile.frpcPath
        enabled = profile.enabled
        hasExistingToken = profile.hasToken
    }

    func request(profileId: String?) -> CoreTaowaFrpProfileRequest? {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let addr = serverAddr.trimmingCharacters(in: .whitespacesAndNewlines)
        let frpc = frpcPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !addr.isEmpty,
              !frpc.isEmpty,
              let serverPortValue = Int(serverPort.trimmingCharacters(in: .whitespacesAndNewlines)),
              let remotePortValue = Int(remotePort.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(serverPortValue),
              (1...65535).contains(remotePortValue)
        else {
            return nil
        }
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return CoreTaowaFrpProfileRequest(
            profileId: profileId,
            displayName: name,
            serverAddr: addr,
            serverPort: serverPortValue,
            token: trimmedToken.isEmpty ? nil : trimmedToken,
            remotePort: remotePortValue,
            protocolName: "tcp",
            frpcPath: frpc,
            enabled: enabled
        )
    }
}

struct TaowaWorkflowStep: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let style: StatusBadge.Style
    let isReady: Bool
}

struct TaowaRequirement: Identifiable {
    enum State {
        case ready
        case warning
        case missing

        var systemImage: String {
            switch self {
            case .ready:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.circle.fill"
            case .missing:
                return "xmark.circle.fill"
            }
        }

        var style: StatusBadge.Style {
            switch self {
            case .ready:
                return .success
            case .warning:
                return .warning
            case .missing:
                return .error
            }
        }
    }

    let id: String
    let title: String
    let state: State
}

enum TaowaSessionStatusStyle {
    static func badgeStyle(for status: String) -> StatusBadge.Style {
        switch status {
        case "running":
            return .running
        case "stopped":
            return .neutral
        case "failed":
            return .error
        default:
            return .warning
        }
    }
}
