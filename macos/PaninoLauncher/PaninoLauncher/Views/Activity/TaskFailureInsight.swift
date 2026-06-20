import Foundation

struct TaskFailureInsight {
    let userSummary: String?
    let causes: [String]
    let actions: [String]

    init(record: TaskRecord, language: AppLanguage) {
        let sourceText = [record.message, record.errorDetail, record.errorCode]
            .compactMap { $0 }
            .joined(separator: "\n")
        let lowercased = sourceText.lowercased()
        let dependencies = Self.matches(in: sourceText, pattern: #"requires\s+([A-Za-z0-9_.+\-]+)"#)
        let affectedMods = Self.matches(in: sourceText, pattern: #"([A-Za-z0-9_.+\-]+\.jar)\s+requires"#)

        if lowercased.contains("required mod dependencies are missing") || lowercased.contains("dependencies are missing") {
            let dependencyList = dependencies.isEmpty
                ? localizedString(language, english: "one or more dependencies", chinese: "一个或多个依赖", italian: "una o più dipendenze", french: "une ou plusieurs dépendances", spanish: "una o más dependencias")
                : Self.listSummary(dependencies)
            let modList = affectedMods.isEmpty
                ? localizedString(language, english: "an installed mod", chinese: "某个已安装 Mod", italian: "una mod installata", french: "un mod installé", spanish: "un mod instalado")
                : Self.listSummary(affectedMods)
            let shouldRecommendFabricAPI = dependencies.isEmpty || dependencies.contains { $0.lowercased().hasPrefix("fabric-") }
            userSummary = localizedString(
                language,
                english: "This instance cannot start because \(modList) is missing required dependencies: \(dependencyList).",
                chinese: "这个实例暂时不能启动：\(modList) 缺少必需依赖：\(dependencyList)。",
                italian: "Questa istanza non può avviarsi perché \(modList) non trova le dipendenze richieste: \(dependencyList).",
                french: "Cette instance ne peut pas démarrer car \(modList) n'a pas les dépendances requises : \(dependencyList).",
                spanish: "Esta instancia no puede iniciarse porque \(modList) no tiene las dependencias requeridas: \(dependencyList)."
            )
            causes = [
                localizedString(
                    language,
                    english: "A mod was installed without its required dependency modules.",
                    chinese: "有 Mod 已安装，但它依赖的模块没有一起安装。",
                    italian: "Una mod è installata senza i moduli dipendenti richiesti.",
                    french: "Un mod est installé sans ses modules dépendants requis.",
                    spanish: "Un mod está instalado sin sus módulos de dependencia requeridos."
                ),
                localizedString(
                    language,
                    english: "The installed dependency version may not match this Minecraft/loader version.",
                    chinese: "已安装的依赖版本也可能不匹配当前 Minecraft/加载器版本。",
                    italian: "La versione della dipendenza può non corrispondere a Minecraft/loader.",
                    french: "La version de dépendance installée peut ne pas correspondre à Minecraft/loader.",
                    spanish: "La versión de dependencia instalada puede no coincidir con Minecraft/loader."
                )
            ]
            actions = [
                shouldRecommendFabricAPI
                    ? localizedString(
                        language,
                        english: "Install Fabric API compatible with this Minecraft version into the selected instance.",
                        chinese: "在当前实例中安装与该 Minecraft 版本兼容的 Fabric API。",
                        italian: "Installa Fabric API compatibile con questa versione Minecraft nell'istanza.",
                        french: "Installez Fabric API compatible avec cette version Minecraft dans l'instance.",
                        spanish: "Instala Fabric API compatible con esta versión de Minecraft en la instancia."
                    )
                    : localizedString(
                        language,
                        english: "Install the missing dependency mods listed above into the selected instance.",
                        chinese: "把上面列出的缺失依赖 Mod 安装到当前实例。",
                        italian: "Installa nell'istanza le mod dipendenti mancanti elencate sopra.",
                        french: "Installez dans l'instance les mods de dépendance manquants ci-dessus.",
                        spanish: "Instala en la instancia los mods de dependencia faltantes indicados arriba."
                    ),
                localizedString(
                    language,
                    english: "If the dependency cannot be installed, remove or update the affected mod, then launch again.",
                    chinese: "如果依赖无法安装，请移除或更新相关 Mod，然后重新启动。",
                    italian: "Se la dipendenza non è installabile, rimuovi o aggiorna la mod e riavvia.",
                    french: "Si la dépendance ne peut pas être installée, retirez ou mettez à jour le mod, puis relancez.",
                    spanish: "Si no puedes instalar la dependencia, elimina o actualiza el mod afectado y vuelve a iniciar."
                )
            ]
            return
        }

        userSummary = nil
        causes = []
        actions = []
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var values: [String] = []
        for match in regex.matches(in: text, options: [], range: nsRange) {
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { continue }
            let value = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: " .;,)"))
            guard !value.isEmpty, !values.contains(value) else { continue }
            values.append(value)
        }
        return values
    }

    private static func listSummary(_ values: [String]) -> String {
        guard !values.isEmpty else { return "unknown dependency" }
        let visible = values.prefix(3)
        if values.count > visible.count {
            return visible.joined(separator: ", ") + " +\(values.count - visible.count)"
        }
        return visible.joined(separator: ", ")
    }
}
