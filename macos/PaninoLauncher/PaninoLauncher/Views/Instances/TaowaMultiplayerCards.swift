import SwiftUI

struct TaowaStepCard: View {
    let step: TaowaWorkflowStep

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(step.style.color.opacity(0.18))
                Image(systemName: step.isReady ? "checkmark" : step.systemImage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(step.style.color)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(step.style.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(step.style.color.opacity(step.isReady ? 0.26 : 0.14), lineWidth: 1)
        }
    }
}

struct TaowaProfileCard: View {
    let profile: CoreTaowaFrpProfile
    let isSelected: Bool
    let hasActiveSession: Bool
    let onSelect: () -> Void
    let onCopyAddress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: profile.enabled ? "server.rack" : "pause.circle")
                    .foregroundStyle(style.color)
                Text(profile.displayName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(style.color)
                }
            }
            Text(profile.remoteAddress)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 6) {
                StatusBadge(title: profile.enabled ? "enabled" : "disabled", style: style)
                if profile.hasToken {
                    StatusBadge(title: "token", style: .neutral)
                }
                if hasActiveSession {
                    StatusBadge(title: "active", style: .running)
                }
                Spacer(minLength: 0)
                Button(action: onCopyAddress) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy remote address")
                .accessibilityLabel("Copy remote address")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.color.opacity(isSelected ? 0.14 : 0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style.color.opacity(isSelected ? 0.45 : 0.14), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(perform: onSelect)
    }

    private var style: StatusBadge.Style {
        if hasActiveSession {
            return .running
        }
        return profile.enabled ? .success : .warning
    }
}

struct TaowaRequirementRow: View {
    let requirement: TaowaRequirement

    var body: some View {
        Label {
            Text(requirement.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        } icon: {
            Image(systemName: requirement.state.systemImage)
                .foregroundStyle(requirement.state.style.color)
        }
        .accessibilityElement(children: .combine)
    }
}
