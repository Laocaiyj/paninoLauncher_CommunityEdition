import Foundation

@MainActor
extension LauncherLogicSelfTest {
    static func runNavigationAndCommandTests(_ failures: inout [String]) {
        expect(LauncherSection.primaryCases == [.launch, .instances, .discover, .diagnostics], "primary navigation cases should stay stable", &failures)
        expect(LauncherSection.resources.primaryParent == .instances, "resources should remain under local instances", &failures)
        expect(LauncherSection.versions.primaryParent == .instances, "versions should remain under local instances", &failures)
        expect(LauncherSection.downloads.primaryParent == .diagnostics, "downloads should remain under tasks", &failures)
        expect(LauncherSection.logs.primaryParent == .diagnostics, "logs should remain under tasks", &failures)
        expect(LauncherSection.discover.title(language: .english) == "Get", "discover title should remain user-facing Get", &failures)
        expect(LauncherSection.diagnostics.title(language: .english) == "Tasks", "diagnostics section should remain user-facing Tasks", &failures)

        let actions = AppActionCenter()
        expect(actions.commandSequence == 0, "new action center should start with no command", &failures)
        actions.dispatch(.openDiscover)
        expect(actions.commandSequence == 1, "dispatch should increment command sequence", &failures)
        expect(actions.lastCommand == .openDiscover, "dispatch should publish last command", &failures)
        actions.dispatch(.openActivity)
        expect(actions.commandSequence == 2, "second dispatch should increment command sequence again", &failures)
        expect(actions.lastCommand == .openActivity, "second dispatch should update last command", &failures)

        actions.focusSettings(.download)
        expect(actions.requestedSettingsSection == .download, "settings focus should store requested settings section", &failures)
        expect(actions.settingsSectionSequence == 1, "settings focus should increment settings sequence", &failures)

        let contentSuccess = TaskCenterRecordFactory.record(
            from: makeSnapshot(
                taskId: "content-success",
                kind: "content-install",
                version: "Sodium",
                gameDir: "/tmp/world",
                state: .succeeded,
                message: "installed Sodium",
                progress: nil
            ),
            now: referenceDate
        )
        expect(contentSuccess.state == .succeeded, "content install success should be terminal success", &failures)
        expect(!contentSuccess.state.needsAttention, "content install success should not request attention navigation", &failures)
        expect(contentSuccess.progress == 1, "content install success should force complete progress", &failures)

        let failedDownload = TaskCenterRecordFactory.record(
            from: makeSnapshot(
                taskId: "download-failed",
                kind: "content-install",
                version: "Iris",
                gameDir: "/tmp/world",
                state: .failed,
                message: nil,
                errorCode: "network_timeout",
                errorDetail: "timeout"
            ),
            now: referenceDate
        )
        expect(failedDownload.state.needsAttention, "failed content task should still be actionable", &failures)
        expect(TaskCenterHistoryPruner.actionableAttentionRecords(in: [contentSuccess, failedDownload]).map(\.id) == ["download-failed"], "only failed content tasks should appear in actionable attention", &failures)
    }
}
