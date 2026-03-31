#if canImport(Testing)
import DriveIconGuardScopeInventory
import Foundation
import Testing

@Test
func detectsCocoaPermissionDeniedErrors() {
    let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)

    #expect(FileAccessGuidance.isPermissionDenied(error))
}

@Test
func usesProtectedFolderMessageForDesktopPaths() {
    let desktopPath = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop/Test Scope")
    let warning = FileAccessGuidance.warning(
        operationCode: "scope_scan_entry_unreadable",
        path: desktopPath,
        error: NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError),
        genericMessage: "generic"
    )

    #expect(warning.code == "scope_scan_entry_unreadable_permission_denied")
    #expect(warning.message.contains("Files and Folders access"))
}
#elseif canImport(XCTest)
import DriveIconGuardScopeInventory
import Foundation
import XCTest

final class FileAccessGuidanceTests: XCTestCase {
    func testDetectsCocoaPermissionDeniedErrors() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)

        XCTAssertTrue(FileAccessGuidance.isPermissionDenied(error))
    }

    func testUsesProtectedFolderMessageForDesktopPaths() {
        let desktopPath = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop/Test Scope")
        let warning = FileAccessGuidance.warning(
            operationCode: "scope_scan_entry_unreadable",
            path: desktopPath,
            error: NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError),
            genericMessage: "generic"
        )

        XCTAssertEqual(warning.code, "scope_scan_entry_unreadable_permission_denied")
        XCTAssertTrue(warning.message.contains("Files and Folders access"))
    }
}
#endif
