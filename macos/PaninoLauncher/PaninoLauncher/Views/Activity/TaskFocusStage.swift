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
                contentPlacement: .top,
                topContentInset: 18,
                backgroundContent: {
                    TaskFocusBackground(record: record)
                },
                primaryContent: {
                    TaskFocusStageContent(
                        record: record,
                        coreStatus: coreStatus,
                        attentionCount: attentionCount,
                        recentCompletedRecords: recentCompletedRecords,
                        canCancel: canCancel,
                        canRetry: canRetry,
                        onCancel: onCancel,
                        onRetry: onRetry,
                        onDiagnostics: onDiagnostics
                    )
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                },
                floatingControls: {
                    EmptyView()
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
        let showsRecentRail = !recentCompletedRecords.isEmpty
        guard let record else { return showsRecentRail ? 430 : 340 }
        if record.state.isActive {
            return showsRecentRail ? 460 : 420
        }
        if record.state.needsAttention {
            return showsRecentRail ? 450 : 410
        }
        return showsRecentRail ? 420 : 370
    }
}
