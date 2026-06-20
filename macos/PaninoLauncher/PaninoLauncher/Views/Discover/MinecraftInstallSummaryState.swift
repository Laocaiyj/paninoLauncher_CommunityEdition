import Foundation

extension MinecraftVersionInstallDetailPage {
    var shaderFallbackSummary: String? {
        guard
            let from = preflight?.shaderFallbackFrom,
            let to = preflight?.shaderFallbackTo
        else {
            return nil
        }
        return localizedString(
            theme.language,
            english: "Using compatible \(to) release because \(from) has no direct shader loader release.",
            chinese: "由于 \(from) 没有直接适配的光影加载器版本，将使用兼容的 \(to) release。",
            italian: "Uso release \(to) compatibile perché \(from) non ha una release diretta.",
            french: "Utilise la release \(to) compatible car \(from) n'a pas de release directe.",
            spanish: "Usando release compatible \(to) porque \(from) no tiene release directa."
        )
    }

    var installerProbeSummary: String? {
        guard let status = preflight?.installerProbeStatus, !status.isEmpty else {
            return nil
        }
        if status.hasPrefix("failed:") {
            return localizedString(
                theme.language,
                english: "Preflight could not fully probe the installer URL; install will still attempt the real download.",
                chinese: "预检未能完整探测安装器 URL；安装时仍会尝试真实下载。",
                italian: "Il preflight non ha verificato completamente l'URL installer; l'installazione tenterà comunque il download.",
                french: "Le précontrôle n'a pas entièrement testé l'URL de l'installateur ; l'installation tentera le téléchargement.",
                spanish: "La prevalidación no pudo verificar completamente la URL; la instalación intentará la descarga real."
            )
        }
        return status
    }

    var effectiveComponentSummary: String {
        [
            loader?.title ?? localizedString(theme.language, english: "Vanilla"),
            effectiveShaderLoader?.title
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    var javaRuntimePlanSummary: String {
        localizedString(
            theme.language,
            english: "\(version.javaRequirement) · Panino resolves from the Minecraft manifest and downloads the runtime inside the launcher when missing.",
            chinese: "\(version.javaRequirement) · Panino 会按 Minecraft 清单解析，缺失时在启动器内下载。",
            italian: "\(version.javaRequirement) · Panino risolve dal manifest Minecraft e scarica il runtime se manca.",
            french: "\(version.javaRequirement) · Panino résout depuis le manifeste Minecraft et télécharge le runtime si nécessaire.",
            spanish: "\(version.javaRequirement) · Panino resuelve desde el manifiesto de Minecraft y descarga el runtime si falta."
        )
    }

    var shaderHelpText: String {
        localizedString(
            theme.language,
            english: "Core installs Iris and Oculus as matching Modrinth mods. OptiFine requires a manual download if the upstream download is unavailable.",
            chinese: "Core 会将 Iris 和 Oculus 作为匹配的 Modrinth Mod 安装；若上游没有可用公开下载，OptiFine 需要手动安装。",
            italian: "Core installa Iris e Oculus da Modrinth. OptiFine può richiedere installazione manuale.",
            french: "Core installe Iris et Oculus depuis Modrinth. OptiFine peut nécessiter une installation manuelle.",
            spanish: "Core instala Iris y Oculus desde Modrinth. OptiFine puede requerir instalación manual."
        )
    }

    var loaderInstallNotice: String {
        localizedString(
            theme.language,
            english: "Core creates an isolated launch profile for the selected loader and records local instance metadata after installation.",
            chinese: "Core 会为所选 Loader 创建隔离的可启动 profile，并在安装后写入本地实例元数据。",
            italian: "Core crea un profilo isolato per il loader selezionato e salva i metadati locali.",
            french: "Core crée un profil isolé pour le loader choisi et enregistre les métadonnées locales.",
            spanish: "Core crea un perfil aislado para el loader seleccionado y guarda los metadatos locales."
        )
    }
}
