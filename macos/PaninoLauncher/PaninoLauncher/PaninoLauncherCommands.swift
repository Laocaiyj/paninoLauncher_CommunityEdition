import SwiftUI

struct PaninoLauncherCommands: Commands {
    let language: AppLanguage
    let hasSelectedInstance: Bool
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

        CommandGroup(replacing: .appTermination) {
            Button(PaninoMenuText.quit.localized(language)) {
                SettingsDebouncer.flush()
                NativeMacCommands.quit()
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}
