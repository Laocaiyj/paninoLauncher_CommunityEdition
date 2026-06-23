import SwiftUI

struct MinecraftVersionInstallDetailPage: View {
    let version: MinecraftVersionInfo
    let instances: [GameInstance]
    @Binding var target: MinecraftInstallTarget
    @Binding var instanceName: String
    @Binding var loader: LoaderKind?
    @Binding var loaderVersion: String?
    @Binding var shaderLoader: ShaderLoaderChoice
    @Binding var shaderLoaderVersion: String?
    let loaderOptions: [LoaderCompatibilityOption]
    let shaderReleases: [OnlineRelease]
    let versionOptionsStatus: String
    @Binding var confirmInstall: Bool
    let preflight: CoreLoaderInstallPreflightResponse?
    let preflightStatus: String
    let choicePreflights: [String: CoreLoaderInstallPreflightResponse]
    let lastInstallFailure: TaskSnapshot?
    let back: () -> Void
    let install: () -> Void
    let openTasks: () -> Void
    let exportDiagnostics: () -> Void
    let openInstanceDirectory: () -> Void
    let downloadJava: (Int) -> Void

    @EnvironmentObject var theme: ThemeSettings
    @State private var showingInstallPlanReview = false
    private let versionMenuLimit = 80

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            MinecraftInstallHeaderPanel(version: version, onBack: back)

            MinecraftInstallLoaderPanel(
                loader: $loader,
                loaderVersion: $loaderVersion,
                compatibleLoaders: compatibleLoaders,
                loaderOptions: loaderOptions,
                versionOptionsStatus: versionOptionsStatus,
                versionMenuLimit: versionMenuLimit,
                choiceState: loaderChoiceState,
                onSelectLoader: selectLoader,
                notice: loaderInstallNotice
            )

            MinecraftInstallShaderPanel(
                shaderLoader: $shaderLoader,
                shaderLoaderVersion: $shaderLoaderVersion,
                shaderReleases: shaderReleases,
                versionOptionsStatus: versionOptionsStatus,
                versionMenuLimit: versionMenuLimit,
                choiceState: shaderChoiceState,
                isChoiceDisabled: shaderChoiceDisabled,
                helpText: shaderHelpText
            )

            MinecraftInstallInstancePanel(
                instanceName: $instanceName,
                targetDirectoryLabel: targetDirectoryLabel
            )

            MinecraftInstallPlanPanel(
                targetSummary: targetSummary,
                effectiveComponentSummary: effectiveComponentSummary,
                javaRuntimePlanSummary: javaRuntimePlanSummary,
                preflight: preflight,
                preflightStatus: preflightStatus,
                shaderFallbackSummary: shaderFallbackSummary,
                installerProbeSummary: installerProbeSummary,
                blockReason: blockReason,
                lastInstallFailure: lastInstallFailure,
                installButtonTitle: installButtonTitle,
                reviewPlan: { showingInstallPlanReview = true },
                confirmInstall: { confirmInstall = true },
                retryInstall: install,
                openTasks: openTasks,
                exportDiagnostics: exportDiagnostics,
                openInstanceDirectory: openInstanceDirectory,
                downloadJava: downloadJava
            )
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Confirm install?", chinese: "确认安装？", italian: "Confermare installazione?", french: "Confirmer l'installation ?", spanish: "¿Confirmar instalación?"),
            isPresented: $confirmInstall,
            titleVisibility: .visible
        ) {
            Button(installButtonTitle) {
                install()
            }
            .disabled(blockReason != nil)
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        } message: {
            Text("\(version.id) · \(effectiveComponentSummary) · \(targetSummary)")
        }
        .sheet(isPresented: $showingInstallPlanReview) {
            if let preflight {
                InstallPlanReviewSheet(
                    plan: preflight.typedPlan,
                    title: localizedString(theme.language, english: "Review install plan", chinese: "确认安装计划", italian: "Controlla piano installazione", french: "Vérifier le plan", spanish: "Revisar instalación"),
                    subtitle: "\(version.id) · \(effectiveComponentSummary)",
                    confirmTitle: installButtonTitle,
                    onCancel: { showingInstallPlanReview = false },
                    onConfirm: {
                        showingInstallPlanReview = false
                        confirmInstall = true
                    }
                )
                .environmentObject(theme)
            }
        }
    }
}
