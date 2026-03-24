import Foundation
import SQLite3
import DriveIconGuardShared

public struct DriveFSRootPreferenceRecord: Equatable, Sendable {
    public var rootID: Int64
    public var title: String
    public var rootPath: String
    public var accountToken: String
    public var syncType: Int
    public var destination: Int
    public var medium: Int
    public var state: Int
    public var oneShot: Bool
    public var isMyDrive: Bool
    public var documentID: String
    public var lastSeenAbsolutePath: String

    public init(
        rootID: Int64,
        title: String,
        rootPath: String,
        accountToken: String,
        syncType: Int,
        destination: Int,
        medium: Int,
        state: Int,
        oneShot: Bool,
        isMyDrive: Bool,
        documentID: String,
        lastSeenAbsolutePath: String
    ) {
        self.rootID = rootID
        self.title = title
        self.rootPath = rootPath
        self.accountToken = accountToken
        self.syncType = syncType
        self.destination = destination
        self.medium = medium
        self.state = state
        self.oneShot = oneShot
        self.isMyDrive = isMyDrive
        self.documentID = documentID
        self.lastSeenAbsolutePath = lastSeenAbsolutePath
    }
}

public enum DriveFSRootPreferenceError: Error, LocalizedError {
    case openDatabase(path: String, code: Int32, message: String)
    case prepareStatement(path: String, code: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case let .openDatabase(path, code, message):
            return "Failed to open DriveFS root preference database at \(path) (\(code)): \(message)"
        case let .prepareStatement(path, code, message):
            return "Failed to prepare DriveFS root preference query for \(path) (\(code)): \(message)"
        }
    }
}

public struct DriveFSRootPreferenceStore {
    private let fileManager: FileManager
    private let driveFSRoot: String
    private let volumeClassifier: VolumeClassifier
    private let supportClassifier: ScopeSupportClassifier

    public init(
        fileManager: FileManager = .default,
        driveFSRoot: String = NSString(string: "~/Library/Application Support/Google/DriveFS").expandingTildeInPath,
        volumeClassifier: VolumeClassifier = VolumeClassifier(),
        supportClassifier: ScopeSupportClassifier = ScopeSupportClassifier()
    ) {
        self.fileManager = fileManager
        self.driveFSRoot = driveFSRoot
        self.volumeClassifier = volumeClassifier
        self.supportClassifier = supportClassifier
    }

    public func existingLocations() -> [String] {
        var locations: [String] = []

        if fileManager.fileExists(atPath: driveFSRoot) {
            locations.append(driveFSRoot)
        }

        let databasePath = rootPreferenceDatabasePath()
        if fileManager.fileExists(atPath: databasePath) {
            locations.append(databasePath)
        }

        locations.append(contentsOf: accountDirectories())

        return locations.sorted()
    }

    public func rootPreferenceDatabasePath() -> String {
        (driveFSRoot as NSString).appendingPathComponent("root_preference_sqlite.db")
    }

    public func loadRecords() throws -> [DriveFSRootPreferenceRecord] {
        let databasePath = rootPreferenceDatabasePath()

        guard fileManager.fileExists(atPath: databasePath) else {
            return []
        }

        return try readRecords(from: databasePath)
    }

    public func discoverScopes() throws -> [DriveManagedScope] {
        try loadRecords().compactMap(scope(from:))
    }

    private func accountDirectories() -> [String] {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: driveFSRoot) else {
            return []
        }

