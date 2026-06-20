import SwiftUI

struct InstanceVersionManagementPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let openResources: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var theme: ThemeSettings
    @State private var focusedVersionID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let focusedVersion {
                InstanceVersionConfigurationPage(
                    viewModel: viewModel,
                    instance: $instance,
                    version: focusedVersion,
                    openResources: openResources,
                    openDiscover: openDiscover,
                    onBack: { focusedVersionID = nil }
                )
            } else {
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            PanelHeader(
                                title: localizedString(theme.language, english: "Installed Versions", chinese: "已安装版本", italian: "Versioni installate", french: "Versions installées", spanish: "Versiones instaladas"),
                                systemImage: "externaldrive.badge.checkmark"
                            )
                            Spacer()
                            GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                                versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
                            }
                            GlassButton(
                                systemImage: "arrow.down.app",
                                title: localizedString(theme.language, english: "Download Versions", chinese: "下载版本", italian: "Scarica versioni", french: "Télécharger versions", spanish: "Descargar versiones"),
                                prominent: true,
                                action: openDiscover
                            )
                        }

                        Text(localizedString(
                            theme.language,
                            english: "This list only manages versions already installed on disk. New Minecraft version downloads live in Discover.",
                            chinese: "这里仅管理磁盘内已安装的版本。新 Minecraft 版本下载请前往“发现”。",
                            italian: "Qui gestisci solo versioni già installate su disco. I download di nuove versioni sono in Scopri.",
                            french: "Cette liste gère uniquement les versions déjà installées. Les nouvelles versions se téléchargent dans Découvrir.",
                            spanish: "Aquí solo se gestionan versiones ya instaladas. Las nuevas versiones se descargan en Descubrir."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if installedVersions.isEmpty {
                            ContentUnavailableView(
                                localizedString(theme.language, english: "No Installed Minecraft Versions", chinese: "没有已安装的 Minecraft 版本", italian: "Nessuna versione Minecraft installata", french: "Aucune version Minecraft installée", spanish: "Sin versiones de Minecraft instaladas"),
                                systemImage: "externaldrive.badge.questionmark",
                                description: Text(localizedString(theme.language, english: "Download a version from Discover, then return here to configure it.", chinese: "请先在“发现”中下载版本，然后回到这里配置。", italian: "Scarica una versione da Scopri, poi torna qui per configurarla.", french: "Téléchargez une version depuis Découvrir, puis revenez la configurer.", spanish: "Descarga una versión desde Descubrir y vuelve para configurarla."))
                            )
                            .frame(minHeight: 180)
                        } else {
                            InstanceVersionCardSection(
                                title: localizedString(theme.language, english: "Release", chinese: "正式版", italian: "Stabili", french: "Stables", spanish: "Estables"),
                                versions: installedReleaseVersions,
                                selectedID: instance.minecraftVersion,
                                select: openVersionConfiguration
                            )

                            InstanceVersionCardSection(
                                title: localizedString(theme.language, english: "Snapshot", chinese: "快照版", italian: "Snapshot", french: "Snapshots", spanish: "Snapshots"),
                                versions: installedSnapshotVersions,
                                selectedID: instance.minecraftVersion,
                                select: openVersionConfiguration
                            )

                            InstanceVersionCardSection(
                                title: localizedString(theme.language, english: "Historical", chinese: "历史版本", italian: "Storiche", french: "Historiques", spanish: "Históricas"),
                                versions: installedHistoricalVersions,
                                selectedID: instance.minecraftVersion,
                                select: openVersionConfiguration
                            )
                        }
                    }
                }
            }
        }
        .task(id: instance.minecraftVersion) {
            versionStore.selectedVersionID = instance.minecraftVersion
            versionStore.refreshAssets(for: instance)
            if let selectedVersion {
                versionStore.loadDetails(for: selectedVersion, instances: instanceStore.instances, settings: launcherSettings)
            }
        }
    }

    private var focusedVersion: MinecraftVersionInfo? {
        guard let focusedVersionID else { return nil }
        return versionStore.versions.first { $0.id == focusedVersionID }
    }

    private var selectedVersion: MinecraftVersionInfo? {
        versionStore.versions.first { $0.id == instance.minecraftVersion }
    }

    private var installedVersions: [MinecraftVersionInfo] {
        uniqueVersions(versionStore.versions.filter { $0.isInstalled || $0.isArchived || $0.isUsedByInstance })
            .sorted {
                if $0.isUsedByInstance != $1.isUsedByInstance { return $0.isUsedByInstance && !$1.isUsedByInstance }
                if $0.isInstalled != $1.isInstalled { return $0.isInstalled && !$1.isInstalled }
                if $0.isArchived != $1.isArchived { return !$0.isArchived && $1.isArchived }
                if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
                return $0.id.localizedStandardCompare($1.id) == .orderedDescending
            }
    }

    private var installedReleaseVersions: [MinecraftVersionInfo] {
        installedVersions.filter { $0.kind == .release }
    }

    private var installedSnapshotVersions: [MinecraftVersionInfo] {
        installedVersions.filter { $0.kind == .snapshot }
    }

    private var installedHistoricalVersions: [MinecraftVersionInfo] {
        installedVersions.filter { $0.kind == .oldBeta || $0.kind == .oldAlpha }
    }

    private func openVersionConfiguration(_ version: MinecraftVersionInfo) {
        focusedVersionID = version.id
        versionStore.selectedVersionID = version.id
        versionStore.loadDetails(for: version, instances: instanceStore.instances, settings: launcherSettings)
        versionStore.refreshAssets(for: instance)
    }
}
