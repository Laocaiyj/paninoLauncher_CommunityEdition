import SwiftUI

extension InstanceVersionConfigurationPage {
    var storageDialogPresented: Binding<Bool> {
        Binding(
            get: { pendingStorageAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingStorageAction = nil
                }
            }
        )
    }

    var usesGlobalRuntime: Binding<Bool> {
        Binding(
            get: { instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            set: { useGlobal in
                if useGlobal {
                    instance.javaPath = ""
                    instance.memoryMb = SettingsStore.memoryMb
                    instance.memoryPolicy = .auto
                    instance.jvmProfile = .auto
                } else {
                    instance.javaPath = "java"
                }
            }
        )
    }

    var compatibleLoaders: [LoaderKind] {
        guard let version else { return LoaderKind.allCases }
        return version.kind == .oldAlpha || version.kind == .oldBeta ? [] : LoaderKind.allCases
    }

    var canApplyVersion: Bool {
        guard let version else { return false }
        return version.id != instance.minecraftVersion && version.isInstalled
    }

    var versionChangeSummary: String {
        guard let version else { return "" }
        return localizedString(
            theme.language,
            english: "\(instance.name) will change from Minecraft \(instance.minecraftVersion) to Minecraft \(version.id). Loader and local content may need review.",
            chinese: "\(instance.name) 将从 Minecraft \(instance.minecraftVersion) 更改为 Minecraft \(version.id)。Loader 和本地内容可能需要重新检查。",
            italian: "\(instance.name) passerà da Minecraft \(instance.minecraftVersion) a Minecraft \(version.id).",
            french: "\(instance.name) passera de Minecraft \(instance.minecraftVersion) à Minecraft \(version.id).",
            spanish: "\(instance.name) cambiará de Minecraft \(instance.minecraftVersion) a Minecraft \(version.id)."
        )
    }

    var versionStateTitle: String {
        guard let version else {
            return localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando")
        }
        if version.isInstalled {
            return localizedString(theme.language, english: "Installed", chinese: "已安装", italian: "Installata", french: "Installée", spanish: "Instalada")
        }
        if version.isArchived {
            return localizedString(theme.language, english: "Archived", chinese: "已归档", italian: "Archiviata", french: "Archivée", spanish: "Archivada")
        }
        return localizedString(theme.language, english: "Needs Install", chinese: "需要安装", italian: "Da installare", french: "À installer", spanish: "Por instalar")
    }

    var versionBadgeStyle: StatusBadge.Style {
        guard let version else { return .running }
        if version.isArchived { return .neutral }
        return version.isInstalled ? .success : .warning
    }

    func restoreAutomaticTuning() {
        instance.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb)
    }

    func restoreLastKnownGoodTuning(_ snapshot: JvmTuningSnapshot) {
        instance.applyJvmTuningSnapshot(snapshot)
    }

    func applyInstanceRuntime() {
        viewModel.version = instance.minecraftVersion
        viewModel.memoryMb = usesGlobalRuntime.wrappedValue ? SettingsStore.memoryMb : instance.memoryMb
        viewModel.javaPath = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SettingsStore.javaPath : instance.javaPath
        if let loader = instance.loader {
            versionStore.selectedLoader = loader
        }
    }

    func repairFocusedVersion() {
        viewModel.version = version?.id ?? instance.minecraftVersion
        viewModel.memoryMb = usesGlobalRuntime.wrappedValue ? SettingsStore.memoryMb : instance.memoryMb
        viewModel.javaPath = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SettingsStore.javaPath : instance.javaPath
        viewModel.install(gameDir: instance.gameDirectory)
    }

    func applyVersionChange() {
        guard let version else { return }
        instance.minecraftVersion = version.id
        if !compatibleLoaders.contains(where: { Optional($0) == instance.loader }) {
            instance.loader = nil
        }
        applyInstanceRuntime()
        versionStore.refreshAssets(for: instance)
    }

    func canArchive(_ version: MinecraftVersionInfo) -> Bool {
        version.isInstalled && !version.isUsedByInstance
    }

    func canDelete(_ version: MinecraftVersionInfo) -> Bool {
        (version.isInstalled || version.isArchived) && !version.isUsedByInstance
    }

    func mutateVersionStorage(_ action: VersionStorageConfirmation) {
        guard let version else { return }
        versionStore.mutateVersionStorage(
            version,
            action: action.coreAction,
            instances: instanceStore.instances,
            settings: launcherSettings
        )
    }
}
