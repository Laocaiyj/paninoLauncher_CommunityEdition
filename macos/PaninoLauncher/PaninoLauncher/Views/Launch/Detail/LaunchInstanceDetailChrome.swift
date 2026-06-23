import SwiftUI

struct LaunchInstanceDetailHeader: View {
    let instance: GameInstance
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let canCancel: Bool
    let back: () -> Void
    let launch: () -> Void
    let cancel: () -> Void
    let editAppearance: () -> Void
    let toggleFavorite: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Button(action: back) {
                        Label(localizedString(theme.language, english: "Back", chinese: "返回", italian: "Indietro", french: "Retour", spanish: "Volver"), systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(instance.name)
                            .font(.title2.bold())
                            .lineLimit(1)
                            .truncationMode(.tail)
                        MetadataLine(items: instance.metadataLine(language: theme.language))
                    }

                    Spacer()
                    LaunchPetPlaceholder()
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { headerActions }
                    VStack(alignment: .leading, spacing: 10) { headerActions }
                }
            }
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        GlassButton(systemImage: primarySystemImage, title: primaryTitle, prominent: true, action: launch)
            .disabled(primaryDisabled)
        if canCancel {
            GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: cancel)
        }
        GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta")) {
            FinderIntegration.openInstanceDirectory(instance)
        }
        GlassButton(systemImage: "paintpalette", title: localizedString(theme.language, english: "Appearance", chinese: "外观", italian: "Aspetto", french: "Apparence", spanish: "Apariencia"), action: editAppearance)
        GlassButton(
            systemImage: instance.isFavorite ? "star.slash" : "star",
            title: instance.isFavorite
                ? localizedString(theme.language, english: "Unpin", chinese: "取消收藏", italian: "Sblocca", french: "Retirer", spanish: "Quitar")
                : localizedString(theme.language, english: "Pin", chinese: "收藏", italian: "Fissa", french: "Épingler", spanish: "Fijar"),
            action: toggleFavorite
        )
    }
}

struct LaunchInstanceDetailSidebar: View {
    @Binding var selectedTab: LaunchInstanceDetailTab
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(LaunchInstanceDetailTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title(language: theme.language))
                            .font(.callout.weight(selectedTab == tab ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                            .padding(.horizontal, 12)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? Color.white : .primary)
                    .background(selectedTab == tab ? theme.semanticSelectionColor : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}
