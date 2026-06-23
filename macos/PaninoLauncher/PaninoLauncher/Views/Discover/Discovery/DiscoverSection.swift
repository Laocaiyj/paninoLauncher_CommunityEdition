enum DiscoverSection: String, CaseIterable, Identifiable {
    case minecraft
    case mods
    case modpacks
    case resources
    case shaders

    var id: String { rawValue }

    var projectType: OnlineProjectType? {
        switch self {
        case .minecraft:
            return nil
        case .mods:
            return .mod
        case .modpacks:
            return .modpack
        case .resources:
            return .resourcePack
        case .shaders:
            return .shaderPack
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .minecraft:
            return "Minecraft"
        case .mods:
            return "Mods"
        case .modpacks:
            return "Modpacks"
        case .resources:
            return localizedString(language, english: "Resource Packs", chinese: "资源包", italian: "Pacchetti risorse", french: "Packs de ressources", spanish: "Paquetes de recursos")
        case .shaders:
            return localizedString(language, english: "Shaders", chinese: "光影包", italian: "Shader", french: "Shaders", spanish: "Shaders")
        }
    }
}
