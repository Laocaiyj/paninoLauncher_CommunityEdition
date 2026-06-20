import SwiftUI

struct InstanceAppearanceColorSection: View {
    @Binding var values: InstanceAppearanceValues

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        InstanceAppearanceSection(
            title: localizedString(theme.language, english: "Color", chinese: "颜色", italian: "Colore", french: "Couleur", spanish: "Color"),
            systemImage: "swatchpalette"
        ) {
            HStack(spacing: 10) {
                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                Text(values.coverColorHex.uppercased())
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                ForEach(InstanceAppearanceColorPreset.allCases) { preset in
                    Button {
                        values.coverColorHex = preset.hex
                    } label: {
                        InstanceAppearanceColorPresetTile(
                            preset: preset,
                            isSelected: isSelected(preset)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color.paninoHex(values.coverColorHex, fallback: theme.semanticSelectionColor) },
            set: { color in
                if let hex = color.paninoHexString {
                    values.coverColorHex = hex
                }
            }
        )
    }

    private func isSelected(_ preset: InstanceAppearanceColorPreset) -> Bool {
        values.coverColorHex.normalizedHex == preset.hex.normalizedHex
    }
}

struct InstanceAppearanceImageSection: View {
    @Binding var values: InstanceAppearanceValues
    let onChooseCover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        InstanceAppearanceSection(
            title: localizedString(theme.language, english: "Image", chinese: "图片", italian: "Immagine", french: "Image", spanish: "Imagen"),
            systemImage: "photo"
        ) {
            HStack(spacing: 8) {
                PaninoTextInput(
                    localizedString(theme.language, english: "Cover image path", chinese: "横幅图片路径", italian: "Percorso immagine", french: "Chemin de l'image", spanish: "Ruta de imagen"),
                    text: $values.coverPath
                )
                GlassButton(systemImage: "folder", title: AppText.choose.localized(theme.language), action: onChooseCover)
                GlassButton(systemImage: "xmark.circle", title: localizedString(theme.language, english: "Clear", chinese: "清除", italian: "Cancella", french: "Effacer", spanish: "Borrar")) {
                    values.coverPath = ""
                }
                .disabled(isCoverPathEmpty)
            }

            InstanceAppearanceSlider(
                title: localizedString(theme.language, english: "Horizontal Focus", chinese: "水平焦点", italian: "Fuoco orizzontale", french: "Point horizontal", spanish: "Enfoque horizontal"),
                value: $values.coverFocusX
            )
            InstanceAppearanceSlider(
                title: localizedString(theme.language, english: "Vertical Focus", chinese: "垂直焦点", italian: "Fuoco verticale", french: "Point vertical", spanish: "Enfoque vertical"),
                value: $values.coverFocusY
            )
            InstanceAppearanceSlider(
                title: localizedString(theme.language, english: "Cover Blur", chinese: "封面模糊", italian: "Sfocatura copertina", french: "Flou couverture", spanish: "Desenfoque portada"),
                value: $values.coverBlur
            )
            InstanceAppearanceSlider(
                title: localizedString(theme.language, english: "Cover Dim", chinese: "封面暗化", italian: "Oscura copertina", french: "Assombrir couverture", spanish: "Oscurecer portada"),
                value: $values.coverDim
            )
        }
    }

    private var isCoverPathEmpty: Bool {
        values.coverPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct InstanceAppearanceIconSection: View {
    @Binding var values: InstanceAppearanceValues

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        InstanceAppearanceSection(
            title: localizedString(theme.language, english: "Icon", chinese: "图标", italian: "Icona", french: "Icône", spanish: "Icono"),
            systemImage: "square.grid.3x3"
        ) {
            Picker(localizedString(theme.language, english: "Backdrop", chinese: "底板", italian: "Sfondo", french: "Fond", spanish: "Fondo"), selection: $values.iconBackdropStyle) {
                ForEach(InstanceIconBackdropStyle.allCases) { style in
                    Text(style.title(language: theme.language)).tag(style)
                }
            }
            .pickerStyle(.segmented)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(InstanceAppearanceIconPreset.allCases) { preset in
                    Button {
                        values.iconName = preset.systemName
                    } label: {
                        InstanceAppearanceIconPresetTile(
                            preset: preset,
                            isSelected: values.iconName == preset.systemName,
                            tint: Color.paninoHex(values.coverColorHex, fallback: theme.semanticSelectionColor)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            PaninoTextInput(
                localizedString(theme.language, english: "SF Symbol name", chinese: "SF Symbol 名称", italian: "Nome SF Symbol", french: "Nom SF Symbol", spanish: "Nombre SF Symbol"),
                text: $values.iconName
            )
        }
    }
}

private struct InstanceAppearanceColorPresetTile: View {
    let preset: InstanceAppearanceColorPreset
    let isSelected: Bool

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.paninoHex(preset.hex, fallback: theme.semanticSelectionColor))
                .frame(width: 28, height: 28)
            Text(preset.title(language: theme.language))
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tileBorder, lineWidth: 1)
        }
    }

    private var tileBackground: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.32)
    }

    private var tileBorder: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.35)
    }
}

private struct InstanceAppearanceIconPresetTile: View {
    let preset: InstanceAppearanceIconPreset
    let isSelected: Bool
    let tint: Color

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: preset.systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
            Text(preset.title(language: theme.language))
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 66)
        .background(tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tileBorder, lineWidth: 1)
        }
    }

    private var tileBackground: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.32)
    }

    private var tileBorder: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.35)
    }
}
