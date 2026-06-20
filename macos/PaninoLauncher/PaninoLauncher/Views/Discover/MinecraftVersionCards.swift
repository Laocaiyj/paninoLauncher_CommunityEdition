import SwiftUI

struct MinecraftVersionFeatureCard: View {
    let version: MinecraftVersionInfo
    let select: (MinecraftVersionInfo) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button {
            select(version)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    MetadataLine(items: [version.kind.title(language: theme.language)], font: .caption.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                Text(version.id)
                    .font(.title3.bold())
                    .lineLimit(1)
                Text("\(version.releasedAt) · \(version.javaRequirement)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let stateText = discoverVisibleDownloadState(version, language: theme.language) {
                    Text(stateText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .background(theme.semanticSelectionColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.semanticSelectionColor.opacity(0.38), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct MinecraftVersionBrowseCard: View {
    let version: MinecraftVersionInfo
    let select: (MinecraftVersionInfo) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button {
            select(version)
        } label: {
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
                HStack(spacing: 6) {
                    if let stateText = browseStateText {
                        Text(stateText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.34), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var browseStateText: String? {
        if version.isUsedByInstance {
            return localizedString(theme.language, english: "Used by config", chinese: "配置使用中", italian: "Usata", french: "Utilisée", spanish: "En uso")
        }
        return discoverVisibleDownloadState(version, language: theme.language)
    }
}
