import SwiftUI

private struct DetailPanel: View {
    @ObservedObject var viewModel: LauncherViewModel
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var instanceStore: InstanceStore

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            Text(AppText.details.localized(theme.language))
                .font(.title3.bold())
                .padding(.bottom, 2)

            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    PanelHeader(title: AppText.instanceDetails.localized(theme.language), systemImage: "sidebar.right")
                    InstanceCard(
                        title: instanceStore.selectedInstance?.name ?? "Default Game Configuration",
                        subtitle: "Version \(instanceStore.selectedInstance?.minecraftVersion ?? viewModel.version)",
                        status: viewModel.currentTask?.state.isActive == true
                            ? .running
                            : (instanceStore.selectedInstance?.status.badgeStyle ?? .neutral),
                        icon: instanceStore.selectedInstance?.iconName ?? "cube.transparent"
                    )
                }
            }

            AccountCard(accountState: viewModel.accountState)

            ProgressRow(task: viewModel.currentTask, idleTitle: AppText.readyForTasks.localized(theme.language))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial.opacity(0.72))
    }
}

struct BottomStatusBar: View {
    @ObservedObject var viewModel: LauncherViewModel
    let openActivity: () -> Void
    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion
        )
        HStack(spacing: 10) {
            PlainStatusText(title: viewModel.coreState.localizedTitle(theme.language), style: viewModel.coreState.isReady ? .success : .neutral)

            if let secondaryStatus {
                Text(secondaryStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()

            if let trailingStatus {
                Text(trailingStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: openActivity)
        .background {
            if reduceTransparency || colorSchemeContrast == .increased {
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(colorSchemeContrast == .increased ? 1.0 : 0.96))
                    .overlay(tokens.selectionColor.opacity(colorSchemeContrast == .increased ? 0.03 : 0.06))
            } else {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.12)

                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.04),
                            tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.14),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(tokens.strokeColor.opacity(max(0.28, tokens.strokeOpacity * 0.58)))
                .frame(height: tokens.strokeWidth)
        }
    }

    private var secondaryStatus: String? {
        if let currentTask = viewModel.currentTask {
            if currentTask.state.isActive, let progress = activeProgress(for: currentTask) {
                return compactProgressStatus(task: currentTask, progress: progress)
            }
            let errorCode = currentTask.errorCode.map { " [\($0)]" } ?? ""
            return "\(currentTask.kind.capitalized) \(currentTask.state.rawValue)\(errorCode): \(currentTask.diagnostic?.userSummary ?? currentTask.message ?? currentTask.version)"
        }
        if case .failed = viewModel.coreState {
            return viewModel.coreState.detail
        }
        return nil
    }

    private var trailingStatus: String? {
        guard let currentTask = viewModel.currentTask else { return nil }
        if currentTask.state.isActive, let progress = activeProgress(for: currentTask) {
            let eta = progress.etaSeconds.map(Self.compactDuration) ?? "-"
            return "\(formattedBytes(progress.speedBytesPerSecond))/s · \(eta)"
        }
        return "\(currentTask.kind.capitalized) \(currentTask.version) - \(currentTask.state.rawValue)"
    }

    private func activeProgress(for task: TaskSnapshot) -> TaskProgress? {
        if let liveProgress = viewModel.currentTaskProgress, liveProgress.taskId == task.taskId {
            return liveProgress
        }
        return task.progress
    }

    private func compactProgressStatus(task: TaskSnapshot, progress: TaskProgress) -> String {
        let percent = progress.overallPercent.map { "\(Int($0.rounded()))%" } ?? "..."
        let phase = progress.phaseTitle.isEmpty ? task.kind.capitalized : progress.phaseTitle
        return "\(task.kind.capitalized) \(percent) · \(phase)"
    }

    private static func compactDuration(_ seconds: Int64) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes < 60 {
            return "\(minutes):\(String(format: "%02d", remainder))"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
