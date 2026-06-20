import SwiftUI

struct InstanceEditor: View {
    @EnvironmentObject var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let openResources: () -> Void
    let openDiscover: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State var showAdvancedSettings = false
    @State var graphicsTuningStatus = ""
    @State var graphicsTuningRunning = false
    @State var graphicsCanRollback = false
    @State var resolvedGraphicsTuning: CoreResolvedGraphicsTuning?

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                InstanceEditorHeader(openFolder: openInstanceFolder, delete: onDelete)

                InstanceEditorBasicsSection(instance: $instance)

                InstanceVersionLoaderSelector(viewModel: viewModel, instance: $instance)

                InstanceVersionWorkspace(
                    viewModel: viewModel,
                    instance: $instance,
                    openResources: openResources,
                    openDiscover: openDiscover
                )

                InstanceEditorPerformanceSection(
                    instance: $instance,
                    restoreAutomaticTuning: restoreAutomaticTuning,
                    restoreLastKnownGoodTuning: restoreLastKnownGoodTuning
                )

                InstanceEditorGraphicsSection(
                    instance: $instance,
                    resolvedGraphicsTuning: resolvedGraphicsTuning,
                    canRollback: graphicsCanRollback || instance.lastGraphicsTuningSnapshot?.canRollback == true,
                    statusText: graphicsTuningStatus,
                    isWorking: graphicsTuningRunning,
                    applyRecommended: applyGraphicsTuning,
                    rollback: rollbackGraphicsTuning,
                    restoreAutomatic: restoreAutomaticGraphicsTuning
                )

                FullWidthDisclosureGroup(isExpanded: $showAdvancedSettings) {
                    InstanceEditorRuntimeOverridesSection(
                        instance: $instance,
                        managedRuntimes: viewModel.managedJavaRuntimes,
                        localRuntimes: viewModel.discoveredJavaRuntimes,
                        manualMemory: manualMemoryBinding,
                        customJvmArguments: customJvmArgumentsBinding,
                        restoreAutomaticTuning: restoreAutomaticTuning
                    )
                } label: {
                    Text(localizedString(theme.language, english: "Advanced Java & Launch", chinese: "高级 Java 与启动", italian: "Java e avvio avanzati", french: "Java et lancement avancés", spanish: "Java e inicio avanzado"))
                        .font(.headline)
                }

                InstanceEditorOrganizationSection(instance: $instance)
            }
        }
        .task {
            if viewModel.managedJavaRuntimes.isEmpty {
                viewModel.loadManagedJavaRuntimes()
            }
            if viewModel.discoveredJavaRuntimes.isEmpty {
                viewModel.scanJavaRuntimes()
            }
        }
        .task(id: graphicsPreviewSignature) {
            refreshGraphicsTuningPreview()
        }
    }

    private func openInstanceFolder() {
        FinderIntegration.openInstanceDirectory(instance)
    }
}
