import SwiftUI

extension LaunchDashboard {
    var javaPreflightItem: LaunchPreflightItem {
        if let resolution = javaResolution(for: selectedInstance) {
            if resolution.isReady {
                return LaunchPreflightItem(
                    id: "java",
                    title: javaPreflightTitle,
                    detail: resolution.conciseStatus,
                    state: .ready
                )
            }
            if resolution.isDownloadable {
                return LaunchPreflightItem(
                    id: "java",
                    title: javaPreflightTitle,
                    detail: resolution.conciseStatus,
                    state: .needsFix,
                    actionTitle: localizedString(theme.language, english: "Download Java \(resolution.requiredMajorVersion)", chinese: "下载 Java \(resolution.requiredMajorVersion)", italian: "Scarica Java \(resolution.requiredMajorVersion)", french: "Télécharger Java \(resolution.requiredMajorVersion)", spanish: "Descargar Java \(resolution.requiredMajorVersion)")
                ) {
                    viewModel.installManagedJavaRuntime(featureVersion: resolution.requiredMajorVersion)
                }
            }
            return LaunchPreflightItem(
                id: "java",
                title: javaPreflightTitle,
                detail: resolution.conciseStatus,
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes"),
                action: openSettings
            )
        }

        guard let javaStatus = viewModel.javaStatus else {
            return LaunchPreflightItem(
                id: "java",
                title: javaPreflightTitle,
                detail: viewModel.javaRuntimeStatus,
                state: .optional,
                actionTitle: localizedString(theme.language, english: "Resolve", chinese: "解析", italian: "Risolvi", french: "Résoudre", spanish: "Resolver"),
                action: refreshSelectedJavaRuntime
            )
        }
        if !javaStatus.isAvailable {
            return LaunchPreflightItem(
                id: "java",
                title: javaPreflightTitle,
                detail: javaStatus.displayText,
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Check", chinese: "检查", italian: "Controlla", french: "Vérifier", spanish: "Comprobar"),
                action: viewModel.checkJavaRuntime
            )
        }
        if let requiredJavaMajor, let current = javaMajorVersion(from: javaStatus.versionSummary), current < requiredJavaMajor {
            return LaunchPreflightItem(
                id: "java",
                title: javaPreflightTitle,
                detail: localizedString(theme.language, english: "Requires Java \(requiredJavaMajor), current runtime looks like Java \(current).", chinese: "需要 Java \(requiredJavaMajor)，当前运行时看起来是 Java \(current)。", italian: "Richiede Java \(requiredJavaMajor), runtime attuale Java \(current).", french: "Nécessite Java \(requiredJavaMajor), runtime actuel Java \(current).", spanish: "Requiere Java \(requiredJavaMajor), runtime actual Java \(current)."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Change Java", chinese: "更换 Java", italian: "Cambia Java", french: "Changer Java", spanish: "Cambiar Java"),
                action: openSettings
            )
        }
        return LaunchPreflightItem(
            id: "java",
            title: javaPreflightTitle,
            detail: requiredJavaMajor.map { localizedString(theme.language, english: "Java runtime is available. Required: Java \($0).", chinese: "Java 可用。需要：Java \($0)。", italian: "Runtime Java disponibile. Richiesto: Java \($0).", french: "Runtime Java disponible. Requis : Java \($0).", spanish: "Runtime Java disponible. Requerido: Java \($0).") } ?? javaStatus.displayText,
            state: .ready
        )
    }

    private var javaPreflightTitle: String {
        AppText.java.localized(theme.language)
    }
}
