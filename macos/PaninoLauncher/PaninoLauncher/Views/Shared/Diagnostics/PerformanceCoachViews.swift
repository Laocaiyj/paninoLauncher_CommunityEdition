import SwiftUI

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
