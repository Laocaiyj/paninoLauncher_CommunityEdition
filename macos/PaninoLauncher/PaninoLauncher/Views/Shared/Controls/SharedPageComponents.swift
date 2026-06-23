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
