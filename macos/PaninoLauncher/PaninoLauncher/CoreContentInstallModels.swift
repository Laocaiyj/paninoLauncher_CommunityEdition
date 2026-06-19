import Foundation

struct CoreContentInstallFile: Codable, Equatable, Sendable {
    let fileName: String
    let url: URL
    let sha1: String?
    let size: Int64?
    let primary: Bool?
}

struct CoreContentInstallDependency: Codable, Equatable, Sendable {
    let projectId: String?
    let versionId: String?
    let source: String?
    let name: String
    let required: Bool
    let installed: Bool?
    let sha1: String?
}

struct CoreDownloadRuntimeOptions: Codable, Equatable, Sendable {
    let concurrency: Int
    let retryCount: Int

    let strategy: String?

    init(concurrency: Int, retryCount: Int, strategy: String? = nil) {
        self.concurrency = concurrency
        self.retryCount = retryCount
        self.strategy = strategy
    }
}

struct CoreContentInstallRequest: Codable, Equatable, Sendable {
    let source: String
    let projectId: String?
    let projectTitle: String
    let projectType: String?
    let releaseId: String
    let gameDir: String
    let targetSubdir: String
    let files: [CoreContentInstallFile]
    let dependencies: [CoreContentInstallDependency]
    let gameVersions: [String]
    let loaders: [String]
    let instances: [CoreContentTargetInstance]
    let concurrency: Int?
    let retryCount: Int?
    let download: CoreDownloadRuntimeOptions?

    init(
        source: String,
        projectId: String?,
        projectTitle: String,
        projectType: String?,
        releaseId: String,
        gameDir: String,
        targetSubdir: String,
        files: [CoreContentInstallFile],
        dependencies: [CoreContentInstallDependency],
        gameVersions: [String],
        loaders: [String],
        instances: [CoreContentTargetInstance],
        concurrency: Int?,
        retryCount: Int? = nil,
        download: CoreDownloadRuntimeOptions? = nil
    ) {
        self.source = source
        self.projectId = projectId
        self.projectTitle = projectTitle
        self.projectType = projectType
        self.releaseId = releaseId
        self.gameDir = gameDir
        self.targetSubdir = targetSubdir
        self.files = files
        self.dependencies = dependencies
        self.gameVersions = gameVersions
        self.loaders = loaders
        self.instances = instances
        self.concurrency = concurrency
        self.retryCount = retryCount
        self.download = download
    }
}

extension CoreContentInstallRequest {
    func withEffectiveDownloadOptions(_ fallback: CoreDownloadRuntimeOptions) -> CoreContentInstallRequest {
        let effectiveConcurrency = concurrency ?? download?.concurrency ?? fallback.concurrency
        let effectiveRetryCount = retryCount ?? download?.retryCount ?? fallback.retryCount
        let effectiveDownload = CoreDownloadRuntimeOptions(
            concurrency: effectiveConcurrency,
            retryCount: effectiveRetryCount,
            strategy: download?.strategy ?? fallback.strategy
        )
        return CoreContentInstallRequest(
            source: source,
            projectId: projectId,
            projectTitle: projectTitle,
            projectType: projectType,
            releaseId: releaseId,
            gameDir: gameDir,
            targetSubdir: targetSubdir,
            files: files,
            dependencies: dependencies,
            gameVersions: gameVersions,
            loaders: loaders,
            instances: instances,
            concurrency: effectiveConcurrency,
            retryCount: effectiveRetryCount,
            download: effectiveDownload
        )
    }

    func withEffectiveConcurrency(_ fallback: Int) -> CoreContentInstallRequest {
        withEffectiveDownloadOptions(
            CoreDownloadRuntimeOptions(
                concurrency: fallback,
                retryCount: retryCount ?? download?.retryCount ?? 3
            )
        )
    }
}

struct CoreContentInstallPlanFile: Decodable, Equatable, Sendable {
    let fileName: String
    let targetPath: String
    let size: Int64?
    let sha1: String?
    let action: String
    let primary: Bool
}


