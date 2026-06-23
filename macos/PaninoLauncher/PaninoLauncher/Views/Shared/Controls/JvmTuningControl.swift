import SwiftUI

struct JvmTuningControl: View {
    @Binding var memoryPolicy: InstanceMemoryPolicy
    @Binding var jvmProfile: InstanceJvmProfile
    @Binding var customMemoryMb: Int?

    let currentMemoryMb: Int
    var customJvmArguments: String = ""
    var lastSnapshot: JvmTuningSnapshot?
    var lastKnownGood: JvmTuningSnapshot?
    var resolved: CoreResolvedJvmTuning?
    var onRestoreAutomatic: () -> Void
    var onRestoreLastKnownGood: ((JvmTuningSnapshot) -> Void)?

    @EnvironmentObject var theme: ThemeSettings

    init(
        memoryPolicy: Binding<InstanceMemoryPolicy>,
        jvmProfile: Binding<InstanceJvmProfile>,
        customMemoryMb: Binding<Int?> = .constant(nil),
        currentMemoryMb: Int,
        customJvmArguments: String = "",
        lastSnapshot: JvmTuningSnapshot? = nil,
        lastKnownGood: JvmTuningSnapshot? = nil,
        resolved: CoreResolvedJvmTuning? = nil,
        onRestoreAutomatic: @escaping () -> Void,
        onRestoreLastKnownGood: ((JvmTuningSnapshot) -> Void)? = nil
    ) {
        self._memoryPolicy = memoryPolicy
        self._jvmProfile = jvmProfile
        self._customMemoryMb = customMemoryMb
        self.currentMemoryMb = currentMemoryMb
        self.customJvmArguments = customJvmArguments
        self.lastSnapshot = lastSnapshot
        self.lastKnownGood = lastKnownGood
        self.resolved = resolved
        self.onRestoreAutomatic = onRestoreAutomatic
        self.onRestoreLastKnownGood = onRestoreLastKnownGood
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: presetBinding) {
                ForEach(JvmTuningPreset.allCases) { preset in
                    Text(title(for: preset)).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 430)

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let advisoryText {
                Label(advisoryText, systemImage: advisoryIcon)
                    .font(.caption)
                    .foregroundStyle(advisoryColor)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                GlassButton(
                    systemImage: primaryActionIcon,
                    title: primaryActionTitle,
                    prominent: true,
                    action: performPrimaryAction
                )

                if let lastSnapshot {
                    Text(snapshotText(lastSnapshot))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}
