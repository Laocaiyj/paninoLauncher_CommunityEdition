import SwiftUI

extension SettingsRuntimeSection {
    func restoreGlobalAutomaticGraphicsTuning() {
        launcherSettings.graphicsProfile = .balanced
        graphicsManualOverrides = [:]
        graphicsTuningStatus = localizedString(theme.language, english: "Automatic graphics recommendation restored.", chinese: "已恢复自动画面推荐。", italian: "Grafica automatica ripristinata.", french: "Recommandation graphique restaurée.", spanish: "Recomendación gráfica restaurada.")
    }

    func applyGlobalGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Applying graphics recommendation...", chinese: "正在应用推荐画面设置...", italian: "Applicazione grafica consigliata...", french: "Application des graphismes recommandés...", spanish: "Aplicando gráficos recomendados...")
        Task {
            do {
                let response = try await viewModel.applyGraphicsTuning(globalGraphicsTuningRequest(dryRun: false))
                await MainActor.run {
                    graphicsTuningStatus = response.tuning.summary + " " + localizedString(theme.language, english: "Relaunch Minecraft to use these settings.", chinese: "重新启动 Minecraft 后生效。", italian: "Riavvia Minecraft per usare queste impostazioni.", french: "Relancez Minecraft pour utiliser ces réglages.", spanish: "Reinicia Minecraft para usar estos ajustes.")
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

    func rollbackGlobalGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Restoring previous graphics settings...", chinese: "正在恢复之前的画面设置...", italian: "Ripristino grafica precedente...", french: "Restauration des anciens graphismes...", spanish: "Restaurando gráficos anteriores...")
        Task {
            do {
                _ = try await viewModel.rollbackGraphicsTuning(
                    CoreGraphicsTuningRollbackRequest(
                        gameDir: launcherSettings.defaultGameDirectory,
                        backupPath: diagnosticsStore.lastEnvironmentReport?.graphicsTuning?.backupPath
                    )
                )
                await MainActor.run {
                    graphicsTuningStatus = localizedString(theme.language, english: "Previous graphics settings restored.", chinese: "已恢复之前的画面设置。", italian: "Grafica precedente ripristinata.", french: "Anciens graphismes restaurés.", spanish: "Gráficos anteriores restaurados.")
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

    func globalGraphicsTuningRequest(dryRun: Bool) -> CoreGraphicsTuningRequest {
        CoreGraphicsTuningRequest(
            gameDir: launcherSettings.defaultGameDirectory,
            minecraftVersion: viewModel.version,
            loader: nil,
            requestedProfile: launcherSettings.graphicsProfile.rawValue,
            manualOverrides: graphicsManualOverrides,
            dryRun: dryRun
        )
    }
}