        return entries
            .filter(isPotentialAccountDirectory(_:))
            .map { (driveFSRoot as NSString).appendingPathComponent($0) }
            .filter { fileManager.fileExists(atPath: $0, isDirectory: nil) }
            .sorted()
    }

    private func isPotentialAccountDirectory(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy(\.isNumber)
    }

    private func scope(from record: DriveFSRootPreferenceRecord) -> DriveManagedScope? {
        guard record.state != 0 else {
            return nil
        }

        let resolvedPath = resolvedPath(for: record)
        guard !resolvedPath.isEmpty else {
            return nil
        }

        let volume = volumeClassifier.classify(path: resolvedPath)
        let driveMode = driveMode(for: record, resolvedPath: resolvedPath)
        let scopeKind = scopeKind(for: record, resolvedPath: resolvedPath, volumeKind: volume.volumeKind)

        let scope = DriveManagedScope(
            accountID: record.accountToken,
            displayName: record.title.isEmpty ? URL(fileURLWithPath: resolvedPath).lastPathComponent : record.title,
            path: resolvedPath,
            scopeKind: scopeKind,
            driveMode: driveMode,
            source: .config,
            volumeKind: volume.volumeKind,
            fileSystemKind: volume.fileSystemKind,
            supportStatus: .auditOnly
        )

        return supportClassifier.applyingAssessment(to: scope)
    }

    private func resolvedPath(for record: DriveFSRootPreferenceRecord) -> String {
        if !record.lastSeenAbsolutePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return record.lastSeenAbsolutePath
        }

        if record.rootPath.hasPrefix("/") {
            return record.rootPath
        }

        if record.rootPath.isEmpty {
            return ""
        }

        return "/" + record.rootPath
    }

    private func driveMode(for record: DriveFSRootPreferenceRecord, resolvedPath: String) -> DriveMode {
        if record.isMyDrive {
            let cloudStoragePrefix = NSHomeDirectory() + "/Library/CloudStorage/"
            return resolvedPath.hasPrefix(cloudStoragePrefix) ? .stream : .mirror
        }

        return .backup
    }

    private func scopeKind(
        for record: DriveFSRootPreferenceRecord,
        resolvedPath: String,
        volumeKind: VolumeKind
    ) -> ScopeKind {
        if record.isMyDrive {
            return .myDrive
        }

        let lowercasedTitle = record.title.lowercased()
        let lowercasedPath = resolvedPath.lowercased()

        if lowercasedTitle.contains("photos") || lowercasedPath.contains("photos library") {
            return .photosLibrary
        }

        if volumeKind == .network {
            return .networkVolume
        }

        if volumeKind == .removable {
            return .removableVolume
        }

        return .backupFolder
    }

    private func readRecords(from path: String) throws -> [DriveFSRootPreferenceRecord] {
        var database: OpaquePointer?
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let databaseURI = "file:\(encodedPath)?mode=ro&immutable=1"

        let openResult = sqlite3_open_v2(databaseURI, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
        guard openResult == SQLITE_OK, let database else {
            let message = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite error"
            sqlite3_close(database)
            throw DriveFSRootPreferenceError.openDatabase(path: path, code: openResult, message: message)
        }

        defer {
            sqlite3_close(database)
        }

        let query = """
        SELECT
            root_id,
            title,
            root_path,
            account_token,
            sync_type,
            destination,
            medium,
            state,
            one_shot,
            is_my_drive,
            doc_id,
            last_seen_absolute_path
        FROM roots
        ORDER BY root_id;
        """

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(database, query, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(database))
            throw DriveFSRootPreferenceError.prepareStatement(path: path, code: prepareResult, message: message)
        }

        defer {
            sqlite3_finalize(statement)
        }

        var records: [DriveFSRootPreferenceRecord] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            records.append(
                DriveFSRootPreferenceRecord(
                    rootID: sqlite3_column_int64(statement, 0),
                    title: textColumn(statement, index: 1),
                    rootPath: textColumn(statement, index: 2),
                    accountToken: textColumn(statement, index: 3),
                    syncType: Int(sqlite3_column_int(statement, 4)),
                    destination: Int(sqlite3_column_int(statement, 5)),
                    medium: Int(sqlite3_column_int(statement, 6)),
                    state: Int(sqlite3_column_int(statement, 7)),
                    oneShot: sqlite3_column_int(statement, 8) != 0,
                    isMyDrive: sqlite3_column_int(statement, 9) != 0,
                    documentID: textColumn(statement, index: 10),
                    lastSeenAbsolutePath: textColumn(statement, index: 11)
                )
            )
        }

        return records
    }

    private func textColumn(_ statement: OpaquePointer?, index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else {
            return ""
        }

        return String(cString: value)
    }
}
