import SwiftUI

struct MinecraftVersionDownloadPanel: View {
    @ObservedObject var viewModel: LauncherViewModel

    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var theme: ThemeSettings
    @State private var showMoreVersions = false

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Minecraft Version Downloads", chinese: "Minecraft 版本下载", italian: "Download versioni Minecraft", french: "Téléchargement versions Minecraft", spanish: "Descargas de versiones Minecraft"),
                        systemImage: "arrow.down.app"
                    )
                    Spacer()
                    CountText(value: availableVersions.count, style: .download)
                    GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                        refreshVersions()
                    }
                    GlassButton(
                        systemImage: showMoreVersions ? "chevron.up" : "chevron.down",
                        title: showMoreVersions
                            ? localizedString(theme.language, english: "Less", chinese: "收起", italian: "Meno", french: "Moins", spanish: "Menos")
                            : localizedString(theme.language, english: "More", chinese: "更多", italian: "Altro", french: "Plus", spanish: "Más")
                    ) {
                        showMoreVersions.toggle()
                    }
                }

                if availableVersions.isEmpty {
                    ContentUnavailableView(
                        localizedString(theme.language, english: "No installable versions loaded", chinese: "暂无可安装版本", italian: "Nessuna versione installabile caricata", french: "Aucune version installable chargée", spanish: "No hay versiones instalables cargadas"),
                        systemImage: "tray",
                        description: Text(versionStore.versionStatus)
                    )
                    .frame(minHeight: 120)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], spacing: 10) {
                        ForEach(availableVersions) { version in
                            MinecraftVersionDownloadCard(
                                version: version,
                                install: { install(version) }
                            )
                        }
                    }
                }

                Text(versionStore.versionStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .task {
            refreshVersions()
        }
    }

    private var availableVersions: [MinecraftVersionInfo] {
        uniqueVersions(latestVersions + versionStore.versions.filter { $0.kind == .release })
            .prefix(showMoreVersions ? 24 : 8)
            .map { $0 }
    }

    private var latestVersions: [MinecraftVersionInfo] {
        [
            versionStore.latestReleaseID,
            versionStore.latestSnapshotID
        ]
        .compactMap { id in id.flatMap { versionID in versionStore.versions.first { $0.id == versionID } } }
    }

    private func install(_ version: MinecraftVersionInfo) {
        viewModel.version = version.id
        viewModel.install(gameDir: isolatedGameDirectory(for: version).path)
    }

    private func isolatedGameDirectory(for version: MinecraftVersionInfo) -> URL {
        let root = (try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true)
        let baseName = "Minecraft \(version.id)"
        var candidate = safeFileComponent(baseName)
        var suffix = 2
        while FileManager.default.fileExists(atPath: root.appendingPathComponent(candidate, isDirectory: true).path) {
            candidate = safeFileComponent("\(baseName) \(suffix)")
            suffix += 1
        }
        return root.appendingPathComponent(candidate, isDirectory: true)
    }

    private func safeFileComponent(_ value: String) -> String {
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

    private func refreshVersions() {
        configureVersionCoreBackend()
        versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
    }

    private func configureVersionCoreBackend() {
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
}

struct MinecraftVersionDownloadCard: View {
    let version: MinecraftVersionInfo
    let install: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(version.id)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                MetadataLine(items: [version.kind.title(language: theme.language)], font: .caption.weight(.semibold))
            }

            Text("\(version.releasedAt) · \(version.javaRequirement)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                if let stateText = visibleDownloadState(version, language: theme.language) {
                    Text(stateText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                GlassButton(
                    systemImage: "arrow.down.circle",
                    title: localizedString(theme.language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar"),
                    prominent: true,
                    action: install
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.34), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        }
    }
}

private func visibleDownloadState(_ version: MinecraftVersionInfo, language: AppLanguage) -> String? {
    version.downloadState == "Available" ? nil : version.downloadState.localizedVersionState(language)
}
