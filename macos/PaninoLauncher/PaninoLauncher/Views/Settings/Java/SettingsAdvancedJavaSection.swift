import SwiftUI

struct SettingsAdvancedJavaSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        FullWidthDisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                SettingsRow(title: localizedString(theme.language, english: "Override", chinese: "覆盖", italian: "Override", french: "Remplacement", spanish: "Sobrescribir"), systemImage: "terminal") {
                    VStack(alignment: .leading, spacing: 8) {
                        JavaRuntimePolicySelector(
                            javaPath: $viewModel.javaPath,
                            managedRuntimes: viewModel.managedJavaRuntimes,
                            localRuntimes: viewModel.discoveredJavaRuntimes
                        )
                        HStack(spacing: 8) {
                            GlassButton(systemImage: "checkmark.circle", title: localizedString(theme.language, english: "Check", chinese: "检查", italian: "Verifica", french: "Vérifier", spanish: "Comprobar"), action: viewModel.checkJavaRuntime)
                            GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan This Mac", chinese: "扫描本机", italian: "Scansiona Mac", french: "Scanner ce Mac", spanish: "Escanear Mac"), action: viewModel.scanJavaRuntimes)
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
}
