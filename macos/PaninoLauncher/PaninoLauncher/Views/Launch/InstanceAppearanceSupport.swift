import SwiftUI

struct InstanceAppearancePreview: View {
    let instance: GameInstance
    let values: InstanceAppearanceValues

    @EnvironmentObject private var theme: ThemeSettings
    @State private var image: NSImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.08, anchor: UnitPoint(x: CGFloat(values.coverFocusX), y: CGFloat(values.coverFocusY)))
                    .blur(radius: values.coverBlur * 14, opaque: true)
            } else {
                LinearGradient(
                    colors: [
                        Color.paninoHex(values.coverColorHex, fallback: theme.semanticSelectionColor).opacity(0.72),
                        Color(nsColor: .controlBackgroundColor).opacity(0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [.black.opacity(0.02), .black.opacity(0.22 + values.coverDim * 0.58)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: values.normalized.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.paninoHex(values.coverColorHex, fallback: theme.semanticSelectionColor))
                    .frame(width: 54, height: 54)
                    .background(iconBackdrop, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(instance.name)
                    .font(.title3.bold())
                    .lineLimit(1)
                Text("Minecraft \(instance.minecraftVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .task(id: values.coverPath) {
            let path = values.coverPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: path, size: CGSize(width: 640, height: 360))
        }
    }

    private var iconBackdrop: Color {
        switch values.iconBackdropStyle {
        case .automatic:
            Color.black.opacity(values.coverPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 0.24)
        case .none:
            Color.clear
        case .plate:
            Color.black.opacity(0.34)
        case .glass:
            Color.white.opacity(0.18)
        }
    }
}

struct InstanceAppearanceSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
    }
}

