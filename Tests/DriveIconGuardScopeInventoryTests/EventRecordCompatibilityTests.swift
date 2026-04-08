import DriveIconGuardShared
import Foundation

#if canImport(Testing)
import Testing

@Test
func eventRecordDecodesLegacyPayloadWithoutCategorySeverityOrMessage() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let record = EventRecord(
        timestamp: Date(timeIntervalSince1970: 1_711_273_600),
        processSignature: ProcessSignature(
            bundleID: "com.richardgeorgedavis.google-drive-icon-guard",
            executablePath: "/Applications/Google Drive Icon Guard.app/Contents/MacOS/Google Drive Icon Guard",
            displayName: "Google Drive Icon Guard",
            isGoogleDriveRelated: false
        ),
        targetPath: "/Users/test/Library/CloudStorage/GoogleDrive/Icon\r",
        artefactType: .iconFile,
        decision: .auditOnly,
        aggregatedCount: 1,
        rawEventType: "helper_install_failed",
        message: "bootstrap failed",
        category: .helper,
        severity: .error
    )

    var payload = try JSONSerialization.jsonObject(with: encoder.encode(record)) as? [String: Any]
    payload?.removeValue(forKey: "message")
    payload?.removeValue(forKey: "category")
    payload?.removeValue(forKey: "severity")

    let legacyData = try JSONSerialization.data(withJSONObject: payload ?? [:], options: [.sortedKeys])
    let decoded = try decoder.decode(EventRecord.self, from: legacyData)

    #expect(decoded.rawEventType == "helper_install_failed")
    #expect(decoded.message == nil)
    #expect(decoded.category == .helper)
    #expect(decoded.severity == .error)
}

#elseif canImport(XCTest)
import XCTest

final class EventRecordCompatibilityTests: XCTestCase {
    func testEventRecordDecodesLegacyPayloadWithoutCategorySeverityOrMessage() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let record = EventRecord(
            timestamp: Date(timeIntervalSince1970: 1_711_273_600),
            processSignature: ProcessSignature(
                bundleID: "com.richardgeorgedavis.google-drive-icon-guard",
                executablePath: "/Applications/Google Drive Icon Guard.app/Contents/MacOS/Google Drive Icon Guard",
                displayName: "Google Drive Icon Guard",
                isGoogleDriveRelated: false
            ),
            targetPath: "/Users/test/Library/CloudStorage/GoogleDrive/Icon\r",
            artefactType: .iconFile,
            decision: .auditOnly,
            aggregatedCount: 1,
            rawEventType: "helper_install_failed",
            message: "bootstrap failed",
            category: .helper,
            severity: .error
        )

        var payload = try JSONSerialization.jsonObject(with: encoder.encode(record)) as? [String: Any]
        payload?.removeValue(forKey: "message")
        payload?.removeValue(forKey: "category")
        payload?.removeValue(forKey: "severity")

        let legacyData = try JSONSerialization.data(withJSONObject: payload ?? [:], options: [.sortedKeys])
        let decoded = try decoder.decode(EventRecord.self, from: legacyData)

        XCTAssertEqual(decoded.rawEventType, "helper_install_failed")
        XCTAssertNil(decoded.message)
        XCTAssertEqual(decoded.category, .helper)
        XCTAssertEqual(decoded.severity, .error)
    }
}
#endif
