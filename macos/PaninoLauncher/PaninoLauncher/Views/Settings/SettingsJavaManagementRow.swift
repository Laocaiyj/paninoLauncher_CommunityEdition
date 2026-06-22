import SwiftUI

struct SettingsJavaManagementRow: View {
    @EnvironmentObject private var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel

    var body: some View {
        SettingsRow(title: "Java", systemImage: "cup.and.saucer") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(localizedString(theme.language, english: "Automatic management", chinese: "自动管理", italian: "Gestione automatica", french: "Gestion automatique", spanish: "Gestión automática"))
                        .font(.callout.weight(.semibold))
                    Spacer()
                    GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: refreshManagedRuntimes)
                    GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan", chinese: "扫描", italian: "Scansiona", french: "Scanner", spanish: "Escanear"), action: viewModel.scanJavaRuntimes)
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

    private var selectedManagedRuntimeForRepair: CoreJavaManagedRuntime? {
        if let selectedRuntimeId = viewModel.javaRuntimeResolution?.selectedRuntimeId,
           let runtime = viewModel.managedJavaRuntimes.first(where: { $0.id == selectedRuntimeId }) {
            return runtime
        }
        return viewModel.managedJavaRuntimes.first
    }

    private func refreshManagedRuntimes() {
        viewModel.loadManagedJavaRuntimes()
        viewModel.resolveJavaRuntime(version: viewModel.version)
    }
}
