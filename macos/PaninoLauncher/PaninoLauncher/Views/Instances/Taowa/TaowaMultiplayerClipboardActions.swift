import AppKit

extension TaowaMultiplayerPage {
    func copy(_ value: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copyStatus = message
        errorText = nil
    }
}
