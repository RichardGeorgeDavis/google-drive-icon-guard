import Darwin
import Foundation
import DriveIconGuardShared

public struct VolumeClassifier {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func classify(path: String) -> VolumeClassification {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let canonicalPath = nearestExistingPath(for: expandedPath)
        let fileSystemKind = detectFileSystemKind(for: canonicalPath)

        if canonicalPath.hasPrefix(NSHomeDirectory() + "/Library/CloudStorage") {
            return VolumeClassification(volumeKind: .systemManaged, fileSystemKind: fileSystemKind)
        }

        if canonicalPath.hasPrefix("/System/Volumes") {
            return VolumeClassification(volumeKind: .systemManaged, fileSystemKind: fileSystemKind)
        }

        if canonicalPath.hasPrefix("/Volumes/") {
            if fileSystemKind == .smb {
                return VolumeClassification(volumeKind: .network, fileSystemKind: fileSystemKind)
            }

            return VolumeClassification(volumeKind: .external, fileSystemKind: fileSystemKind)
        }

        if fileSystemKind == .smb {
            return VolumeClassification(volumeKind: .network, fileSystemKind: fileSystemKind)
        }

        return VolumeClassification(volumeKind: .internalVolume, fileSystemKind: fileSystemKind)
    }

    private func nearestExistingPath(for path: String) -> String {
        var currentPath = path

        while !fileManager.fileExists(atPath: currentPath) {
            let parentPath = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path

            if parentPath == currentPath || parentPath.isEmpty {
                return "/"
            }

            currentPath = parentPath
        }

        return currentPath
    }

    private func detectFileSystemKind(for path: String) -> FileSystemKind {
        var stats = statfs()
        let result = path.withCString { pathPointer in
            statfs(pathPointer, &stats)
        }

        guard result == 0 else {
            return .unknown
        }

        let fileSystemName = withUnsafePointer(to: &stats.f_fstypename) { typePointer in
            typePointer.withMemoryRebound(to: CChar.self, capacity: Int(MFSNAMELEN)) { reboundPointer in
                String(cString: reboundPointer)
            }
        }.lowercased()

        switch fileSystemName {
        case "apfs":
            return .apfs
        case "hfs", "hfsplus":
            return .hfsplus
        case "exfat", "msdos":
            return .exfat
        case "smbfs":
            return .smb
        case "":
            return .unknown
        default:
            return .other
        }
    }
}
