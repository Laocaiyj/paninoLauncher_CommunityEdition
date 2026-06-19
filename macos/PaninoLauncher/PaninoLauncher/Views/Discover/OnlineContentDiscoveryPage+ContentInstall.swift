import AppKit
import Foundation

extension OnlineContentDiscoveryPage {
    func switchSource() {
        selectedSource = selectedSource == .modrinth ? .curseForge : .modrinth
    }

    func syncManagedKind() {
        guard let kind = selectedType.managedAssetKind else { return }
        versionStore.selectedAssetKind = kind
        versionStore.refreshAssets(for: instanceStore.selectedInstance)
    }

    func recommendedReleaseID() -> String? {
        guard let selectedContentMinecraftVersionID else { return nil }
        return onlineContentStore.selectedReleases.first { $0.gameVersions.contains(selectedContentMinecraftVersionID) }?.id
    }

    func resolveTargetsForSelection() {
        targetResolutionTask?.cancel()
        targetResolution = nil
        targetResolutionFailure = nil
        selectedContentTargetID = nil

        guard let selectedProject,
              let selectedRelease,
              let managedKind = selectedProject.projectType.managedAssetKind else { return }

        let request = CoreContentResolveTargetsRequest(
            projectType: selectedProject.projectType.rawValue,
            projectTitle: selectedProject.title,
            releaseId: selectedRelease.id,
            targetSubdir: managedKind.folderName,
            gameVersions: selectedRelease.gameVersions,
            loaders: selectedRelease.loaders.map(\.rawValue),
            instances: instanceStore.instances
                .filter { !$0.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { instance in
                    CoreContentTargetInstance(
                        instanceId: instance.id.uuidString,
                        name: instance.name,
                        gameDir: instance.gameDirectory,
                        minecraftVersion: instance.contentMinecraftVersion,
                        loader: instance.loader?.rawValue
                    )
                }
        )

        targetResolutionTask = Task {
            do {
                let response = try await viewModel.resolveContentTargets(request)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    targetResolution = response
                    targetResolutionFailure = nil
                    selectedContentTargetID = preferredContentTargetID(in: response, release: selectedRelease)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    targetResolution = nil
                    targetResolutionFailure = error.localizedDescription
                    selectedContentTargetID = nil
                }
            }
        }
    }

    func installSelectedRelease(target selectedTarget: CoreContentTargetCandidate? = nil) {
        guard let selectedProject,
              let selectedRelease,
              let managedKind = selectedProject.projectType.managedAssetKind else { return }
        let resolvedTarget = selectedTarget ?? selectedContentTarget(release: selectedRelease)

        if let resolvedTarget,
           let request = coreInstallRequest(
            project: selectedProject,
            release: selectedRelease,
            managedKind: managedKind,
            gameDirectory: resolvedTarget.gameDir
           ) {
            presentContentInstallReview(request: request, release: selectedRelease, managedKind: managedKind)
            return
        }

        let panel = NSOpenPanel()
        panel.title = localizedString(theme.language, english: "Choose target game instance folder", chinese: "确认安装到哪个游戏实例文件夹", italian: "Scegli la cartella dell'istanza", french: "Choisir le dossier de l'instance", spanish: "Elige la carpeta de la instancia")
        panel.message = resolvedTarget == nil
            ? localizedString(theme.language, english: "Choose an isolated game instance folder compatible with the selected Minecraft version.", chinese: "请选择一个与当前 Minecraft 版本兼容的独立游戏实例文件夹。", italian: "Scegli una cartella istanza compatibile con la versione Minecraft selezionata.", french: "Choisissez un dossier d'instance compatible avec la version Minecraft choisie.", spanish: "Elige una carpeta de instancia compatible con la versión de Minecraft seleccionada.")
            : localizedString(theme.language, english: "Panino matched a local instance. Confirm it here, or choose another isolated instance folder.", chinese: "Panino 已匹配本地实例。请在这里确认，或选择另一个独立实例文件夹。", italian: "Panino ha trovato un'istanza locale. Confermala o scegline un'altra.", french: "Panino a trouvé une instance locale. Confirmez-la ou choisissez-en une autre.", spanish: "Panino encontró una instancia local. Confírmala o elige otra.")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if let resolvedTarget {
            panel.directoryURL = URL(fileURLWithPath: resolvedTarget.gameDir, isDirectory: true)
        } else if let selected = instanceStore.selectedInstance {
            panel.directoryURL = URL(fileURLWithPath: selected.gameDirectory, isDirectory: true)
        }

        guard panel.runModal() == .OK,
              let targetURL = panel.url,
              let request = coreInstallRequest(
                project: selectedProject,
                release: selectedRelease,
                managedKind: managedKind,
                gameDirectory: targetURL.path
              ) else { return }

        presentContentInstallReview(request: request, release: selectedRelease, managedKind: managedKind)
    }

