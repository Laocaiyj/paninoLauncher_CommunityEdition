import Darwin
import Foundation

extension CoreProcessManager {
    struct ManagedCoreRecord: Codable {
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

    nonisolated static func recordManagedCoreProcess(_ record: ManagedCoreRecord) throws {
        let url = try managedCoreRecordURL(createDirectory: true)
        let data = try JSONEncoder.panino.encode(record)
        try data.write(to: url, options: .atomic)
    }

    nonisolated static func createSessionTokenFile(token: String) throws -> URL {
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

    nonisolated static func removeSessionTokenFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated static func removeManagedCoreRecord() {
        guard let url = try? managedCoreRecordURL(createDirectory: false) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated private static func readManagedCoreRecord() -> ManagedCoreRecord? {
        guard let url = try? managedCoreRecordURL(createDirectory: false),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder.panino.decode(ManagedCoreRecord.self, from: data)
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
