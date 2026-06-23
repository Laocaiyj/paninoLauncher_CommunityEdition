import Foundation

struct MinecraftAccount: Equatable {
    let id: String
    let name: String
    let accessToken: String
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-120)
    }
}

enum AccountConnectionState: Equatable {
    case signedOut
    case restoring
    case waitingForDeviceCode(DeviceCodeSession)
    case signedIn(MinecraftAccount)
    case failed(String)

    var title: String {
        switch self {
        case .signedOut:
            return "Signed out"
        case .restoring:
            return "Restoring account"
        case .waitingForDeviceCode:
            return "Waiting for Microsoft"
        case .signedIn(let account):
            return "Signed in as \(account.name)"
        case .failed:
            return "Account error"
        }
    }

    var account: MinecraftAccount? {
        if case .signedIn(let account) = self {
            return account
        }
        return nil
    }
}

struct DeviceCodeSession: Equatable {
    let deviceCode: String
    let userCode: String
    let verificationURI: URL
    let message: String
    let intervalSeconds: Int
    let expiresAt: Date
}
