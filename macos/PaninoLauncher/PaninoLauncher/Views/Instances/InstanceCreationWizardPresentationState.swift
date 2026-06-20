import Foundation

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
}
