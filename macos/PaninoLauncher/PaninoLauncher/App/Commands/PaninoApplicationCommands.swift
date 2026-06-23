import SwiftUI

struct PaninoApplicationCommands: Commands {
    let language: AppLanguage
    let dispatch: (NativeAppCommand) -> Void
    let openSettings: (PaninoSettingsSection?) -> Void

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(PaninoMenuText.about.localized(language)) {
                NativeMacCommands.showAboutPanel()
            }
        }

        CommandGroup(after: .appInfo) {
            Button(PaninoMenuText.checkForUpdates.localized(language)) {
                dispatch(.checkForUpdates)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(PaninoMenuText.settings.localized(language)) {
                openSettings(nil)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }

        CommandGroup(replacing: .appTermination) {
            Button(PaninoMenuText.quit.localized(language)) {
                SettingsDebouncer.flush()
                NativeMacCommands.quit()
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}
