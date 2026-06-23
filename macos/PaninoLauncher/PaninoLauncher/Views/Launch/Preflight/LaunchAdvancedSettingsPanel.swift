import SwiftUI

private struct LaunchAdvancedSettingsPanel: View {
    @Binding var version: String
    @Binding var memoryMb: Int
    @Binding var javaPath: String
    @Binding var loader: LoaderKind?
    let gameDirectory: String
    let jvmArguments: String
    let preLaunchBehavior: String
    let launchSummary: String
    let javaStatus: JavaRuntimeStatus?
    let checkJava: () -> Void
    let openSettings: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Advanced Launch Settings", chinese: "高级启动设置", italian: "Impostazioni avanzate", french: "Réglages avancés", spanish: "Ajustes avanzados"),
                    systemImage: "slider.horizontal.3"
                )

                Text(launchSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                SettingsRow(title: "Version", systemImage: "cube.box") {
                    PaninoTextInput("Minecraft version", text: $version)
                        .frame(maxWidth: 220)
                }

                SettingsRow(title: "Loader", systemImage: "puzzlepiece.extension") {
                    Picker("Loader", selection: $loader) {
                        Text(localizedString(theme.language, english: "Vanilla", chinese: "原版", italian: "Vanilla", french: "Vanilla", spanish: "Vanilla"))
                            .tag(nil as LoaderKind?)
                        ForEach(LoaderKind.allCases) { loader in
                            Text(loader.title).tag(Optional(loader))
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                }

                SettingsRow(title: "Memory", systemImage: "memorychip") {
                    Stepper(value: $memoryMb, in: PaninoLimits.memoryMb, step: 512) {
                        Text("\(memoryMb) MB")
                            .monospacedDigit()
                            .frame(minWidth: 92, alignment: .leading)
                    }
                }

                SettingsRow(title: "Java", systemImage: "cup.and.saucer") {
                    HStack(spacing: 10) {
                        PaninoTextInput("java or /path/to/java", text: $javaPath, onSubmit: checkJava)
                        GlassButton(systemImage: "checkmark.circle", title: localizedString(theme.language, english: "Check", chinese: "检查", italian: "Controlla", french: "Vérifier", spanish: "Comprobar"), action: checkJava)
                        GlassButton(systemImage: "gearshape", title: AppText.settings.localized(theme.language), action: openSettings)
                    }
                }

                if let javaStatus {
                    StatusBadge(title: javaStatus.displayText, style: javaStatus.isAvailable ? .success : .warning)
                        .textSelection(.enabled)
                }

                LaunchSettingsSummaryRow(
                    title: localizedString(theme.language, english: "Game Dir", chinese: "游戏目录", italian: "Cartella gioco", french: "Dossier du jeu", spanish: "Directorio"),
                    value: gameDirectory.isEmpty
                        ? localizedString(theme.language, english: "Missing directory", chinese: "缺少目录", italian: "Cartella mancante", french: "Dossier manquant", spanish: "Directorio faltante")
                        : gameDirectory
                )
                LaunchSettingsSummaryRow(title: "JVM Args", value: jvmArguments.isEmpty ? "-" : jvmArguments)
                LaunchSettingsSummaryRow(title: localizedString(theme.language, english: "Pre-launch", chinese: "启动前", italian: "Pre-avvio", french: "Avant lancement", spanish: "Preinicio"), value: preLaunchBehavior.isEmpty ? "-" : preLaunchBehavior)
            }
        }
    }
}

private struct LaunchSettingsSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            Text(value)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer()
        }
    }
}
