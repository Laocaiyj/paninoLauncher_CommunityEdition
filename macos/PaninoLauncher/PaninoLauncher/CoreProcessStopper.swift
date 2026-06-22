import Darwin
import Foundation

@MainActor
enum CoreProcessStopper {
    static func stop(_ process: Process, apiClient: LauncherApiClient?) async {
        if process.isRunning, let apiClient {
            try? await apiClient.shutdown()
            if await waitForExit(process, timeoutNanoseconds: 1_500_000_000) {
                return
            }
        }

        if process.isRunning {
            process.terminate()
            if await waitForExit(process, timeoutNanoseconds: 1_000_000_000) {
                return
            }
        }

        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
            _ = await waitForExit(process, timeoutNanoseconds: 800_000_000)
        }
    }

    private static func waitForExit(_ process: Process, timeoutNanoseconds: UInt64) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while process.isRunning && DispatchTime.now().uptimeNanoseconds < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return !process.isRunning
    }
}
