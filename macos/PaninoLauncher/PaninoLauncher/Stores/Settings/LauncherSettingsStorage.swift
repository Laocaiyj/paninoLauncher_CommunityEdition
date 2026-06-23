import Foundation

extension LauncherSettings {
    static func integer(forKey key: String, defaultValue: Int, range: ClosedRange<Int>) -> Int {
        let rawValue = SettingsStore.string(forKey: key, default: String(defaultValue))
        let value = Int(rawValue) ?? defaultValue
        return min(max(value, range.lowerBound), range.upperBound)
    }

    static func loadEnum<Value: RawRepresentable>(
        key: String,
        defaultValue: Value
    ) -> Value where Value.RawValue == String {
        let rawValue = SettingsStore.string(forKey: key, default: defaultValue.rawValue)
        return Value(rawValue: rawValue) ?? defaultValue
    }
}
