import SwiftUI

struct InstallTargetSection: View {
    let release: OnlineRelease
    let currentMinecraftVersion: String?
    let targetResolution: CoreContentResolveTargetsResponse?
    @Binding var selectedTargetID: String?
    let targetFailure: String?
    let install: (CoreContentTargetCandidate?) -> Void
    let openTasks: () -> Void

    @EnvironmentObject var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var showAllTargets = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localizedString(theme.language, english: "Install Target", chinese: "安装目标", italian: "Destinazione installazione", french: "Cible d'installation", spanish: "Destino de instalación"))
                    .font(.headline)
                Spacer()
                if hasVersionMatchedTarget {
                    CountText(value: versionMatchedTargets.count, style: .download)
                }
            }

            if let targetFailure {
                Label(localizedOnlineError(targetFailure, language: theme.language), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            } else if targetResolution != nil {
                if versionMatchedTargets.isEmpty {
                    Label(noMatchingInstanceMessage, systemImage: "tray")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(visibleTargets) { target in
                            Button {
                                selectedTargetID = target.id
                            } label: {
                                TargetCandidateRow(
                                    target: target,
                                    selected: target.id == activeTarget?.id,
                                    recommended: target.id == recommendedTarget?.id
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if versionMatchedTargets.count > 5 {
                            Button {
                                withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                                    showAllTargets.toggle()
                                }
                            } label: {
                                Label(showMoreTargetsTitle, systemImage: showAllTargets ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.semanticSelectionColor)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(localizedString(theme.language, english: "Matching local instances...", chinese: "正在匹配本地实例...", italian: "Ricerca istanze locali...", french: "Recherche des instances locales...", spanish: "Buscando instancias locales..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GlassButton(systemImage: primaryButtonIcon, title: primaryButtonTitle, prominent: true) {
                        install(activeTarget)
                    }
                        .disabled(!canInstall)
                    GlassButton(systemImage: "list.bullet.rectangle", title: localizedString(theme.language, english: "Tasks", chinese: "任务", italian: "Attività", french: "Tâches", spanish: "Tareas"), action: openTasks)
                }

                if !canInstall {
                    Text(localizedString(theme.language, english: "Missing downloadable file for the selected release.", chinese: "所选版本缺少可下载文件。", italian: "File scaricabile mancante.", french: "Fichier téléchargeable manquant.", spanish: "Falta archivo descargable."))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

}
