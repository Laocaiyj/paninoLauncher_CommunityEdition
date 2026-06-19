import AppKit
import SwiftUI

extension LaunchDashboard {
    var jvmTuningPreflightItem: LaunchPreflightItem {
        let instance = selectedInstance
        if let snapshot = instance.lastJvmTuningSnapshot,
           snapshot.state == .failed,
           let lastKnownGood = instance.lastKnownGoodJvmTuning {
            return LaunchPreflightItem(
                id: "tuning",
                title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
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
                title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
                detail: localizedString(theme.language, english: "Experimental performance mode is for controlled testing. Use automatic recommendation for normal play.", chinese: "实验性能模式只适合测试。普通游玩建议改回自动推荐。", italian: "La modalità prestazioni sperimentale è per test controllati. Usa la raccomandazione automatica.", french: "Le mode performance expérimental sert aux tests. Utilisez la recommandation automatique.", spanish: "El modo experimental es para pruebas. Usa la recomendación automática."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Restore Auto", chinese: "恢复自动", italian: "Automatico", french: "Auto", spanish: "Auto")
            ) {
                updateSelectedInstance { $0.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb) }
            }
        }

        if hasCustomJvmConflict(instance) {
            return LaunchPreflightItem(
                id: "tuning",
                title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
                detail: localizedString(theme.language, english: "Custom advanced launch flags conflict with automatic tuning. Use Panino's recommendation first.", chinese: "自定义高级启动参数会和自动调校冲突。先使用 Panino 推荐。", italian: "Flag avanzati personalizzati confliggono con l'autotuning. Usa prima la raccomandazione Panino.", french: "Les options avancées personnalisées entrent en conflit. Utilisez d'abord la recommandation Panino.", spanish: "Los flags avanzados chocan con el ajuste automático. Usa primero la recomendación de Panino."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Restore Auto", chinese: "恢复自动", italian: "Automatico", french: "Auto", spanish: "Auto")
            ) {
                updateSelectedInstance { $0.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb) }
            }
        }

        if let manualMemoryWarning = manualMemoryWarning(for: instance) {
            return LaunchPreflightItem(
                id: "tuning",
                title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
                detail: manualMemoryWarning.detail,
                state: .needsFix,
                actionTitle: manualMemoryWarning.actionTitle
            ) {
                updateSelectedInstance { selected in
                    selected.memoryPolicy = .custom
                    selected.customMemoryMb = manualMemoryWarning.targetMb
                    selected.memoryMb = manualMemoryWarning.targetMb
                }
            }
        }

        return LaunchPreflightItem(
            id: "tuning",
            title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
            detail: tuningReadyDetail(instance),
            state: .ready,
            actionTitle: nil,
            action: nil
        )
    }

    var performanceSummaryPreflightItem: LaunchPreflightItem? {
        guard let summary = selectedPerformanceSummary else { return nil }
        let state: LaunchPreflightState = summary.status == "needsAction" ? .needsFix : .ready
        return LaunchPreflightItem(
            id: "performance-summary",
            title: localizedString(theme.language, english: "Performance recommendation", chinese: "性能推荐", italian: "Consiglio prestazioni", french: "Recommandation performance", spanish: "Recomendación de rendimiento"),
            detail: performanceSummaryDetail(summary),
            state: state,
            actionTitle: summary.primaryAction.title,
            action: performanceSummaryAction(summary.primaryAction)
        )
    }

    var localPerformancePreflightItem: LaunchPreflightItem {
        if jvmTuningPreflightItem.state == .needsFix {
            return LaunchPreflightItem(
                id: "performance-summary",
                title: localizedString(theme.language, english: "Performance recommendation", chinese: "性能推荐", italian: "Consiglio prestazioni", french: "Recommandation performance", spanish: "Recomendación de rendimiento"),
                detail: jvmTuningPreflightItem.detail,
                state: .needsFix,
                actionTitle: jvmTuningPreflightItem.actionTitle,
                action: jvmTuningPreflightItem.action
            )
        }
        if graphicsPreflightItem.state == .needsFix {
            return LaunchPreflightItem(
                id: "performance-summary",
                title: localizedString(theme.language, english: "Performance recommendation", chinese: "性能推荐", italian: "Consiglio prestazioni", french: "Recommandation performance", spanish: "Recomendación de rendimiento"),
                detail: graphicsPreflightItem.detail,
                state: .needsFix,
                actionTitle: graphicsPreflightItem.actionTitle,
                action: graphicsPreflightItem.action
            )
        }
        return LaunchPreflightItem(
            id: "performance-summary",
            title: localizedString(theme.language, english: "Performance recommendation", chinese: "性能推荐", italian: "Consiglio prestazioni", french: "Recommandation performance", spanish: "Recomendación de rendimiento"),
            detail: localizedString(theme.language, english: "Panino will use an estimated memory and graphics baseline until this instance has local launch metrics.", chinese: "在这个实例产生本机启动指标前，Panino 只使用估算的内存和画面 baseline。", italian: "Panino usa una baseline stimata finché non ci sono metriche locali.", french: "Panino utilise une baseline estimée jusqu'aux métriques locales.", spanish: "Panino usa una base estimada hasta tener métricas locales."),
            state: .ready,
            actionTitle: nil,
            action: nil
        )
    }

