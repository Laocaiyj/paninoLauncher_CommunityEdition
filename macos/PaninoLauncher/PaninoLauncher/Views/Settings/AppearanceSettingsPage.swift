import SwiftUI

struct AppearanceSettingsPage: View {
    var showLanguage = true

    @EnvironmentObject private var theme: ThemeSettings
    @State private var isImportingBackground = false
    @State private var backgroundImportError: String?

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(title: AppText.appearance.localized(theme.language), systemImage: "paintbrush")

                if showLanguage {
                    SettingsRow(title: AppText.language.localized(theme.language), systemImage: "globe") {
                        Picker(AppText.language.localized(theme.language), selection: $theme.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .controlSize(.large)
                        .frame(width: 180, alignment: .leading)
                    }
                }

                SettingsRow(title: AppText.mode.localized(theme.language), systemImage: "circle.lefthalf.filled") {
                    Picker(AppText.mode.localized(theme.language), selection: $theme.appearance) {
                        ForEach(ThemeAppearanceMode.allCases) { mode in
                            Text(mode.title(language: theme.language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .frame(minWidth: 420, maxWidth: 560, alignment: .leading)
                }

                SettingsRow(title: AppText.accent.localized(theme.language), systemImage: "eyedropper") {
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
                    .frame(maxWidth: 560, alignment: .leading)
                }

                SettingsRow(title: AppText.preset.localized(theme.language), systemImage: "swatchpalette") {
                    HStack(spacing: 8) {
                        Picker(AppText.preset.localized(theme.language), selection: $theme.currentPreset) {
                            ForEach(ThemePreset.allCases) { preset in
                                Text(preset.title(language: theme.language)).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .controlSize(.large)
                        .frame(width: 180, alignment: .leading)

                        GlassButton(systemImage: "checkmark", title: AppText.apply.localized(theme.language)) {
                            theme.applyPreset(theme.currentPreset)
                        }
                        .frame(minWidth: 92, alignment: .leading)
                    }
                }

                SettingsRow(title: localizedString(theme.language, english: "Quiet Mode", chinese: "安静模式", italian: "Modalità silenziosa", french: "Mode calme", spanish: "Modo tranquilo"), systemImage: "moon") {
                    Toggle(AppText.enabled.localized(theme.language), isOn: $theme.quietModeEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.large)
                }

                SettingsRow(title: AppText.glass.localized(theme.language), systemImage: "sparkles") {
                    Picker(AppText.glass.localized(theme.language), selection: $theme.materialStrength) {
                        ForEach(MaterialStrength.allCases) { strength in
                            Text(strength.title(language: theme.language)).tag(strength)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .frame(minWidth: 340, maxWidth: 420, alignment: .leading)
                    .disabled(theme.quietModeEnabled)
                    .opacity(theme.quietModeEnabled ? 0.45 : 1)
                }

                SettingsRow(title: AppText.background.localized(theme.language), systemImage: "photo") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Picker(AppText.background.localized(theme.language), selection: $theme.backgroundMode) {
                                ForEach(ThemeBackgroundMode.allCases) { mode in
                                    Text(mode.title(language: theme.language)).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .controlSize(.large)
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

                SettingsRow(title: AppText.softTexture.localized(theme.language), systemImage: "square.stack.3d.forward.dottedline") {
                    Toggle(AppText.enabled.localized(theme.language), isOn: $theme.softBackgroundEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.large)
                        .disabled(theme.quietModeEnabled)
                        .opacity(theme.quietModeEnabled ? 0.45 : 1)
                }

                SettingsRow(title: AppText.density.localized(theme.language), systemImage: "textformat.size") {
                    Picker(AppText.density.localized(theme.language), selection: $theme.fontDensity) {
                        ForEach(FontDensity.allCases) { density in
                            Text(density.title(language: theme.language)).tag(density)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.large)
                    .frame(minWidth: 300, maxWidth: 360, alignment: .leading)
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
}

private struct AccentSwatchButton: View {
    let accent: ThemeAccentColor
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                swatch
                Text(accent.title(language: theme.language))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.semanticSelectionColor)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(buttonBackground, in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.82) : Color(nsColor: .separatorColor).opacity(0.5), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accent.title(language: theme.language))
    }

    @ViewBuilder
    private var swatch: some View {
        if let color = accent.color {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
        } else {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.blue, .purple, .red, .orange, .green, .blue],
                        center: .center
                    )
                )
                .frame(width: 16, height: 16)
        }
    }

    private var buttonBackground: Color {
        if isSelected {
            return theme.semanticSelectionColor.opacity(0.14)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.35)
    }
}
