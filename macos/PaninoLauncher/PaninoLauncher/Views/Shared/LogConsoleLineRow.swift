import SwiftUI

struct LogConsoleLineRow: View {
    let line: LogLine
    let isSelected: Bool
    let select: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Text(line.text)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                isSelected ? theme.semanticSelectionColor.opacity(0.16) : Color.clear,
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: select)
    }
}
