import Foundation

@MainActor
final class PackDoctorStore: ObservableObject {
    @Published private(set) var report: CoreCompatibilityReport?
    @Published private(set) var statusText = ""
    @Published private(set) var isWorking = false

    private var apiClient: LauncherApiClient?
    private var lastSignature = ""

    init(apiClient: LauncherApiClient? = nil) {
        self.apiClient = apiClient
    }

    func configure(endpoint: CoreEndpoint) {
        apiClient = LauncherApiClient(endpoint: endpoint)
    }

    func refresh(instance: GameInstance, force: Bool = false) {
        guard let apiClient else {
            statusText = "Core endpoint is not connected."
            return
        }
        let request = Self.compatibilityRequest(for: instance)
        let signature = [
            request.target.minecraftVersion ?? "",
            request.target.loader ?? "",
            request.target.loaderVersion ?? "",
            request.target.gameDir ?? ""
        ].joined(separator: "|")
        guard force || signature != lastSignature else { return }
        lastSignature = signature
        isWorking = true
        statusText = "Checking Pack Doctor state..."
        Task {
            do {
                let nextReport = try await apiClient.evaluateCompatibility(request)
                await MainActor.run {
                    report = nextReport
                    statusText = nextReport.summary
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

    static func compatibilityRequest(for instance: GameInstance) -> CoreCompatibilityEvaluateRequest {
        CoreCompatibilityEvaluateRequest(
            target: CoreCompatibilityTarget(
                minecraftVersion: instance.contentMinecraftVersion,
                loader: instance.loader?.rawValue,
                loaderVersion: instance.loaderVersion,
                shaderLoader: nil,
                gameDir: instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instance.gameDirectory,
                javaMajor: nil,
                requiredJavaMajor: nil,
                javaArch: nil,
                systemArch: systemArch
            )
        )
    }

    private static var systemArch: String {
        #if arch(arm64)
        return "aarch64"
        #elseif arch(x86_64)
        return "x64"
        #else
        return "unknown"
        #endif
    }
}
