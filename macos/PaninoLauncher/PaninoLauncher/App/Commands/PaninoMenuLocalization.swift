import AppKit

@MainActor
enum NativeMenuLocalizer {
    static func apply(language: AppLanguage) {
        DispatchQueue.main.async {
            guard let mainMenu = NSApplication.shared.mainMenu else { return }
            for item in mainMenu.items {
                if let title = PaninoSystemMenuTitle.localizedTitle(matching: item.title, language: language) {
                    item.title = title
                }
            }
        }
    }
}

private enum PaninoSystemMenuTitle: CaseIterable {
    case file
    case edit
    case view
    case window
    case help

    static func localizedTitle(matching title: String, language: AppLanguage) -> String? {
        Self.allCases.first { $0.allTitles.contains(title) }?.localized(language)
    }

    private var allTitles: Set<String> {
        Set(AppLanguage.allCases.map(localized))
    }

    private func localized(_ language: AppLanguage) -> String {
        switch self {
        case .file:
            return localizedString(language, english: "File", chinese: "文件", italian: "File", french: "Fichier", spanish: "Archivo")
        case .edit:
            return localizedString(language, english: "Edit", chinese: "编辑", italian: "Modifica", french: "Édition", spanish: "Editar")
        case .view:
            return localizedString(language, english: "View", chinese: "显示", italian: "Vista", french: "Présentation", spanish: "Visualización")
        case .window:
            return localizedString(language, english: "Window", chinese: "窗口", italian: "Finestra", french: "Fenêtre", spanish: "Ventana")
        case .help:
            return localizedString(language, english: "Help", chinese: "帮助", italian: "Aiuto", french: "Aide", spanish: "Ayuda")
        }
    }
}
