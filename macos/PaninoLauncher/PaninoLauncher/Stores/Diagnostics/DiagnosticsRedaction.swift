import Foundation

enum DiagnosticRedactor {
    static func redact(_ text: String) -> String {
        var redacted = text
        let patterns = [
            #"(?i)(--session-token(?:=|\s+))\S+"#,
            #"(?i)(--access-token(?:=|\s+))\S+"#,
            #"(?i)(--accessToken(?:=|\s+))\S+"#,
            #"(?i)((?:Authorization|Proxy-Authorization)\s*:\s*(?:Bearer|Basic)\s+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(Bearer\s+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(Basic\s+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)([?&](?:token|access_token|refresh_token|client_secret|signature|sig|X-Amz-Signature|AWSAccessKeyId)=)[^&\s]+"#,
            #"(?i)(access[_-]?token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(refresh[_-]?token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(id[_-]?token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(session[_-]?token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(client[_-]?secret["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(api[_-]?key["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(x-api-key["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(x-auth-token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(x-ms-[A-Za-z0-9_-]+["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(authorization["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(cookie["':=\s]+)[^"',\n}]+"#,
            #"(?i)(set-cookie["':=\s]+)[^"',\n}]+"#
        ]

        for pattern in patterns {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: "$1<redacted>",
                options: .regularExpression
            )
        }
        return redactLocalPaths(redacted)
    }

    static func redactedData(_ data: Data) -> Data {
        if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            let sanitized = sanitizeJSONValue(object)
            if JSONSerialization.isValidJSONObject(sanitized),
               let jsonData = try? JSONSerialization.data(withJSONObject: sanitized, options: [.prettyPrinted, .sortedKeys]) {
                return jsonData
            }
        }
        if let text = String(data: data, encoding: .utf8) {
            return Data(redact(text).utf8)
        }
        return Data()
    }

    static func canRedact(_ data: Data) -> Bool {
        if (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
            return true
        }
        return String(data: data, encoding: .utf8) != nil
    }

    private static func sanitizeJSONValue(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var sanitized: [String: Any] = [:]
            for (key, child) in dictionary {
                sanitized[key] = isSensitiveKey(key) ? "<redacted>" : sanitizeJSONValue(child)
            }
            return sanitized
        }
        if let array = value as? [Any] {
            return array.map(sanitizeJSONValue)
        }
        if let string = value as? String {
            return redact(string)
        }
        return value
    }

    private static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased().replacingOccurrences(of: #"[^a-z0-9]"#, with: "", options: .regularExpression)
        if normalized.contains("token")
            || normalized.contains("secret")
            || normalized.contains("apikey")
            || normalized.contains("authorization")
            || normalized.contains("cookie")
            || normalized.contains("signature")
            || normalized == "sig"
            || normalized == "awsaccesskeyid" {
            return true
        }
        return normalized.hasPrefix("xms") || normalized == "xauthtoken" || normalized == "xapikey"
    }

    private static func redactLocalPaths(_ text: String) -> String {
        var redacted = text
        let home = NSHomeDirectory()
        if !home.isEmpty {
            redacted = redacted.replacingOccurrences(of: "file://\(home)", with: "file://~")
            redacted = redacted.replacingOccurrences(of: home, with: "~")
        }
        redacted = redacted.replacingOccurrences(
            of: #"file:///Users/[^/\s"']+"#,
            with: "file://~",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"/Users/[^/\s"']+"#,
            with: "~",
            options: .regularExpression
        )
        return redacted
    }
}

enum LogRedactor {
    static func redact(_ text: String) -> String {
        DiagnosticRedactor.redact(text)
    }
}
