import SwiftUI

extension LogPanelTab {
    func title(language: AppLanguage) -> String {
        switch self {
        case .core:
            return "Core"
        case .game:
            return localizedString(language, english: "Game", chinese: "游戏", italian: "Gioco", french: "Jeu", spanish: "Juego")
        }
    }
}

extension LogFilterLevel {
    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            return localizedString(language, english: "All", chinese: "全部", italian: "Tutti", french: "Tous", spanish: "Todos")
        case .info:
            return "Info"
        case .warning:
            return localizedString(language, english: "Warning", chinese: "警告", italian: "Avviso", french: "Avertissement", spanish: "Aviso")
        case .error:
            return AppText.error.localized(language)
        }
    }
}
