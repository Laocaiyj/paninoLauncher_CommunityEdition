import SwiftUI

struct GraphicsTuningControl: View {
    @Binding var graphicsProfile: InstanceGraphicsProfile
    @Binding var manualOverrides: [String: String]

    var resolved: CoreResolvedGraphicsTuning?
    var canRollback = false
    var statusText: String = ""
    var isWorking = false
    var onApplyRecommended: () -> Void
    var onRollback: () -> Void
    var onRestoreAutomatic: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $graphicsProfile) {
                ForEach(primaryProfiles) { profile in
                    Text(profile.title(language: theme.language)).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 430)

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let warningText {
                Label(warningText, systemImage: warningIcon)
                    .font(.caption)
                    .foregroundStyle(warningColor)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                GlassButton(
                    systemImage: isWorking ? "hourglass" : primaryActionIcon,
                    title: primaryActionTitle,
                    prominent: true,
                    action: onApplyRecommended
                )
                .disabled(isWorking)

                if resolved?.canRollback == true || canRollback {
                    GlassButton(
                        systemImage: "arrow.uturn.backward.circle",
                        title: localizedString(theme.language, english: "Restore Original", chinese: "恢复原设置", italian: "Ripristina originale", french: "Restaurer original", spanish: "Restaurar original"),
                        action: onRollback
                    )
                    .disabled(isWorking)
                }

                if graphicsProfile == .manual {
                    GlassButton(
                        systemImage: "wand.and.stars",
                        title: localizedString(theme.language, english: "Restore Automatic", chinese: "恢复自动", italian: "Ripristina automatico", french: "Restaurer automatique", spanish: "Restaurar automático"),
                        action: onRestoreAutomatic
                    )
                    .disabled(isWorking)
                }
            }

            if !statusText.isEmpty {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            FullWidthDisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 10) {
                    Stepper(value: intOverrideBinding("renderDistance", defaultValue: 10, range: 4...32), in: 4...32) {
                        graphicsValueRow(title: advancedTitle(for: "renderDistance"), value: advancedValue("renderDistance"))
                    }
                    Stepper(value: intOverrideBinding("simulationDistance", defaultValue: 6, range: 4...16), in: 4...16) {
                        graphicsValueRow(title: advancedTitle(for: "simulationDistance"), value: advancedValue("simulationDistance"))
                    }
                    Stepper(value: intOverrideBinding("maxFps", defaultValue: 90, range: 30...260), in: 30...260, step: 15) {
                        graphicsValueRow(title: advancedTitle(for: "maxFps"), value: advancedValue("maxFps"))
                    }
                    Toggle(isOn: boolOverrideBinding("enableVsync", defaultValue: true)) {
                        Text("VSync")
                            .font(.caption)
                    }
                    Picker(advancedTitle(for: "renderClouds"), selection: textOverrideBinding("renderClouds", defaultValue: "\"fast\"")) {
                        Text("Off").tag("\"false\"")
                        Text("Fast").tag("\"fast\"")
                        Text("Fancy").tag("\"true\"")
                    }
                    .pickerStyle(.segmented)
                    Picker(advancedTitle(for: "particles"), selection: textOverrideBinding("particles", defaultValue: "1")) {
                        Text("Minimal").tag("2")
                        Text("Decreased").tag("1")
                        Text("All").tag("0")
                    }
                    .pickerStyle(.segmented)
                    VStack(alignment: .leading, spacing: 4) {
                        graphicsValueRow(title: advancedTitle(for: "entityDistanceScaling"), value: advancedValue("entityDistanceScaling"))
                        Slider(value: doubleOverrideBinding("entityDistanceScaling", defaultValue: 1.0, range: 0.5...1.5), in: 0.5...1.5, step: 0.05)
                    }
                    Stepper(value: intOverrideBinding("mipmapLevels", defaultValue: 4, range: 0...4), in: 0...4) {
                        graphicsValueRow(title: advancedTitle(for: "mipmapLevels"), value: advancedValue("mipmapLevels"))
                    }
                    GlassButton(
                        systemImage: "wand.and.stars",
                        title: localizedString(theme.language, english: "Restore Automatic", chinese: "恢复自动", italian: "Ripristina automatico", french: "Restaurer automatique", spanish: "Restaurar automático"),
                        action: onRestoreAutomatic
                    )

                    if !patchChanges.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text(localizedString(theme.language, english: "Recommended changes", chinese: "推荐改动", italian: "Modifiche consigliate", french: "Changements recommandés", spanish: "Cambios recomendados"))
                                .font(.caption.weight(.semibold))
                            ForEach(patchChanges, id: \.key) { change in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(advancedTitle(for: change.key))
                                            .font(.caption)
                                        Spacer()
                                        Text(patchValueText(change))
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(change.reason)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 430)
                .padding(.top, 6)
            } label: {
                Text(localizedString(theme.language, english: "Advanced Graphics", chinese: "高级画面", italian: "Grafica avanzata", french: "Graphismes avancés", spanish: "Gráficos avanzados"))
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private var primaryProfiles: [InstanceGraphicsProfile] {
        GraphicsTuningUIContract.primaryProfiles
    }

    private var primaryActionTitle: String {
        if resolved == nil || resolved?.canApply == true {
            if resolved?.applyMode == "ask" || resolved?.confidence == "estimated" {
                return localizedString(theme.language, english: "Review Estimate", chinese: "确认估算画面", italian: "Rivedi stima", french: "Vérifier l'estimation", spanish: "Revisar estimación")
            }
            return localizedString(theme.language, english: "Apply Recommended", chinese: "应用推荐画面", italian: "Applica consigliato", french: "Appliquer recommandé", spanish: "Aplicar recomendado")
        }
        return localizedString(theme.language, english: "Check Graphics", chinese: "检查画面设置", italian: "Controlla grafica", french: "Vérifier graphismes", spanish: "Comprobar gráficos")
    }

    private var primaryActionIcon: String {
        resolved == nil || resolved?.canApply == true ? "wand.and.stars" : "sparkle.magnifyingglass"
    }

    private var summaryText: String {
        if let resolved {
            return [confidenceText(resolved.confidence), resolved.summary, evidenceText(resolved.evidence)]
                .compactMap { $0?.isEmpty == false ? $0 : nil }
                .joined(separator: " ")
        }
        switch graphicsProfile {
        case .clarity:
            return localizedString(theme.language, english: "Keeps the picture clear while Panino lowers expensive settings first.", chinese: "优先保持画面清晰，Panino 会先降低高成本设置。", italian: "Mantiene l'immagine chiara riducendo prima le opzioni costose.", french: "Garde l'image nette en réduisant d'abord les réglages coûteux.", spanish: "Mantiene la imagen clara y baja primero los ajustes costosos.")
        case .balanced:
            return localizedString(theme.language, english: "Recommended for most players. Panino balances clarity, smoothness, and heat for this Mac.", chinese: "大多数玩家选这个。Panino 会按这台 Mac 平衡清晰、流畅和发热。", italian: "Consigliato per quasi tutti. Panino bilancia nitidezza, fluidità e calore.", french: "Recommandé pour la plupart. Panino équilibre clarté, fluidité et chaleur.", spanish: "Recomendado para casi todos. Panino equilibra claridad, fluidez y calor.")
        case .performance:
            return localizedString(theme.language, english: "For stutter, heat, high refresh displays, shaders, or large modpacks.", chinese: "适合掉帧、发热、高刷屏、Shader 或大型整合包。", italian: "Per scatti, calore, schermi high refresh, shader o modpack grandi.", french: "Pour saccades, chaleur, écrans rapides, shaders ou gros packs.", spanish: "Para tirones, calor, pantallas rápidas, shaders o modpacks grandes.")
        case .batterySaver:
            return localizedString(theme.language, english: "Lowers visual cost when playing on battery.", chinese: "电池供电时降低画面成本。", italian: "Riduce il costo grafico a batteria.", french: "Réduit le coût visuel sur batterie.", spanish: "Baja el coste visual con batería.")
        case .manual:
            return localizedString(theme.language, english: "Manual graphics changes are kept, but Panino will still warn about risky values.", chinese: "保留手动画面设置，但 Panino 仍会提示高风险数值。", italian: "Le modifiche manuali restano, ma Panino segnala i rischi.", french: "Les réglages manuels restent, mais Panino signale les risques.", spanish: "Se conservan cambios manuales, pero Panino avisa de riesgos.")
        }
    }

    private func confidenceText(_ confidence: String?) -> String {
        switch confidence {
        case "measured_once":
            return localizedString(theme.language, english: "Measured once on this Mac.", chinese: "已在这台 Mac 上测过一次。", italian: "Misurato una volta su questo Mac.", french: "Mesuré une fois sur ce Mac.", spanish: "Medido una vez en este Mac.")
        case "measured_stable", "experiment_won":
            return localizedString(theme.language, english: "Verified by local launches.", chinese: "已通过本机启动验证。", italian: "Verificato da avvii locali.", french: "Vérifié par lancements locaux.", spanish: "Verificado con inicios locales.")
        case "blocked":
            return localizedString(theme.language, english: "Blocked by safety checks.", chinese: "已被安全检查阻止。", italian: "Bloccato dai controlli.", french: "Bloqué par sécurité.", spanish: "Bloqueado por seguridad.")
        default:
            return localizedString(theme.language, english: "Estimated graphics baseline, not measured yet.", chinese: "这是估算画面 baseline，尚未本机实测。", italian: "Baseline grafica stimata, non ancora misurata.", french: "Baseline graphique estimée, pas encore mesurée.", spanish: "Base gráfica estimada, aún no medida.")
        }
    }

    private func evidenceText(_ evidence: [CorePerformanceEvidence]?) -> String? {
        guard let evidence, !evidence.isEmpty else { return nil }
        let summary = evidence.prefix(2).map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return localizedString(theme.language, english: "Evidence: \(summary).", chinese: "证据：\(summary)。", italian: "Evidenza: \(summary).", french: "Preuves : \(summary).", spanish: "Evidencia: \(summary).")
    }

    private var warningText: String? {
        resolved?.warnings.first?.message
    }

    private var warningIcon: String {
        resolved?.warnings.first?.severity == "error" ? "exclamationmark.triangle" : "info.circle"
    }

    private var warningColor: Color {
        resolved?.warnings.first?.severity == "error" ? .orange : .secondary
    }

    private var patchChanges: [CoreOptionsPatchChange] {
        resolved?.optionsPatch.changes.filter { $0.status != "keep" } ?? []
    }

    private func patchValueText(_ change: CoreOptionsPatchChange) -> String {
        let old = change.oldValue ?? "-"
        let new = change.newValue ?? "-"
        return "\(old) -> \(new)"
    }

    private func graphicsValueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .monospacedDigit()
        }
    }

    private func advancedValue(_ key: String) -> String {
        manualOverrides[key] ?? resolved?.recommendedOptions[key] ?? "-"
    }

    private func markManual(_ key: String, value: String) {
        graphicsProfile = .manual
        manualOverrides[key] = value
    }

    private func intOverrideBinding(_ key: String, defaultValue: Int, range: ClosedRange<Int>) -> Binding<Int> {
        Binding(
            get: {
                let value = Int(advancedValue(key)) ?? defaultValue
                return min(max(value, range.lowerBound), range.upperBound)
            },
            set: { markManual(key, value: String($0)) }
        )
    }

    private func doubleOverrideBinding(_ key: String, defaultValue: Double, range: ClosedRange<Double>) -> Binding<Double> {
        Binding(
            get: {
                let value = Double(advancedValue(key)) ?? defaultValue
                return min(max(value, range.lowerBound), range.upperBound)
            },
            set: { markManual(key, value: String(format: "%.2f", $0)) }
        )
    }

    private func boolOverrideBinding(_ key: String, defaultValue: Bool) -> Binding<Bool> {
        Binding(
            get: {
                switch advancedValue(key).lowercased() {
                case "true":
                    return true
                case "false":
                    return false
                default:
                    return defaultValue
                }
            },
            set: { markManual(key, value: $0 ? "true" : "false") }
        )
    }

    private func textOverrideBinding(_ key: String, defaultValue: String) -> Binding<String> {
        Binding(
            get: {
                let value = advancedValue(key)
                return value == "-" ? defaultValue : encodedGraphicsOptionValue(key: key, value: value)
            },
            set: { markManual(key, value: $0) }
        )
    }

    private func encodedGraphicsOptionValue(key: String, value: String) -> String {
        switch key {
        case "renderClouds":
            switch value.trimmingCharacters(in: CharacterSet(charactersIn: "\"")).lowercased() {
            case "false", "off":
                return "\"false\""
            case "true", "fancy", "all":
                return "\"true\""
            default:
                return "\"fast\""
            }
        case "particles":
            switch value.lowercased() {
            case "all", "full":
                return "0"
            case "minimal":
                return "2"
            default:
                return value == "0" || value == "2" ? value : "1"
            }
        default:
            return value
        }
    }

    private func advancedTitle(for key: String) -> String {
        switch key {
        case "renderDistance":
            return localizedString(theme.language, english: "View Distance", chinese: "视距", italian: "Distanza vista", french: "Distance vue", spanish: "Distancia vista")
        case "simulationDistance":
            return localizedString(theme.language, english: "Simulation", chinese: "模拟距离", italian: "Simulazione", french: "Simulation", spanish: "Simulación")
        case "maxFps":
            return localizedString(theme.language, english: "Max FPS", chinese: "最高 FPS", italian: "FPS massimo", french: "FPS max", spanish: "FPS máximo")
        case "enableVsync":
            return "VSync"
        case "renderClouds":
            return localizedString(theme.language, english: "Clouds", chinese: "云", italian: "Nuvole", french: "Nuages", spanish: "Nubes")
        case "particles":
            return localizedString(theme.language, english: "Particles", chinese: "粒子", italian: "Particelle", french: "Particules", spanish: "Partículas")
        case "entityDistanceScaling":
            return localizedString(theme.language, english: "Entity Distance", chinese: "实体距离", italian: "Distanza entità", french: "Distance entités", spanish: "Distancia entidades")
        case "mipmapLevels":
            return "Mipmap"
        default:
            return key
        }
    }
}

enum GraphicsTuningUIContract {
    static let primaryProfiles: [InstanceGraphicsProfile] = [.balanced, .performance]
    static let advancedOptionKeys = [
        "renderDistance",
        "simulationDistance",
        "maxFps",
        "enableVsync",
        "renderClouds",
        "particles",
        "entityDistanceScaling",
        "mipmapLevels"
    ]
}

extension InstanceGraphicsProfile {
    func title(language: AppLanguage) -> String {
        switch self {
        case .clarity:
            return localizedString(language, english: "Clarity", chinese: "清晰优先", italian: "Nitidezza", french: "Clarté", spanish: "Claridad")
        case .balanced:
            return localizedString(language, english: "Auto", chinese: "自动推荐", italian: "Auto", french: "Auto", spanish: "Auto")
        case .performance:
            return localizedString(language, english: "Smoother", chinese: "更流畅", italian: "Più fluido", french: "Plus fluide", spanish: "Más fluido")
        case .batterySaver:
            return localizedString(language, english: "Battery", chinese: "省电", italian: "Batteria", french: "Batterie", spanish: "Batería")
        case .manual:
            return localizedString(language, english: "Manual", chinese: "手动", italian: "Manuale", french: "Manuel", spanish: "Manual")
        }
    }
}
