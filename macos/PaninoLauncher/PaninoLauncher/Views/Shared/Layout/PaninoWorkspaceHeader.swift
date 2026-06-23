import SwiftUI

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
