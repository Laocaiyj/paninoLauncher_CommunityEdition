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
