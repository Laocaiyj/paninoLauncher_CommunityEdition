import SwiftUI

struct LaunchShelfInstanceRail: View {
    let mode: LaunchShelfMode
    let instances: [GameInstance]
    let selectedID: UUID
    let summaryFor: (GameInstance) -> CoreLaunchInstanceSummary?
    let select: (UUID) -> Void
    let openDetails: (UUID) -> Void
    let toggleFavorite: (UUID, Bool) -> Void
    let hideRecent: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(instances) { instance in
                    LaunchShelfTile(
                        instance: instance,
                        summary: summaryFor(instance),
                        selected: instance.id == selectedID,
                        select: { select(instance.id) },
                        openDetails: { openDetails(instance.id) },
                        toggleFavorite: { toggleFavorite(instance.id, !instance.isFavorite) },
                        hideRecent: hideRecentAction(for: instance)
                    )
                    .frame(width: 236)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func hideRecentAction(for instance: GameInstance) -> (() -> Void)? {
        mode == .recent ? { hideRecent(instance.id) } : nil
    }
}
