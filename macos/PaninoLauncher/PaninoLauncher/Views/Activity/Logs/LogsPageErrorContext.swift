import Foundation

extension LogsPage {
    var errorContext: ErrorDetailContext? {
        if let selected = taskCenterStore.selectedRecord, taskCenterStore.isActionableAttention(selected) {
            return taskErrorContext(selected)
        }

        if case .failed(let message) = viewModel.coreState {
            return coreErrorContext(message)
        }

        if case .failed(let message) = viewModel.accountState {
            return accountErrorContext(message)
        }

        return nil
    }

    private func taskErrorContext(_ selected: TaskRecord) -> ErrorDetailContext {
        let insight = TaskFailureInsight(record: selected, language: theme.language)
        let diagnostic = selected.diagnostic ?? selected.diagnostics?.first
        let technicalDetail = [
            [selected.kind, selected.version, selected.errorCode ?? "no-error-code"].joined(separator: " / "),
            diagnostic.map(diagnosticDetail),
            selected.errorDetail
        ]
        .compactMap(nonEmptyText)
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

    private func coreErrorContext(_ message: String) -> ErrorDetailContext {
        ErrorDetailContext(
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

    private func accountErrorContext(_ message: String) -> ErrorDetailContext {
        ErrorDetailContext(
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

    private func diagnosticDetail(_ diagnostic: CoreDiagnostic) -> String {
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

    private func nonEmptyText(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private func mergedDiagnosticItems(_ primary: [String], _ fallback: [String]) -> [String] {
        var result: [String] = []
        for item in primary + fallback where !result.contains(item) {
            result.append(item)
        }
        return Array(result.prefix(4))
    }
}
