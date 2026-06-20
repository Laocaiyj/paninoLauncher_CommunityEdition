import SwiftUI

struct TaskFocusStage<ContextShelf: View>: View {
    let record: TaskRecord?
    let coreStatus: String
    let attentionCount: Int
    let canCancel: Bool
    let canRetry: Bool
    let recentCompletedRecords: [TaskRecord]
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onDiagnostics: () -> Void
    @ViewBuilder let contextShelf: () -> ContextShelf

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            ImmersivePageScaffold(
                minHeight: focusStageHeight,
                backgroundContent: {
                    TaskFocusBackground(record: record)
                },
                primaryContent: {
                    TaskFocusPrimaryContent(
                        record: record,
                        coreStatus: coreStatus,
                        attentionCount: attentionCount
                    )
                },
                floatingControls: {
                    VStack(alignment: .trailing, spacing: 12) {
                        TaskFocusControls(
                            record: record,
                            canCancel: canCancel,
                            canRetry: canRetry,
                            onCancel: onCancel,
                            onRetry: onRetry,
                            onDiagnostics: onDiagnostics
                        )

                        if !recentCompletedRecords.isEmpty {
                            TaskFocusRecentRail(records: Array(recentCompletedRecords.prefix(3)))
                                .frame(width: 360)
                        }
                    }
                },
                contextShelf: {
                    EmptyView()
                }
            )
            .frame(height: focusStageHeight)
            .animation(.easeInOut(duration: 0.22), value: focusStageHeight)

            contextShelf()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var focusStageHeight: CGFloat {
        guard let record else { return 340 }
        if record.state.isActive {
            return 440
        }
        if record.state.needsAttention {
            return 400
        }
        return 380
    }
}
