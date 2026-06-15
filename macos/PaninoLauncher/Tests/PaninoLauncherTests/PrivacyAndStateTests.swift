#if canImport(XCTest)
import XCTest
@testable import PaninoLauncher

final class PrivacyAndStateTests: XCTestCase {
    @MainActor
    func testCoreEnvironmentSelfTestPasses() {
        XCTAssertEqual(CoreEnvironmentSelfTest.run(), [])
    }
}
#endif
