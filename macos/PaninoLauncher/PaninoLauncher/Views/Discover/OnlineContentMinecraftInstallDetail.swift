import AppKit
import SwiftUI

struct MinecraftVersionInstallDetailPage: View {
    let version: MinecraftVersionInfo
    let instances: [GameInstance]
    let selectedInstance: GameInstance?
    @Binding var target: MinecraftInstallTarget
    @Binding var instanceName: String
    @Binding var loader: LoaderKind?
    @Binding var loaderVersion: String?
    @Binding var shaderLoader: ShaderLoaderChoice
    @Binding var shaderLoaderVersion: String?
    let loaderOptions: [LoaderCompatibilityOption]
    let shaderReleases: [OnlineRelease]
    let versionOptionsStatus: String
    @Binding var confirmInstall: Bool
    let preflight: CoreLoaderInstallPreflightResponse?
    let preflightStatus: String
    let choicePreflights: [String: CoreLoaderInstallPreflightResponse]
    let lastInstallFailure: TaskSnapshot?
    let back: () -> Void
    let install: () -> Void
    let openTasks: () -> Void
    let exportDiagnostics: () -> Void
    let openInstanceDirectory: () -> Void
    let downloadJava: (Int) -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var showingInstallPlanReview = false
    private let versionMenuLimit = 80

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            GlassPanel(surfaceLevel: .elevatedPanel) {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    HStack(spacing: 10) {
                        GlassButton(systemImage: "chevron.left", title: localizedString(theme.language, english: "Back", chinese: "返回", italian: "Indietro", french: "Retour", spanish: "Atrás"), action: back)
                        PanelHeader(
                            title: localizedString(theme.language, english: "Install Minecraft \(version.id)", chinese: "安装 Minecraft \(version.id)", italian: "Installa Minecraft \(version.id)", french: "Installer Minecraft \(version.id)", spanish: "Instalar Minecraft \(version.id)"),
                            systemImage: "arrow.down.circle"
                        )
                        Spacer()
                        MetadataLine(items: [version.kind.title(language: theme.language)], font: .caption.weight(.semibold))
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                        installMetric(localizedString(theme.language, english: "Released", chinese: "发布时间", italian: "Rilascio", french: "Sortie", spanish: "Publicado"), version.releasedAt)
                        installMetric("Java", version.javaRequirement)
                        installMetric(localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"), discoverVisibleDownloadState(version, language: theme.language) ?? "-")
                        installMetric(localizedString(theme.language, english: "Verify", chinese: "校验", italian: "Verifica", french: "Vérifier", spanish: "Verificar"), version.verificationState.localizedVersionState(theme.language))
                    }
                }
            }

