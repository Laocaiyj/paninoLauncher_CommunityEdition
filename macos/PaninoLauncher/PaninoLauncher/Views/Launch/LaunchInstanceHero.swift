import SwiftUI

struct LaunchInstanceHero: View {
    let instance: GameInstance
    let account: AccountProfile?
    let statusTitle: String
    let statusStyle: StatusBadge.Style
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let onPrimaryAction: () -> Void
    let onCancel: () -> Void
    let canCancel: Bool
    let onManageVersion: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 14) {
                LaunchCoverPreview(instance: instance)

                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(instance.name)
                                .font(.title2.bold())
                                .lineLimit(1)
                                .truncationMode(.tail)
                            StatusBadge(title: statusTitle, style: statusStyle)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(instance.name)
                                .font(.title2.bold())
                                .lineLimit(2)
                                .truncationMode(.tail)
                            StatusBadge(title: statusTitle, style: statusStyle)
                        }
                    }

                    heroMetadata
                }

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                    LaunchMetric(
                        title: localizedString(theme.language, english: "Last Launch", chinese: "最近启动", italian: "Ultimo avvio", french: "Dernier lancement", spanish: "Último inicio"),
                        value: instance.lastLaunchedAt?.formatted(date: .abbreviated, time: .shortened)
                            ?? localizedString(theme.language, english: "Never", chinese: "从未", italian: "Mai", french: "Jamais", spanish: "Nunca")
                    )
                    LaunchMetric(
                        title: localizedString(theme.language, english: "Play Time", chinese: "游戏时长", italian: "Tempo gioco", french: "Temps de jeu", spanish: "Tiempo jugado"),
                        value: formattedPlayDuration(instance.totalPlaySeconds ?? 0, language: theme.language)
                    )
                    LaunchMetric(
                        title: localizedString(theme.language, english: "Directory", chinese: "目录", italian: "Cartella", french: "Dossier", spanish: "Directorio"),
                        value: instance.gameDirectory.isEmpty
                            ? localizedString(theme.language, english: "Missing directory", chinese: "缺少目录", italian: "Cartella mancante", french: "Dossier manquant", spanish: "Directorio faltante")
                            : instance.gameDirectory
                    )
                }

                Spacer(minLength: 0)
                actionStack
            }
            .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        }
    }

    private var heroMetadata: some View {
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

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 118), spacing: 8, alignment: .top)]
    }

    private var actionStack: some View {
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

private struct LaunchCoverPreview: View {
    let instance: GameInstance
    @State private var image: NSImage?
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.08, anchor: UnitPoint(x: CGFloat(instance.coverFocusX), y: CGFloat(instance.coverFocusY)))
                        .blur(radius: instance.coverBlur * 14, opaque: true)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [
                            instance.coverTintColor.opacity(0.42),
                            Color(nsColor: .controlBackgroundColor).opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: instance.resolvedIconName)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(instance.coverTintColor)
                            .frame(width: 54, height: 54)
                            .background(iconBackdrop, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("Minecraft \(instance.minecraftVersion)")
                            .font(.headline)
                            .lineLimit(1)
                        Text(instance.loaderTitle(language: theme.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(16)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
                }
                LinearGradient(
                    colors: [.clear, .black.opacity(0.16 + instance.coverDim * 0.52)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .task(id: instance.coverPath) {
            guard !instance.coverPath.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: instance.coverPath, size: CGSize(width: 420, height: 300))
        }
    }

    private var iconBackdrop: Color {
        switch instance.iconBackdropStyle {
        case .automatic:
            return instance.coverPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.clear : Color.black.opacity(0.24)
        case .none:
            return Color.clear
        case .plate:
            return Color.black.opacity(0.34)
        case .glass:
            return Color.white.opacity(0.18)
        }
    }
}
