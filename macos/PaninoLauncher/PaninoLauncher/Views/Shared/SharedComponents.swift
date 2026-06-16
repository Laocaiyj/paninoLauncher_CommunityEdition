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

struct PaninoTextInput: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var onSubmit: (() -> Void)?

    init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field: NSTextField = isSecure ? PaninoSecureTextField() : PaninoPlainTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.stringValue = text
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = true
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.focusRingType = .default
        field.font = .preferredFont(forTextStyle: .body)
        field.lineBreakMode = .byTruncatingTail
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PaninoTextInput

        init(_ parent: PaninoTextInput) {
            self.parent = parent
        }

        @objc func submit(_ sender: NSTextField) {
            parent.text = sender.stringValue
            parent.onSubmit?()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }
            if let field = control as? NSTextField {
                parent.text = field.stringValue
            }
            parent.onSubmit?()
            return true
        }
    }
}

private final class PaninoPlainTextField: NSTextField {
    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self.currentEditor() ?? self)
            }
        }
        return accepted
    }
}

private final class PaninoSecureTextField: NSSecureTextField {
    override var acceptsFirstResponder: Bool { true }
    override var needsPanelToBecomeKey: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self.currentEditor() ?? self)
            }
        }
        return accepted
    }
}

struct GlassButton: View {
    var systemImage: String? = nil
    let title: String
    var prominent = false
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion
        )
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .lineLimit(1)
                    .labelStyle(.titleAndIcon)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .buttonStyle(
            GlassControlButtonStyle(
                prominent: prominent,
                tokens: tokens,
                density: theme.fontDensity,
                reduceMotion: reduceMotion || theme.reducesInterfaceMotion
            )
        )
        .accessibilityLabel(title)
        .help(title)
    }
}

private struct GlassControlButtonStyle: ButtonStyle {
    let prominent: Bool
    let tokens: ResolvedThemeTokens
    let density: FontDensity
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .padding(.horizontal, density.buttonHorizontalPadding)
            .frame(minHeight: tokens.buttonMinHeight)
            .foregroundStyle(prominent ? .white : .primary)
            .background {
                buttonBackground(isPressed: configuration.isPressed)
            }
            .clipShape(RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous))
            .overlay {
                if !prominent {
                    RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
                        .strokeBorder(tokens.strokeColor.opacity(tokens.strokeOpacity * 0.75), lineWidth: tokens.strokeWidth)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(PaninoMotion.noneWhenReduced(tokens.animation ?? PaninoMotion.fast, reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    @ViewBuilder
    private func buttonBackground(isPressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
        if prominent {
            shape.fill(tokens.selectionColor.opacity(isPressed ? 0.82 : 0.94))
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                }
        } else if let material = tokens.surfaceMaterial {
            shape.fill(material)
                .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.72))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.65))
        } else {
            shape.fill(tokens.surfaceFill.opacity(tokens.surfaceFillOpacity))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.45))
        }
    }
}

struct GlassPanel<Content: View>: View {
    var showsShadow = true
    @ViewBuilder let content: Content

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(showsShadow: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsShadow = showsShadow
        self.content = content()
    }

    var body: some View {
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion
        )
        content
            .padding(theme.fontDensity.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: tokens.panelCornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .paninoGlassSurface(tokens: tokens, cornerRadius: tokens.panelCornerRadius)
                    .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity))
                    .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.55))
                    .paninoDepthOverlay(tokens: tokens, cornerRadius: tokens.panelCornerRadius)
            }
            .clipShape(RoundedRectangle(cornerRadius: tokens.panelCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: tokens.panelCornerRadius, style: .continuous)
                    .strokeBorder(tokens.strokeColor.opacity(tokens.strokeOpacity), lineWidth: tokens.strokeWidth)
            }
            .shadow(
                color: Color.black.opacity(showsShadow ? tokens.shadowOpacity : 0),
                radius: showsShadow ? tokens.shadowRadius : 0,
                x: 0,
                y: showsShadow ? tokens.shadowYOffset : 0
            )
    }
}

struct StatusBadge: View {
    enum Style: Equatable {
        case neutral
        case success
        case warning
        case error
        case download
        case running

        var color: Color {
            switch self {
            case .neutral:
                return .secondary
            case .success:
                return .green
            case .warning:
                return .orange
            case .error:
                return .red
            case .download:
                return .blue
            case .running:
                return .teal
            }
        }
    }

    let title: String
    let style: Style

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(style.color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(style.color.opacity(0.14), in: Capsule())
        .foregroundStyle(style.color)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct MetadataLine: View {
    let items: [String]
    var font: Font = .caption
    var style: HierarchicalShapeStyle = .secondary
    var separator = " · "

    private var text: String {
        items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(style)
            .lineLimit(1)
            .truncationMode(.middle)
            .accessibilityLabel(text)
    }
}

struct CountText: View {
    let value: Int
    var suffix: String?
    var style: StatusBadge.Style = .neutral

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(style.color)
                .frame(width: 6, height: 6)
            Text(displayText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayText)
    }

    private var displayText: String {
        guard let suffix, !suffix.isEmpty else { return "\(value)" }
        return "\(value) \(suffix)"
    }
}

struct PlainStatusText: View {
    let title: String
    let style: StatusBadge.Style

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(style.color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(style.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct CompactStatusBadge: View {
    let title: String
    let style: StatusBadge.Style

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(style.color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .frame(maxWidth: 150)
        .background(style.color.opacity(0.14), in: Capsule())
        .foregroundStyle(style.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

extension InstanceStatus {
    var badgeStyle: StatusBadge.Style {
        switch self {
        case .notInstalled:
            return .warning
        case .ready:
            return .success
        case .installing:
            return .download
        case .running:
            return .running
        case .failed:
            return .error
        }
    }
}

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
