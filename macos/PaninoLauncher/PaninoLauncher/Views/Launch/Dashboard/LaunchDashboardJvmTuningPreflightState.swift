import SwiftUI

extension LaunchDashboard {
    var jvmTuningPreflightItem: LaunchPreflightItem {
        let instance = selectedInstance
        if let snapshot = instance.lastJvmTuningSnapshot,
           snapshot.state == .failed,
           let lastKnownGood = instance.lastKnownGoodJvmTuning {
            return LaunchPreflightItem(
                id: "tuning",
                title: tuningPreflightTitle,
                detail: tuningFailureDetail(snapshot),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Restore Last Good", chinese: "恢复上次可用设置", italian: "Ripristina valido", french: "Restaurer valide", spanish: "Restaurar válido")
            ) {
                updateSelectedInstance { $0.applyJvmTuningSnapshot(lastKnownGood) }
            }
        }

        if hasExperimentalGC(instance) {
            return LaunchPreflightItem(
                id: "tuning",
                title: tuningPreflightTitle,
                detail: localizedString(theme.language, english: "Experimental performance mode is for controlled testing. Use automatic recommendation for normal play.", chinese: "实验性能模式只适合测试。普通游玩建议改回自动推荐。", italian: "La modalità prestazioni sperimentale è per test controllati. Usa la raccomandazione automatica.", french: "Le mode performance expérimental sert aux tests. Utilisez la recommandation automatique.", spanish: "El modo experimental es para pruebas. Usa la recomendación automática."),
                state: .needsFix,
                actionTitle: restoreAutoTitle,
                action: restoreAutomaticJvmTuning
            )
        }

        if hasCustomJvmConflict(instance) {
            return LaunchPreflightItem(
                id: "tuning",
                title: tuningPreflightTitle,
                detail: localizedString(theme.language, english: "Custom advanced launch flags conflict with automatic tuning. Use Panino's recommendation first.", chinese: "自定义高级启动参数会和自动调校冲突。先使用 Panino 推荐。", italian: "Flag avanzati personalizzati confliggono con l'autotuning. Usa prima la raccomandazione Panino.", french: "Les options avancées personnalisées entrent en conflit. Utilisez d'abord la recommandation Panino.", spanish: "Los flags avanzados chocan con el ajuste automático. Usa primero la recomendación de Panino."),
                state: .needsFix,
                actionTitle: restoreAutoTitle,
                action: restoreAutomaticJvmTuning
            )
        }

        if let manualMemoryWarning = manualMemoryWarning(for: instance) {
            return LaunchPreflightItem(
                id: "tuning",
                title: tuningPreflightTitle,
                detail: manualMemoryWarning.detail,
                state: .needsFix,
                actionTitle: manualMemoryWarning.actionTitle
            ) {
                applyManualMemoryTarget(manualMemoryWarning.targetMb)
            }
        }

        return LaunchPreflightItem(
            id: "tuning",
            title: tuningPreflightTitle,
            detail: tuningReadyDetail(instance),
            state: .ready
        )
    }

    private var tuningPreflightTitle: String {
        localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento")
    }

    private var restoreAutoTitle: String {
        localizedString(theme.language, english: "Restore Auto", chinese: "恢复自动", italian: "Automatico", french: "Auto", spanish: "Auto")
    }

