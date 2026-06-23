import SwiftUI

struct InstanceVersionWorkspaceHeader: View {
    let minecraftVersion: String
    let summary: String
    let stateTitle: String
    let badgeStyle: StatusBadge.Style

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Minecraft \(minecraftVersion)")
                    .font(.headline)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            StatusBadge(title: stateTitle, style: badgeStyle)
        }
    }
}

struct InstanceVersionWorkspaceMetricGrid: View {
    let javaRequirement: String
    let loaderTitle: String
    let resourceCount: Int
    let fileStateTitle: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
            InstanceVersionWorkspaceMetric(
                title: localizedString(theme.language, english: "Java", chinese: "Java", italian: "Java", french: "Java", spanish: "Java"),
                value: javaRequirement,
                systemImage: "cup.and.saucer"
            )
            InstanceVersionWorkspaceMetric(
                title: localizedString(theme.language, english: "Loader", chinese: "Loader", italian: "Loader", french: "Loader", spanish: "Loader"),
                value: loaderTitle,
                systemImage: "puzzlepiece.extension"
            )
            InstanceVersionWorkspaceMetric(
                title: localizedString(theme.language, english: "Resources", chinese: "资源", italian: "Risorse", french: "Ressources", spanish: "Recursos"),
                value: "\(resourceCount)",
                systemImage: "shippingbox"
            )
            InstanceVersionWorkspaceMetric(
                title: localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"),
                value: fileStateTitle,
                systemImage: "checkmark.seal"
            )
        }
    }
}

private struct InstanceVersionWorkspaceMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct InstanceVersionWorkspaceActions: View {
    let installTitle: String
    let installProminent: Bool
    let install: () -> Void
    let repair: () -> Void
    let manageResources: () -> Void
    let findContent: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                actionButtons
            }

            VStack(alignment: .leading, spacing: 8) {
                actionButtons
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        GlassButton(systemImage: "arrow.down.circle", title: installTitle, prominent: installProminent, action: install)
        GlassButton(systemImage: "checkmark.seal", title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar"), action: repair)
        GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Manage Resources", chinese: "管理资源", italian: "Gestisci risorse", french: "Gérer ressources", spanish: "Gestionar recursos"), action: manageResources)
        GlassButton(systemImage: "magnifyingglass.circle", title: localizedString(theme.language, english: "Find Content", chinese: "查找内容", italian: "Trova contenuti", french: "Trouver contenu", spanish: "Buscar contenido"), action: findContent)
    }
}

struct InstanceVersionResourceSummary: View {
    let assets: [ManagedAsset]

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        if !assets.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(localizedString(theme.language, english: "Local resources in this configuration", chinese: "当前游戏配置资源概况", italian: "Risorse locali in questa configurazione", french: "Ressources locales de cette configuration", spanish: "Recursos locales de esta configuración"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(assets) { asset in
                    InstanceVersionResourcePreviewRow(asset: asset)
                }
            }
        }
    }
}
