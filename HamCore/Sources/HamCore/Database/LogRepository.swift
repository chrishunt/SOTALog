import Foundation
import GRDB

public struct LogRepository {
    public let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Fetch

    public func fetchAll() async throws -> [Log] {
        try await database.dbWriter.read { db in
            try Log.order(Column("date").desc).fetchAll(db)
        }
    }

    public func fetch(id: Int64) async throws -> Log? {
        try await database.dbWriter.read { db in
            try Log.fetchOne(db, id: id)
        }
    }

    // MARK: - Save

    @discardableResult
    public func save(_ log: inout Log) async throws -> Log {
        log = try await database.dbWriter.write { [log] db in
            var mutableLog = log
            try mutableLog.save(db)
            return mutableLog
        }
        return log
    }

    // MARK: - Delete

    public func delete(id: Int64) async throws {
        _ = try await database.dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM qso WHERE logId = ? AND syncedToQRZ = 0",
                arguments: [id]
            )
            try Log.deleteOne(db, id: id)
        }
    }

    // MARK: - Observation

    /// Starts observing all logs, calling the handler on each change.
    public func observeAll(in writer: any DatabaseWriter, onChange: @escaping ([Log]) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try Log.order(Column("date").desc).fetchAll(db)
        }
        return observation.start(
            in: writer,
            onError: { error in AppLog.database.error("Log observation failed: \(error)") },
            onChange: onChange
        )
    }
}
