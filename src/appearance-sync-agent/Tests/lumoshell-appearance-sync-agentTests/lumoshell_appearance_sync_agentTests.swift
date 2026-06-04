import XCTest
@testable import lumoshell_appearance_sync_agent

final class LumoshellAppearanceSyncAgentTests: XCTestCase {


    func testParseArgsAcceptsApplyCommandAndQuiet() {
        let config = parseArgs(arguments: ["--apply-cmd", "/bin/sh", "--quiet"])
        XCTAssertEqual(config.applyCommand, "/bin/sh")
        XCTAssertTrue(config.quiet)
    }

    func testParseArgsAcceptsLogFile() {
        let config = parseArgs(arguments: ["--log-file", "~/tmp/lumoshell.log"])
        XCTAssertTrue(config.logFile.hasSuffix("/tmp/lumoshell.log"))
    }


}