    var graphicsPreflightItem: LaunchPreflightItem {
        let instance = selectedInstance
        if let snapshot = instance.lastGraphicsTuningSnapshot,
           snapshot.state == .failed,
           snapshot.renderRelatedError || snapshot.quickExit || snapshot.canRollback {
            return LaunchPreflightItem(
                id: "graphics",
                title: localizedString(theme.language, english: "Graphics tuning", chinese: "画面调校", italian: "Tuning grafica", french: "Réglage graphismes", spanish: "Ajuste gráfico"),
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
                title: localizedString(theme.language, english: "Graphics tuning", chinese: "画面调校", italian: "Tuning grafica", french: "Réglage graphismes", spanish: "Ajuste gráfico"),
                detail: localizedString(theme.language, english: "Manual graphics settings are active. Panino can return to the safe recommendation before launch.", chinese: "正在使用手动画面设置。启动前可以恢复 Panino 的安全推荐。", italian: "Grafica manuale attiva. Panino può tornare al consiglio sicuro.", french: "Réglages graphiques manuels actifs. Panino peut revenir au réglage sûr.", spanish: "Gráficos manuales activos. Panino puede volver al ajuste seguro."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Restore Auto", chinese: "恢复自动", italian: "Automatico", french: "Auto", spanish: "Auto")
            ) {
                updateSelectedInstance { $0.restoreAutomaticGraphicsTuning() }
            }
        }

        return LaunchPreflightItem(
            id: "graphics",
            title: localizedString(theme.language, english: "Graphics tuning", chinese: "画面调校", italian: "Tuning grafica", french: "Réglage graphismes", spanish: "Ajuste gráfico"),
            detail: graphicsReadyDetail(instance),
            state: .ready,
            actionTitle: nil,
            action: nil
        )
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

    func refreshSelectedPerformanceSummary() {
        let instance = selectedInstance
        let request = CoreEnvironmentReportRequest(
            gameDir: instance.gameDirectory,
            version: instance.contentMinecraftVersion,
            loader: instance.loader?.rawValue,
            loaderVersion: instance.loaderVersion,
            memoryMb: instance.memoryMb,
            memoryPolicy: instance.memoryPolicy.rawValue,
            jvmProfile: instance.jvmProfile.rawValue,
            customMemoryMb: instance.memoryPolicy == .custom ? (instance.customMemoryMb ?? instance.memoryMb) : instance.customMemoryMb,
            customJvmArgs: instance.customJvmArguments,
            modCount: versionStore.managedAssets.count,
            graphicsProfile: instance.graphicsProfile.rawValue
        )
        Task {
            do {
                let report = try await viewModel.environmentReport(request)
                await MainActor.run {
                    guard selectedInstance.id == instance.id else { return }
                    diagnosticsStore.lastEnvironmentReport = report
                }
            } catch {
                await MainActor.run {
                    guard selectedInstance.id == instance.id else { return }
                    diagnosticsStore.lastEnvironmentReport = nil
                }
            }
        }
    }

    private func performanceSummaryAction(_ action: CorePerformancePrimaryAction) -> (() -> Void)? {
        switch action.id {
        case "installPerformancePack":
            return installPerformancePackAction()
        case "applyGraphics", "viewDetails":
            return reviewPerformanceProfileAction()
        case "restoreAuto":
            return {
                updateSelectedInstance {
                    $0.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb)
                    $0.restoreAutomaticGraphicsTuning()
                }
            }
        case "reduceMemory", "increaseMemory":
            guard let memoryMb = action.memoryMb else { return openSettings }
            return {
                updateSelectedInstance {
                    $0.memoryPolicy = .custom
                    $0.customMemoryMb = memoryMb
                    $0.memoryMb = memoryMb
                }
            }
        default:
            return openSettings
        }
    }

    func reviewPerformanceProfileAction() -> (() -> Void)? {
        let instance = selectedInstance
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return openSettings
        }
        let request = CorePerformanceProfileResolveRequest(
            gameDir: instance.gameDirectory,
            instanceFingerprint: CoreInstanceFingerprint(
                minecraftVersion: instance.contentMinecraftVersion,
                javaRequirement: nil,
                loaderFamily: instance.loader?.rawValue,
                loaderVersion: instance.loaderVersion,
                rendererCapability: instance.graphicsProfile.rawValue,
                modCount: versionStore.managedAssets.count,
                shaderLoader: nil,
                activeShaderPackHash: nil,
                resourcePackScale: nil,
                lockfileFingerprint: nil,
                worldTypeHint: nil
            ),
            knobs: CorePerformanceKnobs(
                heapMaxMb: instance.memoryPolicy == .custom ? (instance.customMemoryMb ?? instance.memoryMb) : instance.memoryMb,
                heapInitialPolicy: instance.memoryPolicy.rawValue,
                gcPolicy: instance.jvmProfile.rawValue,
                renderDistance: nil,
                simulationDistance: nil,
                maxFps: nil,
                vsyncPolicy: instance.graphicsProfile.rawValue,
                particles: nil,
                clouds: nil,
                entityDistanceScaling: nil,
                performancePackSet: []
            ),
            evidence: performanceReviewEvidence(for: instance)
        )
        return {
            showPerformanceProfileReview = true
            performanceCoachStore.resolveBaseline(request: request)
        }
    }