    private func restoreAutomaticJvmTuning() {
        updateSelectedInstance { $0.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb) }
    }

    private func applyManualMemoryTarget(_ targetMb: Int) {
        updateSelectedInstance { selected in
            selected.memoryPolicy = .custom
            selected.customMemoryMb = targetMb
            selected.memoryMb = targetMb
        }
    }

    private func tuningFailureDetail(_ snapshot: JvmTuningSnapshot) -> String {
        let suffix = snapshot.exitCode.map { exitCodeDetail($0) } ?? ""
        if snapshot.heapOutOfMemory {
            return localizedString(theme.language, english: "Last launch hit game memory pressure.\(suffix) Restore a known-good setup before increasing memory.", chinese: "上次启动出现游戏内存压力。\(suffix) 先恢复可用设置，不要直接加大内存。", italian: "Ultimo avvio con pressione memoria gioco.\(suffix) Ripristina una configurazione valida prima di aumentare memoria.", french: "Le dernier lancement a subi une pression mémoire.\(suffix) Restaurez un réglage valide avant d'augmenter.", spanish: "El último inicio tuvo presión de memoria.\(suffix) Restaura un ajuste válido antes de subir memoria.")
        }
        if snapshot.nativeOutOfMemory {
            return localizedString(theme.language, english: "Last launch looked like system memory pressure.\(suffix) On unified-memory Macs, lower game memory often helps.", chinese: "上次启动像是系统内存压力。\(suffix) 在统一内存 Mac 上，降低游戏内存经常更有效。", italian: "Ultimo avvio con pressione memoria di sistema.\(suffix) Sui Mac a memoria unificata aiuta spesso ridurre memoria gioco.", french: "Le dernier lancement semble lié à la mémoire système.\(suffix) Réduire la mémoire jeu aide souvent sur Mac.", spanish: "El último inicio parece presión de memoria del sistema.\(suffix) Reducir memoria de juego suele ayudar.")
        }
        if snapshot.gcOverheadLimit {
            return localizedString(theme.language, english: "Last launch spent too much time managing memory.\(suffix) Restore a known-good tuning profile first.", chinese: "上次启动花了太多时间处理内存。\(suffix) 先恢复上次可用调校。", italian: "Ultimo avvio con troppa gestione memoria.\(suffix) Ripristina prima un profilo valido.", french: "Le dernier lancement a trop géré la mémoire.\(suffix) Restaurez d'abord un profil valide.", spanish: "El último inicio gestionó demasiada memoria.\(suffix) Restaura primero un perfil válido.")
        }
        return localizedString(theme.language, english: "Last launch failed.\(suffix) Panino can restore the last known-good tuning without changing files.", chinese: "上次启动失败。\(suffix) Panino 可以恢复上次可用调校，不会改游戏文件。", italian: "Ultimo avvio fallito.\(suffix) Panino può ripristinare il tuning valido.", french: "Dernier lancement échoué.\(suffix) Panino peut restaurer le dernier réglage valide.", spanish: "El último inicio falló.\(suffix) Panino puede restaurar el ajuste válido.")
    }

    private func exitCodeDetail(_ exitCode: Int) -> String {
        localizedString(theme.language, english: " Exit code \(exitCode).", chinese: " 退出码 \(exitCode)。", italian: " Codice uscita \(exitCode).", french: " Code de sortie \(exitCode).", spanish: " Código de salida \(exitCode).")
    }

    private func tuningReadyDetail(_ instance: GameInstance) -> String {
        if let summary = instance.lastJvmTuningSnapshot?.tuningSummary,
           !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        switch instance.jvmProfile {
        case .largePack:
            return localizedString(theme.language, english: "Large-pack profile selected. Core still keeps room for macOS and graphics memory.", chinese: "已选择大型整合包。Core 仍会给 macOS 和图形内存留空间。", italian: "Profilo pacchetto grande selezionato. Core lascia spazio a macOS e grafica.", french: "Profil gros pack sélectionné. Core garde de la place pour macOS et les graphismes.", spanish: "Perfil pack grande seleccionado. Core deja espacio para macOS y gráficos.")
        case .lowMemory, .batterySaver:
            return localizedString(theme.language, english: "Low-memory profile selected. Minecraft will leave more room for the system.", chinese: "已选择低内存。Minecraft 会给系统留出更多空间。", italian: "Profilo poca memoria selezionato. Minecraft lascia più spazio al sistema.", french: "Profil mémoire basse sélectionné. Minecraft laisse plus de place au système.", spanish: "Perfil poca memoria seleccionado. Minecraft deja más espacio al sistema.")
        case .custom:
            return localizedString(theme.language, english: "Custom tuning is active. Core will keep one final memory recommendation.", chinese: "正在使用自定义调校。Core 会保留一组最终内存建议。", italian: "Tuning personalizzato attivo. Core conserva una raccomandazione memoria finale.", french: "Réglage personnalisé actif. Core garde une recommandation mémoire finale.", spanish: "Ajuste personalizado activo. Core deja una recomendación de memoria final.")
        default:
            return localizedString(theme.language, english: "Automatic profile selected. Core will choose safe memory from this Mac and pack size.", chinese: "已选择自动推荐。Core 会按本机和整合包规模选择安全内存。", italian: "Profilo automatico selezionato. Core sceglie memoria sicura in base al Mac e al pacchetto.", french: "Profil automatique sélectionné. Core choisit la mémoire adaptée au Mac et au pack.", spanish: "Perfil automático seleccionado. Core elige memoria segura según el Mac y el pack.")
        }
    }

    private func hasExperimentalGC(_ instance: GameInstance) -> Bool {
        instance.jvmProfile == .experimentalZgc
    }

    private func hasCustomJvmConflict(_ instance: GameInstance) -> Bool {
        splitJvmArguments(instance.customJvmArguments).contains { argument in
            argument.hasPrefix("-Xmx")
                || argument.hasPrefix("-Xms")
                || argument.contains("UseZGC")
                || argument.contains("UseG1GC")
                || argument.contains("UseShenandoahGC")
                || argument.contains("UseParallelGC")
                || argument.contains("UseSerialGC")
        }
    }

    private func manualMemoryWarning(for instance: GameInstance) -> LaunchManualMemoryWarning? {
        guard instance.memoryPolicy == .custom else { return nil }
        let memoryMb = instance.customMemoryMb ?? instance.memoryMb
        if memoryMb >= 12 * 1024 {
            return LaunchManualMemoryWarning(
                detail: localizedString(theme.language, english: "Manual game memory is \(memoryMb) MB. On unified-memory Macs this can starve graphics and system cache.", chinese: "手动游戏内存是 \(memoryMb) MB。在统一内存 Mac 上可能挤压图形和系统缓存。", italian: "Memoria gioco manuale \(memoryMb) MB. Sui Mac a memoria unificata può comprimere grafica e cache.", french: "Mémoire jeu manuelle \(memoryMb) Mo. Sur Mac à mémoire unifiée cela peut gêner graphismes et cache.", spanish: "Memoria manual \(memoryMb) MB. En Mac de memoria unificada puede presionar gráficos y caché."),
                actionTitle: localizedString(theme.language, english: "Reduce to 8GB", chinese: "降到 8GB", italian: "Riduci a 8GB", french: "Réduire à 8 Go", spanish: "Bajar a 8GB"),
                targetMb: 8 * 1024
            )
        }
        if memoryMb < 2 * 1024 {
            return LaunchManualMemoryWarning(
                detail: localizedString(theme.language, english: "Manual game memory is below 2GB. Modern Minecraft and mod loaders usually need more.", chinese: "手动游戏内存低于 2GB。新版 Minecraft 和 Loader 通常不够用。", italian: "Memoria gioco sotto 2GB. Minecraft moderno e loader di solito richiedono di più.", french: "Mémoire jeu sous 2 Go. Minecraft moderne et les loaders demandent souvent plus.", spanish: "Memoria manual bajo 2GB. Minecraft moderno y loaders suelen necesitar más."),
                actionTitle: localizedString(theme.language, english: "Raise to 4GB", chinese: "升到 4GB", italian: "Porta a 4GB", french: "Monter à 4 Go", spanish: "Subir a 4GB"),
                targetMb: 4 * 1024
            )
        }
        return nil
    }
}

private struct LaunchManualMemoryWarning {
    let detail: String
    let actionTitle: String
    let targetMb: Int
}
