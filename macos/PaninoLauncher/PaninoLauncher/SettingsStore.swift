import Foundation

enum SettingsStore {
    private static let microsoftClientIdKey = "MicrosoftClientID"
    private static let memoryMbKey = "MemoryMB"
    private static let javaPathKey = "JavaPath"

    static var microsoftClientId: String {
        get {
            if let environmentValue = ProcessInfo.processInfo.environment["PANINO_MICROSOFT_CLIENT_ID"],
               !environmentValue.isEmpty {
                return environmentValue
            }

            if let plistValue = Bundle.main.object(forInfoDictionaryKey: microsoftClientIdKey) as? String,
               !plistValue.isEmpty {
                return plistValue
            }

            return UserDefaults.standard.string(forKey: microsoftClientIdKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: microsoftClientIdKey)
        }
    }

    static var memoryMb: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: memoryMbKey)
            return value == 0 ? 4096 : value
        }
        set {
            let boundedValue = min(max(newValue, 1024), 16384)
            UserDefaults.standard.set(boundedValue, forKey: memoryMbKey)
        }
    }

    static var javaPath: String {
        get {
            UserDefaults.standard.string(forKey: javaPathKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: javaPathKey)
        }
    }

    static func string(forKey key: String, default defaultValue: String) -> String {
        UserDefaults.standard.string(forKey: key) ?? defaultValue
    }

    static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func data(forKey key: String) -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    static func set(_ value: String, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func set(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    static func set(_ value: Data?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

enum LauncherPaths {
    static func appSupportDirectory() throws -> URL {
        let url = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Panino Launcher", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func gameConfigurationsDirectory() throws -> URL {
        let url = try appSupportDirectory()
            .appendingPathComponent("minecraft", isDirectory: true)
            .appendingPathComponent("versions", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func backupsDirectory(category: String) throws -> URL {
        let url = try appSupportDirectory()
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent(category, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

extension JSONEncoder {
    static var panino: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var panino: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