    private func performanceReviewEvidence(for instance: GameInstance) -> [CorePerformanceEvidence] {
        let summaryEvidence = selectedPerformanceSummary?.evidence ?? []
        return summaryEvidence + [
            CorePerformanceEvidence(key: "source", value: "launch-ui", source: "swift"),
            CorePerformanceEvidence(key: "jvmProfile", value: instance.jvmProfile.rawValue, source: "instance"),
            CorePerformanceEvidence(key: "graphicsProfile", value: instance.graphicsProfile.rawValue, source: "instance")
        ]
    }

    func applySelectedPerformanceProfile(_ profile: CorePerformanceProfile) {
        updateSelectedInstance { instance in
            if let heapMaxMb = profile.knobs.heapMaxMb {
                instance.memoryPolicy = .custom
                instance.customMemoryMb = heapMaxMb
                instance.memoryMb = heapMaxMb
            }

            if let gcPolicy = profile.knobs.gcPolicy?.lowercased() {
                if gcPolicy.contains("zgc") {
                    instance.jvmProfile = .experimentalZgc
                } else if gcPolicy != "auto" && gcPolicy != "default" && gcPolicy != "g1_or_default" {
                    instance.jvmProfile = .custom
                }
            }

            if profile.knobs.renderDistance != nil
                || profile.knobs.simulationDistance != nil
                || profile.knobs.maxFps != nil
                || profile.knobs.vsyncPolicy != nil
                || profile.knobs.particles != nil
                || profile.knobs.clouds != nil
                || profile.knobs.entityDistanceScaling != nil {
                instance.graphicsProfile = .performance
            }
        }
    }

    private func performanceSummaryDetail(_ summary: CorePerformanceSummary) -> String {
        [
            summary.title,
            performanceConfidenceDetail(summary.confidence),
            summary.detail,
            performanceEvidenceSummary(summary.evidence),
            performanceRollbackSummary(summary.rollbackRef)
        ]
        .compactMap { $0?.isEmpty == false ? $0 : nil }
        .joined(separator: "\n")
    }

    private func performanceConfidenceDetail(_ confidence: String?) -> String {
        switch confidence {
        case "measured_once":
            return localizedString(theme.language, english: "Measured once on this Mac.", chinese: "已在这台 Mac 上测过一次。", italian: "Misurato una volta su questo Mac.", french: "Mesuré une fois sur ce Mac.", spanish: "Medido una vez en este Mac.")
        case "measured_stable", "experiment_won":
            return localizedString(theme.language, english: "Verified by local launch history.", chinese: "已通过本机启动历史验证。", italian: "Verificato dagli avvii locali.", french: "Vérifié par l'historique local.", spanish: "Verificado con historial local.")
        case "blocked":
            return localizedString(theme.language, english: "Blocked by safety checks.", chinese: "已被安全检查阻止。", italian: "Bloccato dai controlli.", french: "Bloqué par sécurité.", spanish: "Bloqueado por seguridad.")
        default:
            return localizedString(theme.language, english: "Estimated baseline, not measured yet.", chinese: "这是估算 baseline，尚未本机实测。", italian: "Baseline stimata, non ancora misurata.", french: "Baseline estimée, pas encore mesurée.", spanish: "Base estimada, aún no medida.")
        }
    }

