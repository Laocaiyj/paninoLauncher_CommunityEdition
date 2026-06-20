import SwiftUI

struct TaskRecordRow: View {
    let record: TaskRecord
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(record.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Text(record.finishedAt?.formatted(date: .abbreviated, time: .shortened) ?? record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                TaskStateLine(title: record.state.title(language: theme.language), style: record.state.badgeStyle)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background {
                shape
                    .fill(rowFill)
            }
            .overlay {
                shape.strokeBorder(rowStroke, lineWidth: isSelected ? 1 : 0.7)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(record.name), \(record.state.title(language: theme.language)), \(record.message)")
    }

    private var rowFill: Color {
        if isSelected {
            return theme.semanticSelectionColor.opacity(0.14)
        }
        return Color(nsColor: .textBackgroundColor).opacity(0.28)
    }

    private var rowStroke: Color {
        if isSelected {
            return theme.semanticSelectionColor.opacity(0.42)
        }
        return Color.primary.opacity(0.06)
    }
}
