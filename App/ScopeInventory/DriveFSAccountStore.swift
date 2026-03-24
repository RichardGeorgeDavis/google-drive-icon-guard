import Foundation
import SQLite3

public struct DriveFSAccountRootRecord: Equatable, Sendable {
    public var accountToken: String
    public var rootID: Int64
    public var rootState: Int
    public var localStableID: Int64?
    public var itemID: String?
    public var isMyDrive: Bool

    public init(
        accountToken: String,
        rootID: Int64,
        rootState: Int,
        localStableID: Int64?,
        itemID: String?,
        isMyDrive: Bool
    ) {
        self.accountToken = accountToken
        self.rootID = rootID
        self.rootState = rootState
        self.localStableID = localStableID
        self.itemID = itemID
        self.isMyDrive = isMyDrive
    }
}

public enum DriveFSAccountStoreError: Error, LocalizedError {
    case openDatabase(path: String, code: Int32, message: String)
    case prepareStatement(path: String, code: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case let .openDatabase(path, code, message):
            return "Failed to open DriveFS account database at \(path) (\(code)): \(message)"
        case let .prepareStatement(path, code, message):
            return "Failed to prepare DriveFS account query for \(path) (\(code)): \(message)"
        }
    }
}

public struct DriveFSAccountStore {
    private let fileManager: FileManager
    private let driveFSRoot: String

    public init(
        fileManager: FileManager = .default,
        driveFSRoot: String = NSString(string: "~/Library/Application Support/Google/DriveFS").expandingTildeInPath
    ) {
        self.fileManager = fileManager
        self.driveFSRoot = driveFSRoot
    }

    public func accountDatabasePaths() -> [String] {
        accountTokens().map { mirrorDatabasePath(for: $0) }.filter { fileManager.fileExists(atPath: $0) }
    }

    public func loadRootRecords() throws -> [DriveFSAccountRootRecord] {
        try accountTokens().flatMap { token -> [DriveFSAccountRootRecord] in
            let path = mirrorDatabasePath(for: token)
            guard fileManager.fileExists(atPath: path) else {
                return []
            }

            return try readRootRecords(accountToken: token, from: path)
        }
    }

    public func confirmedRootIDsByAccount() throws -> [String: Set<Int64>] {
        Dictionary(grouping: try loadRootRecords().filter { $0.rootState != 0 }, by: \.accountToken)
            .mapValues { Set($0.map(\.rootID)) }
    }

    private func accountTokens() -> [String] {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: driveFSRoot) else {
            return []
        }

        return entries
            .filter { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
            .sorted()
    }

    private func mirrorDatabasePath(for accountToken: String) -> String {
        (driveFSRoot as NSString).appendingPathComponent(accountToken).appending("/mirror_sqlite.db")
    }

    private func readRootRecords(accountToken: String, from path: String) throws -> [DriveFSAccountRootRecord] {
        var database: OpaquePointer?
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let databaseURI = "file:\(encodedPath)?mode=ro&immutable=1"

        let openResult = sqlite3_open_v2(databaseURI, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
        guard openResult == SQLITE_OK, let database else {
            let message = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite error"
            sqlite3_close(database)
            throw DriveFSAccountStoreError.openDatabase(path: path, code: openResult, message: message)
        }

        defer {
            sqlite3_close(database)
        }

        let query = """
        SELECT
            root_id,
            root_state,
            local_stable_id,
            item_id,
            is_my_drive
        FROM root_config
        ORDER BY root_id;
        """

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(database, query, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(database))
            throw DriveFSAccountStoreError.prepareStatement(path: path, code: prepareResult, message: message)
        }

        defer {
            sqlite3_finalize(statement)
        }

        var records: [DriveFSAccountRootRecord] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let localStableID = sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : Int64(sqlite3_column_int64(statement, 2))
            let itemID = sqlite3_column_text(statement, 3).map { String(cString: $0) }

            records.append(
                DriveFSAccountRootRecord(
                    accountToken: accountToken,
                    rootID: sqlite3_column_int64(statement, 0),
                    rootState: Int(sqlite3_column_int(statement, 1)),
                    localStableID: localStableID,
                    itemID: itemID,
                    isMyDrive: sqlite3_column_int(statement, 4) != 0
                )
            )
        }

        return records
    }
}
