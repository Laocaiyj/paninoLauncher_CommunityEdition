import SwiftUI

extension SettingsCenterPage {
    var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString(theme.language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes"))
                .font(.title3.bold())
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)

            ForEach(PaninoSettingsSection.allCases) { section in
                SettingsSectionButton(
                    section: section,
                    isSelected: selectedSection == section
                ) {
                    selectedSection = section
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .frame(width: PaninoTokens.Layout.secondarySidebarWidth)
    }

    var settingsSectionPicker: some View {
        PaninoGlassSegmentedRail {
            Picker("", selection: $selectedSection) {
                ForEach(PaninoSettingsSection.allCases) { section in
                    Text(section.title(language: theme.language)).tag(section)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(minWidth: 520, idealWidth: 620, maxWidth: .infinity)
        }
    }

    @ViewBuilder
    var settingsContentContainer: some View {
        if usesInternalScroll {
            ScrollView {
                settingsContent
                    .padding(22)
                    .frame(maxWidth: 920, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollContentBackground(.hidden)
        } else {
            settingsContent
                .frame(maxWidth: 920, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    var settingsContent: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            switch selectedSection {
            case .account:
                accountSettings
            case .runtime:
                runtimeSettings
            case .download:
                SettingsDownloadSection(
                    viewModel: viewModel,
                    curseForgeAPIKey: $curseForgeAPIKey,
                    sourceTestResponse: sourceTestResponse,
                    sourceTestMessage: sourceTestMessage,
                    sourceTestRunning: sourceTestRunning,
                    speedTestResponse: speedTestResponse,
                    speedTestMessage: speedTestMessage,
                    speedTestRunning: speedTestRunning,
                    runSourceTest: runSourceTest,
                    runSpeedTest: runSpeedTest,
                    restartCore: restartCore
                )
            case .appearance:
                AppearanceSettingsPage(showLanguage: true)
            case .advanced:
                advancedSettings
            }
        }
    }

    var accountSettings: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(title: PaninoSettingsSection.account.title(language: theme.language), systemImage: PaninoSettingsSection.account.systemImage)

                if launcherSettings.advancedModeEnabled {
                    SettingsRow(title: "Client ID", systemImage: "key") {
                        PaninoTextInput("Azure app client ID", text: $viewModel.microsoftClientId, isSecure: true)
                    }
                } else {
                    SettingsRow(title: "Microsoft", systemImage: "key") {
                        Text(
                            viewModel.canStartLogin
                                ? localizedString(theme.language, english: "Built-in sign-in configuration is available.", chinese: "已使用内置登录配置。", italian: "Configurazione di accesso integrata disponibile.", french: "Configuration de connexion intégrée disponible.", spanish: "La configuración integrada de inicio está disponible.")
                                : localizedString(theme.language, english: "Client ID override is hidden until Advanced is enabled.", chinese: "Client ID 覆盖会在启用高级项后显示。", italian: "L'override Client ID è nascosto finché Avanzate non è attivo.", french: "Le Client ID personnalisé est masqué jusqu'à l'activation d'Avancé.", spanish: "El Client ID personalizado se oculta hasta activar Avanzado.")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    }
                }

                AccountCard(accountState: viewModel.accountState)
            }
        }
    }

    var runtimeSettings: some View {
        SettingsRuntimeSection(
            viewModel: viewModel,
            showRuntimeAdvanced: $showRuntimeAdvanced,
            showLocalJava: $showLocalJava,
            pendingManagedJavaDeletion: $pendingManagedJavaDeletion,
            pendingLocalJavaDeletion: $pendingLocalJavaDeletion
        )
    }
}
