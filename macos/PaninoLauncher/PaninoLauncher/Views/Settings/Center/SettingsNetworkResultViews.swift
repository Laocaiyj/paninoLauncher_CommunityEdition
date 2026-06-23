import SwiftUI

struct SourceTestResultsView: View {
    let response: CoreNetworkSourceTestResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(response.results) { result in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(result.endpoint)
                            .font(.caption.weight(.semibold))
                        Text(result.statusText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(result.ok ? .green : .orange)
                        Spacer(minLength: 0)
                    }
                    Text(result.selectedUrl ?? result.url)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let error = result.error, !result.ok {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct SpeedTestResultsView: View {
    let response: CoreNetworkSpeedTestResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Recommended Strategy")
                    .font(.caption.weight(.semibold))
                Text(recommendedStrategy.title)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            if let fastest = response.fastestResult {
                HStack(spacing: 8) {
                    Text("Fastest")
                        .font(.caption.weight(.semibold))
                    Text("\(fastest.endpoint) · \(formattedBytes(fastest.bytesPerSecond))/s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                    Spacer(minLength: 0)
                }
            }

            ForEach(response.results) { result in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(result.endpoint)
                            .font(.caption.weight(.semibold))
                        Text(result.statusText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(result.ok ? .green : .orange)
                        Spacer(minLength: 0)
                        Text(result.usedProxy ? "proxy" : "direct")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(result.candidateUrl)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let error = result.error, !result.ok {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var recommendedStrategy: DownloadStrategy {
        guard let fastest = response.fastestResult else { return .conservative }
        if fastest.bytesPerSecond >= 20 * 1024 * 1024 && fastest.rangeSupported {
            return .fast
        }
        if fastest.bytesPerSecond < 3 * 1024 * 1024 || !fastest.rangeSupported {
            return .conservative
        }
        return .auto
    }
}
