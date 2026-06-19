import SwiftUI

struct ProgressRow: View {
    let task: TaskSnapshot?
    let idleTitle: String
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(task?.kind.capitalized ?? AppText.status.localized(theme.language))
                        .font(.headline)
                    Spacer()
                    StatusBadge(title: task?.state.localizedTitle(theme.language) ?? AppText.idle.localized(theme.language), style: badgeStyle)
                }

                if let task {
                    if task.state.isActive {
                        ProgressView()
                    } else {
                        ProgressView(value: task.state == .succeeded ? 1 : 0, total: 1)
                    }

                    Text(task.message ?? "\(task.kind.capitalized) \(task.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                } else {
                    ProgressView(value: 0, total: 1)
                    Text(idleTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if let task {
            return "\(task.kind) \(task.state.localizedTitle(theme.language)). \(task.message ?? task.version)"
        }
        return idleTitle
    }

    private var badgeStyle: StatusBadge.Style {
        guard let task else { return .neutral }
        switch task.state {
        case .queued, .running:
            return .running
        case .succeeded:
            return .success
        case .failed:
            return .error
        case .cancelled:
            return .warning
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text(title)
                    .foregroundStyle(.secondary)
                    .frame(width: 132, alignment: .leading)

                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, theme.fontDensity.settingsRowVerticalPadding)
        }
    }
}
