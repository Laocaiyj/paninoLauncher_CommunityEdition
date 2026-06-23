import SwiftUI

struct LaunchTaskTimelineMetrics: View {
    let record: TaskRecord
    let language: AppLanguage

    var body: some View {
        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
            LaunchMetric(title: localizedString(language, english: "Current", chinese: "当前文件", italian: "Corrente", french: "Actuel", spanish: "Actual"), value: record.currentFile.isEmpty ? "-" : record.currentFile)
            LaunchMetric(title: localizedString(language, english: "Speed", chinese: "速度", italian: "Velocità", french: "Vitesse", spanish: "Velocidad"), value: record.speed)
            LaunchMetric(title: localizedString(language, english: "ETA", chinese: "剩余", italian: "Tempo", french: "Restant", spanish: "Restante"), value: record.remainingTime)
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .top)]
    }
}

struct LaunchTaskTimelineActions: View {
    let task: TaskSnapshot?
    let language: AppLanguage
    let retry: () -> Void
    let openLogs: () -> Void
    let openTasks: () -> Void
    let openInstanceFolder: () -> Void

    var body: some View {
        if let task, task.state == .succeeded {
            succeededActions
        } else if let task, task.state == .failed {
            failedActions(task)
        } else {
            idleActions
        }
    }

    private var succeededActions: some View {
        HStack {
            Label(localizedString(language, english: "Started successfully", chinese: "已启动", italian: "Avvio riuscito", french: "Lancement réussi", spanish: "Inicio correcto"), systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            Spacer()
            GlassButton(systemImage: "folder", title: AppText.openFolder.localized(language), action: openInstanceFolder)
            GlassButton(systemImage: "terminal", title: AppText.logs.localized(language), action: openLogs)
        }
    }

    private func failedActions(_ task: TaskSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(task.diagnostic?.userSummary ?? task.message ?? task.errorCode ?? localizedString(language, english: "Launch failed", chinese: "启动失败", italian: "Avvio fallito", french: "Échec du lancement", spanish: "Inicio fallido"), systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
            Text(task.diagnostic?.cause ?? recoveryCauses(errorCode: task.errorCode, language: language).first ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                GlassButton(systemImage: "arrow.clockwise", title: localizedString(language, english: "Retry", chinese: "重试", italian: "Riprova", french: "Réessayer", spanish: "Reintentar"), action: retry)
                GlassButton(systemImage: "exclamationmark.triangle", title: localizedString(language, english: "Failure Detail", chinese: "失败原因", italian: "Dettaglio errore", french: "Détail de l'échec", spanish: "Detalle del fallo"), action: openLogs)
            }
        }
    }

    private var idleActions: some View {
        HStack {
            Spacer()
            GlassButton(systemImage: "list.bullet.rectangle", title: AppText.tasks.localized(language), action: openTasks)
        }
    }
}

struct LaunchTimelineRow: View {
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
