import SwiftUI

struct EmptyStateInline: View {
    let title: String
    let message: String
    var systemImage: String = "tray"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .paninoTruncation(.title)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .paninoTruncation(.summary(lines: 2))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.24), in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
    }
}
