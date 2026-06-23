import SwiftUI

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
