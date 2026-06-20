import SwiftUI

struct JavaRuntimePolicyOption: Identifiable {
    let id: String
    let title: String
    let detail: String
}

extension JavaRuntimePolicySelector {
    var selectedKey: String {
        let trimmed = javaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return wantsCustomPath ? "custom" : "auto" }
        if let runtime = managedRuntimes.first(where: { samePath($0.javaExecutable, trimmed) }) {
            return managedKey(runtime.id)
        }
        if let runtime = localRuntimes.first(where: { samePath($0.path, trimmed) }) {
            return localKey(runtime.path)
        }
        return "custom"
    }

    var selectedTitle: String {
        options.first(where: { $0.id == selectedKey })?.title
            ?? localizedString(theme.language, english: "Custom path", chinese: "自定义路径", italian: "Percorso personalizzato", french: "Chemin personnalisé", spanish: "Ruta personalizada")
    }

    var selectionSummary: String {
        if let option = options.first(where: { $0.id == selectedKey }) {
            return option.detail
        }
        let trimmed = javaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? customPathHint : trimmed
    }

    var options: [JavaRuntimePolicyOption] {
        var values = [
            JavaRuntimePolicyOption(
                id: "auto",
                title: localizedString(theme.language, english: "Automatic", chinese: "自动", italian: "Automatico", french: "Automatique", spanish: "Automático"),
                detail: automaticDetail
            )
        ]

        values += managedRuntimes.map { runtime in
            JavaRuntimePolicyOption(
                id: managedKey(runtime.id),
                title: "\(runtime.displayName) · Panino",
                detail: runtime.detailText
            )
        }

        values += localRuntimes.filter(\.isAvailable).map { runtime in
            JavaRuntimePolicyOption(
                id: localKey(runtime.path),
                title: runtime.source,
                detail: runtime.displayText
            )
        }

        if showCustomPath {
            values.append(
                JavaRuntimePolicyOption(
                    id: "custom",
                    title: localizedString(theme.language, english: "Custom path", chinese: "自定义路径", italian: "Percorso personalizzato", french: "Chemin personnalisé", spanish: "Ruta personalizada"),
                    detail: customPathHint
                )
            )
        }
        return values
    }

    var automaticDetail: String {
        localizedString(
            theme.language,
            english: "Panino chooses Java from the Minecraft manifest and downloads it when needed.",
            chinese: "Panino 会按 Minecraft 清单自动选择 Java，并在缺失时下载。",
            italian: "Panino sceglie Java dal manifest Minecraft e lo scarica se manca.",
            french: "Panino choisit Java depuis le manifeste Minecraft et le télécharge si nécessaire.",
            spanish: "Panino elige Java desde el manifiesto de Minecraft y lo descarga si falta."
        )
    }

    var customPathHint: String {
        localizedString(theme.language, english: "Enter a Java executable path.", chinese: "填写 Java 可执行文件路径。", italian: "Inserisci il percorso Java.", french: "Saisissez le chemin Java.", spanish: "Introduce la ruta de Java.")
    }

    func applySelection(_ key: String) {
        if key == "auto" {
            wantsCustomPath = false
            javaPath = ""
            return
        }
        if key == "custom" {
            wantsCustomPath = true
            return
        }
        if key.hasPrefix("managed:"),
           let runtime = managedRuntimes.first(where: { managedKey($0.id) == key }) {
            wantsCustomPath = false
            javaPath = runtime.javaExecutable
            return
        }
        if key.hasPrefix("local:"),
           let runtime = localRuntimes.first(where: { localKey($0.path) == key }) {
            wantsCustomPath = false
            javaPath = runtime.path
        }
    }

    func managedKey(_ id: String) -> String {
        "managed:\(id)"
    }

    func localKey(_ path: String) -> String {
        "local:\(path)"
    }

    func samePath(_ lhs: String, _ rhs: String) -> Bool {
        URL(fileURLWithPath: lhs).standardizedFileURL.path == URL(fileURLWithPath: rhs).standardizedFileURL.path
    }
}
