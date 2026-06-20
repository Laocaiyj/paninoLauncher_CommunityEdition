import SwiftUI

struct SettingsJavaRuntimePanel: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var showRuntimeAdvanced: Bool
    @Binding var showLocalJava: Bool
    @Binding var pendingManagedJavaDeletion: CoreJavaManagedRuntime?
    @Binding var pendingLocalJavaDeletion: JavaRuntimeCandidate?

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var launcherSettings: LauncherSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(title: PaninoSettingsSection.runtime.title(language: theme.language), systemImage: PaninoSettingsSection.runtime.systemImage)

                javaManagementRow
                managedRuntimesSection
                localJavaSection
                advancedJavaSection
            }
        }
        .task {
            viewModel.loadManagedJavaRuntimes()
            viewModel.resolveJavaRuntime(version: viewModel.version)
            if launcherSettings.autoDetectJava, viewModel.discoveredJavaRuntimes.isEmpty {
                viewModel.scanJavaRuntimes()
            }
        }
    }

    private var javaManagementRow: some View {
        SettingsRow(title: "Java", systemImage: "cup.and.saucer") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(localizedString(theme.language, english: "Automatic management", chinese: "自动管理", italian: "Gestione automatica", french: "Gestion automatique", spanish: "Gestión automática"))
                        .font(.callout.weight(.semibold))
                    Spacer()
                    GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                        viewModel.loadManagedJavaRuntimes()
                        viewModel.resolveJavaRuntime(version: viewModel.version)
                    }
                    GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan", chinese: "扫描", italian: "Scansiona", french: "Scanner", spanish: "Escanear")) {
                        viewModel.scanJavaRuntimes()
                    }
                    if let resolution = viewModel.javaRuntimeResolution, resolution.isDownloadable {
                        GlassButton(systemImage: "arrow.down.circle", title: localizedString(theme.language, english: "Download Java \(resolution.requiredMajorVersion)", chinese: "下载 Java \(resolution.requiredMajorVersion)", italian: "Scarica Java \(resolution.requiredMajorVersion)", french: "Télécharger Java \(resolution.requiredMajorVersion)", spanish: "Descargar Java \(resolution.requiredMajorVersion)"), prominent: true) {
                            viewModel.installManagedJavaRuntime(featureVersion: resolution.requiredMajorVersion)
                        }
                    }
                    if let runtime = selectedManagedRuntimeForRepair {
                        GlassButton(systemImage: "wrench.and.screwdriver", title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar")) {
                            viewModel.verifyManagedJavaRuntime(runtime)
                        }
                    }
                }
                Text(viewModel.javaRuntimeResolution?.conciseStatus ?? viewModel.javaRuntimeStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var managedRuntimesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(localizedString(theme.language, english: "Managed Runtimes", chinese: "托管 Runtime", italian: "Runtime gestiti", french: "Runtimes gérés", spanish: "Runtimes gestionados"))
                    .font(.headline)
                Spacer()
                GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Import", chinese: "导入", italian: "Importa", french: "Importer", spanish: "Importar")) {
                    viewModel.importManagedJavaRuntime()
                }
                GlassButton(systemImage: "arrow.triangle.2.circlepath", title: localizedString(theme.language, english: "Clean", chinese: "清理", italian: "Pulisci", french: "Nettoyer", spanish: "Limpiar")) {
                    viewModel.cleanupManagedJavaRuntimes()
                }
            }
            if viewModel.managedJavaRuntimes.isEmpty {
                Text(localizedString(theme.language, english: "No managed Java runtime is installed yet.", chinese: "尚未安装托管 Java Runtime。", italian: "Nessun runtime Java gestito installato.", french: "Aucun runtime Java géré installé.", spanish: "Aún no hay runtime Java gestionado."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.managedJavaRuntimes) { runtime in
                        ManagedJavaRuntimeRow(
                            runtime: runtime,
                            makeDefault: { viewModel.selectManagedJavaRuntime(runtime) },
                            verify: { viewModel.verifyManagedJavaRuntime(runtime) },
                            remove: { pendingManagedJavaDeletion = runtime }
                        )
                    }
                }
            }
        }
    }

    private var localJavaSection: some View {
        FullWidthDisclosureGroup(isExpanded: $showLocalJava) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(viewModel.javaScanStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan This Mac", chinese: "扫描本机", italian: "Scansiona Mac", french: "Scanner ce Mac", spanish: "Escanear Mac")) {
                        viewModel.scanJavaRuntimes()
                    }
                }
                if viewModel.discoveredJavaRuntimes.filter(\.isAvailable).isEmpty {
                    Text(localizedString(theme.language, english: "No local Java runtime is available yet.", chinese: "尚未发现可用的本机 Java。", italian: "Nessun Java locale disponibile.", french: "Aucun Java local disponible.", spanish: "No hay Java local disponible."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.discoveredJavaRuntimes.filter(\.isAvailable)) { runtime in
                            localJavaRuntimeRow(runtime)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Text(localizedString(theme.language, english: "Local Java", chinese: "本机 Java", italian: "Java locale", french: "Java local", spanish: "Java local"))
                .font(.callout.weight(.semibold))
        }
    }

    private func localJavaRuntimeRow(_ runtime: JavaRuntimeCandidate) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(runtime.source)
                        .font(.caption.weight(.semibold))
                    if runtime.hasMeaningfulSummary {
                        Text(runtime.displayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text(runtime.pathDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let deleteTarget = runtime.deleteTarget, runtime.supportsDeletion {
                    Text(deleteTarget)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            if runtime.supportsDeletion {
                GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language)) {
                    pendingLocalJavaDeletion = runtime
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }

    private var advancedJavaSection: some View {
        FullWidthDisclosureGroup(isExpanded: $showRuntimeAdvanced) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                SettingsRow(title: localizedString(theme.language, english: "Override", chinese: "覆盖", italian: "Override", french: "Remplacement", spanish: "Sobrescribir"), systemImage: "terminal") {
                    VStack(alignment: .leading, spacing: 8) {
                        JavaRuntimePolicySelector(
                            javaPath: $viewModel.javaPath,
                            managedRuntimes: viewModel.managedJavaRuntimes,
                            localRuntimes: viewModel.discoveredJavaRuntimes
                        )
                        HStack(spacing: 8) {
                            GlassButton(systemImage: "checkmark.circle", title: localizedString(theme.language, english: "Check", chinese: "检查", italian: "Verifica", french: "Vérifier", spanish: "Comprobar")) {
                                viewModel.checkJavaRuntime()
                            }
                            GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan This Mac", chinese: "扫描本机", italian: "Scansiona Mac", french: "Scanner ce Mac", spanish: "Escanear Mac")) {
                                viewModel.scanJavaRuntimes()
                            }
                        }
                        if let javaStatus = viewModel.javaStatus {
                            Text(javaStatus.displayText)
                                .font(.caption)
                                .foregroundStyle(javaStatus.isAvailable ? .secondary : Color.orange)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Text(localizedString(theme.language, english: "Advanced Java", chinese: "高级 Java", italian: "Java avanzato", french: "Java avancé", spanish: "Java avanzado"))
                .font(.callout.weight(.semibold))
        }
    }

    private var selectedManagedRuntimeForRepair: CoreJavaManagedRuntime? {
        if let selectedRuntimeId = viewModel.javaRuntimeResolution?.selectedRuntimeId,
           let runtime = viewModel.managedJavaRuntimes.first(where: { $0.id == selectedRuntimeId }) {
            return runtime
        }
        return viewModel.managedJavaRuntimes.first
    }
}
