import SwiftUI

struct MinecraftVersionBrowserPanel: View {
    @Binding var searchText: String
    @Binding var usageFilter: VersionUsageFilter
    @Binding var showReleaseVersions: Bool
    @Binding var showSnapshots: Bool
    @Binding var showHistorical: Bool
    let recommendedVersions: [MinecraftVersionInfo]
    let releaseVersions: [MinecraftVersionInfo]
    let snapshotVersions: [MinecraftVersionInfo]
    let historicalVersions: [MinecraftVersionInfo]
    let selectedVersion: MinecraftVersionInfo?
    let versionStatus: String
    let refresh: () -> Void
    let selectVersion: (MinecraftVersionInfo) -> Void
    let installSelected: (MinecraftVersionInfo) -> Void
    let repairSelected: (MinecraftVersionInfo) -> Void
    let cleanUnused: (MinecraftVersionInfo) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                HStack {
                    PanelHeader(title: AppText.versionSelector.localized(theme.language), systemImage: "clock.arrow.circlepath")
                    Spacer()
                    GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: refresh)
                }

                VersionBrowserHeader(
                    searchText: $searchText,
                    usageFilter: $usageFilter
                )

                VersionBrowserSection(
                    title: localizedString(theme.language, english: "Recommended", chinese: "推荐", italian: "Consigliate", french: "Recommandées", spanish: "Recomendadas"),
                    versions: recommendedVersions,
                    selectedVersionID: selectedVersion?.id,
                    select: selectVersion
                )

                FullWidthDisclosureGroup(isExpanded: $showReleaseVersions) {
                    VersionBrowserSection(
                        title: localizedString(theme.language, english: "Release", chinese: "正式版", italian: "Release", french: "Release", spanish: "Release"),
                        versions: releaseVersions,
                        selectedVersionID: selectedVersion?.id,
                        select: selectVersion
                    )
                    .padding(.top, 8)
                } label: {
                    Text("Release / Installed")
                        .font(.headline)
                }

                FullWidthDisclosureGroup(isExpanded: $showSnapshots) {
                    VersionBrowserSection(
                        title: localizedString(theme.language, english: "Snapshots", chinese: "快照版", italian: "Snapshot", french: "Snapshots", spanish: "Snapshots"),
                        versions: snapshotVersions,
                        selectedVersionID: selectedVersion?.id,
                        select: selectVersion
                    )
                    .padding(.top, 8)
                } label: {
                    Text("Snapshot")
                        .font(.headline)
                }

                FullWidthDisclosureGroup(isExpanded: $showHistorical) {
                    VersionBrowserSection(
                        title: localizedString(theme.language, english: "Historical", chinese: "历史版本", italian: "Storiche", french: "Historiques", spanish: "Históricas"),
                        versions: historicalVersions,
                        selectedVersionID: selectedVersion?.id,
                        select: selectVersion
                    )
                    .padding(.top, 8)
                } label: {
                    Text("Old Beta / Old Alpha")
                        .font(.headline)
                }

                if let selectedVersion {
                    VersionDetailPanel(
                        version: selectedVersion,
                        status: versionStatus,
                        install: {
                            installSelected(selectedVersion)
                        },
                        repair: {
                            repairSelected(selectedVersion)
                        },
                        cleanUnused: {
                            cleanUnused(selectedVersion)
                        }
                    )
                }
            }
        }
    }
}

struct LoaderPlanPanel: View {
    @Binding var selectedLoader: LoaderKind
    let compatibleLoaderKinds: [LoaderKind]
    let compatibilityMessage: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(title: AppText.loaderPlan.localized(theme.language), systemImage: "puzzlepiece.extension")

                if compatibleLoaderKinds.isEmpty {
                    MetadataLine(items: [localizedString(theme.language, english: "Vanilla only", chinese: "仅原版", italian: "Solo Vanilla", french: "Vanilla uniquement", spanish: "Solo Vanilla")])
                } else {
                    Picker(AppText.loader.localized(theme.language), selection: $selectedLoader) {
                        ForEach(compatibleLoaderKinds) { loader in
                            Text(loader.title).tag(loader)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(compatibilityMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}
