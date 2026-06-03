import SwiftUI

struct VersionBrowserHeader: View {
    @Binding var searchText: String
    @Binding var usageFilter: VersionUsageFilter

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack(spacing: 12) {
            PaninoTextInput(
                localizedString(theme.language, english: "Search version number", chinese: "搜索版本号", italian: "Cerca versione", french: "Rechercher une version", spanish: "Buscar versión"),
                text: $searchText
            )
            Picker(localizedString(theme.language, english: "Usage", chinese: "用途", italian: "Uso", french: "Usage", spanish: "Uso"), selection: $usageFilter) {
                ForEach(VersionUsageFilter.allCases) { filter in
                    Text(filter.title(language: theme.language)).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
        }
    }
}

struct VersionBrowserSection: View {
    let title: String
    let versions: [MinecraftVersionInfo]
    let selectedVersionID: String?
    let select: (MinecraftVersionInfo) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                CountText(value: versions.count)
            }

            if versions.isEmpty {
                Text(localizedString(theme.language, english: "No matching versions.", chinese: "没有匹配版本。", italian: "Nessuna versione corrispondente.", french: "Aucune version correspondante.", spanish: "No hay versiones coincidentes."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(versions) { version in
                        VersionInfoCard(
                            version: version,
                            language: theme.language,
                            isSelected: selectedVersionID == version.id
                        ) {
                            select(version)
                        }
                    }
                }
            }
        }
    }
}

struct VersionInfoCard: View {
    let version: MinecraftVersionInfo
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(version.id)
                        .font(.headline)
                    Spacer()
                    MetadataLine(items: [version.kind.title(language: language)], font: .caption.weight(.semibold))
                }

                infoRow(AppText.released.localized(language), version.releasedAt)
                infoRow(AppText.java.localized(language), version.javaRequirement)
                if version.downloadState != "Available" {
                    infoRow(AppText.download.localized(language), version.downloadState.localizedVersionState(language))
                }
                infoRow(AppText.verify.localized(language), version.verificationState.localizedVersionState(language))
                if version.isUsedByInstance {
                    Text(localizedString(language, english: "Used by Config", chinese: "配置使用中", italian: "Usata", french: "Utilisée", spanish: "En uso"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.85) : Color(nsColor: .separatorColor).opacity(0.55), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
        }
        .font(.caption)
    }
}

struct ManagedAssetRow: View {
    let asset: ManagedAsset
    let onToggle: () -> Void
    let onLink: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: asset.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                .foregroundStyle(asset.isEnabled ? .green : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.metadata.displayName ?? asset.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if let conflictMessage = asset.conflictMessage {
                    Text(conflictMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                } else {
                    Text(assetMetadataLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let summary = asset.metadata.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let source = asset.source {
                MetadataLine(items: [source], font: .caption.weight(.semibold))
            }

            GlassButton(
                systemImage: asset.isEnabled ? "pause" : "play",
                title: asset.isEnabled
                    ? AppText.disable.localized(theme.language)
                    : AppText.enable.localized(theme.language),
                action: onToggle
            )

            GlassButton(systemImage: "link", title: localizedString(theme.language, english: "Link", chinese: "关联", italian: "Collega", french: "Lier", spanish: "Vincular"), action: onLink)
            GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language), action: onDelete)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.36), in: RoundedRectangle(cornerRadius: 8))
    }

    private var assetMetadataLine: String {
        [
            asset.metadata.version.map { "v\($0)" },
            asset.metadata.authors.isEmpty ? nil : asset.metadata.authors.prefix(2).joined(separator: ", "),
            asset.metadata.loaders.isEmpty ? nil : asset.metadata.loaders.joined(separator: ", "),
            formattedBytes(asset.fileSizeBytes),
            asset.modifiedAt?.formatted(date: .abbreviated, time: .omitted),
            asset.projectURL?.absoluteString ?? asset.url.path
        ].compactMap { $0 }.joined(separator: " · ")
    }
}

struct VersionDetailPanel: View {
    let version: MinecraftVersionInfo
    let status: String
    let install: () -> Void
    let repair: () -> Void
    let cleanUnused: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PanelHeader(title: "\(version.id) Details", systemImage: "cube.box")
                Spacer()
                if let diskUsageBytes = version.diskUsageBytes {
                    MetadataLine(items: [formattedBytes(diskUsageBytes)])
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                detail("Released", version.releasedAt)
                detail("Type", version.kind.title(language: theme.language))
                detail("Java", version.javaRequirement)
                detail("Libraries", version.libraryCount.map(String.init) ?? "Not loaded")
                detail("Asset Index", version.assetIndexState)
                detail("Client Jar", version.clientJarState)
                detail("Natives", version.nativesState)
            }
            HStack(spacing: 8) {
                GlassButton(systemImage: "arrow.down.circle", title: "Install", prominent: true, action: install)
                GlassButton(systemImage: "checkmark.seal", title: "Repair", action: repair)
                GlassButton(systemImage: "trash", title: "Clean Unused", action: cleanUnused)
                    .disabled(version.isUsedByInstance)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.34), in: RoundedRectangle(cornerRadius: 8))
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.26), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct AssetLinkEditor: View {
    let asset: ManagedAsset
    @Binding var source: String
    @Binding var projectURLText: String
    let save: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader(title: localizedString(theme.language, english: "Link Online Project", chinese: "关联在线项目", italian: "Collega progetto online", french: "Lier le projet", spanish: "Vincular proyecto"), systemImage: "link")
            Text(asset.name)
                .font(.headline)
                .lineLimit(1)
            SettingsRow(title: "Source", systemImage: "globe") {
                PaninoTextInput("Modrinth / CurseForge", text: $source)
            }
            SettingsRow(title: "Project URL", systemImage: "link") {
                PaninoTextInput("https://...", text: $projectURLText)
            }
            HStack {
                Spacer()
                GlassButton(systemImage: "xmark", title: AppText.cancel.localized(theme.language)) {
                    dismiss()
                }
                GlassButton(systemImage: "checkmark.circle", title: AppText.apply.localized(theme.language), prominent: true) {
                    save()
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}
