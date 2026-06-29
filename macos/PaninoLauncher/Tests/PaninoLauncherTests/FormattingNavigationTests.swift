#if canImport(XCTest)
import XCTest
@testable import PaninoLauncher

final class FormattingNavigationTests: XCTestCase {
    @MainActor
    func testPrivacyThemeAndStateSuite() {
        XCTAssertLauncherSelfTestSuite(LauncherLogicSelfTest.runPrivacyAndStateTests)
    }

    @MainActor
    func testFormattingAndFileSafetySuite() {
        XCTAssertLauncherSelfTestSuite(LauncherLogicSelfTest.runFormattingAndFileSafetyTests)
    }

    @MainActor
    func testNavigationAndCommandSuite() {
        XCTAssertLauncherSelfTestSuite(LauncherLogicSelfTest.runNavigationAndCommandTests)
    }
}
#endif
