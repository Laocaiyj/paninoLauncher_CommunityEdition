import SwiftUI

struct LogConsoleToolbar: View {
    let title: String
    let onExport: () -> Void
    let onExportDiagnostics: () -> Void
    let onClear: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PanelHeader(title: title, systemImage: "terminal")

            Spacer()

            Picker("", selection: $diagnosticsStore.selectedTab) {
                ForEach(LogPanelTab.allCases) { tab in
                    Text(tab.title(language: theme.language)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Picker("", selection: $diagnosticsStore.filterLevel) {
                ForEach(LogFilterLevel.allCases) { level in
                    Text(level.title(language: theme.language)).tag(level)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

            GlassButton(systemImage: "square.and.arrow.down", title: AppText.export.localized(theme.language), action: onExport)
            GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Diagnostics", chinese: "诊断", italian: "Diagnostica", french: "Diagnostic", spanish: "Diagnóstico"), action: onExportDiagnostics)
            GlassButton(systemImage: "trash", title: AppText.clear.localized(theme.language), action: onClear)
        }
    }
}
