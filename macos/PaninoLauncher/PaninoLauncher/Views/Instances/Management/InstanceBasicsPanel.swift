import SwiftUI

struct InstanceBasicsPanel: View {
    @EnvironmentObject private var theme: ThemeSettings

    @Binding var instance: GameInstance
    let openFolder: () -> Void
    let delete: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Configuration Basics", chinese: "游戏配置基础", italian: "Base configurazione", french: "Base de configuration", spanish: "Base de configuración"),
                        systemImage: "info.circle"
                    )
                    Spacer()
                    GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language), action: openFolder)
                    GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language), action: delete)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    SettingsRow(title: "Name", systemImage: "text.cursor") {
                        PaninoTextInput(localizedString(theme.language, english: "Configuration name", chinese: "游戏配置名称", italian: "Nome configurazione", french: "Nom de configuration", spanish: "Nombre de configuración"), text: $instance.name)
                    }
                    SettingsRow(title: "Group", systemImage: "folder.badge.gearshape") {
                        PaninoTextInput("Group", text: $instance.group)
                    }
                    SettingsRow(title: "Game Dir", systemImage: "folder") {
                        PaninoTextInput("Game directory", text: $instance.gameDirectory)
                    }
                    SettingsRow(title: "Favorite", systemImage: "star") {
                        Toggle("Pinned", isOn: $instance.isFavorite)
                            .toggleStyle(.switch)
                    }
                }
            }
        }
    }
}
