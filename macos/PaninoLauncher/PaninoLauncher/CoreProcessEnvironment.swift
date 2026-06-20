import Foundation

extension CoreProcessManager {
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
}
