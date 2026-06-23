import SwiftUI

struct PaninoHelpCommands: Commands {
    let language: AppLanguage
    let dispatch: (NativeAppCommand) -> Void

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(PaninoMenuText.openMinecraftWiki.localized(language)) {
                NativeMacCommands.openExternalURL("https://minecraft.wiki/")
            }

            Divider()

            Button(PaninoMenuText.exportDiagnostics.localized(language)) {
                dispatch(.exportDiagnostics)
            }

            Button(PaninoMenuText.copyDiagnosticSummary.localized(language)) {
                dispatch(.copyDiagnosticSummary)
            }
        }
    }
}
