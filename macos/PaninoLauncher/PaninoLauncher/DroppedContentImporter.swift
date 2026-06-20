import Foundation
import UniformTypeIdentifiers

enum DroppedContentImporter {
    @MainActor
    static func importItems(
        _ providers: [NSItemProvider],
        selectedKind: ManagedAssetKind,
        instance: GameInstance?,
        taskStore: TaskCenterStore,
        versionStore: VersionContentStore
    ) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard error == nil, let sourceURL = fileURL(from: item) else { return }
                Task { @MainActor in
                    importFile(
                        sourceURL,
                        selectedKind: selectedKind,
                        instance: instance,
                        taskStore: taskStore,
                        versionStore: versionStore
                    )
                }
            }
        }

        return true
    }

    @MainActor
    private static func importFile(
        _ sourceURL: URL,
        selectedKind: ManagedAssetKind,
        instance: GameInstance?,
        taskStore: TaskCenterStore,
        versionStore: VersionContentStore
    ) {
        let kind = importKind(for: sourceURL, selectedKind: selectedKind)
        guard instance?.gameDirectory.isEmpty == false else {
            taskStore.enqueueLocal(kind: "import", name: "Import Failed", message: "Select a game configuration before importing content.")
            return
        }

        taskStore.enqueueLocal(kind: "import", name: "Import \(sourceURL.lastPathComponent)", message: "Queued \(kind.title) import.")

        Task {
            do {
                let response = try await versionStore.importLocalFile(sourceURL, kind: kind, instance: instance)
                await MainActor.run {
                    taskStore.enqueueLocal(kind: "import", name: "Imported \(sourceURL.lastPathComponent)", message: response.path ?? response.message)
                }
            } catch {
                await MainActor.run {
                    taskStore.enqueueLocal(kind: "import", name: "Import Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }

    private static func importKind(for url: URL, selectedKind: ManagedAssetKind) -> ManagedAssetKind {
        if url.pathExtension.localizedCaseInsensitiveCompare("jar") == .orderedSame {
            return .mods
        }
        return selectedKind
    }
}
