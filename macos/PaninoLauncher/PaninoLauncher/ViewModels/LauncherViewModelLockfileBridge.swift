import Foundation

@MainActor
extension LauncherViewModel {
    func solveLockfile(_ request: CoreLockfileSolveRequest) async throws -> CoreLockfileSolverResult {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.solveLockfile(request)
    }

    func applyLockfile(_ request: CoreLockfileApplyRequest) async throws -> CoreLockfileApplyResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.applyLockfile(request)
    }

    func currentLockfile(gameDir: String? = nil) async throws -> CoreLockfileCurrentResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.currentLockfile(gameDir: gameDir)
    }

    func verifyLockfile(_ request: CoreLockfileVerifyRequest) async throws -> CoreLockfileVerifyResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.verifyLockfile(request)
    }
}
