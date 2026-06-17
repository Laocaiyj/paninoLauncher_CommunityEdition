import SwiftUI

private enum LaunchTimelineStageState {
    case pending
    case running
    case done
    case failed
    case cancelled

    var style: StatusBadge.Style {
        switch self {
        case .pending:
            return .neutral
        case .running:
            return .running
        case .done:
            return .success
        case .failed:
            return .error
        case .cancelled:
            return .warning
        }
    }

    var systemImage: String {
        switch self {
        case .pending:
            return "circle"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .done:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .cancelled:
            return "pause.circle.fill"
        }
    }
}

private struct LaunchTimelineStage: Identifiable {
    let id: String
    let title: String
    let detail: String
    let state: LaunchTimelineStageState
}

struct LaunchTaskTimelinePanel: View {
    let task: TaskSnapshot?
    let record: TaskRecord?
    let idleTitle: String
    let retry: () -> Void
    let repair: () -> Void
    let openLogs: () -> Void
    let openTasks: () -> Void
    let openInstanceFolder: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Launch Timeline", chinese: "启动时间线", italian: "Timeline avvio", french: "Chronologie", spanish: "Cronología"),
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                    Spacer()
                    StatusBadge(title: task?.state.localizedTitle(theme.language) ?? AppText.idle.localized(theme.language), style: taskBadgeStyle)
                }

                ProgressView(value: progressValue, total: 1)

                VStack(spacing: 8) {
                    ForEach(stages) { stage in
                        LaunchTimelineRow(stage: stage)
                    }
                }

                if let record {
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                        LaunchMetric(title: localizedString(theme.language, english: "Current", chinese: "当前文件", italian: "Corrente", french: "Actuel", spanish: "Actual"), value: record.currentFile.isEmpty ? "-" : record.currentFile)
                        LaunchMetric(title: localizedString(theme.language, english: "Speed", chinese: "速度", italian: "Velocità", french: "Vitesse", spanish: "Velocidad"), value: record.speed)
                        LaunchMetric(title: localizedString(theme.language, english: "ETA", chinese: "剩余", italian: "Tempo", french: "Restant", spanish: "Restante"), value: record.remainingTime)
                    }
                } else {
                    Text(idleTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                taskActions
            }
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .top)]
    }

    private var progressValue: Double {
        if let record {
            return min(max(record.progress, 0), 1)
        }
        guard let task else { return 0 }
        switch task.state {
        case .queued:
            return 0.12
        case .running:
            return 0.48
        case .succeeded:
            return 1
        case .failed, .cancelled:
            return 0
        }
    }

    private var taskBadgeStyle: StatusBadge.Style {
        guard let task else { return .neutral }
        switch task.state {
        case .queued, .running:
            return .running
        case .succeeded:
            return .success
        case .failed:
            return .error
        case .cancelled:
            return .warning
        }
    }

    private var stages: [LaunchTimelineStage] {
        let definitions = [
            ("prepare", localizedString(theme.language, english: "Prepare", chinese: "准备", italian: "Prepara", french: "Préparer", spanish: "Preparar"), localizedString(theme.language, english: "Core, account, Java and directory checks.", chinese: "检查 Core、账号、Java 和目录。", italian: "Controlla Core, account, Java e cartella.", french: "Vérifie Core, compte, Java et dossier.", spanish: "Comprueba Core, cuenta, Java y directorio.")),
            ("install", localizedString(theme.language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar"), localizedString(theme.language, english: "Install or repair version and resource files.", chinese: "安装或修复版本与资源文件。", italian: "Installa o ripara versioni e risorse.", french: "Installe ou répare versions et ressources.", spanish: "Instala o repara versiones y recursos.")),
            ("verify", localizedString(theme.language, english: "Verify", chinese: "校验", italian: "Verifica", french: "Vérifier", spanish: "Verificar"), localizedString(theme.language, english: "Check hashes, libraries, assets and natives.", chinese: "校验 hash、库、资源索引和 natives。", italian: "Controlla hash, librerie, asset e native.", french: "Vérifie hashes, bibliothèques, assets et natives.", spanish: "Comprueba hashes, librerías, assets y natives.")),
            ("run", localizedString(theme.language, english: "Run", chinese: "启动", italian: "Avvia", french: "Lancer", spanish: "Ejecutar"), localizedString(theme.language, english: "Start Java and track the game process.", chinese: "启动 Java 并跟踪游戏进程。", italian: "Avvia Java e segue il processo.", french: "Lance Java et suit le processus.", spanish: "Inicia Java y sigue el proceso."))
        ]
        let active = activeStageIndex
        return definitions.enumerated().map { index, definition in
            LaunchTimelineStage(
                id: definition.0,
                title: definition.1,
                detail: definition.2,
                state: stateForStage(index: index, active: active)
            )
        }
    }

    private var activeStageIndex: Int {
        guard let task else { return 0 }
        if let phase = task.diagnostic?.phase.lowercased() {
            if phase == "verify" { return 2 }
            if phase == "launch" || phase == "java" { return 3 }
            if ["download", "loader", "shader", "content", "write"].contains(phase) { return 1 }
            if phase == "prepare" || phase == "preflight" || phase == "solve" || phase == "plan" { return 0 }
        }
        let combined = "\(task.kind) \(task.message ?? "") \(task.errorCode ?? "")".lowercased()
        if combined.contains("hash") || combined.contains("verify") || combined.contains("asset") || combined.contains("library") {
            return 2
        }
        if combined.contains("java") || combined.contains("launch") || combined.contains("process") {
            return 3
        }
        if combined.contains("install") || combined.contains("download") || combined.contains("content") {
            return 1
        }
        return 0
    }

    private func stateForStage(index: Int, active: Int) -> LaunchTimelineStageState {
        guard let task else { return .pending }
        switch task.state {
        case .succeeded:
            return .done
        case .failed:
            if index < active { return .done }
            return index == active ? .failed : .pending
        case .cancelled:
            if index < active { return .done }
            return index == active ? .cancelled : .pending
        case .queued, .running:
            if index < active { return .done }
            return index == active ? .running : .pending
        }
    }

    @ViewBuilder
    private var taskActions: some View {
        if let task, task.state == .succeeded {
            HStack {
                Label(localizedString(theme.language, english: "Started successfully", chinese: "已启动", italian: "Avvio riuscito", french: "Lancement réussi", spanish: "Inicio correcto"), systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language), action: openInstanceFolder)
                GlassButton(systemImage: "terminal", title: AppText.logs.localized(theme.language), action: openLogs)
            }
        } else if let task, task.state == .failed {
            VStack(alignment: .leading, spacing: 8) {
                Label(task.diagnostic?.userSummary ?? task.message ?? task.errorCode ?? localizedString(theme.language, english: "Launch failed", chinese: "启动失败", italian: "Avvio fallito", french: "Échec du lancement", spanish: "Inicio fallido"), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(task.diagnostic?.cause ?? recoveryCauses(errorCode: task.errorCode, language: theme.language).first ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Retry", chinese: "重试", italian: "Riprova", french: "Réessayer", spanish: "Reintentar"), action: retry)
                    GlassButton(systemImage: "exclamationmark.triangle", title: localizedString(theme.language, english: "Failure Detail", chinese: "失败原因", italian: "Dettaglio errore", french: "Détail de l'échec", spanish: "Detalle del fallo"), action: openLogs)
                }
            }
        } else {
            HStack {
                Spacer()
                GlassButton(systemImage: "list.bullet.rectangle", title: AppText.tasks.localized(theme.language), action: openTasks)
            }
        }
    }
}

private struct LaunchTimelineRow: View {
    let stage: LaunchTimelineStage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: stage.state.systemImage)
                .foregroundStyle(stage.state.style.color)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.title)
                    .font(.caption.weight(.semibold))
                Text(stage.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(9)
        .background(stage.state.style.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
