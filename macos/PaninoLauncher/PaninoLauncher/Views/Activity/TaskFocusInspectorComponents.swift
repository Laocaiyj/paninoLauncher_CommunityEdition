import SwiftUI

struct TaskFocusInspector: View {
    let record: TaskRecord?
    let coreStatus: String
    let recentCompletedRecords: [TaskRecord]
    let canCancel: Bool
    let canRetry: Bool
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onDiagnostics: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            TaskFocusControls(
                record: record,
                canCancel: canCancel,
                canRetry: canRetry,
                onCancel: onCancel,
                onRetry: onRetry,
                onDiagnostics: onDiagnostics
            )
            .frame(maxWidth: .infinity, alignment: .trailing)

            LazyVGrid(columns: factColumns, alignment: .leading, spacing: 7) {
                TaskFocusInspectorFact(
                    title: localizedString(theme.language, english: "Core", chinese: "Core", italian: "Core", french: "Core", spanish: "Core"),
                    value: coreStatus
                )
                TaskFocusInspectorFact(
                    title: localizedString(theme.language, english: "Updated", chinese: "更新", italian: "Aggiornato", french: "Mis à jour", spanish: "Actualizado"),
                    value: record?.updatedAt.formatted(date: .omitted, time: .shortened) ?? "-"
                )
                TaskFocusInspectorFact(
                    title: localizedString(theme.language, english: "Kind", chinese: "类型", italian: "Tipo", french: "Type", spanish: "Tipo"),
                    value: record?.kindTitle ?? "-"
                )
                TaskFocusInspectorFact(
                    title: localizedString(theme.language, english: "Remaining", chinese: "剩余", italian: "Tempo", french: "Restant", spanish: "Restante"),
                    value: record?.remainingTime ?? "-"
                )
            }

            if !recentRecords.isEmpty {
                TaskFocusRecentRail(records: recentRecords)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var factColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 116), spacing: 7),
            GridItem(.flexible(minimum: 116), spacing: 7)
        ]
    }

    private var recentRecords: [TaskRecord] {
        Array(recentCompletedRecords.prefix(3))
    }
}

private struct TaskFocusInspectorFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.20))
        }
    }
}
