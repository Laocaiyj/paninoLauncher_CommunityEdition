import SwiftUI

struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    private let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.bold())
                    .paninoTruncation(.title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .paninoTruncation(.summary(lines: 2))
            }
            Spacer(minLength: 12)
            trailing()
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct PageScaffold<Content: View>: View {
    var spacing: CGFloat = PaninoTokens.Layout.sectionSpacing
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    content
                }
                .padding(.horizontal, PaninoTokens.Layout.pagePadding(for: proxy.size.width))
                .padding(.bottom, 24)
                .frame(maxWidth: PaninoTokens.Layout.contentWidth(for: proxy.size.width), alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

struct InspectorPanel<Content: View>: View {
    var width: CGFloat = PaninoTokens.Layout.inspectorWidth
    @ViewBuilder let content: Content

    var body: some View {
        GlassPanel {
            content
        }
        .frame(minWidth: min(width, 280), idealWidth: width, maxWidth: width)
    }
}

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
