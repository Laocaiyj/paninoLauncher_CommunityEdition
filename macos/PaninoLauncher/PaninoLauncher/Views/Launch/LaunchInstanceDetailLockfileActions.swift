import Foundation

extension LaunchInstanceDetailPage {
    func refreshLockfileFromPanel() {
        Task { await refreshLockfileState() }
    }

    func prepareLockfileRepairReview() {
        Task { await prepareLockfileReview(policy: "repair") }
    }

    func prepareLockfileUpdateReview(policy: String) {
        Task { await prepareLockfileReview(policy: policy) }
    }

    @MainActor
    func refreshLockfileState() async {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lockfileBusy = true
        defer { lockfileBusy = false }
        do {
            let current = try await viewModel.currentLockfile(gameDir: instance.gameDirectory)
            currentLockfile = current.lockfile
            if let lockfile = current.lockfile {
                lockfileVerify = try await viewModel.verifyLockfile(CoreLockfileVerifyRequest(targetGameDir: instance.gameDirectory, lockfile: lockfile))
                lockfileStatusMessage = ""
            } else {
                lockfileVerify = nil
                lockfileStatusMessage = localizedString(theme.language, english: "No panino-lock.json exists for this instance.", chinese: "此实例还没有 panino-lock.json。", italian: "Nessun panino-lock.json per questa istanza.", french: "Aucun panino-lock.json pour cette instance.", spanish: "No hay panino-lock.json para esta instancia.")
            }
        } catch {
            lockfileVerify = nil
            lockfileStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    func prepareLockfileReview(policy: String) async {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lockfileBusy = true
        defer { lockfileBusy = false }
        do {
            if currentLockfile == nil {
                let current = try await viewModel.currentLockfile(gameDir: instance.gameDirectory)
                currentLockfile = current.lockfile
            }
            let request = CoreLockfileSolveRequest(
                mode: policy == "repair" ? "repair" : "update",
                targetGameDir: instance.gameDirectory,
                minecraftVersion: instance.contentMinecraftVersion,
                loader: instance.loader?.rawValue,
                loaderVersion: instance.loaderVersion,
                existingLockfile: currentLockfile,
                updatePolicy: policy
            )
            let result = try await viewModel.solveLockfile(request)
            pendingLockfileReview = PendingLockfileReview(policy: policy, result: result)
            lockfileStatusMessage = ""
        } catch {
            lockfileStatusMessage = error.localizedDescription
        }
    }

    func applyLockfileReview(_ review: PendingLockfileReview) {
        guard let lockfile = review.result.lockfile else { return }
        Task {
            do {
                _ = try await viewModel.applyLockfile(
                    CoreLockfileApplyRequest(
                        targetGameDir: instance.gameDirectory,
                        solverFingerprint: lockfile.fingerprint,
                        result: review.result
                    )
                )
                pendingLockfileReview = nil
                lockfileStatusMessage = localizedString(theme.language, english: "Lockfile applied.", chinese: "锁文件已应用。", italian: "Lockfile applicato.", french: "Lockfile appliqué.", spanish: "Lockfile aplicado.")
                await refreshLockfileState()
            } catch {
                lockfileStatusMessage = error.localizedDescription
            }
        }
    }
}
