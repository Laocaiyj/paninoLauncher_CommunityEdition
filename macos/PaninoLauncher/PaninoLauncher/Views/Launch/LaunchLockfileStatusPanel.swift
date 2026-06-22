import SwiftUI

struct LaunchLockfileStatusPanel: View {
    let language: AppLanguage
    let fileCount: Int
    let driftCount: Int
    let repairReady: Bool
    let manualChangeCount: Int
    let statusTitle: String
    let badgeStyle: StatusBadge.Style
    let statusMessage: String
    let busy: Bool
    let onRefresh: () -> Void
    let onRepair: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(
                        localizedString(language, english: "Lockfile", chinese: "锁文件", italian: "Lockfile", french: "Lockfile", spanish: "Lockfile"),
                        systemImage: "lock.doc"
                    )
                    .font(.headline)
                    Spacer()
                    StatusBadge(title: statusTitle, style: badgeStyle)
                }

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: localizedString(language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"), value: "\(fileCount)")
                    LaunchMetric(title: localizedString(language, english: "Drift", chinese: "漂移", italian: "Deriva", french: "Dérive", spanish: "Deriva"), value: "\(driftCount)")
                    LaunchMetric(title: localizedString(language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar"), value: repairLabel)
                    LaunchMetric(title: localizedString(language, english: "Manual", chinese: "手动", italian: "Manuale", french: "Manuel", spanish: "Manual"), value: "\(manualChangeCount)")
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { actionButtons }
                    VStack(alignment: .leading, spacing: 10) { actionButtons }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .paninoTruncation(.summary(lines: 2))
                }
            }
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)]
    }

    private var repairLabel: String {
        repairReady
            ? localizedString(language, english: "Ready", chinese: "可用", italian: "Pronto", french: "Prêt", spanish: "Listo")
            : "-"
    }

    @ViewBuilder
    private var actionButtons: some View {
        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(language), action: onRefresh)
            .disabled(busy)

        if repairReady {
            GlassButton(
                systemImage: "wrench.and.screwdriver",
                title: localizedString(language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar"),
                action: onRepair
            )
            .disabled(busy)
        }
    }
}
