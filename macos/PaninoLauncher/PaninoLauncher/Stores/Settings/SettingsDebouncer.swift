import Foundation

@MainActor
enum SettingsDebouncer {
    private static var tasks: [String: Task<Void, Never>] = [:]
    private static var values: [String: String] = [:]

    static func set(_ value: String, forKey key: String, delayNanoseconds: UInt64 = 350_000_000) {
        values[key] = value
        tasks[key]?.cancel()
        tasks[key] = Task {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled, let value = values[key] else { return }
            SettingsStore.set(value, forKey: key)
            values.removeValue(forKey: key)
            tasks.removeValue(forKey: key)
        }
    }

    static func flush() {
        for (key, value) in values {
            SettingsStore.set(value, forKey: key)
        }
        values.removeAll()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
