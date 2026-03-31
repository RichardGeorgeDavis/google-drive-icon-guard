import Darwin
import Foundation

public enum FileAccessGuidance {
    public static func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileReadNoPermissionError || nsError.code == NSFileWriteNoPermissionError {
            return true
        }

        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == EACCES || nsError.code == EPERM {
            return true
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isPermissionDenied(underlyingError)
        }

        return false
    }

    public static func warning(
        operationCode: String,
        path: String,
        error: Error,
        genericMessage: String
    ) -> DiscoveryWarning {
        if isPermissionDenied(error) {
            return DiscoveryWarning(
                code: operationCode + "_permission_denied",
                message: permissionDeniedMessage(for: path)
            )
        }

        return DiscoveryWarning(
            code: operationCode,
            message: genericMessage
        )
    }

    public static func permissionDeniedMessage(for path: String) -> String {
        let normalizedPath = NSString(string: path).expandingTildeInPath
        let homeDirectory = NSHomeDirectory()

        let desktopPath = (homeDirectory as NSString).appendingPathComponent("Desktop")
        let documentsPath = (homeDirectory as NSString).appendingPathComponent("Documents")
        let downloadsPath = (homeDirectory as NSString).appendingPathComponent("Downloads")

        if normalizedPath.hasPrefix(desktopPath) || normalizedPath.hasPrefix(documentsPath) || normalizedPath.hasPrefix(downloadsPath) {
            return "macOS denied access to \(normalizedPath). This scope may need Files and Folders access for Desktop, Documents, or Downloads in System Settings > Privacy & Security. Full Disk Access is only recommended if you want broad unattended scanning across multiple protected folders."
        }

        if normalizedPath.contains("/Library/Application Support/Google/DriveFS") || normalizedPath.contains("/Library/CloudStorage") {
            return "macOS denied access to \(normalizedPath). This blocks Google Drive discovery or audit data in a protected library location. Full Disk Access may be required for reliable scanning if macOS keeps denying these paths."
        }

        return "macOS denied access to \(normalizedPath). Grant access to this folder or use Full Disk Access if you want the app to scan protected locations without manual intervention."
    }
}
