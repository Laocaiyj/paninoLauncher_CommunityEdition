import SwiftUI

struct AppearanceSettingsPage: View {
    var showLanguage = true

    @EnvironmentObject private var theme: ThemeSettings
    @State private var isImportingBackground = false
    @State private var backgroundImportError: String?

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing + 4) {
                PanelHeader(title: AppText.appearance.localized(theme.language), systemImage: "paintbrush")

                AppearanceSection(title: localizedString(theme.language, english: "Presets", chinese: "预设", italian: "Preset", french: "Préréglages", spanish: "Preajustes"), systemImage: "swatchpalette") {
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

                    SettingsRow(title: localizedString(theme.language, english: "Custom", chinese: "自定义", italian: "Personalizzato", french: "Personnalisé", spanish: "Personalizado"), systemImage: "paintpalette") {
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

                AppearanceSection(title: localizedString(theme.language, english: "Liquid Glass", chinese: "Liquid Glass", italian: "Liquid Glass", french: "Liquid Glass", spanish: "Liquid Glass"), systemImage: "square.stack.3d.down.right") {
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

                    SettingsRow(title: localizedString(theme.language, english: "Liquid Glass Strength", chinese: "Liquid Glass 强度", italian: "Intensità Liquid Glass", french: "Intensité Liquid Glass", spanish: "Intensidad Liquid Glass"), systemImage: "circle.dotted") {
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

                AppearanceSection(title: localizedString(theme.language, english: "Layout", chinese: "布局", italian: "Layout", french: "Disposition", spanish: "Diseño"), systemImage: "rectangle.3.group") {
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

                AppearanceSection(title: localizedString(theme.language, english: "Legibility", chinese: "可读性", italian: "Leggibilità", french: "Lisibilité", spanish: "Legibilidad"), systemImage: "text.magnifyingglass") {
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
        .fileImporter(
            isPresented: $isImportingBackground,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                do {
                    theme.customImageBookmark = try url.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    theme.customImagePath = url.path
                    theme.backgroundMode = .customImage
                } catch {
                    theme.customImageBookmark = nil
                    backgroundImportError = error.localizedDescription
                }
            }
        }
        .alert(
            "Background Import Failed",
            isPresented: Binding(
                get: { backgroundImportError != nil },
                set: { if !$0 { backgroundImportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backgroundImportError ?? "")
        }
    }

    private var customAccentBinding: Binding<Color> {
        Binding(
            get: { Color.paninoHex(theme.customAccentHex, fallback: theme.semanticSelectionColor) },
            set: { color in
                if let hex = color.paninoHexString {
                    theme.customAccentHex = hex
                    theme.accent = .custom
                }
            }
        )
    }
}
