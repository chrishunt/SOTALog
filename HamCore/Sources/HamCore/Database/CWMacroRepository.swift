import Foundation
import GRDB

public struct CWMacroRepository {
    public let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Fetch

    public func fetchAll() async throws -> [CWMacro] {
        try await database.dbWriter.read { db in
            try CWMacro.order(Column("position").asc).fetchAll(db)
        }
    }

    // MARK: - Save

    public func save(_ macro: inout CWMacro) async throws {
        macro = try await database.dbWriter.write { [macro] db in
            var m = macro
            try m.save(db)
            return m
        }
    }

    // MARK: - Reset

    public func resetToDefaults() async throws {
        try await database.dbWriter.write { db in
            try CWMacro.deleteAll(db)
            for var macro in CWMacro.defaults {
                try macro.insert(db)
            }
        }
    }

    public func resetOne(position: Int) async throws {
        guard let factory = CWMacro.defaults.first(where: { $0.position == position }) else { return }
        try await database.dbWriter.write { db in
            if let existing = try CWMacro.filter(Column("position") == position).fetchOne(db) {
                var updated = factory
                updated.id = existing.id
                try updated.update(db)
            }
        }
    }
}
