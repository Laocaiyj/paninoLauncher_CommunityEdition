import Foundation

extension InstanceEditor {
    var graphicsPreviewSignature: String {
        [
            instance.gameDirectory,
            instance.contentMinecraftVersion,
            instance.loader?.rawValue ?? "",
            instance.graphicsProfile.rawValue,
            instance.graphicsManualOverrides
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ";")
        ].joined(separator: "|")
    }

    func restoreAutomaticTuning() {
        instance.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb)
    }

    func restoreLastKnownGoodTuning(_ snapshot: JvmTuningSnapshot) {
        instance.applyJvmTuningSnapshot(snapshot)
    }

    func restoreAutomaticGraphicsTuning() {
        instance.restoreAutomaticGraphicsTuning()
        resolvedGraphicsTuning = nil
        graphicsTuningStatus = localizedString(theme.language, english: "Automatic graphics recommendation restored.", chinese: "已恢复自动画面推荐。", italian: "Grafica automatica ripristinata.", french: "Recommandation graphique restaurée.", spanish: "Recomendación gráfica restaurada.")
    }

    func refreshGraphicsTuningPreview() {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            resolvedGraphicsTuning = nil
            return
        }
        Task {
            do {
                let resolved = try await viewModel.resolveGraphicsTuning(graphicsTuningRequest(dryRun: true))
                await MainActor.run {
                    resolvedGraphicsTuning = resolved
                }
            } catch {
                await MainActor.run {
                    resolvedGraphicsTuning = nil
                }
            }
        }
    }

    func applyGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Applying graphics recommendation...", chinese: "正在应用推荐画面设置...", italian: "Applicazione grafica consigliata...", french: "Application des graphismes recommandés...", spanish: "Aplicando gráficos recomendados...")
        Task {
            do {
                let response = try await viewModel.applyGraphicsTuning(graphicsTuningRequest(dryRun: false))
                await MainActor.run {
                    graphicsTuningStatus = response.tuning.summary + " " + localizedString(theme.language, english: "Relaunch Minecraft to use these settings.", chinese: "重新启动 Minecraft 后生效。", italian: "Riavvia Minecraft per usare queste impostazioni.", french: "Relancez Minecraft pour utiliser ces réglages.", spanish: "Reinicia Minecraft para usar estos ajustes.")
                    resolvedGraphicsTuning = response.tuning
                    graphicsCanRollback = true
                    graphicsTuningRunning = false
                }
            } catch {
                await MainActor.run {
                    graphicsTuningStatus = error.localizedDescription
                    graphicsTuningRunning = false
                }
            }
        }
    }

    func rollbackGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Restoring previous graphics settings...", chinese: "正在恢复之前的画面设置...", italian: "Ripristino grafica precedente...", french: "Restauration des anciens graphismes...", spanish: "Restaurando gráficos anteriores...")
        Task {
            do {
                _ = try await viewModel.rollbackGraphicsTuning(
                    CoreGraphicsTuningRollbackRequest(gameDir: instance.gameDirectory, backupPath: nil)
                )
                await MainActor.run {
                    graphicsTuningStatus = localizedString(theme.language, english: "Previous graphics settings restored.", chinese: "已恢复之前的画面设置。", italian: "Grafica precedente ripristinata.", french: "Anciens graphismes restaurés.", spanish: "Gráficos anteriores restaurados.")
                    resolvedGraphicsTuning = nil
                    graphicsCanRollback = false
                    graphicsTuningRunning = false
                }
            } catch {
                await MainActor.run {
                    graphicsTuningStatus = error.localizedDescription
                    graphicsTuningRunning = false
                }
            }
        }
    }

    func graphicsTuningRequest(dryRun: Bool) -> CoreGraphicsTuningRequest {
        CoreGraphicsTuningRequest(
            instanceId: instance.id.uuidString,
            gameDir: instance.gameDirectory,
            minecraftVersion: instance.contentMinecraftVersion,
            loader: instance.loader?.rawValue,
            requestedProfile: instance.graphicsProfile.rawValue,
            manualOverrides: instance.graphicsManualOverrides,
            dryRun: dryRun
        )
    }
}
