import SwiftUI

struct MinecraftInstallPlanPanel: View {
    let targetSummary: String
    let effectiveComponentSummary: String
    let javaRuntimePlanSummary: String
    let preflight: CoreLoaderInstallPreflightResponse?
    let preflightStatus: String
    let shaderFallbackSummary: String?
    let installerProbeSummary: String?
    let blockReason: String?
    let lastInstallFailure: TaskSnapshot?
    let installButtonTitle: String
    let reviewPlan: () -> Void
    let confirmInstall: () -> Void
    let retryInstall: () -> Void
    let openTasks: () -> Void
    let exportDiagnostics: () -> Void
    let openInstanceDirectory: () -> Void
    let downloadJava: (Int) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .floatingChrome) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Install Plan", chinese: "安装计划", italian: "Piano installazione", french: "Plan d'installation", spanish: "Plan de instalación"),
                    systemImage: "checklist"
                )
                SettingsRow(title: localizedString(theme.language, english: "Result", chinese: "结果", italian: "Risultato", french: "Résultat", spanish: "Resultado"), systemImage: "square.stack.3d.up") {
                    Text(targetSummary)
                        .lineLimit(2)
                }
                SettingsRow(title: localizedString(theme.language, english: "Components", chinese: "组件", italian: "Componenti", french: "Composants", spanish: "Componentes"), systemImage: "shippingbox") {
                    Text(effectiveComponentSummary)
                        .lineLimit(2)
                }
                SettingsRow(title: "Java Runtime", systemImage: "cup.and.saucer") {
                    Text(javaRuntimePlanSummary)
                        .lineLimit(2)
                }
                javaPreflightRow
                optionalSummaryRows
                blockReasonRow
                preflightSummary
                failureBanner
                actionRow
            }
        }
    }

    @ViewBuilder
    private var javaPreflightRow: some View {
        if let javaRuntime = preflight?.javaRuntime {
            SettingsRow(
                title: localizedString(theme.language, english: "Java Preflight", chinese: "Java 预检", italian: "Preflight Java", french: "Précontrôle Java", spanish: "Preflight Java"),
                systemImage: "terminal"
            ) {
                HStack(spacing: 8) {
                    Text(javaRuntime.conciseStatus)
                        .lineLimit(1)
                    if javaRuntime.isDownloadable {
                        GlassButton(
                            systemImage: "arrow.down.circle",
                            title: localizedString(theme.language, english: "Download Java \(javaRuntime.requiredMajorVersion)", chinese: "下载 Java \(javaRuntime.requiredMajorVersion)", italian: "Scarica Java \(javaRuntime.requiredMajorVersion)", french: "Télécharger Java \(javaRuntime.requiredMajorVersion)", spanish: "Descargar Java \(javaRuntime.requiredMajorVersion)")
                        ) {
                            downloadJava(javaRuntime.requiredMajorVersion)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var optionalSummaryRows: some View {
        if let shaderFallbackSummary {
            SettingsRow(
                title: localizedString(theme.language, english: "Shader Fallback", chinese: "光影回退", italian: "Fallback shader", french: "Repli shader", spanish: "Fallback shader"),
                systemImage: "arrow.triangle.branch"
            ) {
                Text(shaderFallbackSummary)
                    .lineLimit(2)
            }
        }
        if let installerProbeSummary {
            SettingsRow(
                title: localizedString(theme.language, english: "Installer Probe", chinese: "安装器探测", italian: "Probe installer", french: "Sonde installateur", spanish: "Probe instalador"),
                systemImage: "antenna.radiowaves.left.and.right"
            ) {
                Text(installerProbeSummary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var blockReasonRow: some View {
        if let blockReason {
            Label(blockReason, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var preflightSummary: some View {
        if let preflight {
            Label(preflight.displaySummary, systemImage: preflightSummaryIcon(preflight))
                .font(.caption)
                .foregroundStyle(preflightSummaryColor(preflight))
                .lineLimit(2)
        } else if !preflightStatus.isEmpty {
            Label(preflightStatus, systemImage: "waveform.path.ecg")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var failureBanner: some View {
        if let failure = lastInstallFailure,
           failure.state == .failed,
           failure.kind.lowercased().contains("install") {
            MinecraftInstallFailureBanner(
                failure: failure,
                retryInstall: retryInstall,
                openTasks: openTasks,
                exportDiagnostics: exportDiagnostics,
                openInstanceDirectory: openInstanceDirectory
            )
        }
    }

    private var actionRow: some View {
        HStack {
            if preflight != nil {
                GlassButton(
                    systemImage: "list.bullet.rectangle",
                    title: localizedString(theme.language, english: "Review Plan", chinese: "查看计划", italian: "Rivedi piano", french: "Voir le plan", spanish: "Revisar plan"),
                    action: reviewPlan
                )
            }
            Spacer()
            GlassButton(systemImage: "arrow.down.circle", title: installButtonTitle, prominent: true, action: confirmInstall)
                .disabled(blockReason != nil)
        }
    }

    private func preflightSummaryIcon(_ preflight: CoreLoaderInstallPreflightResponse) -> String {
        if preflight.isBlocked {
            return "xmark.octagon"
        }
        if preflight.status == "warning" || !preflight.warnings.isEmpty {
            return "exclamationmark.triangle"
        }
        return "checkmark.seal"
    }

    private func preflightSummaryColor(_ preflight: CoreLoaderInstallPreflightResponse) -> Color {
        if preflight.isBlocked || preflight.status == "warning" || !preflight.warnings.isEmpty {
            return .orange
        }
        return .secondary
    }
}

private struct MinecraftInstallFailureBanner: View {
    let failure: TaskSnapshot
    let retryInstall: () -> Void
    let openTasks: () -> Void
    let exportDiagnostics: () -> Void
    let openInstanceDirectory: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                localizedString(theme.language, english: "Install failed", chinese: "安装失败", italian: "Installazione fallita", french: "Installation échouée", spanish: "Instalación fallida"),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.callout.weight(.semibold))
            Text(failure.diagnostic?.userSummary ?? failure.message ?? failure.errorCode ?? failure.version)
                .font(.caption)
                .lineLimit(2)
            if let diagnostic = failure.diagnostic {
                Text(diagnostic.actionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let errorCode = failure.errorCode {
                Text(errorCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let detail = failure.errorDetail {
                DisclosureGroup(localizedString(theme.language, english: "Details", chinese: "详情", italian: "Dettagli", french: "Détails", spanish: "Detalles")) {
                    Text(detail)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
            }
            HStack(spacing: 8) {
                GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Retry", chinese: "重试", italian: "Riprova", french: "Réessayer", spanish: "Reintentar"), action: retryInstall)
                GlassButton(systemImage: "list.bullet.rectangle", title: localizedString(theme.language, english: "Tasks", chinese: "任务", italian: "Attività", french: "Tâches", spanish: "Tareas"), action: openTasks)
                GlassButton(systemImage: "square.and.arrow.up", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter diagnostics", spanish: "Exportar diagnóstico"), action: exportDiagnostics)
                GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开目录", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta"), action: openInstanceDirectory)
            }
            .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paninoGlassCard(isSelected: true, level: .popover, cornerRadius: 8, tint: .orange, showsShadow: true)
    }
}
