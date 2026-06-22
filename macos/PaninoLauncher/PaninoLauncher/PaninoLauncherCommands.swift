import SwiftUI

struct PaninoLauncherCommands: Commands {
    let language: AppLanguage
    let hasSelectedInstance: Bool
    let dispatch: (NativeAppCommand) -> Void
    let openSettings: (PaninoSettingsSection?) -> Void

    var body: some Commands {
        PaninoApplicationCommands(
            language: language,
            dispatch: dispatch,
            openSettings: openSettings
        )
        PaninoLaunchCommandsMenu(language: language, dispatch: dispatch)
        PaninoInstanceCommandsMenu(
            language: language,
            hasSelectedInstance: hasSelectedInstance,
            dispatch: dispatch
        )
        PaninoGetCommandsMenu(language: language, dispatch: dispatch)
        PaninoTaskCommandsMenu(language: language, dispatch: dispatch)
        PaninoToolsCommandsMenu(
            language: language,
            dispatch: dispatch,
            openSettings: openSettings
        )
        PaninoHelpCommands(language: language, dispatch: dispatch)
    }
}
