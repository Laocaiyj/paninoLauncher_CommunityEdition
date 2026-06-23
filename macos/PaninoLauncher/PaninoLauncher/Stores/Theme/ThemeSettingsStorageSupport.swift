import AppKit
import Foundation

extension ThemeSettings {
    static func loadEnum<Value: RawRepresentable>(
        key: String,
        defaultValue: Value
    ) -> Value where Value.RawValue == String {
        let rawValue = SettingsStore.string(forKey: key, default: defaultValue.rawValue)
        return Value(rawValue: rawValue) ?? defaultValue
    }

    static func clampedUnit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    func applyAppAppearance() {
        NSApplication.shared.appearance = appearance.nsAppearance
    }
}
