import Foundation
import DriveIconGuardIPC

public struct ProtectionInstallationStatusResolver {
    public let helperHostLocator: ProtectionHelperHostLocator
    public let installerResourceLocator: ProtectionInstallerResourceLocator
    public let installationReceiptLocator: ProtectionInstallationReceiptLocator

    public init(
        helperHostLocator: ProtectionHelperHostLocator = ProtectionHelperHostLocator(),
        installerResourceLocator: ProtectionInstallerResourceLocator = ProtectionInstallerResourceLocator(),
        installationReceiptLocator: ProtectionInstallationReceiptLocator = ProtectionInstallationReceiptLocator()
    ) {
        self.helperHostLocator = helperHostLocator
        self.installerResourceLocator = installerResourceLocator
        self.installationReceiptLocator = installationReceiptLocator
    }

    public var helperExecutablePath: String? {
        helperHostLocator.locate()?.path
    }

    public func resolve() -> ProtectionInstallationStatus {
        resolve(helperPath: helperExecutablePath)
    }

    public func resolve(helperPath: String?) -> ProtectionInstallationStatus {
        switch installationReceiptLocator.loadReceipt() {
        case .loaded(let receipt):
            return validatedInstallationStatus(from: receipt, helperPath: helperPath)
        case .invalidFormat(let detail):
            return ProtectionInstallationStatus(
                state: .error,
                detail: detail
            )
        case .unavailable:
            break
        }

        guard helperPath != nil else {
            return ProtectionInstallationStatus(
                state: .unavailable,
                detail: "No standalone helper host is bundled, so there is nothing to install yet."
            )
        }

        if let installResources = installerResourceLocator.locateServiceRegistrationDirectory() {
            return ProtectionInstallationStatus(
                state: .installPlanReady,
                detail: "Helper installation resources are packaged at \(installResources.path), but the actual install/registration flow is not implemented yet."
            )
        }

        return ProtectionInstallationStatus(
            state: .bundledOnly,
            detail: "A helper host is bundled, but no installation resources were found for service registration or system extension setup."
        )
    }

    private func validatedInstallationStatus(
        from receipt: ProtectionInstallationReceipt,
        helperPath: String?
    ) -> ProtectionInstallationStatus {
        switch receipt.state {
        case .installed:
            guard let helperPath else {
                return ProtectionInstallationStatus(
                    state: .error,
                    detail: "Installation receipt reports installed, but no bundled helper executable could be located."
                )
            }

            if let recordedHelperPath = receipt.helperExecutablePath,
               recordedHelperPath != helperPath {
                return ProtectionInstallationStatus(
                    state: .error,
                    detail: "Installation receipt helper path \(recordedHelperPath) does not match the currently located helper at \(helperPath)."
                )
            }

            return ProtectionInstallationStatus(
                state: .installed,
                detail: receipt.detail
            )
        case .error:
            return ProtectionInstallationStatus(
                state: .error,
                detail: receipt.detail
            )
        case .unavailable, .bundledOnly, .installPlanReady:
            return ProtectionInstallationStatus(
                state: receipt.state,
                detail: receipt.detail
            )
        }
    }
}
