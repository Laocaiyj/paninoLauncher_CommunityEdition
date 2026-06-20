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

    @EnvironmentObject var theme: ThemeSettings
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
}
