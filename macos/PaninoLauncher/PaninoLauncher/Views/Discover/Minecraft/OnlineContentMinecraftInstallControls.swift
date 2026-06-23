import SwiftUI

struct MinecraftInstallMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct MinecraftInstallChoiceButton: View {
    let title: String
    let isSelected: Bool
    let disabled: Bool
    var state: InstallChoicePreflightState = .normal
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .lineLimit(1)
                if let image = state.systemImage {
                    Image(systemName: image)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : state.tint)
                }
            }
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .frame(minHeight: PaninoTokens.Layout.controlMinSize)
            .background(isSelected ? theme.semanticSelectionColor.opacity(0.92) : Color(nsColor: .controlBackgroundColor).opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

struct MinecraftInstallVersionMenu<Content: View>: View {
    let title: String
    let isEmpty: Bool
    let emptyTitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            if isEmpty {
                Text(emptyTitle)
            } else {
                content()
            }
        } label: {
            HStack(spacing: 6) {
                Text(isEmpty ? emptyTitle : title)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 260, alignment: .trailing)
        }
        .menuStyle(.borderlessButton)
    }
}
