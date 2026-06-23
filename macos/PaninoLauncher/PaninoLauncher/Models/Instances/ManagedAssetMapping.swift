import Foundation

extension ManagedAsset {
    static func fromCoreAsset(
        _ coreAsset: CoreManagedAsset,
        links: [String: AssetManualLink]
    ) -> ManagedAsset {
        let url = URL(fileURLWithPath: coreAsset.path)
        let link = links[coreAsset.path]
        return ManagedAsset(
            id: coreAsset.id,
            name: coreAsset.name,
            url: url,
            isEnabled: coreAsset.isEnabled,
            conflictMessage: coreAsset.conflictMessage,
            metadata: coreAsset.metadata,
            fileSizeBytes: coreAsset.fileSizeBytes,
            modifiedAt: coreAsset.modifiedAt,
            source: link?.source ?? coreAsset.source,
            projectURL: link?.projectURL ?? coreAsset.projectURL
        )
    }

    static func sort(_ lhs: ManagedAsset, _ rhs: ManagedAsset, by sort: ManagedAssetSort) -> Bool {
        switch sort {
        case .name:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case .status:
            if lhs.isEnabled != rhs.isEnabled { return lhs.isEnabled && !rhs.isEnabled }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case .source:
            return (lhs.source ?? "").localizedCaseInsensitiveCompare(rhs.source ?? "") == .orderedAscending
        case .updated:
            return (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        case .size:
            return lhs.fileSizeBytes > rhs.fileSizeBytes
        }
    }
}
