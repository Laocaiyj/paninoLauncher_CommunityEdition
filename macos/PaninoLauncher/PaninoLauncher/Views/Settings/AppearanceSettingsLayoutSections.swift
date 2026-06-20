import SwiftUI

struct AppearanceLayoutSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        AppearanceSection(
            title: localizedString(theme.language, english: "Layout", chinese: "布局", italian: "Layout", french: "Disposition", spanish: "Diseño"),
            systemImage: "rectangle.3.group"
        ) {
            SettingsRow(title: localizedString(theme.language, english: "Chrome", chinese: "窗口层", italian: "Chrome", french: "Chrome", spanish: "Cromo"), systemImage: "macwindow") {
                Picker(localizedString(theme.language, english: "Chrome", chinese: "窗口层", italian: "Chrome", french: "Chrome", spanish: "Cromo"), selection: $theme.chromeStyle) {
                    ForEach(ThemeChromeStyle.allCases) { style in
                        Text(style.title(language: theme.language)).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 240, alignment: .leading)
            }

            SettingsRow(title: localizedString(theme.language, english: "Shape", chinese: "形状", italian: "Forma", french: "Forme", spanish: "Forma"), systemImage: "capsule") {
                PaninoGlassSegmentedRail {
                    Picker(localizedString(theme.language, english: "Shape", chinese: "形状", italian: "Forma", french: "Forme", spanish: "Forma"), selection: $theme.controlShape) {
                        ForEach(ThemeControlShape.allCases) { shape in
                            Text(shape.title(language: theme.language)).tag(shape)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 360, maxWidth: 460, alignment: .leading)
                }
            }

            SettingsRow(title: localizedString(theme.language, english: "Depth Strength", chinese: "深度强度", italian: "Intensità profondità", french: "Intensité profondeur", spanish: "Intensidad de profundidad"), systemImage: "square.stack.3d.up") {
                PaninoGlassSegmentedRail {
                    Picker(localizedString(theme.language, english: "Depth Strength", chinese: "深度强度", italian: "Intensità profondità", french: "Intensité profondeur", spanish: "Intensidad de profundidad"), selection: $theme.depthStyle) {
                        ForEach(ThemeDepthStyle.allCases) { style in
                            Text(style.title(language: theme.language)).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 360, maxWidth: 460, alignment: .leading)
                }
            }

            SettingsRow(title: AppText.density.localized(theme.language), systemImage: "textformat.size") {
                PaninoGlassSegmentedRail {
                    Picker(AppText.density.localized(theme.language), selection: $theme.fontDensity) {
                        ForEach(FontDensity.allCases) { density in
                            Text(density.title(language: theme.language)).tag(density)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 300, maxWidth: 360, alignment: .leading)
                }
            }
        }
    }
}

struct AppearanceLegibilitySection: View {
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        AppearanceSection(
            title: localizedString(theme.language, english: "Legibility", chinese: "可读性", italian: "Leggibilità", french: "Lisibilité", spanish: "Legibilidad"),
            systemImage: "text.magnifyingglass"
        ) {
            SettingsRow(title: localizedString(theme.language, english: "Motion", chinese: "动效", italian: "Movimento", french: "Mouvement", spanish: "Movimiento"), systemImage: "sparkles.tv") {
                PaninoGlassSegmentedRail {
                    Picker(localizedString(theme.language, english: "Motion", chinese: "动效", italian: "Movimento", french: "Mouvement", spanish: "Movimiento"), selection: $theme.motionStyle) {
                        ForEach(ThemeMotionStyle.allCases) { style in
                            Text(style.title(language: theme.language)).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 300, maxWidth: 360, alignment: .leading)
                }
            }

            SettingsRow(title: localizedString(theme.language, english: "Quiet Mode", chinese: "安静模式", italian: "Modalità silenziosa", french: "Mode calme", spanish: "Modo tranquilo"), systemImage: "moon") {
                Toggle(AppText.enabled.localized(theme.language), isOn: $theme.quietModeEnabled)
                    .toggleStyle(.switch)
            }

            SettingsRow(title: localizedString(theme.language, english: "Reduce Visual Noise", chinese: "降低视觉噪声", italian: "Riduci rumore visivo", french: "Réduire le bruit visuel", spanish: "Reducir ruido visual"), systemImage: "eye") {
                Toggle(AppText.enabled.localized(theme.language), isOn: $theme.visualNoiseReductionEnabled)
                    .toggleStyle(.switch)
            }
        }
    }
}
