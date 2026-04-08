#if canImport(Testing)
import DriveIconGuardXPCClient
import Foundation
import Testing

@Test
func statusQueriesRequireAuditTokenButNotTrustedBundleIdentity() {
    let authorizer = ProtectionServiceAuthorizer()

    let result = authorizer.authorize(
        command: .queryStatus,
        context: ProtectionServiceAuthorizationContext(
            callerBundleID: "com.example.other",
            hasAuditToken: true
        )
    )

    #expect(result.isAuthorized)
}

@Test
func highRiskCommandsRejectMissingAuditToken() {
    let authorizer = ProtectionServiceAuthorizer()

    let result = authorizer.authorize(
        command: .updateConfiguration,
        context: ProtectionServiceAuthorizationContext(
            callerBundleID: "com.richardgeorgedavis.google-drive-icon-guard",
            hasAuditToken: false
        )
    )

    #expect(result.isAuthorized == false)
    #expect(result.failureReason == .missingAuditToken)
}

@Test
func highRiskCommandsRequireTrustedCallerIdentity() {
    let authorizer = ProtectionServiceAuthorizer()

    let result = authorizer.authorize(
        command: .startProtection,
        context: ProtectionServiceAuthorizationContext(
            callerBundleID: "com.example.other",
            hasAuditToken: true
        )
    )

    #expect(result.isAuthorized == false)
    #expect(result.failureReason == .callerIdentityUntrusted)
}

@Test
func highRiskCommandsAllowTrustedBundleIdentity() {
    let authorizer = ProtectionServiceAuthorizer()

    let result = authorizer.authorize(
        command: .evaluateNow,
        context: ProtectionServiceAuthorizationContext(
            callerBundleID: "com.richardgeorgedavis.google-drive-icon-guard",
            hasAuditToken: true
        )
    )

    #expect(result.isAuthorized)
}
#elseif canImport(XCTest)
import DriveIconGuardXPCClient
import Foundation
import XCTest

final class ProtectionServiceAuthorizerTests: XCTestCase {
    func testStatusQueriesRequireAuditTokenButNotTrustedBundleIdentity() {
        let authorizer = ProtectionServiceAuthorizer()

        let result = authorizer.authorize(
            command: .queryStatus,
            context: ProtectionServiceAuthorizationContext(
                callerBundleID: "com.example.other",
                hasAuditToken: true
            )
        )

        XCTAssertTrue(result.isAuthorized)
    }

    func testHighRiskCommandsRejectMissingAuditToken() {
        let authorizer = ProtectionServiceAuthorizer()

        let result = authorizer.authorize(
            command: .updateConfiguration,
            context: ProtectionServiceAuthorizationContext(
                callerBundleID: "com.richardgeorgedavis.google-drive-icon-guard",
                hasAuditToken: false
            )
        )

        XCTAssertFalse(result.isAuthorized)
        XCTAssertEqual(result.failureReason, .missingAuditToken)
    }

    func testHighRiskCommandsRequireTrustedCallerIdentity() {
        let authorizer = ProtectionServiceAuthorizer()

        let result = authorizer.authorize(
            command: .startProtection,
            context: ProtectionServiceAuthorizationContext(
                callerBundleID: "com.example.other",
                hasAuditToken: true
            )
        )

        XCTAssertFalse(result.isAuthorized)
        XCTAssertEqual(result.failureReason, .callerIdentityUntrusted)
    }

    func testHighRiskCommandsAllowTrustedBundleIdentity() {
        let authorizer = ProtectionServiceAuthorizer()

        let result = authorizer.authorize(
            command: .evaluateNow,
            context: ProtectionServiceAuthorizationContext(
                callerBundleID: "com.richardgeorgedavis.google-drive-icon-guard",
                hasAuditToken: true
            )
        )

        XCTAssertTrue(result.isAuthorized)
    }
}
#endif
