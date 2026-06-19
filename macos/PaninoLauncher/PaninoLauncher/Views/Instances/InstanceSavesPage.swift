import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InstanceSavesPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let instance: GameInstance

    @EnvironmentObject private var theme: ThemeSettings
    @State private var preflight: CoreExportBackupPreflightResponse?
    @State private var preflightError = ""
    @State private var isCheckingPreflight = false
    @State private var actionStatus = ""
    @State private var isMutatingSaves = false

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas"),
                    systemImage: "tray.full"
                )
                Text(localizedString(theme.language, english: "Save backup and import use this instance's private saves folder; archive creation and extraction are handled by Haskell Core.", chinese: "存档备份与导入只作用于此实例独立存档目录；压缩与解包由 Haskell Core 处理。", italian: "Backup/import usano la cartella salvataggi privata; il Core Haskell archivia/estrae.", french: "Sauvegarde/import utilisent le dossier privé ; le Core Haskell archive/extrait.", spanish: "Copia/importación usan la carpeta privada; Haskell Core archiva/extrae."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                    saveMetric(localizedString(theme.language, english: "Configuration", chinese: "游戏配置", italian: "Configurazione", french: "Configuration", spanish: "Configuración"), instance.name)
                    saveMetric(localizedString(theme.language, english: "Saves Folder", chinese: "存档文件夹", italian: "Cartella salvataggi", french: "Dossier sauvegardes", spanish: "Carpeta de partidas"), savesPath)
                }

                HStack(spacing: 8) {
                    GlassButton(systemImage: "checklist", title: localizedString(theme.language, english: "Run Preflight", chinese: "运行预检", italian: "Preflight", french: "Précontrôle", spanish: "Preflight")) {
                        runBackupPreflight()
                    }
                    .disabled(isCheckingPreflight)
                    GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Saves Folder", chinese: "打开存档文件夹", italian: "Apri salvataggi", french: "Ouvrir sauvegardes", spanish: "Abrir partidas")) {
                        FinderIntegration.openSavesDirectory(instance)
                    }
                    GlassButton(systemImage: "archivebox", title: localizedString(theme.language, english: "Backup Saves", chinese: "备份存档", italian: "Backup salvataggi", french: "Sauvegarder", spanish: "Respaldar partidas")) {
                        backupSaves()
                    }
                    .disabled(isMutatingSaves)
                    GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Import Saves", chinese: "导入存档", italian: "Importa salvataggi", french: "Importer", spanish: "Importar partidas")) {
                        importSaves()
                    }
                    .disabled(isMutatingSaves)
                }

                InstancePreflightResultView(preflight: preflight, error: preflightError, isChecking: isCheckingPreflight)
                if !actionStatus.isEmpty {
                    Text(actionStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func runBackupPreflight() {
        isCheckingPreflight = true
        preflightError = ""
        Task {
            do {
                let result = try await viewModel.exportBackupPreflight(for: instance, kind: "backup")
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

    private var savesPath: String {
        let base = instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        return URL(fileURLWithPath: base, isDirectory: true)
            .appendingPathComponent("saves", isDirectory: true)
            .path
    }

    private var effectiveGameDirectory: String {
        instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func backupSaves() {
        guard !effectiveGameDirectory.isEmpty else {
            actionStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        isMutatingSaves = true
        actionStatus = localizedString(theme.language, english: "Core save backup is running...", chinese: "Core 正在备份存档...", italian: "Backup Core in corso...", french: "Sauvegarde Core en cours...", spanish: "Copia Core en curso...")
        let target = archiveTargetPath()
        Task {
            do {
                let response = try await viewModel.archiveLocalDirectory(sourcePath: savesPath, targetPath: target)
                await MainActor.run {
                    isMutatingSaves = false
                    actionStatus = response.path ?? response.message
                }
            } catch {
                await MainActor.run {
                    isMutatingSaves = false
                    actionStatus = error.localizedDescription
                }
            }
        }
    }

    private func importSaves() {
        guard !effectiveGameDirectory.isEmpty else {
            actionStatus = localizedString(theme.language, english: "This instance has no isolated directory.", chinese: "此实例没有隔离目录。", italian: "Istanza senza cartella isolata.", french: "Cette instance n'a pas de dossier isolé.", spanish: "Esta instancia no tiene carpeta aislada.")
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip]
        panel.message = localizedString(theme.language, english: "Choose a Panino saves backup zip.", chinese: "选择一个 Panino 存档备份 zip。", italian: "Scegli zip backup salvataggi.", french: "Choisissez un zip de sauvegarde.", spanish: "Elige un zip de respaldo.")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isMutatingSaves = true
        actionStatus = localizedString(theme.language, english: "Core save import is running...", chinese: "Core 正在导入存档...", italian: "Import Core in corso...", french: "Import Core en cours...", spanish: "Importación Core en curso...")
        Task {
            do {
                let response = try await viewModel.importLocalArchive(archivePath: url.path, targetDir: effectiveGameDirectory)
                await MainActor.run {
                    isMutatingSaves = false
                    actionStatus = response.path ?? response.message
                }
            } catch {
                await MainActor.run {
                    isMutatingSaves = false
                    actionStatus = error.localizedDescription
                }
            }
        }
    }

    private func archiveTargetPath() -> String {
        let root = ((try? LauncherPaths.appSupportDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher", isDirectory: true))
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Saves", isDirectory: true)
        return root
            .appendingPathComponent("\(safeFileComponent(instance.name))-saves-\(timestamp()).zip")
            .path
    }

    private func safeFileComponent(_ value: String) -> String {
        SafeFileComponent.sanitize(
            value,
            allowedExtraCharacters: "-_",
            fallback: "saves",
            collapseReplacementRuns: false,
            returnsTrimmedValue: false
        )
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func saveMetric(_ title: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}
