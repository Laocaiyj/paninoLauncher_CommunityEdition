import SwiftUI

func formattedBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

func formattedPlayDuration(_ seconds: TimeInterval, language: AppLanguage) -> String {
    let totalMinutes = max(Int(seconds / 60), 0)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours == 0 {
        return localizedString(language, english: "\(minutes)m", chinese: "\(minutes) 分钟", italian: "\(minutes)m", french: "\(minutes) min", spanish: "\(minutes)m")
    }
    if minutes == 0 {
        return localizedString(language, english: "\(hours)h", chinese: "\(hours) 小时", italian: "\(hours)h", french: "\(hours) h", spanish: "\(hours)h")
    }
    return localizedString(language, english: "\(hours)h \(minutes)m", chinese: "\(hours) 小时 \(minutes) 分钟", italian: "\(hours)h \(minutes)m", french: "\(hours) h \(minutes) min", spanish: "\(hours)h \(minutes)m")
}

func javaMajorVersion(from text: String) -> Int? {
    for token in text.split(whereSeparator: { character in
        !character.isNumber && character != "."
    }) {
        let parts = token.split(separator: ".")
        guard let first = parts.first, let major = Int(first) else { continue }
        if major == 1, parts.count > 1, let legacyMajor = Int(parts[1]) {
            return legacyMajor
        }
        return major
    }
    return nil
}

func safeFileName(_ value: String) -> String {
    let fallback = "download.bin"
    let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty, raw != "." && raw != ".." else { return fallback }
    let lastComponent = URL(fileURLWithPath: raw).lastPathComponent
    let trimmed = lastComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != "." && trimmed != ".." else { return fallback }
    return trimmed
}

func sanitizedMarkdown(_ value: String) -> String {
    var sanitized = value
    let patterns = [
        #"(?is)<script\b[^>]*>.*?</script>"#,
        #"(?is)<style\b[^>]*>.*?</style>"#,
        #"(?is)<[^>]+>"#
    ]
    for pattern in patterns {
        sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
    return sanitized
}
