import SwiftUI

struct LockfileReviewSheet: View {
    let result: CoreLockfileSolverResult
    let title: String
    let subtitle: String
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    private var isBlocked: Bool {
        result.status == "blocked" || !result.blockedReasons.isEmpty || result.typedPlan.status == "blocked"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isBlocked ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isBlocked ? Color.orange : Color.green)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .paninoTruncation(.title)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .paninoTruncation(.summary(lines: 2))
                }
                Spacer(minLength: 0)
            }

            MetricStrip(items: metricItems)

            if isBlocked {
                reviewSection(
                    title: localizedString(theme.language, english: "Blocked", chinese: "已阻断", italian: "Bloccato", french: "Bloqué", spanish: "Bloqueado"),
                    systemImage: "exclamationmark.triangle"
                ) {
                    blockedText
                }
            }

            if !result.conflicts.isEmpty {
                reviewSection(
                    title: localizedString(theme.language, english: "Conflicts", chinese: "冲突", italian: "Conflitti", french: "Conflits", spanish: "Conflictos"),
                    systemImage: "bolt.trianglebadge.exclamationmark"
                ) {
                    conflictText
                }
            }

            if !dependencyReasonText.isEmpty {
                reviewSection(
                    title: localizedString(theme.language, english: "Dependency Reasons", chinese: "依赖原因", italian: "Motivi dipendenze", french: "Raisons des dépendances", spanish: "Motivos de dependencias"),
                    systemImage: "point.3.connected.trianglepath.dotted"
                ) {
                    dependencyReasonText
                }
            }

            if !versionChangeText.isEmpty {
                reviewSection(
                    title: localizedString(theme.language, english: "Version Changes", chinese: "版本变化", italian: "Cambi versione", french: "Changements de version", spanish: "Cambios de versión"),
                    systemImage: "arrow.triangle.2.circlepath"
                ) {
                    versionChangeText
                }
            }

            if !riskText.isEmpty {
                reviewSection(
                    title: localizedString(theme.language, english: "Risk", chinese: "风险", italian: "Rischio", french: "Risque", spanish: "Riesgo"),
                    systemImage: "shield.lefthalf.filled"
                ) {
                    riskText
                }
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text("fingerprint: \(result.lockfile?.fingerprint ?? result.typedPlan.fingerprint)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    ForEach(result.typedPlan.nodes.prefix(18), id: \.id) { node in
                        nodeRow(node)
                    }
                    if result.typedPlan.nodes.count > 18 {
                        Text(localizedString(theme.language, english: "\(result.typedPlan.nodes.count - 18) more nodes", chinese: "另有 \(result.typedPlan.nodes.count - 18) 个节点", italian: "Altri \(result.typedPlan.nodes.count - 18) nodi", french: "\(result.typedPlan.nodes.count - 18) noeuds en plus", spanish: "\(result.typedPlan.nodes.count - 18) nodos más"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            } label: {
                Label(
                    localizedString(theme.language, english: "Advanced lockfile", chinese: "高级锁文件", italian: "Lockfile avanzato", french: "Lockfile avancé", spanish: "Lockfile avanzado"),
                    systemImage: "doc.text.magnifyingglass"
                )
                .font(.callout.weight(.semibold))
            }

            HStack {
                Button(localizedString(theme.language, english: "Cancel", chinese: "取消", italian: "Annulla", french: "Annuler", spanish: "Cancelar"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(confirmTitle, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBlocked || result.lockfile == nil)
            }
        }
        .padding(22)
        .frame(width: 760)
        .frame(minHeight: 540)
    }

    private var metricItems: [MetricStripItem] {
        [
            MetricStripItem(title: localizedString(theme.language, english: "Add", chinese: "新增", italian: "Aggiungi", french: "Ajouter", spanish: "Agregar"), value: "\(result.changeset.add.count)", systemImage: "plus.circle"),
            MetricStripItem(title: localizedString(theme.language, english: "Keep", chinese: "保留", italian: "Mantieni", french: "Conserver", spanish: "Mantener"), value: "\(result.changeset.keep.count)", systemImage: "checkmark.circle"),
            MetricStripItem(title: localizedString(theme.language, english: "Replace", chinese: "替换", italian: "Sostituisci", french: "Remplacer", spanish: "Reemplazar"), value: "\(result.changeset.replace.count)", systemImage: "arrow.triangle.2.circlepath"),
            MetricStripItem(title: localizedString(theme.language, english: "Remove", chinese: "删除", italian: "Rimuovi", french: "Supprimer", spanish: "Eliminar"), value: "\(result.changeset.remove.count)", systemImage: "minus.circle"),
            MetricStripItem(title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar"), value: "\(result.changeset.repair.count)", systemImage: "wrench.and.screwdriver"),
            MetricStripItem(title: localizedString(theme.language, english: "Required Deps", chinese: "必需依赖", italian: "Dipendenze", french: "Dépendances", spanish: "Dependencias"), value: "\(requiredDependencyCount)", systemImage: "link")
        ]
    }

    private var requiredDependencyCount: Int {
        result.lockfile?.constraints.filter { constraint in
            constraint.required && constraint.relation == "requires" && constraint.sourcePackage != nil
        }.count ?? 0
    }

    private var blockedText: String {
        (result.blockedReasons + result.typedPlan.blockedReasons).uniqued().joined(separator: "\n")
    }

    private var conflictText: String {
        result.conflicts.prefix(8).map { conflict in
            "\(conflict.title): \(conflict.message)"
        }.joined(separator: "\n")
    }

    private var dependencyReasonText: String {
        result.explain.constraints
            .filter(\.required)
            .prefix(8)
            .map { entry in
                [entry.packageId, entry.constraintId, entry.reason]
                    .compactMap { $0 }
                    .joined(separator: " · ")
            }
            .joined(separator: "\n")
    }

    private var versionChangeText: String {
        result.changeset.replace.prefix(8).map { change in
            "\(change.displayName): \(change.fromVersionId ?? "-") -> \(change.toVersionId ?? "-")"
        }.joined(separator: "\n")
    }

    private var riskText: String {
        let warnings = result.warnings + result.typedPlan.warnings
        let majorChanges = result.changeset.replace.filter { change in
            guard let from = change.fromVersionId, let to = change.toVersionId else { return false }
            return from.split(separator: ".").first != to.split(separator: ".").first
        }
        let lines = warnings.uniqued() + majorChanges.map { "major-version-change: \($0.displayName)" }
        return lines.prefix(10).joined(separator: "\n")
    }

    private func reviewSection(title: String, systemImage: String, text: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
            Text(text())
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.30), in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
    }

    private func nodeRow(_ node: CoreInstallPlanNode) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(node.action)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.label)
                    .font(.caption.weight(.semibold))
                    .paninoTruncation(.title)
                Text([node.kind, node.targetPath].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []
        return filter { seen.insert($0).inserted }
    }
}
