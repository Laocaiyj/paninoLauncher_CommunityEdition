import AppKit
import Foundation

extension OnlineContentDiscoveryPage {
    func openMinecraftInstallDetail(_ version: MinecraftVersionInfo) {
        selectedMinecraftVersion = version
        selectedMinecraftLoader = nil
        selectedMinecraftLoaderVersion = nil
        selectedShaderLoader = .none
        selectedShaderLoaderVersion = nil
        minecraftShaderReleases = []
        minecraftVersionOptionsStatus = ""
        minecraftInstallTarget = .newConfiguration
        minecraftInstanceName = ""
        minecraftInstallChoicePreflights = [:]
        refreshMinecraftInstallVersionChoices()
        handleMinecraftInstallInputChanged()
    }

    func handleMinecraftInstallSelectionChanged() {
        refreshMinecraftInstallVersionChoices()
        handleMinecraftInstallInputChanged()
    }

    func handleMinecraftInstallInputChanged() {
        debounceMinecraftInstallPreflight()
        debounceMinecraftInstallChoicePreflights()
    }

    func cancelTransientTasks() {
        searchDebounceTask?.cancel()
        targetResolutionTask?.cancel()
        minecraftInstallPreflightTask?.cancel()
        minecraftInstallChoicePreflightTask?.cancel()
        minecraftVersionOptionsTask?.cancel()
    }

    func installSelectedMinecraftVersion() {
        guard let version = selectedMinecraftVersion else { return }
        minecraftInstallTarget = .newConfiguration
        let trimmedName = minecraftInstanceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            minecraftInstallPreflightStatus = localizedString(
                theme.language,
                english: "Enter a unique local instance name before installing.",
                chinese: "安装前请手动输入一个唯一的本地实例名称。",
                italian: "Inserisci un nome istanza locale univoco prima di installare.",
                french: "Saisissez un nom d'instance locale unique avant l'installation.",
                spanish: "Introduce un nombre de instancia local único antes de instalar."
            )
            return
        }
        let targetGameDir = minecraftInstallGameDirectory(for: version)
        guard let targetGameDir else {
            minecraftInstallPreflightStatus = localizedString(
                theme.language,
                english: "The local instance name does not produce a valid target folder.",
                chinese: "当前本地实例名称无法生成有效目标目录。",
                italian: "Il nome istanza non produce una cartella valida.",
                french: "Le nom d'instance ne produit pas de dossier valide.",
                spanish: "El nombre de instancia no genera una carpeta válida."
            )
            return
        }
        guard !minecraftInstallTargetDirectoryConflictExists(URL(fileURLWithPath: targetGameDir, isDirectory: true)) else {
            minecraftInstallPreflightStatus = localizedString(
                theme.language,
                english: "This target folder already exists. Rename the local instance before installing.",
                chinese: "目标目录已存在。请先重命名本地实例再安装。",
                italian: "La cartella esiste già. Rinomina l'istanza prima di installare.",
                french: "Le dossier existe déjà. Renommez l'instance avant l'installation.",
                spanish: "La carpeta ya existe. Cambia el nombre antes de instalar."
            )
            return
        }
        let requestedShader = selectedShaderLoader == .none ? nil : selectedShaderLoader.rawValue
        guard minecraftShaderLoaderCompatible(loader: selectedMinecraftLoader?.rawValue, shaderLoader: requestedShader) else {
            minecraftInstallPreflightStatus = localizedString(
                theme.language,
                english: "\(selectedShaderLoader.title) cannot be installed with \(selectedMinecraftLoader?.title ?? "Vanilla").",
                chinese: "\(selectedShaderLoader.title) 不能与 \(selectedMinecraftLoader?.title ?? "Vanilla") 一起安装。",
                italian: "\(selectedShaderLoader.title) non puo essere installato con \(selectedMinecraftLoader?.title ?? "Vanilla").",
                french: "\(selectedShaderLoader.title) ne peut pas etre installe avec \(selectedMinecraftLoader?.title ?? "Vanilla").",
                spanish: "\(selectedShaderLoader.title) no se puede instalar con \(selectedMinecraftLoader?.title ?? "Vanilla")."
            )
            return
        }
        if let preflight = minecraftInstallPreflight, preflight.isBlocked {
            minecraftInstallPreflightStatus = preflight.displaySummary
            return
        }

