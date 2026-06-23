import SwiftUI

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

        let components = rgbaComponents(from: raw, length: hex.count)
        return NSColor(
            srgbRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
    }

    var paninoHexString: String? {
        guard let color = usingColorSpace(.sRGB) else { return nil }
        let red = Self.byteComponent(color.redComponent)
        let green = Self.byteComponent(color.greenComponent)
        let blue = Self.byteComponent(color.blueComponent)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private static func rgbaComponents(
        from raw: UInt64,
        length: Int
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        if length == 8 {
            return (
                red: CGFloat((raw & 0xff00_0000) >> 24) / 255,
                green: CGFloat((raw & 0x00ff_0000) >> 16) / 255,
                blue: CGFloat((raw & 0x0000_ff00) >> 8) / 255,
                alpha: CGFloat(raw & 0x0000_00ff) / 255
            )
        }

        return (
            red: CGFloat((raw & 0xff0000) >> 16) / 255,
            green: CGFloat((raw & 0x00ff00) >> 8) / 255,
            blue: CGFloat(raw & 0x0000ff) / 255,
            alpha: 1
        )
    }

    private static func byteComponent(_ value: CGFloat) -> Int {
        max(0, min(255, Int(round(value * 255))))
    }
}
