import Darwin
import Foundation

@MainActor
enum LauncherLogicSelfTest {
    static func runAndExit() -> Never {
        let failures = run()
        if failures.isEmpty {
            print("launcher logic self-test ok")
            Darwin.exit(0)
        }

        for failure in failures {
            fputs("launcher logic self-test failed: \(failure)\n", stderr)
        }
        Darwin.exit(1)
    }

    static func run() -> [String] {
        var failures: [String] = []
        runPrivacyAndStateTests(&failures)
        runDiagnosticsRedactionTests(&failures)
        runCoreProcessPrivacyTests(&failures)
        runTaskCenterTests(&failures)
        runFormattingAndFileSafetyTests(&failures)
        runNavigationAndCommandTests(&failures)
        runTaskPersistenceTests(&failures)
        runDiagnosticExportModelTests(&failures)
        return failures
    }

    static func runPrivacyAndStateTests(_ failures: inout [String]) {
        expect(CoreEnvironmentSelfTest.run().isEmpty, "core environment self-test should pass", &failures)
        expect(ThemeSettings.normalizedCustomAccentHex("not-a-color") == "#FF4F5E", "invalid custom accent should fall back", &failures)
        expect(ThemeSettings.normalizedCustomAccentHex("336699") == "#336699", "custom accent should normalize with leading hash", &failures)

        let keys = [
            "Theme.DepthStyle",
            "Theme.QuietModeEnabled",
            "Theme.VisualNoiseReductionEnabled",
            "Theme.SurfaceContrast",
            "Theme.GlassFrosting",
            "Theme.BackgroundBlur",
            "Theme.BackgroundDim"
        ]
        let defaults = UserDefaults.standard
        let oldValues = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
        defer {
            for key in keys {
                if case .some(.some(let oldValue)) = oldValues[key] {
                    defaults.set(oldValue, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        let theme = ThemeSettings()
        theme.quietModeEnabled = false
        theme.visualNoiseReductionEnabled = false
        theme.surfaceContrast = 0.2

        theme.depthStyle = .flat
        let flat = theme.resolvedTokens()
        theme.depthStyle = .soft
        let soft = theme.resolvedTokens()
        theme.depthStyle = .layered
        let layered = theme.resolvedTokens()
        theme.depthStyle = .retro
        let retro = theme.resolvedTokens()

        expect(flat.shadowRadius == 0, "flat depth should have no shadow", &failures)
        expect(soft.shadowRadius > flat.shadowRadius, "soft depth should add shadow", &failures)
        expect(layered.shadowRadius > soft.shadowRadius, "layered depth should increase shadow", &failures)
        expect(soft.depthHighlightOpacity > flat.depthHighlightOpacity, "soft depth should add highlights", &failures)
        expect(layered.depthHighlightOpacity > soft.depthHighlightOpacity, "layered depth should increase highlights", &failures)
        expect(retro.depthHighlightOpacity > layered.depthHighlightOpacity, "retro depth should expose highlights", &failures)
        expect(retro.depthShadeOpacity > layered.depthShadeOpacity, "retro depth should expose shade", &failures)

        theme.glassFrosting = 2
        theme.backgroundBlur = -1
        theme.backgroundDim = 1.5
        theme.surfaceContrast = -0.5
        expect(defaults.double(forKey: "Theme.GlassFrosting") == 1, "glass frosting should clamp high values", &failures)
        expect(defaults.double(forKey: "Theme.BackgroundBlur") == 0, "background blur should clamp low values", &failures)
        expect(defaults.double(forKey: "Theme.BackgroundDim") == 1, "background dim should clamp high values", &failures)
        expect(defaults.double(forKey: "Theme.SurfaceContrast") == 0, "surface contrast should clamp low values", &failures)

        let legacy = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Legacy",
          "iconName": "",
          "coverPath": "",
          "minecraftVersion": "1.21.7",
          "gameDirectory": "/tmp/legacy",
          "javaPath": "",
          "memoryMb": 4096,
          "jvmArguments": "",
          "preLaunchBehavior": "none",
          "group": "Default",
          "isFavorite": false,
          "status": "ready"
        }
        """
        do {
            let instance = try JSONDecoder.panino.decode(GameInstance.self, from: Data(legacy.utf8))
            expect(instance.coverColorHex == GameInstance.defaultCoverColorHex, "legacy instance should decode cover color default", &failures)
            expect(instance.coverFocusX == 0.5, "legacy instance should decode cover focus x default", &failures)
            expect(instance.coverFocusY == 0.5, "legacy instance should decode cover focus y default", &failures)
            expect(instance.coverBlur == 0, "legacy instance should decode cover blur default", &failures)
            expect(instance.coverDim == 0.28, "legacy instance should decode cover dim default", &failures)
            expect(instance.iconBackdropStyle == .automatic, "legacy instance should decode icon backdrop default", &failures)
        } catch {
            failures.append("legacy instance should decode: \(error)")
        }
    }

    static func runDiagnosticsRedactionTests(_ failures: inout [String]) {
        let home = NSHomeDirectory()
        let sample = """
        panino-core serve --session-token session-secret --access-token=access-secret
        Authorization: Bearer bearer-secret
        Proxy-Authorization: Basic basic-secret
        Cookie: session=cookie-secret; other=value
        Set-Cookie: refresh=refresh-secret
        X-Auth-Token: auth-secret
        X-Api-Key: api-secret
        X-Ms-Authorization: ms-secret
        https://example.invalid/file?token=query-secret&sig=sig-secret&AWSAccessKeyId=aws-secret&ok=1
        path \(home)/Library/Application Support/Panino Launcher
        file://\(home)/minecraft
        """
        let redacted = DiagnosticRedactor.redact(sample)
        for secret in [
            "session-secret",
            "access-secret",
            "bearer-secret",
            "basic-secret",
            "cookie-secret",
            "refresh-secret",
            "auth-secret",
            "api-secret",
            "ms-secret",
            "query-secret",
            "sig-secret",
            "aws-secret"
        ] {
            expect(!redacted.contains(secret), "redactor should remove \(secret)", &failures)
        }
        expect(!redacted.contains(home), "redactor should remove home path", &failures)
        expect(redacted.contains("--session-token <redacted>"), "redactor should cover spaced session token args", &failures)
        expect(redacted.contains("--access-token=<redacted>"), "redactor should cover equals access token args", &failures)
        expect(redacted.contains("Authorization:") && redacted.contains("<redacted>"), "redactor should cover bearer headers", &failures)
        expect(redacted.contains("Cookie: <redacted>"), "redactor should cover cookies", &failures)
        expect(redacted.contains("file://~"), "redactor should collapse file home urls", &failures)
        expect(redacted.contains("~/Library/Application Support/Panino Launcher"), "redactor should collapse home paths", &failures)

        let json = """
        {
          "sessionToken": "json-session-secret",
          "headers": {
            "Authorization": "Bearer json-bearer-secret",
            "Cookie": "json-cookie-secret"
          },
          "nested": [
            {
              "client_secret": "json-client-secret",
              "path": "\(home)/Library/Application Support/Panino Launcher"
            }
          ],
          "commandLine": "--session-token cli-secret",
          "public": "keep-me"
        }
        """
        let data = DiagnosticRedactor.redactedData(Data(json.utf8))
        guard let text = String(data: data, encoding: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            failures.append("diagnostic redactor should emit readable JSON")
            return
        }
        for value in ["json-session-secret", "json-bearer-secret", "json-cookie-secret", "json-client-secret", "cli-secret", home] {
            expect(!text.contains(value), "JSON redactor should remove \(value)", &failures)
        }
        expect(object["sessionToken"] as? String == "<redacted>", "JSON redactor should redact sessionToken key", &failures)
        expect(object["public"] as? String == "keep-me", "JSON redactor should keep safe values", &failures)
        let headers = object["headers"] as? [String: Any]
        expect(headers?["Authorization"] as? String == "<redacted>", "JSON redactor should redact Authorization key", &failures)
        expect(headers?["Cookie"] as? String == "<redacted>", "JSON redactor should redact Cookie key", &failures)
        let nested = object["nested"] as? [[String: Any]]
        expect(nested?.first?["client_secret"] as? String == "<redacted>", "JSON redactor should redact nested secrets", &failures)
        expect(nested?.first?["path"] as? String == "~/Library/Application Support/Panino Launcher", "JSON redactor should redact nested paths", &failures)
        expect(object["commandLine"] as? String == "--session-token <redacted>", "JSON redactor should redact command-line strings", &failures)

        let textData = Data("Authorization: Bearer plain-secret".utf8)
        let fallbackText = String(data: DiagnosticRedactor.redactedData(textData), encoding: .utf8) ?? ""
        expect(!fallbackText.contains("plain-secret"), "text fallback should redact secrets", &failures)
        expect(fallbackText.contains("Authorization:") && fallbackText.contains("<redacted>"), "text fallback should preserve redacted header shape", &failures)
        expect(DiagnosticRedactor.canRedact(textData), "redactor should accept UTF-8 text", &failures)

        let binary = Data([0xff, 0xfe, 0xfd, 0x00])
        expect(!DiagnosticRedactor.canRedact(binary), "redactor should reject opaque binary", &failures)
        expect(DiagnosticRedactor.redactedData(binary).isEmpty, "redactor should drop opaque binary data", &failures)

        let log = "GET /?access_token=log-secret\n/Users/example/.minecraft"
        let logRedacted = LogRedactor.redact(log)
        expect(!logRedacted.contains("log-secret"), "log redactor should remove access_token values", &failures)
        expect(!logRedacted.contains("/Users/example"), "log redactor should remove user paths", &failures)
        expect(logRedacted.contains("access_token=<redacted>"), "log redactor should keep query key", &failures)
        expect(logRedacted.contains("~/.minecraft"), "log redactor should collapse path", &failures)
    }

    static func runCoreProcessPrivacyTests(_ failures: inout [String]) {
        let tokenFileURL = URL(fileURLWithPath: "/tmp/panino-core-token")
        let args = CoreProcessManager.coreServeArguments(port: 37123, sessionTokenFileURL: tokenFileURL)
        expect(args.first == "serve", "core args should start with serve", &failures)
        expect(args.contains("--session-token-file"), "core args should use token file flag", &failures)
        expect(args.contains(tokenFileURL.path), "core args should include token file path", &failures)
        expect(!args.contains("--session-token"), "core args should not use raw token flag", &failures)
        expect(!args.contains("secret-token"), "core args should not contain token values", &failures)

        let context = CoreProcessLaunchContext(
            executableURL: URL(fileURLWithPath: "/tmp/panino-core"),
            port: 37123,
            sessionToken: "secret-token-value",
            tokenFileURL: tokenFileURL
        )
        expect(context.endpoint.sessionToken == "secret-token-value", "launch context should keep token in memory", &failures)
        expect(!context.serveArguments.joined(separator: " ").contains("secret-token-value"), "launch args should not contain token", &failures)
        let record = context.managedRecord(pid: 1234, startedAt: Date(timeIntervalSince1970: 0))
        expect(record.schemaVersion == 2, "managed record should use schema 2", &failures)
        expect(record.pid == 1234, "managed record should store pid", &failures)
        expect(record.port == 37123, "managed record should store port", &failures)
        expect(record.executablePath == "/tmp/panino-core", "managed record should store executable path", &failures)

        do {
            let data = try CoreProcessManager.managedCoreRecordDataForSelfTest(
                pid: 123,
                port: 37123,
                executablePath: "/tmp/panino-core",
                startedAt: Date(timeIntervalSince1970: 0)
            )
            let encoded = String(data: data, encoding: .utf8) ?? ""
            expect(!encoded.contains("sessionToken"), "managed record should not persist sessionToken", &failures)
        } catch {
            failures.append("managed record should encode: \(error)")
        }

        let legacy = """
        {
          "pid": 123,
          "port": 37123,
          "sessionToken": "old-secret",
          "executablePath": "/tmp/panino-core",
          "startedAt": "1970-01-01T00:00:00Z"
        }
        """
        expect(CoreProcessManager.canDecodeManagedCoreRecordForSelfTest(Data(legacy.utf8)), "managed record should decode old token-bearing JSON", &failures)

        do {
            let token = "file-secret-token"
            let url = try CoreProcessManager.createSessionTokenFile(token: token)
            defer { CoreProcessManager.removeSessionTokenFile(url) }
            expect((try? String(contentsOf: url, encoding: .utf8)) == token, "token file should contain token", &failures)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
            expect((permissions ?? 0) & 0o777 == 0o600, "token file should be 0600", &failures)
            CoreProcessManager.removeSessionTokenFile(url)
            expect(!FileManager.default.fileExists(atPath: url.path), "token file should be removable", &failures)
        } catch {
            failures.append("session token file should be created with safe permissions: \(error)")
        }
    }

    static func runTaskCenterTests(_ failures: inout [String]) {
        let progress = makeProgress(
            overallPercent: 150,
            etaSeconds: 125,
            currentLabel: "  ",
            completedJobs: 3,
            totalJobs: 5,
            completedBytes: 2_048,
            totalBytes: 4_096
        )
        let summary = TaskCenterProgressFormatter.summary(from: progress)
        expect(summary.fraction == 1, "progress fraction should clamp to one", &failures)
        expect(summary.remainingTime == "2m 5s", "progress ETA should format minutes and seconds", &failures)
        expect(summary.currentLabel == nil, "blank current label should become nil", &failures)
        expect(summary.phaseTitle == "Download", "phase title should flow through", &failures)
        expect(summary.completedJobs == 3, "completed job count should flow through", &failures)
        expect(summary.totalJobs == 5, "total job count should flow through", &failures)
        expect(summary.completedBytes == 2_048, "completed bytes should flow through", &failures)
        expect(summary.totalBytes == 4_096, "total bytes should flow through", &failures)

        let empty = TaskCenterProgressFormatter.summary(from: nil)
        expect(empty.fraction == nil, "missing progress should have no fraction", &failures)
        expect(empty.speed == "-", "missing progress should use speed placeholder", &failures)
        expect(empty.remainingTime == "-", "missing progress should use ETA placeholder", &failures)
        let negative = TaskCenterProgressFormatter.summary(from: makeProgress(overallPercent: -25))
        expect(negative.fraction == 0, "negative progress should clamp to zero", &failures)

        var events: [TaskProgress]?
        for index in 0..<205 {
            events = TaskCenterProgressFormatter.appending(
                events,
                progress: makeProgress(overallPercent: Double(index), currentLabel: "file-\(index)")
            )
        }
        expect(events?.count == 200, "progress history should cap at 200", &failures)
        expect(events?.first?.currentLabel == "file-5", "progress history should drop oldest events", &failures)
        expect(events?.last?.currentLabel == "file-204", "progress history should keep newest event", &failures)
        if let events {
            expect(TaskCenterProgressFormatter.appending(events, progress: events.last) == events, "progress history should deduplicate last event", &failures)
        }

        let succeededSnapshot = makeSnapshot(kind: "launch", state: .succeeded, message: nil, progress: nil)
        let succeeded = TaskCenterRecordFactory.record(from: succeededSnapshot, now: referenceDate)
        expect(succeeded.name == "Launch 1.21.7", "succeeded launch should have display name", &failures)
        expect(succeeded.state == .succeeded, "succeeded snapshot should become succeeded record", &failures)
        expect(succeeded.progress == 1, "succeeded record should force full progress", &failures)
        expect(succeeded.finishedAt != nil, "succeeded record should have finish time", &failures)

        let failedSnapshot = makeSnapshot(
            kind: "install",
            state: .failed,
            message: nil,
            errorCode: "process_launch_failed",
            errorDetail: "process failed"
        )
        let failed = TaskCenterRecordFactory.record(from: failedSnapshot, now: referenceDate)
        expect(failed.errorCode == "install_failed", "install process launch failure should normalize error code", &failures)
        expect(failed.message == "Install failed before Minecraft was ready. Open logs for the Core error detail, then retry.", "install process launch failure should normalize message", &failures)
        expect(failed.errorDetail == "process failed", "install failure should keep detail", &failures)

        let previous = makeRecord(
            id: "task-1",
            kind: "install",
            state: .running,
            progress: 0.25,
            requestedLoader: "fabric",
            requestedShaderLoader: "iris",
            progressEvents: [makeProgress(overallPercent: 25, currentLabel: "old")]
        )
        let running = TaskCenterRecordFactory.record(
            from: makeSnapshot(kind: "install", state: .running, progress: makeProgress(overallPercent: 50, currentLabel: "new")),
            previous: previous,
            now: referenceDate
        )
        expect(running.requestedLoader == "fabric", "record factory should carry previous loader", &failures)
        expect(running.requestedShaderLoader == "iris", "record factory should carry previous shader loader", &failures)
        expect(running.progress == 0.5, "record factory should use current progress", &failures)
        expect(running.progressEvents?.map(\.currentLabel) == ["old", "new"], "record factory should append progress events", &failures)

        let interruptedRecords = TaskCenterHistoryPruner.markMissingCoreTasksInterrupted(
            [
                makeRecord(id: "running", kind: "launch", state: .running),
                makeRecord(id: "local", kind: "local-only", state: .running)
            ],
            coreTaskIDs: []
        )
        expect(interruptedRecords.first(where: { $0.id == "running" })?.state == .interrupted, "missing core-backed task should become interrupted", &failures)
        expect(interruptedRecords.first(where: { $0.id == "local" })?.state == .running, "local task should not become interrupted", &failures)

        let failedInstall = makeRecord(id: "failed-install", kind: "install", gameDir: "/tmp/world", state: .failed, updatedAt: referenceDate)
        let laterLaunch = makeRecord(id: "launch-success", kind: "launch", gameDir: "/tmp/world", state: .succeeded, updatedAt: referenceDate.addingTimeInterval(60))
        expect(TaskCenterHistoryPruner.actionableAttentionRecords(in: [failedInstall, laterLaunch]).isEmpty, "later launch success should supersede install failure", &failures)

        let pruned = TaskCenterHistoryPruner.pruned(
            [
                makeRecord(id: "old-success", kind: "install", state: .succeeded, updatedAt: referenceDate.addingTimeInterval(-40 * 24 * 60 * 60)),
                makeRecord(id: "active", kind: "launch", state: .running, updatedAt: referenceDate),
                makeRecord(id: "failed", kind: "content-install", state: .failed, updatedAt: referenceDate)
            ],
            retentionPolicy: .failuresOnly,
            now: referenceDate
        )
        expect(Set(pruned.map(\.id)) == Set(["active", "failed"]), "failuresOnly retention should keep active and recent attention", &failures)
    }

    static func runFormattingAndFileSafetyTests(_ failures: inout [String]) {
        expect(SafeFileComponent.sanitize(" Minecraft 1.21.7 + Iris ", lowercased: true) == "minecraft-1.21.7-iris", "safe component should sanitize instance names", &failures)
        expect(SafeFileComponent.sanitize("///", fallback: "fallback") == "fallback", "safe component should use fallback for empty names", &failures)
        expect(SafeFileComponent.sanitize("A::B", collapseReplacementRuns: false, trimCharacters: "") == "A--B", "safe component should preserve replacement runs when asked", &failures)

        expect(safeFileName("/tmp/mods/Sodium.jar") == "Sodium.jar", "safe file name should use last path component", &failures)
        expect(safeFileName("../Iris.jar") == "Iris.jar", "safe file name should strip traversal parent", &failures)
        expect(safeFileName("   ") == "download.bin", "safe file name should fallback for blank input", &failures)
        expect(safeFileName(".") == "download.bin", "safe file name should fallback for dot", &failures)
        expect(safeFileName("..") == "download.bin", "safe file name should fallback for dot dot", &failures)

        expect(javaMajorVersion(from: "Java 21 runtime") == 21, "java parser should read modern major", &failures)
        expect(javaMajorVersion(from: "temurin-1.8.0_402") == 8, "java parser should read legacy major", &failures)
        expect(javaMajorVersion(from: "jdk-17.0.11+9") == 17, "java parser should read jdk major", &failures)
        expect(javaMajorVersion(from: "no-version") == nil, "java parser should reject strings without versions", &failures)

        expect(formattedPlayDuration(-30, language: .english) == "0m", "play duration should clamp negative values", &failures)
        expect(formattedPlayDuration(59 * 60, language: .english) == "59m", "play duration should format minutes", &failures)
        expect(formattedPlayDuration(60 * 60, language: .english) == "1h", "play duration should format whole hours", &failures)
        expect(formattedPlayDuration(90 * 60, language: .english) == "1h 30m", "play duration should format hours and minutes", &failures)
        expect(formattedPlayDuration(90 * 60, language: .french) == "1 h 30 min", "play duration should localize French", &failures)

        let raw = """
        # Title
        <script>alert("x")</script>
        <style>body { color: red; }</style>
        <b>Safe text</b>
        """
        let sanitized = sanitizedMarkdown(raw)
        expect(!sanitized.contains("<script"), "markdown sanitizer should remove script tags", &failures)
        expect(!sanitized.contains("alert"), "markdown sanitizer should remove script bodies", &failures)
        expect(!sanitized.contains("<style"), "markdown sanitizer should remove style tags", &failures)
        expect(!sanitized.contains("<b>"), "markdown sanitizer should remove inline html", &failures)
        expect(sanitized.contains("# Title"), "markdown sanitizer should keep markdown text", &failures)
        expect(sanitized.contains("Safe text"), "markdown sanitizer should keep safe text", &failures)
    }

    static func expect(_ condition: Bool, _ message: String, _ failures: inout [String]) {
        if !condition {
            failures.append(message)
        }
    }

    static let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

    static func makeSnapshot(
        taskId: String = "task-1",
        kind: String,
        version: String = "1.21.7",
        gameDir: String? = "/tmp/world",
        requestedLoader: String? = nil,
        requestedShaderLoader: String? = nil,
        state: TaskState,
        message: String? = "working",
        errorCode: String? = nil,
        errorDetail: String? = nil,
        diagnostic: CoreDiagnostic? = nil,
        diagnostics: [CoreDiagnostic] = [],
        progress: TaskProgress? = makeProgress()
    ) -> TaskSnapshot {
        TaskSnapshot(
            taskId: taskId,
            kind: kind,
            version: version,
            gameDir: gameDir,
            requestedLoader: requestedLoader,
            requestedShaderLoader: requestedShaderLoader,
            state: state,
            message: message,
            errorCode: errorCode,
            errorDetail: errorDetail,
            diagnostic: diagnostic,
            diagnostics: diagnostics,
            createdAt: "2026-06-17T16:00:00Z",
            updatedAt: "2026-06-17T16:01:00Z",
            finishedAt: state.isTerminal ? "2026-06-17T16:02:00Z" : nil,
            progress: progress
        )
    }

    static func makeRecord(
        id: String,
        kind: String,
        version: String = "1.21.7",
        gameDir: String? = "/tmp/world",
        state: TaskRecordState,
        progress: Double = 0,
        requestedLoader: String? = nil,
        requestedShaderLoader: String? = nil,
        progressEvents: [TaskProgress]? = nil,
        currentFile: String? = nil,
        errorCode: String? = nil,
        diagnostic: CoreDiagnostic? = nil,
        diagnostics: [CoreDiagnostic]? = nil,
        updatedAt: Date = referenceDate
    ) -> TaskRecord {
        var record = TaskCenterRecordFactory.localRecord(
            id: id,
            kind: kind,
            name: "\(kind) \(version)",
            version: version,
            gameDir: gameDir,
            state: state,
            progress: progress,
            speed: "-",
            remainingTime: "-",
            currentFile: currentFile ?? version,
            errorCode: errorCode ?? (state.needsAttention ? "failed" : nil),
            errorDetail: nil,
            diagnostic: diagnostic,
            diagnostics: diagnostics,
            message: state.rawValue,
            now: updatedAt
        )
        record.requestedLoader = requestedLoader
        record.requestedShaderLoader = requestedShaderLoader
        record.progressEvents = progressEvents
        record.updatedAt = updatedAt
        record.finishedAt = state.isTerminal ? updatedAt : nil
        return record
    }

    static func makeProgress(
        taskId: String = "task-1",
        overallPercent: Double? = 50,
        etaSeconds: Int64? = 30,
        currentLabel: String = "file.jar",
        completedJobs: Int = 1,
        totalJobs: Int = 4,
        completedBytes: Int64 = 1_024,
        totalBytes: Int64 = 2_048
    ) -> TaskProgress {
        TaskProgress(
            taskId: taskId,
            phaseId: "download",
            phaseTitle: "Download",
            phaseIndex: 1,
            phaseCount: 4,
            phasePercent: overallPercent,
            overallPercent: overallPercent,
            completedJobs: completedJobs,
            totalJobs: totalJobs,
            completedBytes: completedBytes,
            totalBytes: totalBytes,
            speedBytesPerSecond: 0,
            movingAverageSpeedBytesPerSecond: nil,
            etaSeconds: etaSeconds,
            currentLabel: currentLabel,
            activeWorkers: 1,
            retryCount: 0,
            sourceHost: "libraries.minecraft.net",
            hosts: nil,
            throttleReason: nil,
            multipart: nil
        )
    }
}
