import Foundation

@MainActor
extension LauncherViewModel {
    func sanitizedVersion() -> String {
        sanitizedVersion(nil)
    }

    func sanitizedVersion(_ value: String?) -> String {
        let trimmed = (value ?? version).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "1.20.1" : trimmed
    }

    func sanitizedJavaPath() -> String? {
        let trimmed = javaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func sanitizedGameDir(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    func logGameDirSuffix(_ value: String?) -> String {
        guard let gameDir = sanitizedGameDir(value) else { return "" }
        return " in \(gameDir)"
    }
}
