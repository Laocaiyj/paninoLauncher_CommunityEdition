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
            InstallPlanReviewHeader(title: title, subtitle: subtitle, isBlocked: isBlocked)

            MetricStrip(items: metricItems)

            if isBlocked {
                InstallPlanReviewTextSection(
                    title: localizedString(theme.language, english: "Needs attention", chinese: "需要先处理", italian: "Richiede attenzione", french: "À vérifier", spanish: "Requiere atención"),
                    systemImage: "exclamationmark.triangle",
                    text: blockedSummary
                )
            }

            if !plan.warnings.isEmpty {
                InstallPlanReviewTextSection(
                    title: localizedString(theme.language, english: "Notes", chinese: "提示", italian: "Note", french: "Notes", spanish: "Notas"),
                    systemImage: "info.circle",
                    text: plan.warnings.joined(separator: "\n")
                )
            }

            InstallPlanReviewTextSection(
                title: localizedString(theme.language, english: "Actions", chinese: "将执行", italian: "Azioni", french: "Actions", spanish: "Acciones"),
                systemImage: "list.bullet.rectangle",
                text: actionSummary
            )

            InstallPlanAdvancedDisclosure(plan: plan, language: theme.language)

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
}
