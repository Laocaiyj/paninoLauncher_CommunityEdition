import Foundation

extension InstanceIconBackdropStyle {
    func title(language: AppLanguage) -> String {
        switch self {
        case .automatic:
            return localizedString(language, english: "Auto", chinese: "自动", italian: "Auto", french: "Auto", spanish: "Auto")
        case .none:
            return localizedString(language, english: "None", chinese: "无", italian: "Nessuno", french: "Aucun", spanish: "Ninguno")
        case .plate:
            return localizedString(language, english: "Plate", chinese: "底板", italian: "Piastra", french: "Plaque", spanish: "Placa")
        case .glass:
            return localizedString(language, english: "Glass", chinese: "玻璃", italian: "Vetro", french: "Verre", spanish: "Cristal")
        }
    }
}
