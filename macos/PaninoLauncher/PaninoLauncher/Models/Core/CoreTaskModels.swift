import Foundation

enum TaskState: String, Decodable, Equatable {
    case queued
    case running
    case succeeded
    case failed
    case cancelled

    var isActive: Bool {
        self == .queued || self == .running
    }

    var isTerminal: Bool {
        !isActive
    }
}

struct TaskSnapshot: Decodable, Equatable, Identifiable {
    let taskId: String
    let kind: String
    let version: String
    let gameDir: String?
    let requestedLoader: String?
    let requestedShaderLoader: String?
    let state: TaskState
    let message: String?
    let errorCode: String?
    let errorDetail: String?
    let diagnostic: CoreDiagnostic?
    let diagnostics: [CoreDiagnostic]
    let createdAt: String
    let updatedAt: String
    let finishedAt: String?
    let progress: TaskProgress?

    var id: String { taskId }

    init(
        taskId: String,
        kind: String,
        version: String,
        gameDir: String?,
        requestedLoader: String? = nil,
        requestedShaderLoader: String? = nil,
        state: TaskState,
        message: String?,
        errorCode: String?,
        errorDetail: String?,
        diagnostic: CoreDiagnostic? = nil,
        diagnostics: [CoreDiagnostic] = [],
        createdAt: String,
        updatedAt: String,
        finishedAt: String?,
        progress: TaskProgress?
    ) {
        self.taskId = taskId
        self.kind = kind
        self.version = version
        self.gameDir = gameDir
        self.requestedLoader = requestedLoader
        self.requestedShaderLoader = requestedShaderLoader
        self.state = state
        self.message = message
        self.errorCode = errorCode
        self.errorDetail = errorDetail
        self.diagnostic = diagnostic
        self.diagnostics = diagnostics
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.finishedAt = finishedAt
        self.progress = progress
    }

    private enum CodingKeys: String, CodingKey {
        case taskId
        case kind
        case version
        case gameDir
        case requestedLoader
        case requestedShaderLoader
        case state
        case message
        case errorCode
        case errorDetail
        case diagnostic
        case diagnostics
        case createdAt
        case updatedAt
        case finishedAt
        case progress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try container.decode(String.self, forKey: .taskId)
        kind = try container.decode(String.self, forKey: .kind)
        version = try container.decode(String.self, forKey: .version)
        gameDir = try container.decodeIfPresent(String.self, forKey: .gameDir)
        requestedLoader = try container.decodeIfPresent(String.self, forKey: .requestedLoader)
        requestedShaderLoader = try container.decodeIfPresent(String.self, forKey: .requestedShaderLoader)
        state = try container.decode(TaskState.self, forKey: .state)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)
        errorDetail = try container.decodeIfPresent(String.self, forKey: .errorDetail)
        diagnostic = try container.decodeIfPresent(CoreDiagnostic.self, forKey: .diagnostic)
        diagnostics = try container.decodeIfPresent([CoreDiagnostic].self, forKey: .diagnostics) ?? diagnostic.map { [$0] } ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        finishedAt = try container.decodeIfPresent(String.self, forKey: .finishedAt)
        progress = try container.decodeIfPresent(TaskProgress.self, forKey: .progress)
    }

    static func failedInstall(version: String, gameDir: String?, requestedLoader: String? = nil, requestedShaderLoader: String? = nil, message: String, errorCode: String?, errorDetail: String?, diagnostic: CoreDiagnostic? = nil, diagnostics: [CoreDiagnostic] = []) -> TaskSnapshot {
        let now = ISO8601DateFormatter().string(from: Date())
        return TaskSnapshot(
            taskId: "install-preflight-\(Int(Date().timeIntervalSince1970))",
            kind: "install",
            version: version,
            gameDir: gameDir,
            requestedLoader: requestedLoader,
            requestedShaderLoader: requestedShaderLoader,
            state: .failed,
            message: message,
            errorCode: errorCode,
            errorDetail: errorDetail,
            diagnostic: diagnostic,
            diagnostics: diagnostics.isEmpty ? diagnostic.map { [$0] } ?? [] : diagnostics,
            createdAt: now,
            updatedAt: now,
            finishedAt: now,
            progress: nil
        )
    }
}

struct TaskAccepted: Decodable, Equatable {
    let taskId: String
    let state: TaskState
    let task: TaskSnapshot
}
