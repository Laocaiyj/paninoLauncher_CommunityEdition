import SwiftUI

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
