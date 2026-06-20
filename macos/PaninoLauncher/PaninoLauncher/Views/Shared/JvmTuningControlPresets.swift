import SwiftUI

enum JvmTuningPreset: String, CaseIterable, Identifiable {
    case auto
    case smoother
    case largePack

    var id: String { rawValue }
}

extension JvmTuningControl {
    var presetBinding: Binding<JvmTuningPreset> {
        Binding(
            get: {
                switch jvmProfile {
                case .largePack:
                    return .largePack
                case .lowMemory, .batterySaver:
                    return .smoother
                default:
                    return .auto
                }
            },
            set: { preset in
                memoryPolicy = .auto
                customMemoryMb = nil
                switch preset {
                case .auto:
                    jvmProfile = .auto
                case .largePack:
                    jvmProfile = .largePack
                case .smoother:
                    jvmProfile = .lowMemory
                }
            }
        )
    }

    func title(for preset: JvmTuningPreset) -> String {
        switch preset {
        case .auto:
            return localizedString(theme.language, english: "Auto", chinese: "自动推荐", italian: "Auto", french: "Auto", spanish: "Auto")
        case .largePack:
            return localizedString(theme.language, english: "Large Pack", chinese: "大型整合包", italian: "Pacchetto grande", french: "Gros pack", spanish: "Pack grande")
        case .smoother:
            return localizedString(theme.language, english: "Smoother", chinese: "更流畅", italian: "Più fluido", french: "Plus fluide", spanish: "Más fluido")
        }
    }
}
