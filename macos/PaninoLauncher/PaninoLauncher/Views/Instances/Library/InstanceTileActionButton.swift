import SwiftUI

struct InstanceTileActionButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            if prominent {
                Label(title, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
        }
        .buttonStyle(.plain)
        .font(.callout.weight(.semibold))
        .padding(.horizontal, prominent ? 11 : 0)
        .frame(minHeight: 30)
        .foregroundStyle(prominent ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                .fill(prominent ? theme.semanticSelectionColor.opacity(0.94) : Color(nsColor: .controlBackgroundColor).opacity(0.44))
                .strokeBorder(prominent ? Color.clear : Color(nsColor: .separatorColor).opacity(0.46))
        }
        .help(title)
        .accessibilityLabel(title)
    }
}
