import SwiftUI

extension CoreConnectionState {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .stopped:
            return localized(language, english: "Core stopped", chinese: "Core 已停止", italian: "Core fermo", french: "Core arrêté", spanish: "Core detenido")
        case .starting:
            return localized(language, english: "Starting Core", chinese: "正在启动 Core", italian: "Avvio Core", french: "Démarrage Core", spanish: "Iniciando Core")
        case .running:
            return localized(language, english: "Core connected", chinese: "Core 已连接", italian: "Core connesso", french: "Core connecté", spanish: "Core conectado")
        case .stopping:
            return localized(language, english: "Stopping Core", chinese: "正在停止 Core", italian: "Arresto Core", french: "Arrêt Core", spanish: "Deteniendo Core")
        case .failed:
            return localized(language, english: "Core failed", chinese: "Core 失败", italian: "Errore Core", french: "Échec Core", spanish: "Error de Core")
        }
    }

    private func localized(
        _ language: AppLanguage,
        english: String,
        chinese: String,
        italian: String,
        french: String,
        spanish: String
    ) -> String {
        switch language {
        case .chineseSimplified: return chinese
        case .english: return english
        case .italian: return italian
        case .french: return french
        case .spanish: return spanish
        }
    }
}

extension AccountConnectionState {
    func localizedTitle(_ language: AppLanguage) -> String {
        switch self {
        case .signedOut:
            return AppText.signedOut.localized(language)
        case .restoring:
            return AppText.restoring.localized(language)
        case .waitingForDeviceCode:
            return AppText.waiting.localized(language)
        case .signedIn(let account):
            switch language {
            case .chineseSimplified:
                return "已登录为 \(account.name)"
            case .english:
                return "Signed in as \(account.name)"
            case .italian:
                return "Connesso come \(account.name)"
            case .french:
                return "Connecté en tant que \(account.name)"
            case .spanish:
                return "Conectado como \(account.name)"
            }
        case .failed:
            return AppText.error.localized(language)
        }
    }
}

extension AccountLoginStatus {
    var badgeStyle: StatusBadge.Style {
        switch self {
        case .signedIn:
            return .success
        case .signedOut:
            return .neutral
        case .expired:
            return .warning
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .signedIn:
            return AppText.signedIn.localized(language)
        case .signedOut:
            return AppText.signedOut.localized(language)
        case .expired:
            return localizedString(language, english: "Expired", chinese: "已过期", italian: "Scaduto", french: "Expiré", spanish: "Expirada")
        }
    }
}
