import Foundation

extension KeyedDecodingContainer {
    func lossyURL(forKey key: Key) -> URL? {
        guard let raw = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        return Self.url(from: raw)
    }

    func lossyURLArray(forKey key: Key) -> [URL] {
        guard let values = try? decodeIfPresent([String].self, forKey: key) else { return [] }
        return values.compactMap(Self.url(from:))
    }

    private static func url(from raw: String?) -> URL? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
