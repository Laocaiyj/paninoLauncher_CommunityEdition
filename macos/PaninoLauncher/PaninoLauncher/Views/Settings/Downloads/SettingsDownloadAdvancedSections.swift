import SwiftUI

extension SettingsDownloadSection {
    var sourceRow: some View {
        SettingsRow(title: "Source", systemImage: "globe") {
            VStack(alignment: .leading, spacing: 6) {
                Picker("Source", selection: $launcherSettings.downloadSource) {
                    ForEach(DownloadSource.selectableCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                CapabilityNote(
                    capability: viewModel.coreState.isReady ? .requiresCoreRestart : .available,
                    detail: localizedString(
                        theme.language,
                        english: "Official and BMCLAPI are wired through Core startup environment. Custom is hidden until one validated profile format exists.",
                        chinese: "Official 与 BMCLAPI 已通过 Core 启动环境接入。Custom 在统一格式落地前隐藏。",
                        italian: "Official e BMCLAPI sono collegati tramite ambiente Core. Custom resta nascosto finché il formato non è definito.",
                        french: "Official et BMCLAPI passent par l'environnement Core. Custom reste masqué jusqu'à un format validé.",
                        spanish: "Official y BMCLAPI están conectados vía entorno Core. Custom queda oculto hasta validar un formato."
                    )
                )
                networkTestControls
                if let sourceTestResponse {
                    SourceTestResultsView(response: sourceTestResponse)
                }
                if let speedTestResponse {
                    SpeedTestResultsView(response: speedTestResponse)
                }
            }
        }
    }

    var networkTestControls: some View {
        HStack(spacing: 8) {
            GlassButton(systemImage: "network", title: sourceTestRunning ? "Checking..." : "Check Connection", action: runSourceTest)
                .disabled(sourceTestRunning)
            GlassButton(systemImage: "speedometer", title: speedTestRunning ? "Testing..." : "Test Download Speed", action: runSpeedTest)
                .disabled(speedTestRunning)
            if !sourceTestMessage.isEmpty {
                Text(sourceTestMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !speedTestMessage.isEmpty {
                Text(speedTestMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    var proxyRow: some View {
        SettingsRow(title: "Proxy", systemImage: "network") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    PaninoTextInput("http://127.0.0.1:7890", text: $launcherSettings.proxyAddress)
                    if viewModel.coreState.isReady {
                        GlassButton(systemImage: "arrow.clockwise", title: "Restart Core", action: restartCore)
                    }
                }
                CapabilityNote(
                    capability: viewModel.coreState.isReady ? .requiresCoreRestart : .available,
                    detail: viewModel.coreState.isReady
                        ? localizedString(
                            theme.language,
                            english: "Proxy is injected when Core starts and applies to Core downloads only. Microsoft sign-in follows the system browser/auth flow.",
                            chinese: "代理会在 Core 启动时注入，仅影响 Core 下载。Microsoft 登录仍使用系统浏览器/认证流程。",
                            italian: "Il proxy viene iniettato all'avvio di Core. Riavvia Core per applicarlo ai download.",
                            french: "Le proxy est injecté au démarrage de Core. Redémarrez Core pour l'appliquer aux téléchargements.",
                            spanish: "El proxy se inyecta al iniciar Core. Reinicia Core para aplicarlo a las descargas."
                        )
                        : nil
                )
            }
        }
    }

    var workerLimitRows: some View {
        Group {
            SettingsRow(title: "Max Global Workers", systemImage: "number") {
                VStack(alignment: .leading, spacing: 6) {
                    Stepper(value: $launcherSettings.downloadConcurrency, in: LauncherSettings.downloadConcurrencyRange) {
                        Text("\(launcherSettings.downloadConcurrency)")
                            .monospacedDigit()
                    }
                    CapabilityNote(
                        capability: .available,
                        detail: "Strategy treats this as a ceiling; Core still adjusts active workers from resource limits and host telemetry."
                    )
                }
            }

            SettingsRow(title: "Retries", systemImage: "arrow.clockwise") {
                VStack(alignment: .leading, spacing: 6) {
                    Stepper(value: $launcherSettings.downloadRetryCount, in: LauncherSettings.downloadRetryCountRange) {
                        Text("\(launcherSettings.downloadRetryCount)")
                            .monospacedDigit()
                    }
                    CapabilityNote(capability: .available)
                }
            }

            SettingsRow(title: "Engine Limits", systemImage: "slider.horizontal.3") {
                DownloadEngineLimitsView(strategy: launcherSettings.downloadStrategy, maxWorkers: launcherSettings.downloadConcurrency)
            }
        }
    }

    var cacheSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
                ForEach(launcherSettings.cacheSummaries) { summary in
                    CacheSummaryTile(summary: summary)
                }
            }
            HStack(spacing: 8) {
                GlassButton(systemImage: "arrow.clockwise", title: "Refresh Cache") {
                    launcherSettings.refreshCacheSummaries()
                }
                GlassButton(systemImage: "trash", title: "Clear Staging") {
                    launcherSettings.clearCacheScopes([.downloadStaging], taskCenterStore: taskCenterStore)
                }
                GlassButton(systemImage: "trash", title: "Clear Metadata") {
                    launcherSettings.clearCacheScopes([.metadataHttp, .verificationIndex, .urlCache], taskCenterStore: taskCenterStore)
                }
                GlassButton(systemImage: "trash", title: "Clear All") {
                    launcherSettings.clearCacheScopes(Set(CacheScope.allCases), taskCenterStore: taskCenterStore)
                }
                GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                    FinderIntegration.openDownloadCache()
                }
            }
            Text(launcherSettings.cacheStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
