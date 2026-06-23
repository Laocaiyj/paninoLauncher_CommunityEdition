import SwiftUI

struct MinecraftVersionSearchButton: View {
    let selectedVersionID: String
    let versions: [MinecraftVersionInfo]
    let totalMatches: Int
    let limit: Int
    @Binding var searchText: String
    @Binding var showingPicker: Bool
    let select: (MinecraftVersionInfo) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 8) {
                Text(selectedVersionID)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 280, alignment: .trailing)
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                PaninoTextInput(
                    localizedString(theme.language, english: "Search Minecraft version", chinese: "搜索 Minecraft 版本", italian: "Cerca versione Minecraft", french: "Rechercher une version Minecraft", spanish: "Buscar version de Minecraft"),
                    text: $searchText
                )

                if versions.isEmpty {
                    ContentUnavailableView(
                        localizedString(theme.language, english: "No versions found", chinese: "未找到版本", italian: "Nessuna versione", french: "Aucune version", spanish: "Sin versiones"),
                        systemImage: "tray",
                        description: Text(searchText)
                    )
                    .frame(minHeight: 140)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(versions) { version in
                                Button {
                                    select(version)
                                } label: {
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(version.id)
                                                .font(.callout.weight(.semibold))
                                            Text(version.kind.title)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if version.id == selectedVersionID {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.semanticSelectionColor)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(version.id == selectedVersionID ? theme.semanticSelectionColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: 300)
                }

                Text(resultSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 340)
        }
    }

    private var resultSummary: String {
        if totalMatches > limit {
            return localizedString(
                theme.language,
                english: "Showing \(limit) of \(totalMatches) matches. Type to narrow results.",
                chinese: "显示 \(totalMatches) 个匹配中的前 \(limit) 个。输入关键字可缩小范围。",
                italian: "Mostrate \(limit) di \(totalMatches) corrispondenze.",
                french: "Affiche \(limit) sur \(totalMatches) resultats.",
                spanish: "Mostrando \(limit) de \(totalMatches) coincidencias."
            )
        }
        return localizedString(
            theme.language,
            english: "\(totalMatches) matching versions",
            chinese: "\(totalMatches) 个匹配版本",
            italian: "\(totalMatches) versioni corrispondenti",
            french: "\(totalMatches) versions correspondantes",
            spanish: "\(totalMatches) versiones coincidentes"
        )
    }
}

struct InstanceWizardStepper: View {
    let step: InstanceCreationStep
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack(spacing: 8) {
            ForEach(InstanceCreationStep.allCases) { current in
                Capsule()
                    .fill(current == step ? theme.semanticSelectionColor : Color(nsColor: .separatorColor).opacity(0.45))
                    .frame(height: 6)
            }
        }
    }
}

struct InstanceWizardReviewRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}
