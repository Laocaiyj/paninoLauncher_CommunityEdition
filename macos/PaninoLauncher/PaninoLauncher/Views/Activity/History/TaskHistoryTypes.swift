import SwiftUI

enum TaskHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case failed
    case install
    case download
    case launch
    case diagnostic

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            return localizedString(language, english: "All", chinese: "全部", italian: "Tutte", french: "Toutes", spanish: "Todas")
        case .failed:
            return localizedString(language, english: "Failed", chinese: "失败", italian: "Fallite", french: "Échecs", spanish: "Fallidas")
        case .install:
            return localizedString(language, english: "Install", chinese: "安装", italian: "Installazione", french: "Installation", spanish: "Instalación")
        case .download:
            return localizedString(language, english: "Download", chinese: "下载", italian: "Download", french: "Téléchargement", spanish: "Descarga")
        case .launch:
            return localizedString(language, english: "Launch", chinese: "启动", italian: "Avvio", french: "Lancement", spanish: "Inicio")
        case .diagnostic:
            return localizedString(language, english: "Diagnostic", chinese: "诊断", italian: "Diagnostica", french: "Diagnostic", spanish: "Diagnóstico")
        }
    }

    func includes(_ record: TaskRecord) -> Bool {
        let kind = record.kind.lowercased()
        switch self {
        case .all:
            return true
        case .failed:
            return record.state == .failed || record.state == .interrupted
        case .install:
            return kind.contains("install") || kind.contains("content")
        case .download:
            return kind.contains("download")
        case .launch:
            return kind.contains("launch")
        case .diagnostic:
            return kind.contains("diagnostic") || kind.contains("log") || kind.contains("java") || kind.contains("check") || kind.contains("taowa")
        }
    }
}

enum TaskClearAction: CaseIterable, Identifiable {
    case completed
    case cancelledAndInterrupted
    case failed
    case allFinishedKeepingFailures
    case allFinished
    case allHistory

    var id: String { String(describing: self) }

    var requiresConfirmation: Bool {
        self == .allFinished || self == .allHistory
    }

    var coreStatuses: [String] {
        switch self {
        case .completed:
            return ["succeeded"]
        case .cancelledAndInterrupted:
            return ["cancelled"]
        case .failed:
            return ["failed"]
        case .allFinishedKeepingFailures:
            return ["succeeded", "cancelled", "failed"]
        case .allFinished, .allHistory:
            return ["succeeded", "failed", "cancelled"]
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .completed:
            return localizedString(language, english: "Clear completed", chinese: "清理已完成", italian: "Cancella completate", french: "Effacer terminées", spanish: "Borrar completadas")
        case .cancelledAndInterrupted:
            return localizedString(language, english: "Clear cancelled/interrupted", chinese: "清理取消/中断", italian: "Cancella annullate/interrotte", french: "Effacer annulées/interrompues", spanish: "Borrar canceladas/interrumpidas")
        case .failed:
            return localizedString(language, english: "Clear failed", chinese: "清理失败项", italian: "Cancella fallite", french: "Effacer échecs", spanish: "Borrar fallidas")
        case .allFinishedKeepingFailures:
            return localizedString(language, english: "Clear finished, keep failures", chinese: "清理完成项，保留失败", italian: "Cancella finite, conserva errori", french: "Effacer terminées, garder échecs", spanish: "Borrar finalizadas, conservar fallos")
        case .allFinished:
            return localizedString(language, english: "Clear all finished", chinese: "清理全部结束任务", italian: "Cancella tutte finite", french: "Effacer toutes terminées", spanish: "Borrar todas finalizadas")
        case .allHistory:
            return localizedString(language, english: "Clear all history", chinese: "清空全部历史", italian: "Cancella tutta cronologia", french: "Effacer tout l'historique", spanish: "Borrar todo el historial")
        }
    }

    func statusMessage(language: AppLanguage, localDeleted: Int, coreSummary: CoreTaskHistoryClearResponse?) -> String {
        if let coreSummary {
            return localizedString(
                language,
                english: "Cleaned \(localDeleted) local records. Core deleted \(coreSummary.deleted), kept \(coreSummary.kept), skipped \(coreSummary.skippedActive) active.",
                chinese: "已清理 \(localDeleted) 条本地记录。Core 删除 \(coreSummary.deleted) 条，保留 \(coreSummary.kept) 条，跳过 \(coreSummary.skippedActive) 条活动任务。",
                italian: "Puliti \(localDeleted) record locali. Core ha eliminato \(coreSummary.deleted), mantenuto \(coreSummary.kept), saltato \(coreSummary.skippedActive) attive.",
                french: "\(localDeleted) entrées locales nettoyées. Core a supprimé \(coreSummary.deleted), gardé \(coreSummary.kept), ignoré \(coreSummary.skippedActive) actives.",
                spanish: "Se limpiaron \(localDeleted) registros locales. Core eliminó \(coreSummary.deleted), conservó \(coreSummary.kept), omitió \(coreSummary.skippedActive) activas."
            )
        }
        return localizedString(
            language,
            english: "Cleaned \(localDeleted) local records. Core was unavailable; active tasks were still preserved locally.",
            chinese: "已清理 \(localDeleted) 条本地记录。Core 暂不可用，本地仍保留活动任务。",
            italian: "Puliti \(localDeleted) record locali. Core non disponibile; attività attive conservate localmente.",
            french: "\(localDeleted) entrées locales nettoyées. Core indisponible ; tâches actives conservées localement.",
            spanish: "Se limpiaron \(localDeleted) registros locales. Core no disponible; tareas activas conservadas localmente."
        )
    }
}

extension TaskHistoryRetentionPolicy {
    func title(language: AppLanguage) -> String {
        switch self {
        case .recent20:
            return localizedString(language, english: "Recent 20", chinese: "最近 20 条", italian: "Recenti 20", french: "20 récentes", spanish: "20 recientes")
        case .recent50:
            return localizedString(language, english: "Recent 50", chinese: "最近 50 条", italian: "Recenti 50", french: "50 récentes", spanish: "50 recientes")
        case .sevenDays:
            return localizedString(language, english: "7 days", chinese: "7 天内", italian: "7 giorni", french: "7 jours", spanish: "7 días")
        case .failuresOnly:
            return localizedString(language, english: "Failures only", chinese: "仅失败/中断", italian: "Solo errori", french: "Échecs seulement", spanish: "Solo fallos")
        }
    }
}
