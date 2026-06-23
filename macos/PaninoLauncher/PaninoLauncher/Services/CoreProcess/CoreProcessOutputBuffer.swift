import Foundation

struct CoreProcessOutputBuffer {
    private var pending = ""

    mutating func append(_ text: String) -> [String] {
        pending += text
        let parts = pending.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        guard !parts.isEmpty else { return [] }

        let endedWithNewline = pending.last?.isNewline == true
        let completeLines = endedWithNewline ? parts : parts.dropLast()
        pending = endedWithNewline ? "" : String(parts.last ?? "")
        return completeLines.map(String.init).filter { !$0.isEmpty }
    }

    mutating func flush() -> String? {
        let value = pending.trimmingCharacters(in: .newlines)
        pending = ""
        return value.isEmpty ? nil : value
    }

    mutating func reset() {
        pending = ""
    }
}
