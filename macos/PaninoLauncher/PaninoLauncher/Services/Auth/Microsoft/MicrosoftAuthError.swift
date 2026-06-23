import Foundation

enum MicrosoftAuthError: LocalizedError, Equatable {
    case missingClientId
    case invalidResponse
    case invalidVerificationURI
    case expiredDeviceCode
    case authorizationDeclined
    case minecraftProfileMissing
    case serviceError(String)

    var errorDescription: String? {
        switch self {
        case .missingClientId:
            return "Microsoft client ID is required before signing in."
        case .invalidResponse:
            return "The authentication service returned an invalid response."
        case .invalidVerificationURI:
            return "The authentication service returned an invalid verification URL."
        case .expiredDeviceCode:
            return "The Microsoft sign-in code expired."
        case .authorizationDeclined:
            return "Microsoft sign-in was cancelled or declined."
        case .minecraftProfileMissing:
            return "This Microsoft account does not have a Minecraft Java profile."
        case .serviceError(let message):
            return message
        }
    }
}
