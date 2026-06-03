import Darwin
import Foundation

enum CoreProcessManagerError: LocalizedError, Equatable {
    case coreExecutableNotFound([String])
    case coreExitedEarly(Int32)
    case healthTimedOut
    case socketFailed(String)
    case tokenFileFailed(String)

    var errorDescription: String? {
        switch self {
        case .coreExecutableNotFound(let searchedPaths):
            return "Core executable was not found. Searched: \(searchedPaths.joined(separator: ", "))"
        case .coreExitedEarly(let status):
            return "Core exited before becoming ready with status \(status)."
        case .healthTimedOut:
            return "Core did not become ready before the health check timeout."
        case .socketFailed(let message):
            return "Failed to allocate a local port: \(message)"
        case .tokenFileFailed(let message):
            return "Failed to prepare Core session token: \(message)"
        }
    }
}

@MainActor
final class CoreProcessManager {
    private struct ManagedCoreRecord: Codable {
        let schemaVersion: Int
        let pid: Int32
        let port: Int
        let executablePath: String
        let startedAt: Date

        init(schemaVersion: Int, pid: Int32, port: Int, executablePath: String, startedAt: Date) {
            self.schemaVersion = schemaVersion
            self.pid = pid
            self.port = port
            self.executablePath = executablePath
            self.startedAt = startedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            pid = try container.decode(Int32.self, forKey: .pid)
            port = try container.decode(Int.self, forKey: .port)
            executablePath = try container.decode(String.self, forKey: .executablePath)
            startedAt = try container.decode(Date.self, forKey: .startedAt)
        }
    }

    private var process: Process?
    private var outputPipe: Pipe?
    private var endpoint: CoreEndpoint?
    private var outputBuffer = ""
    private var lastTerminationStatus: Int32?
    private var managedExecutableURL: URL?
    private var managedStartedAt: Date?

    var isRunning: Bool {
        process?.isRunning == true
    }

