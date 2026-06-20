import SwiftUI

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