    private func performanceEvidenceSummary(_ evidence: [CorePerformanceEvidence]?) -> String? {
        guard let evidence, !evidence.isEmpty else { return nil }
        let rendered = evidence.prefix(3).map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return localizedString(theme.language, english: "Evidence: \(rendered).", chinese: "证据：\(rendered)。", italian: "Evidenza: \(rendered).", french: "Preuves : \(rendered).", spanish: "Evidencia: \(rendered).")
    }

    private func performanceRollbackSummary(_ rollbackRef: String?) -> String? {
        guard let rollbackRef, !rollbackRef.isEmpty else { return nil }
        return localizedString(theme.language, english: "Rollback available: \(rollbackRef).", chinese: "可回滚：\(rollbackRef)。", italian: "Rollback disponibile: \(rollbackRef).", french: "Rollback disponible : \(rollbackRef).", spanish: "Rollback disponible: \(rollbackRef).")
    }

    private func installPerformancePackAction() -> (() -> Void)? {
        let instance = selectedInstance
        guard let loader = instance.loader?.rawValue,
              !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return openDiscover
        }
        let request = CorePerformancePackInstallRequest(
            gameDir: instance.gameDirectory,
            minecraftVersion: instance.contentMinecraftVersion,
            loader: loader,
            includeOptional: false,
            download: LauncherSettings.storedDownloadRuntimeOptions()
        )
        return {
            Task {
                do {
                    let plan = try await viewModel.performancePackPlan(request)
                    await MainActor.run {
                        pendingPerformancePackReview = PendingPerformancePackReview(plan: plan, request: request)
                    }
                } catch {
                    await MainActor.run {
                        showPerformancePackPlanError(error)
                    }
                }
            }
        }
    }

    @MainActor
    private func showPerformancePackPlanError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localizedString(theme.language, english: "Could not prepare performance pack", chinese: "无法准备性能包", italian: "Impossibile preparare il pacchetto", french: "Impossible de préparer le pack", spanish: "No se pudo preparar el paquete")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: localizedString(theme.language, english: "OK", chinese: "知道了", italian: "OK", french: "OK", spanish: "OK"))
        alert.runModal()
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

    private func manualMemoryWarning(for instance: GameInstance) -> (detail: String, actionTitle: String, targetMb: Int)? {
        guard instance.memoryPolicy == .custom else { return nil }
        let memoryMb = instance.customMemoryMb ?? instance.memoryMb
        if memoryMb >= 12 * 1024 {
            return (
                localizedString(theme.language, english: "Manual game memory is \(memoryMb) MB. On unified-memory Macs this can starve graphics and system cache.", chinese: "手动游戏内存是 \(memoryMb) MB。在统一内存 Mac 上可能挤压图形和系统缓存。", italian: "Memoria gioco manuale \(memoryMb) MB. Sui Mac a memoria unificata può comprimere grafica e cache.", french: "Mémoire jeu manuelle \(memoryMb) Mo. Sur Mac à mémoire unifiée cela peut gêner graphismes et cache.", spanish: "Memoria manual \(memoryMb) MB. En Mac de memoria unificada puede presionar gráficos y caché."),
                localizedString(theme.language, english: "Reduce to 8GB", chinese: "降到 8GB", italian: "Riduci a 8GB", french: "Réduire à 8 Go", spanish: "Bajar a 8GB"),
                8 * 1024
            )
        }
        if memoryMb < 2 * 1024 {
            return (
                localizedString(theme.language, english: "Manual game memory is below 2GB. Modern Minecraft and mod loaders usually need more.", chinese: "手动游戏内存低于 2GB。新版 Minecraft 和 Loader 通常不够用。", italian: "Memoria gioco sotto 2GB. Minecraft moderno e loader di solito richiedono di più.", french: "Mémoire jeu sous 2 Go. Minecraft moderne et les loaders demandent souvent plus.", spanish: "Memoria manual bajo 2GB. Minecraft moderno y loaders suelen necesitar más."),
                localizedString(theme.language, english: "Raise to 4GB", chinese: "升到 4GB", italian: "Porta a 4GB", french: "Monter à 4 Go", spanish: "Subir a 4GB"),
                4 * 1024
            )
        }
        return nil
    }
}
