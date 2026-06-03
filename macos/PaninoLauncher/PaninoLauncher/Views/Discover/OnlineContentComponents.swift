import AppKit
import Foundation
import SwiftUI

struct CurseForgeAPIKeyInlineEditor: View {
    @Binding var apiKey: String
    let openSettings: () -> Void
    let onSaved: () -> Void
    @EnvironmentObject private var onlineContentStore: OnlineContentStore
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                PanelHeader(title: localizedString(theme.language, english: "CurseForge Advanced Channel", chinese: "CurseForge 高级渠道", italian: "Canale avanzato CurseForge", french: "Canal avancé CurseForge", spanish: "Canal avanzado CurseForge"), systemImage: "key")
                Text(localizedString(theme.language, english: "Panino does not ship a CurseForge API key. Use your own key only if you need this optional channel; it stays in local Keychain and is redacted from logs.", chinese: "Panino 发布版不会内置 CurseForge API Key。仅在需要这个可选渠道时填入你自己的 Key；它只保存在本机钥匙串，并会从日志中脱敏。", italian: "Panino non include una chiave API CurseForge. Usa una tua chiave solo se ti serve questo canale opzionale; resta nel Portachiavi locale.", french: "Panino n'intègre pas de clé API CurseForge. Utilisez votre propre clé seulement pour ce canal optionnel ; elle reste dans le trousseau local.", spanish: "Panino no incluye una API key de CurseForge. Usa tu propia clave solo para este canal opcional; queda en el llavero local."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    PaninoTextInput(localizedString(theme.language, english: "Optional personal CurseForge API Key", chinese: "可选的个人 CurseForge API Key", italian: "Chiave API CurseForge personale opzionale", french: "Clé API CurseForge personnelle optionnelle", spanish: "API key personal opcional de CurseForge"), text: $apiKey, isSecure: true)
                    GlassButton(systemImage: "checkmark.circle", title: AppText.apply.localized(theme.language), prominent: true) {
                        onlineContentStore.saveCurseForgeAPIKey(apiKey)
                        apiKey = ""
                        if onlineContentStore.hasCurseForgeAPIKey() {
                            onSaved()
                        }
                    }
                    GlassButton(systemImage: "trash", title: AppText.clear.localized(theme.language)) {
                        onlineContentStore.saveCurseForgeAPIKey("")
                        apiKey = ""
                    }
                    GlassButton(systemImage: "gearshape", title: AppText.settings.localized(theme.language), action: openSettings)
                }
            }
        }
    }
}

struct OnlineSearchErrorBanner: View {
    let source: ContentSourceID
    let message: String
    let requestSnapshot: String?
    @Binding var proxyAddress: String
    let retry: () -> Void
    let switchSource: () -> Void
    let openSettings: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        InlineBanner(
            title: source.displayName,
            message: bannerMessage,
            style: .warning
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { actions }
                VStack(alignment: .trailing, spacing: 8) { actions }
            }
        }
    }

    private var bannerMessage: String {
        let localized = localizedOnlineError(message, language: theme.language)
        guard let requestSnapshot, !requestSnapshot.isEmpty else { return localized }
        return localizedString(theme.language, english: "\(localized) Request: \(requestSnapshot)", chinese: "\(localized) 请求：\(requestSnapshot)", italian: "\(localized) Richiesta: \(requestSnapshot)", french: "\(localized) Requête : \(requestSnapshot)", spanish: "\(localized) Solicitud: \(requestSnapshot)")
    }

    @ViewBuilder
    private var actions: some View {
        PaninoTextInput("http://127.0.0.1:7890", text: $proxyAddress)
            .frame(width: 180)
        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: retry)
        GlassButton(systemImage: "arrow.left.arrow.right", title: localizedString(theme.language, english: "Switch Source", chinese: "切换渠道", italian: "Cambia fonte", french: "Changer de source", spanish: "Cambiar fuente"), action: switchSource)
        ToolbarIconButton(systemImage: "gearshape", title: AppText.settings.localized(theme.language), action: openSettings)
    }
}

