import Foundation

enum CoreProcessReadinessWaiter {
    @MainActor
    static func wait(
        endpoint: CoreEndpoint,
        terminationStatus: () -> Int32?
    ) async throws {
        let apiClient = LauncherApiClient(endpoint: endpoint)

        for _ in 0..<60 {
            if let status = terminationStatus() {
                throw CoreProcessManagerError.coreExitedEarly(status)
            }

            do {
                let response = try await apiClient.health()
                if response.status == "ok" {
                    return
                }
            } catch {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        throw CoreProcessManagerError.healthTimedOut
    }
}
