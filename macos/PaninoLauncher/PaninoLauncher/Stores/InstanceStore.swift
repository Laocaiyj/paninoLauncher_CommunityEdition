import Foundation
import SwiftUI

@MainActor
final class InstanceStore: ObservableObject {
    @Published var instances: [GameInstance] = [] {
        didSet { save() }
    }

    @Published var selectedInstanceID: UUID? {
        didSet { SettingsStore.set(selectedInstanceID?.uuidString ?? "", forKey: "Instances.SelectedID") }
    }

    @Published private(set) var storageStatus = "Local game instances not loaded"
    var activeLaunchInstanceID: UUID?

    init() {
        load()
    }

    var selectedInstance: GameInstance? {
        instances.first { $0.id == selectedInstanceID } ?? instances.first
    }

    var selectedInstanceBinding: Binding<GameInstance>? {
        guard let selectedID = selectedInstance?.id else {
            return nil
        }
        return Binding(
            get: {
                self.instances.first { $0.id == selectedID }
                    ?? self.selectedInstance
                    ?? Self.placeholderInstance
            },
            set: { newValue in
                if let index = self.instances.firstIndex(where: { $0.id == selectedID }) {
                    self.instances[index] = newValue
                }
            }
        )
    }

    func createInstance(settings: LauncherSettings) {
        storageStatus = "Direct game configuration creation is disabled. Install Minecraft from Get; local instances appear after files are installed."
    }

    func insertConfiguredInstance(_ instance: GameInstance) {
        instances.insert(instance, at: 0)
        selectedInstanceID = instance.id
    }

    func duplicateSelected() {
        storageStatus = "Duplicate configurations are disabled. Install another local instance from Get and rename it after installation."
    }

    func deleteSelected() {
        guard let selectedID = selectedInstance?.id else { return }
        instances.removeAll { $0.id == selectedID }
        selectedInstanceID = instances.first?.id
    }

    func remove(_ instance: GameInstance) {
        instances.removeAll { $0.id == instance.id }
        if selectedInstanceID == instance.id {
            selectedInstanceID = instances.first?.id
        }
    }

    func setFavorite(_ instanceID: UUID, isFavorite: Bool) {
        guard let index = instances.firstIndex(where: { $0.id == instanceID }) else { return }
        instances[index].isFavorite = isFavorite
    }

    func setHiddenFromRecent(_ instanceID: UUID, hidden: Bool) {
        guard let index = instances.firstIndex(where: { $0.id == instanceID }) else { return }
        instances[index].isHiddenFromRecent = hidden
    }

    private func load() {
        do {
            let fileURL = try instancesURL()
            let selectedID = SettingsStore.string(forKey: "Instances.SelectedID", default: "")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                instances = try JSONDecoder.panino
                    .decode([GameInstance].self, from: data)
                    .filter(InstanceLocalCatalog.isConcreteLocalInstance)
            }
            selectedInstanceID = UUID(uuidString: selectedID) ?? instances.first?.id
            storageStatus = "Local game instances loaded from \(fileURL.path)"
        } catch {
            instances = []
            selectedInstanceID = instances.first?.id
            storageStatus = "Local game instance load failed: \(error.localizedDescription)"
        }
    }

    func reconcileInstalledInstances(_ installedInstances: [CoreInstalledMinecraftInstance], settings: LauncherSettings) {
        let isolatedLocal = installedInstances.filter { !$0.archived && InstanceLocalCatalog.isIsolatedGameDirectory($0.gameDir) }
        let legacyMigratable = installedInstances.compactMap { installed -> CoreInstalledMinecraftInstance? in
            guard installed.versionJson,
                  installed.clientJar,
                  !installed.archived,
                  !InstanceLocalCatalog.isIsolatedGameDirectory(installed.gameDir),
                  let isolatedDirectory = InstanceLocalCatalog.isolatedGameDirectory(forVersion: installed.versionId)
            else {
                return nil
            }
            return CoreInstalledMinecraftInstance(
                versionId: installed.versionId,
                minecraftVersion: installed.minecraftVersion,
                loader: installed.loader,
                loaderVersion: installed.loaderVersion,
                name: installed.name,
                gameDir: isolatedDirectory,
                versionJson: false,
                clientJar: false,
                diskUsageBytes: installed.diskUsageBytes,
                archived: false,
                archivePath: nil
            )
        }
        let localCandidates = isolatedLocal + legacyMigratable
        let legacySharedCount = installedInstances.filter { $0.versionJson && $0.clientJar && !$0.archived && !InstanceLocalCatalog.isIsolatedGameDirectory($0.gameDir) }.count
        let installedKeys = Set(localCandidates.map { InstanceLocalCatalog.key(version: $0.versionId, gameDirectory: $0.gameDir) })
        var next = instances.filter { instance in
            installedKeys.contains(InstanceLocalCatalog.key(version: instance.minecraftVersion, gameDirectory: InstanceLocalCatalog.effectiveGameDirectory(for: instance)))
        }

        for installed in localCandidates {
            let key = InstanceLocalCatalog.key(version: installed.versionId, gameDirectory: installed.gameDir)
            if let index = next.firstIndex(where: { InstanceLocalCatalog.key(version: $0.minecraftVersion, gameDirectory: InstanceLocalCatalog.effectiveGameDirectory(for: $0)) == key }) {
                if let loader = installed.loader.flatMap(LoaderKind.init(rawValue:)) {
                    next[index].loader = loader
                }
                if let loaderVersion = installed.loaderVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !loaderVersion.isEmpty {
                    next[index].loaderVersion = loaderVersion
                }
                if let minecraftVersion = installed.minecraftVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !minecraftVersion.isEmpty {
                    next[index].baseMinecraftVersion = minecraftVersion
                }
                next[index].status = installed.versionJson && installed.clientJar ? .ready : .notInstalled
                continue
            }
            next.append(InstanceLocalCatalog.gameInstance(from: installed, settings: settings, existingNames: Set(next.map(\.name))))
        }

        next = InstanceLocalCatalog.normalizeDuplicateNames(next)
        if next != instances {
            instances = next.sorted(by: InstanceLocalCatalog.sort)
        }
        if selectedInstanceID == nil || !instances.contains(where: { $0.id == selectedInstanceID }) {
            selectedInstanceID = instances.first?.id
        }
        storageStatus = legacySharedCount > 0
            ? "Synced \(instances.count) local game instances; \(legacySharedCount) legacy installs require isolation"
            : "Synced \(instances.count) isolated local game instances"
    }

    private func save() {
        do {
            let fileURL = try instancesURL()
            let data = try JSONEncoder.panino.encode(instances)
            try data.write(to: fileURL, options: .atomic)
            storageStatus = "Local game instances saved at \(fileURL.path)"
        } catch {
            storageStatus = "Local game instance save failed: \(error.localizedDescription)"
        }
    }

    private func instancesURL() throws -> URL {
        let directory = try LauncherPaths.appSupportDirectory()
        return directory.appendingPathComponent("instances.json")
    }

    private static var placeholderInstance: GameInstance {
        GameInstance(
            id: UUID(),
            name: "No Installed Instance",
            iconName: "shippingbox.fill",
            coverPath: "",
            minecraftVersion: "",
            gameDirectory: "",
            javaPath: "",
            memoryMb: SettingsStore.memoryMb,
            loader: nil,
            loaderVersion: nil,
            jvmArguments: "",
            preLaunchBehavior: "Install missing files",
            group: "Default",
            isFavorite: false,
            lastLaunchedAt: nil,
            totalPlaySeconds: nil,
            status: .failed
        )
    }
}
