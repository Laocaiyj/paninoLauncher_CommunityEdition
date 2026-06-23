import SwiftUI

struct DiscoverImmersiveBackground: View {
    let section: DiscoverSection

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        sectionTint.opacity(0.64),
                        theme.semanticSelectionColor.opacity(0.28),
                        Color(nsColor: .windowBackgroundColor).opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.80
                )

                Image(systemName: section.symbolName)
                    .font(.system(size: min(proxy.size.width, 520) * 0.34, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.13))
                    .offset(x: proxy.size.width * 0.26, y: -proxy.size.height * 0.08)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var sectionTint: Color {
        switch section {
        case .minecraft:
            return Color(red: 0.24, green: 0.62, blue: 0.34)
        case .mods:
            return Color(red: 0.36, green: 0.42, blue: 0.92)
        case .modpacks:
            return Color(red: 0.87, green: 0.36, blue: 0.27)
        case .resources:
            return Color(red: 0.27, green: 0.62, blue: 0.84)
        case .shaders:
            return Color(red: 0.92, green: 0.55, blue: 0.22)
        }
    }
}

struct DiscoverImmersivePrimary: View {
    let title: String
    let subtitle: String
    let metadata: [String]
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetadataLine(items: metadata, font: .caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            Text(title)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 4)

            Text(subtitle)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: 760, alignment: .leading)

            if !status.isEmpty {
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.22), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DiscoverMinecraftSceneShelf: View {
    let versionCount: Int
    let status: String
    @Binding var searchText: String
    @Binding var group: MinecraftBrowseGroup
    let refresh: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    minecraftSearchField
                    groupPicker
                    refreshButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    minecraftSearchField
                    HStack(spacing: 10) {
                        groupPicker
                        refreshButton
                    }
                }
            }

            HStack(spacing: 8) {
                ImmersiveTextPill(
                    title: localizedString(theme.language, english: "Catalog", chinese: "目录", italian: "Catalogo", french: "Catalogue", spanish: "Catalogo"),
                    value: localizedString(theme.language, english: "\(versionCount) versions", chinese: "\(versionCount) 个版本", italian: "\(versionCount) versioni", french: "\(versionCount) versions", spanish: "\(versionCount) versiones")
                )

                if !status.isEmpty {
                    ImmersiveTextPill(
                        title: localizedString(theme.language, english: "Status", chinese: "状态", italian: "Stato", french: "Etat", spanish: "Estado"),
                        value: status
                    )
                }
            }
        }
        .padding(14)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.panel, tint: theme.semanticSelectionColor)
    }

    private var minecraftSearchField: some View {
        PaninoTextInput(
            localizedString(theme.language, english: "Search version, e.g. 1.20.1", chinese: "搜索版本，例如 1.20.1", italian: "Cerca versione, es. 1.20.1", french: "Rechercher version, ex. 1.20.1", spanish: "Buscar version, ej. 1.20.1"),
            text: $searchText
        )
        .frame(minWidth: 260, idealWidth: 420, maxWidth: 560)
    }

    private var groupPicker: some View {
        PaninoGlassSegmentedRail {
            Picker("", selection: $group) {
                ForEach(MinecraftBrowseGroup.allCases) { browseGroup in
                    Text(browseGroup.title(language: theme.language)).tag(browseGroup)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(minWidth: 300, idealWidth: 430, maxWidth: 500)
        }
    }

    private var refreshButton: some View {
        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: refresh)
    }
}

private extension DiscoverSection {
    var symbolName: String {
        switch self {
        case .minecraft:
            return "cube.box.fill"
        case .mods:
            return "shippingbox.fill"
        case .modpacks:
            return "square.stack.3d.up.fill"
        case .resources:
            return "photo.stack.fill"
        case .shaders:
            return "sun.max.fill"
        }
    }
}
