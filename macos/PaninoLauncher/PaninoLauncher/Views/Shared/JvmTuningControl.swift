import SwiftUI

private enum JvmTuningPreset: String, CaseIterable, Identifiable {
    case auto
    case smoother
    case largePack

    var id: String { rawValue }
}

struct JvmTuningControl: View {
    @Binding var memoryPolicy: InstanceMemoryPolicy
    @Binding var jvmProfile: InstanceJvmProfile
    @Binding var customMemoryMb: Int?

    let currentMemoryMb: Int
    var customJvmArguments: String = ""
    var lastSnapshot: JvmTuningSnapshot?
    var lastKnownGood: JvmTuningSnapshot?
    var resolved: CoreResolvedJvmTuning?
    var onRestoreAutomatic: () -> Void
    var onRestoreLastKnownGood: ((JvmTuningSnapshot) -> Void)?

    @EnvironmentObject private var theme: ThemeSettings

    init(
        memoryPolicy: Binding<InstanceMemoryPolicy>,
        jvmProfile: Binding<InstanceJvmProfile>,
        customMemoryMb: Binding<Int?> = .constant(nil),
        currentMemoryMb: Int,
        customJvmArguments: String = "",
        lastSnapshot: JvmTuningSnapshot? = nil,
        lastKnownGood: JvmTuningSnapshot? = nil,
        resolved: CoreResolvedJvmTuning? = nil,
        onRestoreAutomatic: @escaping () -> Void,
        onRestoreLastKnownGood: ((JvmTuningSnapshot) -> Void)? = nil
    ) {
        self._memoryPolicy = memoryPolicy
        self._jvmProfile = jvmProfile
        self._customMemoryMb = customMemoryMb
        self.currentMemoryMb = currentMemoryMb
        self.customJvmArguments = customJvmArguments
        self.lastSnapshot = lastSnapshot
        self.lastKnownGood = lastKnownGood
        self.resolved = resolved
        self.onRestoreAutomatic = onRestoreAutomatic
        self.onRestoreLastKnownGood = onRestoreLastKnownGood
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: presetBinding) {
                ForEach(JvmTuningPreset.allCases) { preset in
                    Text(title(for: preset)).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 430)

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let advisoryText {
                Label(advisoryText, systemImage: advisoryIcon)
                    .font(.caption)
                    .foregroundStyle(advisoryColor)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                GlassButton(
                    systemImage: primaryActionIcon,
                    title: primaryActionTitle,
                    prominent: true,
                    action: performPrimaryAction
                )

                if let lastSnapshot {
                    Text(snapshotText(lastSnapshot))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var presetBinding: Binding<JvmTuningPreset> {
        Binding(
            get: {
                switch jvmProfile {
                case .largePack:
                    return .largePack
                case .lowMemory, .batterySaver:
                    return .smoother
                default:
                    return .auto
                }
            },
            set: { preset in
                memoryPolicy = .auto
                customMemoryMb = nil
                switch preset {
                case .auto:
                    jvmProfile = .auto
                case .largePack:
                    jvmProfile = .largePack
                case .smoother:
                    jvmProfile = .lowMemory
                }
            }
        )
    }

    private var hasManualOverride: Bool {
        memoryPolicy == .custom
            || jvmProfile == .custom
            || !customJvmArguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var failedWithRollback: Bool {
        lastSnapshot?.state == .failed && lastKnownGood != nil
    }

    private var primaryActionTitle: String {
        if failedWithRollback {
            return localizedString(theme.language, english: "Restore Last Good", chinese: "恢复上次可用设置", italian: "Ripristina funzionante", french: "Restaurer le dernier réglage", spanish: "Restaurar último válido")
        }
        if hasManualOverride {
            return localizedString(theme.language, english: "Restore Automatic", chinese: "恢复自动推荐", italian: "Ripristina automatico", french: "Restaurer automatique", spanish: "Restaurar automático")
        }
        if resolved?.applyMode == "ask" || resolved?.confidence == "estimated" {
            return localizedString(theme.language, english: "Review Estimate", chinese: "确认估算建议", italian: "Rivedi stima", french: "Vérifier l'estimation", spanish: "Revisar estimación")
        }
        return localizedString(theme.language, english: "Apply Recommended", chinese: "应用推荐设置", italian: "Applica consigliato", french: "Appliquer recommandé", spanish: "Aplicar recomendado")
    }

    private var primaryActionIcon: String {
        failedWithRollback ? "arrow.uturn.backward.circle" : "wand.and.stars"
    }

    private func performPrimaryAction() {
        if let lastKnownGood, failedWithRollback {
            onRestoreLastKnownGood?(lastKnownGood)
            return
        }
        onRestoreAutomatic()
    }

    private var summaryText: String {
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

    private var advisoryText: String? {
        if let lastSnapshot, lastSnapshot.state == .failed {
            if lastSnapshot.heapOutOfMemory || lastSnapshot.nativeOutOfMemory || lastSnapshot.gcOverheadLimit {
                return localizedString(
                    theme.language,
                    english: "Last launch looked memory-related. Restore a known-good setup first, then adjust only if it still fails.",
                    chinese: "上次启动像是内存相关失败。先恢复可用设置，再根据结果微调。",
                    italian: "L'ultimo avvio sembra legato alla memoria. Ripristina una configurazione funzionante prima di ritoccare.",
                    french: "Le dernier lancement semble lié à la mémoire. Restaurez un réglage fiable avant d'ajuster.",
                    spanish: "El último inicio parece de memoria. Restaura una configuración válida antes de ajustar."
                )
            }
            return localizedString(
                theme.language,
                english: "Last launch failed. Panino will not change settings silently.",
                chinese: "上次启动失败。Panino 不会在你不知情时改配置。",
                italian: "Ultimo avvio non riuscito. Panino non cambia impostazioni senza dirtelo.",
                french: "Dernier lancement échoué. Panino ne change rien sans vous prévenir.",
                spanish: "El último inicio falló. Panino no cambia ajustes sin avisar."
            )
        }
        if hasCustomJvmConflict {
            return localizedString(
                theme.language,
                english: "Custom advanced launch flags conflict with automatic tuning. Core will keep one final recommendation.",
                chinese: "自定义高级启动参数会和自动调校冲突。Core 最终只保留一组推荐。",
                italian: "Flag avanzati personalizzati confliggono con l'autotuning. Core conserva una raccomandazione.",
                french: "Les options avancées personnalisées entrent en conflit. Core garde une recommandation finale.",
                spanish: "Los flags avanzados chocan con el ajuste automático. Core deja una recomendación final."
            )
        }
        if memoryPolicy == .custom, (customMemoryMb ?? currentMemoryMb) >= 12 * 1024 {
            return localizedString(
                theme.language,
                english: "Very large game memory can starve macOS unified memory and make the game slower.",
                chinese: "游戏内存太大可能挤压 macOS 统一内存，反而让游戏更卡。",
                italian: "Memoria gioco troppo grande può comprimere la memoria unificata di macOS e rallentare.",
                french: "Une mémoire jeu trop grande peut étouffer la mémoire unifiée macOS et ralentir.",
                spanish: "Memoria de juego muy grande puede presionar la memoria unificada de macOS y ralentizar."
            )
        }
        return nil
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

    private var advisoryIcon: String {
        failedWithRollback ? "exclamationmark.triangle" : "info.circle"
    }

    private var advisoryColor: Color {
        failedWithRollback || hasCustomJvmConflict ? .orange : .secondary
    }

    private var hasCustomJvmConflict: Bool {
        splitJvmArguments(customJvmArguments).contains { argument in
            argument.hasPrefix("-Xmx")
                || argument.hasPrefix("-Xms")
                || argument.contains("UseZGC")
                || argument.contains("UseG1GC")
                || argument.contains("UseShenandoahGC")
                || argument.contains("UseParallelGC")
                || argument.contains("UseSerialGC")
        }
    }

    private func title(for preset: JvmTuningPreset) -> String {
        switch preset {
        case .auto:
            return localizedString(theme.language, english: "Auto", chinese: "自动推荐", italian: "Auto", french: "Auto", spanish: "Auto")
        case .largePack:
            return localizedString(theme.language, english: "Large Pack", chinese: "大型整合包", italian: "Pacchetto grande", french: "Gros pack", spanish: "Pack grande")
        case .smoother:
            return localizedString(theme.language, english: "Smoother", chinese: "更流畅", italian: "Più fluido", french: "Plus fluide", spanish: "Más fluido")
        }
    }

    private func snapshotText(_ snapshot: JvmTuningSnapshot) -> String {
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
}
