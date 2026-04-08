import Foundation
import DriveIconGuardShared

public struct GoogleDriveProcessClassifier {
    private let trustedSigningMarkers = [
        "eqhxz8m8av",      // Google LLC Team ID
        "com.google."
    ]

    public init() {}

    public func isGoogleDriveRelated(_ process: ProcessSignature) -> Bool {
        if process.isGoogleDriveRelated {
            return true
        }

        if let signingIdentity = process.signingIdentity?.lowercased(),
           trustedSigningMarkers.contains(where: { signingIdentity.contains($0) }) {
            return true
        }

        if let bundleID = process.bundleID?.lowercased(),
           bundleID.hasPrefix("com.google.drive") || bundleID == "com.google.drivefs" {
            return true
        }

        let haystacks = [
            process.bundleID?.lowercased(),
            process.executablePath.lowercased(),
            process.displayName.lowercased()
        ].compactMap { $0 }

        return haystacks.contains { value in
            value.contains("google drive") || value.contains("googledrive") || value.contains("drivefs")
        }
    }
}
