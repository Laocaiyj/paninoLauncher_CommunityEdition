import SwiftUI

struct TaskRecordDetailSheet: View {
    let record: TaskRecord
    let canRetry: Bool
    let onRetry: () -> Void
    let onOpenLogs: () -> Void
    let onExportDiagnostics: () -> Void
    let onOpenFolder: () -> Void
    let diagnosticActionTitle: String?
    let diagnosticActionSystemImage: String
    let onDiagnosticAction: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.dismiss) private var dismiss
    private var recoveryRecords: [TaskRecoveryRecord] {
        TaskRecoveryRecord.records(for: record)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.name)
                        .font(.title3.weight(.semibold))
                    Text(record.kindTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TaskStateLine(title: record.state.title(language: theme.language), style: record.state.badgeStyle)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                TaskFact(title: localizedString(theme.language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión"), value: record.version.isEmpty ? "-" : record.version)
                TaskFact(title: localizedString(theme.language, english: "Created", chinese: "创建", italian: "Creato", french: "Créée", spanish: "Creada"), value: record.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "-")
                TaskFact(title: localizedString(theme.language, english: "Finished", chinese: "结束", italian: "Terminato", french: "Terminée", spanish: "Finalizada"), value: record.finishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "-")
                TaskFact(title: localizedString(theme.language, english: "Error", chinese: "错误", italian: "Errore", french: "Erreur", spanish: "Error"), value: record.errorCode ?? "-")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString(theme.language, english: "Message", chinese: "消息", italian: "Messaggio", french: "Message", spanish: "Mensaje"))
                    .font(.headline)
                Text(record.message)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .paninoGlassCard(level: .panel, cornerRadius: 8)
            }

            if !recoveryRecords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString(theme.language, english: "Recovery Records", chinese: "可回滚记录", italian: "Registri di ripristino", french: "Journaux de restauration", spanish: "Registros de reversión"))
                        .font(.headline)
                    ForEach(recoveryRecords) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.systemImage)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title.localized(theme.language))
                                    .font(.callout.weight(.medium))
                                Text(item.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .paninoGlassCard(level: .panel, cornerRadius: 8)
                    }
                }
            }

            if record.state.needsAttention {
                Text(record.advice.localizedRecoveryAdvice(theme.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paninoGlassCard(isSelected: true, level: .elevatedPanel, cornerRadius: 8, tint: .orange)
            }

            Spacer()

            HStack {
                GlassButton(systemImage: "xmark", title: AppText.cancel.localized(theme.language)) {
                    dismiss()
                }
                Spacer()
                GlassButton(systemImage: "terminal", title: AppText.logs.localized(theme.language), action: onOpenLogs)
                GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter diagnostic", spanish: "Exportar diagnóstico"), action: onExportDiagnostics)
                GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta"), action: onOpenFolder)
                if let diagnosticActionTitle {
                    GlassButton(systemImage: diagnosticActionSystemImage, title: diagnosticActionTitle, prominent: !canRetry, action: onDiagnosticAction)
                }
                if canRetry {
                    GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Retry", chinese: "重试", italian: "Riprova", french: "Réessayer", spanish: "Reintentar"), prominent: true, action: onRetry)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
    }
}

private struct TaskRecoveryRecord: Identifiable, Equatable {
    let id: String
    let title: TaskRecoveryTitle
    let path: String
    let systemImage: String

    static func records(for record: TaskRecord) -> [TaskRecoveryRecord] {
        var records: [TaskRecoveryRecord] = []
        let combinedText = [record.message, record.errorDetail].compactMap { $0 }.joined(separator: "\n")
        appendMarkerRecord(
            to: &records,
            id: "rollback",
            title: TaskRecoveryTitle(english: "Rollback Record", chinese: "回滚记录", italian: "Registro rollback", french: "Journal de restauration", spanish: "Registro de reversión"),
            systemImage: "arrow.uturn.backward.circle",
            markers: ["Rollback record:", "回滚记录："],
            in: combinedText
        )
        appendMarkerRecord(
            to: &records,
            id: "plan",
            title: TaskRecoveryTitle(english: "Install Plan", chinese: "安装计划", italian: "Piano installazione", french: "Plan d'installation", spanish: "Plan de instalación"),
            systemImage: "list.bullet.rectangle",
            markers: ["Plan:", "计划："],
            in: combinedText
        )
        appendMarkerRecord(
            to: &records,
            id: "execution",
            title: TaskRecoveryTitle(english: "Execution Result", chinese: "执行结果", italian: "Risultato esecuzione", french: "Résultat d'exécution", spanish: "Resultado de ejecución"),
            systemImage: "checklist",
            markers: ["Execution:", "执行："],
            in: combinedText
        )

        if records.isEmpty, let gameDir = record.gameDir?.trimmingCharacters(in: .whitespacesAndNewlines), !gameDir.isEmpty {
            records.append(contentsOf: inferredRecords(kind: record.kind, gameDir: gameDir))
        }
        return deduped(records)
    }

    private static func appendMarkerRecord(
        to records: inout [TaskRecoveryRecord],
        id: String,
        title: TaskRecoveryTitle,
        systemImage: String,
        markers: [String],
        in text: String
    ) {
        for marker in markers {
            if let path = path(after: marker, in: text) {
                records.append(TaskRecoveryRecord(id: id, title: title, path: path, systemImage: systemImage))
                return
            }
        }
    }

    private static func path(after marker: String, in text: String) -> String? {
        guard let markerRange = text.range(of: marker) else { return nil }
        let tail = text[markerRange.upperBound...]
        let terminators = [" Rollback record:", " Plan:", " Execution:", " 回滚记录：", " 计划：", " 执行：", "\n"]
        let end = terminators
            .compactMap { token in tail.range(of: token)?.lowerBound }
            .min() ?? tail.endIndex
        let path = String(tail[..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".)"))
        return path.isEmpty ? nil : path
    }

    private static func inferredRecords(kind: String, gameDir: String) -> [TaskRecoveryRecord] {
        let lowered = kind.lowercased()
        if lowered.contains("performance-pack") {
            return [
                TaskRecoveryRecord(
                    id: "performance-pack-lock",
                    title: TaskRecoveryTitle(english: "Rollback Record", chinese: "回滚记录", italian: "Registro rollback", french: "Journal de restauration", spanish: "Registro de reversión"),
                    path: "\(gameDir)/downloads/performance-pack-lock.json",
                    systemImage: "arrow.uturn.backward.circle"
                )
            ]
        }
        if lowered.contains("content") {
            return [
                TaskRecoveryRecord(
                    id: "content-install-lock",
                    title: TaskRecoveryTitle(english: "Rollback Record", chinese: "回滚记录", italian: "Registro rollback", french: "Journal de restauration", spanish: "Registro de reversión"),
                    path: "\(gameDir)/downloads/content-install-lock.json",
                    systemImage: "arrow.uturn.backward.circle"
                ),
                TaskRecoveryRecord(
                    id: "install-plan-graph",
                    title: TaskRecoveryTitle(english: "Install Plan", chinese: "安装计划", italian: "Piano installazione", french: "Plan d'installation", spanish: "Plan de instalación"),
                    path: "\(gameDir)/downloads/install-plan-graph.json",
                    systemImage: "list.bullet.rectangle"
                ),
                TaskRecoveryRecord(
                    id: "install-plan-execution",
                    title: TaskRecoveryTitle(english: "Execution Result", chinese: "执行结果", italian: "Risultato esecuzione", french: "Résultat d'exécution", spanish: "Resultado de ejecución"),
                    path: "\(gameDir)/downloads/install-plan-execution.json",
                    systemImage: "checklist"
                )
            ]
        }
        return []
    }

    private static func deduped(_ records: [TaskRecoveryRecord]) -> [TaskRecoveryRecord] {
        var seen = Set<String>()
        return records.filter { record in
            let key = record.path
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

private struct TaskRecoveryTitle: Equatable {
    let english: String
    let chinese: String
    let italian: String
    let french: String
    let spanish: String

    func localized(_ language: AppLanguage) -> String {
        localizedString(language, english: english, chinese: chinese, italian: italian, french: french, spanish: spanish)
    }
}
