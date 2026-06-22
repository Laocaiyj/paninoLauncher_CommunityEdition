import SwiftUI

struct PaninoToolsCommandsMenu: Commands {
    let language: AppLanguage
    let dispatch: (NativeAppCommand) -> Void
    let openSettings: (PaninoSettingsSection?) -> Void

    var body: some Commands {
        CommandMenu(PaninoMenuText.toolsMenu.localized(language)) {
            Button(AppText.startCore.localized(language)) {
                dispatch(.startCore)
            }

            Button(AppText.stopCore.localized(language)) {
                dispatch(.stopCore)
            }

            Button(PaninoMenuText.scanJavaRuntimes.localized(language)) {
                dispatch(.scanJava)
            }

            Divider()

            Button(PaninoMenuText.openDownloadCache.localized(language)) {
                dispatch(.openDownloadCache)
            }

            Button(PaninoMenuText.clearDownloadCache.localized(language)) {
                dispatch(.clearDownloadCache)
            }

            Button(PaninoMenuText.openLogsFolder.localized(language)) {
                dispatch(.openLogsDirectory)
            }

            Divider()

            Button(PaninoMenuText.accountSettings.localized(language)) {
                openSettings(.account)
            }

            Button(PaninoMenuText.runtimeSettings.localized(language)) {
                openSettings(.runtime)
            }

            Button(PaninoMenuText.downloadSettings.localized(language)) {
                openSettings(.download)
            }

            Button(PaninoMenuText.appearanceSettings.localized(language)) {
                openSettings(.appearance)
            }

            Button(PaninoMenuText.advancedSettings.localized(language)) {
                openSettings(.advanced)
            }
        }
    }
}
