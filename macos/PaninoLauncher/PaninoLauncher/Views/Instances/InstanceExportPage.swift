import Foundation
import SwiftUI

struct InstanceExportPage: View {
    @EnvironmentObject private var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel
    let instance: GameInstance

    @State private var preflight: CoreExportBackupPreflightResponse?
    @State private var preflightError = ""
    @State private var isCheckingPreflight = false
    @State private var actionStatus = ""
    @State private var isExporting = false

    private var exportMetrics: [InstanceArchiveMetricItem] {
        [
            InstanceArchiveMetricItem(
                title: localizedString(theme.language, english: "Configuration", chinese: "游戏配置", italian: "Configurazione", french: "Configuration", spanish: "Configuración"),
                value: instance.name
            ),
            InstanceArchiveMetricItem(title: "Minecraft", value: instance.minecraftVersion),
            InstanceArchiveMetricItem(
                title: localizedString(theme.language, english: "Loader"),
                value: instance.loaderTitle(language: theme.language)
            ),
            InstanceArchiveMetricItem(
                title: localizedString(theme.language, english: "Directory"),
                value: effectiveGameDirectory
            )
        ]
    }

    private var effectiveGameDirectory: String {
        instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(title: AppText.export.localized(theme.language), systemImage: "shippingbox.and.arrow.up")
                Text(localizedString(theme.language, english: "Export preflight and archive generation are handled by Haskell Core for this isolated instance directory.", chinese: "此隔离实例目录的导出预检与压缩包生成都由 Haskell Core 处理。", italian: "Preflight e archivio sono gestiti dal Core Haskell.", french: "Le précontrôle et l'archive sont gérés par le Core Haskell.", spanish: "La prevalidación y el archivo los gestiona Haskell Core."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                InstanceArchiveMetricsGrid(items: exportMetrics, minimumColumnWidth: 190)

                InstanceExportActionBar(
                    isCheckingPreflight: isCheckingPreflight,
                    isExporting: isExporting,
                    runPreflight: runExportPreflight,
                    openFolder: openInstanceFolder,
                    exportModpack: exportModpack,
                    exportInstanceZip: exportInstanceZip
                )

                InstancePreflightResultView(preflight: preflight, error: preflightError, isChecking: isCheckingPreflight)
                InstanceArchiveStatusText(status: actionStatus)
            }
        }
    }

    private func openInstanceFolder() {
        FinderIntegration.openInstanceDirectory(instance)
    }

    private func runExportPreflight() {
        isCheckingPreflight = true
        preflightError = ""
        Task {
            do {
                let result = try await viewModel.exportBackupPreflight(for: instance, kind: "export")
                await MainActor.run {
                    preflight = result
                    isCheckingPreflight = false
                }
            } catch {
                await MainActor.run {
                    preflight = nil
                    preflightError = error.localizedDescription
                    isCheckingPreflight = false
                }
            }
        }
    }

    private func exportModpack() {
        exportArchive(kind: "modpack")
    }

    private func exportInstanceZip() {
        exportArchive(kind: "instance")
    }

    private func exportArchive(kind: String) {
        guard !effectiveGameDirectory.isEmpty else {
            actionStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        isExporting = true
        actionStatus = localizedString(theme.language, english: "Core export is running...", chinese: "Core 正在导出...", italian: "Export Core in corso...", french: "Export Core en cours...", spanish: "Exportación Core en curso...")
        let target = archiveTargetPath(category: kind == "modpack" ? "Modpacks" : "Instances", suffix: kind)
        Task {
            do {
                let response = try await viewModel.archiveLocalDirectory(
                    sourcePath: effectiveGameDirectory,
                    targetPath: target
                )
                await MainActor.run {
                    isExporting = false
                    actionStatus = response.path ?? response.message
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    actionStatus = error.localizedDescription
                }
            }
        }
    }

    private func archiveTargetPath(category: String, suffix: String) -> String {
        let root = ((try? LauncherPaths.appSupportDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher", isDirectory: true))
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent(category, isDirectory: true)
        return root
            .appendingPathComponent("\(safeFileComponent(instance.name))-\(timestamp())-\(suffix).zip")
            .path
    }

    private func safeFileComponent(_ value: String) -> String {
        SafeFileComponent.sanitize(
            value,
            allowedExtraCharacters: "-_",
            fallback: "instance",
            collapseReplacementRuns: false,
            returnsTrimmedValue: false
        )
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
