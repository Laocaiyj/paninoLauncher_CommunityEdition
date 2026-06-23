import SwiftUI

struct SettingsManagedJavaRuntimesSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var pendingManagedJavaDeletion: CoreJavaManagedRuntime?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(localizedString(theme.language, english: "Managed Runtimes", chinese: "托管 Runtime", italian: "Runtime gestiti", french: "Runtimes gérés", spanish: "Runtimes gestionados"))
                    .font(.headline)
                Spacer()
                GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Import", chinese: "导入", italian: "Importa", french: "Importer", spanish: "Importar"), action: viewModel.importManagedJavaRuntime)
                GlassButton(systemImage: "arrow.triangle.2.circlepath", title: localizedString(theme.language, english: "Clean", chinese: "清理", italian: "Pulisci", french: "Nettoyer", spanish: "Limpiar"), action: viewModel.cleanupManagedJavaRuntimes)
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
}
