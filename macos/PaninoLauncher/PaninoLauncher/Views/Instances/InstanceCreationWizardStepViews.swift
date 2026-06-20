import SwiftUI

struct InstanceCreationSourceStep: View {
    @Binding var draft: InstanceCreationDraft
    let sourceHelpText: String

    @EnvironmentObject private var theme: ThemeSettings

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

    @EnvironmentObject private var theme: ThemeSettings

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
                loaderControls
            }

            if draft.source == "Import Modpack" {
                modpackControls
            }
        }
    }

    private var loaderControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(title: AppText.loader.localized(theme.language), systemImage: "puzzlepiece.extension") {
                Picker(AppText.loader.localized(theme.language), selection: $draft.loader) {
                    ForEach(availableLoaderOptions) { option in
                        Text(option.kind.title).tag(Optional(option.kind))
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 520)
                .disabled(availableLoaderOptions.isEmpty)
            }

            SettingsRow(title: localizedString(theme.language, english: "Loader Version", chinese: "Loader 版本", italian: "Versione loader", french: "Version du loader", spanish: "Versión del loader"), systemImage: "number") {
                Picker("Loader Version", selection: $draft.loaderVersion) {
                    if let recommended = selectedLoaderOption?.recommendedVersion {
                        Text("\(recommended) · Recommended").tag(Optional(recommended))
                    }
                    ForEach(nonRecommendedSelectedLoaderVersions, id: \.id) { metadata in
                        Text(metadata.stable ? metadata.loaderVersion : "\(metadata.loaderVersion) · Experimental")
                            .tag(Optional(metadata.loaderVersion))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 280)
                .disabled(selectedLoaderVersions.isEmpty)
            }

            Text(loaderStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modpackControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(title: localizedString(theme.language, english: "Source", chinese: "来源", italian: "Origine", french: "Source", spanish: "Fuente"), systemImage: "tray.and.arrow.down") {
                Picker("Modpack Source", selection: $draft.modpackSource) {
                    Text("Online").tag("Online")
                    Text("Local File").tag("Local File")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
            }
            if draft.modpackSource == "Local File" {
                SettingsRow(title: localizedString(theme.language, english: "File", chinese: "文件", italian: "File", french: "Fichier", spanish: "Archivo"), systemImage: "doc.zipper") {
                    PaninoTextInput(".mrpack or CurseForge manifest .zip", text: $draft.modpackPath)
                }
            }
            Text(localizedString(theme.language, english: "Modpacks use a dedicated import path. Online import opens the Get page; local files are handed to Core import preflight before any configuration is created.", chinese: "整合包使用专用导入路径。在线整合包会打开“获取”页；本地文件必须先交给 Core 预检，确认后才创建配置。", italian: "I modpack usano un flusso dedicato.", french: "Les modpacks utilisent un flux d'import dédié.", spanish: "Los modpacks usan un flujo de importación dedicado."))
                .font(.caption)
                .foregroundStyle(.secondary)
            if draft.modpackSource == "Local File" {
                HStack(spacing: 8) {
                    GlassButton(systemImage: "checklist", title: localizedString(theme.language, english: "Run Preflight", chinese: "运行预检", italian: "Preflight", french: "Précontrôle", spanish: "Preflight"), action: runModpackPreflight)
                        .disabled(isCheckingModpack || draft.modpackPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text(modpackPreflightSummary)
                        .font(.caption)
                        .foregroundStyle(modpackPreflight?.valid == true ? .secondary : Color.orange)
                        .lineLimit(2)
                }
            }
        }
    }
}

struct InstanceCreationReviewStep: View {
    @Binding var draft: InstanceCreationDraft
    @Binding var showAdvancedOptions: Bool
    let loaderReviewText: String
    let installPlanSummary: String

    @EnvironmentObject private var theme: ThemeSettings

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
                advancedOptions
            } label: {
                Text(localizedString(theme.language, english: "More Options", chinese: "更多选项", italian: "Altre opzioni", french: "Plus d'options", spanish: "Más opciones"))
                    .font(.headline)
            }
        }
    }

    private var advancedOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsRow(title: "Game Dir", systemImage: "folder") {
                PaninoTextInput("Game directory", text: $draft.gameDirectory)
            }
            SettingsRow(title: "Java", systemImage: "cup.and.saucer") {
                PaninoTextInput("Custom Java path", text: $draft.javaPath)
            }
            SettingsRow(title: "Memory", systemImage: "memorychip") {
                Stepper(value: $draft.memoryMb, in: PaninoLimits.memoryMb, step: 512) {
                    Text("\(draft.memoryMb) MB")
                        .monospacedDigit()
                }
            }
            SettingsRow(title: "Group", systemImage: "folder.badge.gearshape") {
                PaninoTextInput("Group", text: $draft.group)
            }
        }
        .padding(.top, 8)
    }
}
