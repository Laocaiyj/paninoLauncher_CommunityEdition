#if canImport(XCTest)
import XCTest
@testable import PaninoLauncher

final class DiagnosticsRedactionTests: XCTestCase {
    @MainActor
    func testDiagnosticRedactionSuite() {
        XCTAssertLauncherSelfTestSuite(LauncherLogicSelfTest.runDiagnosticsRedactionTests)
    }

    @MainActor
    func testDiagnosticExportModelSuite() {
        XCTAssertLauncherSelfTestSuite(LauncherLogicSelfTest.runDiagnosticExportModelTests)
    }
}
#endif
