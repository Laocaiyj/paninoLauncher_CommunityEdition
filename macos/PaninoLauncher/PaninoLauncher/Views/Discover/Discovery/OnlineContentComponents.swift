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
