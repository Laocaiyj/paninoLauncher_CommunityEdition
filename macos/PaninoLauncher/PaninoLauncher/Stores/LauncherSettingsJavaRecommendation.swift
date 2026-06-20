import Foundation

extension LauncherSettings {
    static func javaRecommendation(for minecraftVersion: String) -> String {
        let normalized = minecraftVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let version = MinecraftVersionNumber(normalized) else {
            return "Select a Minecraft version to calculate the Java recommendation from its release family."
        }

        if version >= MinecraftVersionNumber(1, 20, 5) {
            return "Minecraft \(normalized) recommends Java 21."
        }
        if version >= MinecraftVersionNumber(1, 18, 0) {
            return "Minecraft \(normalized) recommends Java 17."
        }
        if version >= MinecraftVersionNumber(1, 17, 0) {
            return "Minecraft \(normalized) recommends Java 16."
        }
        return "Minecraft \(normalized) generally uses Java 8."
    }
}

private struct MinecraftVersionNumber: Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ rawValue: String) {
        let numberPrefix = rawValue.prefix { character in
            character.isNumber || character == "."
        }
        let parts = numberPrefix.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        major = parts[0]
        minor = parts[1]
        patch = parts.count > 2 ? parts[2] : 0
    }

    static func < (lhs: MinecraftVersionNumber, rhs: MinecraftVersionNumber) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
