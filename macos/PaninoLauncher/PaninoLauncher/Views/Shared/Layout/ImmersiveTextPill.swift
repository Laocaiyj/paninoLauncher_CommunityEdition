import SwiftUI

struct ImmersiveTextPill<Leading: View>: View {
    let title: String
    let value: String
    @ViewBuilder let leading: () -> Leading

    @EnvironmentObject private var theme: ThemeSettings

    init(title: String, value: String, @ViewBuilder leading: @escaping () -> Leading) {
        self.title = title
        self.value = value
        self.leading = leading
    }

    var body: some View {
        HStack(spacing: 8) {
            leading()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.control + 4, tint: theme.semanticSelectionColor)
    }
}

extension ImmersiveTextPill where Leading == EmptyView {
    init(title: String, value: String) {
        self.init(title: title, value: value) {
            EmptyView()
        }
    }
}