        viewModel.version = version.id

        viewModel.install(
            gameDir: targetGameDir,
            loader: selectedMinecraftLoader,
            loaderVersion: selectedMinecraftLoaderVersion,
            shaderLoader: automaticMinecraftInstallShaderLoader(),
            shaderVersion: automaticMinecraftInstallShaderVersion(),
            instanceName: trimmedName
        )
        openTasks()
    }

    func exportMinecraftInstallDiagnostics() {
        diagnosticsStore.exportDiagnosticPackage(
            logs: viewModel.logs,
            tasks: taskCenterStore.records,
            coreState: viewModel.coreState,
            javaStatus: viewModel.javaStatus,
            managedJavaRuntimes: viewModel.managedJavaRuntimes,
            javaRuntimeResolution: viewModel.javaRuntimeResolution
        )
        openTasks()
    }

    func openMinecraftInstallDirectory() {
        guard let version = selectedMinecraftVersion,
              let path = minecraftInstallGameDirectory(for: version) else {
            FinderIntegration.openDownloadCache()
            return
        }
        let targetURL = URL(fileURLWithPath: path, isDirectory: true)
        if FileManager.default.fileExists(atPath: targetURL.path) {
            NSWorkspace.shared.open(targetURL)
        } else {
            NSWorkspace.shared.open(targetURL.deletingLastPathComponent())
        }
    }

    func downloadMinecraftInstallJava(_ majorVersion: Int) {
        viewModel.installManagedJavaRuntime(featureVersion: majorVersion)
        openTasks()
    }

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

    func debounceMinecraftInstallPreflight() {
        minecraftInstallPreflightTask?.cancel()
        guard let version = selectedMinecraftVersion else {
            minecraftInstallPreflight = nil
            minecraftInstallPreflightStatus = ""
            return
        }
        let targetGameDir: String? = nil
        let loader = selectedMinecraftLoader?.rawValue
        let shader = minecraftShaderLoaderForPreflight(loader: loader, shaderLoader: selectedShaderLoader == .none ? nil : selectedShaderLoader.rawValue)
        let name = minecraftInstallDisplayName(for: version)
        minecraftInstallPreflightStatus = localizedString(theme.language, english: "Checking install compatibility...", chinese: "正在检查安装兼容性...", italian: "Controllo compatibilità...", french: "Vérification compatibilité...", spanish: "Comprobando compatibilidad...")
        minecraftInstallPreflightTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let result = try await viewModel.installPreflight(
                    CoreLoaderInstallPreflightRequest(
                        version: version.id,
                        gameDir: targetGameDir,
                        loader: loader,
                        loaderVersion: selectedMinecraftLoaderVersion,
                        shaderLoader: shader,
                        shaderVersion: automaticMinecraftInstallShaderVersion(),
                        instanceName: name
                    )
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftInstallPreflight = result
                    minecraftInstallPreflightStatus = ""
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftInstallPreflight = nil
                    minecraftInstallPreflightStatus = localizedString(
                        theme.language,
                        english: "Preflight failed: \(error.localizedDescription)",
                        chinese: "预检失败：\(error.localizedDescription)",
                        italian: "Preflight fallito: \(error.localizedDescription)",
                        french: "Précontrôle échoué : \(error.localizedDescription)",
                        spanish: "Preflight falló: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    func debounceMinecraftInstallChoicePreflights() {
        minecraftInstallChoicePreflightTask?.cancel()
        guard let version = selectedMinecraftVersion else {
            minecraftInstallChoicePreflights = [:]
            return
        }
        let targetGameDir: String? = nil
        let selectedLoader = selectedMinecraftLoader?.rawValue
        let selectedShader = selectedShaderLoader == .none ? nil : selectedShaderLoader.rawValue
        let name = minecraftInstallDisplayName(for: version)
        let loaderCandidates: [String?] = [nil] + LoaderKind.allCases.map { Optional($0.rawValue) }
        let shaderCandidates: [String?] = [nil] + ShaderLoaderChoice.allCases
            .filter { $0 != .none }
            .map { Optional($0.rawValue) }
        var requests: [(key: String, loader: String?, shader: String?)] = []
        for loaderCandidate in loaderCandidates {
            let shaderForCandidate = minecraftShaderLoaderForPreflight(loader: loaderCandidate, shaderLoader: selectedShader)
            requests.append((
                key: minecraftInstallChoiceKey(loader: loaderCandidate, shaderLoader: shaderForCandidate),
                loader: loaderCandidate,
                shader: shaderForCandidate
            ))
        }
        for shaderCandidate in shaderCandidates {
            requests.append((
                key: minecraftInstallChoiceKey(loader: selectedLoader, shaderLoader: shaderCandidate),
                loader: selectedLoader,
                shader: shaderCandidate
            ))
        }
        let uniqueRequests = requests.reduce(into: [(key: String, loader: String?, shader: String?)]()) { result, request in
            if !result.contains(where: { $0.key == request.key }) {
                result.append(request)
            }
        }
        minecraftInstallChoicePreflightTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            var results: [String: CoreLoaderInstallPreflightResponse] = [:]
            for request in uniqueRequests {
                guard !Task.isCancelled else { return }
                do {
                    let result = try await viewModel.inspectInstallPreflight(
                        CoreLoaderInstallPreflightRequest(
                            version: version.id,
                            gameDir: targetGameDir,
                            loader: request.loader,
                            loaderVersion: request.loader == selectedLoader ? selectedMinecraftLoaderVersion : nil,
                            shaderLoader: request.shader,
                            shaderVersion: request.shader == selectedShader ? automaticMinecraftInstallShaderVersion() : nil,
                            instanceName: name
                        )
                    )
                    results[request.key] = result
                } catch {
                    continue
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                minecraftInstallChoicePreflights = results
            }
        }
    }

    func minecraftInstallGameDirectory(for version: MinecraftVersionInfo) -> String? {
        switch minecraftInstallTarget {
        case .newConfiguration:
            return manualGameConfigurationDirectory().map(\.path)
        case .existingConfiguration:
            return instanceStore.selectedInstance?.gameDirectory
        case .downloadOnly:
            return downloadOnlyDirectory(for: version).path
        }
    }

    func manualGameConfigurationDirectory() -> URL? {
        let trimmedName = minecraftInstanceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let root = gameConfigurationsRoot()
        return root.appendingPathComponent(slug(trimmedName), isDirectory: true)
    }

    func downloadOnlyDirectory(for version: MinecraftVersionInfo) -> URL {
        let base = (try? LauncherPaths.appSupportDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher", isDirectory: true)
        return base
            .appendingPathComponent("DownloadCache", isDirectory: true)
            .appendingPathComponent("MinecraftVersionFiles", isDirectory: true)
            .appendingPathComponent(slug(version.id), isDirectory: true)
    }

    func gameConfigurationsRoot() -> URL {
        (try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true)
    }

    func slug(_ value: String) -> String {
        var result = ""
        for scalar in value.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        return trimmed.isEmpty ? "minecraft" : trimmed
    }

    func minecraftInstallDisplayName(for _: MinecraftVersionInfo) -> String {
        minecraftInstanceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func automaticMinecraftInstallShaderLoader() -> String? {
        switch selectedShaderLoader {
        case .none, .optiFine:
            return nil
        case .iris, .oculus:
            return minecraftShaderLoaderForPreflight(loader: selectedMinecraftLoader?.rawValue, shaderLoader: selectedShaderLoader.rawValue)
        }
    }

    func automaticMinecraftInstallShaderVersion() -> String? {
        switch selectedShaderLoader {
        case .none, .optiFine:
            return nil
        case .iris, .oculus:
            return selectedShaderLoaderVersion
        }
    }
}
