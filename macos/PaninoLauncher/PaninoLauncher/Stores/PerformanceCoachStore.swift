import Foundation
import SwiftUI

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

struct PerformanceEvidencePanel: View {
    let recommendation: CorePerformanceRecommendation?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let recommendation {
                Label(confidenceTitle(recommendation.confidence), systemImage: "gauge.with.dots.needle.67percent")
                    .font(.caption.weight(.semibold))
                ForEach(Array(recommendation.evidence.prefix(6)), id: \.key) { item in
                    HStack {
                        Text(item.key)
                            .font(.caption)
                        Spacer()
                        Text(item.value)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let rollbackRef = recommendation.rollbackRef {
                    Label("Rollback: \(rollbackRef)", systemImage: "arrow.uturn.backward.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No performance evidence loaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func confidenceTitle(_ value: String) -> String {
        switch value {
        case "measured_once":
            return "Measured once"
        case "measured_stable":
            return "Measured stable"
        case "experiment_won":
            return "Experiment winner"
        case "blocked":
            return "Blocked"
        default:
            return "Estimated baseline"
        }
    }
}

struct PerformanceExperimentBanner: View {
    let candidate: CorePerformanceCandidateResponse?

    var body: some View {
        if let candidate {
            Label(
                candidate.safetyGate.allowed
                    ? "One candidate ready for the next launch."
                    : "Candidate blocked: \(candidate.safetyGate.reasons.joined(separator: ", "))",
                systemImage: candidate.safetyGate.allowed ? "checkmark.seal" : "exclamationmark.triangle"
            )
            .font(.caption)
            .foregroundStyle(candidate.safetyGate.allowed ? Color.secondary : Color.orange)
        }
    }
}

struct PerformanceProfileReviewSheet: View {
    let recommendation: CorePerformanceRecommendation
    let candidate: CorePerformanceCandidateResponse?
    let isWorking: Bool
    let statusText: String
    let onGenerateCandidate: (String?) -> Void
    let onApply: (CorePerformanceProfile) -> Void
    let onRollback: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance profile")
                        .font(.headline)
                    Text(recommendation.confidence == "estimated" ? "Estimated baseline" : "Measured recommendation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let rollbackRef = recommendation.rollbackRef {
                    Button("Rollback") {
                        onRollback(rollbackRef)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking)
                }
                Button("Candidate") {
                    onGenerateCandidate(recommendation.baseline.profileId)
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)
                Button("Apply") {
                    onApply(candidate?.candidate ?? recommendation.candidate ?? recommendation.baseline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || candidate?.safetyGate.allowed == false)
            }

            if !statusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            PerformanceExperimentBanner(candidate: candidate)
            LaunchComparisonView(baseline: recommendation.baseline, candidate: recommendation.candidate)
            PerformanceEvidencePanel(recommendation: recommendation)
        }
        .padding(18)
        .frame(minWidth: 520, idealWidth: 620, maxWidth: 720, alignment: .topLeading)
    }
}

struct LaunchComparisonView: View {
    let baseline: CorePerformanceProfile
    let candidate: CorePerformanceProfile?

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
            GridRow {
                Text("Knob")
                    .font(.caption.weight(.semibold))
                Text("Current")
                    .font(.caption.weight(.semibold))
                Text("Candidate")
                    .font(.caption.weight(.semibold))
            }
            ForEach(comparisonRows, id: \.name) { row in
                GridRow {
                    Text(row.name)
                        .font(.caption)
                    Text(row.current)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(row.candidate)
                        .font(.caption)
                        .foregroundStyle(row.changed ? Color.primary : Color.secondary)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var comparisonRows: [ComparisonRow] {
        let candidateKnobs = candidate?.knobs
        return [
            ComparisonRow("Heap max", baseline.knobs.heapMaxMb.map { "\($0) MB" }, candidateKnobs?.heapMaxMb.map { "\($0) MB" }),
            ComparisonRow("GC policy", baseline.knobs.gcPolicy, candidateKnobs?.gcPolicy),
            ComparisonRow("Render distance", baseline.knobs.renderDistance.map(String.init), candidateKnobs?.renderDistance.map(String.init)),
            ComparisonRow("Simulation distance", baseline.knobs.simulationDistance.map(String.init), candidateKnobs?.simulationDistance.map(String.init)),
            ComparisonRow("Max FPS", baseline.knobs.maxFps.map(String.init), candidateKnobs?.maxFps.map(String.init)),
            ComparisonRow("VSync", baseline.knobs.vsyncPolicy, candidateKnobs?.vsyncPolicy)
        ]
    }

    private struct ComparisonRow {
        let name: String
        let current: String
        let candidate: String
        let changed: Bool

        init(_ name: String, _ current: String?, _ candidate: String?) {
            self.name = name
            self.current = current ?? "-"
            self.candidate = candidate ?? current ?? "-"
            self.changed = current != nil && candidate != nil && current != candidate
        }
    }
}

struct PerformancePrivacySettings: View {
    @Binding var keepLocalSessions: Bool
    @Binding var allowExperiments: Bool
    @Binding var shareAnonymousPriors: Bool
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(localizedString(language, english: "Keep local performance sessions", chinese: "保留本机性能会话", italian: "Conserva sessioni locali", french: "Garder les sessions locales", spanish: "Guardar sesiones locales"), isOn: $keepLocalSessions)
                .toggleStyle(.switch)
            Toggle(localizedString(language, english: "Allow one-candidate experiments", chinese: "允许单候选实验", italian: "Consenti esperimenti", french: "Autoriser les essais", spanish: "Permitir experimentos"), isOn: $allowExperiments)
                .toggleStyle(.switch)
            Toggle(localizedString(language, english: "Share anonymous profile priors", chinese: "分享匿名 profile priors", italian: "Condividi prior anonimi", french: "Partager des priors anonymes", spanish: "Compartir priors anónimos"), isOn: $shareAnonymousPriors)
                .toggleStyle(.switch)
            Label(
                localizedString(
                    language,
                    english: "Performance data stays in the instance folder by default. Anonymous priors are opt-in and aggregate-only.",
                    chinese: "性能数据默认只保存在实例目录。匿名 priors 必须显式开启，且只使用聚合指标。",
                    italian: "I dati restano nella cartella istanza. I prior anonimi sono facoltativi e aggregati.",
                    french: "Les données restent dans le dossier d'instance. Les priors anonymes sont optionnels et agrégés.",
                    spanish: "Los datos quedan en la instancia. Los priors anónimos son opcionales y agregados."
                ),
                systemImage: "lock.shield"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
