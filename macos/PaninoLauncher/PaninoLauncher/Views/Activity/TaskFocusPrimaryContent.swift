import SwiftUI

struct TaskFocusPrimaryContent: View {
    let record: TaskRecord?
    let coreStatus: String
    let attentionCount: Int
    var showsFacts: Bool = true

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                TaskStateLine(title: stateTitle, style: record?.state.badgeStyle ?? .neutral)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.control + 4)

                if attentionCount > 0 {
                    ImmersiveTextPill(
                        title: localizedString(theme.language, english: "Needs Attention", chinese: "需要处理", italian: "Attenzione", french: "Action requise", spanish: "Atención"),
                        value: "\(attentionCount)"
                    )
                }
            }

            Text(title)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.38), radius: 10, x: 0, y: 4)

            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(3)
                .frame(maxWidth: 720, alignment: .leading)

            if let record, shouldShowProgress(record) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(percentText(record))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text(phaseText(record))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }

                    ProgressView(value: min(max(record.progress, 0), 1), total: 1)
                        .tint(record.state.badgeStyle.color)
                        .frame(maxWidth: 760)
                }
                .padding(14)
                .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.panel, tint: record.state.badgeStyle.color, showsShadow: true)
            }

            if showsFacts {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { facts }
                    VStack(alignment: .leading, spacing: 8) { facts }
                }
            }
        }
        .frame(maxWidth: 820, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var facts: some View {
        ImmersiveTextPill(
            title: localizedString(theme.language, english: "Core", chinese: "Core", italian: "Core", french: "Core", spanish: "Core"),
            value: coreStatus
        )
        ImmersiveTextPill(
            title: localizedString(theme.language, english: "Updated", chinese: "更新", italian: "Aggiornato", french: "Mis à jour", spanish: "Actualizado"),
            value: record?.updatedAt.formatted(date: .omitted, time: .shortened) ?? "-"
        )
        ImmersiveTextPill(
            title: localizedString(theme.language, english: "Kind", chinese: "类型", italian: "Tipo", french: "Type", spanish: "Tipo"),
            value: record?.kindTitle ?? "-"
        )
        if let record {
            ImmersiveTextPill(
                title: localizedString(theme.language, english: "Speed", chinese: "速度", italian: "Velocità", french: "Vitesse", spanish: "Velocidad"),
                value: record.speed
            )
            ImmersiveTextPill(
                title: localizedString(theme.language, english: "ETA", chinese: "剩余", italian: "Tempo", french: "Restant", spanish: "Restante"),
                value: record.remainingTime
            )
        }
    }

    private var stateTitle: String {
        record?.state.title(language: theme.language) ?? AppText.idle.localized(theme.language)
    }

    private var title: String {
        guard let record else {
            return localizedString(theme.language, english: "No Active Task", chinese: "没有正在运行的任务", italian: "Nessuna attività attiva", french: "Aucune tâche active", spanish: "Sin tarea activa")
        }
        guard record.state.isActive else { return record.name }
        let target = record.version.isEmpty ? record.name : record.version
        if record.kind.contains("content") {
            return localizedString(theme.language, english: "Installing \(target)", chinese: "正在安装 \(target)", italian: "Installazione di \(target)", french: "Installation de \(target)", spanish: "Instalando \(target)")
        }
        if record.kind.contains("launch") {
            return localizedString(theme.language, english: "Preparing launch \(target)", chinese: "正在准备启动 \(target)", italian: "Preparazione avvio \(target)", french: "Préparation du lancement \(target)", spanish: "Preparando inicio \(target)")
        }
        if record.kind.contains("install") {
            return localizedString(theme.language, english: "Installing Minecraft \(target)", chinese: "正在安装 Minecraft \(target)", italian: "Installazione Minecraft \(target)", french: "Installation Minecraft \(target)", spanish: "Instalando Minecraft \(target)")
        }
        return record.name
    }

    private var subtitle: String {
        guard let record else {
            return localizedString(theme.language, english: "Ready. Failed, running, and completed work stays below.", chinese: "当前空闲；失败、运行中和已完成任务会在下方显示。", italian: "Pronto. Le attività restano sotto.", french: "Prêt. Les tâches restent ci-dessous.", spanish: "Listo. Las tareas quedan abajo.")
        }
        if record.state.needsAttention, record.progress > 0 {
            return localizedString(theme.language, english: "Stopped at \(percentText(record)): \(phaseText(record))", chinese: "停止于 \(percentText(record))：\(phaseText(record))", italian: "Interrotto al \(percentText(record)): \(phaseText(record))", french: "Arrêté à \(percentText(record)) : \(phaseText(record))", spanish: "Detenido al \(percentText(record)): \(phaseText(record))")
        }
        if record.state == .succeeded {
            return localizedString(theme.language, english: "Finished and verified. You can inspect details from task history.", chinese: "已完成并校验；可在任务历史中查看详情。", italian: "Completato e verificato.", french: "Terminé et vérifié.", spanish: "Finalizado y verificado.")
        }
        return record.message
    }

    private func shouldShowProgress(_ record: TaskRecord) -> Bool {
        record.state.isActive || record.progress > 0
    }

    private func percentText(_ record: TaskRecord) -> String {
        "\(Int((min(max(record.progress, 0), 1) * 100).rounded()))%"
    }

    private func phaseText(_ record: TaskRecord) -> String {
        let phase = record.phaseTitle ?? record.message
        if let index = record.phaseIndex, let count = record.phaseCount, count > 1 {
            return "\(index)/\(count) \(phase)"
        }
        return phase
    }
}
