import SwiftUI

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
