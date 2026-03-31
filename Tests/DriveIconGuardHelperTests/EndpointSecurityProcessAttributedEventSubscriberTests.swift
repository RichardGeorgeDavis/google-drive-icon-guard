#if canImport(Testing)
import DriveIconGuardHelper
import DriveIconGuardIPC
import Foundation
import Testing

@Test
func endpointSecuritySubscriberReportsStructuredStatus() {
    let subscriber = EndpointSecurityProcessAttributedEventSubscriber()

    #expect(subscriber.status.state == .needsApproval || subscriber.status.state == .unavailable)
    #expect(subscriber.status.detail.isEmpty == false)
}
#elseif canImport(XCTest)
import DriveIconGuardHelper
import DriveIconGuardIPC
import Foundation
import XCTest

final class EndpointSecurityProcessAttributedEventSubscriberTests: XCTestCase {
    func testEndpointSecuritySubscriberReportsStructuredStatus() {
        let subscriber = EndpointSecurityProcessAttributedEventSubscriber()

        XCTAssertTrue(subscriber.status.state == .needsApproval || subscriber.status.state == .unavailable)
        XCTAssertFalse(subscriber.status.detail.isEmpty)
    }
}
#endif
