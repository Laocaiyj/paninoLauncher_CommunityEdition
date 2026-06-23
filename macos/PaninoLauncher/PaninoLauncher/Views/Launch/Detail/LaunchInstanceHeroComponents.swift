import SwiftUI

struct LaunchInstanceHeroTitle: View {
    let instance: GameInstance
    let account: AccountProfile?
    let statusTitle: String
    let statusStyle: StatusBadge.Style

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    instanceName(lineLimit: 1)
                    StatusBadge(title: statusTitle, style: statusStyle)
                }

                VStack(alignment: .leading, spacing: 6) {
                    instanceName(lineLimit: 2)
                    StatusBadge(title: statusTitle, style: statusStyle)
                }
            }

            metadata
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 6) {
            MetadataLine(items: [
                "Minecraft \(instance.minecraftVersion)",
                instance.loaderTitle(language: theme.language)
            ])
            if let account, account.loginStatus == .expired {
                StatusBadge(title: account.name, style: .warning)
            } else if account == nil {
                StatusBadge(title: localizedString(theme.language, english: "Offline fallback"), style: .warning)
            }
        }
    }

    private func instanceName(lineLimit: Int) -> some View {
        Text(instance.name)
            .font(.title2.bold())
            .lineLimit(lineLimit)
            .truncationMode(.tail)
    }
}

struct LaunchInstanceHeroMetrics: View {
    let instance: GameInstance

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
            LaunchMetric(
                title: localizedString(theme.language, english: "Last Launch", chinese: "最近启动", italian: "Ultimo avvio", french: "Dernier lancement", spanish: "Último inicio"),
                value: lastLaunchValue
            )
            LaunchMetric(
                title: localizedString(theme.language, english: "Play Time", chinese: "游戏时长", italian: "Tempo gioco", french: "Temps de jeu", spanish: "Tiempo jugado"),
                value: formattedPlayDuration(instance.totalPlaySeconds ?? 0, language: theme.language)
            )
            LaunchMetric(
                title: localizedString(theme.language, english: "Directory", chinese: "目录", italian: "Cartella", french: "Dossier", spanish: "Directorio"),
                value: directoryValue
            )
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 118), spacing: 8, alignment: .top)]
    }

    private var lastLaunchValue: String {
        instance.lastLaunchedAt?.formatted(date: .abbreviated, time: .shortened)
            ?? localizedString(theme.language, english: "Never", chinese: "从未", italian: "Mai", french: "Jamais", spanish: "Nunca")
    }

    private var directoryValue: String {
        instance.gameDirectory.isEmpty
            ? localizedString(theme.language, english: "Missing directory", chinese: "缺少目录", italian: "Cartella mancante", french: "Dossier manquant", spanish: "Directorio faltante")
            : instance.gameDirectory
    }
}

struct LaunchInstanceHeroActions: View {
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let canCancel: Bool
    let onPrimaryAction: () -> Void
    let onCancel: () -> Void
    let onManageVersion: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                primaryLaunchButton
                secondaryActionButtons
            }

            VStack(alignment: .leading, spacing: 8) {
                primaryLaunchButton
                secondaryActionButtons
            }
        }
    }

    private var primaryLaunchButton: some View {
        GlassButton(systemImage: primarySystemImage, title: primaryTitle, prominent: true, action: onPrimaryAction)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(primaryDisabled)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .center)
    }

    private var secondaryActionButtons: some View {
        HStack(spacing: 8) {
            GlassButton(
                systemImage: "cube.box",
                title: localizedString(theme.language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión"),
                action: onManageVersion
            )
            .frame(maxWidth: .infinity)
            if canCancel {
                GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: onCancel)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
