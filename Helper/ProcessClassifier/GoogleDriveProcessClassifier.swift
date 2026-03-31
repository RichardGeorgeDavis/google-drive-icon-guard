import Foundation
import DriveIconGuardShared

public struct GoogleDriveProcessClassifier {
    public init() {}

    public func isGoogleDriveRelated(_ process: ProcessSignature) -> Bool {
        if process.isGoogleDriveRelated {
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
