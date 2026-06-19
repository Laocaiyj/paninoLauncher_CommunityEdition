import SwiftUI

struct SettingsSectionButton: View {
    let section: PaninoSettingsSection
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            Text(section.title(language: theme.language))
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 38)
                .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                .fill(isSelected ? theme.semanticSelectionColor : Color.clear)
        }
    }
}

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

struct CacheSummaryTile: View {
    let summary: CacheScopeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(summary.sizeText)
                .font(.callout.weight(.semibold).monospacedDigit())
            Text(summary.path)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

enum SettingCapability {
    case available
    case requiresCoreRestart
    case advancedOnly
    case notImplemented
}

struct CapabilityNote: View {
    let capability: SettingCapability
    var detail: String? = nil

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        if let message = displayMessage, !message.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                if capability != .available {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                }
                Text(message)
                    .font(.caption)
                    .foregroundStyle(capability == .available ? .secondary : indicatorColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var displayMessage: String? {
        switch capability {
        case .available:
            return detail
        case .requiresCoreRestart:
            let restart = localizedString(
                theme.language,
                english: "Restart Core to apply this change.",
                chinese: "重启 Core 后生效。",
                italian: "Riavvia Core per applicare la modifica.",
                french: "Redémarrez Core pour appliquer ce changement.",
                spanish: "Reinicia Core para aplicar este cambio."
            )
            if let detail, !detail.isEmpty {
                return "\(restart) \(detail)"
            }
            return restart
        case .advancedOnly:
            return detail ?? localizedString(
                theme.language,
                english: "Visible when advanced controls are enabled.",
                chinese: "启用高级控制后显示。",
                italian: "Visibile quando i controlli avanzati sono attivi.",
                french: "Visible lorsque les contrôles avancés sont activés.",
                spanish: "Visible cuando los controles avanzados están activos."
            )
        case .notImplemented:
            return detail
        }
    }

    private var indicatorColor: Color {
        switch capability {
        case .available:
            return .secondary
        case .requiresCoreRestart:
            return .orange
        case .advancedOnly:
            return .blue
        case .notImplemented:
            return .secondary
        }
    }
}
