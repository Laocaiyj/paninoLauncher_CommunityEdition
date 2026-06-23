import SwiftUI

struct AccountCard: View {
    let accountState: AccountConnectionState

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusStyle.color.opacity(0.18))
                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundStyle(statusStyle.color)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppText.microsoftAccount.localized(theme.language))
                        .font(.headline)
                    Text(accountState.localizedTitle(theme.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Spacer()

                StatusBadge(title: statusTitle, style: statusStyle)
            }
        }
    }

    private var statusTitle: String {
        switch accountState {
        case .signedIn:
            return AppText.signedIn.localized(theme.language)
        case .restoring:
            return AppText.restoring.localized(theme.language)
        case .waitingForDeviceCode:
            return AppText.waiting.localized(theme.language)
        case .failed:
            return AppText.error.localized(theme.language)
        case .signedOut:
            return AppText.signedOut.localized(theme.language)
        }
    }

    private var statusStyle: StatusBadge.Style {
        switch accountState {
        case .signedIn:
            return .success
        case .restoring, .waitingForDeviceCode:
            return .running
        case .failed:
            return .error
        case .signedOut:
            return .neutral
        }
    }

    private var statusIcon: String {
        switch accountState {
        case .signedIn:
            return "person.crop.circle.fill.badge.checkmark"
        case .restoring, .waitingForDeviceCode:
            return "person.crop.circle.badge.clock"
        case .failed:
            return "person.crop.circle.badge.exclamationmark"
        case .signedOut:
            return "person.crop.circle"
        }
    }
}

struct InstanceCard: View {
    let title: String
    let subtitle: String
    let status: StatusBadge.Style
    let icon: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                        .fill(status.color.opacity(0.16))
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(status.color)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer()

                StatusBadge(title: statusTitle, style: status)
            }
        }
    }

    private var statusTitle: String {
        switch status {
        case .success:
            return AppText.ready.localized(theme.language)
        case .warning:
            return AppText.attention.localized(theme.language)
        case .error:
            return AppText.failed.localized(theme.language)
        case .download:
            return AppText.downloading.localized(theme.language)
        case .running:
            return AppText.running.localized(theme.language)
        case .neutral:
            return AppText.idle.localized(theme.language)
        }
    }
}

struct DeviceCodePanel: View {
    let session: DeviceCodeSession
    let onCancel: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(session.userCode)
                    .font(.system(.title3, design: .monospaced).bold())
                    .textSelection(.enabled)

                Link(AppText.openMicrosoft.localized(theme.language), destination: session.verificationURI)

                GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: onCancel)
            }

            Text(session.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.card))
    }
}
