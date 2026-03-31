import Foundation
import DriveIconGuardIPC

#if os(macOS) && canImport(EndpointSecurity)
import EndpointSecurity
#endif

public final class EndpointSecurityProcessAttributedEventSubscriber: ProcessAttributedEventSubscriber, @unchecked Sendable {
    public private(set) var status: ProtectionEventSourceStatus

    public init() {
        #if os(macOS) && canImport(EndpointSecurity)
        status = ProtectionEventSourceStatus(
            state: .needsApproval,
            detail: "Endpoint Security support is compiled into this build, but live monitoring still needs the Apple-granted entitlement, system extension install path, and user approval flow."
        )
        #else
        status = ProtectionEventSourceStatus(
            state: .unavailable,
            detail: "The Endpoint Security framework is unavailable in this build environment, so live process-attributed monitoring cannot start."
        )
        #endif
    }

    public func start(eventHandler: @escaping @Sendable (ProcessAttributedFileEvent) -> Void) {
        #if os(macOS) && canImport(EndpointSecurity)
        status = ProtectionEventSourceStatus(
            state: .needsApproval,
            detail: "Endpoint Security subscriber skeleton is present, but the system extension registration, entitlement approval, and live event subscription path are not implemented yet."
        )
        #else
        status = ProtectionEventSourceStatus(
            state: .unavailable,
            detail: "Endpoint Security monitoring cannot start because the framework is unavailable in this build environment."
        )
        #endif
    }

    public func stop() {
        #if os(macOS) && canImport(EndpointSecurity)
        status = ProtectionEventSourceStatus(
            state: .bundled,
            detail: "Endpoint Security subscriber skeleton is bundled but idle. Live monitoring still requires the install and approval path."
        )
        #else
        status = ProtectionEventSourceStatus(
            state: .unavailable,
            detail: "Endpoint Security monitoring remains unavailable in this build environment."
        )
        #endif
    }
}