struct OnlineRequestFailedView: View {
    let source: ContentSourceID
    let message: String
    let retry: () -> Void
    let switchSource: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentUnavailableView(
                localizedString(theme.language, english: "Search failed", chinese: "搜索失败", italian: "Ricerca non riuscita", french: "Recherche échouée", spanish: "Búsqueda fallida"),
                systemImage: "exclamationmark.triangle",
                description: Text(localizedOnlineError(message, language: theme.language))
            )
            .frame(minHeight: 160)
            HStack {
                Spacer()
                GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: retry)
                GlassButton(systemImage: "arrow.left.arrow.right", title: localizedString(theme.language, english: "Switch Source", chinese: "切换渠道", italian: "Cambia fonte", french: "Changer de source", spanish: "Cambiar fuente"), action: switchSource)
            }
        }
        .padding(.vertical, 8)
    }
}

struct OnlineEmptyResultsView: View {
    let source: ContentSourceID
    let canSearch: Bool
    let isVersionFiltered: Bool
    let retry: () -> Void
    let relaxVersionFilter: () -> Void
    let switchSource: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ContentUnavailableView(
                localizedString(theme.language, english: "No online results", chinese: "暂无在线结果", italian: "Nessun risultato online", french: "Aucun résultat en ligne", spanish: "Sin resultados online"),
                systemImage: canSearch ? "square.stack.3d.up.slash" : "key.slash",
                description: Text(canSearch
                    ? localizedString(theme.language, english: "Try another keyword, loosen the version/loader filter, or switch content source.", chinese: "请尝试其他关键词、放宽版本/加载器筛选，或切换内容渠道。", italian: "Prova un'altra parola chiave, amplia i filtri o cambia fonte.", french: "Essayez un autre mot-clé, assouplissez les filtres ou changez de source.", spanish: "Prueba otra palabra, relaja filtros o cambia de fuente.")
                    : localizedString(theme.language, english: "\(source.displayName) needs configuration before searching.", chinese: "\(source.displayName) 需要配置后才能搜索。", italian: "\(source.displayName) richiede configurazione.", french: "\(source.displayName) nécessite une configuration.", spanish: "\(source.displayName) necesita configuración."))
            )
            .frame(minHeight: 160)
            HStack {
                Spacer()
                if isVersionFiltered {
                    GlassButton(systemImage: "line.3.horizontal.decrease.circle", title: localizedString(theme.language, english: "Relax Version", chinese: "放宽版本", italian: "Allarga versione", french: "Assouplir version", spanish: "Relajar versión"), action: relaxVersionFilter)
                }
                GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: retry)
                    .disabled(!canSearch)
                GlassButton(systemImage: "arrow.left.arrow.right", title: localizedString(theme.language, english: "Switch Source", chinese: "切换渠道", italian: "Cambia fonte", french: "Changer de source", spanish: "Cambiar fuente"), action: switchSource)
            }
        }
        .padding(.vertical, 8)
    }
}

extension OnlineProjectType {
    var displayTitle: String {
        switch self {
        case .mod:
            return "Mod"
        case .modpack:
            return "Modpack"
        case .resourcePack:
            return "Resource Pack"
        case .shaderPack:
            return "Shader Pack"
        case .plugin:
            return "Plugin"
        case .minecraftVersion:
            return "Minecraft"
        case .loader:
            return "Loader"
        }
    }
}

struct OnlineProjectSkeletonGrid: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 282), spacing: 12)], spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.2)).frame(width: 42, height: 42)
                    RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.2)).frame(height: 16)
                    RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.14)).frame(height: 42)
                    RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.16)).frame(width: 150, height: 14)
                }
                .padding(12)
                .frame(minHeight: 132)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                .redacted(reason: .placeholder)
            }
        }
    }
}

