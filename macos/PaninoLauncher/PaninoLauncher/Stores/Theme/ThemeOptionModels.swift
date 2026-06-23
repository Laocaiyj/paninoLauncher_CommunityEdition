enum ThemePreset: String, CaseIterable, Identifiable {
    case vanilla
    case nether
    case deepDark
    case liquidGlass
    case frostedGraphite
    case minecraftAmbient
    case focusSolid
    case highLegibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vanilla:
            return "Vanilla"
        case .nether:
            return "Nether"
        case .deepDark:
            return "Deep Dark"
        case .liquidGlass:
            return "Liquid Glass"
        case .frostedGraphite:
            return "Frosted Graphite"
        case .minecraftAmbient:
            return "Minecraft Ambient"
        case .focusSolid:
            return "Focus Solid"
        case .highLegibility:
            return "High Legibility"
        }
    }
}
