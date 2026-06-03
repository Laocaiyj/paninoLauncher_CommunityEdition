import SwiftUI

private enum InstanceCreationStep: String, CaseIterable, Identifiable {
    case source
    case version
    case review

    var id: String { rawValue }
}

struct InstanceCreationDraft: Equatable {
    var name = "New Game Configuration"
    var source = "Blank Configuration"
    var minecraftVersion = "1.20.1"
    var loader: LoaderKind?
    var loaderVersion: String?
    var modpackSource = "Online"
    var modpackPath = ""
    var gameDirectory = ""
    var javaPath = ""
    var memoryMb = 4096
    var group = "Default"

    init() {}

    @MainActor
    init(settings: LauncherSettings) {
        gameDirectory = Self.defaultConfigurationDirectory(name: name)
        javaPath = ""
        memoryMb = SettingsStore.memoryMb
    }

    static func defaultConfigurationDirectory(name: String) -> String {
        let slug = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9._-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        let safeSlug = slug.isEmpty ? UUID().uuidString : slug
        let root = (try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true)
        return root
            .appendingPathComponent(safeSlug, isDirectory: true)
            .path
    }
}

private struct PendingModpackImportReview: Identifiable {
    let id = UUID()
    let plan: CoreTypedInstallPlan
    let sourcePath: String
    let targetGameDir: String
}

