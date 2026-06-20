import SwiftUI

struct AppearanceLiquidGlassSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        AppearanceSection(
            title: localizedString(theme.language, english: "Liquid Glass", chinese: "Liquid Glass", italian: "Liquid Glass", french: "Liquid Glass", spanish: "Liquid Glass"),
            systemImage: "square.stack.3d.down.right"
        ) {
            SettingsRow(title: AppText.glass.localized(theme.language), systemImage: "sparkles") {
                PaninoGlassSegmentedRail {
                    Picker(AppText.glass.localized(theme.language), selection: $theme.glassStyle) {
                        ForEach(ThemeGlassStyle.allCases) { style in
                            Text(style.title(language: theme.language)).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 420, maxWidth: 560, alignment: .leading)
                }
                .disabled(theme.quietModeEnabled)
                .opacity(theme.quietModeEnabled ? 0.45 : 1)
            }

            SettingsRow(
                title: localizedString(theme.language, english: "Liquid Glass Strength", chinese: "Liquid Glass 强度", italian: "Intensità Liquid Glass", french: "Intensité Liquid Glass", spanish: "Intensidad Liquid Glass"),
                systemImage: "circle.dotted"
            ) {
                PaninoGlassSegmentedRail {
                    Picker(localizedString(theme.language, english: "Liquid Glass Strength", chinese: "Liquid Glass 强度", italian: "Intensità Liquid Glass", french: "Intensité Liquid Glass", spanish: "Intensidad Liquid Glass"), selection: $theme.materialStrength) {
                        ForEach(MaterialStrength.allCases) { strength in
                            Text(strength.title(language: theme.language)).tag(strength)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 340, maxWidth: 420, alignment: .leading)
                }
                .disabled(theme.quietModeEnabled || theme.glassStyle == .solid)
                .opacity(theme.quietModeEnabled || theme.glassStyle == .solid ? 0.45 : 1)
            }

            ThemeSliderRow(
                title: localizedString(theme.language, english: "Glass Frosting", chinese: "玻璃磨砂", italian: "Satinatura vetro", french: "Dépoli du verre", spanish: "Esmerilado del cristal"),
                systemImage: "cloud.fog",
                value: $theme.glassFrosting
            )

            ThemeSliderRow(
                title: localizedString(theme.language, english: "Panel Legibility", chinese: "面板可读性", italian: "Leggibilità pannelli", french: "Lisibilité des panneaux", spanish: "Legibilidad de paneles"),
                systemImage: "circle.righthalf.filled",
                value: $theme.surfaceContrast
            )
        }
    }
}

struct AppearanceBackgroundSection: View {
    @Binding var isImportingBackground: Bool

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        AppearanceSection(title: AppText.background.localized(theme.language), systemImage: "photo") {
            SettingsRow(title: AppText.background.localized(theme.language), systemImage: "photo.on.rectangle") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Picker(AppText.background.localized(theme.language), selection: $theme.backgroundMode) {
                            ForEach(ThemeBackgroundMode.allCases) { mode in
                                Text(mode.title(language: theme.language)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 210, alignment: .leading)

                        GlassButton(systemImage: "folder", title: AppText.choose.localized(theme.language), prominent: theme.backgroundMode == .customImage) {
                            isImportingBackground = true
                        }
                        .disabled(theme.quietModeEnabled || theme.backgroundMode != .customImage)
                    }
                    .disabled(theme.quietModeEnabled)

                    if !theme.customImagePath.isEmpty {
                        Text(theme.customImagePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .frame(maxWidth: 560, alignment: .leading)
                    }
                }
            }

            ThemeSliderRow(
                title: localizedString(theme.language, english: "Blur", chinese: "模糊", italian: "Sfocatura", french: "Flou", spanish: "Desenfoque"),
                systemImage: "camera.filters",
                value: $theme.backgroundBlur,
                disabled: theme.quietModeEnabled || theme.visualNoiseReductionEnabled
            )

            ThemeSliderRow(
                title: localizedString(theme.language, english: "Dim", chinese: "暗化", italian: "Oscuramento", french: "Assombrir", spanish: "Oscurecer"),
                systemImage: "sun.min",
                value: $theme.backgroundDim
            )

            SettingsRow(title: AppText.softTexture.localized(theme.language), systemImage: "square.stack.3d.forward.dottedline") {
                Toggle(AppText.enabled.localized(theme.language), isOn: $theme.softBackgroundEnabled)
                    .toggleStyle(.switch)
                    .disabled(theme.quietModeEnabled || theme.visualNoiseReductionEnabled)
                    .opacity(theme.quietModeEnabled || theme.visualNoiseReductionEnabled ? 0.45 : 1)
            }
        }
    }
}
