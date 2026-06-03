import SwiftUI

struct InstallPlanReviewSheet: View {
    let plan: CoreTypedInstallPlan
    let title: String
    let subtitle: String
    let confirmTitle: String
    var repairTitle: String?
    let onCancel: () -> Void
    var onRepair: (() -> Void)?
    let onConfirm: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    private var isBlocked: Bool {
        plan.status == "blocked" || !plan.blockedReasons.isEmpty
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
                    title: localizedString(theme.language, english: "Needs attention", chinese: "需要先处理", italian: "Richiede attenzione", french: "À vérifier", spanish: "Requiere atención"),
                    systemImage: "exclamationmark.triangle"
                ) {
                    blockedSummary
                }
            }

            if !plan.warnings.isEmpty {
                reviewSection(
                    title: localizedString(theme.language, english: "Notes", chinese: "提示", italian: "Note", french: "Notes", spanish: "Notas"),
                    systemImage: "info.circle"
                ) {
                    plan.warnings.joined(separator: "\n")
                }
            }

            reviewSection(
                title: localizedString(theme.language, english: "Actions", chinese: "将执行", italian: "Azioni", french: "Actions", spanish: "Acciones"),
                systemImage: "list.bullet.rectangle"
            ) {
                actionSummary
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    planIdentity
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(plan.nodes.prefix(18), id: \.id) { node in
                            nodeRow(node)
                        }
                        if plan.nodes.count > 18 {
                            Text(localizedString(theme.language, english: "\(plan.nodes.count - 18) more nodes", chinese: "另有 \(plan.nodes.count - 18) 个节点", italian: "Altri \(plan.nodes.count - 18) nodi", french: "\(plan.nodes.count - 18) noeuds en plus", spanish: "\(plan.nodes.count - 18) nodos más"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                Label(
                    localizedString(theme.language, english: "Advanced plan", chinese: "高级计划", italian: "Piano avanzato", french: "Plan avancé", spanish: "Plan avanzado"),
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
                .font(.callout.weight(.semibold))
            }

            HStack {
                Button(localizedString(theme.language, english: "Cancel", chinese: "取消", italian: "Annulla", french: "Annuler", spanish: "Cancelar"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                if let repairTitle, let onRepair {
                    Button(repairTitle, action: onRepair)
                }
                Spacer()
                Button(confirmTitle, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBlocked)
            }
        }
        .padding(22)
        .frame(width: 760)
        .frame(minHeight: 520)
    }

    private var metricItems: [MetricStripItem] {
        [
            MetricStripItem(
                title: localizedString(theme.language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar"),
                value: "\(plan.summary.downloadNodes)",
                systemImage: "arrow.down.circle"
            ),
            MetricStripItem(
                title: localizedString(theme.language, english: "Keep", chinese: "保留", italian: "Mantieni", french: "Conserver", spanish: "Mantener"),
                value: "\(plan.summary.keepNodes)",
                systemImage: "checkmark.circle"
            ),
            MetricStripItem(
                title: localizedString(theme.language, english: "Replace", chinese: "替换", italian: "Sostituisci", french: "Remplacer", spanish: "Reemplazar"),
                value: "\(plan.summary.replaceNodes)",
                systemImage: "arrow.triangle.2.circlepath"
            ),
            MetricStripItem(
                title: localizedString(theme.language, english: "Write", chinese: "写入", italian: "Scrivi", french: "Écrire", spanish: "Escribir"),
                value: "\(plan.summary.writeNodes)",
                systemImage: "square.and.pencil"
            ),
            MetricStripItem(
                title: localizedString(theme.language, english: "Download", chinese: "下载", italian: "Download", french: "Téléchargement", spanish: "Descarga"),
                value: plan.summary.estimatedBytes.map(formattedBytes) ?? "-",
                systemImage: "externaldrive.badge.icloud"
            )
        ]
    }

    private var actionSummary: String {
        if plan.nodes.isEmpty {
            return localizedString(theme.language, english: "No file changes.", chinese: "没有文件变更。", italian: "Nessuna modifica file.", french: "Aucune modification de fichier.", spanish: "Sin cambios de archivos.")
        }
        let lines = plan.nodes.prefix(10).map { node in
            let target = node.targetPath.map { " -> \($0)" } ?? ""
            return "\(node.action): \(node.label)\(target)"
        }
        let remaining = plan.nodes.count - lines.count
        if remaining > 0 {
            return (lines + [localizedString(theme.language, english: "\(remaining) more actions", chinese: "另有 \(remaining) 个动作", italian: "Altre \(remaining) azioni", french: "\(remaining) actions en plus", spanish: "\(remaining) acciones más")]).joined(separator: "\n")
        }
        return lines.joined(separator: "\n")
    }

    private var blockedSummary: String {
        let reasons = plan.blockedReasons.isEmpty
            ? localizedString(theme.language, english: "This plan is blocked.", chinese: "这个计划暂时不能继续。", italian: "Questo piano è bloccato.", french: "Ce plan est bloqué.", spanish: "Este plan está bloqueado.")
            : plan.blockedReasons.joined(separator: "\n")
        let fixes = suggestedFixes
        guard !fixes.isEmpty else { return reasons }
        return reasons + "\n\n" + fixes.joined(separator: "\n")
    }

    private var suggestedFixes: [String] {
        let lowercasedReasons = plan.blockedReasons.map { $0.lowercased() }
        var fixes: [String] = []
        if lowercasedReasons.contains(where: { $0.contains("curseforge") || $0.contains("api_key") }) {
            fixes.append(localizedString(theme.language, english: "Add the CurseForge API Key in Settings, then try again.", chinese: "先在设置里填写 CurseForge API Key，然后重试。", italian: "Aggiungi la chiave API CurseForge nelle impostazioni e riprova.", french: "Ajoutez la clé API CurseForge dans les réglages puis réessayez.", spanish: "Agrega la API Key de CurseForge en Ajustes y vuelve a intentar."))
        }
        if lowercasedReasons.contains(where: { $0.contains("target") || $0.contains("directory") || $0.contains("game_dir") }) {
            fixes.append(localizedString(theme.language, english: "Choose an empty isolated game folder.", chinese: "选择一个空的独立游戏目录。", italian: "Scegli una cartella istanza vuota.", french: "Choisissez un dossier d'instance vide.", spanish: "Elige una carpeta de instancia vacía."))
        }
        if lowercasedReasons.contains(where: { $0.contains("dependency") }) {
            fixes.append(localizedString(theme.language, english: "Pick a compatible release so Panino can resolve required dependencies.", chinese: "选择兼容版本，让 Panino 能解析必需依赖。", italian: "Scegli una release compatibile per risolvere le dipendenze.", french: "Choisissez une version compatible pour résoudre les dépendances.", spanish: "Elige una versión compatible para resolver dependencias."))
        }
        if lowercasedReasons.contains(where: { $0.contains("compatible") || $0.contains("conflict") || $0.contains("optifine") }) {
            fixes.append(localizedString(theme.language, english: "Resolve incompatible files in the instance before continuing.", chinese: "先处理实例里的不兼容文件。", italian: "Risolvi i file incompatibili prima di continuare.", french: "Corrigez les fichiers incompatibles avant de continuer.", spanish: "Resuelve los archivos incompatibles antes de continuar."))
        }
        return fixes.isEmpty
            ? [localizedString(theme.language, english: "Fix the listed issue, then generate the plan again.", chinese: "处理上面的问题后重新生成计划。", italian: "Correggi il problema e rigenera il piano.", french: "Corrigez le problème puis régénérez le plan.", spanish: "Corrige el problema y genera el plan otra vez.")]
            : fixes
    }

    private var planIdentity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("planId: \(plan.planId)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("fingerprint: \(plan.fingerprint)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let targetGameDir = plan.targetGameDir {
                Text("target: \(targetGameDir)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("edges: \(plan.edges.count) · rollback: \(plan.rollbackPolicy)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
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
                HStack(spacing: 8) {
                    Text(node.kind)
                    if let targetPath = node.targetPath {
                        Text(targetPath)
                    }
                    if let sha1 = node.sha1 {
                        Text(sha1)
                    }
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