    func start(
        onOutput: @escaping @MainActor (String) -> Void,
        onTermination: @escaping @MainActor (Int32) -> Void = { _ in }
    ) async throws -> CoreEndpoint {
        if let endpoint, isRunning {
            if shouldRestartForUpdatedExecutable(), let process {
                await stopRunningProcess(process, apiClient: LauncherApiClient(endpoint: endpoint))
                cleanupRunningProcessState()
                Self.removeManagedCoreRecord()
            } else {
                return endpoint
            }
        }

        Self.emergencyStopRecordedCore()

        let executableURL = try findCoreExecutable()
        let port = try allocateLoopbackPort()
        let token = makeSessionToken()
        lastTerminationStatus = nil
        let endpoint = CoreEndpoint(
            baseURL: URL(string: "http://127.0.0.1:\(port)")!,
            sessionToken: token
        )

        let process = Process()
        let outputPipe = Pipe()
        let tokenFileURL = try Self.createSessionTokenFile(token: token)

        process.executableURL = executableURL
        process.arguments = Self.coreServeArguments(port: port, sessionTokenFileURL: tokenFileURL)
        process.environment = Self.coreEnvironment()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard self?.process === process else { return }
                self?.flushProcessOutput(onOutput: onOutput)
                self?.lastTerminationStatus = process.terminationStatus
                self?.cleanupRunningProcessState(keepingLastTerminationStatus: true)
                onOutput("Core exited with status \(process.terminationStatus)")
                onTermination(process.terminationStatus)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.consumeProcessOutput(text, onOutput: onOutput)
            }
        }

        do {
            try process.run()
        } catch {
            Self.removeSessionTokenFile(tokenFileURL)
            throw error
        }
        let startedAt = Date()
        do {
            try Self.recordManagedCoreProcess(
                ManagedCoreRecord(
                    schemaVersion: 2,
                    pid: process.processIdentifier,
                    port: port,
                    executablePath: executableURL.standardizedFileURL.path,
                    startedAt: startedAt
                )
            )
        } catch {
            Self.removeSessionTokenFile(tokenFileURL)
            await stopRunningProcess(process, apiClient: nil)
            throw error
        }

        self.process = process
        self.outputPipe = outputPipe
        self.endpoint = endpoint
        self.managedExecutableURL = executableURL.standardizedFileURL
        self.managedStartedAt = startedAt

        do {
            try await waitForCore(endpoint: endpoint)
            Self.removeSessionTokenFile(tokenFileURL)
            return endpoint
        } catch {
            Self.removeSessionTokenFile(tokenFileURL)
            await stopRunningProcess(process, apiClient: nil)
            Self.removeManagedCoreRecord()
            throw error
        }
    }

    func stop(using apiClient: LauncherApiClient?) async {
        guard let process else {
            Self.emergencyStopRecordedCore()
            return
        }
        await stopRunningProcess(process, apiClient: apiClient)

        cleanupRunningProcessState()
        Self.removeManagedCoreRecord()
    }

    func shouldRestartForUpdatedExecutable() -> Bool {
        guard isRunning,
              let managedExecutableURL,
              let managedStartedAt,
              let modifiedAt = try? managedExecutableURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return false
        }
        return modifiedAt > managedStartedAt.addingTimeInterval(0.25)
    }

    nonisolated static func emergencyStopRecordedCore() {
        guard let record = readManagedCoreRecord() else { return }
        defer { removeManagedCoreRecord() }
        let pid = pid_t(record.pid)
        guard pid > 0, isProcessAlive(pid) else { return }
        if let actualPath = processExecutablePath(pid: pid),
           actualPath != record.executablePath,
           URL(fileURLWithPath: actualPath).lastPathComponent != URL(fileURLWithPath: record.executablePath).lastPathComponent {
            return
        }
        signalAndWait(pid: pid, signal: SIGTERM, timeoutMicroseconds: 1_200_000)
        if isProcessAlive(pid) {
            signalAndWait(pid: pid, signal: SIGKILL, timeoutMicroseconds: 800_000)
        }
    }

    private func consumeProcessOutput(_ text: String, onOutput: @MainActor (String) -> Void) {
        outputBuffer += text
        let parts = outputBuffer.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        guard !parts.isEmpty else { return }

        let endedWithNewline = outputBuffer.last?.isNewline == true
        let completeLines = endedWithNewline ? parts : parts.dropLast()

        for line in completeLines {
            let value = String(line)
            if !value.isEmpty {
                onOutput(value)
            }
        }

        outputBuffer = endedWithNewline ? "" : String(parts.last ?? "")
    }

    private func flushProcessOutput(onOutput: @MainActor (String) -> Void) {
        let value = outputBuffer.trimmingCharacters(in: .newlines)
        outputBuffer = ""
        if !value.isEmpty {
            onOutput(value)
        }
    }

    private func cleanupRunningProcessState(keepingLastTerminationStatus: Bool = false) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        outputPipe = nil
        endpoint = nil
        outputBuffer = ""
        managedExecutableURL = nil
        managedStartedAt = nil
        if !keepingLastTerminationStatus {
            lastTerminationStatus = nil
        }
    }

    static func coreEnvironment(
        baseEnvironment: [String: String] = ProcessInfo.processInfo.environment,
        proxyAddress: String = SettingsStore.string(forKey: "Settings.ProxyAddress", default: ""),
        source: DownloadSource = LauncherSettings.storedDownloadSource(),
        retryCount: Int = LauncherSettings.storedDownloadRetryCount(),
        strategy: DownloadStrategy = LauncherSettings.storedDownloadStrategy()
    ) -> [String: String] {
        var environment = baseEnvironment
        environment["PANINO_HTTP_RETRY_COUNT"] = String(retryCount)
        environment["PANINO_DOWNLOAD_STRATEGY"] = strategy.rawValue
        applyDownloadSourceEnvironment(&environment, source: source)

        let proxyAddress = proxyAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedProxyAddress = validProxyAddress(proxyAddress) else { return environment }

        for key in ["http_proxy", "https_proxy", "all_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY"] {
            environment[key] = normalizedProxyAddress
        }
        let loopbackBypass = "127.0.0.1,localhost,::1"
        environment["no_proxy"] = environment["no_proxy"].map { "\($0),\(loopbackBypass)" } ?? loopbackBypass
        environment["NO_PROXY"] = environment["NO_PROXY"].map { "\($0),\(loopbackBypass)" } ?? loopbackBypass
        return environment
    }

    private static func validProxyAddress(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let components = URLComponents(string: value) else { return nil }
        guard let scheme = components.scheme?.lowercased(),
              ["http", "https", "socks5"].contains(scheme),
              components.host?.isEmpty == false else {
            return nil
        }
        return components.string
    }

    private static func applyDownloadSourceEnvironment(_ environment: inout [String: String], source: DownloadSource) {
        switch source {
        case .official:
            for key in sourceEndpointEnvironmentKeys {
                environment.removeValue(forKey: key)
            }
            environment.removeValue(forKey: "PANINO_DISABLE_OFFICIAL_FALLBACK")
            environment["PANINO_SOURCE_PROFILE"] = "official"
        case .bmclapi:
            for key in sourceEndpointEnvironmentKeys {
                environment.removeValue(forKey: key)
            }
            environment.removeValue(forKey: "PANINO_DISABLE_OFFICIAL_FALLBACK")
            environment["PANINO_SOURCE_PROFILE"] = "bmclapi"
            environment["PANINO_MOJANG_META_BASE"] = "https://bmclapi2.bangbang93.com"
            environment["PANINO_MOJANG_RESOURCES_BASE"] = "https://bmclapi2.bangbang93.com/assets"
            environment["PANINO_MOJANG_LIBRARIES_BASE"] = "https://bmclapi2.bangbang93.com/maven"
            environment["PANINO_FABRIC_META_BASE"] = "https://bmclapi2.bangbang93.com/fabric-meta"
            environment["PANINO_FORGE_MAVEN_BASE"] = "https://bmclapi2.bangbang93.com/maven"
            environment["PANINO_NEOFORGE_MAVEN_BASE"] = "https://bmclapi2.bangbang93.com/maven"
        case .custom:
            environment["PANINO_SOURCE_PROFILE"] = "custom"
        }
    }

    private static let sourceEndpointEnvironmentKeys = [
        "PANINO_MOJANG_META_BASE",
        "PANINO_MOJANG_RESOURCES_BASE",
        "PANINO_MOJANG_LIBRARIES_BASE",
        "PANINO_FABRIC_META_BASE",
        "PANINO_QUILT_META_BASE",
        "PANINO_FORGE_FILES_BASE",
        "PANINO_FORGE_MAVEN_BASE",
        "PANINO_NEOFORGE_MAVEN_BASE",
        "PANINO_MODRINTH_API_BASE",
        "PANINO_MODRINTH_CDN_BASE",
        "PANINO_CURSEFORGE_API_BASE"
    ]

    private func waitForCore(endpoint: CoreEndpoint) async throws {
        let apiClient = LauncherApiClient(endpoint: endpoint)

        for _ in 0..<60 {
            if let lastTerminationStatus {
                throw CoreProcessManagerError.coreExitedEarly(lastTerminationStatus)
            }

            if let process, !process.isRunning {
                throw CoreProcessManagerError.coreExitedEarly(process.terminationStatus)
            }

            do {
                let response = try await apiClient.health()
                if response.status == "ok" {
                    return
                }
            } catch {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        throw CoreProcessManagerError.healthTimedOut
    }

    private func stopRunningProcess(_ process: Process, apiClient: LauncherApiClient?) async {
        if process.isRunning, let apiClient {
            try? await apiClient.shutdown()
            if await waitForExit(process, timeoutNanoseconds: 1_500_000_000) {
                return
            }
        }

        if process.isRunning {
            process.terminate()
            if await waitForExit(process, timeoutNanoseconds: 1_000_000_000) {
                return
            }
        }

        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            _ = await waitForExit(process, timeoutNanoseconds: 800_000_000)
        }
    }

    private func waitForExit(_ process: Process, timeoutNanoseconds: UInt64) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while process.isRunning && DispatchTime.now().uptimeNanoseconds < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return !process.isRunning
    }

    private func findCoreExecutable() throws -> URL {
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

    private func makeSessionToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
            + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    nonisolated static func coreServeArguments(port: Int, sessionTokenFileURL: URL) -> [String] {
        [
            "serve",
            "--host", "127.0.0.1",
            "--port", "\(port)",
            "--session-token-file", sessionTokenFileURL.path,
            "+RTS", "-N", "-A24m", "-qn1","-Iw3", "-RTS"
        ]
    }

    nonisolated static func managedCoreRecordDataForSelfTest(
        pid: Int32,
        port: Int,
        executablePath: String,
        startedAt: Date
    ) throws -> Data {
        try JSONEncoder.panino.encode(
            ManagedCoreRecord(
                schemaVersion: 2,
                pid: pid,
                port: port,
                executablePath: executablePath,
                startedAt: startedAt
            )
        )
    }

    nonisolated static func canDecodeManagedCoreRecordForSelfTest(_ data: Data) -> Bool {
        (try? JSONDecoder.panino.decode(ManagedCoreRecord.self, from: data)) != nil
    }

    private func allocateLoopbackPort() throws -> Int {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw CoreProcessManagerError.socketFailed(String(cString: strerror(errno)))
        }
        defer { close(socketDescriptor) }

        var reuse: Int32 = 1
        setsockopt(
            socketDescriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuse,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(socketDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw CoreProcessManagerError.socketFailed(String(cString: strerror(errno)))
        }

        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                getsockname(socketDescriptor, sockaddrPointer, &length)
            }
        }
        guard nameResult == 0 else {
            throw CoreProcessManagerError.socketFailed(String(cString: strerror(errno)))
        }

        return Int(UInt16(bigEndian: address.sin_port))
    }

    nonisolated private static func recordManagedCoreProcess(_ record: ManagedCoreRecord) throws {
        let url = try managedCoreRecordURL(createDirectory: true)
        let data = try JSONEncoder.panino.encode(record)
        try data.write(to: url, options: .atomic)
    }

    nonisolated private static func readManagedCoreRecord() -> ManagedCoreRecord? {
        guard let url = try? managedCoreRecordURL(createDirectory: false),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder.panino.decode(ManagedCoreRecord.self, from: data)
    }

    nonisolated private static func createSessionTokenFile(token: String) throws -> URL {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("PaninoLauncher", isDirectory: true)
            .appendingPathComponent("core-session", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("core-token-\(UUID().uuidString)")
            let data = Data(token.utf8)
            let created = fileManager.createFile(
                atPath: url.path,
                contents: data,
                attributes: [.posixPermissions: NSNumber(value: 0o600)]
            )
            guard created else {
                throw CoreProcessManagerError.tokenFileFailed("createFile returned false")
            }
            try fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o600)], ofItemAtPath: url.path)
            return url
        } catch let error as CoreProcessManagerError {
            throw error
        } catch {
            throw CoreProcessManagerError.tokenFileFailed(error.localizedDescription)
        }
    }

    nonisolated private static func removeSessionTokenFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated private static func removeManagedCoreRecord() {
        guard let url = try? managedCoreRecordURL(createDirectory: false) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated private static func managedCoreRecordURL(createDirectory: Bool) throws -> URL {
        let directory = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: createDirectory)
            .appendingPathComponent("Panino Launcher", isDirectory: true)
        if createDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("core-process.json")
    }

    nonisolated private static func isProcessAlive(_ pid: pid_t) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }

    nonisolated private static func signalAndWait(pid: pid_t, signal: Int32, timeoutMicroseconds: useconds_t) {
        kill(pid, signal)
        var waited: useconds_t = 0
        let step: useconds_t = 100_000
        while isProcessAlive(pid) && waited < timeoutMicroseconds {
            usleep(step)
            waited += step
        }
    }

    nonisolated private static func processExecutablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
            proc_pidpath(pid, pointer.baseAddress, UInt32(pointer.count))
        }
        guard count > 0 else { return nil }
        let codeUnits = buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }
        return String(decoding: codeUnits, as: UTF8.self)
    }
}
