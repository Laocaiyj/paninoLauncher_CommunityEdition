import SwiftUI

struct ProjectDescriptionSection: View {
    let text: String
    var collapsedLineLimit = 5
    @State private var isExpanded = false
    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SafeDescriptionText(text: text, lineLimit: canToggle ? (isExpanded ? nil : collapsedLineLimit) : nil)

            if canToggle {
                Button {
                    withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Label(
                        isExpanded
                            ? localizedString(theme.language, english: "Collapse", chinese: "收起", italian: "Comprimi", french: "Réduire", spanish: "Contraer")
                            : localizedString(theme.language, english: "Show More", chinese: "展开", italian: "Mostra altro", french: "Afficher plus", spanish: "Mostrar más"),
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.semanticSelectionColor)
            }
        }
    }

    private var canToggle: Bool {
        text.count > 280 || text.components(separatedBy: .newlines).count > 5
    }
}

struct ProjectMetadataSection: View {
    let project: OnlineProject
    var presentation: OnlineProjectDetailPresentation = .full
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if presentation == .inspector {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 8) {
                    metadataItems
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow {
                        metadataRow(authorTitle, project.authors.prefix(3).joined(separator: ", "))
                        metadataRow(sourceTitle, project.source.displayName)
                    }
                    GridRow {
                        metadataRow(versionTitle, summarized(project.gameVersions, limit: 4))
                        metadataRow("Loader", summarized(project.loaders.map(\.displayTitle), limit: 4))
                    }
                    GridRow {
                        metadataRow(sideTitle, "\(project.clientSide.sideTitle(prefix: "Client")) · \(project.serverSide.sideTitle(prefix: "Server"))")
                        metadataRow(downloadTitle, formattedCount(project.downloads))
                    }
                    GridRow {
                        metadataRow(updatedTitle, project.updatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                        metadataRow(licenseTitle, project.license ?? "-")
                    }
                }
            }

            if !project.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(project.categories.prefix(10), id: \.self) { category in
                            Text(category)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .controlBackgroundColor).opacity(0.38), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var metadataItems: some View {
        metadataRow(authorTitle, project.authors.prefix(3).joined(separator: ", "))
        metadataRow(sourceTitle, project.source.displayName)
        metadataRow(versionTitle, summarized(project.gameVersions, limit: 3))
        metadataRow("Loader", summarized(project.loaders.map(\.displayTitle), limit: 3))
        metadataRow(sideTitle, "\(project.clientSide.sideTitle(prefix: "Client")) · \(project.serverSide.sideTitle(prefix: "Server"))")
        metadataRow(downloadTitle, formattedCount(project.downloads))
        metadataRow(updatedTitle, project.updatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "-")
        metadataRow(licenseTitle, project.license ?? "-")
    }

    private var authorTitle: String {
        localizedString(theme.language, english: "Authors", chinese: "作者", italian: "Autori", french: "Auteurs", spanish: "Autores")
    }

    private var sourceTitle: String {
        localizedString(theme.language, english: "Source", chinese: "来源", italian: "Fonte", french: "Source", spanish: "Fuente")
    }

    private var versionTitle: String {
        localizedString(theme.language, english: "Versions", chinese: "版本", italian: "Versioni", french: "Versions", spanish: "Versiones")
    }

    private var sideTitle: String {
        localizedString(theme.language, english: "Side", chinese: "运行端", italian: "Lato", french: "Côté", spanish: "Lado")
    }

    private var downloadTitle: String {
        localizedString(theme.language, english: "Downloads", chinese: "下载量", italian: "Download", french: "Téléchargements", spanish: "Descargas")
    }

    private var updatedTitle: String {
        localizedString(theme.language, english: "Updated", chinese: "更新", italian: "Aggiornato", french: "Mis à jour", spanish: "Actualizado")
    }

    private var licenseTitle: String {
        localizedString(theme.language, english: "License", chinese: "许可证", italian: "Licenza", french: "Licence", spanish: "Licencia")
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value.isEmpty ? "-" : value)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summarized(_ values: [String], limit: Int) -> String {
        let cleaned = values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !cleaned.isEmpty else { return "-" }
        let prefix = cleaned.prefix(limit).joined(separator: ", ")
        if cleaned.count > limit {
            return "\(prefix) +\(cleaned.count - limit)"
        }
        return prefix
    }

    private func formattedCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
