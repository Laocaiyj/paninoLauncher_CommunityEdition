import Foundation

enum PaninoWindowID {
    static let settings = "panino-settings"
}

enum PaninoSettingsSection: String, CaseIterable, Identifiable {
    case account
    case runtime
    case download
    case appearance
    case advanced

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .account:
            return AppText.account.localized(language)
        case .runtime:
            return localizedString(language, english: "Runtime", chinese: "运行环境", italian: "Runtime", french: "Runtime", spanish: "Runtime")
        case .download:
            return AppText.download.localized(language)
        case .appearance:
            return AppText.appearance.localized(language)
        case .advanced:
            return localizedString(language, english: "Advanced", chinese: "高级", italian: "Avanzate", french: "Avancé", spanish: "Avanzado")
        }
    }

    var systemImage: String {
        switch self {
        case .account:
            return "person.crop.circle"
        case .runtime:
            return "cup.and.saucer"
        case .download:
            return "arrow.down.circle"
        case .appearance:
            return "paintbrush"
        case .advanced:
            return "slider.horizontal.3"
        }
    }
}
