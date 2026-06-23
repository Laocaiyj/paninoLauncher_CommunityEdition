import Foundation

struct LauncherApiClient: Equatable {
    let endpoint: CoreEndpoint

    func install(
        version: String,
        gameDir: String,
        loader: String? = nil,
        loaderVersion: String? = nil,
        shaderLoader: String? = nil,
        shaderVersion: String? = nil,
        instanceName: String? = nil,
        downloadOptions: CoreDownloadRuntimeOptions = CoreDownloadRuntimeOptions(concurrency: 32, retryCount: 3)
    ) async throws -> TaskAccepted {
        let body = LauncherApiInstallRequest(
            version: version,
            gameDir: gameDir,
            loader: loader,
            loaderVersion: loaderVersion,
            shaderLoader: shaderLoader,
            shaderVersion: shaderVersion,
            instanceName: instanceName,
            concurrency: downloadOptions.concurrency,
            retryCount: downloadOptions.retryCount,
            download: downloadOptions
        )
        return try await send(path: "/api/v1/install", method: "POST", body: body)
    }

    func installPreflight(_ request: CoreLoaderInstallPreflightRequest) async throws -> CoreLoaderInstallPreflightResponse {
        let downloadOptions = CoreDownloadRuntimeOptions(concurrency: 32, retryCount: 3)
        let body = LauncherApiInstallRequest(
            version: request.version,
            gameDir: request.gameDir ?? "",
            loader: request.loader,
            loaderVersion: request.loaderVersion,
            shaderLoader: request.shaderLoader,
            shaderVersion: request.shaderVersion,
            instanceName: request.instanceName,
            concurrency: downloadOptions.concurrency,
            retryCount: downloadOptions.retryCount,
            download: downloadOptions
        )
        return try await send(path: "/api/v1/install/preflight", method: "POST", body: body)
    }

    func launch(
        version: String,
        memoryMb: Int,
        javaPath: String?,
        account: MinecraftAccount?,
        gameDir: String,
        instanceId: String? = nil,
        loader: String? = nil,
        memoryPolicy: String? = nil,
        jvmProfile: String? = nil,
        customMemoryMb: Int? = nil,
        customJvmArguments: [String] = [],
        installBeforeLaunch: Bool = true,
        downloadOptions: CoreDownloadRuntimeOptions = CoreDownloadRuntimeOptions(concurrency: 32, retryCount: 3),
        jvmArguments: [String] = [],
        windowWidth: Int? = nil,
        windowHeight: Int? = nil
    ) async throws -> TaskAccepted {
        let body = LauncherApiLaunchRequest(
            version: version,
            gameDir: gameDir,
            memoryMb: memoryMb,
            java: javaPath,
            instanceId: instanceId,
            loader: loader,
            memoryPolicy: memoryPolicy,
            jvmProfile: jvmProfile,
            customMemoryMb: customMemoryMb,
            username: account?.name,
            uuid: account?.id,
            accessToken: account?.accessToken,
            jvmArgs: jvmArguments,
            customJvmArgs: customJvmArguments,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            concurrency: downloadOptions.concurrency,
            retryCount: downloadOptions.retryCount,
            download: downloadOptions,
            install: installBeforeLaunch
        )
        return try await send(path: "/api/v1/launch", method: "POST", body: body)
    }
}
