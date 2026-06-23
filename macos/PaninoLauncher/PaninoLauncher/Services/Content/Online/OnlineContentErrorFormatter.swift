import Foundation

enum OnlineContentErrorFormatter {
    static func displayMessage(for error: Error) -> String {
        if case LauncherApiError.unexpectedStatus(_, let body) = error,
           let data = body.data(using: .utf8),
           let payload = try? JSONDecoder().decode(CoreErrorPayload.self, from: data) {
            if let details = payload.details, !details.isEmpty {
                return details
            }
            if let message = payload.message, !message.isEmpty {
                return message
            }
        }
        return error.localizedDescription
    }
}

private struct CoreErrorPayload: Decodable {
    let error: String?
    let message: String?
    let details: String?
}
