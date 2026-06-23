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
