import AppKit

extension LaunchDashboard {
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

    private func performanceReviewEvidence(for instance: GameInstance) -> [CorePerformanceEvidence] {
        let summaryEvidence = selectedPerformanceSummary?.evidence ?? []
        return summaryEvidence + [
            CorePerformanceEvidence(key: "source", value: "launch-ui", source: "swift"),
            CorePerformanceEvidence(key: "jvmProfile", value: instance.jvmProfile.rawValue, source: "instance"),
            CorePerformanceEvidence(key: "graphicsProfile", value: instance.graphicsProfile.rawValue, source: "instance")
        ]
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
}
