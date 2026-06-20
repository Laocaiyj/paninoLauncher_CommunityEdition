import SwiftUI

struct InstanceVersionResourcePreviewRow: View {
    let asset: ManagedAsset

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: asset.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                .foregroundStyle(asset.isEnabled ? .green : .secondary)
                .frame(width: 18)
            Text(asset.metadata.displayName ?? asset.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            if let source = asset.source {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct VersionPickerRow: View {
    let version: MinecraftVersionInfo
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(version.id)
                        .font(.callout.weight(.semibold))
                    Text("\(version.kind.title(language: theme.language)) · \(version.javaRequirement)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if version.isUsedByInstance {
                    StatusBadge(title: localizedString(theme.language, english: "Used by Config", chinese: "配置使用中", italian: "Usata", french: "Utilisée", spanish: "En uso"), style: .success)
                } else if version.isInstalled {
                    StatusBadge(title: localizedString(theme.language, english: "Installed", chinese: "已安装", italian: "Installata", french: "Installée", spanish: "Instalada"), style: .success)
                }
            }
            .padding(9)
            .background(
                isSelected ? theme.semanticSelectionColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.28),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.65) : Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

func uniqueVersions(_ versions: [MinecraftVersionInfo]) -> [MinecraftVersionInfo] {
    var seen = Set<String>()
    return versions.filter { version in
        seen.insert(version.id).inserted
    }
}
