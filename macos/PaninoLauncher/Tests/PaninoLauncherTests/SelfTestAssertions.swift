#if canImport(XCTest)
import XCTest
@testable import PaninoLauncher

@MainActor
func XCTAssertLauncherSelfTestSuite(
    _ runSuite: (inout [String]) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    var failures: [String] = []
    runSuite(&failures)
    XCTAssertEqual(failures, [], file: file, line: line)
}
#endif
