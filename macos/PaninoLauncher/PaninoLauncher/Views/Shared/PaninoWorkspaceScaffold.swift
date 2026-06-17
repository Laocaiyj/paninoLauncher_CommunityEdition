import SwiftUI

enum PaninoWorkspaceWidthClass: Equatable {
    case compact
    case regular
    case wide

    init(width: CGFloat) {
        if width >= 1500 {
            self = .wide
        } else if width >= 1050 {
            self = .regular
        } else {
            self = .compact
        }
    }

    var isCompact: Bool { self == .compact }
    var showsInspectorInline: Bool { self == .wide }
}

struct PaninoWorkspaceMetrics: Equatable {
    let availableWidth: CGFloat
    let widthClass: PaninoWorkspaceWidthClass
    let pagePadding: CGFloat
    let contentWidth: CGFloat

    init(availableWidth: CGFloat) {
        self.availableWidth = availableWidth
        self.widthClass = PaninoWorkspaceWidthClass(width: availableWidth)
        self.pagePadding = PaninoTokens.Layout.pagePadding(for: availableWidth)
        self.contentWidth = PaninoTokens.Layout.contentWidth(for: availableWidth)
    }
}

struct PaninoWorkspaceHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    var systemImage: String?
    @ViewBuilder let trailing: Trailing

    @EnvironmentObject private var theme: ThemeSettings

    init(
        title: String,
        subtitle: String,
        systemImage: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    var body: some View {
        GlassPanel(showsShadow: false, surfaceLevel: .floatingChrome) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    titleCluster
                    Spacer(minLength: 12)
                    trailing
                }

                VStack(alignment: .leading, spacing: 10) {
                    titleCluster
                    trailing
                }
            }
        }
    }

    private var titleCluster: some View {
        HStack(alignment: .center, spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.semanticSelectionColor)
                    .frame(width: 28, height: 28)
                    .paninoGlassCard(
                        level: .floatingChrome,
                        cornerRadius: PaninoTokens.Radius.control,
                        tint: theme.semanticSelectionColor
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .allowsTightening(true)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .allowsTightening(true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension PaninoWorkspaceHeader where Trailing == EmptyView {
    init(title: String, subtitle: String, systemImage: String? = nil) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage) {
            EmptyView()
        }
    }
}

struct PaninoWorkspaceScaffold<Header: View, Sidebar: View, Content: View, Inspector: View>: View {
    var spacing: CGFloat = PaninoTokens.Layout.sectionSpacing
    private let hasHeader: Bool
    private let hasSidebar: Bool
    private let hasInspector: Bool
    @ViewBuilder let header: (PaninoWorkspaceMetrics) -> Header
    @ViewBuilder let sidebar: (PaninoWorkspaceMetrics) -> Sidebar
    @ViewBuilder let content: (PaninoWorkspaceMetrics) -> Content
    @ViewBuilder let inspector: (PaninoWorkspaceMetrics) -> Inspector

    @EnvironmentObject private var theme: ThemeSettings

    init(
        spacing: CGFloat = PaninoTokens.Layout.sectionSpacing,
        hasHeader: Bool = true,
        hasSidebar: Bool = true,
        hasInspector: Bool = true,
        @ViewBuilder header: @escaping (PaninoWorkspaceMetrics) -> Header,
        @ViewBuilder sidebar: @escaping (PaninoWorkspaceMetrics) -> Sidebar,
        @ViewBuilder content: @escaping (PaninoWorkspaceMetrics) -> Content,
        @ViewBuilder inspector: @escaping (PaninoWorkspaceMetrics) -> Inspector
    ) {
        self.spacing = spacing
        self.hasHeader = hasHeader
        self.hasSidebar = hasSidebar
        self.hasInspector = hasInspector
        self.header = header
        self.sidebar = sidebar
        self.content = content
        self.inspector = inspector
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = PaninoWorkspaceMetrics(availableWidth: proxy.size.width)

            VStack(alignment: .center, spacing: 0) {
                if hasHeader {
                    header(metrics)
                        .padding(.horizontal, metrics.pagePadding)
                        .padding(.top, PaninoTokens.Layout.pageTopSpacing)
                        .frame(maxWidth: metrics.contentWidth, alignment: .topLeading)
                }

                ScrollView {
                    layout(metrics: metrics)
                        .padding(.horizontal, metrics.pagePadding)
                        .padding(.top, hasHeader ? spacing : PaninoTokens.Layout.pageTopSpacing)
                        .padding(.bottom, 24)
                        .frame(maxWidth: metrics.contentWidth, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func layout(metrics: PaninoWorkspaceMetrics) -> some View {
        if !hasSidebar && !hasInspector {
            content(metrics)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        } else if metrics.widthClass.showsInspectorInline {
            HStack(alignment: .top, spacing: spacing) {
                if hasSidebar {
                    sidebar(metrics)
                        .frame(width: PaninoTokens.Layout.secondarySidebarWidth, alignment: .topLeading)
                }
                content(metrics)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                if hasInspector {
                    inspector(metrics)
                        .frame(width: PaninoTokens.Layout.inspectorWidth, alignment: .topLeading)
                }
            }
        } else if metrics.widthClass.isCompact {
            VStack(alignment: .leading, spacing: spacing) {
                if hasSidebar {
                    sidebar(metrics)
                }
                content(metrics)
                if hasInspector {
                    inspector(metrics)
                }
            }
        } else {
            HStack(alignment: .top, spacing: spacing) {
                if hasSidebar {
                    sidebar(metrics)
                        .frame(width: PaninoTokens.Layout.secondarySidebarWidth, alignment: .topLeading)
                }
                content(metrics)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                if hasInspector {
                    inspector(metrics)
                        .frame(width: PaninoTokens.Layout.inspectorWidth, alignment: .topLeading)
                }
            }
        }
    }
}

extension PaninoWorkspaceScaffold where Sidebar == EmptyView, Inspector == EmptyView {
    init(
        spacing: CGFloat = PaninoTokens.Layout.sectionSpacing,
        @ViewBuilder header: @escaping (PaninoWorkspaceMetrics) -> Header,
        @ViewBuilder content: @escaping (PaninoWorkspaceMetrics) -> Content
    ) {
        self.init(
            spacing: spacing,
            hasHeader: true,
            hasSidebar: false,
            hasInspector: false,
            header: header,
            sidebar: { _ in EmptyView() },
            content: content,
            inspector: { _ in EmptyView() }
        )
    }
}

extension PaninoWorkspaceScaffold where Header == EmptyView, Sidebar == EmptyView, Inspector == EmptyView {
    init(
        spacing: CGFloat = PaninoTokens.Layout.sectionSpacing,
        @ViewBuilder content: @escaping (PaninoWorkspaceMetrics) -> Content
    ) {
        self.init(
            spacing: spacing,
            hasHeader: false,
            hasSidebar: false,
            hasInspector: false,
            header: { _ in EmptyView() },
            sidebar: { _ in EmptyView() },
            content: content,
            inspector: { _ in EmptyView() }
        )
    }
}
