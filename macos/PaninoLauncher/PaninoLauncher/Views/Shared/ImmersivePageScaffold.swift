import SwiftUI

struct ImmersivePageScaffold<BackgroundContent: View, PrimaryContent: View, FloatingControls: View, ContextShelf: View, InspectorContent: View>: View {
    var minHeight: CGFloat = 680
    var cornerRadius: CGFloat = PaninoTokens.Radius.panel + 8
    @ViewBuilder let backgroundContent: () -> BackgroundContent
    @ViewBuilder let primaryContent: () -> PrimaryContent
    @ViewBuilder let floatingControls: () -> FloatingControls
    @ViewBuilder let contextShelf: () -> ContextShelf
    @ViewBuilder let inspectorContent: () -> InspectorContent

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(
        minHeight: CGFloat = 680,
        cornerRadius: CGFloat = PaninoTokens.Radius.panel + 8,
        @ViewBuilder backgroundContent: @escaping () -> BackgroundContent,
        @ViewBuilder primaryContent: @escaping () -> PrimaryContent,
        @ViewBuilder floatingControls: @escaping () -> FloatingControls,
        @ViewBuilder contextShelf: @escaping () -> ContextShelf,
        @ViewBuilder inspectorContent: @escaping () -> InspectorContent
    ) {
        self.minHeight = minHeight
        self.cornerRadius = cornerRadius
        self.backgroundContent = backgroundContent
        self.primaryContent = primaryContent
        self.floatingControls = floatingControls
        self.contextShelf = contextShelf
        self.inspectorContent = inspectorContent
    }

    var body: some View {
        GeometryReader { proxy in
            let motionDisabled = reduceMotion || theme.reducesInterfaceMotion
            let tokens = theme.resolvedTokens(
                reduceTransparency: reduceTransparency,
                increasedContrast: colorSchemeContrast == .increased,
                reduceMotion: motionDisabled
            )
            let scaffoldShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            ZStack(alignment: .bottomLeading) {
                scaffoldShape
                    .fill(
                        LinearGradient(
                            colors: [
                                tokens.surfaceFill.opacity(max(tokens.surfaceVeilOpacity * 0.86, 0.20)),
                                tokens.surfaceFill.opacity(max(tokens.surfaceFillOpacity * 0.74, 0.18))
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(theme.semanticSelectionColor.opacity(tokens.accentBackgroundOpacity * 0.16))

                backgroundContent()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.06),
                        Color.black.opacity(0.26),
                        Color.black.opacity(0.50)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [
                        theme.semanticSelectionColor.opacity(0.22),
                        Color.clear,
                        Color.black.opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Spacer(minLength: 0)
                        floatingControls()
                    }
                    .padding(24)

                    Spacer(minLength: 36)

                    VStack(alignment: .leading, spacing: 18) {
                        primaryContent()
                        contextShelf()
                    }
                    .padding(24)
                }

                HStack {
                    Spacer(minLength: 0)
                    inspectorContent()
                        .frame(maxHeight: .infinity, alignment: .topTrailing)
                        .transition(
                            motionDisabled
                                ? .opacity
                                : .move(edge: .trailing).combined(with: .opacity)
                        )
                }
                .padding(24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background {
                scaffoldShape
                    .fill(tokens.surfaceFill.opacity(max(tokens.surfaceVeilOpacity * 0.72, 0.16)))
            }
            .clipShape(scaffoldShape)
            .compositingGroup()
            .overlay {
                scaffoldShape
                    .strokeBorder(tokens.strokeColor.opacity(tokens.strokeOpacity * 0.82), lineWidth: tokens.strokeWidth)
            }
            .shadow(
                color: Color.black.opacity(tokens.shadowOpacity * 0.70),
                radius: tokens.shadowRadius * 1.18,
                x: 0,
                y: tokens.shadowYOffset * 0.86
            )
        }
        .frame(minHeight: minHeight)
    }
}

extension ImmersivePageScaffold where InspectorContent == EmptyView {
    init(
        minHeight: CGFloat = 680,
        cornerRadius: CGFloat = PaninoTokens.Radius.panel + 8,
        @ViewBuilder backgroundContent: @escaping () -> BackgroundContent,
        @ViewBuilder primaryContent: @escaping () -> PrimaryContent,
        @ViewBuilder floatingControls: @escaping () -> FloatingControls,
        @ViewBuilder contextShelf: @escaping () -> ContextShelf
    ) {
        self.init(
            minHeight: minHeight,
            cornerRadius: cornerRadius,
            backgroundContent: backgroundContent,
            primaryContent: primaryContent,
            floatingControls: floatingControls,
            contextShelf: contextShelf
        ) {
            EmptyView()
        }
    }
}

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
