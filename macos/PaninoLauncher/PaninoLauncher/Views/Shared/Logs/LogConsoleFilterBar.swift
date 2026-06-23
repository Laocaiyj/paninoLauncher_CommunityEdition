import SwiftUI

struct LogConsoleFilterBar: View {
    let selectedLogs: [LogLine]
    let onCopySelected: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore

    var body: some View {
        HStack(spacing: 10) {
            PaninoTextInput(
                localizedString(theme.language, english: "Search logs", chinese: "搜索日志", italian: "Cerca log", french: "Rechercher dans les journaux", spanish: "Buscar registros"),
                text: $diagnosticsStore.searchText
            )
            .frame(maxWidth: 260)

            Toggle(isOn: $diagnosticsStore.autoScroll) {
                Label(localizedString(theme.language, english: "Auto Scroll", chinese: "自动滚动", italian: "Scorrimento automatico", french: "Défilement auto", spanish: "Desplazamiento automático"), systemImage: "arrow.down.to.line")
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $diagnosticsStore.pauseScroll) {
                Label(localizedString(theme.language, english: "Pause", chinese: "暂停", italian: "Pausa", french: "Pause", spanish: "Pausa"), systemImage: "pause.circle")
            }
            .toggleStyle(.checkbox)

            Spacer()

            GlassButton(systemImage: "doc.on.doc", title: localizedString(theme.language, english: "Copy Selected", chinese: "复制选中", italian: "Copia selezione", french: "Copier sélection", spanish: "Copiar selección")) {
                onCopySelected()
            }
            .disabled(selectedLogs.isEmpty)
        }
    }
}
