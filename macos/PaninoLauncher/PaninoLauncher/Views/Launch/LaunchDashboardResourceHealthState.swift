import Foundation

extension LaunchDashboard {
    var conflictCount: Int {
        versionStore.managedAssets.filter { $0.conflictMessage != nil }.count
    }

    var missingDependencyCount: Int {
        versionStore.managedAssets.filter { asset in
            let text = (asset.conflictMessage ?? "") + " " + (asset.metadata.summary ?? "")
            let lowercased = text.lowercased()
            return lowercased.contains("missing") || lowercased.contains("dependency") || lowercased.contains("依赖")
        }.count
    }

    var archivedDeprecatedCount: Int {
        versionStore.managedAssets.filter { asset in
            let text = [asset.name, asset.metadata.displayName, asset.metadata.summary, asset.source]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()
            return text.contains("archived")
                || text.contains("deprecated")
                || text.contains("withheld")
                || text.contains("弃用")
                || text.contains("归档")
        }.count
    }

    var updateCandidateCount: Int {
        versionStore.managedAssets.filter { $0.projectURL != nil || ($0.source?.isEmpty == false) }.count
    }

    var recentChangeCount: Int {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return versionStore.managedAssets.filter { ($0.modifiedAt ?? .distantPast) >= cutoff }.count
    }

    var sourceSummary: String {
        let sources = Set(versionStore.managedAssets.compactMap { $0.source?.isEmpty == false ? $0.source : nil })
        if sources.isEmpty {
            return localizedString(theme.language, english: "Local files", chinese: "本地文件", italian: "File locali", french: "Fichiers locaux", spanish: "Archivos locales")
        }
        return sources.sorted().prefix(3).joined(separator: ", ")
    }

    var resourceSummary: String {
        let count = versionStore.managedAssets.count
        return localizedString(theme.language, english: "\(count) \(versionStore.selectedAssetKind.title)", chinese: "\(count) 个 \(versionStore.selectedAssetKind.title)", italian: "\(count) \(versionStore.selectedAssetKind.title)", french: "\(count) \(versionStore.selectedAssetKind.title)", spanish: "\(count) \(versionStore.selectedAssetKind.title)")
    }
}
