import SwiftUI

struct PaninoTaskCommandsMenu: Commands {
    let language: AppLanguage
    let dispatch: (NativeAppCommand) -> Void

    var body: some Commands {
        CommandMenu(PaninoMenuText.tasksMenu.localized(language)) {
            Button(PaninoMenuText.openTaskCenter.localized(language)) {
                dispatch(.openActivity)
            }
            .keyboardShortcut("4", modifiers: [.command])

            Button(PaninoMenuText.retryAttentionTask.localized(language)) {
                dispatch(.retryTask)
            }

            Divider()

            Button(PaninoMenuText.openLogs.localized(language)) {
                dispatch(.openLogs)
            }

            Button(PaninoMenuText.exportDiagnostics.localized(language)) {
                dispatch(.exportDiagnostics)
            }

            Button(PaninoMenuText.copyDiagnosticSummary.localized(language)) {
                dispatch(.copyDiagnosticSummary)
            }
        }
    }
}
