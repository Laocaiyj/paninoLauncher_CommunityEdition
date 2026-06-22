import SwiftUI

struct LaunchPreflightRow: View {
    let item: LaunchPreflightItem

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                rowStatus
                    .frame(width: 90, alignment: .leading)
                rowText
                Spacer(minLength: 8)
                rowAction
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    rowStatus
                    Spacer(minLength: 8)
                    rowAction
                }
                rowText
            }
        }
        .padding(10)
        .paninoGlassCard(isSelected: item.state == .needsFix, level: item.state == .needsFix ? .elevatedPanel : .panel, cornerRadius: 8, tint: item.state.badgeStyle.color, showsShadow: item.state == .needsFix)
    }

    private var rowStatus: some View {
        StatusBadge(title: item.state.title(language: theme.language), style: item.state.badgeStyle)
    }

    private var rowText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    @ViewBuilder
    private var rowAction: some View {
        if let actionTitle = item.actionTitle, let action = item.action {
            GlassButton(systemImage: "arrow.right.circle", title: actionTitle, action: action)
                .frame(minWidth: 92, alignment: .trailing)
        }
    }
}
