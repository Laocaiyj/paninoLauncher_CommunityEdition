import SwiftUI

struct StatusBadge: View {
    enum Style: Equatable {
        case neutral
        case success
        case warning
        case error
        case download
        case running

        var color: Color {
            switch self {
            case .neutral:
                return .secondary
            case .success:
                return .green
            case .warning:
                return .orange
            case .error:
                return .red
            case .download:
                return .blue
            case .running:
                return .teal
            }
        }
    }

    let title: String
    let style: Style

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(style.color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(style.color.opacity(0.14), in: Capsule())
        .foregroundStyle(style.color)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct MetadataLine: View {
    let items: [String]
    var font: Font = .caption
    var style: HierarchicalShapeStyle = .secondary
    var separator = " · "

    private var text: String {
        items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(style)
            .lineLimit(1)
            .truncationMode(.middle)
            .accessibilityLabel(text)
    }
}

struct CountText: View {
    let value: Int
    var suffix: String?
    var style: StatusBadge.Style = .neutral

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(style.color)
                .frame(width: 6, height: 6)
            Text(displayText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayText)
    }

    private var displayText: String {
        guard let suffix, !suffix.isEmpty else { return "\(value)" }
        return "\(value) \(suffix)"
    }
}

struct PlainStatusText: View {
    let title: String
    let style: StatusBadge.Style

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(style.color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(style.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct CompactStatusBadge: View {
    let title: String
    let style: StatusBadge.Style

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(style.color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .frame(maxWidth: 150)
        .background(style.color.opacity(0.14), in: Capsule())
        .foregroundStyle(style.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

extension InstanceStatus {
    var badgeStyle: StatusBadge.Style {
        switch self {
        case .notInstalled:
            return .warning
        case .ready:
            return .success
        case .installing:
            return .download
        case .running:
            return .running
        case .failed:
            return .error
        }
    }
}
