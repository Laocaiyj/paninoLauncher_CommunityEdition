import SwiftUI

struct LockfileReviewHeader: View {
    let title: String
    let subtitle: String
    let isBlocked: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isBlocked ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(isBlocked ? Color.orange : Color.green)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .paninoTruncation(.title)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .paninoTruncation(.summary(lines: 2))
            }
            Spacer(minLength: 0)
        }
    }
}
