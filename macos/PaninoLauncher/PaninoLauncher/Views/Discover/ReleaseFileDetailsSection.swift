import SwiftUI

struct ReleaseFileDetailsSection: View {
    let release: OnlineRelease

    @EnvironmentObject private var theme: ThemeSettings
    @State private var isExpanded = true

    private var primaryFile: OnlineFile? {
        release.files.first(where: \.isPrimary) ?? release.files.first
    }

    var body: some View {
        FullWidthDisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 7) {
                if let primaryFile {
                    metadataRow("File", primaryFile.fileName)
                    metadataRow("Size", formattedBytes(primaryFile.sizeBytes))
                    ForEach(primaryFile.hashes.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        metadataRow(key.uppercased(), value)
                    }
                }
                metadataRow("Release", release.releaseType.rawValue.capitalized)
                metadataRow("Game", release.gameVersions.prefix(6).joined(separator: ", "))
                metadataRow("Loader", release.loaders.map(\.displayTitle).joined(separator: ", "))

                if !release.dependencies.isEmpty {
                    Text(localizedString(theme.language, english: "Dependencies", chinese: "依赖", italian: "Dipendenze", french: "Dépendances", spanish: "Dependencias"))
                        .font(.caption.weight(.semibold))
                    ForEach(release.dependencies.prefix(8)) { dependency in
                        Text("\(dependency.relation.rawValue): \(dependency.projectID ?? dependency.versionID ?? dependency.id)")
                            .font(.caption)
                            .foregroundStyle(dependency.relation == .incompatible ? .orange : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let changelog = release.changelog, !changelog.isEmpty {
                    Text(localizedString(theme.language, english: "Changelog", chinese: "更新日志", italian: "Registro modifiche", french: "Journal des modifications", spanish: "Cambios"))
                        .font(.caption.weight(.semibold))
                    SafeDescriptionText(text: changelog, lineLimit: 8)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text(localizedString(theme.language, english: "File Details", chinese: "文件详情", italian: "Dettagli file", french: "Détails du fichier", spanish: "Detalles del archivo"))
                    .font(.headline)
                Spacer()
                if let primaryFile {
                    Text(formattedBytes(primaryFile.sizeBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }
}
