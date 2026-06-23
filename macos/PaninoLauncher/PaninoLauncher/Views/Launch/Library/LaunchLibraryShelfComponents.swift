import SwiftUI

enum LaunchShelfMode: String, CaseIterable, Identifiable {
    case recent
    case favorites
    case installed

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .recent:
            return localizedString(language, english: "Recent", chinese: "最近", italian: "Recenti", french: "Récents", spanish: "Recientes")
        case .favorites:
            return localizedString(language, english: "Favorites", chinese: "收藏", italian: "Preferiti", french: "Favoris", spanish: "Favoritos")
        case .installed:
            return localizedString(language, english: "Installed", chinese: "已安装", italian: "Installate", french: "Installées", spanish: "Instaladas")
        }
    }
}
