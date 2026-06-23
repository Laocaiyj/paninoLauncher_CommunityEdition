import SwiftUI

struct TaowaSessionHistoryRow: View {
    let session: CoreTaowaSession
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(session.remoteAddress)
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    StatusBadge(title: session.status, style: style)
                }
                MetadataLine(items: [
                    "local \(session.localPort)",
                    "remote \(session.remotePort)",
                    session.updatedAt.formatted(date: .abbreviated, time: .shortened)
                ])
                if !session.diagnostics.isEmpty {
                    Text(session.diagnostics.first?.userSummary ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.color.opacity(isSelected ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(style.color.opacity(isSelected ? 0.42 : 0.14), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var style: StatusBadge.Style {
        TaowaSessionStatusStyle.badgeStyle(for: session.status)
    }
}
