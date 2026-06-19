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
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
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
}
