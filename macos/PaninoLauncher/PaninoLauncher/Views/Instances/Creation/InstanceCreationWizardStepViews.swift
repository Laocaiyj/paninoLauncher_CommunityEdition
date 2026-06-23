import SwiftUI

struct InstanceCreationSourceStep: View {
    @EnvironmentObject private var theme: ThemeSettings

    @Binding var draft: InstanceCreationDraft
    let sourceHelpText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(title: "Name", systemImage: "text.cursor") {
                PaninoTextInput(
                    localizedString(theme.language, english: "Configuration name", chinese: "游戏配置名称", italian: "Nome configurazione", french: "Nom de configuration", spanish: "Nombre de configuración"),
                    text: $draft.name
                )
            }
            SettingsRow(title: localizedString(theme.language, english: "Purpose", chinese: "用途", italian: "Uso", french: "Usage", spanish: "Uso"), systemImage: "square.stack.3d.up") {
                Picker("Source", selection: $draft.source) {
                    Text(localizedString(theme.language, english: "Vanilla Minecraft", chinese: "原版 Minecraft", italian: "Minecraft Vanilla", french: "Minecraft Vanilla", spanish: "Minecraft Vanilla")).tag("Vanilla Minecraft")
                    Text(localizedString(theme.language, english: "Mod Configuration", chinese: "Mod 配置", italian: "Configurazione Mod", french: "Configuration Mod", spanish: "Configuración Mod")).tag("Mod Configuration")
                    Text(localizedString(theme.language, english: "Import Modpack", chinese: "导入整合包", italian: "Importa modpack", french: "Importer modpack", spanish: "Importar modpack")).tag("Import Modpack")
                }
                .pickerStyle(.segmented)
            }
            Text(sourceHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct InstanceCreationVersionStep: View {
    @EnvironmentObject private var theme: ThemeSettings

    @Binding var draft: InstanceCreationDraft
    let versionPickerVersions: [MinecraftVersionInfo]
    let versionPickerTotalMatches: Int
    let versionPickerLimit: Int
    @Binding var versionSearchText: String
    @Binding var showingVersionPicker: Bool
    let availableLoaderOptions: [LoaderCompatibilityOption]
    let selectedLoaderOption: LoaderCompatibilityOption?
    let selectedLoaderVersions: [LoaderMetadata]
    let nonRecommendedSelectedLoaderVersions: [LoaderMetadata]
    let loaderStatusText: String
    let modpackPreflight: CoreModpackPreflightResponse?
    let modpackPreflightSummary: String
    let isCheckingModpack: Bool
    let runModpackPreflight: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(title: "Minecraft", systemImage: "cube.box") {
                MinecraftVersionSearchButton(
                    selectedVersionID: draft.minecraftVersion,
                    versions: versionPickerVersions,
                    totalMatches: versionPickerTotalMatches,
                    limit: versionPickerLimit,
                    searchText: $versionSearchText,
                    showingPicker: $showingVersionPicker
                ) { version in
                    draft.minecraftVersion = version.id
                    showingVersionPicker = false
                }
            }

            if draft.source == "Mod Configuration" {
                InstanceCreationLoaderControls(
                    draft: $draft,
                    availableLoaderOptions: availableLoaderOptions,
                    selectedLoaderOption: selectedLoaderOption,
                    selectedLoaderVersions: selectedLoaderVersions,
                    nonRecommendedSelectedLoaderVersions: nonRecommendedSelectedLoaderVersions,
                    loaderStatusText: loaderStatusText
                )
            }

            if draft.source == "Import Modpack" {
                InstanceCreationModpackControls(
                    draft: $draft,
                    modpackPreflight: modpackPreflight,
                    modpackPreflightSummary: modpackPreflightSummary,
                    isCheckingModpack: isCheckingModpack,
                    runModpackPreflight: runModpackPreflight
                )
            }
        }
    }
}

struct InstanceCreationReviewStep: View {
    @EnvironmentObject private var theme: ThemeSettings

    @Binding var draft: InstanceCreationDraft
    @Binding var showAdvancedOptions: Bool
    let loaderReviewText: String
    let installPlanSummary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InstanceWizardReviewRow(title: localizedString(theme.language, english: "Game Configuration", chinese: "游戏配置", italian: "Configurazione", french: "Configuration", spanish: "Configuración"), value: draft.name)
            InstanceWizardReviewRow(title: "Source", value: draft.source)
            InstanceWizardReviewRow(title: "Version", value: draft.minecraftVersion)
            InstanceWizardReviewRow(title: "Loader", value: loaderReviewText)
            InstanceWizardReviewRow(title: localizedString(theme.language, english: "Runtime", chinese: "运行环境", italian: "Runtime", french: "Runtime", spanish: "Runtime"), value: "\(draft.memoryMb) MB · \(draft.javaPath.isEmpty ? "Automatic Java" : draft.javaPath)")
            InstanceWizardReviewRow(title: localizedString(theme.language, english: "Directory", chinese: "目录", italian: "Cartella", french: "Dossier", spanish: "Directorio"), value: draft.gameDirectory)
            InstanceWizardReviewRow(title: localizedString(theme.language, english: "Install Plan", chinese: "安装计划", italian: "Piano installazione", french: "Plan d'installation", spanish: "Plan de instalación"), value: installPlanSummary)

            FullWidthDisclosureGroup(isExpanded: $showAdvancedOptions) {
                InstanceCreationAdvancedOptions(draft: $draft)
            } label: {
                Text(localizedString(theme.language, english: "More Options", chinese: "更多选项", italian: "Altre opzioni", french: "Plus d'options", spanish: "Más opciones"))
                    .font(.headline)
            }
        }
    }
}
