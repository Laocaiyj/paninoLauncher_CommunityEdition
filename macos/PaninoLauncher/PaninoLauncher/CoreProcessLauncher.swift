import Foundation

struct TestBinaryResult: Equatable, Sendable {
    let exitCode: Int32
    let output: String
}

enum CoreProcessLauncherError: LocalizedError, Equatable, Sendable {
    case testBinaryNotFound([String])
    case processFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .testBinaryNotFound(let searchedPaths):
            return "Test binary was not found. Searched: \(searchedPaths.joined(separator: ", "))"
        case .processFailed(let exitCode, let output):
            return "Process exited with code \(exitCode): \(output)"
        }
    }
}

final class CoreProcessLauncher: Sendable {
    func runTestBinary() async throws -> TestBinaryResult {
        try await runTestBinary(at: try defaultTestBinaryURL())
    }

    func runTestBinary(at executableURL: URL) async throws -> TestBinaryResult {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let pipe = Pipe()

            process.executableURL = executableURL
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let result = TestBinaryResult(exitCode: process.terminationStatus, output: output)

            guard result.exitCode == 0 else {
                throw CoreProcessLauncherError.processFailed(result.exitCode, result.output)
            }

            return result
        }.value
    }

    private func defaultTestBinaryURL() throws -> URL {
        let fileManager = FileManager.default
        let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("panino-test-core"),
            currentDirectory.appendingPathComponent("Support/TestBinary/panino-test-core"),
            currentDirectory.appendingPathComponent("macos/PaninoLauncher/Support/TestBinary/panino-test-core")
        ].compactMap { $0 }

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate.path) {
            return candidate
        }

        throw CoreProcessLauncherError.testBinaryNotFound(candidates.map(\.path))
    }
}
