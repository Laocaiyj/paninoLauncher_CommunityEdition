import SwiftUI

struct MetricStripItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    var systemImage: String?
}

struct MetricStrip: View {
    let items: [MetricStripItem]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8, alignment: .top)], spacing: 8) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    if let systemImage = item.systemImage {
                        Image(systemName: systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .paninoTruncation(.title)
                        Text(item.value)
                            .font(.caption.weight(.semibold))
                            .paninoTruncation(.path)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(height: 54)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
            }
        }
    }
}

struct SelectableListRow<Leading: View, Content: View, Trailing: View>: View {
    let isSelected: Bool
    let action: () -> Void
    private let leading: () -> Leading
    private let content: () -> Content
    private let trailing: () -> Trailing

    @EnvironmentObject private var theme: ThemeSettings

    init(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.isSelected = isSelected
        self.action = action
        self.leading = leading
        self.content = content
        self.trailing = trailing
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading()
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.rowHeightCompact, alignment: .leading)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.72) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var rowBackground: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.30)
    }
}

struct ToolbarIconButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .frame(width: PaninoTokens.Layout.controlMinSize, height: PaninoTokens.Layout.controlMinSize)
                .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
        .help(title)
    }
}
