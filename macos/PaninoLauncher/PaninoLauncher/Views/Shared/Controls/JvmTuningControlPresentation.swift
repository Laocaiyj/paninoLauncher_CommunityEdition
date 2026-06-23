import SwiftUI

extension JvmTuningControl {
    var summaryText: String {
        if let resolved {
            return [confidenceText(resolved.confidence), resolved.summary, evidenceText(resolved.evidence)]
                .compactMap { $0?.isEmpty == false ? $0 : nil }
                .joined(separator: " ")
        }
        if memoryPolicy == .custom {
            let memory = customMemoryMb ?? currentMemoryMb
            return localizedString(
                theme.language,
                english: "Manual memory is \(memory) MB. Use this only when you know why the pack needs it.",
                chinese: "当前是手动内存 \(memory) MB。只有明确知道整合包需要时再这样做。",
                italian: "Memoria manuale: \(memory) MB. Usala solo quando sai che il pacchetto la richiede.",
                french: "Mémoire manuelle : \(memory) Mo. À utiliser seulement si le pack l'exige.",
                spanish: "Memoria manual: \(memory) MB. Úsala solo si el pack lo necesita."
            )
        }
        switch jvmProfile {
        case .largePack:
            return localizedString(
                theme.language,
                english: "For large modpacks. Panino still reserves memory for macOS, GPU, cache, and background apps.",
                chinese: "适合大型整合包。Panino 仍会给 macOS、GPU、缓存和后台程序留内存。",
                italian: "Per modpack grandi. Panino lascia comunque memoria a macOS, GPU, cache e app in background.",
                french: "Pour gros modpacks. Panino garde de la mémoire pour macOS, le GPU, le cache et les apps.",
                spanish: "Para modpacks grandes. Panino reserva memoria para macOS, GPU, caché y apps."
            )
        case .lowMemory, .batterySaver:
            return localizedString(
                theme.language,
                english: "Keeps Minecraft modest so smaller Macs stay responsive.",
                chinese: "让 Minecraft 少占一点，小内存 Mac 会更稳。",
                italian: "Limita Minecraft per mantenere reattivi i Mac con poca memoria.",
                french: "Garde Minecraft modeste pour que les petits Mac restent réactifs.",
                spanish: "Limita Minecraft para que los Mac con poca memoria sigan ágiles."
            )
        case .experimentalZgc:
            return localizedString(
                theme.language,
                english: "Experimental performance mode is enabled. Keep it for controlled tests only.",
                chinese: "已启用实验性能模式。只建议受控测试使用。",
                italian: "Modalità prestazioni sperimentale attiva. Solo per test controllati.",
                french: "Mode performance expérimental actif. À garder pour les tests.",
                spanish: "Modo experimental activo. Úsalo solo para pruebas controladas."
            )
        case .custom:
            return localizedString(
                theme.language,
                english: "Custom launch tuning is active. Panino will keep one final memory recommendation.",
                chinese: "正在使用自定义启动调校。Panino 会保留一组最终内存建议。",
                italian: "Tuning avvio personalizzato attivo. Panino conserva una raccomandazione memoria finale.",
                french: "Réglage de lancement personnalisé actif. Panino garde une recommandation mémoire finale.",
                spanish: "Ajuste de inicio personalizado activo. Panino deja una recomendación de memoria final."
            )
        case .auto:
            return localizedString(
                theme.language,
                english: "Recommended for most players. Panino chooses safe memory from this Mac and pack size.",
                chinese: "大多数玩家选这个。Panino 会按本机和整合包规模选择安全内存。",
                italian: "Consigliato per quasi tutti. Panino sceglie memoria sicura in base a Mac e pacchetto.",
                french: "Recommandé pour la plupart. Panino choisit la mémoire adaptée au Mac et au pack.",
                spanish: "Recomendado para casi todos. Panino elige memoria segura según el Mac y el pack."
            )
        }
    }

    func snapshotText(_ snapshot: JvmTuningSnapshot) -> String {
        let memory = snapshot.finalXmxMb.map { "\($0) MB" } ?? "\(snapshot.configuredMemoryMb) MB"
        let gc = snapshot.finalGc ?? "GC"
        switch snapshot.state {
        case .succeeded:
            return localizedString(theme.language, english: "Last good: \(memory), \(gc)", chinese: "上次可用：\(memory)，\(gc)", italian: "Ultima valida: \(memory), \(gc)", french: "Dernier bon : \(memory), \(gc)", spanish: "Último válido: \(memory), \(gc)")
        case .failed:
            return localizedString(theme.language, english: "Last failed: \(memory), \(gc)", chinese: "上次失败：\(memory)，\(gc)", italian: "Ultima fallita: \(memory), \(gc)", french: "Dernier échec : \(memory), \(gc)", spanish: "Último falló: \(memory), \(gc)")
        case .running:
            return localizedString(theme.language, english: "Launch running", chinese: "启动中", italian: "Avvio in corso", french: "Lancement en cours", spanish: "Iniciando")
        case .cancelled:
            return localizedString(theme.language, english: "Last launch cancelled", chinese: "上次启动已取消", italian: "Ultimo avvio annullato", french: "Dernier lancement annulé", spanish: "Último inicio cancelado")
        }
    }

    private func confidenceText(_ confidence: String?) -> String? {
        switch confidence {
        case "measured_once":
            return localizedString(theme.language, english: "Measured once on this Mac.", chinese: "已在这台 Mac 上测过一次。", italian: "Misurato una volta su questo Mac.", french: "Mesuré une fois sur ce Mac.", spanish: "Medido una vez en este Mac.")
        case "measured_stable", "experiment_won":
            return localizedString(theme.language, english: "Verified by local launches.", chinese: "已通过本机启动验证。", italian: "Verificato da avvii locali.", french: "Vérifié par lancements locaux.", spanish: "Verificado con inicios locales.")
        case "blocked":
            return localizedString(theme.language, english: "Blocked by safety checks.", chinese: "已被安全检查阻止。", italian: "Bloccato dai controlli.", french: "Bloqué par sécurité.", spanish: "Bloqueado por seguridad.")
        default:
            return localizedString(theme.language, english: "Estimated baseline, not measured yet.", chinese: "这是估算 baseline，尚未本机实测。", italian: "Baseline stimata, non ancora misurata.", french: "Baseline estimée, pas encore mesurée.", spanish: "Base estimada, aún no medida.")
        }
    }

    private func evidenceText(_ evidence: [CorePerformanceEvidence]?) -> String? {
        guard let evidence, !evidence.isEmpty else { return nil }
        let summary = evidence.prefix(2).map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return localizedString(theme.language, english: "Evidence: \(summary).", chinese: "证据：\(summary)。", italian: "Evidenza: \(summary).", french: "Preuves : \(summary).", spanish: "Evidencia: \(summary).")
    }
}
