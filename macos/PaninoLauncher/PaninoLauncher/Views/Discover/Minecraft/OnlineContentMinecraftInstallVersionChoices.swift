import Foundation

extension OnlineContentDiscoveryPage {
    func refreshMinecraftInstallVersionChoices() {
        minecraftVersionOptionsTask?.cancel()
        guard let version = selectedMinecraftVersion else {
            minecraftLoaderOptions = LoaderKind.allCases.map {
                LoaderCompatibilityOption(kind: $0, recommendedVersion: nil, versions: [], isAvailable: false, reason: nil)
            }
            minecraftShaderReleases = []
            selectedMinecraftLoaderVersion = nil
            selectedShaderLoaderVersion = nil
            minecraftVersionOptionsStatus = ""
            return
        }
        let selectedLoader = selectedMinecraftLoader
        let selectedShader = selectedShaderLoader
        minecraftVersionOptionsStatus = localizedString(theme.language, english: "Loading versions...", chinese: "正在加载版本...", italian: "Caricamento versioni...", french: "Chargement versions...", spanish: "Cargando versiones...")
        minecraftVersionOptionsTask = Task {
            do {
                async let loaderMetadata = viewModel.loaderMetadata(for: version.id)
                let shaderReleases = try await minecraftInstallShaderReleases(for: version, loader: selectedLoader, shader: selectedShader)
                let loaderOptions = LoaderCompatibilityOption.options(from: try await loaderMetadata)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftLoaderOptions = loaderOptions
                    minecraftShaderReleases = shaderReleases
                    selectedMinecraftLoaderVersion = resolvedMinecraftLoaderVersion(loader: selectedLoader, options: loaderOptions)
                    selectedShaderLoaderVersion = resolvedMinecraftShaderVersion(shader: selectedShader, releases: shaderReleases)
                    minecraftVersionOptionsStatus = ""
                    handleMinecraftInstallInputChanged()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftShaderReleases = []
                    selectedShaderLoaderVersion = nil
                    minecraftVersionOptionsStatus = localizedString(
                        theme.language,
                        english: "Version lookup failed",
                        chinese: "版本查询失败",
                        italian: "Ricerca versioni fallita",
                        french: "Recherche versions échouée",
                        spanish: "Error al buscar versiones"
                    )
                    handleMinecraftInstallInputChanged()
                }
            }
        }
    }

    func minecraftInstallShaderReleases(for version: MinecraftVersionInfo, loader: LoaderKind?, shader: ShaderLoaderChoice) async throws -> [OnlineRelease] {
        guard let projectID = minecraftInstallShaderProjectID(shader) else { return [] }
        let candidateLoaders = minecraftInstallShaderLoaderCandidates(loader: loader, shader: shader)
        for candidate in candidateLoaders {
            let response = try await viewModel.contentProject(
                id: projectID,
                source: .modrinth,
                query: OnlineSearchQuery(
                    projectTypes: [.mod],
                    gameVersion: version.id,
                    loaders: [candidate],
                    sort: .newest,
                    limit: 50
                ),
                curseForgeAPIKey: nil
            )
            let releases = sortedMinecraftShaderReleases(
                response.releases.filter { release in
                    release.gameVersions.contains(version.id) && release.loaders.contains(candidate)
                }
            )
            if !releases.isEmpty {
                return releases
            }
        }
        return []
    }

    func minecraftInstallShaderProjectID(_ shader: ShaderLoaderChoice) -> String? {
        switch shader {
        case .iris:
            return "iris"
        case .oculus:
            return "oculus"
        case .none, .optiFine:
            return nil
        }
    }

    func minecraftInstallShaderLoaderCandidates(loader: LoaderKind?, shader: ShaderLoaderChoice) -> [LoaderFamily] {
        switch (shader, loader) {
        case (.iris, .quilt):
            return [.quilt, .fabric]
        case (.iris, .fabric):
            return [.fabric]
        case (.oculus, .neoForge):
            return [.neoForge, .forge]
        case (.oculus, .forge):
            return [.forge]
        default:
            return []
        }
    }

    func sortedMinecraftShaderReleases(_ releases: [OnlineRelease]) -> [OnlineRelease] {
        releases.sorted { lhs, rhs in
            let leftRank = minecraftShaderReleaseRank(lhs)
            let rightRank = minecraftShaderReleaseRank(rhs)
            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.isRecommended != rhs.isRecommended { return lhs.isRecommended }
            if lhs.publishedAt != rhs.publishedAt {
                return (lhs.publishedAt ?? .distantPast) > (rhs.publishedAt ?? .distantPast)
            }
            return lhs.versionNumber.localizedStandardCompare(rhs.versionNumber) == .orderedDescending
        }
    }

    func minecraftShaderReleaseRank(_ release: OnlineRelease) -> Int {
        switch release.releaseType {
        case .release:
            return 0
        case .beta:
            return 1
        case .alpha:
            return 2
        case .snapshot:
            return 3
        case .unknown:
            return 4
        }
    }

    func resolvedMinecraftLoaderVersion(loader: LoaderKind?, options: [LoaderCompatibilityOption]) -> String? {
        guard let loader else { return nil }
        let option = options.first { $0.kind == loader }
        if let current = selectedMinecraftLoaderVersion,
           option?.versions.contains(where: { $0.loaderVersion == current }) == true {
            return current
        }
        return option?.versions.first(where: \.stable)?.loaderVersion
    }

    func resolvedMinecraftShaderVersion(shader: ShaderLoaderChoice, releases: [OnlineRelease]) -> String? {
        guard shader == .iris || shader == .oculus else { return nil }
        if let current = selectedShaderLoaderVersion,
           releases.contains(where: { $0.id == current }) {
            return current
        }
        return releases.first(where: { $0.releaseType == .release })?.id
    }
}
