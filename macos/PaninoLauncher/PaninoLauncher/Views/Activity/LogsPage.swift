import SwiftUI

struct LogsPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject private var taskCenterStore: TaskCenterStore
    @State private var areLogsExpanded = false

    var body: some View {
        logWorkspace
        .padding(20)
        .frame(minWidth: 760, minHeight: 620)
    }

    @ViewBuilder
    private var logWorkspace: some View {
        if let context = errorContext {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: theme.fontDensity.spacing) {
                    ErrorDetailPanel(context: context, onCopy: copyErrorContext, onCopyRepro: copyMinimumRepro, onExportDiagnostics: exportDiagnostics)
                        .frame(minWidth: 420, maxWidth: .infinity, alignment: .topLeading)
                    logConsole(showsPanel: true, scrollMinHeight: 360)
                        .frame(width: 440, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    ErrorDetailPanel(context: context, onCopy: copyErrorContext, onCopyRepro: copyMinimumRepro, onExportDiagnostics: exportDiagnostics)
                    collapsedLogConsole
                }
            }
        } else {
            logConsole(showsPanel: true, scrollMinHeight: 320)
                .frame(minHeight: 420)
        }
    }

    private var collapsedLogConsole: some View {
        GlassPanel(showsShadow: false, surfaceLevel: .panel) {
            FullWidthDisclosureGroup(isExpanded: $areLogsExpanded) {
                logConsole(showsPanel: false, scrollMinHeight: 220)
                    .padding(.top, 12)
            } label: {
                HStack(spacing: 10) {
                    Text(localizedString(theme.language, english: "Logs", chinese: "日志详情", italian: "Log", french: "Journaux", spanish: "Registros"))
                        .font(.headline)
                    CountText(value: displayedLogCount)
                    Text(localizedString(theme.language, english: "Expand only when you need raw Core/Game output.", chinese: "仅在需要原始 Core/游戏输出时展开。", italian: "Espandi solo se servono i log grezzi.", french: "Dépliez seulement si les journaux bruts sont nécessaires.", spanish: "Expande solo si necesitas la salida sin procesar."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    private func logConsole(showsPanel: Bool, scrollMinHeight: CGFloat) -> some View {
        LogConsole(
            title: AppText.coreLogs.localized(theme.language),
            logs: coreLogsForDisplay,
            gameLogs: gameLogsForDisplay,
            exportedURL: viewModel.lastExportedLogURL,
            diagnosticURL: diagnosticsStore.lastDiagnosticURL,
            showsPanel: showsPanel,
            scrollMinHeight: scrollMinHeight,
            onExport: {
                viewModel.exportLogs()
                taskCenterStore.enqueueLocal(
                    kind: "log-export",
                    name: localizedString(theme.language, english: "Log Export", chinese: "日志导出", italian: "Esportazione log", french: "Export des journaux", spanish: "Exportación de registros"),
                    message: localizedString(theme.language, english: "Launcher log export requested.", chinese: "已请求导出启动器日志。", italian: "Export log launcher richiesto.", french: "Export des journaux du lanceur demandé.", spanish: "Se solicitó exportar registros del launcher.")
                )
            },
            onClear: viewModel.clearLogs,
            onExportDiagnostics: exportDiagnostics
        )
    }

    private var errorContext: ErrorDetailContext? {
        if let selected = taskCenterStore.selectedRecord, taskCenterStore.isActionableAttention(selected) {
            let insight = TaskFailureInsight(record: selected, language: theme.language)
            let summary = [selected.kind, selected.version, selected.errorCode ?? "no-error-code"].joined(separator: " / ")
            let diagnostic = selected.diagnostic ?? selected.diagnostics?.first
            let diagnosticDetail = diagnostic.map { diagnostic in
                let evidenceLines = diagnostic.evidence.map { evidence in
                    "Evidence: \(evidence.key)=\(evidence.value)\(evidence.redacted ? " (redacted)" : "")"
                }
                return ([
                    "Diagnostic: \(diagnostic.code)",
                    "Phase: \(diagnostic.phase)",
                    "Source: \(diagnostic.source)",
                    diagnostic.filePath.map { "File: \($0)" },
                    diagnostic.planId.map { "Plan: \($0)" },
                    diagnostic.packageId.map { "Package: \($0)" },
                    diagnostic.urlHost.map { "Host: \($0)" },
                    diagnostic.developerDetail
                ] + evidenceLines)
                .compactMap { $0 }
                .joined(separator: "\n")
            }
            let technicalDetail = [summary, diagnosticDetail, selected.errorDetail]
                .compactMap { value in
                    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                    return value
                }
                .joined(separator: "\n")
            return ErrorDetailContext(
                title: selected.state == .interrupted
                    ? localizedString(theme.language, english: "Task Interrupted", chinese: "任务已中断", italian: "Attività interrotta", french: "Tâche interrompue", spanish: "Tarea interrumpida")
                    : localizedString(theme.language, english: "Task Failed", chinese: "任务失败", italian: "Attività fallita", french: "Échec de la tâche", spanish: "Tarea fallida"),
                userSummary: diagnostic?.userSummary ?? insight.userSummary ?? selected.message,
                technicalDetail: technicalDetail,
                causes: mergedDiagnosticItems(
                    [diagnostic?.cause].compactMap { $0 } + insight.causes,
                    recoveryCauses(errorCode: selected.errorCode, language: theme.language)
                ),
                actions: mergedDiagnosticItems(
                    [diagnostic?.actionLabel].compactMap { $0 } + insight.actions,
                    recoveryActions(errorCode: selected.errorCode, language: theme.language)
                )
            )
        }

        if case .failed(let message) = viewModel.coreState {
            return ErrorDetailContext(
                title: localizedString(theme.language, english: "Core Error", chinese: "Core 错误", italian: "Errore Core", french: "Erreur Core", spanish: "Error de Core"),
                userSummary: message,
                technicalDetail: viewModel.coreState.detail,
                causes: [
                    localizedString(theme.language, english: "Core process crashed or failed to start.", chinese: "Core 进程崩溃或启动失败。", italian: "Il processo Core è terminato o non è partito.", french: "Le processus Core a planté ou n'a pas démarré.", spanish: "El proceso Core falló o no arrancó."),
                    localizedString(theme.language, english: "Local port, permissions, or bundled runtime may be unavailable.", chinese: "本地端口、权限或内置运行时可能不可用。", italian: "Porta locale, permessi o runtime integrato potrebbero non essere disponibili.", french: "Le port local, les permissions ou le runtime intégré peuvent être indisponibles.", spanish: "El puerto local, permisos o runtime integrado pueden no estar disponibles.")
                ],
                actions: [
                    localizedString(theme.language, english: "Start Core again; the launcher restarts it once automatically after a crash.", chinese: "重新启动 Core；崩溃后启动器会自动重启一次。", italian: "Riavvia Core; il launcher lo riavvia automaticamente una volta dopo un crash.", french: "Redémarrez Core ; le lanceur le relance une fois automatiquement après un plantage.", spanish: "Inicia Core de nuevo; el launcher lo reinicia una vez tras un cierre inesperado."),
                    localizedString(theme.language, english: "Export diagnostics and inspect app.log/core.log if it fails again.", chinese: "再次失败时导出诊断包并检查 app.log/core.log。", italian: "Esporta diagnostica e controlla app.log/core.log se fallisce ancora.", french: "Exportez le diagnostic et inspectez app.log/core.log si l'échec persiste.", spanish: "Exporta diagnóstico y revisa app.log/core.log si vuelve a fallar.")
                ]
            )
        }

        if case .failed(let message) = viewModel.accountState {
            return ErrorDetailContext(
                title: localizedString(theme.language, english: "Account Error", chinese: "账号错误", italian: "Errore account", french: "Erreur de compte", spanish: "Error de cuenta"),
                userSummary: message,
                technicalDetail: message,
                causes: [
                    localizedString(theme.language, english: "The login session expired or Microsoft returned an authentication error.", chinese: "登录会话过期，或 Microsoft 返回了认证错误。", italian: "La sessione è scaduta o Microsoft ha restituito un errore.", french: "La session a expiré ou Microsoft a renvoyé une erreur d'authentification.", spanish: "La sesión expiró o Microsoft devolvió un error de autenticación.")
                ],
                actions: [
                    localizedString(theme.language, english: "Re-authenticate the default account from the Account page.", chinese: "在账号页面重新登录默认账号。", italian: "Riautentica l'account predefinito dalla pagina Account.", french: "Réauthentifiez le compte par défaut depuis la page Compte.", spanish: "Reautentica la cuenta predeterminada desde Cuenta.")
                ]
            )
        }

        return nil
    }

    private var gameLogsForDisplay: [LogLine] {
        viewModel.logs.filter { $0.source == .game }
    }

    private var displayedLogCount: Int {
        diagnosticsStore.filteredLogs(coreLogs: coreLogsForDisplay, gameLogs: gameLogsForDisplay).count
    }

    private var coreLogsForDisplay: [LogLine] {
        let coreLogs = viewModel.logs.filter { $0.source == .core }
        guard coreLogs.isEmpty,
              let selected = taskCenterStore.selectedRecord,
              taskCenterStore.isActionableAttention(selected)
        else {
            return coreLogs
        }

        let detail = selected.errorDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = [
            "Task \(selected.id) \(selected.state.rawValue): \(selected.kind) \(selected.version)",
            "Error code: \(selected.errorCode ?? "no-error-code")",
            "Message: \(selected.message)"
        ]
        if let detail, !detail.isEmpty {
            lines.append("Detail: \(detail)")
        }
        let logLines = lines.map { LogLine(text: $0, source: .core) }
        return logLines
    }

    private func exportDiagnostics() {
        diagnosticsStore.exportDiagnosticPackage(
            logs: logsForDiagnosticExport,
            tasks: taskCenterStore.records,
            coreState: viewModel.coreState,
            javaStatus: viewModel.javaStatus,
            managedJavaRuntimes: viewModel.managedJavaRuntimes,
            javaRuntimeResolution: viewModel.javaRuntimeResolution
        )
        taskCenterStore.enqueueLocal(
            kind: "log-export",
            name: localizedString(theme.language, english: "Diagnostic Package", chinese: "诊断包", italian: "Pacchetto diagnostico", french: "Paquet diagnostic", spanish: "Paquete de diagnóstico"),
            message: diagnosticsStore.exportStatus
        )
    }

    private var logsForDiagnosticExport: [LogLine] {
        if viewModel.logs.contains(where: { $0.source == .core }) {
            return viewModel.logs
        }
        return viewModel.logs + coreLogsForDisplay
    }

    private func copyErrorContext(_ context: ErrorDetailContext) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context.copyText, forType: .string)
    }

    private func copyMinimumRepro(_ context: ErrorDetailContext) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context.minimumReproText, forType: .string)
    }

    private func mergedDiagnosticItems(_ primary: [String], _ fallback: [String]) -> [String] {
        var result: [String] = []
        for item in primary + fallback where !result.contains(item) {
            result.append(item)
        }
        return Array(result.prefix(4))
    }
}

private struct TaskFailureInsight {
    let userSummary: String?
    let causes: [String]
    let actions: [String]

    init(record: TaskRecord, language: AppLanguage) {
        let sourceText = [record.message, record.errorDetail, record.errorCode]
            .compactMap { $0 }
            .joined(separator: "\n")
        let lowercased = sourceText.lowercased()
        let dependencies = Self.matches(in: sourceText, pattern: #"requires\s+([A-Za-z0-9_.+\-]+)"#)
        let affectedMods = Self.matches(in: sourceText, pattern: #"([A-Za-z0-9_.+\-]+\.jar)\s+requires"#)

        if lowercased.contains("required mod dependencies are missing") || lowercased.contains("dependencies are missing") {
            let dependencyList = dependencies.isEmpty
                ? localizedString(language, english: "one or more dependencies", chinese: "一个或多个依赖", italian: "una o più dipendenze", french: "une ou plusieurs dépendances", spanish: "una o más dependencias")
                : Self.listSummary(dependencies)
            let modList = affectedMods.isEmpty
                ? localizedString(language, english: "an installed mod", chinese: "某个已安装 Mod", italian: "una mod installata", french: "un mod installé", spanish: "un mod instalado")
                : Self.listSummary(affectedMods)
            let shouldRecommendFabricAPI = dependencies.isEmpty || dependencies.contains { $0.lowercased().hasPrefix("fabric-") }
            userSummary = localizedString(
                language,
                english: "This instance cannot start because \(modList) is missing required dependencies: \(dependencyList).",
                chinese: "这个实例暂时不能启动：\(modList) 缺少必需依赖：\(dependencyList)。",
                italian: "Questa istanza non può avviarsi perché \(modList) non trova le dipendenze richieste: \(dependencyList).",
                french: "Cette instance ne peut pas démarrer car \(modList) n'a pas les dépendances requises : \(dependencyList).",
                spanish: "Esta instancia no puede iniciarse porque \(modList) no tiene las dependencias requeridas: \(dependencyList)."
            )
            causes = [
                localizedString(
                    language,
                    english: "A mod was installed without its required dependency modules.",
                    chinese: "有 Mod 已安装，但它依赖的模块没有一起安装。",
                    italian: "Una mod è installata senza i moduli dipendenti richiesti.",
                    french: "Un mod est installé sans ses modules dépendants requis.",
                    spanish: "Un mod está instalado sin sus módulos de dependencia requeridos."
                ),
                localizedString(
                    language,
                    english: "The installed dependency version may not match this Minecraft/loader version.",
                    chinese: "已安装的依赖版本也可能不匹配当前 Minecraft/加载器版本。",
                    italian: "La versione della dipendenza può non corrispondere a Minecraft/loader.",
                    french: "La version de dépendance installée peut ne pas correspondre à Minecraft/loader.",
                    spanish: "La versión de dependencia instalada puede no coincidir con Minecraft/loader."
                )
            ]
            actions = [
                shouldRecommendFabricAPI
                    ? localizedString(
                        language,
                        english: "Install Fabric API compatible with this Minecraft version into the selected instance.",
                        chinese: "在当前实例中安装与该 Minecraft 版本兼容的 Fabric API。",
                        italian: "Installa Fabric API compatibile con questa versione Minecraft nell'istanza.",
                        french: "Installez Fabric API compatible avec cette version Minecraft dans l'instance.",
                        spanish: "Instala Fabric API compatible con esta versión de Minecraft en la instancia."
                    )
                    : localizedString(
                        language,
                        english: "Install the missing dependency mods listed above into the selected instance.",
                        chinese: "把上面列出的缺失依赖 Mod 安装到当前实例。",
                        italian: "Installa nell'istanza le mod dipendenti mancanti elencate sopra.",
                        french: "Installez dans l'instance les mods de dépendance manquants ci-dessus.",
                        spanish: "Instala en la instancia los mods de dependencia faltantes indicados arriba."
                    ),
                localizedString(
                    language,
                    english: "If the dependency cannot be installed, remove or update the affected mod, then launch again.",
                    chinese: "如果依赖无法安装，请移除或更新相关 Mod，然后重新启动。",
                    italian: "Se la dipendenza non è installabile, rimuovi o aggiorna la mod e riavvia.",
                    french: "Si la dépendance ne peut pas être installée, retirez ou mettez à jour le mod, puis relancez.",
                    spanish: "Si no puedes instalar la dependencia, elimina o actualiza el mod afectado y vuelve a iniciar."
                )
            ]
            return
        }

        userSummary = nil
        causes = []
        actions = []
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var values: [String] = []
        for match in regex.matches(in: text, options: [], range: nsRange) {
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { continue }
            let value = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: " .;,)"))
            guard !value.isEmpty, !values.contains(value) else { continue }
            values.append(value)
        }
        return values
    }

    private static func listSummary(_ values: [String]) -> String {
        guard !values.isEmpty else { return "unknown dependency" }
        let visible = values.prefix(3)
        if values.count > visible.count {
            return visible.joined(separator: ", ") + " +\(values.count - visible.count)"
        }
        return visible.joined(separator: ", ")
    }
}