struct OnlineProjectSkeletonList: View {
    var body: some View {
        LazyVStack(spacing: 6) {
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.2))
                            .frame(width: 180, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.14))
                            .frame(height: 12)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.secondary.opacity(0.16))
                        .frame(width: 88, height: 22)
                }
                .padding(10)
                .frame(minHeight: PaninoTokens.Layout.compactResultRowHeight)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                .redacted(reason: .placeholder)
            }
        }
    }
}

struct OnlineProjectResultRow: View {
    let project: OnlineProject
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Capsule()
                    .fill(isSelected ? theme.semanticSelectionColor : Color.clear)
                    .frame(width: 3, height: 42)

                OnlineProjectIcon(url: project.iconURL)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(project.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        if !project.authors.isEmpty {
                            Text(project.authors.prefix(2).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(project.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    MetadataLine(items: compactMetadata, font: .caption2)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(projectMeta)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 170, alignment: .trailing)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.compactResultRowHeight, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.72) : Color(nsColor: .separatorColor).opacity(isHovering ? 0.55 : 0.28), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(isHovering && !reduceMotion ? 1.006 : 1, anchor: .center)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                isHovering = hovering
            }
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return theme.semanticSelectionColor.opacity(0.14)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.38 : 0.22)
    }

    private var projectMeta: String {
        let updated = project.updatedAt?.formatted(date: .abbreviated, time: .omitted)
        return [
            "\(project.downloads.formatted()) ↓",
            updated.map { "Updated \($0)" },
            project.source.displayName
        ].compactMap { $0 }.joined(separator: " · ")
    }

    private var compactMetadata: [String] {
        [
            project.projectType.displayTitle,
            project.loaders.prefix(3).map(\.displayTitle).joined(separator: ", "),
            project.categories.prefix(3).joined(separator: ", "),
            project.gameVersions.prefix(3).joined(separator: ", ")
        ]
        .filter { !$0.isEmpty }
    }
}

struct OnlineProjectCard: View {
    let project: OnlineProject
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    OnlineProjectIcon(url: project.iconURL)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(project.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                MetadataLine(items: [project.source.displayName, project.projectType.displayTitle])

                Text(projectMeta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                MetadataLine(items: [
                    project.loaders.prefix(3).map(\.displayTitle).joined(separator: ", "),
                    project.gameVersions.prefix(2).joined(separator: ", ")
                ], font: .caption2)

                HStack(spacing: 6) {
                    PlainStatusText(title: project.clientSide.sideTitle(prefix: "Client"), style: project.clientSide.badgeStyle)
                    PlainStatusText(title: project.serverSide.sideTitle(prefix: "Server"), style: project.serverSide.badgeStyle)
                }

            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(isSelected ? 0.58 : 0.36), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.45), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var projectMeta: String {
        let authors = project.authors.prefix(2).joined(separator: ", ")
        let updated = project.updatedAt?.formatted(date: .abbreviated, time: .omitted)
        return [
            authors.isEmpty ? nil : authors,
            "\(project.downloads.formatted()) downloads",
            updated.map { "Updated \($0)" }
        ].compactMap { $0 }.joined(separator: " · ")
    }
}

struct OnlineProjectIcon: View {
    let url: URL?
    @State private var image: NSImage?
    @State private var failed = false

    private static let cache = NSCache<NSURL, NSImage>()

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed || url == nil {
                Image(systemName: "shippingbox.fill").font(.title3).foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: 42, height: 42)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url) {
            await loadIcon()
        }
    }

    @MainActor
    private func loadIcon() async {
        image = nil
        failed = false
        guard let url else {
            failed = true
            return
        }
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled, let loaded = NSImage(data: data) else { return }
            Self.cache.setObject(loaded, forKey: url as NSURL)
            image = loaded
        } catch {
            if !Task.isCancelled {
                failed = true
            }
        }
    }
}
