import SwiftUI

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
