import Foundation
import GRDB

struct LogRepository {
    let database: AppDatabase

    // MARK: - Fetch

    func fetchAll() async throws -> [Log] {
        try await database.dbWriter.read { db in
            try Log.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    func fetch(id: Int64) async throws -> Log? {
        try await database.dbWriter.read { db in
            try Log.fetchOne(db, id: id)
        }
    }

    func fetchActive() async throws -> Log? {
        try await database.dbWriter.read { db in
            try Log.filter(Column("isActive") == true).fetchOne(db)
        }
    }

    // MARK: - Save

    @discardableResult
    func save(_ log: inout Log) async throws -> Log {
        let isActive = log.isActive
        log = try await database.dbWriter.write { [log] db in
            var mutableLog = log
            if isActive {
                try Log.filter(Column("isActive") == true).updateAll(db, Column("isActive").set(to: false))
            }
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
            try Log.order(Column("createdAt").desc).fetchAll(db)
        }
        return observation.start(in: writer, onError: { _ in }, onChange: onChange)
    }
}
