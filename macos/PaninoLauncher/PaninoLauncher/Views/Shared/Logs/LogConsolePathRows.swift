import SwiftUI

struct LogConsolePathRows: View {
    let exportedURL: URL?
    let diagnosticURL: URL?

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let exportedURL {
                diagnosticPathRow(
                    title: localizedString(theme.language, english: "Log", chinese: "日志", italian: "Log", french: "Journal", spanish: "Registro"),
                    url: exportedURL
                )
            }
            if let diagnosticURL {
                diagnosticPathRow(
                    title: localizedString(theme.language, english: "Diagnostics", chinese: "诊断", italian: "Diagnostica", french: "Diagnostic", spanish: "Diagnóstico"),
                    url: diagnosticURL
                )
            }
            if !diagnosticsStore.copyStatus.isEmpty {
                Text(diagnosticsStore.copyStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func diagnosticPathRow(title: String, url: URL) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(url.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}
