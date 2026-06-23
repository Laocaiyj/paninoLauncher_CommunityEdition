import Foundation

struct CoreGameConfigurationRequest: Codable, Equatable, Sendable {
    let id: String?
    let name: String
    let minecraftVersion: String
    let loader: String?
    let loaderVersion: String?
    let gameDir: String
    let javaPath: String?
    let memoryMb: Int
    let memoryPolicy: String
    let jvmProfile: String
    let graphicsProfile: String
    let customMemoryMb: Int?
    let customJvmArgs: [String]
    let status: String?
    let isFavorite: Bool
    let lastLaunchedAt: String?
    let lastLaunchState: String?
    let launchCount: Int
    let isHiddenFromRecent: Bool

    init(instance: GameInstance) {
        self.id = instance.id.uuidString
        self.name = instance.name
        self.minecraftVersion = instance.minecraftVersion
        self.loader = instance.loader?.rawValue
        self.loaderVersion = instance.loaderVersion
        self.gameDir = instance.gameDirectory
        self.javaPath = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instance.javaPath
        self.memoryMb = instance.memoryMb
        self.memoryPolicy = instance.memoryPolicy.rawValue
        self.jvmProfile = instance.jvmProfile.rawValue
        self.graphicsProfile = instance.graphicsProfile.rawValue
        self.customMemoryMb = instance.customMemoryMb
        self.customJvmArgs = splitJvmArguments(instance.customJvmArguments)
        self.status = instance.status.rawValue
        self.isFavorite = instance.isFavorite
        self.lastLaunchedAt = instance.lastLaunchedAt.map { ISO8601DateFormatter().string(from: $0) }
        self.lastLaunchState = instance.lastLaunchState?.rawValue
        self.launchCount = instance.launchCount
        self.isHiddenFromRecent = instance.isHiddenFromRecent
    }
}

func splitJvmArguments(_ value: String) -> [String] {
    var result: [String] = []
    var current = ""
    var quote: Character?
    var escaping = false

    for char in value {
        if escaping {
            current.append(char)
            escaping = false
            continue
        }
        if char == "\\" {
            escaping = true
            continue
        }
        if let activeQuote = quote {
            if char == activeQuote {
                quote = nil
            } else {
                current.append(char)
            }
            continue
        }
        if char == "\"" || char == "'" {
            quote = char
            continue
        }
        if char.isWhitespace {
            if !current.isEmpty {
                result.append(current)
                current.removeAll(keepingCapacity: true)
            }
        } else {
            current.append(char)
        }
    }
    if escaping {
        current.append("\\")
    }
    if !current.isEmpty {
        result.append(current)
    }
    return result
}
