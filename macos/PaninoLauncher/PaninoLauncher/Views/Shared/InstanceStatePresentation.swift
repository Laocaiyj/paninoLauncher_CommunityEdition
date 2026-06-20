import SwiftUI

extension InstanceStatus {
    func title(language: AppLanguage) -> String {
        switch self {
        case .notInstalled:
            return localizedString(language, english: "Needs Install")
        case .ready:
            return localizedString(language, english: "Ready")
        case .installing:
            return AppText.downloading.localized(language)
        case .running:
            return AppText.running.localized(language)
        case .failed:
            return AppText.failed.localized(language)
        }
    }
}

extension GameInstance {
    func loaderTitle(language: AppLanguage, includesVersion: Bool = false) -> String {
        guard let loader else {
            return localizedString(language, english: "Vanilla")
        }
        let title = loader.title
        guard includesVersion, let loaderVersion, !loaderVersion.isEmpty else {
            return title
        }
        return "\(title) \(loaderVersion)"
    }

    func metadataLine(language: AppLanguage, includesLoaderVersion: Bool = false) -> [String] {
        [
            localizedString(language, english: group),
            "Minecraft \(minecraftVersion)",
            loaderTitle(language: language, includesVersion: includesLoaderVersion)
        ]
    }
}
