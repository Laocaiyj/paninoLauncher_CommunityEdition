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
                        attentionCount: attentionCount,
                        showsFacts: false
                    )
                    .frame(maxWidth: 660, alignment: .leading)
                },
                floatingControls: {
                    EmptyView()
                },
                contextShelf: {
                    EmptyView()
                },
                inspectorContent: {
                    TaskFocusInspector(
                        record: record,
                        coreStatus: coreStatus,
                        recentCompletedRecords: recentCompletedRecords,
                        canCancel: canCancel,
                        canRetry: canRetry,
                        onCancel: onCancel,
                        onRetry: onRetry,
                        onDiagnostics: onDiagnostics
                    )
                    .frame(width: 360, alignment: .topLeading)
                }
            )
            .frame(height: focusStageHeight)
            .animation(.easeInOut(duration: 0.22), value: focusStageHeight)

            contextShelf()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var focusStageHeight: CGFloat {
        guard let record else { return recentCompletedRecords.isEmpty ? 340 : 410 }
        if record.state.isActive {
            return 440
        }
        if record.state.needsAttention {
            return 420
        }
        return recentCompletedRecords.isEmpty ? 360 : 400
    }
}
