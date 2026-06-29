#if canImport(XCTest)
import XCTest
@testable import PaninoLauncher

final class CoreProcessPrivacyTests: XCTestCase {
    @MainActor
    func testCoreEnvironmentSuite() {
        XCTAssertEqual(CoreEnvironmentSelfTest.run(), [])
    }

    @MainActor
    func testCoreProcessPrivacySuite() {
        XCTAssertLauncherSelfTestSuite(LauncherLogicSelfTest.runCoreProcessPrivacyTests)
    }
}
#endif
