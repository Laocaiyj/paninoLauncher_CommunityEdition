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
            LockfileReviewHeader(title: title, subtitle: subtitle, isBlocked: isBlocked)

            MetricStrip(items: metricItems)

            if isBlocked {
                LockfileReviewTextSection(
                    title: localizedString(theme.language, english: "Blocked", chinese: "已阻断", italian: "Bloccato", french: "Bloqué", spanish: "Bloqueado"),
                    systemImage: "exclamationmark.triangle",
                    text: blockedText
                )
            }

            if !result.conflicts.isEmpty {
                LockfileReviewTextSection(
                    title: localizedString(theme.language, english: "Conflicts", chinese: "冲突", italian: "Conflitti", french: "Conflits", spanish: "Conflictos"),
                    systemImage: "bolt.trianglebadge.exclamationmark",
                    text: conflictText
                )
            }

            if !dependencyReasonText.isEmpty {
                LockfileReviewTextSection(
                    title: localizedString(theme.language, english: "Dependency Reasons", chinese: "依赖原因", italian: "Motivi dipendenze", french: "Raisons des dépendances", spanish: "Motivos de dependencias"),
                    systemImage: "point.3.connected.trianglepath.dotted",
                    text: dependencyReasonText
                )
            }

            if !versionChangeText.isEmpty {
                LockfileReviewTextSection(
                    title: localizedString(theme.language, english: "Version Changes", chinese: "版本变化", italian: "Cambi versione", french: "Changements de version", spanish: "Cambios de versión"),
                    systemImage: "arrow.triangle.2.circlepath",
                    text: versionChangeText
                )
            }

            if !riskText.isEmpty {
                LockfileReviewTextSection(
                    title: localizedString(theme.language, english: "Risk", chinese: "风险", italian: "Rischio", french: "Risque", spanish: "Riesgo"),
                    systemImage: "shield.lefthalf.filled",
                    text: riskText
                )
            }

            LockfileAdvancedSection(result: result)

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

}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []
        return filter { seen.insert($0).inserted }
    }
}
