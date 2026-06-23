import Foundation

struct CoreProcessLaunchContext {
    let executableURL: URL
    let port: Int
    let endpoint: CoreEndpoint
    let tokenFileURL: URL

    init(executableURL: URL, port: Int, sessionToken: String, tokenFileURL: URL) {
        self.executableURL = executableURL
        self.port = port
        self.endpoint = CoreEndpoint(
            baseURL: URL(string: "http://127.0.0.1:\(port)")!,
            sessionToken: sessionToken
        )
        self.tokenFileURL = tokenFileURL
    }

    var serveArguments: [String] {
        CoreProcessManager.coreServeArguments(port: port, sessionTokenFileURL: tokenFileURL)
    }

    var standardizedExecutableURL: URL {
        executableURL.standardizedFileURL
    }

    func managedRecord(pid: Int32, startedAt: Date) -> CoreProcessManager.ManagedCoreRecord {
        CoreProcessManager.ManagedCoreRecord(
            schemaVersion: 2,
            pid: pid,
            port: port,
            executablePath: standardizedExecutableURL.path,
            startedAt: startedAt
        )
    }
}
