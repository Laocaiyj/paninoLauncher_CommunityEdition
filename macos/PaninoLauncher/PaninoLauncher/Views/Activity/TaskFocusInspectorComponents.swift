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

struct TaskFocusControls: View {
    let record: TaskRecord?
    let canCancel: Bool
    let canRetry: Bool
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onDiagnostics: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { controls }
            VStack(alignment: .trailing, spacing: 10) { controls }
        }
        .padding(7)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.control + 10, tint: record?.state.badgeStyle.color ?? theme.semanticSelectionColor, showsShadow: true)
    }

    @ViewBuilder
    private var controls: some View {
        if canCancel {
            GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: onCancel)
        }
        if canRetry {
            GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Retry", chinese: "重试", italian: "Riprova", french: "Réessayer", spanish: "Reintentar"), prominent: true, action: onRetry)
        }
        GlassButton(systemImage: "terminal", title: AppText.logs.localized(theme.language), action: onDiagnostics)
    }
}
