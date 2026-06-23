import Foundation

enum MicrosoftAuthInput {
    static func sanitizeClientID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
