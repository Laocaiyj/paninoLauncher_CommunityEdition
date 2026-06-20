enum GraphicsTuningUIContract {
    static let primaryProfiles: [InstanceGraphicsProfile] = [.balanced, .performance]
    static let advancedOptionKeys = [
        "renderDistance",
        "simulationDistance",
        "maxFps",
        "enableVsync",
        "renderClouds",
        "particles",
        "entityDistanceScaling",
        "mipmapLevels"
    ]
}

extension InstanceGraphicsProfile {
    func title(language: AppLanguage) -> String {
        switch self {
        case .clarity:
            return localizedString(language, english: "Clarity", chinese: "清晰优先", italian: "Nitidezza", french: "Clarté", spanish: "Claridad")
        case .balanced:
            return localizedString(language, english: "Auto", chinese: "自动推荐", italian: "Auto", french: "Auto", spanish: "Auto")
        case .performance:
            return localizedString(language, english: "Smoother", chinese: "更流畅", italian: "Più fluido", french: "Plus fluide", spanish: "Más fluido")
        case .batterySaver:
            return localizedString(language, english: "Battery", chinese: "省电", italian: "Batteria", french: "Batterie", spanish: "Batería")
        case .manual:
            return localizedString(language, english: "Manual", chinese: "手动", italian: "Manuale", french: "Manuel", spanish: "Manual")
        }
    }
}
