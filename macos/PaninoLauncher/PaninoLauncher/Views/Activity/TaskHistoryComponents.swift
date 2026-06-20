import SwiftUI

struct TaskHistorySection: View {
    let records: [TaskRecord]
    let selectedRecordID: String?
    @Binding var filter: TaskHistoryFilter
    @Binding var retentionPolicy: TaskHistoryRetentionPolicy
    var viewportHeight: CGFloat? = nil
    let clearStatus: String?
    let onSelect: (TaskRecord) -> Void
    let onClear: (TaskClearAction) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: PaninoTokens.Radius.panel, style: .continuous)

        VStack(alignment: .leading, spacing: 12) {
            historyToolbar

            if let clearStatus {
                Text(clearStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            historyViewport
        }
        .padding(theme.fontDensity.panelPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: shape)
        .background {
            shape
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.58))
                .overlay(theme.semanticSelectionColor.opacity(0.035))
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var historyViewportHeight: CGFloat {
        viewportHeight ?? (records.isEmpty ? 136 : 320)
    }

    private var historyToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                historyTitle
                historyFilterPicker
                Spacer(minLength: 12)
                historyRetentionPicker
                TaskClearMenu(onClear: onClear)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    historyTitle
                    Spacer(minLength: 12)
                    TaskClearMenu(onClear: onClear)
                }
                HStack(spacing: 10) {
                    historyFilterPicker
                    Spacer(minLength: 12)
                    historyRetentionPicker
                }
            }
        }
    }

    private var historyTitle: some View {
        HStack(spacing: 8) {
            Text(localizedString(theme.language, english: "Task History", chinese: "任务历史", italian: "Cronologia attività", french: "Historique des tâches", spanish: "Historial de tareas"))
                .font(.headline)
            CountText(value: records.count)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var historyViewport: some View {
        if records.isEmpty {
            emptyHistoryView
                .frame(height: historyViewportHeight)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(records) { record in
                        TaskRecordRow(
                            record: record,
                            isSelected: selectedRecordID == record.id
                        ) {
                            onSelect(record)
                        }
                    }
                }
                .padding(.trailing, 4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: historyViewportHeight)
            .scrollIndicators(.visible)
            .scrollClipDisabled(false)
        }
    }

    private var emptyHistoryView: some View {
        ContentUnavailableView(
            localizedString(theme.language, english: "No History", chinese: "没有历史", italian: "Nessuna cronologia", french: "Aucun historique", spanish: "Sin historial"),
            systemImage: "tray",
            description: Text(localizedString(theme.language, english: "Finished tasks appear here after downloads, installs, launches or diagnostics.", chinese: "下载、安装、启动或诊断结束后会显示在这里。", italian: "Le attività finite appariranno qui.", french: "Les tâches terminées apparaissent ici.", spanish: "Las tareas finalizadas aparecerán aquí."))
        )
        .frame(maxWidth: .infinity, minHeight: historyViewportHeight)
    }

    private var historyFilterPicker: some View {
        PaninoGlassSegmentedRail {
            Picker("", selection: $filter) {
                ForEach(TaskHistoryFilter.allCases) { item in
                    Text(item.title(language: theme.language)).tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 560)
        }
    }

    private var historyRetentionPicker: some View {
        Picker("", selection: $retentionPolicy) {
            ForEach(TaskHistoryRetentionPolicy.allCases) { policy in
                Text(policy.title(language: theme.language)).tag(policy)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 190)
    }
}

private struct TaskClearMenu: View {
    let onClear: (TaskClearAction) -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Menu {
            Button(TaskClearAction.completed.title(language: theme.language)) { onClear(.completed) }
            Button(TaskClearAction.cancelledAndInterrupted.title(language: theme.language)) { onClear(.cancelledAndInterrupted) }
            Button(TaskClearAction.failed.title(language: theme.language)) { onClear(.failed) }
            Button(TaskClearAction.allFinishedKeepingFailures.title(language: theme.language)) { onClear(.allFinishedKeepingFailures) }
            Divider()
            Button(TaskClearAction.allFinished.title(language: theme.language), role: .destructive) { onClear(.allFinished) }
            Button(TaskClearAction.allHistory.title(language: theme.language), role: .destructive) { onClear(.allHistory) }
        } label: {
            Label(localizedString(theme.language, english: "Clean Up", chinese: "清理", italian: "Pulisci", french: "Nettoyer", spanish: "Limpiar"), systemImage: "trash")
        }
        .menuStyle(.button)
        .fixedSize()
    }
}

private struct TaskRecordRow: View {
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
