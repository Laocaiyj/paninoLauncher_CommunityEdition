import Foundation

struct InstanceStoreInstalledInstanceReconciliation {
    let instances: [GameInstance]
    let legacySharedCount: Int
}

@MainActor
enum InstanceStoreInstalledInstanceReconciler {
    static func reconcile(
        _ installedInstances: [CoreInstalledMinecraftInstance],
        currentInstances: [GameInstance],
        settings: LauncherSettings
    ) -> InstanceStoreInstalledInstanceReconciliation {
        let localCandidates = isolatedLocalInstances(installedInstances) + legacyMigratableInstances(installedInstances)
        let installedKeys = Set(localCandidates.map { InstanceLocalCatalog.key(version: $0.versionId, gameDirectory: $0.gameDir) })
        var next = currentInstances.filter { instance in
            installedKeys.contains(InstanceLocalCatalog.key(version: instance.minecraftVersion, gameDirectory: InstanceLocalCatalog.effectiveGameDirectory(for: instance)))
        }

        for installed in localCandidates {
            merge(installed, into: &next, settings: settings)
        }

        return InstanceStoreInstalledInstanceReconciliation(
            instances: InstanceLocalCatalog.normalizeDuplicateNames(next).sorted(by: InstanceLocalCatalog.sort),
            legacySharedCount: legacySharedCount(installedInstances)
        )
    }

    private static func isolatedLocalInstances(_ installedInstances: [CoreInstalledMinecraftInstance]) -> [CoreInstalledMinecraftInstance] {
        installedInstances.filter { !$0.archived && InstanceLocalCatalog.isIsolatedGameDirectory($0.gameDir) }
    }

    private static func legacyMigratableInstances(_ installedInstances: [CoreInstalledMinecraftInstance]) -> [CoreInstalledMinecraftInstance] {
        installedInstances.compactMap { installed -> CoreInstalledMinecraftInstance? in
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
    }

    private static func merge(
        _ installed: CoreInstalledMinecraftInstance,
        into instances: inout [GameInstance],
        settings: LauncherSettings
    ) {
        let key = InstanceLocalCatalog.key(version: installed.versionId, gameDirectory: installed.gameDir)
        if let index = instances.firstIndex(where: { InstanceLocalCatalog.key(version: $0.minecraftVersion, gameDirectory: InstanceLocalCatalog.effectiveGameDirectory(for: $0)) == key }) {
            update(&instances[index], from: installed)
            return
        }
        instances.append(InstanceLocalCatalog.gameInstance(from: installed, settings: settings, existingNames: Set(instances.map(\.name))))
    }

    private static func update(_ instance: inout GameInstance, from installed: CoreInstalledMinecraftInstance) {
        if let loader = installed.loader.flatMap(LoaderKind.init(rawValue:)) {
            instance.loader = loader
        }
        if let loaderVersion = installed.loaderVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !loaderVersion.isEmpty {
            instance.loaderVersion = loaderVersion
        }
        if let minecraftVersion = installed.minecraftVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !minecraftVersion.isEmpty {
            instance.baseMinecraftVersion = minecraftVersion
        }
        instance.status = installed.versionJson && installed.clientJar ? .ready : .notInstalled
    }

    private static func legacySharedCount(_ installedInstances: [CoreInstalledMinecraftInstance]) -> Int {
        installedInstances
            .filter { $0.versionJson && $0.clientJar && !$0.archived && !InstanceLocalCatalog.isIsolatedGameDirectory($0.gameDir) }
            .count
    }
}
