import SwiftUI

struct SettingsDownloadSection: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var curseForgeAPIKey: String
    let sourceTestResponse: CoreNetworkSourceTestResponse?
    let sourceTestMessage: String
    let sourceTestRunning: Bool
    let speedTestResponse: CoreNetworkSpeedTestResponse?
    let speedTestMessage: String
    let speedTestRunning: Bool
    let runSourceTest: () -> Void
    let runSpeedTest: () -> Void
    let restartCore: () -> Void

    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var launcherSettings: LauncherSettings
    @EnvironmentObject var taskCenterStore: TaskCenterStore
    @EnvironmentObject var onlineContentStore: OnlineContentStore

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(title: PaninoSettingsSection.download.title(language: theme.language), systemImage: PaninoSettingsSection.download.systemImage)

                downloadStrategyRow

                if launcherSettings.advancedModeEnabled {
                    sourceRow
                }

                proxyRow

                if launcherSettings.advancedModeEnabled {
                    workerLimitRows
                }

                curseForgeRow
                cacheSection
            }
        }
    }

    private var downloadStrategyRow: some View {
        SettingsRow(title: "Download Strategy", systemImage: "speedometer") {
            VStack(alignment: .leading, spacing: 6) {
                Picker("Download Strategy", selection: $launcherSettings.downloadStrategy) {
                    ForEach(DownloadStrategy.allCases) { strategy in
                        Text(strategy.title).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
                CapabilityNote(
                    capability: viewModel.coreState.isReady ? .requiresCoreRestart : .available,
                    detail: launcherSettings.downloadStrategy.detail
                )
            }
        }
    }

    private var curseForgeRow: some View {
        SettingsRow(title: "CurseForge API", systemImage: "key") {
            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString(theme.language, english: "Optional advanced channel. Release builds do not include a shared API key; personal keys stay only in local Keychain.", chinese: "可选高级渠道。发布版不会内置共享 API Key；个人 Key 只保存在本机钥匙串。", italian: "Canale avanzato opzionale. Le build pubbliche non includono una chiave condivisa.", french: "Canal avancé optionnel. Les versions publiques n'intègrent pas de clé partagée.", spanish: "Canal avanzado opcional. Las versiones públicas no incluyen una clave compartida."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    PaninoTextInput(
                        onlineContentStore.hasCurseForgeAPIKey() ? "Stored in Keychain" : "Optional personal CurseForge API Key",
                        text: $curseForgeAPIKey,
                        isSecure: true
                    )
                    GlassButton(systemImage: "checkmark.circle", title: AppText.apply.localized(theme.language), prominent: true) {
                        onlineContentStore.saveCurseForgeAPIKey(curseForgeAPIKey)
                        curseForgeAPIKey = ""
                    }
                    GlassButton(systemImage: "trash", title: AppText.clear.localized(theme.language)) {
                        onlineContentStore.saveCurseForgeAPIKey("")
                        curseForgeAPIKey = ""
                    }
                }
            }
        }
    }
}
