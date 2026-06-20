import Foundation
import Combine

@MainActor
final class PerformanceCoachStore: ObservableObject {
    @Published private(set) var recommendation: CorePerformanceRecommendation?
    @Published private(set) var candidate: CorePerformanceCandidateResponse?
    @Published private(set) var lastAppliedProfile: CorePerformanceProfile?
    @Published private(set) var statusText = ""
    @Published private(set) var isWorking = false

    private var apiClient: LauncherApiClient?

    init(apiClient: LauncherApiClient? = nil) {
        self.apiClient = apiClient
    }

    func configure(endpoint: CoreEndpoint) {
        apiClient = LauncherApiClient(endpoint: endpoint)
    }

    func resolveBaseline(request: CorePerformanceProfileResolveRequest) {
        guard let apiClient else {
            statusText = "Core endpoint is not connected."
            return
        }
        isWorking = true
        statusText = "Resolving performance baseline..."
        Task {
            do {
                let resolved = try await apiClient.resolvePerformanceProfile(request)
                await MainActor.run {
                    recommendation = resolved
                    candidate = nil
                    statusText = resolved.confidence == "estimated"
                        ? "Estimated baseline ready for review."
                        : "Measured recommendation ready."
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    statusText = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    func generateCandidate(request: CorePerformanceCandidateRequest) {
        guard let apiClient else {
            statusText = "Core endpoint is not connected."
            return
        }
        isWorking = true
        statusText = "Checking one bounded candidate..."
        Task {
            do {
                let response = try await apiClient.performanceCandidate(request)
                await MainActor.run {
                    candidate = response
                    recommendation = response.recommendation
                    statusText = response.safetyGate.allowed
                        ? "Candidate passed safety checks."
                        : "Candidate blocked: \(response.safetyGate.reasons.joined(separator: ", "))"
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    statusText = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    func apply(profile: CorePerformanceProfile, gameDir: String) {
        guard let apiClient else {
            statusText = "Core endpoint is not connected."
            return
        }
        isWorking = true
        statusText = "Applying reviewed performance profile..."
        Task {
            do {
                let response = try await apiClient.applyPerformanceProfile(
                    CorePerformanceApplyRequest(gameDir: gameDir, profile: profile)
                )
                await MainActor.run {
                    lastAppliedProfile = response.profile
                    statusText = response.rollbackRef.map { "Applied with rollback \($0)." } ?? "Applied."
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    statusText = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    func rollback(gameDir: String, rollbackRef: String) {
        guard let apiClient else {
            statusText = "Core endpoint is not connected."
            return
        }
        isWorking = true
        statusText = "Rolling back performance profile..."
        Task {
            do {
                let response = try await apiClient.rollbackPerformanceProfile(
                    CorePerformanceRollbackRequest(gameDir: gameDir, rollbackRef: rollbackRef)
                )
                await MainActor.run {
                    lastAppliedProfile = response.profile
                    statusText = response.rolledBack ? "Rolled back and cooldown recorded." : "No applied profile to roll back."
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    statusText = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }
}
