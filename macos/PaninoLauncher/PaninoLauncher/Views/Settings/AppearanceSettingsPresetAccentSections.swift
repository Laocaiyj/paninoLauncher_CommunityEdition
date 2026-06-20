import SwiftUI

struct AppearancePresetsSection: View {
    let showLanguage: Bool

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        AppearanceSection(
            title: localizedString(theme.language, english: "Presets", chinese: "预设", italian: "Preset", french: "Préréglages", spanish: "Preajustes"),
            systemImage: "swatchpalette"
        ) {
            if showLanguage {
                SettingsRow(title: AppText.language.localized(theme.language), systemImage: "globe") {
                    Picker(AppText.language.localized(theme.language), selection: $theme.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 180, alignment: .leading)
                }
            }

            SettingsRow(title: AppText.mode.localized(theme.language), systemImage: "circle.lefthalf.filled") {
                PaninoGlassSegmentedRail {
                    Picker(AppText.mode.localized(theme.language), selection: $theme.appearance) {
                        ForEach(ThemeAppearanceMode.allCases) { mode in
                            Text(mode.title(language: theme.language)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(minWidth: 420, maxWidth: 560, alignment: .leading)
                }
            }

            SettingsRow(title: AppText.preset.localized(theme.language), systemImage: "sparkles.rectangle.stack") {
                HStack(spacing: 8) {
                    Picker(AppText.preset.localized(theme.language), selection: $theme.currentPreset) {
                        ForEach(ThemePreset.allCases) { preset in
                            Text(preset.title(language: theme.language)).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220, alignment: .leading)

                    GlassButton(systemImage: "checkmark", title: AppText.apply.localized(theme.language)) {
                        theme.applyPreset(theme.currentPreset)
                    }
                    .frame(minWidth: 92, alignment: .leading)
                }
            }
        }
    }
}

struct AppearanceAccentSection: View {
    let customAccentBinding: Binding<Color>

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        AppearanceSection(title: AppText.accent.localized(theme.language), systemImage: "eyedropper") {
            SettingsRow(title: AppText.accent.localized(theme.language), systemImage: "circle.hexagongrid") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(ThemeAccentColor.allCases) { accent in
                        AccentSwatchButton(
                            accent: accent,
                            isSelected: theme.accent == accent
                        ) {
                            theme.accent = accent
                        }
                    }
                }
                .frame(maxWidth: 660, alignment: .leading)
            }

            SettingsRow(
                title: localizedString(theme.language, english: "Custom", chinese: "自定义", italian: "Personalizzato", french: "Personnalisé", spanish: "Personalizado"),
                systemImage: "paintpalette"
            ) {
                HStack(spacing: 10) {
                    ColorPicker("", selection: customAccentBinding, supportsOpacity: false)
                        .labelsHidden()
                    Text(theme.customAccentHex.uppercased())
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .leading)
                    GlassButton(systemImage: "paintbrush.pointed", title: localizedString(theme.language, english: "Use Custom", chinese: "使用自定义", italian: "Usa", french: "Utiliser", spanish: "Usar")) {
                        theme.accent = .custom
                    }
                }
            }
        }
    }
}
