import SwiftUI

struct InstanceCreationWizard: View {
    @Binding var draft: InstanceCreationDraft
    let create: (InstanceCreationDraft) -> Void
    let openModpackImport: () -> Void
    let loadLoaderCompatibility: (String) async throws -> CoreLoaderCompatibilityResponse
    let preflightModpack: (String, String?, String?) async throws -> CoreModpackPreflightResponse
    let importModpack: (String, String, String) async throws -> CoreModpackImportResponse

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var versionStore: VersionContentStore
    @State var step: InstanceCreationStep = .source
    @State var showAdvancedOptions = false
    @State var loaderOptions: [LoaderCompatibilityOption] = LoaderKind.allCases.map {
        LoaderCompatibilityOption(kind: $0, recommendedVersion: nil, versions: [], isAvailable: false, reason: nil)
    }
    @State var loaderStatus = "Loader metadata not loaded"
    @State var isLoadingLoaders = false
    @State var modpackPreflight: CoreModpackPreflightResponse?
    @State var modpackPreflightStatus = ""
    @State var isCheckingModpack = false
    @State var pendingModpackImportReview: PendingModpackImportReview?
    @State var versionSearchText = ""
    @State var showingVersionPicker = false
    let versionPickerLimit = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InstanceCreationWizardHeader(stepTitle: stepTitle)

            InstanceWizardStepper(step: step)

            Group {
                switch step {
                case .source:
                    InstanceCreationSourceStep(draft: $draft, sourceHelpText: sourceHelpText)
                case .version:
                    InstanceCreationVersionStep(
                        draft: $draft,
                        versionPickerVersions: versionPickerVersions,
                        versionPickerTotalMatches: versionPickerTotalMatches,
                        versionPickerLimit: versionPickerLimit,
                        versionSearchText: $versionSearchText,
                        showingVersionPicker: $showingVersionPicker,
                        availableLoaderOptions: availableLoaderOptions,
                        selectedLoaderOption: selectedLoaderOption,
                        selectedLoaderVersions: selectedLoaderVersions,
                        nonRecommendedSelectedLoaderVersions: nonRecommendedSelectedLoaderVersions,
                        loaderStatusText: loaderStatusText,
                        modpackPreflight: modpackPreflight,
                        modpackPreflightSummary: modpackPreflightSummary,
                        isCheckingModpack: isCheckingModpack,
                        runModpackPreflight: runModpackPreflight
                    )
                case .review:
                    InstanceCreationReviewStep(
                        draft: $draft,
                        showAdvancedOptions: $showAdvancedOptions,
                        loaderReviewText: loaderReviewText,
                        installPlanSummary: installPlanSummary
                    )
                }
            }
            .frame(minHeight: 250, alignment: .topLeading)

            InstanceCreationWizardFooter(
                step: step,
                primaryActionIcon: primaryActionIcon,
                primaryActionTitle: primaryActionTitle,
                canMoveNext: canMoveNext,
                canComplete: canComplete,
                onCancel: { dismiss() },
                onBack: { moveStep(-1) },
                onNext: { moveStep(1) },
                onComplete: performPrimaryAction
            )
        }
        .padding(22)
        .frame(width: 720)
        .onAppear(perform: normalizeDraftForPurpose)
        .onChange(of: draft.source) {
            normalizeDraftForPurpose()
        }
        .onChange(of: draft.modpackPath) {
            modpackPreflight = nil
            modpackPreflightStatus = ""
        }
        .onChange(of: draft.minecraftVersion) {
            regenerateNameIfNeeded()
            Task { await refreshLoaderOptions() }
        }
        .onChange(of: draft.loader) {
            draft.loaderVersion = selectedLoaderOption?.recommendedVersion
            regenerateNameIfNeeded()
        }
        .task(id: "\(draft.source)-\(draft.minecraftVersion)") {
            await refreshLoaderOptions()
        }
        .sheet(item: $pendingModpackImportReview) { review in
            InstanceModpackImportReviewSheet(
                review: review,
                draftName: draft.name,
                onCancel: { pendingModpackImportReview = nil },
                onRepair: {
                    pendingModpackImportReview = nil
                    runModpackPreflight()
                },
                onConfirm: { confirmModpackImport(review) }
            )
        }
    }

}
