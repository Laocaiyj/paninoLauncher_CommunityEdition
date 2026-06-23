import SwiftUI

extension GraphicsTuningControl {
    var primaryProfiles: [InstanceGraphicsProfile] {
        GraphicsTuningUIContract.primaryProfiles
    }

    var primaryActionTitle: String {
        if resolved == nil || resolved?.canApply == true {
            if resolved?.applyMode == "ask" || resolved?.confidence == "estimated" {
                return localizedString(theme.language, english: "Review Estimate", chinese: "确认估算画面", italian: "Rivedi stima", french: "Vérifier l'estimation", spanish: "Revisar estimación")
            }
            return localizedString(theme.language, english: "Apply Recommended", chinese: "应用推荐画面", italian: "Applica consigliato", french: "Appliquer recommandé", spanish: "Aplicar recomendado")
        }
        return localizedString(theme.language, english: "Check Graphics", chinese: "检查画面设置", italian: "Controlla grafica", french: "Vérifier graphismes", spanish: "Comprobar gráficos")
    }

    var primaryActionIcon: String {
        resolved == nil || resolved?.canApply == true ? "wand.and.stars" : "sparkle.magnifyingglass"
    }

    var summaryText: String {
        if let resolved {
            return [confidenceText(resolved.confidence), resolved.summary, evidenceText(resolved.evidence)]
                .compactMap { $0?.isEmpty == false ? $0 : nil }
                .joined(separator: " ")
        }
        switch graphicsProfile {
        case .clarity:
            return localizedString(theme.language, english: "Keeps the picture clear while Panino lowers expensive settings first.", chinese: "优先保持画面清晰，Panino 会先降低高成本设置。", italian: "Mantiene l'immagine chiara riducendo prima le opzioni costose.", french: "Garde l'image nette en réduisant d'abord les réglages coûteux.", spanish: "Mantiene la imagen clara y baja primero los ajustes costosos.")
        case .balanced:
            return localizedString(theme.language, english: "Recommended for most players. Panino balances clarity, smoothness, and heat for this Mac.", chinese: "大多数玩家选这个。Panino 会按这台 Mac 平衡清晰、流畅和发热。", italian: "Consigliato per quasi tutti. Panino bilancia nitidezza, fluidità e calore.", french: "Recommandé pour la plupart. Panino équilibre clarté, fluidité et chaleur.", spanish: "Recomendado para casi todos. Panino equilibra claridad, fluidez y calor.")
        case .performance:
            return localizedString(theme.language, english: "For stutter, heat, high refresh displays, shaders, or large modpacks.", chinese: "适合掉帧、发热、高刷屏、Shader 或大型整合包。", italian: "Per scatti, calore, schermi high refresh, shader o modpack grandi.", french: "Pour saccades, chaleur, écrans rapides, shaders ou gros packs.", spanish: "Para tirones, calor, pantallas rápidas, shaders o modpacks grandes.")
        case .batterySaver:
            return localizedString(theme.language, english: "Lowers visual cost when playing on battery.", chinese: "电池供电时降低画面成本。", italian: "Riduce il costo grafico a batteria.", french: "Réduit le coût visuel sur batterie.", spanish: "Baja el coste visual con batería.")
        case .manual:
            return localizedString(theme.language, english: "Manual graphics changes are kept, but Panino will still warn about risky values.", chinese: "保留手动画面设置，但 Panino 仍会提示高风险数值。", italian: "Le modifiche manuali restano, ma Panino segnala i rischi.", french: "Les réglages manuels restent, mais Panino signale les risques.", spanish: "Se conservan cambios manuales, pero Panino avisa de riesgos.")
        }
    }

    var warningText: String? {
        resolved?.warnings.first?.message
    }

    var warningIcon: String {
        resolved?.warnings.first?.severity == "error" ? "exclamationmark.triangle" : "info.circle"
    }

    var warningColor: Color {
        resolved?.warnings.first?.severity == "error" ? .orange : .secondary
    }

    var patchChanges: [CoreOptionsPatchChange] {
        resolved?.optionsPatch.changes.filter { $0.status != "keep" } ?? []
    }

    func patchValueText(_ change: CoreOptionsPatchChange) -> String {
        let old = change.oldValue ?? "-"
        let new = change.newValue ?? "-"
        return "\(old) -> \(new)"
    }

    func advancedTitle(for key: String) -> String {
        switch key {
        case "renderDistance":
            return localizedString(theme.language, english: "View Distance", chinese: "视距", italian: "Distanza vista", french: "Distance vue", spanish: "Distancia vista")
        case "simulationDistance":
            return localizedString(theme.language, english: "Simulation", chinese: "模拟距离", italian: "Simulazione", french: "Simulation", spanish: "Simulación")
        case "maxFps":
            return localizedString(theme.language, english: "Max FPS", chinese: "最高 FPS", italian: "FPS massimo", french: "FPS max", spanish: "FPS máximo")
        case "enableVsync":
            return "VSync"
        case "renderClouds":
            return localizedString(theme.language, english: "Clouds", chinese: "云", italian: "Nuvole", french: "Nuages", spanish: "Nubes")
        case "particles":
            return localizedString(theme.language, english: "Particles", chinese: "粒子", italian: "Particelle", french: "Particules", spanish: "Partículas")
        case "entityDistanceScaling":
            return localizedString(theme.language, english: "Entity Distance", chinese: "实体距离", italian: "Distanza entità", french: "Distance entités", spanish: "Distancia entidades")
        case "mipmapLevels":
            return "Mipmap"
        default:
            return key
        }
    }

    private func confidenceText(_ confidence: String?) -> String {
        switch confidence {
        case "measured_once":
            return localizedString(theme.language, english: "Measured once on this Mac.", chinese: "已在这台 Mac 上测过一次。", italian: "Misurato una volta su questo Mac.", french: "Mesuré une fois sur ce Mac.", spanish: "Medido una vez en este Mac.")
        case "measured_stable", "experiment_won":
            return localizedString(theme.language, english: "Verified by local launches.", chinese: "已通过本机启动验证。", italian: "Verificato da avvii locali.", french: "Vérifié par lancements locaux.", spanish: "Verificado con inicios locales.")
        case "blocked":
            return localizedString(theme.language, english: "Blocked by safety checks.", chinese: "已被安全检查阻止。", italian: "Bloccato dai controlli.", french: "Bloqué par sécurité.", spanish: "Bloqueado por seguridad.")
        default:
            return localizedString(theme.language, english: "Estimated graphics baseline, not measured yet.", chinese: "这是估算画面 baseline，尚未本机实测。", italian: "Baseline grafica stimata, non ancora misurata.", french: "Baseline graphique estimée, pas encore mesurée.", spanish: "Base gráfica estimada, aún no medida.")
        }
    }

    private func evidenceText(_ evidence: [CorePerformanceEvidence]?) -> String? {
        guard let evidence, !evidence.isEmpty else { return nil }
        let summary = evidence.prefix(2).map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return localizedString(theme.language, english: "Evidence: \(summary).", chinese: "证据：\(summary)。", italian: "Evidenza: \(summary).", french: "Preuves : \(summary).", spanish: "Evidencia: \(summary).")
    }
}
