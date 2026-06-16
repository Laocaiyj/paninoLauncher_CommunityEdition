#if canImport(XCTest)
import XCTest
@testable import PaninoLauncher

final class PrivacyAndStateTests: XCTestCase {
    @MainActor
    func testCoreEnvironmentSelfTestPasses() {
        XCTAssertEqual(CoreEnvironmentSelfTest.run(), [])
    }

    func testCustomAccentHexNormalizationFallsBackSafely() {
        XCTAssertEqual(ThemeSettings.normalizedCustomAccentHex("not-a-color"), "#FF4F5E")
        XCTAssertEqual(ThemeSettings.normalizedCustomAccentHex("336699"), "#336699")
    }

    @MainActor
    func testDepthStyleSeparatesModernAndRetroEffects() {
        let keys = [
            "Theme.DepthStyle",
            "Theme.QuietModeEnabled",
            "Theme.VisualNoiseReductionEnabled",
            "Theme.SurfaceContrast"
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

        XCTAssertEqual(flat.shadowRadius, 0)
        XCTAssertGreaterThan(soft.shadowRadius, flat.shadowRadius)
        XCTAssertGreaterThan(layered.shadowRadius, soft.shadowRadius)
        XCTAssertEqual(soft.depthHighlightOpacity, 0)
        XCTAssertEqual(layered.depthHighlightOpacity, 0)
        XCTAssertGreaterThan(retro.depthHighlightOpacity, layered.depthHighlightOpacity)
        XCTAssertGreaterThan(retro.depthShadeOpacity, layered.depthShadeOpacity)
    }

    @MainActor
    func testThemeSliderAssignmentsDoNotReenterPublishedDidSet() {
        let keys = [
            "Theme.GlassFrosting",
            "Theme.BackgroundBlur",
            "Theme.BackgroundDim",
            "Theme.SurfaceContrast"
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
        theme.glassFrosting = 2
        theme.backgroundBlur = -1
        theme.backgroundDim = 1.5
        theme.surfaceContrast = -0.5

        XCTAssertEqual(defaults.double(forKey: "Theme.GlassFrosting"), 1)
        XCTAssertEqual(defaults.double(forKey: "Theme.BackgroundBlur"), 0)
        XCTAssertEqual(defaults.double(forKey: "Theme.BackgroundDim"), 1)
        XCTAssertEqual(defaults.double(forKey: "Theme.SurfaceContrast"), 0)
    }

    func testOldInstanceJsonDecodesAppearanceDefaults() throws {
        let json = """
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

        let instance = try JSONDecoder.panino.decode(GameInstance.self, from: Data(json.utf8))
        XCTAssertEqual(instance.coverColorHex, GameInstance.defaultCoverColorHex)
        XCTAssertEqual(instance.coverFocusX, 0.5)
        XCTAssertEqual(instance.coverFocusY, 0.5)
        XCTAssertEqual(instance.coverBlur, 0)
        XCTAssertEqual(instance.coverDim, 0.28)
        XCTAssertEqual(instance.iconBackdropStyle, .automatic)
    }
}
#endif
