import SwiftUI

struct ProgressSummary: View {
    let title: String
    let message: String
    let progress: Double?
    let style: StatusBadge.Style

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .paninoTruncation(.title)
                Spacer()
                StatusBadge(title: statusTitle, style: style)
            }
            ProgressView(value: min(max(progress ?? 0, 0), 1), total: 1)
                .opacity(progress == nil ? 0.35 : 1)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .paninoTruncation(.summary(lines: 2))
                .frame(minHeight: 32, alignment: .topLeading)
        }
    }

    private var statusTitle: String {
        switch style {
        case .success:
            return "Success"
        case .warning:
            return "Warning"
        case .error:
            return "Failed"
        case .download, .running:
            return "Running"
        case .neutral:
            return "Idle"
        }
    }
}
