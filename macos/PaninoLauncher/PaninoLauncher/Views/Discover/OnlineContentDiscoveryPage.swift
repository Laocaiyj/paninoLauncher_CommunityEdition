import AppKit
import SwiftUI

struct OnlineContentDiscoveryPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let openSettings: () -> Void
    let openDownloadSettings: () -> Void
    let openTasks: () -> Void

    @EnvironmentObject var onlineContentStore: OnlineContentStore
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var versionStore: VersionContentStore
    @EnvironmentObject var taskCenterStore: TaskCenterStore
    @EnvironmentObject var launcherSettings: LauncherSettings
    @EnvironmentObject var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var searchText = ""
    @State var selectedSource: ContentSourceID = .modrinth
    @State var selectedType: OnlineProjectType = .mod
    @State var selectedLoader: LoaderFamily?
    @State var selectedSort: OnlineContentSort = .downloads
    @State var selectedReleaseID: String?
    @State var onlinePage = 0
    @State var useMinecraftVersionFilter = false
    @State var selectedContentMinecraftVersionID: String?
    @State var curseForgeAPIKey = ""
    @State var selectedSection: DiscoverSection = .minecraft
    @State var selectedCategory: String?
    @State var showingProjectDetail = false
    @State var targetResolution: CoreContentResolveTargetsResponse?
    @State var targetResolutionFailure: String?
    @State var selectedContentTargetID: String?
    @State var targetResolutionTask: Task<Void, Never>?
    @State var searchDebounceTask: Task<Void, Never>?
    @State var selectedMinecraftVersion: MinecraftVersionInfo?
    @State var minecraftSearchText = ""
    @State var minecraftBrowseGroup: MinecraftBrowseGroup = .recommended
    @State var minecraftPage = 0
    @State var minecraftInstallTarget: MinecraftInstallTarget = .newConfiguration
    @State var minecraftInstanceName = ""
    @State var selectedMinecraftLoader: LoaderKind?
    @State var selectedMinecraftLoaderVersion: String?
    @State var selectedShaderLoader: ShaderLoaderChoice = .none
    @State var selectedShaderLoaderVersion: String?
    @State var minecraftLoaderOptions: [LoaderCompatibilityOption] = LoaderKind.allCases.map {
        LoaderCompatibilityOption(kind: $0, recommendedVersion: nil, versions: [], isAvailable: false, reason: nil)
    }
    @State var minecraftShaderReleases: [OnlineRelease] = []
    @State var minecraftVersionOptionsStatus = ""
    @State var minecraftVersionOptionsTask: Task<Void, Never>?
    @State var confirmMinecraftInstall = false
    @State var minecraftInstallPreflight: CoreLoaderInstallPreflightResponse?
    @State var minecraftInstallPreflightStatus = ""
    @State var minecraftInstallPreflightTask: Task<Void, Never>?
    @State var minecraftInstallChoicePreflights: [String: CoreLoaderInstallPreflightResponse] = [:]
    @State var minecraftInstallChoicePreflightTask: Task<Void, Never>?
    @State var pendingContentInstallReview: PendingContentInstallReview?

    var projects: [OnlineProject] {
        onlineContentStore.searchResults[selectedSource]?.projects ?? []
    }

    var categoryOptions: [OnlineCategoryOption] {
        OnlineCategoryCatalog.options(for: selectedType, source: selectedSource)
    }

    var primaryCategoryOptions: [OnlineCategoryOption] {
        Array(categoryOptions.prefix(7))
    }

    var overflowCategoryOptions: [OnlineCategoryOption] {
        Array(categoryOptions.dropFirst(7))
    }

    var selectedCategoryOption: OnlineCategoryOption? {
        guard let selectedCategory else { return nil }
        return OnlineCategoryCatalog.option(id: selectedCategory, projectType: selectedType, source: selectedSource)
    }

    var selectedProject: OnlineProject? {
        guard onlineContentStore.selectedProject?.source == selectedSource else { return nil }
        return onlineContentStore.selectedProject
    }

    var selectedRelease: OnlineRelease? {
        guard let selectedContentMinecraftVersionID else { return nil }
        if let selectedReleaseID,
           let release = onlineContentStore.selectedReleases.first(where: { $0.id == selectedReleaseID && $0.gameVersions.contains(selectedContentMinecraftVersionID) }) {
            return release
        }
        return onlineContentStore.selectedReleases.first { $0.gameVersions.contains(selectedContentMinecraftVersionID) }
    }

    var canSearchSelectedSource: Bool {
        selectedSource != .curseForge || onlineContentStore.hasCurseForgeAPIKey()
    }

    var releaseMinecraftVersions: [MinecraftVersionInfo] {
        versionStore.versions.filter { $0.kind == .release }
    }

    var body: some View {
        contentReviewSheet
    }

    private var contentReviewSheet: some View {
        contentWithLifecycle
            .sheet(item: $pendingContentInstallReview) { review in
                InstallPlanReviewSheet(
                    plan: review.plan.typedPlan,
                    title: localizedString(theme.language, english: "Review install plan", chinese: "确认安装计划", italian: "Controlla piano installazione", french: "Vérifier le plan", spanish: "Revisar instalación"),
                    subtitle: "\(review.plan.projectTitle) · \(review.releaseVersionName)",
                    confirmTitle: localizedString(theme.language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar"),
                    repairTitle: contentReviewRepairTitle(for: review.plan.typedPlan),
                    onCancel: { pendingContentInstallReview = nil },
                    onRepair: { repairContentInstallReview(review) },
                    onConfirm: { beginReviewedContentInstall(review) }
                )
                .environmentObject(theme)
            }
    }

    private var contentWithLifecycle: some View {
        minecraftInstallChangeHandlers
            .onDisappear(perform: cancelTransientTasks)
    }

    private var minecraftInstallChangeHandlers: some View {
        minecraftBrowseChangeHandlers
            .onChange(of: selectedMinecraftLoader) { _, _ in
                handleMinecraftInstallSelectionChanged()
            }
            .onChange(of: selectedShaderLoader) { _, _ in
                handleMinecraftInstallSelectionChanged()
            }
            .onChange(of: selectedMinecraftLoaderVersion) { _, _ in
                handleMinecraftInstallInputChanged()
            }
            .onChange(of: selectedShaderLoaderVersion) { _, _ in
                handleMinecraftInstallInputChanged()
            }
            .onChange(of: minecraftInstanceName) { _, _ in
                handleMinecraftInstallInputChanged()
            }
    }

    private var minecraftBrowseChangeHandlers: some View {
        onlineContentChangeHandlers
            .onChange(of: selectedReleaseID) { _, _ in
                handleSelectedReleaseIDChanged()
            }
            .onChange(of: minecraftBrowseGroup) { _, _ in
                handleMinecraftBrowseGroupChanged()
            }
            .onChange(of: minecraftSearchText) { _, _ in
                handleMinecraftSearchTextChanged()
            }
    }

    private var onlineContentChangeHandlers: some View {
        discoveryPageContent
            .task {
                handleDiscoveryTask()
            }
            .onChange(of: selectedSection) { _, _ in
                handleSelectedSectionChanged()
            }
            .onChange(of: selectedSource) { _, _ in
                handleSelectedSourceChanged()
            }
            .onChange(of: selectedType) { _, _ in
                handleSelectedTypeChanged()
            }
            .onChange(of: selectedSort) { _, _ in
                handleSelectedSortChanged()
            }
            .onChange(of: selectedLoader) { _, _ in
                handleSelectedLoaderChanged()
            }
            .onChange(of: useMinecraftVersionFilter) { _, _ in
                handleUseMinecraftVersionFilterChanged()
            }
            .onChange(of: selectedContentMinecraftVersionID) { _, _ in
                handleSelectedContentMinecraftVersionChanged()
            }
            .onChange(of: searchText) { _, _ in
                debounceSearch()
            }
            .onChange(of: onlineContentStore.selectedReleases) { _, _ in
                handleSelectedReleasesChanged()
            }
    }

    @ViewBuilder
    private var discoveryPageContent: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            discoverSectionBar
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                if selectedSection == .minecraft {
                    minecraftContent
                } else {
                    resourcesContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    func handleDiscoveryTask() {
        configureCoreBackend()
        configureVersionCoreBackend()
        syncManagedKind()
        versionStore.refreshAssets(for: instanceStore.selectedInstance)
        if !versionStore.hasRemoteVersions {
            refreshMinecraftVersions()
        }
        if selectedSection != .minecraft, projects.isEmpty {
            search(clearExisting: false)
        }
    }

    func handleSelectedSectionChanged() {
        selectedMinecraftVersion = nil
        clearOnlineSelectionContext(clearCategory: true)
        if let projectType = selectedSection.projectType {
            selectedType = projectType
            syncManagedKind()
            refreshOnlineContent()
        } else {
            refreshMinecraftVersions()
        }
    }

    func handleSelectedSourceChanged() {
        selectedReleaseID = nil
        clearOnlineSelectionContext(clearCategory: true)
        onlinePage = 0
        if canSearchSelectedSource {
            refreshOnlineContent()
        } else {
            onlineContentStore.requireConfiguration(for: selectedSource)
        }
    }

    func handleSelectedTypeChanged() {
        clearOnlineSelectionContext(clearCategory: true)
        syncManagedKind()
        onlinePage = 0
        refreshOnlineContent()
    }

    func handleSelectedSortChanged() {
        clearOnlineSelectionContext(clearCategory: false)
        onlinePage = 0
        refreshOnlineContent()
    }

    func handleSelectedLoaderChanged() {
        clearOnlineSelectionContext(clearCategory: false)
        onlinePage = 0
        refreshOnlineContent()
    }

    func handleUseMinecraftVersionFilterChanged() {
        clearOnlineSelectionContext(clearCategory: false)
        onlinePage = 0
        guard !useMinecraftVersionFilter || selectedContentMinecraftVersionID != nil else { return }
        refreshOnlineContent()
    }

    func handleSelectedContentMinecraftVersionChanged() {
        clearOnlineSelectionContext(clearCategory: false)
        selectedReleaseID = recommendedReleaseID()
        onlinePage = 0
        guard useMinecraftVersionFilter else { return }
        refreshOnlineContent()
        resolveTargetsForSelection()
    }

    func handleSelectedReleasesChanged() {
        selectedReleaseID = recommendedReleaseID()
        resolveTargetsForSelection()
    }

    func handleSelectedReleaseIDChanged() {
        resolveTargetsForSelection()
    }

    func handleMinecraftBrowseGroupChanged() {
        minecraftPage = 0
    }

    func handleMinecraftSearchTextChanged() {
        minecraftPage = 0
    }

    func search(clearExisting: Bool = false, completion: ((Bool) -> Void)? = nil) {
        searchDebounceTask?.cancel()
        guard canSearchSelectedSource else {
            onlineContentStore.requireConfiguration(for: selectedSource)
            completion?(false)
            return
        }
        configureCoreBackend()
        syncManagedKind()
        onlineContentStore.search(searchQuery, sources: [selectedSource], clearExisting: clearExisting, completion: completion)
    }

    func refreshOnlineContent() {
        onlinePage = 0
        targetResolution = nil
        targetResolutionFailure = nil
        search(clearExisting: false)
    }

    func refreshOnlineContentApplyingNetworkSettings() {
        let proxyAddress = launcherSettings.proxyAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !proxyAddress.isEmpty else {
            refreshOnlineContent()
            return
        }

        onlinePage = 0
        targetResolution = nil
        targetResolutionFailure = nil
        SettingsStore.set(proxyAddress, forKey: "Settings.ProxyAddress")
        Task { @MainActor in
            await viewModel.shutdownCore()
            await viewModel.startCoreIfNeeded()
            search(clearExisting: false)
        }
    }

    func debounceSearch() {
        guard selectedSection != .minecraft else { return }
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                onlinePage = 0
                clearOnlineSelectionContext(clearCategory: false)
                search(clearExisting: false)
            }
        }
    }

    func goToOnlinePage(_ nextPage: Int) {
        let targetPage = max(nextPage, 0)
        guard targetPage != onlinePage else { return }
        let previousPage = onlinePage
        onlinePage = targetPage
        targetResolution = nil
        targetResolutionFailure = nil
        selectedContentTargetID = nil
        search(clearExisting: false) { success in
            if !success {
                onlinePage = previousPage
            }
        }
    }

    func selectCategory(_ categoryID: String?) {
        guard selectedCategory != categoryID else { return }
        selectedCategory = categoryID
        onlinePage = 0
        clearOnlineSelectionContext(clearCategory: false)
        if categoryID != nil && selectedSort == .downloads {
            selectedSort = .relevance
        } else {
            refreshOnlineContent()
        }
    }

    func relaxMinecraftVersionFilter() {
        useMinecraftVersionFilter = false
        selectedContentMinecraftVersionID = nil
    }

    func clearOnlineSelectionContext(clearCategory: Bool) {
        if clearCategory {
            selectedCategory = nil
        }
        selectedReleaseID = nil
        showingProjectDetail = false
        targetResolution = nil
        targetResolutionFailure = nil
        selectedContentTargetID = nil
        onlineContentStore.clearSelection()
    }

    func copySearchDebugSummary() {
        let summary = searchQuery.diagnosticSummary(source: selectedSource)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    func configureCoreBackend() {
        onlineContentStore.configure(
            coreBackend: OnlineContentCoreBackend(
                search: { query, source, apiKey in
                    try await viewModel.searchContent(query, source: source, curseForgeAPIKey: apiKey)
                },
                project: { projectID, source, query, apiKey in
                    try await viewModel.contentProject(id: projectID, source: source, query: query, curseForgeAPIKey: apiKey)
                },
                minecraftVersions: {
                    try await viewModel.minecraftVersions()
                },
                minecraftPackage: { version in
                    try await viewModel.minecraftPackage(for: version)
                },
                loaderMetadata: { minecraftVersion in
                    try await viewModel.loaderMetadata(for: minecraftVersion)
                }
            )
        )
    }

    func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: VersionContentCoreBackend(
                minecraftVersions: {
                    try await viewModel.minecraftVersions()
                },
                minecraftInstallStatus: { versionIds, gameDirs in
                    try await viewModel.minecraftInstallStatus(versionIds: versionIds, gameDirs: gameDirs)
                },
                installedMinecraftInstances: { versionIds, gameDirs in
                    try await viewModel.installedMinecraftInstances(versionIds: versionIds, gameDirs: gameDirs)
                },
                minecraftPackage: { version in
                    try await viewModel.minecraftPackage(for: version)
                },
                localResources: { gameDir, kind, loader in
                    try await viewModel.localResources(gameDir: gameDir, kind: kind, loader: loader)
                },
                toggleLocalResource: { path in
                    try await viewModel.toggleLocalResource(path: path)
                },
                deleteLocalResource: { path in
                    try await viewModel.deleteLocalResource(path: path)
                },
                importLocalResource: { sourcePath, gameDir, kind in
                    try await viewModel.importLocalResource(sourcePath: sourcePath, gameDir: gameDir, kind: kind)
                },
                cleanMinecraftVersion: { version, gameDir in
                    try await viewModel.cleanMinecraftVersion(version: version, gameDir: gameDir)
                },
                mutateMinecraftVersionStorage: { version, gameDir, action in
                    try await viewModel.mutateMinecraftVersionStorage(version: version, gameDir: gameDir, action: action)
                }
            )
        )
    }

    func refreshMinecraftVersions() {
        configureVersionCoreBackend()
        versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
    }

    func openMinecraftInstallDetail(_ version: MinecraftVersionInfo) {
        selectedMinecraftVersion = version
        selectedMinecraftLoader = nil
        selectedMinecraftLoaderVersion = nil
        selectedShaderLoader = .none
        selectedShaderLoaderVersion = nil
        minecraftShaderReleases = []
        minecraftVersionOptionsStatus = ""
        minecraftInstallTarget = .newConfiguration
        minecraftInstanceName = ""
        minecraftInstallChoicePreflights = [:]
        refreshMinecraftInstallVersionChoices()
        handleMinecraftInstallInputChanged()
    }

    func handleMinecraftInstallSelectionChanged() {
        refreshMinecraftInstallVersionChoices()
        handleMinecraftInstallInputChanged()
    }

    func handleMinecraftInstallInputChanged() {
        debounceMinecraftInstallPreflight()
        debounceMinecraftInstallChoicePreflights()
    }

    func cancelTransientTasks() {
        searchDebounceTask?.cancel()
        targetResolutionTask?.cancel()
        minecraftInstallPreflightTask?.cancel()
        minecraftInstallChoicePreflightTask?.cancel()
        minecraftVersionOptionsTask?.cancel()
    }

    func installSelectedMinecraftVersion() {
        guard let version = selectedMinecraftVersion else { return }
        minecraftInstallTarget = .newConfiguration
        let trimmedName = minecraftInstanceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            minecraftInstallPreflightStatus = localizedString(
                theme.language,
                english: "Enter a unique local instance name before installing.",
                chinese: "安装前请手动输入一个唯一的本地实例名称。",
                italian: "Inserisci un nome istanza locale univoco prima di installare.",
                french: "Saisissez un nom d'instance locale unique avant l'installation.",
                spanish: "Introduce un nombre de instancia local único antes de instalar."
            )
            return
        }
        let targetGameDir = minecraftInstallGameDirectory(for: version)
        guard let targetGameDir else {
            minecraftInstallPreflightStatus = localizedString(
                theme.language,
                english: "The local instance name does not produce a valid target folder.",
                chinese: "当前本地实例名称无法生成有效目标目录。",
                italian: "Il nome istanza non produce una cartella valida.",
                french: "Le nom d'instance ne produit pas de dossier valide.",
                spanish: "El nombre de instancia no genera una carpeta válida."
            )
            return
        }
        guard !minecraftInstallTargetDirectoryConflictExists(URL(fileURLWithPath: targetGameDir, isDirectory: true)) else {
            minecraftInstallPreflightStatus = localizedString(
                theme.language,
                english: "This target folder already exists. Rename the local instance before installing.",
                chinese: "目标目录已存在。请先重命名本地实例再安装。",
                italian: "La cartella esiste già. Rinomina l'istanza prima di installare.",
                french: "Le dossier existe déjà. Renommez l'instance avant l'installation.",
                spanish: "La carpeta ya existe. Cambia el nombre antes de instalar."
            )
            return
        }
        let requestedShader = selectedShaderLoader == .none ? nil : selectedShaderLoader.rawValue
        guard minecraftShaderLoaderCompatible(loader: selectedMinecraftLoader?.rawValue, shaderLoader: requestedShader) else {
            minecraftInstallPreflightStatus = localizedString(
                theme.language,
                english: "\(selectedShaderLoader.title) cannot be installed with \(selectedMinecraftLoader?.title ?? "Vanilla").",
                chinese: "\(selectedShaderLoader.title) 不能与 \(selectedMinecraftLoader?.title ?? "Vanilla") 一起安装。",
                italian: "\(selectedShaderLoader.title) non puo essere installato con \(selectedMinecraftLoader?.title ?? "Vanilla").",
                french: "\(selectedShaderLoader.title) ne peut pas etre installe avec \(selectedMinecraftLoader?.title ?? "Vanilla").",
                spanish: "\(selectedShaderLoader.title) no se puede instalar con \(selectedMinecraftLoader?.title ?? "Vanilla")."
            )
            return
        }
        if let preflight = minecraftInstallPreflight, preflight.isBlocked {
            minecraftInstallPreflightStatus = preflight.displaySummary
            return
        }

        viewModel.version = version.id

        viewModel.install(
            gameDir: targetGameDir,
            loader: selectedMinecraftLoader,
            loaderVersion: selectedMinecraftLoaderVersion,
            shaderLoader: automaticMinecraftInstallShaderLoader(),
            shaderVersion: automaticMinecraftInstallShaderVersion(),
            instanceName: trimmedName
        )
        openTasks()
    }

    func exportMinecraftInstallDiagnostics() {
        diagnosticsStore.exportDiagnosticPackage(
            logs: viewModel.logs,
            tasks: taskCenterStore.records,
            coreState: viewModel.coreState,
            javaStatus: viewModel.javaStatus,
            managedJavaRuntimes: viewModel.managedJavaRuntimes,
            javaRuntimeResolution: viewModel.javaRuntimeResolution
        )
        openTasks()
    }

    func openMinecraftInstallDirectory() {
        guard let version = selectedMinecraftVersion,
              let path = minecraftInstallGameDirectory(for: version) else {
            FinderIntegration.openDownloadCache()
            return
        }
        let targetURL = URL(fileURLWithPath: path, isDirectory: true)
        if FileManager.default.fileExists(atPath: targetURL.path) {
            NSWorkspace.shared.open(targetURL)
        } else {
            NSWorkspace.shared.open(targetURL.deletingLastPathComponent())
        }
    }

    func downloadMinecraftInstallJava(_ majorVersion: Int) {
        viewModel.installManagedJavaRuntime(featureVersion: majorVersion)
        openTasks()
    }

    func refreshMinecraftInstallVersionChoices() {
        minecraftVersionOptionsTask?.cancel()
        guard let version = selectedMinecraftVersion else {
            minecraftLoaderOptions = LoaderKind.allCases.map {
                LoaderCompatibilityOption(kind: $0, recommendedVersion: nil, versions: [], isAvailable: false, reason: nil)
            }
            minecraftShaderReleases = []
            selectedMinecraftLoaderVersion = nil
            selectedShaderLoaderVersion = nil
            minecraftVersionOptionsStatus = ""
            return
        }
        let selectedLoader = selectedMinecraftLoader
        let selectedShader = selectedShaderLoader
        minecraftVersionOptionsStatus = localizedString(theme.language, english: "Loading versions...", chinese: "正在加载版本...", italian: "Caricamento versioni...", french: "Chargement versions...", spanish: "Cargando versiones...")
        minecraftVersionOptionsTask = Task {
            do {
                async let loaderMetadata = viewModel.loaderMetadata(for: version.id)
                let shaderReleases = try await minecraftInstallShaderReleases(for: version, loader: selectedLoader, shader: selectedShader)
                let loaderOptions = LoaderCompatibilityOption.options(from: try await loaderMetadata)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftLoaderOptions = loaderOptions
                    minecraftShaderReleases = shaderReleases
                    selectedMinecraftLoaderVersion = resolvedMinecraftLoaderVersion(loader: selectedLoader, options: loaderOptions)
                    selectedShaderLoaderVersion = resolvedMinecraftShaderVersion(shader: selectedShader, releases: shaderReleases)
                    minecraftVersionOptionsStatus = ""
                    handleMinecraftInstallInputChanged()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftShaderReleases = []
                    selectedShaderLoaderVersion = nil
                    minecraftVersionOptionsStatus = localizedString(
                        theme.language,
                        english: "Version lookup failed",
                        chinese: "版本查询失败",
                        italian: "Ricerca versioni fallita",
                        french: "Recherche versions échouée",
                        spanish: "Error al buscar versiones"
                    )
                    handleMinecraftInstallInputChanged()
                }
            }
        }
    }

    func minecraftInstallShaderReleases(for version: MinecraftVersionInfo, loader: LoaderKind?, shader: ShaderLoaderChoice) async throws -> [OnlineRelease] {
        guard let projectID = minecraftInstallShaderProjectID(shader) else { return [] }
        let candidateLoaders = minecraftInstallShaderLoaderCandidates(loader: loader, shader: shader)
        for candidate in candidateLoaders {
            let response = try await viewModel.contentProject(
                id: projectID,
                source: .modrinth,
                query: OnlineSearchQuery(
                    projectTypes: [.mod],
                    gameVersion: version.id,
                    loaders: [candidate],
                    sort: .newest,
                    limit: 50
                ),
                curseForgeAPIKey: nil
            )
            let releases = sortedMinecraftShaderReleases(
                response.releases.filter { release in
                    release.gameVersions.contains(version.id) && release.loaders.contains(candidate)
                }
            )
            if !releases.isEmpty {
                return releases
            }
        }
        return []
    }

    func minecraftInstallShaderProjectID(_ shader: ShaderLoaderChoice) -> String? {
        switch shader {
        case .iris:
            return "iris"
        case .oculus:
            return "oculus"
        case .none, .optiFine:
            return nil
        }
    }

    func minecraftInstallShaderLoaderCandidates(loader: LoaderKind?, shader: ShaderLoaderChoice) -> [LoaderFamily] {
        switch (shader, loader) {
        case (.iris, .quilt):
            return [.quilt, .fabric]
        case (.iris, .fabric):
            return [.fabric]
        case (.oculus, .neoForge):
            return [.neoForge, .forge]
        case (.oculus, .forge):
            return [.forge]
        default:
            return []
        }
    }

    func sortedMinecraftShaderReleases(_ releases: [OnlineRelease]) -> [OnlineRelease] {
        releases.sorted { lhs, rhs in
            let leftRank = minecraftShaderReleaseRank(lhs)
            let rightRank = minecraftShaderReleaseRank(rhs)
            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.isRecommended != rhs.isRecommended { return lhs.isRecommended }
            if lhs.publishedAt != rhs.publishedAt {
                return (lhs.publishedAt ?? .distantPast) > (rhs.publishedAt ?? .distantPast)
            }
            return lhs.versionNumber.localizedStandardCompare(rhs.versionNumber) == .orderedDescending
        }
    }

    func minecraftShaderReleaseRank(_ release: OnlineRelease) -> Int {
        switch release.releaseType {
        case .release:
            return 0
        case .beta:
            return 1
        case .alpha:
            return 2
        case .snapshot:
            return 3
        case .unknown:
            return 4
        }
    }

    func resolvedMinecraftLoaderVersion(loader: LoaderKind?, options: [LoaderCompatibilityOption]) -> String? {
        guard let loader else { return nil }
        let option = options.first { $0.kind == loader }
        if let current = selectedMinecraftLoaderVersion,
           option?.versions.contains(where: { $0.loaderVersion == current }) == true {
            return current
        }
        return option?.versions.first(where: \.stable)?.loaderVersion
    }

    func resolvedMinecraftShaderVersion(shader: ShaderLoaderChoice, releases: [OnlineRelease]) -> String? {
        guard shader == .iris || shader == .oculus else { return nil }
        if let current = selectedShaderLoaderVersion,
           releases.contains(where: { $0.id == current }) {
            return current
        }
        return releases.first(where: { $0.releaseType == .release })?.id
    }

    func debounceMinecraftInstallPreflight() {
        minecraftInstallPreflightTask?.cancel()
        guard let version = selectedMinecraftVersion else {
            minecraftInstallPreflight = nil
            minecraftInstallPreflightStatus = ""
            return
        }
        let targetGameDir: String? = nil
        let loader = selectedMinecraftLoader?.rawValue
        let shader = minecraftShaderLoaderForPreflight(loader: loader, shaderLoader: selectedShaderLoader == .none ? nil : selectedShaderLoader.rawValue)
        let name = minecraftInstallDisplayName(for: version)
        minecraftInstallPreflightStatus = localizedString(theme.language, english: "Checking install compatibility...", chinese: "正在检查安装兼容性...", italian: "Controllo compatibilità...", french: "Vérification compatibilité...", spanish: "Comprobando compatibilidad...")
        minecraftInstallPreflightTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let result = try await viewModel.installPreflight(
                    CoreLoaderInstallPreflightRequest(
                        version: version.id,
                        gameDir: targetGameDir,
                        loader: loader,
                        loaderVersion: selectedMinecraftLoaderVersion,
                        shaderLoader: shader,
                        shaderVersion: automaticMinecraftInstallShaderVersion(),
                        instanceName: name
                    )
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftInstallPreflight = result
                    minecraftInstallPreflightStatus = ""
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    minecraftInstallPreflight = nil
                    minecraftInstallPreflightStatus = localizedString(
                        theme.language,
                        english: "Preflight failed: \(error.localizedDescription)",
                        chinese: "预检失败：\(error.localizedDescription)",
                        italian: "Preflight fallito: \(error.localizedDescription)",
                        french: "Précontrôle échoué : \(error.localizedDescription)",
                        spanish: "Preflight falló: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    func debounceMinecraftInstallChoicePreflights() {
        minecraftInstallChoicePreflightTask?.cancel()
        guard let version = selectedMinecraftVersion else {
            minecraftInstallChoicePreflights = [:]
            return
        }
        let targetGameDir: String? = nil
        let selectedLoader = selectedMinecraftLoader?.rawValue
        let selectedShader = selectedShaderLoader == .none ? nil : selectedShaderLoader.rawValue
        let name = minecraftInstallDisplayName(for: version)
        let loaderCandidates: [String?] = [nil] + LoaderKind.allCases.map { Optional($0.rawValue) }
        let shaderCandidates: [String?] = [nil] + ShaderLoaderChoice.allCases
            .filter { $0 != .none }
            .map { Optional($0.rawValue) }
        var requests: [(key: String, loader: String?, shader: String?)] = []
        for loaderCandidate in loaderCandidates {
            let shaderForCandidate = minecraftShaderLoaderForPreflight(loader: loaderCandidate, shaderLoader: selectedShader)
            requests.append((
                key: minecraftInstallChoiceKey(loader: loaderCandidate, shaderLoader: shaderForCandidate),
                loader: loaderCandidate,
                shader: shaderForCandidate
            ))
        }
        for shaderCandidate in shaderCandidates {
            requests.append((
                key: minecraftInstallChoiceKey(loader: selectedLoader, shaderLoader: shaderCandidate),
                loader: selectedLoader,
                shader: shaderCandidate
            ))
        }
        let uniqueRequests = requests.reduce(into: [(key: String, loader: String?, shader: String?)]()) { result, request in
            if !result.contains(where: { $0.key == request.key }) {
                result.append(request)
            }
        }
        minecraftInstallChoicePreflightTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            var results: [String: CoreLoaderInstallPreflightResponse] = [:]
            for request in uniqueRequests {
                guard !Task.isCancelled else { return }
                do {
                    let result = try await viewModel.inspectInstallPreflight(
                        CoreLoaderInstallPreflightRequest(
                            version: version.id,
                            gameDir: targetGameDir,
                            loader: request.loader,
                            loaderVersion: request.loader == selectedLoader ? selectedMinecraftLoaderVersion : nil,
                            shaderLoader: request.shader,
                            shaderVersion: request.shader == selectedShader ? automaticMinecraftInstallShaderVersion() : nil,
                            instanceName: name
                        )
                    )
                    results[request.key] = result
                } catch {
                    continue
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                minecraftInstallChoicePreflights = results
            }
        }
    }

    func minecraftInstallGameDirectory(for version: MinecraftVersionInfo) -> String? {
        switch minecraftInstallTarget {
        case .newConfiguration:
            return manualGameConfigurationDirectory().map(\.path)
        case .existingConfiguration:
            return instanceStore.selectedInstance?.gameDirectory
        case .downloadOnly:
            return downloadOnlyDirectory(for: version).path
        }
    }

    func manualGameConfigurationDirectory() -> URL? {
        let trimmedName = minecraftInstanceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let root = gameConfigurationsRoot()
        return root.appendingPathComponent(slug(trimmedName), isDirectory: true)
    }

    func downloadOnlyDirectory(for version: MinecraftVersionInfo) -> URL {
        let base = (try? LauncherPaths.appSupportDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher", isDirectory: true)
        return base
            .appendingPathComponent("DownloadCache", isDirectory: true)
            .appendingPathComponent("MinecraftVersionFiles", isDirectory: true)
            .appendingPathComponent(slug(version.id), isDirectory: true)
    }

    func gameConfigurationsRoot() -> URL {
        (try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true)
    }

    func slug(_ value: String) -> String {
        var result = ""
        for scalar in value.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        return trimmed.isEmpty ? "minecraft" : trimmed
    }

    func minecraftInstallDisplayName(for _: MinecraftVersionInfo) -> String {
        minecraftInstanceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func automaticMinecraftInstallShaderLoader() -> String? {
        switch selectedShaderLoader {
        case .none, .optiFine:
            return nil
        case .iris, .oculus:
            return minecraftShaderLoaderForPreflight(loader: selectedMinecraftLoader?.rawValue, shaderLoader: selectedShaderLoader.rawValue)
        }
    }

    func automaticMinecraftInstallShaderVersion() -> String? {
        switch selectedShaderLoader {
        case .none, .optiFine:
            return nil
        case .iris, .oculus:
            return selectedShaderLoaderVersion
        }
    }

    func switchSource() {
        selectedSource = selectedSource == .modrinth ? .curseForge : .modrinth
    }

    func syncManagedKind() {
        guard let kind = selectedType.managedAssetKind else { return }
        versionStore.selectedAssetKind = kind
        versionStore.refreshAssets(for: instanceStore.selectedInstance)
    }

    func recommendedReleaseID() -> String? {
        guard let selectedContentMinecraftVersionID else { return nil }
        return onlineContentStore.selectedReleases.first { $0.gameVersions.contains(selectedContentMinecraftVersionID) }?.id
    }

    func resolveTargetsForSelection() {
        targetResolutionTask?.cancel()
        targetResolution = nil
        targetResolutionFailure = nil
        selectedContentTargetID = nil

        guard let selectedProject,
              let selectedRelease,
              let managedKind = selectedProject.projectType.managedAssetKind else { return }

        let request = CoreContentResolveTargetsRequest(
            projectType: selectedProject.projectType.rawValue,
            projectTitle: selectedProject.title,
            releaseId: selectedRelease.id,
            targetSubdir: managedKind.folderName,
            gameVersions: selectedRelease.gameVersions,
            loaders: selectedRelease.loaders.map(\.rawValue),
            instances: instanceStore.instances
                .filter { !$0.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { instance in
                    CoreContentTargetInstance(
                        instanceId: instance.id.uuidString,
                        name: instance.name,
                        gameDir: instance.gameDirectory,
                        minecraftVersion: instance.contentMinecraftVersion,
                        loader: instance.loader?.rawValue
                    )
                }
        )

        targetResolutionTask = Task {
            do {
                let response = try await viewModel.resolveContentTargets(request)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    targetResolution = response
                    targetResolutionFailure = nil
                    selectedContentTargetID = preferredContentTargetID(in: response, release: selectedRelease)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    targetResolution = nil
                    targetResolutionFailure = error.localizedDescription
                    selectedContentTargetID = nil
                }
            }
        }
    }

    func installSelectedRelease(target selectedTarget: CoreContentTargetCandidate? = nil) {
        guard let selectedProject,
              let selectedRelease,
              let managedKind = selectedProject.projectType.managedAssetKind else { return }
        let resolvedTarget = selectedTarget ?? selectedContentTarget(release: selectedRelease)

        if let resolvedTarget,
           let request = coreInstallRequest(
            project: selectedProject,
            release: selectedRelease,
            managedKind: managedKind,
            gameDirectory: resolvedTarget.gameDir
           ) {
            presentContentInstallReview(request: request, release: selectedRelease, managedKind: managedKind)
            return
        }

        let panel = NSOpenPanel()
        panel.title = localizedString(theme.language, english: "Choose target game instance folder", chinese: "确认安装到哪个游戏实例文件夹", italian: "Scegli la cartella dell'istanza", french: "Choisir le dossier de l'instance", spanish: "Elige la carpeta de la instancia")
        panel.message = resolvedTarget == nil
            ? localizedString(theme.language, english: "Choose an isolated game instance folder compatible with the selected Minecraft version.", chinese: "请选择一个与当前 Minecraft 版本兼容的独立游戏实例文件夹。", italian: "Scegli una cartella istanza compatibile con la versione Minecraft selezionata.", french: "Choisissez un dossier d'instance compatible avec la version Minecraft choisie.", spanish: "Elige una carpeta de instancia compatible con la versión de Minecraft seleccionada.")
            : localizedString(theme.language, english: "Panino matched a local instance. Confirm it here, or choose another isolated instance folder.", chinese: "Panino 已匹配本地实例。请在这里确认，或选择另一个独立实例文件夹。", italian: "Panino ha trovato un'istanza locale. Confermala o scegline un'altra.", french: "Panino a trouvé une instance locale. Confirmez-la ou choisissez-en une autre.", spanish: "Panino encontró una instancia local. Confírmala o elige otra.")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if let resolvedTarget {
            panel.directoryURL = URL(fileURLWithPath: resolvedTarget.gameDir, isDirectory: true)
        } else if let selected = instanceStore.selectedInstance {
            panel.directoryURL = URL(fileURLWithPath: selected.gameDirectory, isDirectory: true)
        }

        guard panel.runModal() == .OK,
              let targetURL = panel.url,
              let request = coreInstallRequest(
                project: selectedProject,
                release: selectedRelease,
                managedKind: managedKind,
                gameDirectory: targetURL.path
              ) else { return }

        presentContentInstallReview(request: request, release: selectedRelease, managedKind: managedKind)
    }

    func presentContentInstallReview(request: CoreContentInstallRequest, release: OnlineRelease, managedKind: ManagedAssetKind) {
        Task {
            do {
                let plan = try await viewModel.contentInstallPlan(request)
                await MainActor.run {
                    pendingContentInstallReview =
                        PendingContentInstallReview(
                            plan: plan,
                            releaseVersionName: release.versionName,
                            request: request,
                            managedKind: managedKind
                        )
                }
            } catch {
                await MainActor.run {
                    targetResolutionFailure = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    func beginReviewedContentInstall(_ review: PendingContentInstallReview) {
        pendingContentInstallReview = nil
        versionStore.selectedAssetKind = review.managedKind
        if let targetInstance = instanceStore.instances.first(where: { sameFilePath($0.gameDirectory, review.request.gameDir) }) {
            instanceStore.selectedInstanceID = targetInstance.id
        }
        Task {
            do {
                _ = try await viewModel.installContentAccepted(review.request)
                await MainActor.run {
                    targetResolutionFailure = nil
                }
            } catch {
                await MainActor.run {
                    targetResolutionFailure = error.localizedDescription
                }
            }
        }
    }

    func contentReviewRepairTitle(for plan: CoreTypedInstallPlan) -> String? {
        guard plan.status == "blocked" || !plan.blockedReasons.isEmpty else { return nil }
        if plan.blockedReasons.contains(where: { $0.localizedCaseInsensitiveContains("curseforge") || $0.localizedCaseInsensitiveContains("api_key") }) {
            return localizedString(theme.language, english: "Open Settings", chinese: "打开设置", italian: "Apri impostazioni", french: "Ouvrir les réglages", spanish: "Abrir ajustes")
        }
        return localizedString(theme.language, english: "Choose Target", chinese: "重新选择目标", italian: "Scegli destinazione", french: "Choisir la cible", spanish: "Elegir destino")
    }

    @MainActor
    func repairContentInstallReview(_ review: PendingContentInstallReview) {
        pendingContentInstallReview = nil
        if review.plan.typedPlan.blockedReasons.contains(where: { $0.localizedCaseInsensitiveContains("curseforge") || $0.localizedCaseInsensitiveContains("api_key") }) {
            openSettings()
        } else {
            installSelectedRelease()
        }
    }

    func isContentTargetVersionMatched(_ target: CoreContentTargetCandidate, release: OnlineRelease) -> Bool {
        let hasVersionMismatch = target.blockedReasons.contains { reason in
            reason.localizedCaseInsensitiveContains("minecraft_version_mismatch")
        }
        guard !hasVersionMismatch else { return false }
        return release.gameVersions.isEmpty || release.gameVersions.contains(target.minecraftVersion)
    }

    func selectedContentTarget(release: OnlineRelease) -> CoreContentTargetCandidate? {
        guard let selectedContentTargetID else { return nil }
        return targetResolution?.candidates.first {
            $0.id == selectedContentTargetID && isContentTargetVersionMatched($0, release: release)
        }
    }

    func preferredContentTargetID(in response: CoreContentResolveTargetsResponse, release: OnlineRelease) -> String? {
        if let selectedContentTargetID,
           response.candidates.contains(where: { $0.id == selectedContentTargetID && isContentTargetVersionMatched($0, release: release) }) {
            return selectedContentTargetID
        }
        if let recommended = response.recommended,
           isContentTargetVersionMatched(recommended, release: release) {
            return recommended.id
        }
        return response.candidates.first { isContentTargetVersionMatched($0, release: release) }?.id
    }

    func coreInstallRequest(
        project: OnlineProject,
        release: OnlineRelease,
        managedKind: ManagedAssetKind,
        gameDirectory: String
    ) -> CoreContentInstallRequest? {
        guard let sourceFile = release.files.first(where: \.isPrimary) ?? release.files.first,
              let sourceURL = sourceFile.downloadURL,
              !gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let hashes = Dictionary(uniqueKeysWithValues: sourceFile.hashes.map { ($0.key.lowercased(), $0.value) })
        let file = CoreContentInstallFile(
            fileName: safeFileName(sourceFile.fileName),
            url: sourceURL,
            sha1: hashes["sha1"],
            size: sourceFile.sizeBytes,
            primary: sourceFile.isPrimary
        )
        let dependencies = release.dependencies.map { dependency in
            CoreContentInstallDependency(
                projectId: dependency.projectID,
                versionId: dependency.versionID,
                source: dependency.source.rawValue,
                name: dependency.projectID ?? dependency.versionID ?? dependency.id,
                required: dependency.relation == .required,
                installed: nil,
                sha1: nil
            )
        }

        return CoreContentInstallRequest(
            source: project.source.rawValue,
            projectId: project.id,
            projectTitle: project.title,
            projectType: project.projectType.rawValue,
            releaseId: release.id,
            gameDir: gameDirectory,
            targetSubdir: managedKind.folderName,
            files: [file],
            dependencies: dependencies,
            gameVersions: release.gameVersions,
            loaders: release.loaders.map(\.rawValue),
            instances: instanceStore.instances
                .filter { !$0.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { instance in
                    CoreContentTargetInstance(
                        instanceId: instance.id.uuidString,
                        name: instance.name,
                        gameDir: instance.gameDirectory,
                        minecraftVersion: instance.contentMinecraftVersion,
                        loader: instance.loader?.rawValue
                    )
                },
            concurrency: launcherSettings.downloadConcurrency,
            retryCount: launcherSettings.downloadRetryCount,
            download: CoreDownloadRuntimeOptions(
                concurrency: launcherSettings.downloadConcurrency,
                retryCount: launcherSettings.downloadRetryCount
            )
        )
    }

    func sameFilePath(_ lhs: String, _ rhs: String) -> Bool {
        URL(fileURLWithPath: lhs).standardizedFileURL.path == URL(fileURLWithPath: rhs).standardizedFileURL.path
    }
}
