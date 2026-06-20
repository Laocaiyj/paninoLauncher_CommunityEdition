import Foundation

extension InstanceCreationWizard {
    func runModpackPreflight() {
        let sourcePath = draft.modpackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourcePath.isEmpty else { return }
        isCheckingModpack = true
        modpackPreflightStatus = ""
        Task {
            do {
                let result = try await preflightModpack("local", sourcePath, draft.gameDirectory)
                await MainActor.run {
                    modpackPreflight = result
                    if result.valid {
                        if let name = result.name, shouldRegenerateName {
                            draft.name = name
                        }
                        if let version = result.minecraftVersion {
                            draft.minecraftVersion = version
                        }
                        draft.loader = result.loader.flatMap(LoaderKind.init(rawValue:))
                        draft.loaderVersion = result.loaderVersion
                        draft.gameDirectory = InstanceCreationDraft.defaultConfigurationDirectory(name: draft.name)
                    }
                    modpackPreflightStatus = result.valid ? "" : result.blockingReasons.joined(separator: ", ")
                    isCheckingModpack = false
                }
            } catch {
                await MainActor.run {
                    modpackPreflight = nil
                    modpackPreflightStatus = "Core modpack preflight failed: \(error.localizedDescription)"
                    isCheckingModpack = false
                }
            }
        }
    }

    @MainActor
    func prepareModpackImportReview() {
        let sourcePath = draft.modpackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let modpackPreflight, !sourcePath.isEmpty else { return }
        pendingModpackImportReview =
            PendingModpackImportReview(
                plan: modpackPreflight.typedPlan,
                sourcePath: sourcePath,
                targetGameDir: draft.gameDirectory
            )
    }

    @MainActor
    func confirmModpackImport(_ review: PendingModpackImportReview) {
        pendingModpackImportReview = nil
        isCheckingModpack = true
        modpackPreflightStatus = localizedString(theme.language, english: "Core is importing the modpack...", chinese: "Core 正在导入整合包...", italian: "Core importa il modpack...", french: "Core importe le modpack...", spanish: "Core importa el modpack...")
        Task {
            do {
                let response = try await importModpack("local", review.sourcePath, review.targetGameDir)
                await MainActor.run {
                    isCheckingModpack = false
                    if response.imported {
                        modpackPreflightStatus = localizedString(
                            theme.language,
                            english: "Imported. Rollback record: \(response.lockfilePath)",
                            chinese: "已导入。回滚记录：\(response.lockfilePath)",
                            italian: "Importato. Registro rollback: \(response.lockfilePath)",
                            french: "Importé. Journal de restauration : \(response.lockfilePath)",
                            spanish: "Importado. Registro de reversión: \(response.lockfilePath)"
                        )
                        create(draft)
                        dismiss()
                    } else {
                        modpackPreflight = CoreModpackPreflightResponse(
                            valid: false,
                            name: modpackPreflight?.name,
                            minecraftVersion: modpackPreflight?.minecraftVersion,
                            loader: modpackPreflight?.loader,
                            loaderVersion: modpackPreflight?.loaderVersion,
                            modCount: modpackPreflight?.modCount ?? 0,
                            resourcePackCount: modpackPreflight?.resourcePackCount ?? 0,
                            shaderPackCount: modpackPreflight?.shaderPackCount ?? 0,
                            overridesCount: modpackPreflight?.overridesCount ?? 0,
                            estimatedDownloadBytes: modpackPreflight?.estimatedDownloadBytes,
                            requiresApiKey: modpackPreflight?.requiresApiKey ?? false,
                            warnings: response.warnings,
                            blockingReasons: response.blockingReasons,
                            typedPlan: response.typedPlan
                        )
                        modpackPreflightStatus = response.blockingReasons.joined(separator: ", ")
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingModpack = false
                    modpackPreflightStatus = "Core modpack import failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
