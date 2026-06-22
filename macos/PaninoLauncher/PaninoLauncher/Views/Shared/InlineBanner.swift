import SwiftUI

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
