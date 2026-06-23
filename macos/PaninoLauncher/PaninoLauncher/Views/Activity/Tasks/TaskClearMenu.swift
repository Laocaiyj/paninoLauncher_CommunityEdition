import SwiftUI

struct TaskClearMenu: View {
    let onClear: (TaskClearAction) -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Menu {
            Button(TaskClearAction.completed.title(language: theme.language)) { onClear(.completed) }
            Button(TaskClearAction.cancelledAndInterrupted.title(language: theme.language)) { onClear(.cancelledAndInterrupted) }
            Button(TaskClearAction.failed.title(language: theme.language)) { onClear(.failed) }
            Button(TaskClearAction.allFinishedKeepingFailures.title(language: theme.language)) { onClear(.allFinishedKeepingFailures) }
            Divider()
            Button(TaskClearAction.allFinished.title(language: theme.language), role: .destructive) { onClear(.allFinished) }
            Button(TaskClearAction.allHistory.title(language: theme.language), role: .destructive) { onClear(.allHistory) }
        } label: {
            Label(localizedString(theme.language, english: "Clean Up", chinese: "清理", italian: "Pulisci", french: "Nettoyer", spanish: "Limpiar"), systemImage: "trash")
        }
        .menuStyle(.button)
        .fixedSize()
    }
}
