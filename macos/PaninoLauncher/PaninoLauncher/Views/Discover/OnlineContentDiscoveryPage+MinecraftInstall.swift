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
}