            GlassPanel(surfaceLevel: .panel) {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    PanelHeader(title: localizedString(theme.language, english: "Loader", chinese: "加载器", italian: "Loader", french: "Loader", spanish: "Loader"), systemImage: "puzzlepiece.extension")
                    HStack(spacing: 8) {
                        loaderButton(title: "Vanilla", isSelected: loader == nil, disabled: false, state: loaderChoiceState(nil)) {
                            selectLoader(nil)
                        }
                        ForEach(LoaderKind.allCases) { kind in
                            loaderButton(title: kind.title, isSelected: loader == kind, disabled: !compatibleLoaders.contains(kind), state: loaderChoiceState(kind)) {
                                selectLoader(kind)
                            }
                        }
                    }
                    loaderVersionPicker

                    Text(loaderInstallNotice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            GlassPanel(surfaceLevel: .panel) {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    PanelHeader(title: localizedString(theme.language, english: "Shader Loader", chinese: "光影加载器", italian: "Shader loader", french: "Loader de shaders", spanish: "Loader de shaders"), systemImage: "sparkles.rectangle.stack")
                    HStack(spacing: 8) {
                        ForEach(ShaderLoaderChoice.allCases) { choice in
                            loaderButton(title: choice.title, isSelected: shaderLoader == choice, disabled: shaderChoiceDisabled(choice), state: shaderChoiceState(choice)) {
                                shaderLoaderVersion = nil
                                shaderLoader = choice
                            }
                        }
                    }
                    shaderVersionPicker
                    Text(shaderHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            GlassPanel(surfaceLevel: .panel) {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    PanelHeader(title: localizedString(theme.language, english: "Local Instance", chinese: "本地实例", italian: "Istanza locale", french: "Instance locale", spanish: "Instancia local"), systemImage: "folder.badge.plus")
                    PaninoTextInput(
                        localizedString(theme.language, english: "Instance name", chinese: "实例名称", italian: "Nome istanza", french: "Nom de l'instance", spanish: "Nombre de instancia"),
                        text: $instanceName
                    )
                    Text(localizedString(
                        theme.language,
                        english: "Folder: \(targetDirectoryLabel)",
                        chinese: "目录：\(targetDirectoryLabel)",
                        italian: "Cartella: \(targetDirectoryLabel)",
                        french: "Dossier : \(targetDirectoryLabel)",
                        spanish: "Carpeta: \(targetDirectoryLabel)"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
            }

            GlassPanel(surfaceLevel: .floatingChrome) {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    PanelHeader(title: localizedString(theme.language, english: "Install Plan", chinese: "安装计划", italian: "Piano installazione", french: "Plan d'installation", spanish: "Plan de instalación"), systemImage: "checklist")
                    SettingsRow(title: localizedString(theme.language, english: "Result", chinese: "结果", italian: "Risultato", french: "Résultat", spanish: "Resultado"), systemImage: "square.stack.3d.up") {
                        Text(targetSummary)
                            .lineLimit(2)
                    }
                    SettingsRow(title: localizedString(theme.language, english: "Components", chinese: "组件", italian: "Componenti", french: "Composants", spanish: "Componentes"), systemImage: "shippingbox") {
                        Text(effectiveComponentSummary)
                            .lineLimit(2)
                    }
                    SettingsRow(title: "Java Runtime", systemImage: "cup.and.saucer") {
                        Text(javaRuntimePlanSummary)
                            .lineLimit(2)
                    }
                    if let javaRuntime = preflight?.javaRuntime {
                        SettingsRow(title: localizedString(theme.language, english: "Java Preflight", chinese: "Java 预检", italian: "Preflight Java", french: "Précontrôle Java", spanish: "Preflight Java"), systemImage: "terminal") {
                            HStack(spacing: 8) {
                                Text(javaRuntime.conciseStatus)
                                    .lineLimit(1)
                                if javaRuntime.isDownloadable {
                                    GlassButton(systemImage: "arrow.down.circle", title: localizedString(theme.language, english: "Download Java \(javaRuntime.requiredMajorVersion)", chinese: "下载 Java \(javaRuntime.requiredMajorVersion)", italian: "Scarica Java \(javaRuntime.requiredMajorVersion)", french: "Télécharger Java \(javaRuntime.requiredMajorVersion)", spanish: "Descargar Java \(javaRuntime.requiredMajorVersion)")) {
                                        downloadJava(javaRuntime.requiredMajorVersion)
                                    }
                                }
                            }
                        }
                    }
                    if let shaderFallbackSummary {
                        SettingsRow(title: localizedString(theme.language, english: "Shader Fallback", chinese: "光影回退", italian: "Fallback shader", french: "Repli shader", spanish: "Fallback shader"), systemImage: "arrow.triangle.branch") {
                            Text(shaderFallbackSummary)
                                .lineLimit(2)
                        }
                    }
                    if let installerProbeSummary {
                        SettingsRow(title: localizedString(theme.language, english: "Installer Probe", chinese: "安装器探测", italian: "Probe installer", french: "Sonde installateur", spanish: "Probe instalador"), systemImage: "antenna.radiowaves.left.and.right") {
                            Text(installerProbeSummary)
                                .lineLimit(2)
                        }
                    }
                    if let blockReason {
                        Label(blockReason, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    installPreflightSummary
                    installFailureBanner
                    HStack {
                        if preflight != nil {
                            GlassButton(systemImage: "list.bullet.rectangle", title: localizedString(theme.language, english: "Review Plan", chinese: "查看计划", italian: "Rivedi piano", french: "Voir le plan", spanish: "Revisar plan")) {
                                showingInstallPlanReview = true
                            }
                        }
                        Spacer()
                        GlassButton(systemImage: "arrow.down.circle", title: installButtonTitle, prominent: true) {
                            confirmInstall = true
                        }
                        .disabled(blockReason != nil)
                    }
                }
            }
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Confirm install?", chinese: "确认安装？", italian: "Confermare installazione?", french: "Confirmer l'installation ?", spanish: "¿Confirmar instalación?"),
            isPresented: $confirmInstall,
            titleVisibility: .visible
        ) {
            Button(installButtonTitle) {
                install()
            }
            .disabled(blockReason != nil)
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        } message: {
            Text("\(version.id) · \(effectiveComponentSummary) · \(targetSummary)")
        }
        .sheet(isPresented: $showingInstallPlanReview) {
            if let preflight {
                InstallPlanReviewSheet(
                    plan: preflight.typedPlan,
                    title: localizedString(theme.language, english: "Review install plan", chinese: "确认安装计划", italian: "Controlla piano installazione", french: "Vérifier le plan", spanish: "Revisar instalación"),
                    subtitle: "\(version.id) · \(effectiveComponentSummary)",
                    confirmTitle: installButtonTitle,
                    onCancel: { showingInstallPlanReview = false },
                    onConfirm: {
                        showingInstallPlanReview = false
                        confirmInstall = true
                    }
                )
                .environmentObject(theme)
            }
        }
    }

    private var compatibleLoaders: [LoaderKind] {
        version.kind == .oldAlpha || version.kind == .oldBeta ? [] : LoaderKind.allCases
    }

    private func selectLoader(_ candidate: LoaderKind?) {
        loaderVersion = nil
        shaderLoaderVersion = nil
        loader = candidate
        if !minecraftShaderLoaderCompatible(loader: candidate?.rawValue, shaderLoader: shaderLoader == .none ? nil : shaderLoader.rawValue) {
            shaderLoader = .none
        }
    }

    @ViewBuilder
    private var loaderVersionPicker: some View {
        if loader != nil {
            SettingsRow(title: localizedString(theme.language, english: "Loader Version", chinese: "加载器版本", italian: "Versione loader", french: "Version du loader", spanish: "Versión del loader"), systemImage: "number") {
                versionMenu(
                    title: selectedLoaderVersionTitle,
                    isEmpty: selectedLoaderVersions.isEmpty,
                    emptyTitle: versionOptionsStatus.isEmpty ? localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando") : versionOptionsStatus
                ) {
                    ForEach(visibleSelectedLoaderVersions) { metadata in
                        Button(loaderVersionTitle(metadata)) {
                            loaderVersion = metadata.loaderVersion
                        }
                    }
                    if hiddenSelectedLoaderVersionCount > 0 {
                        Divider()
                        Text(localizedString(theme.language, english: "Showing first \(versionMenuLimit) versions", chinese: "已显示前 \(versionMenuLimit) 个版本", italian: "Mostrate prime \(versionMenuLimit) versioni", french: "Affiche les \(versionMenuLimit) premieres versions", spanish: "Mostrando primeras \(versionMenuLimit) versiones"))
                    }
                }
                .disabled(selectedLoaderVersions.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var shaderVersionPicker: some View {
        if shaderLoader == .iris || shaderLoader == .oculus {
            SettingsRow(title: localizedString(theme.language, english: "Shader Loader Version", chinese: "光影加载器版本", italian: "Versione shader loader", french: "Version du loader shader", spanish: "Versión del loader de shaders"), systemImage: "sparkles") {
                versionMenu(
                    title: selectedShaderReleaseTitle,
                    isEmpty: shaderReleases.isEmpty,
                    emptyTitle: versionOptionsStatus.isEmpty ? localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando") : versionOptionsStatus
                ) {
                    ForEach(visibleShaderReleases) { release in
                        Button(shaderReleaseTitle(release)) {
                            shaderLoaderVersion = release.id
                        }
                    }
                    if hiddenShaderReleaseCount > 0 {
                        Divider()
                        Text(localizedString(theme.language, english: "Showing first \(versionMenuLimit) releases", chinese: "已显示前 \(versionMenuLimit) 个 release", italian: "Mostrate prime \(versionMenuLimit) release", french: "Affiche les \(versionMenuLimit) premieres releases", spanish: "Mostrando primeras \(versionMenuLimit) releases"))
                    }
                }
                .disabled(shaderReleases.isEmpty)
            }
        }
    }

    private func versionMenu<Content: View>(title: String, isEmpty: Bool, emptyTitle: String, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            if isEmpty {
                Text(emptyTitle)
            } else {
                content()
            }
        } label: {
            HStack(spacing: 6) {
                Text(isEmpty ? emptyTitle : title)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 260, alignment: .trailing)
        }
        .menuStyle(.borderlessButton)
    }

    private var selectedLoaderOption: LoaderCompatibilityOption? {
        guard let loader else { return nil }
        return loaderOptions.first { $0.kind == loader }
    }

    private var selectedLoaderVersions: [LoaderMetadata] {
        selectedLoaderOption?.versions ?? []
    }

    private var visibleSelectedLoaderVersions: [LoaderMetadata] {
        Array(selectedLoaderVersions.prefix(versionMenuLimit))
    }

    private var hiddenSelectedLoaderVersionCount: Int {
        max(selectedLoaderVersions.count - visibleSelectedLoaderVersions.count, 0)
    }

    private var selectedLoaderVersionTitle: String {
        if let selected = selectedLoaderVersions.first(where: { $0.loaderVersion == loaderVersion }) {
            return loaderVersionTitle(selected)
        }
        if let loaderVersion {
            return loaderVersion
        }
        return selectedLoaderOption?.recommendedVersion ?? "-"
    }

    private func loaderVersionTitle(_ metadata: LoaderMetadata) -> String {
        metadata.stable ? metadata.loaderVersion : "\(metadata.loaderVersion) · Beta"
    }

    private var selectedShaderReleaseTitle: String {
        if let selected = shaderReleases.first(where: { $0.id == shaderLoaderVersion }) {
            return shaderReleaseTitle(selected)
        }
        return shaderReleases.first.map(shaderReleaseTitle) ?? "-"
    }

    private var visibleShaderReleases: [OnlineRelease] {
        Array(shaderReleases.prefix(versionMenuLimit))
    }

    private var hiddenShaderReleaseCount: Int {
        max(shaderReleases.count - visibleShaderReleases.count, 0)
    }

    private func shaderReleaseTitle(_ release: OnlineRelease) -> String {
        let versionText = release.versionNumber.isEmpty ? release.versionName : release.versionNumber
        return release.releaseType == .release ? versionText : "\(versionText) · \(release.releaseType.rawValue.capitalized)"
    }

    private var shaderFallbackSummary: String? {
        guard
            let from = preflight?.shaderFallbackFrom,
            let to = preflight?.shaderFallbackTo
        else {
            return nil
        }
        return localizedString(
            theme.language,
            english: "Using compatible \(to) release because \(from) has no direct shader loader release.",
            chinese: "由于 \(from) 没有直接适配的光影加载器版本，将使用兼容的 \(to) release。",
            italian: "Uso release \(to) compatibile perché \(from) non ha una release diretta.",
            french: "Utilise la release \(to) compatible car \(from) n'a pas de release directe.",
            spanish: "Usando release compatible \(to) porque \(from) no tiene release directa."
        )
    }

    private var installerProbeSummary: String? {
        guard let status = preflight?.installerProbeStatus, !status.isEmpty else {
            return nil
        }
        if status.hasPrefix("failed:") {
            return localizedString(
                theme.language,
                english: "Preflight could not fully probe the installer URL; install will still attempt the real download.",
                chinese: "预检未能完整探测安装器 URL；安装时仍会尝试真实下载。",
                italian: "Il preflight non ha verificato completamente l'URL installer; l'installazione tenterà comunque il download.",
                french: "Le précontrôle n'a pas entièrement testé l'URL de l'installateur ; l'installation tentera le téléchargement.",
                spanish: "La prevalidación no pudo verificar completamente la URL; la instalación intentará la descarga real."
            )
        }
        return status
    }

    private var blockReason: String? {
        let trimmedName = instanceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return localizedString(theme.language, english: "Name this local instance before installing.", chinese: "安装前请为这个本地实例命名。", italian: "Assegna un nome all'istanza prima di installare.", french: "Nommez cette instance locale avant l'installation.", spanish: "Pon nombre a esta instancia local antes de instalar.")
        }
        if instances.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            return localizedString(theme.language, english: "An instance with this name already exists. Rename this one to keep data isolated.", chinese: "已有同名实例。请重命名，确保各实例数据隔离。", italian: "Esiste già un'istanza con questo nome.", french: "Une instance porte déjà ce nom.", spanish: "Ya existe una instancia con este nombre.")
        }
        if targetDirectoryConflictExists {
            return localizedString(theme.language, english: "This instance folder already exists. Choose another name or restore it from the local list.", chinese: "该实例目录已存在。请换一个名称，或从本地列表恢复它。", italian: "La cartella dell'istanza esiste già.", french: "Ce dossier d'instance existe déjà.", spanish: "Esta carpeta de instancia ya existe.")
        }
        if let loader, !compatibleLoaders.contains(loader) {
            return localizedString(theme.language, english: "\(loader.title) is not available for this version.", chinese: "\(loader.title) 不适用于该版本。", italian: "\(loader.title) non disponibile.", french: "\(loader.title) indisponible.", spanish: "\(loader.title) no disponible.")
        }
        if loader != nil, loaderVersion == nil {
            return localizedString(
                theme.language,
                english: "Choose an exact loader version before installing. Beta versions are never selected automatically.",
                chinese: "安装前请选择具体加载器版本。Beta 版本不会自动选择。",
                italian: "Scegli una versione precisa del loader prima di installare.",
                french: "Choisissez une version exacte du loader avant l'installation.",
                spanish: "Elige una version exacta del loader antes de instalar."
            )
        }
        if !selectedShaderLoaderIsCompatible {
            return localizedString(
                theme.language,
                english: "\(shaderLoader.title) cannot be installed with \(loader?.title ?? "Vanilla"). Choose a compatible shader loader or switch it to None.",
                chinese: "\(shaderLoader.title) 不能与 \(loader?.title ?? "Vanilla") 一起安装。请选择兼容的光影加载器，或切换为 None。",
                italian: "\(shaderLoader.title) non puo essere installato con \(loader?.title ?? "Vanilla").",
                french: "\(shaderLoader.title) ne peut pas etre installe avec \(loader?.title ?? "Vanilla").",
                spanish: "\(shaderLoader.title) no se puede instalar con \(loader?.title ?? "Vanilla")."
            )
        }
        if effectiveShaderLoader != nil, shaderLoaderVersion == nil {
            return localizedString(
                theme.language,
                english: "Choose an exact shader loader release before installing. Beta releases are never selected automatically.",
                chinese: "安装前请选择具体光影加载器版本。Beta 版本不会自动选择。",
                italian: "Scegli una release precisa del loader shader prima di installare.",
                french: "Choisissez une release exacte du loader de shaders avant l'installation.",
                spanish: "Elige una version exacta del loader de shaders antes de instalar."
            )
        }
        if let preflight, preflight.isBlocked {
            return localizedString(
                theme.language,
                english: preflight.displaySummary,
                chinese: preflight.displaySummary,
                italian: preflight.displaySummary,
                french: preflight.displaySummary,
                spanish: preflight.displaySummary
            )
        }
        return nil
    }

    @ViewBuilder
    private var installPreflightSummary: some View {
        if let preflight {
            Label(preflight.displaySummary, systemImage: preflightSummaryIcon(preflight))
                .font(.caption)
                .foregroundStyle(preflightSummaryColor(preflight))
                .lineLimit(2)
        } else if !preflightStatus.isEmpty {
            Label(preflightStatus, systemImage: "waveform.path.ecg")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var installFailureBanner: some View {
        if let failure = lastInstallFailure,
           failure.state == .failed,
           failure.kind.lowercased().contains("install") {
            VStack(alignment: .leading, spacing: 6) {
                Label(localizedString(theme.language, english: "Install failed", chinese: "安装失败", italian: "Installazione fallita", french: "Installation échouée", spanish: "Instalación fallida"), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout.weight(.semibold))
                Text(failure.diagnostic?.userSummary ?? failure.message ?? failure.errorCode ?? failure.version)
                    .font(.caption)
                    .lineLimit(2)
                if let diagnostic = failure.diagnostic {
                    Text(diagnostic.actionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorCode = failure.errorCode {
                    Text(errorCode)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                if let detail = failure.errorDetail {
                    DisclosureGroup(localizedString(theme.language, english: "Details", chinese: "详情", italian: "Dettagli", french: "Détails", spanish: "Detalles")) {
                        Text(detail)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption)
                }
                HStack(spacing: 8) {
                    GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Retry", chinese: "重试", italian: "Riprova", french: "Réessayer", spanish: "Reintentar"), action: install)
                    GlassButton(systemImage: "list.bullet.rectangle", title: localizedString(theme.language, english: "Tasks", chinese: "任务", italian: "Attività", french: "Tâches", spanish: "Tareas"), action: openTasks)
                    GlassButton(systemImage: "square.and.arrow.up", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter diagnostics", spanish: "Exportar diagnóstico"), action: exportDiagnostics)
                    GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开目录", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta"), action: openInstanceDirectory)
                }
                .font(.caption)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .paninoGlassCard(isSelected: true, level: .popover, cornerRadius: 8, tint: .orange, showsShadow: true)
        }
    }

    private var targetSummary: String {
        switch target {
        case .newConfiguration:
            let name = instanceDisplayName.isEmpty ? localizedString(theme.language, english: "manual name required", chinese: "需要手动命名", italian: "nome richiesto", french: "nom requis", spanish: "nombre requerido") : instanceDisplayName
            return localizedString(theme.language, english: "Create local instance \"\(name)\". Core verifies files before it appears in the local list.", chinese: "创建本地实例“\(name)”。Core 校验磁盘文件后会显示在本地列表。", italian: "Crea istanza locale \"\(name)\".", french: "Créer l'instance locale \"\(name)\".", spanish: "Crear instancia local \"\(name)\".")
        case .existingConfiguration:
            return localizedString(theme.language, english: "Existing-instance installs are disabled. Install a new local instance instead.", chinese: "已禁用覆盖当前实例安装。请安装为新的本地实例。", italian: "Installazione su istanza esistente disabilitata.", french: "Installation sur instance existante désactivée.", spanish: "Instalación sobre instancia existente desactivada.")
        case .downloadOnly:
            return localizedString(theme.language, english: "Download-only installs are disabled here. Installed files become a local instance.", chinese: "此处不再提供仅下载模式。安装后的文件会成为本地实例。", italian: "Solo download disabilitato.", french: "Téléchargement seul désactivé.", spanish: "Solo descarga desactivada.")
        }
    }

    private var componentSummary: String {
        [
            loader?.title ?? localizedString(theme.language, english: "Vanilla"),
            shaderLoader == .none ? nil : shaderLoader.title
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var effectiveComponentSummary: String {
        [
            loader?.title ?? localizedString(theme.language, english: "Vanilla"),
            effectiveShaderLoader?.title
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var selectedShaderLoaderRawValue: String? {
        shaderLoader == .none ? nil : shaderLoader.rawValue
    }

    private var selectedShaderLoaderIsCompatible: Bool {
        minecraftShaderLoaderCompatible(loader: loader?.rawValue, shaderLoader: selectedShaderLoaderRawValue)
    }

    private var effectiveShaderLoader: ShaderLoaderChoice? {
        selectedShaderLoaderIsCompatible && shaderLoader != .none ? shaderLoader : nil
    }

    private var javaRuntimePlanSummary: String {
        localizedString(
            theme.language,
            english: "\(version.javaRequirement) · Panino resolves from the Minecraft manifest and downloads the runtime inside the launcher when missing.",
            chinese: "\(version.javaRequirement) · Panino 会按 Minecraft 清单解析，缺失时在启动器内下载。",
            italian: "\(version.javaRequirement) · Panino risolve dal manifest Minecraft e scarica il runtime se manca.",
            french: "\(version.javaRequirement) · Panino résout depuis le manifeste Minecraft et télécharge le runtime si nécessaire.",
            spanish: "\(version.javaRequirement) · Panino resuelve desde el manifiesto de Minecraft y descarga el runtime si falta."
        )
    }

    private var shaderHelpText: String {
        localizedString(
            theme.language,
            english: "Core installs Iris and Oculus as matching Modrinth mods. OptiFine requires a manual download if the upstream download is unavailable.",
            chinese: "Core 会将 Iris 和 Oculus 作为匹配的 Modrinth Mod 安装；若上游没有可用公开下载，OptiFine 需要手动安装。",
            italian: "Core installa Iris e Oculus da Modrinth. OptiFine può richiedere installazione manuale.",
            french: "Core installe Iris et Oculus depuis Modrinth. OptiFine peut nécessiter une installation manuelle.",
            spanish: "Core instala Iris y Oculus desde Modrinth. OptiFine puede requerir instalación manual."
        )
    }

    private var loaderInstallNotice: String {
        localizedString(
            theme.language,
            english: "Core creates an isolated launch profile for the selected loader and records local instance metadata after installation.",
            chinese: "Core 会为所选 Loader 创建隔离的可启动 profile，并在安装后写入本地实例元数据。",
            italian: "Core crea un profilo isolato per il loader selezionato e salva i metadati locali.",
            french: "Core crée un profil isolé pour le loader choisi et enregistre les métadonnées locales.",
            spanish: "Core crea un perfil aislado para el loader seleccionado y guarda los metadatos locales."
        )
    }

    private var installButtonTitle: String {
        switch target {
        case .newConfiguration:
            return localizedString(theme.language, english: "Install Local Instance", chinese: "安装本地实例", italian: "Installa istanza", french: "Installer l'instance", spanish: "Instalar instancia")
        case .existingConfiguration:
            return localizedString(theme.language, english: "Apply and Install", chinese: "应用并安装", italian: "Applica e installa", french: "Appliquer et installer", spanish: "Aplicar e instalar")
        case .downloadOnly:
            return localizedString(theme.language, english: "Download Files", chinese: "下载文件", italian: "Scarica file", french: "Télécharger fichiers", spanish: "Descargar archivos")
        }
    }

    private var instanceDisplayName: String {
        instanceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var targetDirectoryName: String {
        instanceDisplayName.isEmpty ? "" : slug(instanceDisplayName)
    }

    private var targetDirectoryLabel: String {
        targetDirectoryName.isEmpty
            ? localizedString(theme.language, english: "enter a name first", chinese: "请先输入名称", italian: "inserisci prima un nome", french: "saisissez d'abord un nom", spanish: "introduce primero un nombre")
            : "minecraft/versions/\(targetDirectoryName)"
    }

    private var targetDirectoryPath: String {
        targetDirectoryURL.path
    }

    private var targetDirectoryURL: URL {
        let root = (try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true)
        return root.appendingPathComponent(targetDirectoryName, isDirectory: true)
    }

    private var targetDirectoryConflictExists: Bool {
        guard target == .newConfiguration else { return false }
        guard !targetDirectoryName.isEmpty else { return false }
        return minecraftInstallTargetDirectoryConflictExists(targetDirectoryURL)
    }

    @ViewBuilder
    private func installMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
    }

    private func loaderButton(title: String, isSelected: Bool, disabled: Bool, state: InstallChoicePreflightState = .normal, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .lineLimit(1)
                if let image = state.systemImage {
                    Image(systemName: image)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : state.tint)
                }
            }
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .frame(minHeight: PaninoTokens.Layout.controlMinSize)
            .background(isSelected ? theme.semanticSelectionColor.opacity(0.92) : Color(nsColor: .controlBackgroundColor).opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func loaderChoiceState(_ candidate: LoaderKind?) -> InstallChoicePreflightState {
        let shader = minecraftShaderLoaderForPreflight(loader: candidate?.rawValue, shaderLoader: shaderLoader == .none ? nil : shaderLoader.rawValue)
        let result = choicePreflights[minecraftInstallChoiceKey(loader: candidate?.rawValue, shaderLoader: shader)]
        return installChoiceState(from: result, fallback: candidate == loader ? preflight : nil)
    }

    private func shaderChoiceState(_ choice: ShaderLoaderChoice) -> InstallChoicePreflightState {
        if shaderChoiceDisabled(choice) {
            return .blocked
        }
        let shader = choice == .none ? nil : choice.rawValue
        let result = choicePreflights[minecraftInstallChoiceKey(loader: loader?.rawValue, shaderLoader: shader)]
        return installChoiceState(from: result, fallback: choice == shaderLoader ? preflight : nil)
    }

    private func shaderChoiceDisabled(_ choice: ShaderLoaderChoice) -> Bool {
        choice != .none && !minecraftShaderLoaderCompatible(loader: loader?.rawValue, shaderLoader: choice.rawValue)
    }

    private func installChoiceState(from result: CoreLoaderInstallPreflightResponse?, fallback: CoreLoaderInstallPreflightResponse?) -> InstallChoicePreflightState {
        let resolved = result ?? fallback
        if let resolved, hasChoiceCompatibilityBlocker(resolved) {
            return .blocked
        }
        if resolved?.isBlocked == true || resolved?.status == "warning" || resolved?.warnings.isEmpty == false {
            return .warning
        }
        return .normal
    }

    private func hasChoiceCompatibilityBlocker(_ preflight: CoreLoaderInstallPreflightResponse) -> Bool {
        preflight.blockedReasons.contains { reason in
            let normalized = reason.lowercased()
            return normalized.hasPrefix("loader_version_not_found")
                || normalized.hasPrefix("loader_profile_not_found")
                || normalized.hasPrefix("loader_profile_url_not_found")
                || normalized.hasPrefix("loader_installer_not_found")
                || normalized.hasPrefix("forge_installer_url_not_found")
                || normalized.hasPrefix("neoforge_installer_url_not_found")
                || normalized.hasPrefix("shader_loader_incompatible")
                || normalized.hasPrefix("shader_release_not_found")
                || normalized.hasPrefix("shader_dependency_unresolved")
        }
    }

    private func preflightSummaryIcon(_ preflight: CoreLoaderInstallPreflightResponse) -> String {
        if preflight.isBlocked {
            return "xmark.octagon"
        }
        if preflight.status == "warning" || !preflight.warnings.isEmpty {
            return "exclamationmark.triangle"
        }
        return "checkmark.seal"
    }

    private func preflightSummaryColor(_ preflight: CoreLoaderInstallPreflightResponse) -> Color {
        if preflight.isBlocked || preflight.status == "warning" || !preflight.warnings.isEmpty {
            return .orange
        }
        return .secondary
    }

    private func slug(_ value: String) -> String {
        var result = ""
        for scalar in value.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        return trimmed.isEmpty ? "minecraft-instance" : trimmed
    }
}

func discoverVisibleDownloadState(_ version: MinecraftVersionInfo, language: AppLanguage) -> String? {
    version.downloadState == "Available" ? nil : version.downloadState.localizedVersionState(language)
}

func minecraftInstallChoiceKey(loader: String?, shaderLoader: String?) -> String {
    "\(normalizedMinecraftInstallChoice(loader ?? "vanilla"))|\(normalizedMinecraftInstallChoice(shaderLoader ?? "none"))"
}

func normalizedMinecraftInstallChoice(_ value: String) -> String {
    value.lowercased()
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: "_", with: "")
}

func minecraftShaderLoaderCompatible(loader: String?, shaderLoader: String?) -> Bool {
    guard let shaderLoader else {
        return true
    }
    let normalizedShader = normalizedMinecraftInstallChoice(shaderLoader)
    let normalizedLoader = normalizedMinecraftInstallChoice(loader ?? "vanilla")
    switch normalizedShader {
    case "iris":
        return normalizedLoader == "fabric" || normalizedLoader == "quilt"
    case "oculus":
        return normalizedLoader == "forge" || normalizedLoader == "neoforge"
    case "optifine":
        return true
    default:
        return true
    }
}

func minecraftShaderLoaderForPreflight(loader: String?, shaderLoader: String?) -> String? {
    guard minecraftShaderLoaderCompatible(loader: loader, shaderLoader: shaderLoader) else {
        return nil
    }
    return shaderLoader
}

func minecraftInstallTargetDirectoryConflictExists(_ url: URL) -> Bool {
    var isDirectory = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
        return false
    }
    guard isDirectory.boolValue else { return true }
    return !minecraftInstallDirectoryCanBeReused(url)
}

func minecraftInstallDirectoryCanBeReused(_ url: URL) -> Bool {
    guard let entries = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return false
    }
    guard !entries.isEmpty else { return true }
    guard entries.count == 1, entries[0].lastPathComponent == "downloads" else {
        return false
    }
    return minecraftInstallDownloadsDirectoryCanBeReused(entries[0])
}

func minecraftInstallDownloadsDirectoryCanBeReused(_ url: URL) -> Bool {
    guard let entries = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return false
    }
    let reusableFiles: Set<String> = [
        "install-preflight.json",
        "install-rollback.json",
        "install-state.json",
        "loader-install.log",
        "shader-install.log"
    ]
    let reusableDirectories: Set<String> = [
        "rollback-backups"
    ]
    return entries.allSatisfy { entry in
        let name = entry.lastPathComponent
        if reusableFiles.contains(name) {
            return true
        }
        let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return isDirectory && reusableDirectories.contains(name)
    }
}

enum MinecraftBrowseGroup: String, CaseIterable, Identifiable {
    case recommended
    case release
    case snapshot
    case historical

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .recommended:
            return localizedString(language, english: "Recommended", chinese: "推荐", italian: "Consigliate", french: "Recommandées", spanish: "Recomendadas")
        case .release:
            return localizedString(language, english: "Release", chinese: "正式版", italian: "Release", french: "Release", spanish: "Release")
        case .snapshot:
            return localizedString(language, english: "Snapshot", chinese: "快照版", italian: "Snapshot", french: "Snapshot", spanish: "Snapshot")
        case .historical:
            return localizedString(language, english: "Historical", chinese: "历史版本", italian: "Storiche", french: "Historiques", spanish: "Históricas")
        }
    }
}

enum MinecraftInstallTarget: String, CaseIterable, Identifiable {
    case newConfiguration
    case existingConfiguration
    case downloadOnly

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .newConfiguration:
            return localizedString(language, english: "Create Local Instance After Install", chinese: "安装后生成本地实例", italian: "Crea istanza dopo installazione", french: "Créer l'instance après installation", spanish: "Crear instancia tras instalar")
        case .existingConfiguration:
            return localizedString(language, english: "Selected Configuration", chinese: "当前游戏配置", italian: "Configurazione selezionata", french: "Configuration sélectionnée", spanish: "Configuración seleccionada")
        case .downloadOnly:
            return localizedString(language, english: "Download Version Files Only", chinese: "仅下载版本文件", italian: "Solo file versione", french: "Télécharger fichiers seulement", spanish: "Solo descargar archivos")
        }
    }
}

enum ShaderLoaderChoice: String, CaseIterable, Identifiable {
    case none
    case iris
    case optiFine
    case oculus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .iris:
            return "Iris"
        case .optiFine:
            return "OptiFine"
        case .oculus:
            return "Oculus"
        }
    }
}

enum InstallChoicePreflightState: Equatable {
    case normal
    case warning
    case blocked

    var systemImage: String? {
        switch self {
        case .normal:
            return nil
        case .warning:
            return "exclamationmark.triangle"
        case .blocked:
            return "xmark.octagon"
        }
    }

    var tint: Color {
        switch self {
        case .normal:
            return .secondary
        case .warning:
            return .orange
        case .blocked:
            return .red
        }
    }
}
