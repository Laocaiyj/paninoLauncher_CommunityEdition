import SwiftUI

extension LaunchDashboard {
    var graphicsPreflightItem: LaunchPreflightItem {
        let instance = selectedInstance
        if let snapshot = instance.lastGraphicsTuningSnapshot,
           snapshot.state == .failed,
           snapshot.renderRelatedError || snapshot.quickExit || snapshot.canRollback {
            return LaunchPreflightItem(
                id: "graphics",
                title: graphicsPreflightTitle,
                detail: graphicsFailureDetail(snapshot),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Switch Smoother", chinese: "切到更流畅", italian: "Più fluido", french: "Plus fluide", spanish: "Más fluido")
            ) {
                updateSelectedInstance { $0.graphicsProfile = .performance }
            }
        }

        if instance.graphicsProfile == .manual {
            return LaunchPreflightItem(
                id: "graphics",
                title: graphicsPreflightTitle,
                detail: localizedString(theme.language, english: "Manual graphics settings are active. Panino can return to the safe recommendation before launch.", chinese: "正在使用手动画面设置。启动前可以恢复 Panino 的安全推荐。", italian: "Grafica manuale attiva. Panino può tornare al consiglio sicuro.", french: "Réglages graphiques manuels actifs. Panino peut revenir au réglage sûr.", spanish: "Gráficos manuales activos. Panino puede volver al ajuste seguro."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Restore Auto", chinese: "恢复自动", italian: "Automatico", french: "Auto", spanish: "Auto")
            ) {
                updateSelectedInstance { $0.restoreAutomaticGraphicsTuning() }
            }
        }

        return LaunchPreflightItem(
            id: "graphics",
            title: graphicsPreflightTitle,
            detail: graphicsReadyDetail(instance),
            state: .ready
        )
    }

    private var graphicsPreflightTitle: String {
        localizedString(theme.language, english: "Graphics tuning", chinese: "画面调校", italian: "Tuning grafica", french: "Réglage graphismes", spanish: "Ajuste gráfico")
    }

    private func graphicsFailureDetail(_ snapshot: GraphicsTuningSnapshot) -> String {
        if snapshot.renderRelatedError {
            return localizedString(theme.language, english: "Last launch looked render or shader related. Switch to a smoother profile before trying again.", chinese: "上次启动像是渲染或 Shader 相关问题。再次启动前建议切到更流畅。", italian: "L'ultimo avvio sembra legato a rendering o shader. Passa a un profilo più fluido.", french: "Le dernier lancement semble lié au rendu ou aux shaders. Passez à un profil plus fluide.", spanish: "El último inicio parece de render o shaders. Cambia a un perfil más fluido.")
        }
        if snapshot.quickExit {
            return localizedString(theme.language, english: "The last session ended very quickly. If the screen stuttered or heated up, use the smoother graphics profile.", chinese: "上次会话很快结束。如果有卡顿或发热，先用更流畅画面配置。", italian: "L'ultima sessione è finita subito. Se c'erano scatti o calore, usa il profilo più fluido.", french: "La dernière session a été très courte. En cas de saccades ou chaleur, utilisez le profil fluide.", spanish: "La última sesión terminó rápido. Si hubo tirones o calor, usa el perfil fluido.")
        }
        return localizedString(theme.language, english: "Panino can lower graphics pressure before launch and keep the original settings recoverable.", chinese: "Panino 可以先降低画面压力，并保留恢复原设置的能力。", italian: "Panino può ridurre il carico grafico e mantenere il ripristino.", french: "Panino peut réduire la pression graphique et garder le retour arrière.", spanish: "Panino puede bajar presión gráfica y conservar recuperación.")
    }

    private func graphicsReadyDetail(_ instance: GameInstance) -> String {
        if let summary = instance.lastGraphicsTuningSnapshot?.tuningSummary,
           !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        switch instance.graphicsProfile {
        case .clarity:
            return localizedString(theme.language, english: "Clarity profile selected. Panino preserves sharpness and lowers expensive settings first.", chinese: "已选择清晰优先。Panino 会保留清晰度，优先降低高成本项。", italian: "Profilo nitidezza. Panino conserva chiarezza e riduce prima le opzioni costose.", french: "Profil clarté. Panino garde la netteté et réduit les options coûteuses.", spanish: "Perfil claridad. Panino conserva nitidez y baja ajustes costosos.")
        case .performance:
            return localizedString(theme.language, english: "Smoother profile selected. Good for Retina pressure, shaders, heat, or large packs.", chinese: "已选择更流畅。适合 Retina 压力、Shader、发热或大型整合包。", italian: "Profilo fluido. Utile per Retina, shader, calore o pacchetti grandi.", french: "Profil fluide. Utile pour Retina, shaders, chaleur ou gros packs.", spanish: "Perfil fluido. Útil para Retina, shaders, calor o packs grandes.")
        case .batterySaver:
            return localizedString(theme.language, english: "Battery profile selected. Panino lowers visual cost while playing unplugged.", chinese: "已选择省电。Panino 会在电池供电时降低画面成本。", italian: "Profilo batteria. Panino riduce il costo grafico a batteria.", french: "Profil batterie. Panino réduit le coût visuel sur batterie.", spanish: "Perfil batería. Panino baja el coste visual con batería.")
        case .manual:
            return localizedString(theme.language, english: "Manual graphics profile selected. Panino will warn before risky values are applied.", chinese: "已选择手动画面。高风险数值应用前 Panino 会提醒。", italian: "Profilo manuale. Panino avvisa prima dei valori rischiosi.", french: "Profil manuel. Panino alerte avant les valeurs risquées.", spanish: "Perfil manual. Panino avisa de valores riesgosos.")
        case .balanced:
            return localizedString(theme.language, english: "Automatic graphics selected. Panino balances clarity, smoothness, and heat for this Mac.", chinese: "已选择自动画面。Panino 会按这台 Mac 平衡清晰、流畅和发热。", italian: "Grafica automatica. Panino bilancia nitidezza, fluidità e calore.", french: "Graphismes automatiques. Panino équilibre clarté, fluidité et chaleur.", spanish: "Gráficos automáticos. Panino equilibra claridad, fluidez y calor.")
        }
    }
}
