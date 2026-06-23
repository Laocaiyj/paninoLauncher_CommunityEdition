import SwiftUI

struct ManagedAssetGroupView: View {
    let title: String
    let assets: [ManagedAsset]
    let selectedAssetIDs: Set<String>
    let toggleSelection: (String) -> Void
    let toggleAsset: (ManagedAsset) -> Void
    let linkAsset: (ManagedAsset) -> Void
    let deleteAsset: (ManagedAsset) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            ForEach(assets) { asset in
                HStack(alignment: .center, spacing: 8) {
                    Button {
                        toggleSelection(asset.id)
                    } label: {
                        Image(systemName: selectedAssetIDs.contains(asset.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedAssetIDs.contains(asset.id) ? theme.semanticSelectionColor : .secondary)
                            .frame(width: 22)
                    }
                    .buttonStyle(.plain)

                    ManagedAssetRow(asset: asset) {
                        toggleAsset(asset)
                    } onLink: {
                        linkAsset(asset)
                    } onDelete: {
                        deleteAsset(asset)
                    }
                }
            }
        }
    }
}
