import SwiftUI

extension InstanceCreationWizard {
    var stepTitle: String {
        InstanceCreationWizardPresentation.stepTitle(language: theme.language, step: step)
    }

    var sourceHelpText: String {
        InstanceCreationWizardPresentation.sourceHelpText(language: theme.language, source: draft.source)
    }

    var generatedName: String {
        InstanceCreationWizardPresentation.generatedName(
            language: theme.language,
            draft: draft,
            modpackPreflight: modpackPreflight
        )
    }

    var shouldRegenerateName: Bool {
        InstanceCreationWizardPresentation.shouldRegenerateName(draft.name)
    }

    var versionPickerMatches: [MinecraftVersionInfo] {
        InstanceCreationWizardPresentation.versionPickerMatches(
            versions: versionStore.versions,
            latestReleaseID: versionStore.latestReleaseID,
            selectedVersionID: draft.minecraftVersion,
            searchText: versionSearchText
        )
    }

    var versionPickerVersions: [MinecraftVersionInfo] {
        Array(versionPickerMatches.prefix(versionPickerLimit))
    }

    var versionPickerTotalMatches: Int {
        versionPickerMatches.count
    }

    var availableLoaderOptions: [LoaderCompatibilityOption] {
        loaderOptions.filter(\.isAvailable)
    }

    var selectedLoaderOption: LoaderCompatibilityOption? {
        guard let loader = draft.loader else { return nil }
        return loaderOptions.first { $0.kind == loader }
    }

    var selectedLoaderVersions: [LoaderMetadata] {
        selectedLoaderOption?.versions ?? []
    }

    var nonRecommendedSelectedLoaderVersions: [LoaderMetadata] {
        selectedLoaderVersions.filter { $0.loaderVersion != selectedLoaderOption?.recommendedVersion }
    }

    var loaderStatusText: String {
        InstanceCreationWizardPresentation.loaderStatusText(
            language: theme.language,
            isLoadingLoaders: isLoadingLoaders,
            loaderStatus: loaderStatus,
            availableLoaderOptions: availableLoaderOptions
        )
    }

    var loaderReviewText: String {
        InstanceCreationWizardPresentation.loaderReviewText(draft: draft)
    }

    var installPlanSummary: String {
        InstanceCreationWizardPresentation.installPlanSummary(
            language: theme.language,
            draft: draft,
            loaderReviewText: loaderReviewText
        )
    }

    var primaryActionTitle: String {
        InstanceCreationWizardPresentation.primaryActionTitle(language: theme.language, draft: draft)
    }

    var primaryActionIcon: String {
        InstanceCreationWizardPresentation.primaryActionIcon(source: draft.source)
    }

    var canMoveNext: Bool {
        switch step {
        case .source:
            return !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .version:
            if draft.source == "Mod Configuration" {
                return draft.loader != nil && draft.loaderVersion != nil && !selectedLoaderVersions.isEmpty
            }
            if draft.source == "Import Modpack", draft.modpackSource == "Local File" {
                return modpackPreflight?.valid == true
            }
            return true
        case .review:
            return canComplete
        }
    }

    var canComplete: Bool {
        switch draft.source {
        case "Mod Configuration":
            return draft.loader != nil && draft.loaderVersion != nil
        case "Import Modpack":
            return draft.modpackSource == "Online" || modpackPreflight?.valid == true
        default:
            return true
        }
    }

    var modpackPreflightSummary: String {
        InstanceCreationWizardPresentation.modpackPreflightSummary(
            language: theme.language,
            isCheckingModpack: isCheckingModpack,
            status: modpackPreflightStatus,
            modpackPreflight: modpackPreflight
        )
    }

    func moveStep(_ delta: Int) {
        guard let index = InstanceCreationStep.allCases.firstIndex(of: step) else { return }
        let nextIndex = min(max(index + delta, 0), InstanceCreationStep.allCases.count - 1)
        step = InstanceCreationStep.allCases[nextIndex]
    }

    func performPrimaryAction() {
        if draft.source == "Import Modpack" {
            if draft.modpackSource == "Online" {
                openModpackImport()
                dismiss()
            } else {
                prepareModpackImportReview()
            }
        } else {
            create(draft)
            dismiss()
        }
    }

    func regenerateNameIfNeeded() {
        guard shouldRegenerateName else { return }
        draft.name = generatedName
        draft.gameDirectory = InstanceCreationDraft.defaultConfigurationDirectory(name: draft.name)
    }

    func normalizeDraftForPurpose() {
        if draft.source == "Mod Configuration" {
            if draft.loader == nil {
                draft.loader = .fabric
            }
        } else {
            draft.loader = nil
            draft.loaderVersion = nil
        }

        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.name == "New Game Configuration" {
            draft.name = generatedName
            draft.gameDirectory = InstanceCreationDraft.defaultConfigurationDirectory(name: draft.name)
        }
    }

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

    @MainActor
    func refreshLoaderOptions() async {
        guard draft.source == "Mod Configuration" else {
            loaderOptions = LoaderKind.allCases.map {
                LoaderCompatibilityOption(kind: $0, recommendedVersion: nil, versions: [], isAvailable: false, reason: nil)
            }
            loaderStatus = "Loader metadata not needed for this configuration."
            return
        }
        isLoadingLoaders = true
        do {
            let response = try await loadLoaderCompatibility(draft.minecraftVersion)
            loaderOptions = LoaderCompatibilityOption.options(from: response)
            let available = loaderOptions.filter(\.isAvailable)
            if let current = draft.loader, !available.contains(where: { $0.kind == current }) {
                draft.loader = available.first?.kind
            } else if draft.loader == nil {
                draft.loader = available.first(where: { $0.kind == .fabric })?.kind ?? available.first?.kind
            }
            if let option = selectedLoaderOption {
                draft.loaderVersion = option.recommendedVersion
            }
            loaderStatus = available.isEmpty
                ? "Core did not report any compatible Loader for \(draft.minecraftVersion)."
                : "Loaded \(available.count) compatible loader families from Core."
        } catch {
            loaderOptions = []
            draft.loader = nil
            draft.loaderVersion = nil
            loaderStatus = "Core loader compatibility failed: \(error.localizedDescription)"
        }
        isLoadingLoaders = false
    }
}