struct InstanceAppearanceSlider: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Slider(value: $value, in: 0...1, step: 0.01)
            Text("\(Int((value * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

extension InstanceIconBackdropStyle {
    func title(language: AppLanguage) -> String {
        switch self {
        case .automatic:
            return localizedString(language, english: "Auto", chinese: "自动", italian: "Auto", french: "Auto", spanish: "Auto")
        case .none:
            return localizedString(language, english: "None", chinese: "无", italian: "Nessuno", french: "Aucun", spanish: "Ninguno")
        case .plate:
            return localizedString(language, english: "Plate", chinese: "底板", italian: "Piastra", french: "Plaque", spanish: "Placa")
        case .glass:
            return localizedString(language, english: "Glass", chinese: "玻璃", italian: "Vetro", french: "Verre", spanish: "Cristal")
        }
    }
}

enum InstanceAppearanceColorPreset: String, CaseIterable, Identifiable {
    case redstone
    case grass
    case diamond
    case gold
    case amethyst
    case nether
    case prismarine
    case deepslate

    var id: String { rawValue }

    var hex: String {
        switch self {
        case .redstone: return "#ef4444"
        case .grass: return "#22c55e"
        case .diamond: return "#38bdf8"
        case .gold: return "#f59e0b"
        case .amethyst: return "#a855f7"
        case .nether: return "#dc2626"
        case .prismarine: return "#14b8a6"
        case .deepslate: return "#64748b"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .redstone:
            return localizedString(language, english: "Redstone", chinese: "红石", italian: "Redstone", french: "Redstone", spanish: "Redstone")
        case .grass:
            return localizedString(language, english: "Grass", chinese: "草方块", italian: "Erba", french: "Herbe", spanish: "Hierba")
        case .diamond:
            return localizedString(language, english: "Diamond", chinese: "钻石", italian: "Diamante", french: "Diamant", spanish: "Diamante")
        case .gold:
            return localizedString(language, english: "Gold", chinese: "金锭", italian: "Oro", french: "Or", spanish: "Oro")
        case .amethyst:
            return localizedString(language, english: "Amethyst", chinese: "紫水晶", italian: "Ametista", french: "Améthyste", spanish: "Amatista")
        case .nether:
            return localizedString(language, english: "Nether", chinese: "下界", italian: "Nether", french: "Nether", spanish: "Nether")
        case .prismarine:
            return localizedString(language, english: "Prismarine", chinese: "海晶", italian: "Prismarine", french: "Prismarine", spanish: "Prismarino")
        case .deepslate:
            return localizedString(language, english: "Deepslate", chinese: "深板岩", italian: "Ardesia", french: "Ardoise", spanish: "Pizarra")
        }
    }
}

enum InstanceAppearanceIconPreset: String, CaseIterable, Identifiable {
    case cube
    case chest
    case stack
    case pickaxe
    case forge
    case mod
    case world
    case leaf
    case fire
    case water
    case lightning
    case controller

    var id: String { rawValue }

    var systemName: String {
        switch self {
        case .cube: return "cube.fill"
        case .chest: return "shippingbox.fill"
        case .stack: return "square.stack.3d.up.fill"
        case .pickaxe: return "hammer.fill"
        case .forge: return "wrench.and.screwdriver.fill"
        case .mod: return "puzzlepiece.extension.fill"
        case .world: return "mountain.2.fill"
        case .leaf: return "leaf.fill"
        case .fire: return "flame.fill"
        case .water: return "drop.fill"
        case .lightning: return "bolt.fill"
        case .controller: return "gamecontroller.fill"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .cube:
            return localizedString(language, english: "Block", chinese: "方块", italian: "Blocco", french: "Bloc", spanish: "Bloque")
        case .chest:
            return localizedString(language, english: "Crate", chinese: "箱子", italian: "Cassa", french: "Caisse", spanish: "Caja")
        case .stack:
            return localizedString(language, english: "Stack", chinese: "堆叠", italian: "Pila", french: "Pile", spanish: "Pila")
        case .pickaxe:
            return localizedString(language, english: "Tool", chinese: "工具", italian: "Attrezzo", french: "Outil", spanish: "Herramienta")
        case .forge:
            return localizedString(language, english: "Forge", chinese: "锻造", italian: "Forgia", french: "Forge", spanish: "Forja")
        case .mod:
            return localizedString(language, english: "Mod", chinese: "Mod", italian: "Mod", french: "Mod", spanish: "Mod")
        case .world:
            return localizedString(language, english: "World", chinese: "世界", italian: "Mondo", french: "Monde", spanish: "Mundo")
        case .leaf:
            return localizedString(language, english: "Nature", chinese: "自然", italian: "Natura", french: "Nature", spanish: "Naturaleza")
        case .fire:
            return localizedString(language, english: "Fire", chinese: "火焰", italian: "Fuoco", french: "Feu", spanish: "Fuego")
        case .water:
            return localizedString(language, english: "Water", chinese: "水域", italian: "Acqua", french: "Eau", spanish: "Agua")
        case .lightning:
            return localizedString(language, english: "Power", chinese: "能量", italian: "Energia", french: "Énergie", spanish: "Energía")
        case .controller:
            return localizedString(language, english: "Game", chinese: "游戏", italian: "Gioco", french: "Jeu", spanish: "Juego")
        }
    }
}

extension InstanceAppearanceValues {
    var normalized: InstanceAppearanceValues {
        InstanceAppearanceValues(
            iconName: iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "cube.fill" : iconName.trimmingCharacters(in: .whitespacesAndNewlines),
            coverPath: coverPath.trimmingCharacters(in: .whitespacesAndNewlines),
            coverColorHex: coverColorHex.normalizedHex.isEmpty ? GameInstance.defaultCoverColorHex : coverColorHex.normalizedHex,
            coverFocusX: GameInstance.clampedUnit(coverFocusX),
            coverFocusY: GameInstance.clampedUnit(coverFocusY),
            coverBlur: GameInstance.clampedUnit(coverBlur),
            coverDim: GameInstance.clampedUnit(coverDim),
            iconBackdropStyle: iconBackdropStyle
        )
    }

    init(
        iconName: String,
        coverPath: String,
        coverColorHex: String,
        coverFocusX: Double,
        coverFocusY: Double,
        coverBlur: Double,
        coverDim: Double,
        iconBackdropStyle: InstanceIconBackdropStyle
    ) {
        self.iconName = iconName
        self.coverPath = coverPath
        self.coverColorHex = coverColorHex
        self.coverFocusX = coverFocusX
        self.coverFocusY = coverFocusY
        self.coverBlur = coverBlur
        self.coverDim = coverDim
        self.iconBackdropStyle = iconBackdropStyle
    }
}

extension Color {
    static func paninoHex(_ value: String, fallback: Color) -> Color {
        guard let color = NSColor.paninoHex(value) else { return fallback }
        return Color(nsColor: color)
    }

    var paninoHexString: String? {
        NSColor(self).paninoHexString
    }
}

extension String {
    var normalizedHex: String {
        guard let color = NSColor.paninoHex(self) else { return "" }
        return color.paninoHexString ?? ""
    }
}

private extension NSColor {
    static func paninoHex(_ value: String) -> NSColor? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard hex.count == 6 || hex.count == 8 else { return nil }
        var raw: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&raw) else { return nil }
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        if hex.count == 8 {
            red = CGFloat((raw & 0xff00_0000) >> 24) / 255
            green = CGFloat((raw & 0x00ff_0000) >> 16) / 255
            blue = CGFloat((raw & 0x0000_ff00) >> 8) / 255
            alpha = CGFloat(raw & 0x0000_00ff) / 255
        } else {
            red = CGFloat((raw & 0xff0000) >> 16) / 255
            green = CGFloat((raw & 0x00ff00) >> 8) / 255
            blue = CGFloat(raw & 0x0000ff) / 255
            alpha = 1
        }
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var paninoHexString: String? {
        guard let color = usingColorSpace(.sRGB) else { return nil }
        let red = max(0, min(255, Int(round(color.redComponent * 255))))
        let green = max(0, min(255, Int(round(color.greenComponent * 255))))
        let blue = max(0, min(255, Int(round(color.blueComponent * 255))))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
