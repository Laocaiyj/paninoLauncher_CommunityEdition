import Foundation

@MainActor
extension LauncherLogicSelfTest {
    static func runTaskPersistenceTests(_ failures: inout [String]) {
        let newer = makeRecord(
            id: "newer",
            kind: "launch",
            state: .succeeded,
            updatedAt: referenceDate.addingTimeInterval(60)
        )
        let older = makeRecord(
            id: "older",
            kind: "install",
            state: .succeeded,
            updatedAt: referenceDate
        )
        expect(TaskCenterHistoryPruner.sorted([older, newer]).map(\.id) == ["newer", "older"], "history sorting should put newest records first", &failures)
        expect(TaskCenterHistoryPruner.unique([older, newer, older]).map(\.id) == ["older", "newer"], "history unique should keep first occurrence", &failures)

        let active = makeRecord(
            id: "active",
            kind: "launch",
            state: .running,
            updatedAt: referenceDate
        )
        let recentFailure = makeRecord(
            id: "recent-failure",
            kind: "content-install",
            state: .failed,
            updatedAt: referenceDate.addingTimeInterval(-60)
        )
        let oldFailure = makeRecord(
            id: "old-failure",
            kind: "content-install",
            state: .failed,
            updatedAt: referenceDate.addingTimeInterval(-40 * 24 * 60 * 60)
        )
        let prunedFailuresOnly = TaskCenterHistoryPruner.pruned(
            [oldFailure, recentFailure, active],
            retentionPolicy: .failuresOnly,
            now: referenceDate
        )
        expect(Set(prunedFailuresOnly.map(\.id)) == Set(["active", "recent-failure"]), "failuresOnly retention should keep active and recent failures only", &failures)

        let selectedInstallFailure = makeRecord(
            id: "install-failure",
            kind: "install",
            version: "1.21.7",
            gameDir: "/tmp/world",
            state: .failed,
            requestedLoader: "fabric",
            requestedShaderLoader: "iris",
            updatedAt: referenceDate
        )
        let sameInstallSuccess = makeRecord(
            id: "install-success",
            kind: "install",
            version: "1.21.7",
            gameDir: "/tmp/world",
            state: .succeeded,
            requestedLoader: "fabric",
            requestedShaderLoader: "iris",
            updatedAt: referenceDate.addingTimeInterval(60)
        )
        expect(TaskCenterHistoryPruner.actionableAttentionRecords(in: [selectedInstallFailure, sameInstallSuccess]).isEmpty, "later matching install success should supersede install failure", &failures)

        let differentLoaderSuccess = makeRecord(
            id: "install-success-quilt",
            kind: "install",
            version: "1.21.7",
            gameDir: "/tmp/world",
            state: .succeeded,
            requestedLoader: "quilt",
            requestedShaderLoader: "iris",
            updatedAt: referenceDate.addingTimeInterval(60)
        )
        expect(TaskCenterHistoryPruner.actionableAttentionRecords(in: [selectedInstallFailure, differentLoaderSuccess]).map(\.id) == ["install-failure"], "different loader success should not supersede install failure", &failures)

        let interrupted = TaskCenterHistoryPruner.markMissingCoreTasksInterrupted(
            [
                makeRecord(id: "runtime", kind: "runtime.install", state: .running),
                makeRecord(id: "performance", kind: "performance-pack-install", state: .running),
                makeRecord(id: "local", kind: "local-only", state: .running)
            ],
            coreTaskIDs: ["performance"]
        )
        expect(interrupted.first(where: { $0.id == "runtime" })?.state == .interrupted, "missing runtime task should become interrupted", &failures)
        expect(interrupted.first(where: { $0.id == "performance" })?.state == .running, "known core task should stay running", &failures)
        expect(interrupted.first(where: { $0.id == "local" })?.state == .running, "local-only task should not be interrupted by core history", &failures)
    }
}
