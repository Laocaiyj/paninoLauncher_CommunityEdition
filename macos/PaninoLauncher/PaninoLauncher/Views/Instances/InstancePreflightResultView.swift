import SwiftUI

struct InstancePreflightResultView: View {
    let preflight: CoreExportBackupPreflightResponse?
    let error: String
    let isChecking: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isChecking {
                Text("Core preflight is running...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            } else if let preflight {
                Text(preflight.allowed ? "Preflight passed" : "Preflight blocked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(preflight.allowed ? Color.green : Color.orange)
                if let estimatedBytes = preflight.estimatedBytes {
                    Text(ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(preflight.blockingReasons + preflight.warnings, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
