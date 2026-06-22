import SwiftUI

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