struct InstanceCreationWizard: View {
    @Binding var draft: InstanceCreationDraft
    let create: (InstanceCreationDraft) -> Void
    let openModpackImport: () -> Void
    let loadLoaderCompatibility: (String) async throws -> CoreLoaderCompatibilityResponse
    let preflightModpack: (String, String?, String?) async throws -> CoreModpackPreflightResponse
    let importModpack: (String, String, String) async throws -> CoreModpackImportResponse

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var versionStore: VersionContentStore
    @State private var step: InstanceCreationStep = .source
    @State private var showAdvancedOptions = false
    @State private var loaderOptions: [LoaderCompatibilityOption] = LoaderKind.allCases.map {
        LoaderCompatibilityOption(kind: $0, recommendedVersion: nil, versions: [], isAvailable: false, reason: nil)
    }
    @State private var loaderStatus = "Loader metadata not loaded"
    @State private var isLoadingLoaders = false
    @State private var modpackPreflight: CoreModpackPreflightResponse?
    @State private var modpackPreflightStatus = ""
    @State private var isCheckingModpack = false
    @State private var pendingModpackImportReview: PendingModpackImportReview?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                PanelHeader(
                    title: localizedString(theme.language, english: "Create Game Configuration", chinese: "创建游戏配置", italian: "Crea configurazione", french: "Créer une configuration", spanish: "Crear configuración"),
                    systemImage: "plus.square.on.square"
                )
                Spacer()
                StatusBadge(title: stepTitle, style: .download)
            }

            InstanceWizardStepper(step: step)

            Group {
                switch step {
                case .source:
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRow(title: "Name", systemImage: "text.cursor") {
                            PaninoTextInput(localizedString(theme.language, english: "Configuration name", chinese: "游戏配置名称", italian: "Nome configurazione", french: "Nom de configuration", spanish: "Nombre de configuración"), text: $draft.name)
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
                case .version:
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRow(title: "Minecraft", systemImage: "cube.box") {
                            Picker("Version", selection: $draft.minecraftVersion) {
                                ForEach(recommendedVersions) { version in
                                    Text(version.id).tag(version.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 280)
                        }

                        if draft.source == "Mod Configuration" {
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

                        if draft.source == "Import Modpack" {
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
                                    GlassButton(systemImage: "checklist", title: localizedString(theme.language, english: "Run Preflight", chinese: "运行预检", italian: "Preflight", french: "Précontrôle", spanish: "Preflight")) {
                                        runModpackPreflight()
                                    }
                                    .disabled(isCheckingModpack || draft.modpackPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    Text(modpackPreflightSummary)
                                        .font(.caption)
                                        .foregroundStyle(modpackPreflight?.valid == true ? .secondary : Color.orange)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                case .review:
                    VStack(alignment: .leading, spacing: 10) {
                        InstanceWizardReviewRow(title: localizedString(theme.language, english: "Game Configuration", chinese: "游戏配置", italian: "Configurazione", french: "Configuration", spanish: "Configuración"), value: draft.name)
                        InstanceWizardReviewRow(title: "Source", value: draft.source)
                        InstanceWizardReviewRow(title: "Version", value: draft.minecraftVersion)
                        InstanceWizardReviewRow(title: "Loader", value: loaderReviewText)
                        InstanceWizardReviewRow(title: localizedString(theme.language, english: "Runtime", chinese: "运行环境", italian: "Runtime", french: "Runtime", spanish: "Runtime"), value: "\(draft.memoryMb) MB · \(draft.javaPath.isEmpty ? "Automatic Java" : draft.javaPath)")
                        InstanceWizardReviewRow(title: localizedString(theme.language, english: "Directory", chinese: "目录", italian: "Cartella", french: "Dossier", spanish: "Directorio"), value: draft.gameDirectory)
                        InstanceWizardReviewRow(title: localizedString(theme.language, english: "Install Plan", chinese: "安装计划", italian: "Piano installazione", french: "Plan d'installation", spanish: "Plan de instalación"), value: installPlanSummary)

                        FullWidthDisclosureGroup(isExpanded: $showAdvancedOptions) {
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
                        } label: {
                            Text(localizedString(theme.language, english: "More Options", chinese: "更多选项", italian: "Altre opzioni", french: "Plus d'options", spanish: "Más opciones"))
                                .font(.headline)
                        }
                    }
                }
            }
            .frame(minHeight: 250, alignment: .topLeading)

            HStack {
                GlassButton(systemImage: "xmark", title: AppText.cancel.localized(theme.language)) {
                    dismiss()
                }
                Spacer()
                GlassButton(systemImage: "chevron.left", title: localizedString(theme.language, english: "Back", chinese: "上一步", italian: "Indietro", french: "Retour", spanish: "Atrás")) {
                    moveStep(-1)
                }
                .disabled(step == .source)
                if step == .review {
                    GlassButton(systemImage: primaryActionIcon, title: primaryActionTitle, prominent: true) {
                        if draft.source == "Import Modpack" {
                            if draft.modpackSource == "Online" {
                                openModpackImport()
                                dismiss()
                            } else {
                                prepareModpackImportReview()
                            }
                        } else {
                            create(draft)
                            dismiss()
                        }
                    }
                    .disabled(!canComplete)
                } else {
                    GlassButton(systemImage: "chevron.right", title: localizedString(theme.language, english: "Next", chinese: "下一步", italian: "Avanti", french: "Suivant", spanish: "Siguiente"), prominent: true) {
                        moveStep(1)
                    }
                    .disabled(!canMoveNext)
                }
            }
        }
        .padding(22)
        .frame(width: 720)
        .onAppear(perform: normalizeDraftForPurpose)
        .onChange(of: draft.source) {
            normalizeDraftForPurpose()
        }
        .onChange(of: draft.modpackPath) {
            modpackPreflight = nil
            modpackPreflightStatus = ""
        }
        .onChange(of: draft.minecraftVersion) {
            if shouldRegenerateName {
                draft.name = generatedName
                draft.gameDirectory = InstanceCreationDraft.defaultConfigurationDirectory(name: draft.name)
            }
            Task { await refreshLoaderOptions() }
        }
        .onChange(of: draft.loader) {
            draft.loaderVersion = selectedLoaderOption?.recommendedVersion
            if shouldRegenerateName {
                draft.name = generatedName
                draft.gameDirectory = InstanceCreationDraft.defaultConfigurationDirectory(name: draft.name)
            }
        }
        .task(id: "\(draft.source)-\(draft.minecraftVersion)") {
            await refreshLoaderOptions()
        }
        .sheet(item: $pendingModpackImportReview) { review in
            InstallPlanReviewSheet(
                plan: review.plan,
                title: localizedString(theme.language, english: "Review modpack import", chinese: "确认整合包导入", italian: "Controlla import modpack", french: "Vérifier import modpack", spanish: "Revisar importación"),
                subtitle: draft.name,
                confirmTitle: localizedString(theme.language, english: "Import", chinese: "导入", italian: "Importa", french: "Importer", spanish: "Importar"),
                repairTitle: review.plan.status == "blocked" || !review.plan.blockedReasons.isEmpty
                    ? localizedString(theme.language, english: "Run Preflight", chinese: "重新预检", italian: "Preflight", french: "Précontrôle", spanish: "Preflight")
                    : nil,
                onCancel: { pendingModpackImportReview = nil },
                onRepair: {
                    pendingModpackImportReview = nil
                    runModpackPreflight()
                },
                onConfirm: { confirmModpackImport(review) }
            )
            .environmentObject(theme)
        }
    }

    private var stepTitle: String {
        switch step {
        case .source: return localizedString(theme.language, english: "Purpose", chinese: "用途", italian: "Uso", french: "Usage", spanish: "Uso")
        case .version: return localizedString(theme.language, english: "Version & Loader", chinese: "版本与 Loader", italian: "Versione e loader", french: "Version et loader", spanish: "Versión y loader")
        case .review: return localizedString(theme.language, english: "Review", chinese: "预检查", italian: "Revisione", french: "Vérification", spanish: "Revisión")
        }
    }

    private var sourceHelpText: String {
        switch draft.source {
        case "Mod Configuration":
            return localizedString(theme.language, english: "Panino will recommend a loader and keep Java, memory and folders automatic unless you open More Options.", chinese: "Panino 会推荐加载器，并自动处理 Java、内存和目录；需要时可在“更多选项”中修改。", italian: "Panino consiglia un loader e automatizza runtime e cartelle.", french: "Panino recommande un loader et automatise Java, mémoire et dossiers.", spanish: "Panino recomienda un loader y automatiza Java, memoria y carpetas.")
        case "Import Modpack":
            return localizedString(theme.language, english: "Modpack import will not create an empty configuration. Choose a pack source first, then Core creates the target after preflight.", chinese: "整合包导入不会创建空配置。先选择整合包来源，Core 预检通过后再创建目标配置。", italian: "L'import modpack non crea configurazioni vuote.", french: "L'import de modpack ne crée pas de configuration vide.", spanish: "Importar modpacks no crea configuraciones vacías.")
        default:
            return localizedString(theme.language, english: "Create a clean Vanilla game configuration with automatic Java, memory and folder defaults.", chinese: "创建一个干净的原版游戏配置，Java、内存和目录默认自动处理。", italian: "Crea una configurazione Vanilla con impostazioni automatiche.", french: "Créer une configuration Vanilla avec réglages automatiques.", spanish: "Crear una configuración Vanilla con ajustes automáticos.")
        }
    }

    private var generatedName: String {
        if draft.source == "Mod Configuration" {
            return "\(draft.loader?.title ?? "Fabric") \(draft.minecraftVersion)"
        }
        if draft.source == "Import Modpack" {
            return modpackPreflight?.name ?? localizedString(theme.language, english: "Imported Modpack", chinese: "导入整合包", italian: "Modpack importato", french: "Modpack importé", spanish: "Modpack importado")
        }
        return "Minecraft \(draft.minecraftVersion)"
    }

    private var shouldRegenerateName: Bool {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            || trimmed == "New Game Configuration"
            || trimmed.hasPrefix("Minecraft ")
            || trimmed.hasPrefix("Fabric ")
            || trimmed.hasPrefix("Forge ")
            || trimmed.hasPrefix("Quilt ")
            || trimmed.hasPrefix("NeoForge ")
    }

    private var recommendedVersions: [MinecraftVersionInfo] {
        uniqueVersions(
            versionStore.versions.filter { $0.id == draft.minecraftVersion }
                + latestReleaseVersions
                + versionStore.versions.filter(\.isInstalled)
                + Array(versionStore.versions.filter { $0.kind == .release }.prefix(8))
        )
    }

    private var latestReleaseVersions: [MinecraftVersionInfo] {
        guard let latestReleaseID = versionStore.latestReleaseID else { return [] }
        return versionStore.versions.filter { $0.id == latestReleaseID }
    }

    private var availableLoaderOptions: [LoaderCompatibilityOption] {
        loaderOptions.filter(\.isAvailable)
    }

    private var selectedLoaderOption: LoaderCompatibilityOption? {
        guard let loader = draft.loader else { return nil }
        return loaderOptions.first { $0.kind == loader }
    }

    private var selectedLoaderVersions: [LoaderMetadata] {
        selectedLoaderOption?.versions ?? []
    }

    private var nonRecommendedSelectedLoaderVersions: [LoaderMetadata] {
        selectedLoaderVersions.filter { $0.loaderVersion != selectedLoaderOption?.recommendedVersion }
    }

    private var loaderStatusText: String {
        if isLoadingLoaders {
            return localizedString(theme.language, english: "Loading Loader compatibility from Core...", chinese: "正在从 Core 加载 Loader 兼容性...", italian: "Caricamento compatibilità loader dal Core...", french: "Chargement compatibilité loader depuis Core...", spanish: "Cargando compatibilidad del loader desde Core...")
        }
        if availableLoaderOptions.isEmpty {
            return localizedString(theme.language, english: loaderStatus, chinese: loaderStatus, italian: loaderStatus, french: loaderStatus, spanish: loaderStatus)
        }
        let names = availableLoaderOptions.map(\.kind.title).joined(separator: ", ")
        return localizedString(theme.language, english: "Core reports compatible loaders: \(names).", chinese: "Core 返回的可用 Loader：\(names)。", italian: "Loader compatibili dal Core: \(names).", french: "Loaders compatibles Core : \(names).", spanish: "Loaders compatibles de Core: \(names).")
    }

    private var loaderReviewText: String {
        guard let loader = draft.loader else { return "Vanilla" }
        return [loader.title, draft.loaderVersion].compactMap { $0 }.joined(separator: " · ")
    }

    private var installPlanSummary: String {
        switch draft.source {
        case "Mod Configuration":
            return localizedString(theme.language, english: "Install Minecraft files, install \(loaderReviewText), then open the Mods page.", chinese: "安装 Minecraft 文件，安装 \(loaderReviewText)，然后进入 Mods 页。", italian: "Installa Minecraft e \(loaderReviewText), poi apri Mods.", french: "Installer Minecraft et \(loaderReviewText), puis ouvrir Mods.", spanish: "Instalar Minecraft y \(loaderReviewText), luego abrir Mods.")
        case "Import Modpack":
            return draft.modpackSource == "Online"
                ? localizedString(theme.language, english: "Open the Get page and select a modpack before Core creates a configuration.", chinese: "打开“获取”页选择整合包，Core 预检后再创建配置。", italian: "Apri Ottieni e seleziona un modpack.", french: "Ouvrir Obtenir et sélectionner un modpack.", spanish: "Abrir Obtener y elegir un modpack.")
                : localizedString(theme.language, english: "Local modpack path will be parsed by Core before any configuration is created.", chinese: "本地整合包路径会先由 Core 解析，之后才创建配置。", italian: "Il file locale sarà analizzato dal Core.", french: "Le fichier local sera analysé par Core.", spanish: "Core analizará el archivo local.")
        default:
            return localizedString(theme.language, english: "Install Minecraft files and create a Vanilla configuration.", chinese: "安装 Minecraft 文件并创建原版配置。", italian: "Installa Minecraft e crea Vanilla.", french: "Installer Minecraft et créer Vanilla.", spanish: "Instalar Minecraft y crear Vanilla.")
        }
    }

    private var primaryActionTitle: String {
        if draft.source == "Import Modpack" {
            return draft.modpackSource == "Online"
                ? localizedString(theme.language, english: "Open Import", chinese: "打开导入", italian: "Apri import", french: "Ouvrir import", spanish: "Abrir importación")
                : localizedString(theme.language, english: "Create from Pack", chinese: "从整合包创建", italian: "Crea da pack", french: "Créer depuis pack", spanish: "Crear desde pack")
        }
        return localizedString(theme.language, english: "Create & Install", chinese: "创建并安装", italian: "Crea e installa", french: "Créer et installer", spanish: "Crear e instalar")
    }

    private var primaryActionIcon: String {
        draft.source == "Import Modpack" ? "arrow.down.app" : "checkmark.circle"
    }

    private var canMoveNext: Bool {
        switch step {
        case .source:
            return !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .version:
            if draft.source == "Mod Configuration" {
                return draft.loader != nil && draft.loaderVersion != nil && !selectedLoaderVersions.isEmpty
            }
            if draft.source == "Import Modpack", draft.modpackSource == "Local File" {
                return modpackPreflight?.valid == true
            }
            return true
        case .review:
            return canComplete
        }
    }

    private var canComplete: Bool {
        switch draft.source {
        case "Mod Configuration":
            return draft.loader != nil && draft.loaderVersion != nil
        case "Import Modpack":
            return draft.modpackSource == "Online" || modpackPreflight?.valid == true
        default:
            return true
        }
    }

    private func moveStep(_ delta: Int) {
        guard let index = InstanceCreationStep.allCases.firstIndex(of: step) else { return }
        let nextIndex = min(max(index + delta, 0), InstanceCreationStep.allCases.count - 1)
        step = InstanceCreationStep.allCases[nextIndex]
    }

    private func normalizeDraftForPurpose() {
        if draft.source == "Mod Configuration" {
            if draft.loader == nil {
                draft.loader = .fabric
            }
        } else {
            draft.loader = nil
            draft.loaderVersion = nil
        }

        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.name == "New Game Configuration" {
            draft.name = generatedName
            draft.gameDirectory = InstanceCreationDraft.defaultConfigurationDirectory(name: draft.name)
        }
    }

    private var modpackPreflightSummary: String {
        if isCheckingModpack {
            return localizedString(theme.language, english: "Core is checking the modpack...", chinese: "Core 正在检查整合包...", italian: "Core controlla il modpack...", french: "Core vérifie le modpack...", spanish: "Core revisa el modpack...")
        }
        if !modpackPreflightStatus.isEmpty {
            return modpackPreflightStatus
        }
        if let modpackPreflight {
            if modpackPreflight.valid {
                return localizedString(
                    theme.language,
                    english: "\(modpackPreflight.minecraftVersion ?? "Unknown") · \(modpackPreflight.loader ?? "Vanilla") · \(modpackPreflight.modCount) mods",
                    chinese: "\(modpackPreflight.minecraftVersion ?? "未知版本") · \(modpackPreflight.loader ?? "原版") · \(modpackPreflight.modCount) 个 Mod",
                    italian: "\(modpackPreflight.minecraftVersion ?? "Sconosciuta") · \(modpackPreflight.loader ?? "Vanilla") · \(modpackPreflight.modCount) mod",
                    french: "\(modpackPreflight.minecraftVersion ?? "Inconnue") · \(modpackPreflight.loader ?? "Vanilla") · \(modpackPreflight.modCount) mods",
                    spanish: "\(modpackPreflight.minecraftVersion ?? "Desconocida") · \(modpackPreflight.loader ?? "Vanilla") · \(modpackPreflight.modCount) mods"
                )
            }
            return modpackPreflight.blockingReasons.joined(separator: ", ")
        }
        return localizedString(theme.language, english: "Preflight required before creating a local modpack configuration.", chinese: "创建本地整合包配置前需要先预检。", italian: "Preflight richiesto.", french: "Précontrôle requis.", spanish: "Preflight requerido.")
    }

    private func runModpackPreflight() {
        let sourcePath = draft.modpackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourcePath.isEmpty else { return }
        isCheckingModpack = true
        modpackPreflightStatus = ""
        Task {
            do {
                let result = try await preflightModpack("local", sourcePath, draft.gameDirectory)
                await MainActor.run {
                    modpackPreflight = result
                    if result.valid {
                        if let name = result.name, shouldRegenerateName {
                            draft.name = name
                        }
                        if let version = result.minecraftVersion {
                            draft.minecraftVersion = version
                        }
                        draft.loader = result.loader.flatMap(LoaderKind.init(rawValue:))
                        draft.loaderVersion = result.loaderVersion
                        draft.gameDirectory = InstanceCreationDraft.defaultConfigurationDirectory(name: draft.name)
                    }
                    modpackPreflightStatus = result.valid ? "" : result.blockingReasons.joined(separator: ", ")
                    isCheckingModpack = false
                }
            } catch {
                await MainActor.run {
                    modpackPreflight = nil
                    modpackPreflightStatus = "Core modpack preflight failed: \(error.localizedDescription)"
                    isCheckingModpack = false
                }
            }
        }
    }

    @MainActor
    private func prepareModpackImportReview() {
        let sourcePath = draft.modpackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let modpackPreflight, !sourcePath.isEmpty else { return }
        pendingModpackImportReview =
            PendingModpackImportReview(
                plan: modpackPreflight.typedPlan,
                sourcePath: sourcePath,
                targetGameDir: draft.gameDirectory
            )
    }

    @MainActor
    private func confirmModpackImport(_ review: PendingModpackImportReview) {
        pendingModpackImportReview = nil
        isCheckingModpack = true
        modpackPreflightStatus = localizedString(theme.language, english: "Core is importing the modpack...", chinese: "Core 正在导入整合包...", italian: "Core importa il modpack...", french: "Core importe le modpack...", spanish: "Core importa el modpack...")
        Task {
            do {
                let response = try await importModpack("local", review.sourcePath, review.targetGameDir)
                await MainActor.run {
                    isCheckingModpack = false
                    if response.imported {
                        modpackPreflightStatus = localizedString(
                            theme.language,
                            english: "Imported. Rollback record: \(response.lockfilePath)",
                            chinese: "已导入。回滚记录：\(response.lockfilePath)",
                            italian: "Importato. Registro rollback: \(response.lockfilePath)",
                            french: "Importé. Journal de restauration : \(response.lockfilePath)",
                            spanish: "Importado. Registro de reversión: \(response.lockfilePath)"
                        )
                        create(draft)
                        dismiss()
                    } else {
                        modpackPreflight = CoreModpackPreflightResponse(
                            valid: false,
                            name: modpackPreflight?.name,
                            minecraftVersion: modpackPreflight?.minecraftVersion,
                            loader: modpackPreflight?.loader,
                            loaderVersion: modpackPreflight?.loaderVersion,
                            modCount: modpackPreflight?.modCount ?? 0,
                            resourcePackCount: modpackPreflight?.resourcePackCount ?? 0,
                            shaderPackCount: modpackPreflight?.shaderPackCount ?? 0,
                            overridesCount: modpackPreflight?.overridesCount ?? 0,
                            estimatedDownloadBytes: modpackPreflight?.estimatedDownloadBytes,
                            requiresApiKey: modpackPreflight?.requiresApiKey ?? false,
                            warnings: response.warnings,
                            blockingReasons: response.blockingReasons,
                            typedPlan: response.typedPlan
                        )
                        modpackPreflightStatus = response.blockingReasons.joined(separator: ", ")
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingModpack = false
                    modpackPreflightStatus = "Core modpack import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    @MainActor
    private func refreshLoaderOptions() async {
        guard draft.source == "Mod Configuration" else {
            loaderOptions = LoaderKind.allCases.map {
                LoaderCompatibilityOption(kind: $0, recommendedVersion: nil, versions: [], isAvailable: false, reason: nil)
            }
            loaderStatus = "Loader metadata not needed for this configuration."
            return
        }
        isLoadingLoaders = true
        do {
            let response = try await loadLoaderCompatibility(draft.minecraftVersion)
            loaderOptions = LoaderCompatibilityOption.options(from: response)
            let available = loaderOptions.filter(\.isAvailable)
            if let current = draft.loader, !available.contains(where: { $0.kind == current }) {
                draft.loader = available.first?.kind
            } else if draft.loader == nil {
                draft.loader = available.first(where: { $0.kind == .fabric })?.kind ?? available.first?.kind
            }
            if let option = selectedLoaderOption {
                draft.loaderVersion = option.recommendedVersion
            }
            loaderStatus = available.isEmpty
                ? "Core did not report any compatible Loader for \(draft.minecraftVersion)."
                : "Loaded \(available.count) compatible loader families from Core."
        } catch {
            loaderOptions = []
            draft.loader = nil
            draft.loaderVersion = nil
            loaderStatus = "Core loader compatibility failed: \(error.localizedDescription)"
        }
        isLoadingLoaders = false
    }
}

private struct InstanceWizardStepper: View {
    let step: InstanceCreationStep
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack(spacing: 8) {
            ForEach(InstanceCreationStep.allCases) { current in
                Capsule()
                    .fill(current == step ? theme.semanticSelectionColor : Color(nsColor: .separatorColor).opacity(0.45))
                    .frame(height: 6)
            }
        }
    }
}

private struct InstanceWizardReviewRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}
