import SwiftUI

struct LaunchShelfModeSelector: View {
    @Binding var mode: LaunchShelfMode

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PaninoGlassSegmentedRail {
            HStack(spacing: 2) {
                ForEach(LaunchShelfMode.allCases) { item in
                    Button {
                        withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                            mode = item
                        }
                    } label: {
                        Text(item.title(language: theme.language))
                            .font(.callout.weight(mode == item ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                            .allowsTightening(true)
                            .padding(.horizontal, 8)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 34)
                            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(mode == item ? Color.white : Color.primary)
                    .background {
                        if mode == item {
                            RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                                .fill(theme.semanticSelectionColor)
                                .overlay {
                                    RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                                }
                        }
                    }
                }
            }
            .frame(minWidth: 0, idealWidth: preferredWidth, maxWidth: preferredWidth)
        }
        .layoutPriority(1)
    }

    private var preferredWidth: CGFloat {
        let titles = LaunchShelfMode.allCases.map { $0.title(language: theme.language) }
        let characterCount = titles.reduce(0) { $0 + $1.count }
        return min(max(CGFloat(characterCount) * 7.8 + CGFloat(titles.count) * 30, 230), 360)
    }
}
