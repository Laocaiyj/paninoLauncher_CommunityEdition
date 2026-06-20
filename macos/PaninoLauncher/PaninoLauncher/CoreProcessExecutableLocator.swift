import Foundation

extension CoreProcessManager {
    func findCoreExecutable() throws -> URL {
        let fileManager = FileManager.default
        var searched: [URL] = []

        if let override = ProcessInfo.processInfo.environment["PANINO_CORE_PATH"] {
            let url = URL(fileURLWithPath: override)
            searched.append(url)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        let resourceCandidates = [
            Bundle.main.resourceURL?.appendingPathComponent("panino-core"),
            Bundle.main.resourceURL?.appendingPathComponent("haskell-launcher-core")
        ].compactMap { $0 }

        for candidate in resourceCandidates {
            searched.append(candidate)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        for root in repositoryRootCandidates() {
            let directCandidate = root.appendingPathComponent("core/dist-newstyle/build")
            searched.append(directCandidate)
            if let found = findExecutable(named: "panino-core", under: directCandidate) {
                return found
            }
        }

        throw CoreProcessManagerError.coreExecutableNotFound(searched.map(\.path))
    }

    private func repositoryRootCandidates() -> [URL] {
        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return [
            currentDirectory,
            currentDirectory.deletingLastPathComponent(),
            currentDirectory.deletingLastPathComponent().deletingLastPathComponent(),
            currentDirectory.appendingPathComponent("..").appendingPathComponent("..")
        ].map { $0.standardizedFileURL }
    }

    private func findExecutable(named name: String, under root: URL) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isExecutableKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == name {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
                continue
            }
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
