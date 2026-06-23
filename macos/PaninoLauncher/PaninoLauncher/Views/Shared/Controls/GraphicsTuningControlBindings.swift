import SwiftUI

extension GraphicsTuningControl {
    func advancedValue(_ key: String) -> String {
        manualOverrides[key] ?? resolved?.recommendedOptions[key] ?? "-"
    }

    func markManual(_ key: String, value: String) {
        graphicsProfile = .manual
        manualOverrides[key] = value
    }

    func intOverrideBinding(_ key: String, defaultValue: Int, range: ClosedRange<Int>) -> Binding<Int> {
        Binding(
            get: {
                let value = Int(advancedValue(key)) ?? defaultValue
                return min(max(value, range.lowerBound), range.upperBound)
            },
            set: { markManual(key, value: String($0)) }
        )
    }

    func doubleOverrideBinding(_ key: String, defaultValue: Double, range: ClosedRange<Double>) -> Binding<Double> {
        Binding(
            get: {
                let value = Double(advancedValue(key)) ?? defaultValue
                return min(max(value, range.lowerBound), range.upperBound)
            },
            set: { markManual(key, value: String(format: "%.2f", $0)) }
        )
    }

    func boolOverrideBinding(_ key: String, defaultValue: Bool) -> Binding<Bool> {
        Binding(
            get: {
                switch advancedValue(key).lowercased() {
                case "true":
                    return true
                case "false":
                    return false
                default:
                    return defaultValue
                }
            },
            set: { markManual(key, value: $0 ? "true" : "false") }
        )
    }

    func textOverrideBinding(_ key: String, defaultValue: String) -> Binding<String> {
        Binding(
            get: {
                let value = advancedValue(key)
                return value == "-" ? defaultValue : encodedGraphicsOptionValue(key: key, value: value)
            },
            set: { markManual(key, value: $0) }
        )
    }

    func encodedGraphicsOptionValue(key: String, value: String) -> String {
        switch key {
        case "renderClouds":
            switch value.trimmingCharacters(in: CharacterSet(charactersIn: "\"")).lowercased() {
            case "false", "off":
                return "\"false\""
            case "true", "fancy", "all":
                return "\"true\""
            default:
                return "\"fast\""
            }
        case "particles":
            switch value.lowercased() {
            case "all", "full":
                return "0"
            case "minimal":
                return "2"
            default:
                return value == "0" || value == "2" ? value : "1"
            }
        default:
            return value
        }
    }
}
