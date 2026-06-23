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
