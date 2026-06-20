import Foundation

extension GameInstance {
    static let defaultCoverColorHex = "#ef4444"

    static func clampedUnit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    var contentMinecraftVersion: String {
        if let value = baseMinecraftVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            return value
        }
        return Self.contentMinecraftVersion(from: minecraftVersion)
    }

    mutating func restoreAutomaticJvmTuning(defaultMemoryMb: Int = SettingsStore.memoryMb) {
        memoryPolicy = .auto
        jvmProfile = .auto
        customMemoryMb = nil
        memoryMb = defaultMemoryMb
        customJvmArguments = ""
        jvmArguments = ""
    }

    mutating func restoreAutomaticGraphicsTuning() {
        graphicsProfile = .balanced
        graphicsManualOverrides = [:]
    }

    mutating func applyJvmTuningSnapshot(_ snapshot: JvmTuningSnapshot) {
        memoryPolicy = snapshot.memoryPolicy
        jvmProfile = snapshot.jvmProfile
        memoryMb = snapshot.configuredMemoryMb
        customMemoryMb = snapshot.customMemoryMb
        customJvmArguments = snapshot.customJvmArgs.joined(separator: " ")
        jvmArguments = customJvmArguments
    }

    private static func contentMinecraftVersion(from rawValue: String) -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return rawValue }

        let lowercased = value.lowercased()
        for marker in ["-forge-", "-neoforge-", "-fabric-", "-quilt-"] {
            guard let range = lowercased.range(of: marker) else { continue }
            let prefix = String(value[..<range.lowerBound])
            if looksLikeMinecraftRelease(prefix) {
                return prefix
            }
        }

        let parts = value.split(separator: "-").map(String.init)
        guard !parts.isEmpty else { return value }
        for index in stride(from: parts.count - 1, through: 0, by: -1) {
            let candidate = parts[index...].joined(separator: "-")
            if looksLikeMinecraftRelease(candidate) {
                return candidate
            }
        }
        return value
    }

    private static func looksLikeMinecraftRelease(_ value: String) -> Bool {
        let mainPart = value.split(separator: "-").first.map(String.init) ?? value
        let numericParts = mainPart.split(separator: ".")
        guard numericParts.count >= 2 else { return false }
        return numericParts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isNumber)
        }
    }
}
