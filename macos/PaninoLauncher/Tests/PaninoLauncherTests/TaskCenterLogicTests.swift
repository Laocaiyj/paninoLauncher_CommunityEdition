#if canImport(XCTest)
import XCTest
@testable import PaninoLauncher

final class TaskCenterLogicTests: XCTestCase {
    @MainActor
    func testTaskCenterFormattingAndRecordFactorySuite() {
        XCTAssertLauncherSelfTestSuite(LauncherLogicSelfTest.runTaskCenterTests)
    }

    @MainActor
    func testTaskHistoryPersistenceAndPruningSuite() {
        XCTAssertLauncherSelfTestSuite(LauncherLogicSelfTest.runTaskPersistenceTests)
    }
}
#endif
