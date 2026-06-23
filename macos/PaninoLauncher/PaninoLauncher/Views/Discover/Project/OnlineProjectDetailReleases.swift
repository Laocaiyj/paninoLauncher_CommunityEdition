import SwiftUI

struct ReleasePickerSection: View {
    let releases: [OnlineRelease]
    @Binding var selectedReleaseID: String?
    let currentMinecraftVersion: String?
    let projectFailure: String?
    let isLoading: Bool
    let retryLoad: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showAll = false

    private var compatibleReleases: [OnlineRelease] {
        guard let currentMinecraftVersion else { return [] }
        return releases.filter { $0.gameVersions.contains(currentMinecraftVersion) }
    }

    private var visibleReleases: [OnlineRelease] {
        showAll ? compatibleReleases : Array(compatibleReleases.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localizedString(theme.language, english: "Choose Version", chinese: "选择版本", italian: "Scegli versione", french: "Choisir version", spanish: "Elegir versión"))
                    .font(.headline)
                Spacer()
                CountText(value: compatibleReleases.count)
            }

            if let projectFailure {
                HStack(spacing: 8) {
                    Label(localizedOnlineError(projectFailure, language: theme.language), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: retryLoad)
                }
            } else if currentMinecraftVersion == nil {
                Label(localizedString(theme.language, english: "Select a Minecraft release to filter installable versions.", chinese: "请选择 Minecraft 正式版，以筛选可安装版本。", italian: "Seleziona una release Minecraft per filtrare.", french: "Sélectionnez une version Minecraft pour filtrer.", spanish: "Selecciona una versión de Minecraft para filtrar."), systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isLoading && releases.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localizedString(theme.language, english: "Loading compatible files...", chinese: "正在加载兼容文件...", italian: "Caricamento file compatibili...", french: "Chargement des fichiers compatibles...", spanish: "Cargando archivos compatibles..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if compatibleReleases.isEmpty {
                ContentUnavailableView(
                    localizedString(theme.language, english: "No compatible release", chinese: "没有兼容版本", italian: "Nessuna versione compatibile", french: "Aucune version compatible", spanish: "Sin versión compatible"),
                    systemImage: "tray",
                    description: Text(localizedString(theme.language, english: "This project did not return files for the selected Minecraft version.", chinese: "该项目没有返回当前 Minecraft 版本可用的文件。", italian: "Nessun file per la versione Minecraft selezionata.", french: "Aucun fichier pour la version Minecraft choisie.", spanish: "No hay archivos para la versión de Minecraft seleccionada."))
                )
                .frame(minHeight: 120)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(visibleReleases) { release in
                        ReleasePickerRow(
                            release: release,
                            selected: isSelected(release)
                        ) {
                            selectedReleaseID = release.id
                        }
                    }
                }

                if compatibleReleases.count > 10 {
                    Button {
                        withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                            showAll.toggle()
                        }
                    } label: {
                        Label(showMoreTitle, systemImage: showAll ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.semanticSelectionColor)
                }
            }
        }
    }

    private var showMoreTitle: String {
        if showAll {
            return localizedString(theme.language, english: "Show Less", chinese: "收起", italian: "Mostra meno", french: "Afficher moins", spanish: "Mostrar menos")
        }
        let remaining = compatibleReleases.count - visibleReleases.count
        return localizedString(theme.language, english: "Show \(remaining) More", chinese: "显示更多 \(remaining) 个", italian: "Mostra altri \(remaining)", french: "Afficher \(remaining) de plus", spanish: "Mostrar \(remaining) más")
    }

    private func isSelected(_ release: OnlineRelease) -> Bool {
        (selectedReleaseID ?? compatibleReleases.first?.id) == release.id
    }
}

private struct ReleasePickerRow: View {
    let release: OnlineRelease
    let selected: Bool
    let select: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(release.versionName.isEmpty ? release.versionNumber : release.versionName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(releaseSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 10)
                PlainStatusText(title: release.releaseType.rawValue.capitalized, style: releaseBadgeStyle)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(selected ? 0.5 : 0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.3), lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var releaseSubtitle: String {
        [
            release.gameVersions.prefix(4).joined(separator: ", "),
            release.loaders.map(\.displayTitle).joined(separator: ", "),
            release.publishedAt?.formatted(date: .abbreviated, time: .omitted)
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: " · ")
    }

    private var releaseBadgeStyle: StatusBadge.Style {
        switch release.releaseType {
        case .release:
            return .neutral
        case .beta, .snapshot:
            return .warning
        case .alpha, .unknown:
            return .error
        }
    }
}