    func presentContentInstallReview(request: CoreContentInstallRequest, release: OnlineRelease, managedKind: ManagedAssetKind) {
        Task {
            do {
                let plan = try await viewModel.contentInstallPlan(request)
                await MainActor.run {
                    pendingContentInstallReview =
                        PendingContentInstallReview(
                            plan: plan,
                            releaseVersionName: release.versionName,
                            request: request,
                            managedKind: managedKind
                        )
                }
            } catch {
                await MainActor.run {
                    targetResolutionFailure = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    func beginReviewedContentInstall(_ review: PendingContentInstallReview) {
        pendingContentInstallReview = nil
        versionStore.selectedAssetKind = review.managedKind
        if let targetInstance = instanceStore.instances.first(where: { sameFilePath($0.gameDirectory, review.request.gameDir) }) {
            instanceStore.selectedInstanceID = targetInstance.id
        }
        Task {
            do {
                _ = try await viewModel.installContentAccepted(review.request)
                await MainActor.run {
                    targetResolutionFailure = nil
                }
            } catch {
                await MainActor.run {
                    targetResolutionFailure = error.localizedDescription
                }
            }
        }
    }

    func contentReviewRepairTitle(for plan: CoreTypedInstallPlan) -> String? {
        guard plan.status == "blocked" || !plan.blockedReasons.isEmpty else { return nil }
        if plan.blockedReasons.contains(where: { $0.localizedCaseInsensitiveContains("curseforge") || $0.localizedCaseInsensitiveContains("api_key") }) {
            return localizedString(theme.language, english: "Open Settings", chinese: "打开设置", italian: "Apri impostazioni", french: "Ouvrir les réglages", spanish: "Abrir ajustes")
        }
        return localizedString(theme.language, english: "Choose Target", chinese: "重新选择目标", italian: "Scegli destinazione", french: "Choisir la cible", spanish: "Elegir destino")
    }

    @MainActor
    func repairContentInstallReview(_ review: PendingContentInstallReview) {
        pendingContentInstallReview = nil
        if review.plan.typedPlan.blockedReasons.contains(where: { $0.localizedCaseInsensitiveContains("curseforge") || $0.localizedCaseInsensitiveContains("api_key") }) {
            openSettings()
        } else {
            installSelectedRelease()
        }
    }

    func isContentTargetVersionMatched(_ target: CoreContentTargetCandidate, release: OnlineRelease) -> Bool {
        let hasVersionMismatch = target.blockedReasons.contains { reason in
            reason.localizedCaseInsensitiveContains("minecraft_version_mismatch")
        }
        guard !hasVersionMismatch else { return false }
        return release.gameVersions.isEmpty || release.gameVersions.contains(target.minecraftVersion)
    }

    func selectedContentTarget(release: OnlineRelease) -> CoreContentTargetCandidate? {
        guard let selectedContentTargetID else { return nil }
        return targetResolution?.candidates.first {
            $0.id == selectedContentTargetID && isContentTargetVersionMatched($0, release: release)
        }
    }

    func preferredContentTargetID(in response: CoreContentResolveTargetsResponse, release: OnlineRelease) -> String? {
        if let selectedContentTargetID,
           response.candidates.contains(where: { $0.id == selectedContentTargetID && isContentTargetVersionMatched($0, release: release) }) {
            return selectedContentTargetID
        }
        if let recommended = response.recommended,
           isContentTargetVersionMatched(recommended, release: release) {
            return recommended.id
        }
        return response.candidates.first { isContentTargetVersionMatched($0, release: release) }?.id
    }

    func coreInstallRequest(
        project: OnlineProject,
        release: OnlineRelease,
        managedKind: ManagedAssetKind,
        gameDirectory: String
    ) -> CoreContentInstallRequest? {
        guard let sourceFile = release.files.first(where: \.isPrimary) ?? release.files.first,
              let sourceURL = sourceFile.downloadURL,
              !gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let hashes = Dictionary(uniqueKeysWithValues: sourceFile.hashes.map { ($0.key.lowercased(), $0.value) })
        let file = CoreContentInstallFile(
            fileName: safeFileName(sourceFile.fileName),
            url: sourceURL,
            sha1: hashes["sha1"],
            size: sourceFile.sizeBytes,
            primary: sourceFile.isPrimary
        )
        let dependencies = release.dependencies.map { dependency in
            CoreContentInstallDependency(
                projectId: dependency.projectID,
                versionId: dependency.versionID,
                source: dependency.source.rawValue,
                name: dependency.projectID ?? dependency.versionID ?? dependency.id,
                required: dependency.relation == .required,
                installed: nil,
                sha1: nil
            )
        }

        return CoreContentInstallRequest(
            source: project.source.rawValue,
            projectId: project.id,
            projectTitle: project.title,
            projectType: project.projectType.rawValue,
            releaseId: release.id,
            gameDir: gameDirectory,
            targetSubdir: managedKind.folderName,
            files: [file],
            dependencies: dependencies,
            gameVersions: release.gameVersions,
            loaders: release.loaders.map(\.rawValue),
            instances: instanceStore.instances
                .filter { !$0.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { instance in
                    CoreContentTargetInstance(
                        instanceId: instance.id.uuidString,
                        name: instance.name,
                        gameDir: instance.gameDirectory,
                        minecraftVersion: instance.contentMinecraftVersion,
                        loader: instance.loader?.rawValue
                    )
                },
            concurrency: launcherSettings.downloadConcurrency,
            retryCount: launcherSettings.downloadRetryCount,
            download: CoreDownloadRuntimeOptions(
                concurrency: launcherSettings.downloadConcurrency,
                retryCount: launcherSettings.downloadRetryCount
            )
        )
    }

    func sameFilePath(_ lhs: String, _ rhs: String) -> Bool {
        URL(fileURLWithPath: lhs).standardizedFileURL.path == URL(fileURLWithPath: rhs).standardizedFileURL.path
    }
}
