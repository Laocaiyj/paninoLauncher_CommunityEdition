import SwiftUI

struct PaninoGetCommandsMenu: Commands {
    let language: AppLanguage
    let dispatch: (NativeAppCommand) -> Void

    var body: some Commands {
        CommandMenu(PaninoMenuText.getMenu.localized(language)) {
            Button(PaninoMenuText.openGetPage.localized(language)) {
                dispatch(.openDiscover)
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button(PaninoMenuText.browseVersionsLoaders.localized(language)) {
                dispatch(.openVersions)
            }

            Button(PaninoMenuText.manageResources.localized(language)) {
                dispatch(.openResources)
            }
        }
    }
}
