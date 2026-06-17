import Darwin
import Foundation

@MainActor
enum GraphicsTuningSelfTest {
    static func runAndExit() -> Never {
        let failures = run()
        if failures.isEmpty {
            print("graphics-tuning ui self-test ok")
            Darwin.exit(0)
        }

        for failure in failures {
            fputs("graphics-tuning ui self-test failed: \(failure)\n", stderr)
        }
        Darwin.exit(1)
    }

    static func run() -> [String] {
        var failures: [String] = []

        expect(
            GraphicsTuningUIContract.primaryProfiles == [.balanced, .performance],
            "primary UI should expose only automatic and smoother profiles",
            &failures
        )
        expect(
            !GraphicsTuningUIContract.primaryProfiles.contains(.manual),
            "manual profile should stay out of the first-level segmented control",
            &failures
        )
        expect(
            GraphicsTuningUIContract.advancedOptionKeys == [
                "renderDistance",
                "simulationDistance",
                "maxFps",
                "enableVsync",
                "renderClouds",
                "particles",
                "entityDistanceScaling",
                "mipmapLevels"
            ],
            "advanced graphics keys should remain in the folded advanced area",
            &failures
        )
        expect(
            InstanceGraphicsProfile.balanced.title(language: .chineseSimplified) == "自动推荐",
            "balanced graphics profile should read as automatic recommendation",
            &failures
        )
        expect(
            PaninoWorkspaceWidthClass(width: 900) == .compact,
            "workspace should collapse to a single column at 900px",
            &failures
        )
        expect(
            PaninoWorkspaceWidthClass(width: 1280) == .regular,
            "workspace should use the regular two-column layout at 1280px",
            &failures
        )
        expect(
            PaninoWorkspaceWidthClass(width: 1600) == .wide,
            "workspace should expose the wide inspector layout at 1600px",
            &failures
        )
        expect(
            PaninoWorkspaceMetrics(availableWidth: 900).contentWidth >= 640,
            "compact workspace content width should remain usable",
            &failures
        )
        expect(
            PaninoWorkspaceMetrics(availableWidth: 2000).contentWidth >= PaninoWorkspaceMetrics(availableWidth: 1600).contentWidth,
            "wide workspace content width should not shrink as the window grows",
            &failures
        )

        let request = CoreGraphicsTuningRequest(
            gameDir: "/tmp/panino-graphics",
            minecraftVersion: "1.21.5",
            loader: "fabric",
            requestedProfile: InstanceGraphicsProfile.manual.rawValue,
            manualOverrides: ["renderDistance": "11", "maxFps": "75"],
            dryRun: true
        )
        guard let data = try? JSONEncoder.panino.encode(request),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            failures.append("graphics tuning request should encode")
            return failures
        }
        let overrides = object["manualOverrides"] as? [String: String]
        expect(overrides?["renderDistance"] == "11", "advanced render distance override should encode", &failures)
        expect(overrides?["maxFps"] == "75", "advanced FPS override should encode", &failures)
        expect(object["dryRun"] as? Bool == true, "UI resolve requests should support dry-run", &failures)

        return failures
    }

    private static func expect(_ condition: Bool, _ message: String, _ failures: inout [String]) {
        if !condition {
            failures.append(message)
        }
    }
}
