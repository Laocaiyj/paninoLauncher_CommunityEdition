import SwiftUI

struct LaunchTaskTimelinePanel: View {
    let task: TaskSnapshot?
    let record: TaskRecord?
    let idleTitle: String
    let retry: () -> Void
    let repair: () -> Void
    let openLogs: () -> Void
    let openTasks: () -> Void
    let openInstanceFolder: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        let presentation = LaunchTaskTimelinePresentation(task: task, language: theme.language)

        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Launch Timeline", chinese: "启动时间线", italian: "Timeline avvio", french: "Chronologie", spanish: "Cronología"),
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                    Spacer()
                    StatusBadge(
                        title: task?.state.localizedTitle(theme.language) ?? AppText.idle.localized(theme.language),
                        style: presentation.taskBadgeStyle
                    )
                }

                ProgressView(value: presentation.progressValue(record: record), total: 1)

                VStack(spacing: 8) {
                    ForEach(presentation.stages) { stage in
                        LaunchTimelineRow(stage: stage)
                    }
                }

                if let record {
                    LaunchTaskTimelineMetrics(record: record, language: theme.language)
                } else {
                    Text(idleTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                LaunchTaskTimelineActions(
                    task: task,
                    language: theme.language,
                    retry: retry,
                    openLogs: openLogs,
                    openTasks: openTasks,
                    openInstanceFolder: openInstanceFolder
                )
            }
        }
    }
}
