import SwiftUI

struct LaunchResourceRiskPanel: View {
    let assetCount: Int
    let sourceSummary: String
    let recentChangeCount: Int
    let conflictCount: Int
    let missingDependencyCount: Int
    let archivedDeprecatedCount: Int
    let openResources: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Content Trust", chinese: "内容信任", italian: "Affidabilità", french: "Confiance", spanish: "Confianza"),
                        systemImage: "shield.lefthalf.filled"
                    )
                    Spacer()
                    MetadataLine(items: [sourceSummary], font: .caption.weight(.semibold))
                }

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                    LaunchMetric(title: localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"), value: "\(assetCount)")
                    LaunchMetric(title: localizedString(theme.language, english: "Recent", chinese: "最近变更", italian: "Recenti", french: "Récents", spanish: "Recientes"), value: "\(recentChangeCount)")
                    LaunchMetric(title: localizedString(theme.language, english: "Risk", chinese: "风险", italian: "Rischio", french: "Risque", spanish: "Riesgo"), value: riskSummary)
                }

                if assetCount >= 30 || conflictCount > 0 || missingDependencyCount > 0 || archivedDeprecatedCount > 0 {
                    Label(riskDetail, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(conflictCount > 0 || missingDependencyCount > 0 || archivedDeprecatedCount > 0 ? .orange : .secondary)
                } else {
                    Label(localizedString(theme.language, english: "No resource conflicts detected in the current scan.", chinese: "当前扫描未发现资源冲突。", italian: "Nessun conflitto risorse rilevato.", french: "Aucun conflit de ressources détecté.", spanish: "No se detectaron conflictos."), systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    GlassButton(systemImage: "list.bullet.rectangle", title: localizedString(theme.language, english: "Review", chinese: "查看资源", italian: "Controlla", french: "Vérifier", spanish: "Revisar"), action: openResources)
                }
            }
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .top)]
    }

    private var riskSummary: String {
        if conflictCount > 0 || missingDependencyCount > 0 || archivedDeprecatedCount > 0 {
            return "\(conflictCount + missingDependencyCount + archivedDeprecatedCount)"
        }
        return assetCount >= 30 ? "High" : "OK"
    }

    private var riskDetail: String {
        if conflictCount > 0 || missingDependencyCount > 0 || archivedDeprecatedCount > 0 {
            return localizedString(theme.language, english: "Conflicts, dependency warnings, or archived/deprecated hints should be reviewed before launch.", chinese: "启动前应先查看冲突、依赖风险或归档/弃用提示。", italian: "Controlla conflitti, dipendenze o indizi archiviati/deprecati prima dell'avvio.", french: "Vérifiez conflits, dépendances ou indices archivés/obsolètes avant lancement.", spanish: "Revisa conflictos, dependencias o indicios archivados/obsoletos antes de iniciar.")
        }
        return localizedString(theme.language, english: "This game configuration contains many third-party files; review sources after large changes.", chinese: "该游戏配置包含较多第三方文件；大量变更后建议检查来源。", italian: "Questa configurazione contiene molti file di terze parti; controlla le fonti dopo grandi modifiche.", french: "Cette configuration contient de nombreux fichiers tiers ; vérifiez les sources après de grands changements.", spanish: "Esta configuración contiene muchos archivos de terceros; revisa fuentes tras grandes cambios.")
    }
}
