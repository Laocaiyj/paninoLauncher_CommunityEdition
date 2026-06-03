import Darwin
import Foundation

@MainActor
enum CoreEnvironmentSelfTest {
    static func runAndExit() -> Never {
        let failures = run()
        if failures.isEmpty {
            print("core-environment self-test ok")
            Darwin.exit(0)
        }

        for failure in failures {
            fputs("core-environment self-test failed: \(failure)\n", stderr)
        }
        Darwin.exit(1)
    }

    static func run() -> [String] {
        var failures: [String] = []

        let noProxy = CoreProcessManager.coreEnvironment(
            baseEnvironment: [:],
            proxyAddress: "",
            source: .official,
            retryCount: 3
        )
        expect(noProxy["http_proxy"] == nil, "no proxy should not export http_proxy", &failures)
        expect(noProxy["PANINO_SOURCE_PROFILE"] == "official", "official profile should be exported", &failures)
        expect(noProxy["PANINO_HTTP_RETRY_COUNT"] == "3", "retry count should be exported", &failures)

        let httpProxy = CoreProcessManager.coreEnvironment(
            baseEnvironment: [:],
            proxyAddress: "http://127.0.0.1:7890",
            source: .official,
            retryCount: 5
        )
        expect(httpProxy["http_proxy"] == "http://127.0.0.1:7890", "HTTP proxy should export http_proxy", &failures)
        expect(httpProxy["https_proxy"] == "http://127.0.0.1:7890", "HTTP proxy should export https_proxy", &failures)
        expect(httpProxy["all_proxy"] == "http://127.0.0.1:7890", "HTTP proxy should export all_proxy", &failures)
        expect(httpProxy["no_proxy"] == "127.0.0.1,localhost,::1", "HTTP proxy should add loopback no_proxy", &failures)
        expect(httpProxy["PANINO_HTTP_RETRY_COUNT"] == "5", "custom retry count should be exported", &failures)

        let httpsProxy = CoreProcessManager.coreEnvironment(
            baseEnvironment: ["no_proxy": "example.test"],
            proxyAddress: "https://proxy.example:8443",
            source: .bmclapi,
            retryCount: 1
        )
        expect(httpsProxy["https_proxy"] == "https://proxy.example:8443", "HTTPS proxy should export https_proxy", &failures)
        expect(httpsProxy["PANINO_SOURCE_PROFILE"] == "bmclapi", "BMCLAPI profile should be exported", &failures)
        expect(httpsProxy["PANINO_MOJANG_META_BASE"] == "https://bmclapi2.bangbang93.com", "BMCLAPI Mojang metadata base should be exported", &failures)
        expect(httpsProxy["no_proxy"] == "example.test,127.0.0.1,localhost,::1", "HTTPS proxy should preserve existing no_proxy", &failures)

        let invalidProxy = CoreProcessManager.coreEnvironment(
            baseEnvironment: [:],
            proxyAddress: "ftp://proxy.example:21",
            source: .official,
            retryCount: 3
        )
        expect(invalidProxy["http_proxy"] == nil, "invalid proxy should not export http_proxy", &failures)
        expect(invalidProxy["https_proxy"] == nil, "invalid proxy should not export https_proxy", &failures)
        expect(invalidProxy["all_proxy"] == nil, "invalid proxy should not export all_proxy", &failures)

        let tokenFileURL = URL(fileURLWithPath: "/tmp/panino-core-token")
        let serveArguments = CoreProcessManager.coreServeArguments(port: 37123, sessionTokenFileURL: tokenFileURL)
        expect(serveArguments.contains("--session-token-file"), "Core serve args should use token file flag", &failures)
        expect(!serveArguments.contains("--session-token"), "Core serve args should not include raw token flag", &failures)
        expect(!serveArguments.contains("secret-token"), "Core serve args should not contain token value", &failures)

        if let recordData = try? CoreProcessManager.managedCoreRecordDataForSelfTest(
            pid: 123,
            port: 37123,
            executablePath: "/tmp/panino-core",
            startedAt: Date(timeIntervalSince1970: 0)
        ),
           let recordText = String(data: recordData, encoding: .utf8) {
            expect(!recordText.contains("sessionToken"), "managed Core record should not persist sessionToken", &failures)
        } else {
            failures.append("managed Core record should encode for privacy self-test")
        }
        let oldRecord = """
        {"pid":123,"port":37123,"sessionToken":"old-secret","executablePath":"/tmp/panino-core","startedAt":"1970-01-01T00:00:00Z"}
        """
        expect(
            CoreProcessManager.canDecodeManagedCoreRecordForSelfTest(Data(oldRecord.utf8)),
            "managed Core record should decode old records with ignored sessionToken",
            &failures
        )

        let redacted = LogRedactor.redact(
            """
            --session-token secret-token --session-token=other-secret
            Authorization: Basic abc123
            Cookie: sid=secret
            {"sessionToken":"json-secret","path":"/Users/sen/Library/Application Support/Panino Launcher"}
            https://example.test/download?client_secret=url-secret&sig=abc
            """
        )
        expect(!redacted.contains("secret-token"), "redactor should hide --session-token value", &failures)
        expect(!redacted.contains("other-secret"), "redactor should hide --session-token=value", &failures)
        expect(!redacted.contains("abc123"), "redactor should hide Authorization Basic value", &failures)
        expect(!redacted.contains("sid=secret"), "redactor should hide Cookie value", &failures)
        expect(!redacted.contains("json-secret"), "redactor should hide JSON sessionToken value", &failures)
        expect(!redacted.contains("/Users/sen"), "redactor should hide local user path", &failures)
        expect(!redacted.contains("url-secret"), "redactor should hide sensitive URL query values", &failures)

        return failures
    }

    private static func expect(_ condition: Bool, _ message: String, _ failures: inout [String]) {
        if !condition {
            failures.append(message)
        }
    }
}
