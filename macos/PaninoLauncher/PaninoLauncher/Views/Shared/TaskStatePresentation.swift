import SwiftUI

extension TaskState {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .queued:
            switch language {
            case .chineseSimplified: return "排队中"
            case .english: return "Queued"
            case .italian: return "In coda"
            case .french: return "En file"
            case .spanish: return "En cola"
            }
        case .running:
            return AppText.running.localized(language)
        case .succeeded:
            return AppText.ready.localized(language)
        case .failed:
            return AppText.failed.localized(language)
        case .cancelled:
            return AppText.cancel.localized(language)
        }
    }
}

extension TaskRecordState {
    var badgeStyle: StatusBadge.Style {
        switch self {
        case .queued, .running:
            return .running
        case .succeeded:
            return .success
        case .failed:
            return .error
        case .cancelled:
            return .warning
        case .interrupted:
            return .warning
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .queued:
            return localizedString(language, english: "Queued", chinese: "排队中", italian: "In coda", french: "En file", spanish: "En cola")
        case .running:
            return AppText.running.localized(language)
        case .succeeded:
            return localizedString(language, english: "Succeeded", chinese: "已完成", italian: "Completata", french: "Réussie", spanish: "Completada")
        case .failed:
            return AppText.failed.localized(language)
        case .cancelled:
            return AppText.cancel.localized(language)
        case .interrupted:
            return localizedString(language, english: "Interrupted", chinese: "已中断", italian: "Interrotta", french: "Interrompue", spanish: "Interrumpida")
        }
    }
}

extension TaskRecord {
    var iconName: String {
        let lowercased = kind.lowercased()
        if lowercased.contains("install") {
            return "square.and.arrow.down"
        }
        if lowercased.contains("download") {
            return "arrow.down.circle"
        }
        if lowercased.contains("check") || lowercased.contains("verify") {
            return "checkmark.seal"
        }
        if lowercased.contains("launch") {
            return "play.circle"
        }
        if lowercased.contains("log") {
            return "doc.text"
        }
        return "gearshape.2"
    }
}
