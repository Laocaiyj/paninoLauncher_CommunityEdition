import SwiftUI

struct PaninoLaunchCommandsMenu: Commands {
    let language: AppLanguage
    let dispatch: (NativeAppCommand) -> Void

    var body: some Commands {
        CommandMenu(PaninoMenuText.launchMenu.localized(language)) {
            Button(PaninoMenuText.launchSelected.localized(language)) {
                dispatch(.launchDefault)
            }
            .keyboardShortcut(.return, modifiers: [.command])

            Button(PaninoMenuText.openLaunchDashboard.localized(language)) {
                dispatch(.openLaunch)
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button(PaninoMenuText.openRecentInstance.localized(language)) {
                dispatch(.openRecent)
            }

            Divider()

            Button(PaninoMenuText.checkJavaRuntime.localized(language)) {
                dispatch(.checkJava)
            }
        }
    }
}
