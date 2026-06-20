import SwiftUI

extension SettingsCenterPage {
    func runSourceTest() {
        sourceTestRunning = true
        sourceTestMessage = "Checking connection through Core..."
        Task {
            do {
                let response = try await viewModel.sourceTest()
                await MainActor.run {
                    sourceTestResponse = response
                    sourceTestMessage = response.ok ? "Connection check passed" : "Connection check found failures"
                    sourceTestRunning = false
                }
            } catch {
                await MainActor.run {
                    sourceTestMessage = "Connection check failed: \(error.localizedDescription)"
                    sourceTestRunning = false
                }
            }
        }
    }

    func runSpeedTest() {
        speedTestRunning = true
        speedTestMessage = "Measuring download throughput..."
        let reportRequest = CoreEnvironmentReportRequest(
            gameDir: launcherSettings.defaultGameDirectory,
            version: viewModel.version,
            loader: nil,
            loaderVersion: nil,
            memoryMb: viewModel.memoryMb,
            memoryPolicy: launcherSettings.memoryPolicy.rawValue,
            jvmProfile: launcherSettings.jvmProfile.rawValue,
            customMemoryMb: launcherSettings.memoryPolicy == .custom ? viewModel.memoryMb : nil,
            customJvmArgs: launcherSettings.jvmArguments,
            graphicsProfile: launcherSettings.graphicsProfile.rawValue
        )
        Task {
            do {
                async let speed = viewModel.speedTest()
                async let environment = viewModel.environmentReport(reportRequest)
                let response = try await speed
                let report = try await environment
                await MainActor.run {
                    speedTestResponse = response
                    diagnosticsStore.lastNetworkSpeedTest = response
                    diagnosticsStore.lastEnvironmentReport = report
                    let fastest = response.fastestResult.map { formattedBytes($0.bytesPerSecond) + "/s" } ?? "-"
                    speedTestMessage = response.ok ? "Fastest: \(fastest)" : "Speed test found failures"
                    speedTestRunning = false
                }
            } catch {
                await MainActor.run {
                    speedTestMessage = "Speed test failed: \(error.localizedDescription)"
                    speedTestRunning = false
                }
            }
        }
    }

    func restartCore() {
        Task {
            await viewModel.shutdownCore()
            await viewModel.startCoreIfNeeded()
        }
    }
}
