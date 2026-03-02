import Foundation
import GRDB

struct LogRepository {
    let database: AppDatabase

    // MARK: - Fetch

    func fetchAll() async throws -> [Log] {
        try await database.dbWriter.read { db in
            try Log.order(Column("date").desc).fetchAll(db)
        }
    }

    func fetch(id: Int64) async throws -> Log? {
        try await database.dbWriter.read { db in
            try Log.fetchOne(db, id: id)
        }
    }

    // MARK: - Save

    @discardableResult
    func save(_ log: inout Log) async throws -> Log {
        log = try await database.dbWriter.write { [log] db in
            var mutableLog = log
            try mutableLog.save(db)
            return mutableLog
        }
        return log
    }

    // MARK: - Delete

    func delete(id: Int64) async throws {
        _ = try await database.dbWriter.write { db in
            try Log.deleteOne(db, id: id)
        }
    }

    // MARK: - Observation

    /// Starts observing all logs, calling the handler on each change.
    func observeAll(in writer: any DatabaseWriter, onChange: @escaping ([Log]) -> Void) -> AnyDatabaseCancellable {
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
