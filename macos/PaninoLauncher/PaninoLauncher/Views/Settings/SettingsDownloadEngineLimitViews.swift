import SwiftUI

struct DownloadEngineLimitsView: View {
    let strategy: DownloadStrategy
    let maxWorkers: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
            EngineLimitTile(title: "Global", value: "\(effectiveMaxWorkers)")
            EngineLimitTile(title: "Per-host", value: perHostText)
            EngineLimitTile(title: "Multipart", value: multipartText)
            EngineLimitTile(title: "Segment", value: "8-16 MB")
        }
    }

    private var effectiveMaxWorkers: Int {
        switch strategy {
        case .auto:
            return maxWorkers
        case .fast:
            return max(maxWorkers, 48)
        case .conservative:
            return min(maxWorkers, 12)
        }
    }

    private var perHostText: String {
        switch strategy {
        case .auto:
            return "AIMD"
        case .fast:
            return "AIMD+"
        case .conservative:
            return "Capped"
        }
    }

    private var multipartText: String {
        switch strategy {
        case .auto:
            return "32 MB+"
        case .fast:
            return "32 MB+"
        case .conservative:
            return "Range only"
        }
    }
}

private struct EngineLimitTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}
