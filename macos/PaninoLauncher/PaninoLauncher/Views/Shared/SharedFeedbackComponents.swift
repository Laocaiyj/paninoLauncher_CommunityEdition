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

struct InlineBanner<Actions: View>: View {
    let title: String
    let message: String
    var style: StatusBadge.Style = .neutral
    private let actions: () -> Actions

    init(
        title: String,
        message: String,
        style: StatusBadge.Style = .neutral,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.message = message
        self.style = style
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(style.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .paninoTruncation(.title)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .paninoTruncation(.summary(lines: 2))
            }
            Spacer(minLength: 10)
            actions()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(style.color.opacity(0.10), in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                .stroke(style.color.opacity(0.22), lineWidth: 1)
        }
    }

    private var iconName: String {
        switch style {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        case .download, .running:
            return "arrow.down.circle.fill"
        case .neutral:
            return "info.circle.fill"
        }
    }
}

extension InlineBanner where Actions == EmptyView {
    init(title: String, message: String, style: StatusBadge.Style = .neutral) {
        self.init(title: title, message: message, style: style) {
            EmptyView()
        }
    }
}

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

struct PanelHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Text(title)
            .font(.headline)
            .lineLimit(1)
    }
}

struct FullWidthDisclosureGroup<Label: View, Content: View>: View {
    @Binding var isExpanded: Bool
    private let label: () -> Label
    private let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var theme: ThemeSettings

    init(
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self._isExpanded = isExpanded
        self.content = content
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    label()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }
}
