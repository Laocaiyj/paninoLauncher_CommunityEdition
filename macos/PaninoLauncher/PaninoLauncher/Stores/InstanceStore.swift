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
        let reconciliation = InstanceStoreInstalledInstanceReconciler.reconcile(
            installedInstances,
            currentInstances: instances,
            settings: settings
        )
        if reconciliation.instances != instances {
            instances = reconciliation.instances
        }
        if selectedInstanceID == nil || !instances.contains(where: { $0.id == selectedInstanceID }) {
            selectedInstanceID = instances.first?.id
        }
        storageStatus = reconciliation.legacySharedCount > 0
            ? "Synced \(instances.count) local game instances; \(reconciliation.legacySharedCount) legacy installs require isolation"
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
