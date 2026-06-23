import SwiftUI

struct LaunchInstanceHero: View {
    let instance: GameInstance
    let account: AccountProfile?
    let statusTitle: String
    let statusStyle: StatusBadge.Style
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let onPrimaryAction: () -> Void
    let onCancel: () -> Void
    let canCancel: Bool
    let onManageVersion: () -> Void

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 14) {
                LaunchCoverPreview(instance: instance)

                LaunchInstanceHeroTitle(
                    instance: instance,
                    account: account,
                    statusTitle: statusTitle,
                    statusStyle: statusStyle
                )

                LaunchInstanceHeroMetrics(instance: instance)

                Spacer(minLength: 0)

                LaunchInstanceHeroActions(
                    primaryTitle: primaryTitle,
                    primarySystemImage: primarySystemImage,
                    primaryDisabled: primaryDisabled,
                    canCancel: canCancel,
                    onPrimaryAction: onPrimaryAction,
                    onCancel: onCancel,
                    onManageVersion: onManageVersion
                )
            }
            .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        }
    }
}
