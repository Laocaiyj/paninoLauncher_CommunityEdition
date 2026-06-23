import SwiftUI

struct PaninoInstanceCommandsMenu: Commands {
    let language: AppLanguage
    let hasSelectedInstance: Bool
    let dispatch: (NativeAppCommand) -> Void

    var body: some Commands {
        CommandMenu(PaninoMenuText.instancesMenu.localized(language)) {
            Button(PaninoMenuText.manageLocalInstances.localized(language)) {
                dispatch(.openInstances)
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button(PaninoMenuText.openInstanceFolder.localized(language)) {
                dispatch(.openInstanceDirectory)
            }
            .disabled(!hasSelectedInstance)

            Divider()

            Button(PaninoMenuText.manageResources.localized(language)) {
                dispatch(.openResources)
            }

            Button(PaninoMenuText.browseVersionsLoaders.localized(language)) {
                dispatch(.openVersions)
            }

            Divider()

            Button(PaninoMenuText.duplicateInstance.localized(language)) {
                dispatch(.duplicateInstance)
            }
            .disabled(!hasSelectedInstance)

            Button(PaninoMenuText.deleteInstance.localized(language), role: .destructive) {
                dispatch(.deleteInstance)
            }
            .disabled(!hasSelectedInstance)
        }
    }
}
