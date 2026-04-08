import XCTest
@testable import lumoshell_appearance_sync_agent

final class LumoshellAppearanceSyncAgentTests: XCTestCase {
    func testResolveExecutablePathWithAbsolutePath() {
        let resolved = resolveExecutablePath("/bin/sh")
        XCTAssertEqual(resolved, "/bin/sh")
    }

    func testResolveExecutablePathFindsCommandOnPath() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumoshell-appearance-sync-agent-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let toolPath = tempDir.appendingPathComponent("fake-apply")
        try "#!/usr/bin/env bash\nexit 0\n".write(to: toolPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: toolPath.path
        )

        let originalPath = String(cString: getenv("PATH"))
        setenv("PATH", "\(tempDir.path):\(originalPath)", 1)
        defer { setenv("PATH", originalPath, 1) }

        let resolved = resolveExecutablePath("fake-apply")
        XCTAssertEqual(resolved, toolPath.path)
    }

    func testParseArgsAcceptsApplyCommandAndQuiet() {
        let config = parseArgs(arguments: ["--apply-cmd", "/bin/sh", "--quiet"])
        XCTAssertEqual(config.applyCommand, "/bin/sh")
        XCTAssertTrue(config.quiet)
    }
}
