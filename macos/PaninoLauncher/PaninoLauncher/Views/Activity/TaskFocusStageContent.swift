import SwiftUI

struct TaskFocusStageContent: View {
    let record: TaskRecord?
    let coreStatus: String
    let attentionCount: Int
    let recentCompletedRecords: [TaskRecord]
    let canCancel: Bool
    let canRetry: Bool
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onDiagnostics: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 28) {
                TaskFocusPrimaryContent(
                    record: record,
                    coreStatus: coreStatus,
                    attentionCount: attentionCount
                )
                .frame(minWidth: 460, maxWidth: 760, alignment: .leading)
                .layoutPriority(1)

                Spacer(minLength: 16)

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
                .frame(width: 390, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: 18) {
                TaskFocusPrimaryContent(
                    record: record,
                    coreStatus: coreStatus,
                    attentionCount: attentionCount
                )

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
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
