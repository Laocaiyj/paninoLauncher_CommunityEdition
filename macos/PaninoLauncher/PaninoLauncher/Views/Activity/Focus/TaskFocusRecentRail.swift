import SwiftUI

struct TaskFocusRecentRail: View {
    let records: [TaskRecord]

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(localizedString(theme.language, english: "Recent Completed", chinese: "最近完成", italian: "Completate di recente", french: "Récemment terminées", spanish: "Completadas recientes"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer(minLength: 8)
                CountText(value: records.count, style: .success)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(records) { record in
                    TaskFocusRecentRow(record: record)
                }
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.22))
        }
    }
}

private struct TaskFocusRecentRow: View {
    let record: TaskRecord

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(record.state.badgeStyle.color)
                .frame(width: 3, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(record.finishedAt?.formatted(date: .abbreviated, time: .shortened) ?? record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.60))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(height: 31)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white.opacity(0.058))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.name), \(record.state.title(language: theme.language))")
    }
}
