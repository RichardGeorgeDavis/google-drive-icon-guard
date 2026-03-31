import Foundation

enum FileFootprint {
    static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
        .totalFileSizeKey,
        .fileAllocatedSizeKey,
        .totalFileAllocatedSizeKey,
        .nameKey
    ]

    static func bytes(for resourceValues: URLResourceValues) -> Int {
        resourceValues.totalFileAllocatedSize
            ?? resourceValues.fileAllocatedSize
            ?? resourceValues.totalFileSize
            ?? resourceValues.fileSize
            ?? 0
    }
}
