import Foundation

enum SafeFileComponent {
    static func sanitize(
        _ value: String,
        allowedExtraCharacters: String = "-_.",
        fallback: String = "instance",
        lowercased: Bool = false,
        collapseReplacementRuns: Bool = true,
        trimCharacters: String = "-",
        returnsTrimmedValue: Bool = true
    ) -> String {
        let source = lowercased ? value.lowercased() : value
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: allowedExtraCharacters))
        var result = ""
        for scalar in source.unicodeScalars {
            if allowed.contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !collapseReplacementRuns || !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: trimCharacters))
        return trimmed.isEmpty ? fallback : (returnsTrimmedValue ? trimmed : result)
    }
}
