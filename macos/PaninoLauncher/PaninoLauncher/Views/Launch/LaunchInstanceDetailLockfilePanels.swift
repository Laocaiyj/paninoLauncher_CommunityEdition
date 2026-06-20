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

struct LaunchLockfileUpdatePanel: View {
    let language: AppLanguage
    let busy: Bool
    let onPolicySelected: (String) -> Void

    private let policies = LaunchLockfileUpdatePolicyOption.all

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(language, english: "Lockfile Updates", chinese: "锁文件更新", italian: "Aggiornamenti lockfile", french: "Mises à jour lockfile", spanish: "Actualizaciones lockfile"))
                    .font(.headline)

                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    ForEach(policies) { option in
                        LaunchLockfilePolicyButton(
                            option: option,
                            language: language,
                            busy: busy,
                            onSelect: onPolicySelected
                        )
                    }
                }
            }
        }
    }

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .top)]
    }
}

private struct LaunchLockfileUpdatePolicyOption: Identifiable {
    let policy: String
    let systemImage: String

    var id: String { policy }

    static let all: [LaunchLockfileUpdatePolicyOption] = [
        LaunchLockfileUpdatePolicyOption(policy: "keepLocked", systemImage: "lock"),
        LaunchLockfileUpdatePolicyOption(policy: "updateSelected", systemImage: "checklist.checked"),
        LaunchLockfileUpdatePolicyOption(policy: "updateAllSafe", systemImage: "shield.checkered"),
        LaunchLockfileUpdatePolicyOption(policy: "relock", systemImage: "arrow.triangle.2.circlepath")
    ]

    func title(language: AppLanguage) -> String {
        switch policy {
        case "updateSelected":
            return localizedString(language, english: "Update Selected", chinese: "只更新选中项", italian: "Aggiorna selezionati", french: "Mettre à jour sélection", spanish: "Actualizar selección")
        case "updateAllSafe":
            return localizedString(language, english: "Update All Safe", chinese: "安全更新全部", italian: "Aggiorna sicuro", french: "Tout mettre à jour sûr", spanish: "Actualizar seguro")
        case "relock":
            return localizedString(language, english: "Relock", chinese: "重新锁定", italian: "Riblocca", french: "Reverrouiller", spanish: "Rebloquear")
        default:
            return localizedString(language, english: "Keep Locked", chinese: "保持锁定", italian: "Mantieni bloccato", french: "Garder verrouillé", spanish: "Mantener fijado")
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch policy {
        case "updateSelected":
            return localizedString(language, english: "Selected packages and required dependencies.", chinese: "选中项目及必需依赖。", italian: "Elementi selezionati e dipendenze.", french: "Sélection et dépendances.", spanish: "Selección y dependencias.")
        case "updateAllSafe":
            return localizedString(language, english: "Compatible updates only.", chinese: "只接受兼容更新。", italian: "Solo aggiornamenti compatibili.", french: "Mises à jour compatibles.", spanish: "Solo compatibles.")
        case "relock":
            return localizedString(language, english: "Resolve from current inputs.", chinese: "按当前输入重新求解。", italian: "Risolvi dagli input attuali.", french: "Résoudre depuis les entrées.", spanish: "Resolver de nuevo.")
        default:
            return localizedString(language, english: "Preserve existing locked packages.", chinese: "保留已锁定内容。", italian: "Mantieni pacchetti bloccati.", french: "Conserver le verrou.", spanish: "Conservar bloqueados.")
        }
    }
}

private struct LaunchLockfilePolicyButton: View {
    let option: LaunchLockfileUpdatePolicyOption
    let language: AppLanguage
    let busy: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Button {
            onSelect(option.policy)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: option.systemImage)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title(language: language))
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(option.subtitle(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }
}
