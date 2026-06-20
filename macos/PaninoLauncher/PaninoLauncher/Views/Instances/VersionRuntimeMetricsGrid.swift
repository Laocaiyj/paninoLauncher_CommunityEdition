import SwiftUI

struct VersionRuntimeMetricsGrid: View {
    let version: MinecraftVersionInfo?
    let instance: GameInstance

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 10)], spacing: 10) {
            VersionRuntimeMetricCard(
                title: AppText.java.localized(theme.language),
                value: version?.javaRequirement ?? "--",
                systemImage: "cup.and.saucer"
            )
            VersionRuntimeMetricCard(
                title: AppText.loader.localized(theme.language),
                value: instance.loader?.title ?? "Vanilla",
                systemImage: "puzzlepiece.extension"
            )
            VersionRuntimeMetricCard(
                title: AppText.download.localized(theme.language),
                value: version?.downloadState.localizedVersionState(theme.language) ?? "--",
                systemImage: "arrow.down.circle"
            )
            VersionRuntimeMetricCard(
                title: AppText.verify.localized(theme.language),
                value: version?.verificationState.localizedVersionState(theme.language) ?? "--",
                systemImage: "checkmark.seal"
            )
        }
    }
}

private struct VersionRuntimeMetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}
