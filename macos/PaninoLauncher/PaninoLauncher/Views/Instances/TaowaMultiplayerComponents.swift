import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct TaowaProfileDraft: Equatable {
    var displayName = ""
    var serverAddr = ""
    var serverPort = "7000"
    var token = ""
    var remotePort = "25565"
    var frpcPath = ""
    var enabled = true
    var hasExistingToken = false

    init() {}

    init(profile: CoreTaowaFrpProfile) {
        displayName = profile.displayName
        serverAddr = profile.serverAddr
        serverPort = String(profile.serverPort)
        token = ""
        remotePort = String(profile.remotePort)
        frpcPath = profile.frpcPath
        enabled = profile.enabled
        hasExistingToken = profile.hasToken
    }

    func request(profileId: String?) -> CoreTaowaFrpProfileRequest? {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let addr = serverAddr.trimmingCharacters(in: .whitespacesAndNewlines)
        let frpc = frpcPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              !addr.isEmpty,
              !frpc.isEmpty,
              let serverPortValue = Int(serverPort.trimmingCharacters(in: .whitespacesAndNewlines)),
              let remotePortValue = Int(remotePort.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(serverPortValue),
              (1...65535).contains(remotePortValue)
        else {
            return nil
        }
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return CoreTaowaFrpProfileRequest(
            profileId: profileId,
            displayName: name,
            serverAddr: addr,
            serverPort: serverPortValue,
            token: trimmedToken.isEmpty ? nil : trimmedToken,
            remotePort: remotePortValue,
            protocolName: "tcp",
            frpcPath: frpc,
            enabled: enabled
        )
    }
}

struct TaowaWorkflowStep: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let style: StatusBadge.Style
    let isReady: Bool
}

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

struct TaowaRequirement: Identifiable {
    enum State {
        case ready
        case warning
        case missing

        var systemImage: String {
            switch self {
            case .ready:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.circle.fill"
            case .missing:
                return "xmark.circle.fill"
            }
        }

        var style: StatusBadge.Style {
            switch self {
            case .ready:
                return .success
            case .warning:
                return .warning
            case .missing:
                return .error
            }
        }
    }

    let id: String
    let title: String
    let state: State
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

enum TaowaSessionStatusStyle {
    static func badgeStyle(for status: String) -> StatusBadge.Style {
        switch status {
        case "running":
            return .running
        case "stopped":
            return .neutral
        case "failed":
            return .error
        default:
            return .warning
        }
    }
}

struct TaowaProfileTestPanel: View {
    let test: CoreTaowaFrpProfileTestResponse
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    test.ok
                        ? localizedString(theme.language, english: "Profile test passed", chinese: "配置测试通过", italian: "Test profilo riuscito", french: "Test du profil réussi", spanish: "Prueba de perfil superada")
                        : localizedString(theme.language, english: "Profile test needs attention", chinese: "配置测试需要处理", italian: "Test profilo da controllare", french: "Test du profil à vérifier", spanish: "Prueba de perfil requiere atención"),
                    systemImage: test.ok ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(style.color)
                Spacer()
                StatusBadge(title: test.ok ? "ok" : localizedString(theme.language, english: "check failed", chinese: "检查失败", italian: "controllo fallito", french: "échec", spanish: "falló"), style: style)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                ForEach(test.checks) { check in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: check.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(check.ok ? StatusBadge.Style.success.color : StatusBadge.Style.error.color)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(check.name)
                                .font(.caption.weight(.semibold))
                            Text(check.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background((check.ok ? Color.green : Color.red).opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .padding(10)
        .background(style.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style.color.opacity(0.18), lineWidth: 1)
        }
    }

    private var style: StatusBadge.Style {
        test.ok ? .success : .warning
    }
}

struct TaowaSessionHistoryRow: View {
    let session: CoreTaowaSession
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(session.remoteAddress)
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    StatusBadge(title: session.status, style: style)
                }
                MetadataLine(items: [
                    "local \(session.localPort)",
                    "remote \(session.remotePort)",
                    session.updatedAt.formatted(date: .abbreviated, time: .shortened)
                ])
                if !session.diagnostics.isEmpty {
                    Text(session.diagnostics.first?.userSummary ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.color.opacity(isSelected ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(style.color.opacity(isSelected ? 0.42 : 0.14), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var style: StatusBadge.Style {
        TaowaSessionStatusStyle.badgeStyle(for: session.status)
    }
}

struct QRCodeImage: View {
    let value: String

    private static let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = makeImage() {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(10)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                }
        } else {
            ContentUnavailableView("QR", systemImage: "qrcode")
        }
    }

    private func makeImage() -> NSImage? {
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = Self.context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: transformed.extent.width, height: transformed.extent.height))
    }
}
