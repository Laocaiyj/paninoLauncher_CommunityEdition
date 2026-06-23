import Foundation
import UserNotifications

@MainActor
final class UserNotificationService {
    static let shared = UserNotificationService()

    private var requestedAuthorization = false
    private var deliveredIdentifiers = Set<String>()

    private init() {}

    func requestAuthorization() {
        guard !requestedAuthorization, let center else { return }
        requestedAuthorization = true
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func notifyOnce(identifier: String, title: String, body: String) {
        guard let center else { return }
        guard deliveredIdentifiers.insert(identifier).inserted else { return }
        requestAuthorization()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        Task {
            try? await center.add(request)
        }
    }

    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return UNUserNotificationCenter.current()
    }
}
