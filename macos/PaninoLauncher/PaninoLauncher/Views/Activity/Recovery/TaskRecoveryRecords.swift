import Foundation

struct TaskRecoveryRecord: Identifiable, Equatable {
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

struct TaskRecoveryTitle: Equatable {
    let english: String
    let chinese: String
    let italian: String
    let french: String
    let spanish: String

    func localized(_ language: AppLanguage) -> String {
        localizedString(language, english: english, chinese: chinese, italian: italian, french: french, spanish: spanish)
    }
}