struct CoreContentInstallPlanResponse: Decodable, Equatable, Sendable {
    let action: String
    let source: String
    let projectId: String?
    let projectTitle: String
    let releaseId: String
    let targetDir: String
    let files: [CoreContentInstallPlanFile]
    let dependencies: [CoreContentInstallDependency]
    let warnings: [String]
    let blockedReasons: [String]
    let totalSize: Int64?
    let typedPlan: CoreTypedInstallPlan
}

struct CoreContentUpdatePlanResource: Codable, Equatable, Sendable {
    let projectId: String?
    let projectTitle: String
    let currentReleaseId: String?
    let currentFileName: String
    let currentSha1: String?
    let currentTargetPath: String
    let remoteReleaseId: String?
    let remoteFileName: String?
    let remoteUrl: String?
    let remoteSha1: String?
    let remoteSize: Int64?
    let selected: Bool?
    let dependencies: [CoreContentInstallDependency]
}

struct CoreContentUpdatePlanRequest: Codable, Equatable, Sendable {
    let mode: String
    let gameDir: String
    let source: String
    let resources: [CoreContentUpdatePlanResource]
}

struct CoreContentUpdateLockEntry: Codable, Equatable, Sendable {
    let projectId: String?
    let projectTitle: String
    let oldReleaseId: String?
    let newReleaseId: String?
    let oldSha1: String?
    let newSha1: String?
    let targetPath: String
    let backupPath: String?
}

struct CoreContentUpdatePlanResponse: Decodable, Equatable, Sendable {
    let action: String
    let mode: String
    let lockfilePath: String
    let lockEntries: [CoreContentUpdateLockEntry]
    let warnings: [String]
    let blockedReasons: [String]
    let typedPlan: CoreTypedInstallPlan
}

struct CoreContentTargetInstance: Codable, Equatable, Sendable {
    let instanceId: String?
    let name: String
    let gameDir: String
    let minecraftVersion: String
    let loader: String?
}

struct CoreContentResolveTargetsRequest: Codable, Equatable, Sendable {
    let projectType: String
    let projectTitle: String
    let releaseId: String?
    let targetSubdir: String
    let gameVersions: [String]
    let loaders: [String]
    let instances: [CoreContentTargetInstance]
}

struct CoreContentTargetCandidate: Decodable, Equatable, Identifiable, Sendable {
    let instanceId: String?
    let name: String
    let gameDir: String
    let minecraftVersion: String
    let loader: String?
    let score: Int
    let reasons: [String]
    let blockedReasons: [String]
    let recommended: Bool

    var id: String {
        [instanceId, gameDir, name].compactMap { $0 }.joined(separator: "|")
    }
}

struct CoreContentResolveTargetsResponse: Decodable, Equatable, Sendable {
    let candidates: [CoreContentTargetCandidate]
    let recommended: CoreContentTargetCandidate?
    let blockedReasons: [String]
}

struct CoreContentSearchRequest: Encodable, Equatable, Sendable {
    let source: ContentSourceID
    let text: String
    let projectTypes: [OnlineProjectType]
    let categories: [String]
    let gameVersion: String?
    let loaders: [LoaderFamily]
    let sort: OnlineContentSort
    let offset: Int
    let limit: Int
    let curseForgeAPIKey: String?

    init(source: ContentSourceID, query: OnlineSearchQuery, curseForgeAPIKey: String?) {
        self.source = source
        self.text = query.text
        self.projectTypes = Array(query.projectTypes)
        self.categories = Array(query.categories)
        self.gameVersion = query.gameVersion
        self.loaders = Array(query.loaders)
        self.sort = query.sort
        self.offset = query.offset
        self.limit = query.limit
        self.curseForgeAPIKey = curseForgeAPIKey
    }
}

struct CoreContentProjectRequest: Encodable, Equatable, Sendable {
    let source: ContentSourceID
    let projectId: String
    let query: CoreContentSearchRequest
    let curseForgeAPIKey: String?
}

struct CoreContentProjectResponse: Decodable, Equatable, Sendable {
    let project: OnlineProject
    let releases: [OnlineRelease]
}
